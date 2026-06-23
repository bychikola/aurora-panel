# DATABASE FORENSICS — Remnawave → AURORA

> **Stage 3: Database Intelligence**
> **Date:** 2026-06-23
> **Status:** COMPLETE

---

## 1. OVERVIEW

| Параметр | Значение |
|----------|---------|
| **СУБД** | PostgreSQL |
| **ORM** | Prisma 6.19.0 |
| **Query Builder** | Kysely 0.28.11 |
| **Количество таблиц** | 36 |
| **Количество миграций** | 98 (с 2024-11-29 по 2026-06-25) |
| **Первичные ключи** | UUID (gen_random_uuid()) — 24 таблицы, BigInt autoincrement — 5 таблиц, Composite PK — 7 таблиц |
| **Seed файлов** | 12 |

---

## 2. ENTITY-RELATIONSHIP DIAGRAM

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           REMNAWAVE DATABASE — 36 TABLES                              │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌──────────────────┐          ┌──────────────────┐                                   │
│  │  remnawave_      │          │      admin       │                                   │
│  │  settings (1)    │          │  (uuid PK)       │                                   │
│  │  JSON settings   │          │  username UNIQUE  │                                   │
│  └──────────────────┘          │  passwordHash     │                                   │
│                                │  role             │                                   │
│  ┌──────────────────┐          └────────┬─────────┘                                   │
│  │   api_tokens     │                   │ 1:N                                         │
│  │  (uuid PK)       │          ┌────────┴─────────┐                                   │
│  │  token UNIQUE    │          │    passkeys       │                                   │
│  └──────────────────┘          │  (id PK)          │                                   │
│                                │  adminUuid FK     │                                   │
│                                │  publicKey BYTES  │                                   │
│  ┌──────────────────┐          │  counter          │                                   │
│  │     keygen       │          └──────────────────┘                                   │
│  │  (uuid PK)       │                                                                │
│  │  privKey, pubKey │                                                                │
│  │  caCert, clientCert│                                                               │
│  └──────────────────┘                                                                │
│                                                                                      │
│  ┌──────────────────────────────────────────────────────────────────────────────┐    │
│  │                          USER MANAGEMENT SUBSYSTEM                             │    │
│  ├──────────────────────────────────────────────────────────────────────────────┤    │
│  │                                                                               │    │
│  │  ┌──────────────────────┐          ┌──────────────────────┐                   │    │
│  │  │       users          │ 1:1      │    user_traffic      │                   │    │
│  │  │  (tId PK BIGINT)     │◄────────►│  (tId PK = users.tId)│                   │    │
│  │  │  uuid UNIQUE UUID    │          │  usedTrafficBytes    │                   │    │
│  │  │  shortUuid UNIQUE    │          │  lifetimeUsedBytes   │                   │    │
│  │  │  username UNIQUE     │          │  onlineAt            │                   │    │
│  │  │  status VARCHAR(10)  │          │  lastConnectedNode   │                   │    │
│  │  │  trafficLimitBytes   │          │  firstConnectedAt    │                   │    │
│  │  │  trafficLimitStrategy│          └──────────────────────┘                   │    │
│  │  │  expireAt            │                                                     │    │
│  │  │  trojanPassword      │          ┌──────────────────────┐                   │    │
│  │  │  vlessUuid UUID      │ 1:N      │ hwid_user_devices    │                   │    │
│  │  │  ssPassword          │◄─────────│  (hwid+userUuid PK)  │                   │    │
│  │  │  telegramId          │          │  platform, osVersion │                   │    │
│  │  │  email               │          │  deviceModel, ua     │                   │    │
│  │  │  hwidDeviceLimit     │          └──────────────────────┘                   │    │
│  │  │  externalSquadUuid FK│                                                     │    │
│  │  │  tag                 │          ┌──────────────────────┐                   │    │
│  │  │  lastTriggeredThreshold│        │      user_meta       │                   │    │
│  │  │  createdAt, updatedAt│ 1:1      │  (userId PK)         │                   │    │
│  │  └──────┬───────────────┘◄─────────│  metadata JSON       │                   │    │
│  │         │                           └──────────────────────┘                   │    │
│  │         │ 1:N                                                                   │    │
│  │         ├──────────────────────────────────────────────────┐                    │    │
│  │         │ 1:N                                               │                    │    │
│  │  ┌──────┴──────────────────┐                    ┌──────────┴──────────┐        │    │
│  │  │ internal_squad_members  │                    │ torrent_blocker_    │        │    │
│  │  │ (squadUuid+userId PK)   │                    │ reports             │        │    │
│  │  └──────┬──────────────────┘                    │ (id PK BIGINT)      │        │    │
│  │         │                                       │ userId FK, nodeId FK│        │    │
│  │         │                                       │ report JSON         │        │    │
│  │  ┌──────┴──────────────┐                        └─────────────────────┘        │    │
│  │  │  internal_squads    │                                                         │    │
│  │  │  (uuid PK)          │          ┌──────────────────────┐                       │    │
│  │  │  name UNIQUE        │ 1:N      │internal_squad_inbounds│                       │    │
│  │  └──────┬──────────────┘◄─────────│ (squadUuid+inbound PK)│                       │    │
│  │         │                           └──────────┬───────────┘                       │    │
│  │         │ 1:N                                   │                                   │    │
│  │  ┌──────┴──────────────────────┐               │                                   │    │
│  │  │internal_squad_host_exclusions│              │                                   │    │
│  │  │ (hostUuid+squadUuid PK)     │               │                                   │    │
│  │  └─────────────────────────────┘               │                                   │    │
│  │                                                ▼                                   │    │
│  └───────────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  ┌──────────────────────────────────────────────────────────────────────────────┐    │
│  │                          NODE MANAGEMENT SUBSYSTEM                             │    │
│  ├──────────────────────────────────────────────────────────────────────────────┤    │
│  │                                                                               │    │
│  │  ┌──────────────────────────┐                                                 │    │
│  │  │         nodes            │                                                 │    │
│  │  │  (uuid PK, id UNIQUE)    │                                                 │    │
│  │  │  name UNIQUE             │                                                 │    │
│  │  │  address UNIQUE          │                                                 │    │
│  │  │  port                    │                                                 │    │
│  │  │  isConnected BOOL        │                                                 │    │
│  │  │  isDisabled BOOL         │                                                 │    │
│  │  │  consumptionMultiplier   │                                                 │    │
│  │  │  trafficLimitBytes       │                                                 │    │
│  │  │  trafficUsedBytes        │                                                 │    │
│  │  │  trafficResetDay         │                                                 │    │
│  │  │  activeConfigProfileUuid │                                                 │    │
│  │  │  activePluginUuid        │                                                 │    │
│  │  │  providerUuid            │                                                 │    │
│  │  │  countryCode             │                                                 │    │
│  │  │  tags VARCHAR[]          │                                                 │    │
│  │  │  viewPosition            │                                                 │    │
│  │  └───────┬──────────────────┘                                                 │    │
│  │          │                                                                    │    │
│  │          │ 1:N                                                               │    │
│  │          ├───────────────────────────────┐                                    │    │
│  │          │ 1:N                           │ 1:N                                │    │
│  │  ┌───────┴──────────────────┐  ┌─────────┴──────────────────┐                │    │
│  │  │ nodes_usage_history      │  │ nodes_user_usage_history   │                │    │
│  │  │ (nodeUuid+createdAt PK)  │  │ (nodeId+createdAt+userId)  │                │    │
│  │  │ downloadBytes            │  │ totalBytes                 │                │    │
│  │  │ uploadBytes              │  └────────────────────────────┘                │    │
│  │  │ totalBytes               │                                                │    │
│  │  │ createdAt (date_trunc hr)│  ┌────────────────────────────┐                │    │
│  │  └──────────────────────────┘  │ nodes_traffic_usage_history│                │    │
│  │                                │ (id PK BIGINT)             │                │    │
│  │  ┌──────────────────────────┐  │ nodeUuid FK                │                │    │
│  │  │  config_profiles         │  │ trafficBytes               │                │    │
│  │  │  (uuid PK)               │  │ resetAt                    │                │    │
│  │  │  name UNIQUE             │  └────────────────────────────┘                │    │
│  │  │  config JSON             │                                                │    │
│  │  └──────┬───────────────────┘                                                │    │
│  │         │ 1:N                                                               │    │
│  │  ┌──────┴──────────────────────┐                                             │    │
│  │  │ config_profile_inbounds     │                                             │    │
│  │  │ (uuid PK)                   │                                             │    │
│  │  │ profileUuid FK              │                                             │    │
│  │  │ tag UNIQUE                  │                                             │    │
│  │  │ type, network, security     │                                             │    │
│  │  │ port, rawInbound JSON       │                                             │    │
│  │  └──────┬──────────────────────┘                                             │    │
│  │         │ 1:N (M:N через)                                                   │    │
│  │  ┌──────┴────────────────────────────────┐                                   │    │
│  │  │ config_profile_inbounds_to_nodes      │                                   │    │
│  │  │ (inboundUuid+nodeUuid PK)             │                                   │    │
│  │  └───────────────────────────────────────┘                                   │    │
│  │                                                                               │    │
│  │  ┌──────────────────────────┐                                                 │    │
│  │  │      node_meta           │                                                 │    │
│  │  │  (nodeId PK)             │                                                 │    │
│  │  │  metadata JSON           │                                                 │    │
│  │  └──────────────────────────┘                                                 │    │
│  │                                                                               │    │
│  │  ┌──────────────────────────┐                                                 │    │
│  │  │      node_plugin         │                                                 │    │
│  │  │  (uuid PK)               │                                                 │    │
│  │  │  name                    │                                                 │    │
│  │  │  pluginConfig JSON       │                                                 │    │
│  │  └──────────────────────────┘                                                 │    │
│  │                                                                               │    │
│  └──────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  ┌──────────────────────────────────────────────────────────────────────────────┐    │
│  │                          HOST / INBOUND SUBSYSTEM                              │    │
│  ├──────────────────────────────────────────────────────────────────────────────┤    │
│  │                                                                               │    │
│  │  ┌──────────────────────────────┐                                             │    │
│  │  │           hosts              │                                             │    │
│  │  │  (uuid PK)                   │                                             │    │
│  │  │  remark VARCHAR(50)          │                                             │    │
│  │  │  address, port               │                                             │    │
│  │  │  path, sni, host             │                                             │    │
│  │  │  alpn, fingerprint           │                                             │    │
│  │  │  securityLayer               │                                             │    │
│  │  │  xHttpExtraParams JSON       │                                             │    │
│  │  │  muxParams JSON              │                                             │    │
│  │  │  sockoptParams JSON          │                                             │    │
│  │  │  finalMask JSON              │                                             │    │
│  │  │  isDisabled BOOL             │                                             │    │
│  │  │  allowInsecure BOOL          │                                             │    │
│  │  │  shuffleHost BOOL            │                                             │    │
│  │  │  mihomoX25519 BOOL           │                                             │    │
│  │  │  keepSniBlank BOOL           │                                             │    │
│  │  │  isHidden BOOL               │                                             │    │
│  │  │  overrideSniFromAddress BOOL │                                             │    │
│  │  │  xrayJsonTemplate FK         │                                             │    │
│  │  │  configProfile FK            │                                             │    │
│  │  │  configProfileInbound FK     │                                             │    │
│  │  │  vlessRouteId                │                                             │    │
│  │  │  excludeFromSubTypes[]       │                                             │    │
│  │  └──────┬───────────────────────┘                                             │    │
│  │         │ M:N                                                               │    │
│  │  ┌──────┴────────────────┐                                                    │    │
│  │  │   hosts_to_nodes      │                                                    │    │
│  │  │  (hostUuid+nodeUuid)  │                                                    │    │
│  │  └───────────────────────┘                                                    │    │
│  │                                                                               │    │
│  └──────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  ┌──────────────────────────────────────────────────────────────────────────────┐    │
│  │                        SUBSCRIPTION SUBSYSTEM                                  │    │
│  ├──────────────────────────────────────────────────────────────────────────────┤    │
│  │                                                                               │    │
│  │  ┌───────────────────────────┐   ┌───────────────────────────┐               │    │
│  │  │  subscription_templates   │   │  subscription_settings     │               │    │
│  │  │  (uuid PK)                │   │  (uuid PK)                │               │    │
│  │  │  name, templateType       │   │  profileTitle             │               │    │
│  │  │  templateYaml TEXT        │   │  supportLink              │               │    │
│  │  │  templateJson JSON        │   │  profileUpdateInterval    │               │    │
│  │  │  UNIQUE(type+name)        │   │  hwidSettings JSON        │               │    │
│  │  └───────────────────────────┘   │  responseRules JSON       │               │    │
│  │                                  │  customRemarks JSON       │               │    │
│  │  ┌───────────────────────────┐   │  customResponseHeaders    │               │    │
│  │  │  subscription_page_config │   │  happAnnounce, happRouting│               │    │
│  │  │  (uuid PK)                │   │  randomizeHosts BOOL      │               │    │
│  │  │  name UNIQUE              │   └───────────────────────────┘               │    │
│  │  │  config JSON              │                                               │    │
│  │  └───────────────────────────┘   ┌───────────────────────────┐               │    │
│  │                                  │user_subscription_request  │               │    │
│  │  ┌───────────────────────────┐   │       _history            │               │    │
│  │  │ config_profile_snippets   │   │  (id PK BIGINT)          │               │    │
│  │  │  (name PK)                │   │  userUuid FK              │               │    │
│  │  │  snippet JSON             │   │  requestIp, userAgent     │               │    │
│  │  └───────────────────────────┘   │  requestAt                │               │    │
│  │                                  └───────────────────────────┘               │    │
│  └──────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  ┌──────────────────────────────────────────────────────────────────────────────┐    │
│  │                        EXTERNAL SQUADS SUBSYSTEM                               │    │
│  ├──────────────────────────────────────────────────────────────────────────────┤    │
│  │                                                                               │    │
│  │  ┌──────────────────────────┐   ┌──────────────────────────┐                 │    │
│  │  │    external_squads       │   │ external_squads_templates│                 │    │
│  │  │  (uuid PK)               │   │ (squadUuid+type PK)      │                 │    │
│  │  │  name UNIQUE             │◄──│ templateUuid FK          │                 │    │
│  │  │  subscriptionSettings JSON│  └──────────────────────────┘                 │    │
│  │  │  hostOverrides JSON      │                                                │    │
│  │  │  responseHeaders JSON    │                                                │    │
│  │  │  hwidSettings JSON       │                                                │    │
│  │  │  customRemarks JSON      │                                                │    │
│  │  │  subpageConfigUuid FK    │                                                │    │
│  │  └──────────────────────────┘                                                │    │
│  │                                                                               │    │
│  └──────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  ┌──────────────────────────────────────────────────────────────────────────────┐    │
│  │                        INFRA BILLING SUBSYSTEM                                 │    │
│  ├──────────────────────────────────────────────────────────────────────────────┤    │
│  │                                                                               │    │
│  │  ┌──────────────────────────┐   ┌──────────────────────────┐                 │    │
│  │  │    infra_providers       │   │   infra_billing_nodes    │                 │    │
│  │  │  (uuid PK)               │◄──│  (uuid PK)               │                 │    │
│  │  │  name UNIQUE             │   │  nodeUuid FK             │                 │    │
│  │  │  faviconLink             │   │  providerUuid FK         │                 │    │
│  │  │  loginUrl                │   │  nextBillingAt           │                 │    │
│  │  └──────────────────────────┘   │  UNIQUE(node+provider)   │                 │    │
│  │                                 └──────────────────────────┘                 │    │
│  │  ┌──────────────────────────────────────┐                                    │    │
│  │  │       infra_billing_history          │                                    │    │
│  │  │  (uuid PK)                           │                                    │    │
│  │  │  providerUuid FK                     │                                    │    │
│  │  │  amount FLOAT                        │                                    │    │
│  │  │  billedAt                            │                                    │    │
│  │  └──────────────────────────────────────┘                                    │    │
│  │                                                                               │    │
│  └──────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. COMPLETE TABLE CATALOG (36 Tables)

### 3.1 Core Configuration — 1 table

#### `remnawave_settings` (remnawave_settings)
**Назначение:** Глобальные настройки панели. Singleton-таблица (одна строка).

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `id` | INT | PK, @default(1) | Всегда id=1 (singleton) |
| `passkeySettings` | JSON? | | Конфигурация Passkey/WebAuthn |
| `oauth2Settings` | JSON? | | OAuth2 провайдеры (GitHub, Telegram, Yandex...) |
| `passwordSettings` | JSON? | | Настройки парольной аутентификации |
| `brandingSettings` | JSON? | | Брендинг панели |

---

### 3.2 Authentication & Authorization — 3 tables

#### `admin` (admin)
**Назначение:** Администраторы панели.

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `uuid` | UUID | PK, gen_random_uuid() | |
| `username` | VARCHAR | UNIQUE | |
| `passwordHash` | VARCHAR | | HMAC+scrypt хэш |
| `role` | VARCHAR | | ADMIN, etc. |
| `createdAt` | TIMESTAMP | DEFAULT now() | |
| `updatedAt` | TIMESTAMP | @updatedAt | |

**Отношения:** `admin` 1→N `passkeys`

#### `passkeys` (passkeys)
**Назначение:** WebAuthn/FIDO2 passkey credentials для админов.

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `id` | VARCHAR | PK | Base64URL credential ID |
| `adminUuid` | UUID | FK → admin.uuid, CASCADE, INDEX | |
| `publicKey` | BYTES | | RAW public key bytes |
| `counter` | BIGINT | | Signature counter |
| `deviceType` | VARCHAR | | 'singleDevice' | 'multiDevice' |
| `backedUp` | BOOLEAN | | |
| `transports` | VARCHAR? | | CSV: usb,nfc,ble,internal |
| `passkeyProvider` | VARCHAR? | | |
| `createdAt` | TIMESTAMP | DEFAULT now() | |

**Индексы:** `@@index([id])`, `@@index([adminUuid])`

#### `api_tokens` (api_tokens)
**Назначение:** API токены для программного доступа.

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `uuid` | UUID | PK, gen_random_uuid() | |
| `token` | VARCHAR | UNIQUE | Bearer token value |
| `tokenName` | VARCHAR | | |
| `createdAt` | TIMESTAMP | DEFAULT now() | |
| `updatedAt` | TIMESTAMP | @updatedAt | |

---

### 3.3 Users — 3 tables

#### `users` (users)
**Назначение:** VPN-пользователи. Центральная таблица системы.

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `tId` | BIGINT | PK, @autoincrement | Surrogate key |
| `uuid` | UUID | UNIQUE, gen_random_uuid() | Публичный идентификатор |
| `shortUuid` | VARCHAR | UNIQUE | Короткий UUID для URL подписок |
| `username` | VARCHAR | UNIQUE | Имя пользователя |
| `status` | VARCHAR(10) | DEFAULT 'ACTIVE' | ACTIVE/DISABLED/LIMITED/EXPIRED |
| `trafficLimitBytes` | BIGINT | DEFAULT 0 | Лимит трафика |
| `trafficLimitStrategy` | VARCHAR | DEFAULT 'NO_RESET' | NO_RESET/DAY/WEEK/MONTH/MONTH_ROLLING |
| `expireAt` | DATETIME | | Дата истечения |
| `lastTrafficResetAt` | DATETIME? | | Последний сброс трафика |
| `subRevokedAt` | DATETIME? | | Время отзыва подписки |
| `trojanPassword` | VARCHAR | | Пароль Trojan |
| `vlessUuid` | UUID | | UUID VLESS |
| `ssPassword` | VARCHAR | | Пароль Shadowsocks |
| `description` | VARCHAR? | | Описание |
| `tag` | VARCHAR? | | Тег |
| `telegramId` | BIGINT? | | Telegram ID |
| `email` | VARCHAR? | | Email |
| `hwidDeviceLimit` | INT? | | Лимит HWID-устройств |
| `externalSquadUuid` | UUID? | FK → external_squads.uuid, SET NULL | Внешняя группа |
| `lastTriggeredThreshold` | INT | DEFAULT 0 | Последний порог для уведомлений |
| `createdAt` | TIMESTAMP | DEFAULT now() | |
| `updatedAt` | TIMESTAMP | @updatedAt | |

**Отношения:**
- `users` 1→1 `user_traffic` (CASCADE)
- `users` 1→N `hwid_user_devices` (CASCADE)
- `users` 1→N `internal_squad_members` (CASCADE)
- `users` 1→N `user_subscription_request_history` (CASCADE)
- `users` 1→1 `user_meta` (CASCADE)
- `users` 1→N `torrent_blocker_reports` (CASCADE)
- `users` N→1 `external_squads` (SET NULL)

#### `user_traffic` (user_traffic)
**Назначение:** Статистика трафика пользователя (1:1 с users).

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `tId` | BIGINT | PK, FK → users.tId, CASCADE | |
| `usedTrafficBytes` | BIGINT | DEFAULT 0 | Использовано в текущем периоде |
| `lifetimeUsedTrafficBytes` | BIGINT | DEFAULT 0 | Использовано за всё время |
| `onlineAt` | DATETIME? | | Последний онлайн |
| `lastConnectedNodeUuid` | UUID? | FK → nodes.uuid, SET NULL | Последняя нода |
| `firstConnectedAt` | DATETIME? | | Первое подключение |

#### `hwid_user_devices` (hwid_user_devices)
**Назначение:** Отслеживание устройств по Hardware ID.

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `hwid` | VARCHAR | PK (composite) | Hardware ID |
| `userUuid` | VARCHAR | PK (composite), FK → users.uuid, CASCADE | |
| `platform` | VARCHAR? | | ОС |
| `osVersion` | VARCHAR? | | Версия ОС |
| `deviceModel` | VARCHAR? | | Модель устройства |
| `userAgent` | VARCHAR? | | User-Agent |
| `createdAt` | TIMESTAMP | DEFAULT now() | |
| `updatedAt` | TIMESTAMP | @updatedAt | |

**Первичный ключ:** `@@id([hwid, userUuid])`

---

### 3.4 Nodes — 4 tables

#### `nodes` (nodes)
**Назначение:** Прокси-серверы (ноды).

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `id` | BIGINT | UNIQUE, @autoincrement | Surrogate key |
| `uuid` | UUID | PK, gen_random_uuid() | |
| `name` | VARCHAR | UNIQUE | Имя ноды |
| `address` | VARCHAR | UNIQUE | IP/домен |
| `port` | INT? | | Порт |
| `activeConfigProfileUuid` | UUID? | FK → config_profiles.uuid, SET NULL | Активный профиль |
| `activePluginUuid` | UUID? | FK → node_plugin.uuid, SET NULL | Активный плагин |
| `isConnected` | BOOLEAN | DEFAULT false | Онлайн статус |
| `isConnecting` | BOOLEAN | DEFAULT false | В процессе подключения |
| `isDisabled` | BOOLEAN | DEFAULT false | Отключена |
| `lastStatusChange` | DATETIME? | | Время изменения статуса |
| `lastStatusMessage` | VARCHAR? | | Сообщение статуса |
| `consumptionMultiplier` | BIGINT | DEFAULT 1000000000 | Множитель трафика |
| `isTrafficTrackingActive` | BOOLEAN | DEFAULT false | Отслеживание трафика |
| `trafficResetDay` | INT? | DEFAULT 1 | День сброса |
| `trafficLimitBytes` | BIGINT? | DEFAULT 0 | Лимит трафика ноды |
| `trafficUsedBytes` | BIGINT? | DEFAULT 0 | Использовано трафика |
| `notifyPercent` | INT? | DEFAULT 0 | Порог уведомлений |
| `providerUuid` | UUID? | FK → infra_providers.uuid, SET NULL | Провайдер |
| `viewPosition` | INT | @autoincrement | Порядок отображения |
| `countryCode` | VARCHAR | DEFAULT 'XX' | Код страны |
| `tags` | VARCHAR[] | DEFAULT [] | Теги |
| `createdAt` | TIMESTAMP | DEFAULT now() | |
| `updatedAt` | TIMESTAMP | @updatedAt | |

**Индексы:** `@@index([id])`

**Отношения:** 1→N (usage histories, billing, hosts), N→1 (config profile, plugin, provider), 1→N (connected users via UserTraffic)

#### `nodes_usage_history` (nodes_usage_history)
**Назначение:** Почасовое использование трафика каждой ноды.

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `nodeUuid` | UUID | PK (composite), FK → nodes.uuid, CASCADE | |
| `downloadBytes` | BIGINT | | Входящий трафик |
| `uploadBytes` | BIGINT | | Исходящий трафик |
| `totalBytes` | BIGINT | | Всего |
| `createdAt` | DATE | PK (composite), date_trunc('hour', now()) | |
| `updatedAt` | TIMESTAMP | @updatedAt | |

**Первичный ключ:** `@@id([nodeUuid, createdAt])`
**Индексы:** `@@index([nodeUuid, createdAt(sort: Desc)])`

#### `nodes_user_usage_history` (nodes_user_usage_history)
**Назначение:** Использование трафика пользователем на конкретной ноде (за день).

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `nodeId` | BIGINT | PK (composite), FK → nodes.id, CASCADE | |
| `userId` | BIGINT | PK (composite), FK → users.tId, CASCADE | |
| `totalBytes` | BIGINT | | Трафик за день |
| `createdAt` | DATE | PK (composite), DEFAULT CURRENT_DATE | |
| `updatedAt` | TIMESTAMP | @updatedAt | |

**Первичный ключ:** `@@id([nodeId, createdAt, userId])`

#### `nodes_traffic_usage_history` (nodes_traffic_usage_history)
**Назначение:** История сбросов трафика нод.

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `id` | BIGINT | PK, @autoincrement | |
| `nodeUuid` | UUID | FK → nodes.uuid, CASCADE | |
| `trafficBytes` | BIGINT | | Заархивированный трафик |
| `resetAt` | DATETIME | DEFAULT now() | Время сброса |

---

### 3.5 Hosts — 2 tables

#### `hosts` (hosts)
**Назначение:** Конфигурация inbound-подключений (хосты), которые раздаются клиентам.

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `uuid` | UUID | PK, gen_random_uuid() | |
| `viewPosition` | INT | @autoincrement | Порядок |
| `remark` | VARCHAR(50) | | Отображаемое имя |
| `address` | VARCHAR | | Адрес сервера |
| `port` | INT | | Порт |
| `path` | VARCHAR? | | Путь (WebSocket/gRPC) |
| `sni` | VARCHAR? | | Server Name Indication |
| `host` | VARCHAR? | | HTTP Host header |
| `alpn` | VARCHAR? | | ALPN (h2, http/1.1) |
| `fingerprint` | VARCHAR? | | TLS fingerprint (chrome, firefox, ...) |
| `securityLayer` | VARCHAR | DEFAULT 'DEFAULT' | DEFAULT/TLS/NONE |
| `xHttpExtraParams` | JSON? | | XHTTP параметры |
| `muxParams` | JSON? | | Multiplex параметры |
| `sockoptParams` | JSON? | | Socket options |
| `finalMask` | JSON? | | Конечная маска |
| `isDisabled` | BOOLEAN | DEFAULT false | |
| `serverDescription` | VARCHAR(30)? | | Описание сервера |
| `vlessRouteId` | INT? | | VLESS route ID |
| `allowInsecure` | BOOLEAN | DEFAULT false | Разрешить небезопасные сертификаты |
| `shuffleHost` | BOOLEAN | DEFAULT false | Перемешивать хост |
| `mihomoX25519` | BOOLEAN | DEFAULT false | Mihomo X25519 |
| `xrayJsonTemplateUuid` | UUID? | FK → subscription_templates.uuid, SET NULL | |
| `keepSniBlank` | BOOLEAN | DEFAULT false | |
| `excludeFromSubscriptionTypes` | VARCHAR[] | DEFAULT [] | Скрыть из типов подписок |
| `tag` | VARCHAR? | | Тег |
| `isHidden` | BOOLEAN | DEFAULT false | Скрытый |
| `overrideSniFromAddress` | BOOLEAN | DEFAULT false | SNI = address |
| `configProfileUuid` | UUID? | FK → config_profiles.uuid, SET NULL | |
| `configProfileInboundUuid` | UUID? | FK → config_profile_inbounds.uuid, SET NULL | |

**Отношения:**
- `hosts` M→N `nodes` (через hosts_to_nodes)
- `hosts` 1→N `internal_squad_host_exclusions`

#### `hosts_to_nodes` (hosts_to_nodes)
**Назначение:** Many-to-Many связь хостов и нод.

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `hostUuid` | UUID | PK (composite), FK → hosts.uuid, CASCADE | |
| `nodeUuid` | UUID | PK (composite), FK → nodes.uuid, CASCADE | |

**Первичный ключ:** `@@id([hostUuid, nodeUuid])`

---

### 3.6 Config Profiles — 4 tables

#### `config_profiles` (config_profiles)
**Назначение:** Профили конфигурации Xray для нод.

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `uuid` | UUID | PK, gen_random_uuid() | |
| `viewPosition` | INT | @autoincrement | |
| `name` | VARCHAR | UNIQUE | |
| `config` | JSON | | Полный Xray JSON конфиг |
| `createdAt` | TIMESTAMP | DEFAULT now() | |
| `updatedAt` | TIMESTAMP | @updatedAt | |

**Отношения:** 1→N `nodes`, 1→N `config_profile_inbounds`, 1→N `hosts`

#### `config_profile_inbounds` (config_profile_inbounds)
**Назначение:** Inbound-ы внутри конфигурационных профилей.

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `uuid` | UUID | PK, gen_random_uuid() | |
| `profileUuid` | UUID | FK → config_profiles.uuid, CASCADE, INDEX | |
| `tag` | VARCHAR | UNIQUE | Inbound tag |
| `type` | VARCHAR | | Тип (trojan, vless, ss, ...) |
| `network` | VARCHAR? | | Сеть (tcp, ws, grpc, xhttp) |
| `security` | VARCHAR? | | Безопасность (tls, reality) |
| `port` | INT? | | Порт |
| `rawInbound` | JSON? | | Полный inbound JSON |

**Отношения:** 1→N `hosts`, 1→N `config_profile_inbounds_to_nodes`, 1→N `internal_squad_inbounds`

#### `config_profile_inbounds_to_nodes` (config_profile_inbounds_to_nodes)
**Назначение:** M:N связь inbound'ов и нод.

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `configProfileInboundUuid` | UUID | PK (composite), FK → config_profile_inbounds.uuid, CASCADE | |
| `nodeUuid` | UUID | PK (composite), FK → nodes.uuid, CASCADE | |

#### `config_profile_snippets` (config_profile_snippets)
**Назначение:** Переиспользуемые JSON-сниппеты для профилей.

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `name` | VARCHAR(255) | PK | Имя сниппета |
| `snippet` | JSON | | JSON content |
| `createdAt` | TIMESTAMP | DEFAULT now() | |

---

### 3.7 Internal Squads — 3 tables

#### `internal_squads` (internal_squads)
**Назначение:** Внутренние группы пользователей.

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `uuid` | UUID | PK, gen_random_uuid() | |
| `viewPosition` | INT | @autoincrement | |
| `name` | VARCHAR | UNIQUE | |
| `createdAt` | TIMESTAMP | DEFAULT now() | |
| `updatedAt` | TIMESTAMP | @updatedAt | |

**Отношения:** 1→N `internal_squad_members`, 1→N `internal_squad_inbounds`, 1→N `internal_squad_host_exclusions`

#### `internal_squad_members` (internal_squad_members)
| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `internalSquadUuid` | UUID | PK (composite), FK → internal_squads.uuid, CASCADE, INDEX | |
| `userId` | BIGINT | PK (composite), FK → users.tId, CASCADE, INDEX | |

#### `internal_squad_inbounds` (internal_squad_inbounds)
| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `internalSquadUuid` | UUID | PK (composite), FK → internal_squads.uuid, CASCADE | |
| `inboundUuid` | UUID | PK (composite), FK → config_profile_inbounds.uuid, CASCADE | |

#### `internal_squad_host_exclusions` (internal_squad_host_exclusions)
| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `hostUuid` | UUID | PK (composite), FK → hosts.uuid, CASCADE | |
| `squadUuid` | UUID | PK (composite), FK → internal_squads.uuid, CASCADE | |

---

### 3.8 External Squads — 2 tables

#### `external_squads` (external_squads)
**Назначение:** Внешние группы клиентов с собственными настройками и брендингом (White Label).

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `uuid` | UUID | PK, gen_random_uuid() | |
| `viewPosition` | INT | @autoincrement | |
| `name` | VARCHAR(30) | UNIQUE | |
| `subscriptionSettings` | JSON? | | Оверрайд настроек подписки |
| `hostOverrides` | JSON? | | Оверрайд хостов |
| `responseHeaders` | JSON? | | Кастомные заголовки ответа |
| `hwidSettings` | JSON? | | HWID настройки |
| `customRemarks` | JSON? | | Кастомные ремарки |
| `subpageConfigUuid` | UUID? | FK → subscription_page_config.uuid, SET NULL | |
| `createdAt` | TIMESTAMP | DEFAULT now() | |
| `updatedAt` | TIMESTAMP | @updatedAt | |

**Отношения:** 1→N `external_squads_templates`, 1→N `users`

#### `external_squads_templates` (external_squads_templates)
| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `externalSquadUuid` | UUID | PK (composite), FK → external_squads.uuid, CASCADE | |
| `templateUuid` | UUID | FK → subscription_templates.uuid, CASCADE | |
| `templateType` | VARCHAR | PK (composite) | XRAY_JSON, MIHOMO, STASH, CLASH, SINGBOX |

---

### 3.9 Subscriptions — 3 tables

#### `subscription_templates` (subscription_templates)
**Назначение:** Шаблоны конфигураций подписки.

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `uuid` | UUID | PK, gen_random_uuid() | |
| `viewPosition` | INT | @autoincrement | |
| `name` | VARCHAR(255) | DEFAULT 'Default' | |
| `templateType` | VARCHAR | UNIQUE (with name) | XRAY_JSON/MIHOMO/CLASH/SINGBOX/STASH |
| `templateYaml` | TEXT? | | YAML шаблон |
| `templateJson` | JSON? | | JSON шаблон |
| `createdAt` | TIMESTAMP | DEFAULT now() | |
| `updatedAt` | TIMESTAMP | @updatedAt | |

**Уникальное ограничение:** `@@unique([templateType, name])`

#### `subscription_settings` (subscription_settings)
**Назначение:** Глобальные настройки профиля подписки.

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `uuid` | UUID | PK, gen_random_uuid() | |
| `profileTitle` | VARCHAR | | Заголовок профиля |
| `supportLink` | VARCHAR | | Ссылка поддержки |
| `profileUpdateInterval` | INT | | Интервал обновления (часы) |
| `isProfileWebpageUrlEnabled` | BOOLEAN | DEFAULT true | Веб-страница профиля |
| `serveJsonAtBaseSubscription` | BOOLEAN | DEFAULT false | JSON на базовом URL |
| `happAnnounce` | VARCHAR? | | Happ announce |
| `happRouting` | VARCHAR? | | Happ routing |
| `isShowCustomRemarks` | BOOLEAN | DEFAULT true | Показывать ремарки |
| `customRemarks` | JSON | | Кастомные ремарки |
| `customResponseHeaders` | JSON? | | Кастомные заголовки |
| `randomizeHosts` | BOOLEAN | DEFAULT false | Случайный порядок хостов |
| `responseRules` | JSON? | | Правила ответа |
| `hwidSettings` | JSON? | | Настройки HWID |
| `createdAt` | TIMESTAMP | DEFAULT now() | |
| `updatedAt` | TIMESTAMP | @updatedAt | |

#### `subscription_page_config` (subscription_page_config)
**Назначение:** Конфигурация веб-страницы подписки (внешний вид).

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `uuid` | UUID | PK, gen_random_uuid() | |
| `viewPosition` | INT | @autoincrement | |
| `name` | VARCHAR(30) | UNIQUE | |
| `config` | JSON | | Полный конфиг страницы |
| `createdAt` | TIMESTAMP | DEFAULT now() | |
| `updatedAt` | TIMESTAMP | @updatedAt | |

#### `user_subscription_request_history` (user_subscription_request_history)
**Назначение:** Аудит запросов подписки.

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `id` | BIGINT | PK, @autoincrement | |
| `userUuid` | VARCHAR | FK → users.uuid, CASCADE, INDEX | |
| `requestIp` | VARCHAR? | | IP запроса |
| `userAgent` | VARCHAR? | | User-Agent |
| `requestAt` | DATETIME | DEFAULT now(), INDEX | Время запроса |

**Индексы:** `@@index([userUuid])`, `@@index([requestAt(sort: Asc)])`

---

### 3.10 Node Plugins — 1 table

#### `node_plugin` (node_plugin)
**Назначение:** Определения плагинов для нод (торрент-блокер, фильтры).

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `uuid` | UUID | PK, gen_random_uuid() | |
| `viewPosition` | INT | @autoincrement | |
| `name` | VARCHAR(255) | | |
| `pluginConfig` | JSON | | ZOD-валидируемый конфиг |
| `createdAt` | TIMESTAMP | DEFAULT now() | |
| `updatedAt` | TIMESTAMP | @updatedAt | |

---

### 3.11 Infrastructure Billing — 3 tables

#### `infra_providers` (infra_providers)
**Назначение:** Хостинг-провайдеры.

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `uuid` | UUID | PK, gen_random_uuid() | |
| `name` | VARCHAR | UNIQUE | |
| `faviconLink` | VARCHAR? | | Ссылка на favicon |
| `loginUrl` | VARCHAR? | | URL панели управления |
| `createdAt` | TIMESTAMP | DEFAULT now() | |
| `updatedAt` | TIMESTAMP | @updatedAt | |

#### `infra_billing_nodes` (infra_billing_nodes)
| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `uuid` | UUID | PK, gen_random_uuid() | |
| `nodeUuid` | UUID | FK → nodes.uuid, CASCADE, UNIQUE with provider | |
| `providerUuid` | UUID | FK → infra_providers.uuid, CASCADE, UNIQUE with node | |
| `nextBillingAt` | DATETIME | INDEX | Дата следующего платежа |
| `createdAt` | TIMESTAMP | DEFAULT now() | |
| `updatedAt` | TIMESTAMP | @updatedAt | |

**Индексы:** `@@unique([nodeUuid, providerUuid])`, `@@index([nextBillingAt])`

#### `infra_billing_history` (infra_billing_history)
| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `uuid` | UUID | PK, gen_random_uuid() | |
| `providerUuid` | UUID | FK → infra_providers.uuid, CASCADE | |
| `amount` | FLOAT | | Сумма |
| `billedAt` | DATETIME | | Дата платежа |

---

### 3.12 Key Management — 1 table

#### `keygen` (keygen)
**Назначение:** X25519 ключи и сертификаты для подписок.

| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `uuid` | UUID | PK, gen_random_uuid() | |
| `privKey` | VARCHAR | | Приватный ключ X25519 |
| `pubKey` | VARCHAR | | Публичный ключ X25519 |
| `caCert` | VARCHAR? | | CA сертификат |
| `caKey` | VARCHAR? | | CA приватный ключ |
| `clientCert` | VARCHAR? | | Клиентский сертификат |
| `clientKey` | VARCHAR? | | Клиентский приватный ключ |
| `createdAt` | TIMESTAMP | DEFAULT now() | |
| `updatedAt` | TIMESTAMP | @updatedAt | |

---

### 3.13 Metadata — 2 tables

#### `user_meta` (user_meta)
| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `userId` | BIGINT | PK, FK → users.tId, CASCADE | |
| `metadata` | JSON | | Произвольные метаданные |

#### `node_meta` (node_meta)
| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `nodeId` | BIGINT | PK, FK → nodes.id, CASCADE | |
| `metadata` | JSON | | Произвольные метаданные |

---

### 3.14 Torrent Blocker — 1 table

#### `torrent_blocker_reports` (torrent_blocker_reports)
| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `id` | BIGINT | PK, @autoincrement | |
| `userId` | BIGINT | FK → users.tId, CASCADE | |
| `nodeId` | BIGINT | FK → nodes.id, CASCADE | |
| `report` | JSON | | Данные детекта |
| `createdAt` | TIMESTAMP | DEFAULT now() | |

---

## 4. INDEX INVENTORY

### 4.1 Primary Keys

| Type | Tables |
|------|--------|
| **UUID (gen_random_uuid)** | users, admin, api_tokens, keygen, nodes, hosts, config_profiles, config_profile_inbounds, internal_squads, external_squads, subscription_templates, subscription_settings, subscription_page_config, node_plugin, infra_providers, infra_billing_nodes, infra_billing_history |
| **BigInt @autoincrement** | users (tId), nodes (id), nodes_traffic_usage_history (id), user_subscription_request_history (id), torrent_blocker_reports (id) |
| **Composite** | hwid_user_devices, nodes_usage_history, nodes_user_usage_history, hosts_to_nodes, internal_squad_members, internal_squad_inbounds, internal_squad_host_exclusions, config_profile_inbounds_to_nodes, external_squads_templates |
| **Natural** | passkeys (id = credential ID), config_profile_snippets (name), user_meta (userId), node_meta (nodeId) |

### 4.2 Unique Constraints

| Table | Column(s) |
|-------|----------|
| `users` | `uuid`, `shortUuid`, `username` |
| `admin` | `username` |
| `api_tokens` | `token` |
| `nodes` | `name`, `address` |
| `nodes.id` | `id` (UNIQUE besides PK uuid) |
| `config_profiles` | `name` |
| `config_profile_inbounds` | `tag` |
| `internal_squads` | `name` |
| `external_squads` | `name` |
| `subscription_templates` | `[templateType, name]` |
| `subscription_page_config` | `name` |
| `infra_providers` | `name` |
| `infra_billing_nodes` | `[nodeUuid, providerUuid]` |

### 4.3 Secondary Indexes

| Table | Index | Type |
|-------|-------|------|
| `passkeys` | `[id]` | B-tree |
| `passkeys` | `[adminUuid]` | B-tree (FK) |
| `nodes` | `[id]` | B-tree |
| `nodes_usage_history` | `[nodeUuid, createdAt DESC]` | B-tree |
| `config_profile_inbounds` | `[profileUuid, uuid]` | B-tree (FK composite) |
| `internal_squad_members` | `[internalSquadUuid]` | B-tree |
| `internal_squad_members` | `[userId]` | B-tree |
| `infra_billing_nodes` | `[nextBillingAt]` | B-tree |
| `user_subscription_request_history` | `[userUuid]` | B-tree |
| `user_subscription_request_history` | `[requestAt ASC]` | B-tree |

---

## 5. RELATIONSHIP MAP (Foreign Keys)

```
┌──────────────────────────────────────────────────────────────────┐
│                      FOREIGN KEY RELATIONSHIPS                     │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  users.tId ──────────────► user_traffic.tId (1:1, CASCADE)       │
│  users.uuid ◄───────────── hwid_user_devices.userUuid (CASCADE)   │
│  users.uuid ◄───────────── user_subscription_request_history      │
│  users.tId ◄────────────── internal_squad_members.userId          │
│  users.tId ◄────────────── user_meta.userId (CASCADE)             │
│  users.tId ◄────────────── torrent_blocker_reports.userId         │
│  users.externalSquadUuid ─► external_squads.uuid (SET NULL)       │
│                                                                   │
│  user_traffic.lastConnectedNodeUuid ─► nodes.uuid (SET NULL)      │
│                                                                   │
│  admin.uuid ◄───────────── passkeys.adminUuid (CASCADE)           │
│                                                                   │
│  nodes.uuid ◄───────────── nodes_usage_history.nodeUuid           │
│  nodes.id ◄─────────────── nodes_user_usage_history.nodeId        │
│  nodes.uuid ◄───────────── nodes_traffic_usage_history.nodeUuid   │
│  nodes.uuid ◄───────────── hosts_to_nodes.nodeUuid                │
│  nodes.uuid ◄───────────── config_profile_inbounds_to_nodes       │
│  nodes.id ◄─────────────── node_meta.nodeId (CASCADE)             │
│  nodes.id ◄─────────────── torrent_blocker_reports.nodeId         │
│  nodes.activeConfigProfileUuid ─► config_profiles.uuid (SET NULL) │
│  nodes.activePluginUuid ─► node_plugin.uuid (SET NULL)            │
│  nodes.providerUuid ─► infra_providers.uuid (SET NULL)            │
│                                                                   │
│  hosts.uuid ◄───────────── hosts_to_nodes.hostUuid                │
│  hosts.uuid ◄───────────── internal_squad_host_exclusions         │
│  hosts.configProfileUuid ─► config_profiles.uuid (SET NULL)       │
│  hosts.configProfileInboundUuid ─► config_profile_inbounds.uuid   │
│  hosts.xrayJsonTemplateUuid ─► subscription_templates.uuid        │
│                                                                   │
│  config_profiles.uuid ◄──── config_profile_inbounds.profileUuid   │
│  config_profile_inbounds.uuid ◄─ config_profile_inbounds_to_nodes │
│  config_profile_inbounds.uuid ◄─ internal_squad_inbounds          │
│                                                                   │
│  internal_squads.uuid ◄────── internal_squad_members              │
│  internal_squads.uuid ◄────── internal_squad_inbounds             │
│  internal_squads.uuid ◄────── internal_squad_host_exclusions      │
│                                                                   │
│  external_squads.uuid ◄────── external_squads_templates           │
│  external_squads.uuid ◄────── users.externalSquadUuid             │
│  external_squads.subpageConfigUuid ─► subpage_config.uuid         │
│                                                                   │
│  external_squads_templates.templateUuid ─► sub_templates.uuid     │
│                                                                   │
│  infra_providers.uuid ◄────── infra_billing_nodes.providerUuid    │
│  infra_providers.uuid ◄────── infra_billing_history.providerUuid  │
│  infra_billing_nodes.nodeUuid ─► nodes.uuid                       │
│                                                                   │
│  subscription_page_config.uuid ◄── external_squads                │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

**Cascade Delete Chains:**
- `users` → `user_traffic`, `hwid_user_devices`, `internal_squad_members`, `user_subscription_request_history`, `user_meta`, `torrent_blocker_reports`
- `nodes` → `nodes_usage_history`, `nodes_user_usage_history`, `nodes_traffic_usage_history`, `hosts_to_nodes`, `config_profile_inbounds_to_nodes`, `node_meta`, `torrent_blocker_reports`, `infra_billing_nodes`
- `hosts` → `hosts_to_nodes`, `internal_squad_host_exclusions`
- `config_profiles` → `config_profile_inbounds` → `config_profile_inbounds_to_nodes`, `internal_squad_inbounds`, `hosts`
- `internal_squads` → `internal_squad_members`, `internal_squad_inbounds`, `internal_squad_host_exclusions`
- `external_squads` → `external_squads_templates`, `users.externalSquadUuid` (SET NULL)
- `admin` → `passkeys`
- `infra_providers` → `infra_billing_nodes`, `infra_billing_history`

---

## 6. DATA TYPES ANALYSIS

| Prisma Type | PostgreSQL Type | Использование |
|-------------|----------------|---------------|
| `String` | `text` / `varchar(N)` | Имена, URL, ключи |
| `Int` | `integer` | Порядок, порты, лимиты |
| `BigInt` | `bigint` | ID, байты трафика |
| `Float` | `double precision` | Только billing amount |
| `Boolean` | `boolean` | Флаги |
| `DateTime` | `timestamp` | Все даты |
| `Json` | `jsonb` | Конфигурации, настройки |
| `Bytes` | `bytea` | Только passkey publicKey |
| `String[]` | `text[]` | Массивы (tags, exclude types) |

**Особенности:**
- `BigInt` используется для всех счетчиков байт (трафик) — поддержка больших объёмов
- `Json` (JSONB) активно используется для гибких конфигураций (21 колонка типа JSON)
- `VARCHAR` с ограничениями длины только для `users.status(10)`, `hosts.remark(50)`, `hosts.serverDescription(30)`, `external_squads.name(30)`

---

## 7. JSON COLUMN INVENTORY

21 колонка типа JSON/JSONB в 11 таблицах:

| Table | JSON Columns | Purpose |
|-------|-------------|---------|
| `remnawave_settings` | 4 | passkey, oauth2, password, branding settings |
| `hosts` | 4 | xHttpExtraParams, muxParams, sockoptParams, finalMask |
| `subscription_settings` | 5 | customRemarks, customResponseHeaders, responseRules, hwidSettings, happ* |
| `subscription_templates` | 1 | templateJson |
| `subscription_page_config` | 1 | config |
| `config_profiles` | 1 | config |
| `config_profile_inbounds` | 1 | rawInbound |
| `config_profile_snippets` | 1 | snippet |
| `external_squads` | 5 | subscriptionSettings, hostOverrides, responseHeaders, hwidSettings, customRemarks |
| `node_plugin` | 1 | pluginConfig |
| `user_meta` / `node_meta` | 1 | metadata |
| `torrent_blocker_reports` | 1 | report |

---

## 8. MIGRATION HISTORY & EVOLUTION

### 8.1 Хронология (98 миграций за 18 месяцев)

| Период | Миграций | Ключевые изменения |
|--------|---------|-------------------|
| **2024-11** | 1 | Initial schema |
| **2024-12** | 4 | User online stats, node exclusions, updatedAt fixes |
| **2025-01** | 3 | View positions, country codes, descriptions |
| **2025-02** | 3 | Consumption multiplier, deprecated strategies removed |
| **2025-03** | 10 | **Major:** OAuth2, subscription templates, subscription settings, security layers, XHTTP, CA certs |
| **2025-04** | 5 | Custom remarks, HWID, response headers, PK changes |
| **2025-05** | 5 | User tags, indexes, first_connected_at, randomize hosts |
| **2025-06** | 6 | **Major:** Squads + config profiles (drop old tables), infra billing, node version, server descriptions |
| **2025-07** | 3 | API tokens, MUX, sockopt |
| **2025-08** | 5 | Host tag/isHidden, SNI override, VLESS route, indexes, tId |
| **2025-09** | 4 | Subscription request history, shuffle, mihomo x25519 |
| **2025-10** | 8 | **Major:** hosts_to_nodes, snippets, response rules, external squads, passkeys |
| **2025-11** | 13 | **Major:** usage history refactor, user_traffic, xray JSON template, DnD, node tags, squad host exclusions, custom remarks unification, status/PK changes, stricter host columns |
| **2025-12** | 7 | Drop deprecated columns/tables, blank SNI, subpage configs |
| **2026-01** | 1 | ES custom remarks fix |
| **2026-02** | 2 | Exclude host from subtypes, node plugins |
| **2026-03** | 1 | Final mask in host |

### 8.2 Ключевые архитектурные эволюции

1. **2025-03: OAuth2 + Subscription System** — Крупнейшее изменение. Добавлена вся подсистема подписок.
2. **2025-06: Squads + Config Profiles** — Переход от простых inbound'ов к профилям конфигурации. Старые таблицы дропнуты.
3. **2025-10: External Squads** — Добавлен White Label (внешние группы с оверрайдами).
4. **2025-11: Usage History Refactor** — Переработка системы учёта трафика.
5. **2025-12: Subpage Configs** — Кастомизация страницы подписки.

---

## 9. CRITICAL DATA PATHS

### 9.1 Subscription Delivery (самый сложный запрос)
```sql
-- Получение подписки требует:
SELECT u.* FROM users u WHERE u.shortUuid = $1;           -- найти пользователя
SELECT ut.* FROM user_traffic ut WHERE ut.t_id = u.tId;    -- трафик
SELECT h.* FROM hosts h                                     -- хосты
  JOIN hosts_to_nodes h2n ON h.uuid = h2n.host_uuid
  JOIN nodes n ON h2n.node_uuid = n.uuid
  LEFT JOIN internal_squad_host_exclusions ishe ON ...      -- исключения
WHERE n.is_disabled = false AND h.is_disabled = false;
SELECT st.* FROM subscription_templates st WHERE ...;       -- шаблон
SELECT es.* FROM external_squads es WHERE es.uuid = u.external_squad_uuid; -- оверрайды
```

### 9.2 User Traffic Recording (самый частый запрос)
```sql
-- Каждые 15 секунд
INSERT INTO nodes_user_usage_history (nodeId, userId, totalBytes, createdAt)
VALUES (...) ON CONFLICT (nodeId, createdAt, userId) DO UPDATE SET totalBytes = totalBytes + $new;
UPDATE user_traffic SET used_traffic_bytes = used_traffic_bytes + $delta;
```

### 9.3 Node Status Check (каждые 10 секунд)
```sql
SELECT uuid, address, port, is_connected, is_disabled
FROM nodes WHERE is_disabled = false;
-- Затем для каждой: POST /node/xray/healthcheck
```

### 9.4 User Expiry Check (каждые 30 секунд)
```sql
UPDATE users SET status = 'EXPIRED'
WHERE status = 'ACTIVE' AND expire_at < now();
```

---

## 10. SEED DATA STRATEGY

12 seed-файлов выполняются последовательно:

| # | Seeder | Назначение |
|---|--------|-----------|
| 1 | `fix-migrations` | Исправление старых миграций |
| 2 | `checkup-external-squads` | Проверка внешних squads |
| 3 | `seed-remnawave-settings` | Дефолтные настройки панели |
| 4 | `seed-subscription-template` | 5 дефолтных шаблонов (XRAY_JSON, MIHOMO, CLASH, SINGBOX, STASH) |
| 5 | `seed-config-profile` | Дефолтный конфиг-профиль |
| 6 | `sync-inbounds` | Синхронизация inbound'ов |
| 7 | `seed-default-internal-squad` | Дефолтная внутренняя группа |
| 8 | `seed-subscription-settings` | Настройки подписки |
| 9 | `seed-keygen` | Генерация X25519 ключей и сертификатов |
| 10 | `seed-response-rules` | Правила ответа подписок |
| 11 | `seed-subpage-config` | Дефолтный конфиг страницы подписки |
| 12 | `verify-admin` | Проверка наличия админа |

---

## 11. DATABASE DESIGN PATTERNS

### 11.1 Используемые паттерны

| Паттерн | Где применяется | Оценка |
|---------|----------------|--------|
| **UUID as PK** | 24 таблицы | ✅ Хорошо для распределённых систем |
| **Surrogate BigInt + UUID** | users, nodes | ✅ UUID публичный, BigInt для внутренних связей |
| **Composite PK (M:N)** | 7 junction tables | ✅ Стандарт |
| **JSONB for flexible config** | 21 колонка | ⚠️ Нет типизации на уровне БД |
| **CASCADE delete** | 15+ отношений | ✅ Автоматическая очистка |
| **SET NULL on delete** | 7 отношений | ✅ Предотвращает потерю данных |
| **@autoincrement for ordering** | 9 таблиц | ⚠️ Возможны проблемы с уникальностью |
| **Singleton table** | remnawave_settings (id=1) | ⚠️ Нестандартно, но работает |
| **Array columns** | nodes.tags, hosts.excludeFromSubscriptionTypes | ✅ Удобно, но не реляционно |

### 11.2 Потенциальные проблемы

1. **JSONB без валидации на уровне БД** — 21 колонка JSON без constraints. Валидация только через Zod в приложении.
2. **BigInt usage bytes** — Правильно для больших чисел, но требует сериализации (`.toJSON()` monkey-patch).
3. **VARCHAR без явных длин** — Большинство VARCHAR колонок без ограничений длины.
4. **@autoincrement для viewPosition** — В Prisma это создаёт отдельную последовательность, может быть неожиданным.
5. **date_trunc час в PK** — Может привести к коллизиям при опоздавших данных.
6. **Отсутствие soft-delete** — Нигде не используется мягкое удаление, только CASCADE.

---

## 12. TABLE SIZE ESTIMATES (Production)

| Таблица | Оценка роста | Причина |
|---------|-------------|---------|
| `nodes_user_usage_history` | **HIGH** | +1 row/user/node/день |
| `nodes_usage_history` | **HIGH** | +1 row/node/час |
| `user_subscription_request_history` | **MEDIUM** | Каждый запрос подписки |
| `torrent_blocker_reports` | **LOW-MED** | Только при детектах |
| `users` | **LOW** | Растёт с клиентами |
| `nodes` | **LOW** | ~количество серверов |
| `hosts` | **LOW** | ~количество inbound'ов |
| `*_settings` / `*_config` | **STATIC** | 1-N записей |

**Рекомендации по очистке:**
- `nodes_user_usage_history` — scheduler SERVICE.CLEAN_OLD_USAGE_RECORDS (weekly)
- `nodes_usage_history` — аналогично
- `user_subscription_request_history` — `CountAndDeleteSubscriptionRequestHistoryCommand`
- `nodes_traffic_usage_history` — только последние N записей

---

*End of Stage 3 — DATABASE_FORENSICS.md*
