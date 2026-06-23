# XRAY REVERSE ENGINEERING — Remnawave → AURORA

> **Stage 6: Xray Reverse Engineering**
> **Date:** 2026-06-23
> **Status:** COMPLETE

---

## 1. XRAY-CORE INTEGRATION ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        REMNAWAVE ↔ XRAY INTEGRATION                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  BACKEND (Panel)                                                         │
│  ├── ConfigProfiles → Xray JSON config templates                        │
│  ├── Hosts → inbound/outbound definitions                                │
│  ├── Keygen → X25519 keys + certificates                                │
│  └── Users → trojanPassword, vlessUuid, ssPassword                       │
│       │                                                                  │
│       │ mTLS + JWT (RS256)                                              │
│       ▼                                                                  │
│  NODE (Edge Agent)                                                       │
│  │                                                                       │
│  ├── XrayService.startXray()                                             │
│  │   ├── generateApiConfig() — MERGE panel config + Xray API defaults    │
│  │   ├── InternalService.extractUsersFromConfig() — HashedSet per inbound│
│  │   └── restartXrayProcess() — Supervisord XML-RPC                      │
│  │                                                                       │
│  ├── InternalService                                                     │
│  │   └── GET /internal/get-config — Serves merged config to Xray        │
│  │                                                                       │
│  ├── HandlerService                                                      │
│  │   └── gRPC → Xray HandlerService (addUser, removeUser, ...)           │
│  │                                                                       │
│  ├── StatsService                                                        │
│  │   └── gRPC → Xray StatsService (getStats, getSysStats, ...)           │
│  │                                                                       │
│  ├── VisionService                                                       │
│  │   └── gRPC → Xray RoutingService (addSrcIpRule, removeRule)           │
│  │                                                                       │
│  └── PluginService                                                       │
│      ├── nftables (IP blocking)                                          │
│      ├── sockdestroy (connection drop)                                   │
│      └── Webhook ← Xray torrent detection                                │
│                                                                          │
│       │                                                                  │
│       ▼                                                                  │
│  XRAY-CORE (rw-core fork)                                                │
│  ├── Inbounds (user traffic): trojan, vless, ss, ss2022, hysteria       │
│  ├── API Inbound (gRPC): REMNAWAVE_API_INBOUND (mTLS, localhost)        │
│  ├── Outbounds (proxy destinations)                                      │
│  ├── Routing Rules (traffic direction)                                   │
│  ├── Stats counters (per-user uplink/downlink)                           │
│  └── Observatory (torrent detection → webhook)                           │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. CONFIG GENERATION

### 2.1 Backend Side: User Data Preparation

При создании пользователя backend генерирует:

```typescript
// users table
{
    trojanPassword: randomPassword(),    // random string
    vlessUuid: crypto.randomUUID(),      // стандартный UUID v4
    ssPassword: randomPassword(),        // random string
    shortUuid: nanoid(SHORT_UUID_LENGTH) // 16-64 символов, URL-safe
}
```

**VLESS UUID** — стандартный UUID v4 (RFC 9562), генерируется PostgreSQL: `gen_random_uuid()`.
**Short UUID** — генерируется через `nanoid`, длина настраивается (по умолчанию 16).
**Trojan/SS пароли** — случайные строки.

### 2.2 Backend Side: Config Profile → Node Config

Backend хранит Xray JSON конфиги в `config_profiles.config` (JSONB). Когда нода запускается:

1. Backend загружает `ConfigProfile` для ноды
2. Вычисляет `computedConfig` (резолвит inbounds, хостовые привязки)
3. Отправляет через `POST /node/xray/start` body: `{ xrayConfig: {...}, internals: { hashes: {...} } }`

### 2.3 Node Side: generateApiConfig() — Слияние конфига

**Файл:** `node_source/src/common/utils/generate-api-config.ts`

```
Panel Config (входящий)
    │
    ├── stats: {}                            ← XRAY_DEFAULT_STATS_MODEL
    ├── api: { services: [...], tag: ... }   ← XRAY_DEFAULT_API_MODEL
    │
    ├── inbounds: [
    │       REMNAWAVE_API_INBOUND,           ← mTLS gRPC, 127.0.0.1:XTLS_API_PORT
    │       ...panel_inbounds,               ← Оригинальные inbounds из панели
    │   ]
    │
    ├── policy: {                            ← XRAY_DEFAULT_POLICY_MODEL
    │       levels: {
    │           '0': {
    │               statsUserUplink: true,
    │               statsUserDownlink: true,
    │               statsUserOnline: hasCapNetAdmin,  ← true если NET_ADMIN
    │           }
    │       }
    │   }
    │
    ├── routing: {
    │       rules: [
    │           API_ROUTING_RULE,             ← REMNAWAVE_API_INBOUND → REMNAWAVE_API
    │           ...panel_routing_rules,       ← Оригинальные routing rules
    │       ]
    │   }
    │
    └── [if torrent blocker enabled]:
        ├── outbounds: [..., BLACKHOLE_OUTBOUND]  ← RW_TB_OUTBOUND_BLOCK (blackhole)
        └── routing.rules: [..., TORRENT_RULE]    ← bittorrent → blackhole + webhook
```

**API Inbound (gRPC endpoint):**
```json
{
    "tag": "REMNAWAVE_API_INBOUND",
    "port": 61000,
    "listen": "127.0.0.1",
    "protocol": "dokodemo-door",
    "settings": { "address": "127.0.0.1" },
    "streamSettings": {
        "security": "tls",
        "tlsSettings": {
            "alpn": ["h2"],
            "serverName": "internal.remnawave.local",
            "disableSystemRoot": true,
            "rejectUnknownSni": true,
            "certificates": [
                { "certificate": [...], "key": [...], "usage": "issue" },
                { "certificate": [...], "usage": "verify" }
            ]
        }
    }
}
```

**API Services (доступные через gRPC):**
- `HandlerService` — добавление/удаление пользователей
- `StatsService` — запрос статистики трафика
- `RoutingService` — управление правилами маршрутизации

**Policy (настройки статистики):**
- `statsUserUplink: true` — счётчик аплинка на пользователя
- `statsUserDownlink: true` — счётчик даунлинка на пользователя
- `statsUserOnline: true` (только с CAP_NET_ADMIN) — отслеживание онлайна
- Системные счётчики для inbound/outbound

---

## 3. CLIENT (USER) MANAGEMENT

### 3.1 Поддерживаемые протоколы

| Протокол | Поле в БД | Тип в Xray | Параметры |
|----------|----------|-----------|-----------|
| **Trojan** | `trojanPassword` | `addTrojanUser` | password, level=0 |
| **VLESS** | `vlessUuid` | `addVlessUser` | uuid, flow, level=0 |
| **Shadowsocks** | `ssPassword` | `addShadowsocksUser` | password, cipherType, ivCheck=false, level=0 |
| **Shadowsocks 2022** | `ssPassword` | `addShadowsocks2022User` | key (base64 encoded), level=0 |
| **Hysteria** | `vlessUuid` (как password) | `addHysteriaUser` | uuid (используется vlessUuid), level=0 |

### 3.2 Add User Flow (Single)

```
Backend: POST /node/handler/add-user
    Body: {
        data: [{ type, tag, username, password/uuid, flow }],
        hashData: { vlessUuid, prevVlessUuid? }
    }
    │
    ▼
HandlerService.addUser()
    │
    ├── 1. Для каждого inbound tag → internalService.addXtlsConfigInbound(tag)
    │
    ├── 2. Для КАЖДОГО известного inbound:
    │   ├── xtlsApi.handler.removeUser(tag, username)  ← удалить перед добавлением
    │   └── internalService.removeUserFromInbound(tag, vlessUuid)
    │
    ├── 3. Для каждого элемента data:
    │   ├── Switch по protocol type:
    │   │   ├── trojan → xtlsApi.handler.addTrojanUser({tag, username, password, level:0})
    │   │   ├── vless  → xtlsApi.handler.addVlessUser({tag, username, uuid, flow, level:0})
    │   │   ├── shadowsocks → xtlsApi.handler.addShadowsocksUser({..., cipherType, ivCheck:false})
    │   │   ├── shadowsocks22 → xtlsApi.handler.addShadowsocks2022User({tag, username, key})
    │   │   └── hysteria → xtlsApi.handler.addHysteriaUser({tag, username, uuid})
    │   └── Если успешно → internalService.addUserToInbound(tag, vlessUuid)
    │
    └── 4. Return { success: true }
```

### 3.3 Bulk Add Users Flow

```
Backend: POST /node/handler/add-users
    Body: {
        affectedInboundTags: ['tag1', 'tag2'],
        users: [{
            userData: { userId, hashUuid, vlessUuid, trojanPassword, ssPassword },
            inboundData: [{ type, tag, flow, ... }]
        }, ...]
    }
    │
    ▼
HandlerService.addUsers()
    │
    ├── 1. Для каждого affectedInboundTag → internalService.addXtlsConfigInbound(tag)
    │
    ├── 2. Для КАЖДОГО пользователя:
    │   ├── Для каждого известного inbound:
    │   │   ├── xtlsApi.handler.removeUser(tag, userId)
    │   │   └── internalService.removeUserFromInbound(tag, hashUuid)
    │   └── Для каждого inboundData:
    │       ├── Switch по типу → add*User()
    │       └── Если успешно → internalService.addUserToInbound(tag, vlessUuid)
    │
    └── 3. Return { success: true }
```

### 3.4 Remove User Flow

```
HandlerService.removeUser()
    │
    ├── 1. Получить IP пользователя: xtlsApi.stats.rawClient.getStatsOnlineIpList()
    │       Pattern: "user>>>{username}>>>online"
    │
    ├── 2. Для КАЖДОГО известного inbound:
    │   ├── xtlsApi.handler.removeUser(tag, username)
    │   └── internalService.removeUserFromInbound(tag, vlessUuid)
    │
    ├── 3. Опубликовать DropConnectionsEvent (с IP пользователя)
    │       → sockdestroy: killSockets() для каждого IP
    │
    └── 4. Return { success: true }
```

### 3.5 Drop Connections Flow

```
DropConnectionsHandler (CQRS Event)
    │
    ├── Получает IP-адреса
    ├── Проверяет whitelist (connection-drop plugin state)
    ├── Фильтрует: исключает whitelisted IP
    └── sockdestroy.killSockets(ips)
        └── Прямой обрыв TCP соединений через /proc/net/tcp
            (без fork'а shell-процессов, CPU-efficient)
```

---

## 4. TRAFFIC ACCOUNTING

### 4.1 Xray Stats Service API

Xray-core предоставляет gRPC StatsService со следующими методами:

| Метод | Параметры | Возвращает |
|-------|----------|-----------|
| `getSysStats` | — | `{ NumGoroutine, NumGC, Alloc, TotalAlloc, Sys, Mallocs, Frees, LiveObjects, PauseTotalNs, Uptime }` |
| `getUserOnlineStatus` | `username` | `{ online: boolean }` |
| `getAllUsersStats` | `reset: boolean` | `{ users: [{ username, uplink, downlink }] }` |
| `getInboundStats` | `tag, reset` | `{ inbound: { inbound, uplink, downlink } }` |
| `getOutboundStats` | `tag, reset` | `{ outbound: { outbound, uplink, downlink } }` |
| `getAllInboundsStats` | `reset` | `{ inbounds: [...] }` |
| `getAllOutboundsStats` | `reset` | `{ outbounds: [...] }` |
| `getStatsOnlineIpList` | `name, reset` | `{ ips: { ip: timestamp } }` |
| `getAllOnlineUsers` | `{}` | `{ users: string[] }` |

### 4.2 Stats Collection Pipeline

```
┌─────────────────────────────────────────────────────────────────────┐
│                    TRAFFIC ACCOUNTING PIPELINE                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Xray-core (каждый пакет)                                           │
│    │ Считает байты per-user внутри ядра (in-memory counters)        │
│    │                                                                 │
│    ▼                                                                 │
│  Scheduler: RECORD_USER_USAGE (каждые 15 сек)                       │
│    │ Enqueue: NODES_RECORD_USER_USAGE_QUEUE                          │
│    │                                                                 │
│    ▼                                                                 │
│  Worker Processor: record-user-usage                                 │
│    │ POST /node/stats/get-users-stats { reset: true }                │
│    │                                                                 │
│    ▼                                                                 │
│  Node StatsService.getUsersStats(reset: true)                       │
│    │ xtlsSdk.stats.getAllUsersStats(true)                            │
│    │ ← Xray возвращает { username, uplink, downlink }                │
│    │ ← Xray АТОМАРНО обнуляет счётчики (reset: true)                │
│    │                                                                 │
│    ▼                                                                 │
│  Worker: BulkUpsertUserHistoryEntry                                  │
│    │ UPSERT INTO nodes_user_usage_history (nodeId, userId, date)     │
│    │ UPDATE user_traffic SET used_traffic_bytes += delta             │
│    │ UPDATE nodes SET traffic_used_bytes += delta                    │
│    │                                                                 │
│    ▼                                                                 │
│  PostgreSQL: исторические данные + текущие счётчики                   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.3 Reset Pattern

Ключевой механизм учёта — **атомарный сброс** счётчиков Xray:

```
StatsService.getUsersStats(reset: true)
    │
    │ Xray gRPC: getAllUsersStats(reset=true)
    │   ├── Читает текущие значения счётчиков
    │   ├── Возвращает прочитанные значения
    │   └── Обнуляет счётчики (атомарно)
    │
    │ Backend получает дельту с последнего замера
    │ UPSERT ... totalBytes = totalBytes + delta
```

**Частота сбора:**
- User usage: каждые 15 секунд (RECORD_USER_USAGE)
- Node usage: каждые 30 секунд (RECORD_NODE_USAGE)
- System stats: каждый запрос к Node (on-demand + healthcheck)

### 4.4 System Stats (расширенные)

`getSystemStats()` на Node объединяет:
1. **Xray Go runtime**: горутины, память, GC, uptime (через `xtlsSdk.stats.getSysStats()`)
2. **Node OS**: CPU модель/ядра, load average, память, диск, uptime (через `getSystemStats()`)
3. **Network interfaces**: rx/tx bytes/sec на интерфейсах (через `NetworkStatsService` — `/proc/net/dev` polling)
4. **Plugin status**: количество torrent blocker reports

---

## 5. UUID GENERATION

### 5.1 VLESS UUID

```sql
-- PostgreSQL генерирует стандартный UUID v4
uuid UUID DEFAULT gen_random_uuid()
```

**Формат:** `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx` (RFC 9562, UUID v4)
**Использование:** VLESS протокол, Hysteria протокол, внешние ссылки

### 5.2 Short UUID

```typescript
// nanoid с настраиваемой длиной
shortUuid = nanoid(SHORT_UUID_LENGTH) // default: 16 символов
```

**Назначение:** URL-safe идентификатор для подписок (`/api/sub/:shortUuid`).
**Алфавит:** `A-Za-z0-9_-` (64 символа)
**Коллизии:** при длине 16 вероятность коллизии ~1.4e-29 (ничтожна)

### 5.3 Trojan/Shadowsocks Passwords

Случайные строки, генерируются приложением (не БД). Используются как пароли протоколов.

### 5.4 X25519 Keys (Keygen)

```typescript
// Генерируются через @stablelib/x25519
const keypair = generateKeyPair();
// Сохраняются в keygen таблице
{
    privKey: base64(keypair.secretKey),
    pubKey: base64(keypair.publicKey),
    caCert: ..., caKey: ...,
    clientCert: ..., clientKey: ...
}
```

**Назначение:** Reality/X25519 ключи для VLESS XTLS.

---

## 6. INBOUND / OUTBOUND OPERATIONS

### 6.1 Inbound Types (поддерживаемые панелью)

| Тип | Xray Inbound Protocol | Параметры |
|-----|----------------------|-----------|
| `trojan` | trojan | password, fallback |
| `vless` | vless | uuid, flow (xtls-rprx-vision) |
| `shadowsocks` | shadowsocks | password, cipherType |
| `shadowsocks2022` | shadowsocks2022 | key (base64) |
| `hysteria` | hysteria (external core) | uuid |

### 6.2 Inbound Config Structure

```json
{
    "tag": "inbound-1",
    "port": 443,
    "protocol": "vless",
    "settings": {
        "clients": [
            {
                "id": "uuid-v4",
                "flow": "xtls-rprx-vision",
                "level": 0,
                "email": "username"
            }
        ],
        "decryption": "none"
    },
    "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
            "serverNames": ["discord.com", "addons.mozilla.org"],
            "privateKey": "base64-x25519-privkey",
            "shortIds": ["abcdef"],
            "show": false
        }
    },
    "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic", "fakedns"]
    }
}
```

### 6.3 Routing Rules

```json
{
    "routing": {
        "rules": [
            {
                "inboundTag": ["REMNAWAVE_API_INBOUND"],
                "outboundTag": "REMNAWAVE_API",
                "type": "field"
            },
            {
                "protocol": ["bittorrent"],
                "outboundTag": "RW_TB_OUTBOUND_BLOCK",
                "webhook": {
                    "url": "http+unix:///run/remnawave-xxx.sock:/internal/webhook?token=yyy",
                    "deduplication": 5
                }
            }
        ]
    }
}
```

### 6.4 IP Block/Unblock (Vision)

```typescript
// Block: hash IP (MD5) + add routing rule
const ipHash = md5(ip);
await xtlsApi.router.addSrcIpRule({
    ip: ip,
    outboundTag: 'BLOCK',
    ruleTag: ipHash
});

// Unblock: remove routing rule by tag
await xtlsApi.router.removeRuleByRuleTag({ ruleTag: ipHash });
```

**Примечание:** Vision эндпоинты (`/block-ip`, `/unblock-ip`) не имеют префикса `/node` и не имеют JWT guard — только mTLS.

---

## 7. HASH-BASED CONFIG OPTIMIZATION

### 7.1 HashedSet Data Structure

```
HashedSet (from @remnawave/hashed-set)
    │
    ├── add(userId)     → обновляет внутренний hash64 (O(1))
    ├── delete(userId)  → обновляет внутренний hash64 (O(1))
    ├── size            → количество пользователей
    └── hash64String    → 64-битный хеш (всех элементов)
```

### 7.2 Hash Comparison Flow

```
Panel → Node: { xrayConfig, internals: { hashes: {
    emptyConfig: "abc123",           ← hash конфига БЕЗ clients
    inbounds: [
        { tag: "inbound-1", hash: "def456", usersCount: 150 },
        { tag: "inbound-2", hash: "789xyz", usersCount: 200 }
    ]
} } }

Node InternalService.isNeedRestartCore(incomingHashes):
    │
    ├── emptyConfig hash изменился? → RESTART
    ├── Количество inbounds изменилось? → RESTART
    ├── Для каждого inbound:
    │   ├── Есть ли входящий inbound с таким tag?
    │   └── localHash === incomingHash? → NO RESTART
    │       localHash !== incomingHash? → RESTART
    │
    └── Все хеши совпали → NO RESTART (пропускаем перезапуск Xray)
```

**Результат:** Если пользователи не изменились — Xray не перезапускается. Экономия downtime.

---

## 8. TORRENT BLOCKER INTEGRATION

### 8.1 Xray Webhook Flow

```
1. Torrent пакет обнаружен Xray (по protocol sniffing)
2. Xray отправляет webhook на Internal Socket:
   POST http+unix:///run/remnawave-xxx.sock:/internal/webhook?token=yyy
   Body: { source: { ip: "1.2.3.4" }, ... }
3. InternalController → EventBus: XrayWebhookEvent
4. XrayWebhookHandler:
   ├── Проверяет ignored IPs/users
   ├── nftService.blockIp(ip, timeout) → nftables rule
   ├── DropConnectionsEvent → sockdestroy.killSockets()
   └── Сохраняет report в memory (collectReports)
```

### 8.2 Nftables Integration

```typescript
// Блокировка IP через nftables-napi (C++ addon)
nftService.blockIp(ip, timeoutSeconds) {
    // Добавляет IP в nftables set с таймаутом
    nftManager.setAddElement('REMNAWAVE', 'torrent_blocker_set', {
        element: { ip, timeout: timeoutSeconds }
    });
}
```

**Nftables table: `REMNAWAVE`**
- Set `torrent_blocker_set` — временная блокировка (с timeout)
- Set `ingress_filter_set` — постоянный ingress фильтр
- Set `egress_filter_set` — постоянный egress фильтр (IP)
- Set `egress_filter_port_set` — egress фильтр (порты)

---

## 9. CONFIG DELIVERY TO XRAY

### 9.1 Startup Sequence

```
1. Panel: POST /node/xray/start { xrayConfig: {...}, internals: {...} }
2. Node: generateApiConfig() → merged config
3. Node: InternalService.setXrayConfig(mergedConfig)
4. Node: Supervisord → stop xray (if running) → start xray
5. Supervisord запускает Xray с командой:
   rw-core -config http+unix://<socket>/internal/get-config?token=<token> -format json
6. Xray делает HTTP GET на Unix socket:
   GET /internal/get-config?token=<token>
7. InternalController возвращает InternalService.xrayConfig
8. Xray парсит конфиг и начинает принимать трафик
```

### 9.2 Config Format

Xray-core принимает конфиг в JSON формате. Все настройки (inbounds, outbounds, routing, stats, api, policy) передаются как единый JSON-объект.

---

## 10. XRAY-CORE FORK (rw-core)

Remnawave использует собственный форк Xray-core (`rw-core`):

- **Бинарник:** `/usr/local/bin/rw-core`
- **Версия:** Устанавливается через `XRAY_CORE_VERSION` env var
- **Обновление:** Через `CUSTOM_CORE_URL` env var (скачивание кастомного бинарника)
- **Symlink:** `rw-core` → `xray` (создаётся в Dockerfile)

**Ключевое отличие от upstream:** поддержка `http+unix://` схемы для получения конфига (в стандартном Xray такой схемы нет).

---

## 11. SUBSCRIPTION CONFIG GENERATION (Backend)

### 11.1 Template Generators

5 генераторов конфигов для клиентских приложений:

| Генератор | Формат | Клиенты |
|-----------|--------|---------|
| `XrayGeneratorService` | Xray custom format | Nekoray, Nekobox, v2rayNG |
| `XrayJsonGeneratorService` | Xray JSON | Xray-core напрямую |
| `ClashGeneratorService` | Clash Meta YAML | Clash Meta, Clash Verge |
| `MihomoGeneratorService` | Mihomo format | Mihomo Party |
| `SingboxGeneratorService` | Sing-box JSON | Sing-box |

### 11.2 Генерация подписки (Pipeline)

```
1. User-Agent → определение типа клиента (ResponseRulesMiddleware)
2. Загрузка хостов (с фильтрацией по squads и inbound доступу)
3. Применение внешних оверрайдов (external squad: hostOverrides, subscriptionSettings)
4. Применение HWID проверок (если включено)
5. Рендеринг шаблона:
   ├── Подстановка хостов (address, port, sni, path, ...)
   ├── Подстановка пользователя (uuid, password, ...)
   ├── Подстановка ключей X25519 (для reality)
   ├── Подстановка TLS fingerprint, ALPN, MUX, sockopt
   └── Генерация финального конфига
6. Применение Response Rules (custom headers, content-type)
7. Возврат клиенту
```

---

## 12. KEY FILES REFERENCE

| Компонент | Файл | Назначение |
|-----------|------|-----------|
| **Node: Config Merge** | `node_source/src/common/utils/generate-api-config.ts` | Слияние конфига панели с Xray API |
| **Node: Xray Lifecycle** | `node_source/src/modules/xray-core/xray.service.ts` | Start/Stop/Healthcheck |
| **Node: User CRUD** | `node_source/src/modules/handler/handler.service.ts` | addUser, removeUser, bulk ops |
| **Node: Stats** | `node_source/src/modules/stats/stats.service.ts` | Traffic queries |
| **Node: Internal** | `node_source/src/modules/internal/internal.service.ts` | HashedSet, hash comparison |
| **Node: Plugin** | `node_source/src/modules/_plugin/plugin.service.ts` | Torrent blocker, nftables |
| **Node: Vision** | `node_source/src/modules/vision/vision.service.ts` | IP block/unblock |
| **Node: API Inbound** | `node_source/libs/contract/constants/xray/stats.ts` | Xray API inbound config |
| **Backend: Templates** | `backend_source/src/modules/subscription-template/generators/` | Client config generators |
| **Backend: Keygen** | `backend_source/src/modules/keygen/` | X25519 keys, certificates |

---

*End of Stage 6 — XRAY_INTERNALS.md*
