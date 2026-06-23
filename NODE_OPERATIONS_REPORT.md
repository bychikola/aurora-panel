# NODE SYSTEM ANALYSIS — Remnawave → AURORA

> **Stage 7: Node System Analysis**
> **Date:** 2026-06-23
> **Status:** COMPLETE

---

## 1. NODE LIFECYCLE

### 1.1 Полный жизненный цикл ноды

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        NODE LIFECYCLE                                     │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌──────────────────┐                                                     │
│  │  1. REGISTRATION │  Admin создаёт Node в панели                        │
│  │     (Backend)    │  POST /api/nodes { name, address, port, config }    │
│  └────────┬─────────┘                                                     │
│           │                                                               │
│           ▼                                                               │
│  ┌──────────────────┐                                                     │
│  │  2. CONNECTING   │  Backend → BullMQ: START_NODE_QUEUE                 │
│  │     (Queue)      │  Worker: POST /node/xray/start { xrayConfig }       │
│  └────────┬─────────┘                                                     │
│           │                                                               │
│           ▼                                                               │
│  ┌──────────────────┐                                                     │
│  │  3. ONLINE       │  Node: isConnected=true, isXrayOnline=true          │
│  │     (Active)     │  Backend: isConnected=true                          │
│  └────────┬─────────┘                                                     │
│           │                                                               │
│           ├──► 3a. HEARTBEAT (каждые 10 сек)                              │
│           │    POST /node/xray/healthcheck                                │
│           │    Обновление Redis: system info, stats, online users         │
│           │                                                               │
│           ├──► 3b. TRAFFIC RECORDING (каждые 15/30 сек)                   │
│           │    POST /node/stats/get-users-stats { reset: true }           │
│           │    POST /node/stats/get-system-stats                           │
│           │                                                               │
│           ├──► 3c. USER SYNC (on demand)                                  │
│           │    POST /node/handler/add-user / remove-user                  │
│           │                                                               │
│           └──► 3d. PLUGIN SYNC (on demand)                                │
│                POST /node/plugin/sync { plugin config }                   │
│                                                                           │
│           ▼                                                               │
│  ┌──────────────────┐                                                     │
│  │  4. DISABLED     │  Admin отключает Node                               │
│  │     (Offline)    │  POST /api/nodes/:uuid/actions/disable              │
│  │                  │  Backend → BullMQ: STOP_NODE_QUEUE                  │
│  └────────┬─────────┘                                                     │
│           │                                                               │
│           ▼                                                               │
│  ┌──────────────────┐                                                     │
│  │  5. DELETED      │  Admin удаляет Node                                 │
│  │     (Removed)    │  DELETE /api/nodes/:uuid                            │
│  │                  │  Backend → BullMQ: STOP_NODE_QUEUE (delete flag)    │
│  │                  │  EventEmitter: NODE.DELETED                         │
│  └──────────────────┘                                                     │
│                                                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Node States (Backend DB)

| Состояние | `isConnected` | `isConnecting` | `isDisabled` | Когда |
|-----------|--------------|----------------|-------------|-------|
| **New** | false | false | false | Сразу после создания |
| **Connecting** | false | true | false | Start job отправлен |
| **Online** | true | false | false | Healthcheck успешен |
| **Offline** | false | false | false | Healthcheck провален |
| **Disabled** | false | false | true | Админ отключил |
| **Error** | false | false | false | `lastStatusMessage` != null |

---

## 2. NODE REGISTRATION

### 2.1 Создание ноды

```
Admin (Frontend)
    │ POST /api/nodes { name, address, port, configProfile }
    ▼
Backend NodesController.createNode()
    │
    ▼
NodesService.createNode()
    ├── 1. Валидация name/address уникальности (Prisma P2002)
    ├── 2. Создание записи в БД:
    │       INSERT INTO nodes (uuid, name, address, port, ...)
    ├── 3. Привязка Config Profile:
    │       GET config_profiles WHERE uuid = activeConfigProfileUuid
    │       INSERT INTO config_profile_inbounds_to_nodes
    │           (configProfileInboundUuid, nodeUuid)
    ├── 4. Старт ноды:
    │       this.nodesQueuesService.startNode({ nodeUuid })
    │       → BullMQ: NODES_START_NODE_QUEUE.add()
    ├── 5. Event: NODE.CREATED
    │       → Telegram/Webhook уведомления
    └── 6. Return NodeResponseModel with system info from Redis cache
```

### 2.2 Регистрация НЕ требует рукопожатия

Node **не регистрируется самостоятельно** на Backend. Вся инициализация идёт от Backend к Node:
- Backend знает адрес Node из БД
- Backend подключается к Node через HTTPS (mTLS)
- Node не подключается к Backend (в отличие от pull-модели)

---

## 3. HEARTBEAT (Health Check)

### 3.1 Health Check Pipeline

```
Scheduler (каждые 10 секунд):
    │
    ▼
NodeHealthCheckTask.handleCron()
    │
    ├── Первый запуск после рестарта панели:
    │   this.nodesQueuesService.startAllNodes({ emitter: 'nodeHealthCheck' })
    │   → BullMQ: START_ALL_NODES_QUEUE
    │   → Worker запускает все enabled ноды
    │
    ├── Последующие запуски:
    │   GetEnabledNodesPartialQuery → только enabled ноды
    │   this.nodesQueuesService.checkNodeHealthBulk(nodes)
    │   → BullMQ: NODES_HEALTH_CHECK_QUEUE.addBulk(...)
    │
    └── Worker: health-check.processor
        │
        Для каждой ноды (concurrently):
        ├── POST /node/xray/healthcheck
        │   ← Node: { isAlive, xrayInternalStatusCached, xrayVersion, nodeVersion }
        │
        ├── Если isAlive=true:
        │   ├── POST /node/stats/get-system-stats
        │   │   ← Node: { xrayInfo, plugins, system }
        │   │   → Redis: CACHE_KEYS.NODE_SYSTEM_INFO (TTL: бессрочно)
        │   │   → Redis: CACHE_KEYS.NODE_SYSTEM_STATS (TTL: 30s)
        │   │   → Redis: CACHE_KEYS.NODE_VERSIONS (TTL: бессрочно)
        │   │   → Redis: CACHE_KEYS.NODE_XRAY_UPTIME (TTL: 16s)
        │   │   → Redis: CACHE_KEYS.NODE_USERS_ONLINE (TTL: 16s)
        │   │
        │   └── UPDATE nodes SET
        │       isConnected = true,
        │       isConnecting = false,
        │       lastStatusChange = now(),
        │       lastStatusMessage = null
        │
        └── Если isAlive=false или ошибка:
            ├── Логирование ошибки
            └── UPDATE nodes SET
                isConnected = false,
                isConnecting = false,
                lastStatusChange = now(),
                lastStatusMessage = error.message
```

### 3.2 Redis Caching Strategy

Node healthcheck обновляет 5 ключей в Redis (через `ioredis` pipeline):

| Cache Key | TTL | Данные |
|-----------|-----|--------|
| `NODE_SYSTEM_INFO(uuid)` | ∞ | CPU, память, ОС |
| `NODE_SYSTEM_STATS(uuid)` | 30s | Load average, память, uptime |
| `NODE_USERS_ONLINE(uuid)` | 16s | Количество пользователей онлайн |
| `NODE_VERSIONS(uuid)` | ∞ | Node version, Xray version |
| `NODE_XRAY_UPTIME(uuid)` | 16s | Uptime Xray-core |

**Примечание:** Данные живут в Redis с короткими TTL, поэтому при остановке scheduler'а Node будет показываться как offline через 16-30 секунд.

### 3.3 Connection State Machine

```
                     startNode()
    [DISCONNECTED] ─────────────► [CONNECTING]
         ▲                            │
         │ healthcheck fail          │ healthcheck OK
         │                            ▼
         └────────────────────── [CONNECTED]
                                       │
                                       │ healthcheck fail
                                       ▼
                                  [DISCONNECTED]

    disableNode() → [DISABLED] (stopNode + isDisabled=true)
```

---

## 4. SYNCHRONIZATION

### 4.1 User Synchronization

При изменении пользователя на Backend:

```
UsersService (Backend)
    │
    ├── Create User:
    │   EventEmitter: AddUserToNodeEvent
    │   → NodesQueuesService.addUserToNode({ nodeUuid, userData })
    │   → BullMQ: NODES_NODE_USERS_QUEUE
    │   → Worker: POST /node/handler/add-user
    │
    ├── Bulk Create:
    │   EventEmitter: AddUsersToNodeEvent
    │   → NodesQueuesService.addUsersToNode({ nodeUuids[], users[] })
    │   → BullMQ: NODES_BULK_USERS_QUEUE
    │   → Worker: POST /node/handler/add-users
    │
    ├── Delete User:
    │   EventEmitter: RemoveUserFromNodeEvent
    │   → NodesQueuesService.removeUserFromNode(...)
    │   → BullMQ: NODES_NODE_USERS_QUEUE
    │   → Worker: POST /node/handler/remove-user
    │
    └── Reset Traffic:
        EventEmitter → NodesQueuesService
        → BullMQ: resetUserTrafficProcessor
        └── Для каждой ноды с пользователем:
            POST /node/handler/add-user (пересоздание пользователя)
```

### 4.2 Plugin Synchronization

```
Backend: Plugin изменён
    │
    ├── NodesQueuesService.syncNodePlugins({ nodeUuid })
    │   → BullMQ: NODES_PLUGINS_QUEUE
    │   → Worker: POST /node/plugin/sync { plugin }
    │
    └── Bulk sync:
        NodesQueuesService.syncNodePluginsBulk([...])
        → BullMQ: NODES_PLUGINS_QUEUE.addBulk(...)
```

### 4.3 Config Profile Synchronization (Start/Stop Pattern)

При изменении Config Profile или перезапуске ноды:

```
Backend → startNode({ nodeUuid })
    │
    ▼
Worker: start-node.processor
    ├── 1. Get Node by UUID (DB)
    ├── 2. Get Config Profile with inbounds
    ├── 3. Get Active Plugin
    ├── 4. Get Users for this Node (GetPreparedConfigWithUsersQuery)
    │       ├── Группировка пользователей по internal squads
    │       ├── Фильтрация: только ACTIVE, не истекшие
    │       └── Построение структуры inbound→users
    ├── 5. Build Xray Config:
    │       ├── configProfile.config (JSON)
    │       ├── Вставка пользователей в inbounds[].settings.clients
    │       └── Настройка streamSettings, routing, etc.
    ├── 6. Build Hashes:
    │       ├── emptyConfigHash (конфиг без clients)
    │       └── per-inbound: HashedSet из UUID пользователей
    ├── 7. POST /node/xray/start { xrayConfig, internals: { hashes } }
    ├── 8. UPDATE nodes SET isConnecting = true
    └── 9. Return { isStarted }
```

---

## 5. STATISTICS TRANSFER

### 5.1 User Traffic Collection

```
Scheduler (каждые 15 секунд):
    RecordUserUsageTask
        │
        ├── GetOnlineNodesQuery → только isConnected=true
        └── nodesQueuesService.recordUserUsageBulk([...])
            │
            ▼
        Worker: record-user-usage.processor
            │
            Для каждой онлайн-ноды:
            ├── POST /node/stats/get-users-stats { reset: true }
            │   ← { users: [{ username, uplink, downlink }] }
            │
            ├── Фильтр: USER_USAGE_IGNORE_BELOW_BYTES (default: 0)
            ├── UPSERT INTO nodes_user_usage_history
            │       (nodeId, userId, createdAt, totalBytes)
            │       VALUES (...) ON CONFLICT DO UPDATE
            │       SET totalBytes = totalBytes + delta
            │
            ├── UPDATE user_traffic
            │       SET used_traffic_bytes = used_traffic_bytes + delta,
            │           lifetime_used_traffic_bytes = lifetime_used_traffic_bytes + delta
            │
            └── UPDATE nodes
                    SET traffic_used_bytes = traffic_used_bytes + totalDelta
```

### 5.2 Node Traffic Collection

```
Scheduler (каждые 30 секунд):
    RecordNodesUsageTask
        │
        └── Worker: record-node-usage.processor
            │
            ├── POST /node/stats/get-system-stats
            │   ← { xrayInfo, plugins, system }
            │
            └── UPSERT INTO nodes_usage_history
                    (nodeUuid, createdAt, downloadBytes, uploadBytes, totalBytes)
                    VALUES (...) ON CONFLICT (nodeUuid, date_trunc('hour', now())) DO UPDATE
```

### 5.3 Statistics Flow Summary

```
Xray-core (in-memory counters)
    │ gRPC (reset=true каждые 15с)
    ▼
Node StatsService
    │ HTTPS (mTLS+JWT)
    ▼
Backend Worker (BullMQ)
    │ Prisma/Kysely
    ▼
PostgreSQL
    ├── nodes_user_usage_history (daily, per user per node)
    ├── nodes_usage_history (hourly, per node)
    └── user_traffic (current totals, per user)
```

### 5.4 Traffic Reset Flows

**Пользовательские сбросы:**
```
Scheduler: RESET_USER_TRAFFIC.DAILY (00:05 every day)
    → Enqueue: USERS_RESET_USER_TRAFFIC_QUEUE
    → Worker: reset-user-traffic.processor
        ├── Найти пользователей со стратегией DAY
        ├── Для каждого: архивировать usage → обнулить счётчик
        └── Для каждой ноды: пересоздать пользователя (addUser)
```

**Нодовые сбросы:**
```
Scheduler: RESET_NODE_TRAFFIC (01:00 every day)
    → Direct task (не через очередь):
        ├── Найти все ноды
        ├── Для каждой: архивировать trafficUsedBytes в nodes_traffic_usage_history
        └── Обнулить trafficUsedBytes
```

---

## 6. STARTUP RECOVERY

### 6.1 Backend Panel Restart

При запуске Scheduler'а:

```
NodeHealthCheckTask (первый вызов):
    this.isNodesRestarted = false → true
    │
    └── startAllNodes({ emitter: 'nodeHealthCheck' })
        → BullMQ: START_ALL_NODES_QUEUE
        → Worker перебирает ВСЕ enabled ноды и запускает их
```

Это гарантирует, что после перезагрузки панели все ноды получат актуальный конфиг.

### 6.2 Node Restart

При перезапуске контейнера Node:

```
Docker entrypoint.sh:
    ├── Генерирует новые случайные креденшелы
    ├── Запускает supervisord
    └── Запускает Node NestJS приложение

Node main.ts:
    ├── initializeMTLSCerts() → генерация внутренних TLS сертификатов
    ├── parseNodePayload() → извлечение сертификатов из SECRET_KEY
    └── Запуск HTTPS + Unix Socket серверов

XrayCore → НЕ запущен (autostart=false)
```

Node **ждёт** команды от Backend для запуска Xray. Без панели Xray не стартует.

### 6.3 Recovery Scenarios

| Сценарий | Backend | Node | Recovery |
|----------|---------|------|----------|
| Node рестарт | Не знает | Xray offline | Следующий healthcheck обнаружит offline → restart |
| Node временно недоступен | Healthcheck fail → isConnected=false | OK | Следующий healthcheck OK → isConnected=true |
| Backend рестарт | Все ноды offline | OK, Xray работает | NodeHealthCheck: startAllNodes() на всех |
| Backend + Node рестарт | Все offline | Xray не запущен | Backend стартует → healthcheck → startAllNodes |

---

## 7. IPC (INTER-PROCESS COMMUNICATION)

### 7.1 Backend Internal Communication

```
┌──────────┐        ┌──────────┐        ┌──────────┐
│   API    │        │ Scheduler│        │  Worker  │
│ (cluster)│        │  (fork)  │        │ (cluster)│
└────┬─────┘        └────┬─────┘        └────┬─────┘
     │                   │                   │
     │  Enqueue Job      │  Enqueue Job      │  Process Job
     │  (BullMQ)         │  (BullMQ)         │  (BullMQ)
     │                   │                   │
     ▼                   ▼                   ▼
┌──────────────────────────────────────────────────┐
│                  Redis / Valkey                   │
│  ┌──────────────────┐  ┌──────────────────────┐  │
│  │  BullMQ Queues   │  │  Raw Cache (ioredis) │  │
│  │  (11 node queues)│  │  (5 keys per node)   │  │
│  └──────────────────┘  └──────────────────────┘  │
└──────────────────────────────────────────────────┘
     ▲                                               │
     │  EventEmitter2 (in-process)                   │
     │                                               │
┌────┴─────────────┐                                │
│  Module Events   │                                │
│  NODE.CREATED    │                                │
│  NODE.MODIFIED   │                                │
│  NODE.ENABLED    │                                │
│  NODE.DISABLED   │                                │
│  NODE.DELETED    │                                │
└──────────────────┘                                │
                                                    │
     ┌──────────────────────────────────────────────┘
     │
     ▼
┌──────────────────────────────────────────────────┐
│              Node Communication                    │
│  POST https://node:NODE_PORT/node/*               │
│  (mTLS + JWT RS256)                               │
└──────────────────────────────────────────────────┘
```

### 7.2 BullMQ Queue Design

| Queue | Type | Concurrency | Dedup | JobId Pattern |
|-------|------|------------|-------|---------------|
| START_NODE | Serial | Default | No | `start-node-{uuid}` |
| STOP_NODE | Serial | Default | No | `stop-node-{uuid}` |
| HEALTH_CHECK | Bulk | Default | No | `health-check-{uuid}` |
| START_ALL_BY_PROFILE | Serial | **3** | Yes (profileUuid) | — |
| START_ALL_NODES | Serial | **1** | Yes (fixed) | — |
| RECORD_USER_USAGE | Bulk | Default | No | `record-user-usage-{nodeId}` |
| RECORD_NODE_USAGE | Bulk | Default | No | `record-node-usage-{uuid}` |
| NODE_USERS | Serial | Default | No | — |
| BULK_USERS | Serial | Default | No | — |
| QUERY_NODES | Serial | Default | No | — |
| PLUGINS | Bulk | Default | No | — |

**Concurrency control:**
- `START_ALL_BY_PROFILE`: max 3 одновременных запуска
- `START_ALL_NODES`: строго 1 (последовательный запуск всех нод)

**Job Options:**
- `removeOnComplete: true` — удалять успешные jobs
- `removeOnFail: true` — удалять упавшие jobs
- `deduplication.id` — предотвращать дубликаты

---

## 8. MONITORING & OBSERVABILITY

### 8.1 Node Status in Frontend

Frontend получает статус ноды через:
```
GET /api/nodes → getAllNodes()
    │
    └── NodesSystemCacheService.getMany(nodes)
        ├── Redis Pipeline (5 keys per node, batch)
        └── Возвращает: { system: {info, stats}, versions, xrayUptime, onlineUsers }
```

Обновление: каждый запрос к `/api/nodes` читает Redis (не БД для system info).

### 8.2 Prometheus Metrics

Backend экспортирует метрики для Prometheus в Scheduler:

```
Scheduler: ExportMetricsTask (каждые 15 секунд)
    ├── GetAllNodesQuery → все ноды
    ├── GetShortUserStatsQuery → статистика пользователей
    └── Установка gauge/counter:
        ├── remnawave_nodes_status (gauge)
        ├── remnawave_users_total (gauge)
        ├── remnawave_bandwidth_total (counter)
        └── process_* (runtime metrics)
```

Доступ: `GET /metrics` (Basic Auth)

### 8.3 Telegram/Webhook Notifications

Node события генерируют уведомления:

```typescript
EventEmitter.emit(EVENTS.NODE.CREATED, new NodeEvent(node, event))
    ↓
Queue: NTFY_TELEGRAM_QUEUE / NTFY_WEBHOOK_QUEUE
    ↓
Telegram: formatted message with node details
Webhook: POST to configured URL with JSON payload
```

---

*End of Stage 7 — NODE_OPERATIONS_REPORT.md*
