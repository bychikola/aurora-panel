# ARCHITECTURE RECONSTRUCTION — Remnawave → AURORA

> **Stage 1: Architecture Reconstruction**
> **Date:** 2026-06-23
> **Status:** COMPLETE

---

## 1. EXECUTIVE SUMMARY

Remnawave — это трёхкомпонентная распределённая система управления VPN/прокси на базе Xray-core:

| Компонент | Технология | Роль | Порты |
|-----------|-----------|------|-------|
| **Backend** | NestJS 11 + PostgreSQL + Redis | Центральный API, оркестрация | 3000 (API), 3001 (Metrics) |
| **Frontend** | React 19 + Vite 7.3 | Административная SPA | 3333 (dev) |
| **Node** | NestJS 11 + Xray-core | Edge-агент на прокси-сервере | 2222 (API), Unix Socket |

---

## 2. BACKEND — CENTRAL CONTROL PLANE

### 2.1 Multi-Process Architecture

Backend запускается как **три независимых процесса** под управлением PM2:

```
┌─────────────────────────────────────────────────────────────┐
│                      PM2 Process Manager                      │
├─────────────────┬──────────────────┬─────────────────────────┤
│  remnawave-api  │ remnawave-       │  remnawave-jobs         │
│  (cluster)      │ scheduler (fork) │  (cluster)              │
│                 │                  │                         │
│  ENV:           │ ENV:             │ ENV:                    │
│  INSTANCE_TYPE  │ INSTANCE_TYPE    │ INSTANCE_TYPE           │
│  =api           │ =scheduler       │ =processor              │
│                 │                  │                         │
│  Порт 3000      │ Без портов       │ Без портов              │
│  REST API       │ Cron Jobs        │ BullMQ Workers          │
│  Swagger/Scalar │ @nestjs/schedule │                         │
└─────────────────┴──────────────────┴─────────────────────────┘
         │                  │                    │
         └──────────────────┼────────────────────┘
                            │
                    ┌───────┴───────┐
                    │  Redis/Valkey  │
                    │  (Pub/Sub +    │
                    │   BullMQ)      │
                    └───────────────┘
```

**Разделение кода:**
- `src/main.ts` — точка входа API
- `src/bin/scheduler/scheduler.ts` — точка входа Scheduler
- `src/bin/processors/processors.ts` — точка входа Job Worker

**Условная загрузка модулей:**
- `isRestApi()` — модули, загружаемые только в API (auth, admin, subscription, system)
- `isScheduler()` — модули, загружаемые только в Scheduler (remnawave-service)
- Остальные модули загружаются во всех процессах (users, nodes, hosts — для доступа к БД)

### 2.2 Request Lifecycle

```
HTTP Request
    │
    ▼
Helmet (CSP, CORS headers)
    │
    ▼
compression (gzip)
    │
    ▼
getRealIp middleware (X-Forwarded-For)
    │
    ▼
Morgan logger (если включен)
    │
    ▼
noRobotsMiddleware → proxyCheckMiddleware
    │
    ▼
ZodValidationPipe (global)
    │
    ▼
Guard: JwtAuthGuard | OptionalJwtGuard | RolesGuard | ProxyCheckGuard
    │
    ▼
Controller → @GetJwtPayload(), @GetIp(), @GetUseragent(), @Roles()
    │
    ▼
Service Layer (CQRS: CommandBus / QueryBus)
    │
    ▼
Repository → PrismaService / TxKyselyService
    │
    ▼
PostgreSQL
```

### 2.3 CQRS Pattern

Все бизнес-операции разделены на команды (изменения) и запросы (чтение):

```
modules/<domain>/
├── commands/           # Команды (мутации)
│   └── <action>/
│       ├── <action>.command.ts    # Класс команды
│       └── <action>.handler.ts    # Обработчик (аннотирован @CommandHandler)
├── queries/            # Запросы (чтение)
│   └── <action>/
│       ├── <action>.query.ts      # Класс запроса
│       └── <action>.handler.ts    # Обработчик (аннотирован @QueryHandler)
├── events/             # События
│   └── <event>/
│       ├── <event>.event.ts
│       └── <event>.handler.ts     # Обработчик (аннотирован @EventsHandler)
├── dtos/               # Data Transfer Objects
├── entities/           # Бизнес-сущности
├── models/             # Модели ответов
├── repositories/       # Доступ к данным
└── <domain>.module.ts
```

### 2.4 Database Layer

**Двойной доступ к данным:**

| Слой | Технология | Применение |
|------|-----------|-----------|
| Prisma ORM | `PrismaService` | Стандартные CRUD операции |
| Kysely | `TxKyselyService` | Сложные транзакционные запросы |

**Генераторы Prisma:**
```prisma
generator client   → prisma-client-js (основной клиент)
generator kysely   → prisma-kysely (типизированный SQL билдер)
generator json     → prisma-json-types-generator (типизированные JSON поля)
```

**Transactional Pattern:**
```typescript
// Автоматические транзакции через @nestjs-cls/transactional
@Transactional()
async createUser(dto: CreateUserDto) {
    const user = await this.prisma.users.create({ data: dto });
    await this.prisma.userTraffic.create({ data: { tId: user.tId } });
    return user;
}
```

### 2.5 Module Dependency Graph

```
AppModule
├── CommonConfigModule (Zod валидация .env)
├── PrismaModule (глобальный)
├── ClsModule (транзакции, глобальный)
├── EventEmitterModule (wildcard events, глобальный)
├── RawCacheModule (in-memory cache)
├── AxiosModule (HTTP клиент для node API)
├── IntegrationModules
│   ├── HealthController (Terminus health checks)
│   ├── PrometheusReporter (/metrics)
│   └── Notifications (Telegram Bot + Webhook)
├── RemnawaveModules (все бизнес-модули)
│   ├── [COND] AdminModule (isRestApi)
│   ├── [COND] AuthModule (isRestApi)
│   ├── [COND] SystemModule (isRestApi)
│   ├── [COND] SubscriptionModule (isRestApi)
│   ├── [COND] SubscriptionTemplateModule (isRestApi)
│   ├── [COND] SubscriptionSettingsModule (isRestApi)
│   ├── [COND] RemnawaveServiceModule (isScheduler)
│   ├── UsersModule (всегда)
│   ├── NodesModule (всегда)
│   ├── HostsModule (всегда)
│   ├── KeygenModule (всегда)
│   ├── ConfigProfileModule (всегда)
│   ├── InternalSquadModule (всегда)
│   ├── ExternalSquadModule (всегда)
│   ├── NodePluginModule (всегда)
│   ├── HwidUserDevicesModule (всегда)
│   ├── InfraBillingModule (всегда)
│   └── ... usage history modules (всегда)
├── QueueModule (BullMQ — во всех процессах)
├── RuntimeMetricsModule
└── [COND] ServeStaticModule (фронтенд, если не dev)
```

### 2.6 Queue System (BullMQ)

**19 очередей** в трёх категориях:

| Категория | Очереди | Процессоры |
|-----------|---------|-----------|
| **Nodes** | HEALTH_CHECK, START, STOP, USERS, BULK_USERS, START_ALL_BY_PROFILE, START_ALL_NODES, RECORD_USER_USAGE, RECORD_NODE_USAGE, QUERY_NODES, PLUGINS | bulk-users, health-check, plugins, query-nodes, record-node-usage, record-user-usage, start-node, stop-node, start-all-nodes, start-all-nodes-by-profile |
| **Users** | SERIAL_OPERATIONS, MODIFY_MANY, SUBSCRIPTION_REQUESTS, RESET_USER_TRAFFIC, USERS_WATCHDOG, USER_EVENTS, UPDATE_USERS_USAGE | modify-many-users, reset-user-traffic, serial-operations, subscription-requests, update-users-usage, user-events, users-watchdog |
| **Notifications** | NTFY_TELEGRAM_QUEUE, NTFY_WEBHOOK_QUEUE | telegram-bot-logger, webhook-logger |
| **Service** | SERVICE_QUEUE, PUSH_TO_DB_QUEUE | service, push-from-redis |

**Поток данных в очередях:**
```
Scheduler (Cron) → Enqueue Job → BullMQ Queue → Worker Processor
    ├── Node health check (каждые 10 сек)
    ├── Record node usage (каждые 30 сек)
    ├── Record user usage (каждые 15 сек)
    ├── Reset user traffic (daily/weekly/monthly)
    ├── Find expired/exceeded users
    └── Vacuum tables (weekly)
```

### 2.7 Scheduler (Cron Jobs)

**Полный список cron-задач:**

| Задача | Интервал | Описание |
|--------|---------|----------|
| `METRIC_EXPORT_METRICS` | Каждые 15 сек | Экспорт метрик Prometheus |
| `METRIC_SYNC_METRICS` | Каждые 6 часов | Синхронизация метрик |
| `NODE_HEALTH_CHECK` | Каждые 10 сек | Проверка здоровья нод |
| `RECORD_NODE_USAGE` | Каждые 30 сек | Запись использования нод |
| `RECORD_USER_USAGE` | Каждые 15 сек | Запись использования пользователей |
| `RESET_NODE_TRAFFIC` | Каждый день в 01:00 | Сброс трафика нод |
| `REVIEW_NODES` | Каждый час | Аудит статуса нод |
| `RESET_USER_TRAFFIC.DAILY` | Каждый день в 00:05 | Ежедневный сброс |
| `RESET_USER_TRAFFIC.WEEKLY` | Понедельник 00:15 | Еженедельный сброс |
| `RESET_USER_TRAFFIC.MONTHLY` | 1-е число 00:20 | Ежемесячный сброс |
| `RESET_USER_TRAFFIC.MONTHLY_ROLLING` | Каждый день 00:10 | Скользящий сброс |
| `REVIEW_USERS.FIND_EXCEEDED` | Каждые 45 сек | Поиск превысивших трафик |
| `REVIEW_USERS.FIND_EXPIRED` | Каждые 30 сек | Поиск истекших пользователей |
| `EXPIRE_NOTIFICATIONS` | Каждую минуту | Уведомления об истечении |
| `BANDWIDTH_NOTIFICATIONS` | Каждые 5 мин | Уведомления о bandwidth |
| `NOT_CONNECTED_NOTIFICATIONS` | Каждые 10 мин | Уведомления о неактивных |
| `SERVICE.CLEAN_OLD_RECORDS` | Понедельник 00:30 | Очистка старых записей |
| `SERVICE.VACUUM_TABLES` | Понедельник 00:45 | Vacuum PostgreSQL |
| `CRM.INFRA_BILLING` | Каждый день 17:00 | Уведомления о биллинге |

### 2.8 Authentication & Authorization

**Стратегии аутентификации:**

| Стратегия | Механизм | Guard |
|-----------|---------|-------|
| JWT (основной) | Bearer token (HS256) | `JwtAuthGuard` |
| JWT API Tokens | Bearer token (отдельный secret) | `JwtAuthGuard` |
| Optional JWT | Bearer token (опционально) | `OptionalJwtAuthGuard` |
| Passkey (WebAuthn) | FIDO2/WebAuthn | Встроен в auth.service |
| OAuth2 | Passport (провайдеры: GitHub, Telegram, Yandex, Keycloak, PocketID, Generic) | Встроен в auth.controller |
| Basic Auth | Для /metrics endpoint | `BasicAuthGuard` |
| Internal Token | Query-param token (для Node ↔ Backend) | `WorkerRoutesGuard` |

**Уровни ролей (RBAC):**
- `@Roles()` декоратор + `RolesGuard`
- Роли: `ADMIN`, возможно другие (определены в `@libs/contracts/constants/roles/`)

### 2.9 Subscription Engine (ключевая подсистема)

Самый сложный пайплайн в backend — генерация конфигов подписки:

```
Client Request: GET /api/sub/:shortUuid/:token
    │
    ▼
SubscriptionController
    │
    ▼
SubscriptionService
    ├── 1. Валидация токена подписки
    ├── 2. Поиск пользователя по shortUuid
    ├── 3. Проверка статуса, срока действия, трафика
    ├── 4. Определение типа клиента (User-Agent parsing)
    ├── 5. Загрузка хостов (с фильтрацией по squads)
    ├── 6. Загрузка шаблона подписки
    ├── 7. Применение правил ответа (SubscriptionResponseRules)
    │       ├── Middleware pipeline
    │       ├── Модификация заголовков
    │       └── Модификация тела ответа
    ├── 8. Рендеринг шаблона
    │       ├── Xray JSON Generator
    │       ├── Clash Config Generator
    │       ├── Mihomo Config Generator
    │       ├── Sing-box Config Generator
    │       └── Stash Config Generator
    ├── 9. Применение HWID-проверок
    └── 10. Возврат конфига
```

**Типы шаблонов подписки:**
- `XRAY_JSON` — стандартный JSON конфиг Xray
- `MİHOMO` — Mihomo (Clash Meta) конфиг
- `CLASH` — Clash конфиг
- `SINGBOX` — Sing-box конфиг
- `STASH` — Stash конфиг

**Поддерживаемые протоколы в хостах:**
- VLESS (XTLs, Reality, gRPC, WebSocket, XHTTP)
- Trojan (TLS, gRPC, WebSocket)
- Shadowsocks (2022)
- Hysteria2

---

## 3. FRONTEND — ADMIN DASHBOARD

### 3.1 Framework & Build

| Аспект | Детали |
|--------|--------|
| **Фреймворк** | React 19 |
| **Бандлер** | Vite 7.3 |
| **Роутинг** | React Router DOM v6.27 |
| **UI Kit** | Mantine v8.3.18 |
| **State Management** | Zustand 5.0 + TanStack React Query 5.85 |
| **Валидация** | Zod 3.25 |
| **i18n** | i18next (4 языка: EN, RU, FA, ZH) |
| **Архитектура** | Feature-Sliced Design (FSD) |

### 3.2 FSD Layer Architecture

```
┌──────────────────────────────────────────────────────┐
│                        APP                            │
│  app.tsx (провайдеры) + router.tsx (дерево маршрутов) │
├──────────────────────────────────────────────────────┤
│                       PAGES                           │
│  Композиция страниц: connectors + components          │
├──────────────────────────────────────────────────────┤
│                      WIDGETS                          │
│  Составные бизнес-блоки (таблицы, модалки, редакторы)  │
├──────────────────────────────────────────────────────┤
│                     FEATURES                          │
│  Пользовательские взаимодействия (формы, кнопки, ...)  │
├──────────────────────────────────────────────────────┤
│                     ENTITIES                          │
│  Бизнес-сущности: Zustand stores + domain models      │
├──────────────────────────────────────────────────────┤
│                      SHARED                           │
│  API (axios + react-query), UI kit, utils, constants   │
└──────────────────────────────────────────────────────┘
```

### 3.3 Route Tree

```
/ → redirect /dashboard
/auth → AuthLayout
  /auth/login → LoginPage
/oauth2/callback/:provider → OAuth2CallbackPage (без AuthGuard)

/dashboard → MainLayout (AppShell + Sidebar + Header)
  /dashboard/home → HomePage (метрики, recap)
  /dashboard/management
    /users → UsersPage
    /hosts → HostsPage
    /nodes → NodesPage
    /bandwidth-table → NodesBandwidthTablePage
    /stats/nodes → StatisticNodesPage
    /metrics/nodes → NodesMetricsPage
    /subscription-settings → SubscriptionSettingsPage
    /config-profiles → ConfigProfilesPage
    /config-profiles/:uuid → ConfigProfileEditorPage
    /internal-squads → InternalSquadsPage
    /external-squads → ExternalSquadsPage
    /settings → RemnawaveSettingsPage
    /plugins → NodePluginsPage
    /plugins/:uuid → NodePluginEditorPage
    /response-rules → ResponseRulesPage
  /dashboard/tools
    /hwid-inspector → HwidInspectorPage
    /srh-inspector → SrhInspectorPage
    /torrent-blocker-reports → TorrentBlockerReportsPage
    /sessions-explorer → SessionsExplorerPage
  /dashboard/templates
    /:type → TemplateBasePage
    /:type/:uuid → TemplateEditorPage
  /dashboard/subpage
    / → SubpageConfigsPage
    /:uuid → SubpageConfigEditorPage
  /dashboard/crm
    /infra-billing → InfraBillingPage
* → 404 NotFoundPage
```

### 3.4 State Management Architecture

**Zustand Stores (entities/):**
```
entities/
├── auth/session-store/          ← JWT token (persisted in localStorage)
│   └── Авто-синхронизация с Axios через subscribe()
├── dashboard/
│   ├── appshell-store/          ← Sidebar open/close
│   ├── nodes-store/             ← Node management state
│   ├── hosts-store/             ← Host management state
│   ├── users-table-store/       ← User table config
│   ├── bulk-users-actions-store/← Bulk action state
│   ├── user-modal-store/        ← User modal state
│   ├── user-creation-modal-store/
│   ├── modal-store/             ← Modal state management
│   ├── misc-store/              ← Misc dashboard state
│   └── updates-store/           ← GitHub stars, version info
```

**Server State (TanStack React Query):**
```
shared/api/
├── axios.ts                     ← Axios instance (JWT interceptor + auto-logout on 401/403)
├── query-client.ts              ← QueryClient (staleTime: 60s, gcTime: 120s, retry: 0)
├── tsq-helpers/
│   ├── create-get-query.hook.ts   ← Generic GET hook factory
│   └── create-mutation-hook.ts    ← Generic Mutation hook factory
├── keys-factory.ts               ← Все query keys (merge из всех доменов)
└── hooks/                        ← 22 доменных модуля API-хуков
    ├── auth/              ← login, register, logout, getAuthStatus
    ├── users/             ← CRUD + bulk actions + reset/revoke
    ├── nodes/             ← CRUD + restart/enable/disable/reset-traffic
    ├── hosts/             ← CRUD + bulk
    ├── config-profiles/   ← CRUD
    ├── subscription-*/    ← Settings, templates, page configs
    ├── api-tokens/        ← CRUD
    ├── passkeys/          ← WebAuthn management
    ├── system/            ← System info
    ├── bandwidth-stats/   ← Bandwidth statistics
    ├── hwid-user-devices/ ← HWID tracking
    ├── infra-billing/     ← Infrastructure billing
    ├── node-plugins/      ← Node plugins
    ├── internal-squads/   ← Internal squads
    ├── external-squads/   ← External squads
    ├── ip-control/        ← IP control
    ├── snippets/          ← Config snippets
    ├── subpage-configs/   ← Subpage configs
    └── subscription-request-history/
```

**Auth Flow:**
```
1. Login Form → POST /api/auth/login → { token }
2. setToken(token) → Zustand persist (localStorage)
3. Store.subscribe() → setAuthorizationToken(token) → Axios interceptor
4. Все запросы: Authorization: Bearer <token>
5. 401/403 Response → logoutEvents.emit()
6. AuthProvider слушает logoutEvents → resetAllStores() + removeToken()
7. AuthGuard → isAuthenticated=false → redirect /auth/login
```

### 3.5 API Layer Generic Pattern

```typescript
// Generic GET hook factory
export const createGetQueryHook = <TResponse, TArgs>(options: {
    queryKey: QueryKey;
    url: string | ((args: TArgs) => string);
    schema?: ZodSchema<TResponse>;
}) => {
    return (args: TArgs, queryOptions?: UseQueryOptions) => {
        return useQuery({
            queryKey: [...queryKey, args],
            queryFn: async () => {
                const url = typeof options.url === 'function'
                    ? options.url(args)
                    : options.url;
                const { data } = await instance.get(url);
                return options.schema ? options.schema.parse(data) : data;
            },
            ...queryOptions,
        });
    };
};
```

### 3.6 Theme System

**Цветовая схема (Dark-only):**
- Background: `#0d1117` (GitHub dark)
- Поверхности: стеклянный морфизм (backdrop-blur)
- Primary: `#22d3ee` (cyan)
- Secondary: `#9775fa` (purple)
- Шрифты: Montserrat (body), Unbounded (headings), Fira Mono (code)

**Компонентные оверрайды:** Badge, Breadcrumbs, Buttons, Charts, Inputs, Layouts, LoadingOverlay, Menu, Notification, RingProgress, Table, Tooltip, Card, Drawer, Fieldset, Modal

---

## 4. NODE — EDGE DATA PLANE

### 4.1 Dual HTTP Server Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    NODE AGENT                            │
├─────────────────────────┬───────────────────────────────┤
│  Публичный HTTPS сервер  │  Внутренний HTTP (Unix Socket) │
│  Порт: NODE_PORT (2222) │  Путь: /run/remnawave-*.sock │
│  mTLS (сертификаты из   │  Token auth (query param)    │
│   SECRET_KEY)           │                               │
│                         │                               │
│  Endpoints:             │  Endpoints:                    │
│  /node/xray/*           │  /internal/get-config          │
│  /node/handler/*        │  /internal/webhook             │
│  /node/stats/*          │                               │
│  /node/plugin/*         │                               │
│  /block-ip (no prefix)  │                               │
│  /unblock-ip (no prefix)│                               │
└─────────────────────────┴───────────────────────────────┘
```

### 4.2 Xray Lifecycle Management (startXray flow)

```
Panel: POST /node/xray/start (JWT guarded)
    │
    ▼
XrayController.startXray()
    │
    ▼
XrayService.startXray(body, ip)
    │
    ├── 1. Get system info (CPU, load, network interfaces)
    ├── 2. Guard: is another start already in progress?
    ├── 3. Guard: is Xray online AND hash check passes?
    │       ├── Yes (hash match) → SKIP RESTART, return OK
    │       └── No (hash mismatch) → CONTINUE
    │
    ├── 4. Get torrent blocker state
    ├── 5. generateApiConfig() — MERGE:
    │       ├── Panel config (inbounds, outbounds, routing from backend)
    │       ├── API inbound (mTLS gRPC endpoint on 127.0.0.1:XTLS_API_PORT)
    │       ├── Stats settings
    │       ├── Policy levels (statsUserUplink/Downlink/Online)
    │       ├── Routing rule (API traffic → API outbound)
    │       └── Torrent blocker (if enabled):
    │           ├── Blackhole outbound
    │           ├── Protocol-level routing rule
    │           └── Webhook URL → internal Unix socket
    │
    ├── 6. InternalService.extractUsersFromConfig()
    │       └── Для каждого inbound: HashedSet(user UUIDs)
    │           └── Далее hash-сравнение вместо перезапуска Xray
    │
    ├── 7. restartXrayProcess()
    │       ├── Stop Xray через supervisord XML-RPC
    │       ├── Start Xray через supervisord XML-RPC
    │       └── Xray читает конфиг:
    │           -config http+unix://<socket>/internal/get-config?token=<token>
    │
    ├── 8. getXrayInternalStatus()
    │       └── p-retry (10 попыток, 2 сек интервал)
    │           └── xtlsSdk.stats.getSysStats() через gRPC
    │
    └── 9. Return response (version, status, system info)
```

### 4.3 Certificate Trust Chain

```
SECRET_KEY (base64 JSON из .env панели)
    │
    ▼
parseNodePayload()
    ├── nodeKeyPem      → Приватный ключ Node (для HTTPS сервера)
    ├── nodeCertPem     → Сертификат Node (подписан CA панели)
    ├── caCertPem       → CA сертификат панели
    └── jwtPublicKey    → Публичный ключ для проверки JWT панели

initializeMTLSCerts() (генерируется при первом запуске)
    ├── caCertPem       → Локальный CA (для gRPC к Xray)
    ├── caKeyPem        → Приватный ключ локального CA
    ├── serverCertPem   → Сертификат сервера (Xray)
    ├── serverKeyPem    → Приватный ключ сервера (Xray)
    ├── clientCertPem   → Сертификат клиента (Node)
    └── clientKeyPem    → Приватный ключ клиента (Node)

Итог:
    Panel ↔ Node: mTLS (CA панели → сертификаты Node)
    Node ↔ Xray:  mTLS (Локальный CA → сертификаты Xray + Node)
```

### 4.4 User Management on Xray

```
HandlerService
    │
    ├── addUser({ type, tag, username, password/uuid, flow })
    │   ├── Remove existing user (если есть)
    │   ├── Add user по протоколу:
    │   │   ├── trojan → xtlsApi.handler.addTrojanUser()
    │   │   ├── vless  → xtlsApi.handler.addVlessUser()
    │   │   ├── shadowsocks → xtlsApi.handler.addShadowsocksUser()
    │   │   ├── shadowsocks2022 → xtlsApi.handler.addShadowsocks2022User()
    │   │   └── hysteria → xtlsApi.handler.addHysteriaUser()
    │   └── Update InternalService.HashedSet
    │
    ├── removeUser({ type, tag, username })
    │   ├── xtlsApi.handler.removeUser()
    │   ├── Drop user connections (sockdestroy)
    │   └── Remove from HashedSet
    │
    ├── addUsers / removeUsers (bulk)
    └── dropUsersConnections / dropIps
```

### 4.5 Traffic Statistics

```
StatsService
    │
    ├── getSystemStats()
    │   ├── xtlsSdk.stats.getSysStats() → Xray gRPC
    │   ├── getSystemInfo() → CPU model, cores
    │   ├── getSystemStats() → Load average
    │   └── NetworkStatsService → /proc/net/dev rates
    │
    ├── getUsersStats(reset?: boolean)
    │   └── xtlsSdk.stats.getAllUsersStats(reset)
    │       └── Xray возвращает { uplink, downlink } для каждого user
    │
    ├── getInboundStats(tag, reset)
    ├── getOutboundStats(tag, reset)
    ├── getAllInboundsStats(reset)
    ├── getAllOutboundsStats(reset)
    ├── getCombinedStats(reset)
    │
    ├── getUserOnlineStatus(username)
    │   └── xtlsSdk.stats.getUserOnlineStatus()
    │
    └── getUsersIpList()
        └── xtlsSdk.stats.rawClient.getStatsOnlineIpList()
            └── Pattern: user>>>{userId}>>>online
```

### 4.6 Plugin System

```
PluginService.sync(body)
    │
    ├── Validate: NodePluginSchema (Zod)
    ├── Resolve shared IP lists
    ├── syncConnectionDrop()
    │   └── Set whitelisted IPs
    ├── syncTorrentBlocker()
    │   └── Configure: enabled, blockDuration, ignoredIPs/users, ruleTags
    ├── syncIngressFilter()
    │   └── nftService.blockIps() → nftables-napi
    ├── syncEgressFilter()
    │   └── nftService.blockIpsAndPorts() → nftables-napi
    └── Determine: нужно ли перезапустить Xray?

Plugin Events:
    ├── XrayWebhookHandler (torrent detection)
    │   └── Xray POST /internal/webhook → nftService.blockIp() + report
    └── DropConnectionsHandler
        └── sockdestroy.killSockets() (CPU-efficient, bypasses conntrack)
```

---

## 5. INFRASTRUCTURE

### 5.1 Docker Compose Architecture (Production)

```yaml
services:
  remnawave:        # Backend (remnawave/backend:2)
    ports:          # 127.0.0.1:3000:APP_PORT, 127.0.0.1:3001:METRICS_PORT
    volumes:        # valkey-socket:/var/run/valkey
    depends_on:     # remnawave-db, remnawave-redis
    healthcheck:    # curl /health каждые 30 сек

  remnawave-db:     # PostgreSQL 17.6
    ports:          # 127.0.0.1:6767:5432
    volumes:        # remnawave-db-data:/var/lib/postgresql/data
    healthcheck:    # pg_isready каждые 3 сек

  remnawave-redis:  # Valkey 9 (Redis-совместимый)
    ports:          # none (Unix socket only)
    volumes:        # valkey-socket:/var/run/valkey
    config:         # --save "" --appendonly no --maxmemory-policy noeviction
    healthcheck:    # valkey-cli ping каждые 3 сек
```

### 5.2 Node Docker Architecture

```
┌──────────────────────────────────────────┐
│           NODE DOCKER CONTAINER           │
│                                           │
│  ┌─────────────────────────────────────┐ │
│  │  supervisord                        │ │
│  │  ├── [program:xray]                 │ │
│  │  │   └── rw-core -config http+unix: │ │
│  │  │       //.../internal/get-config  │ │
│  │  └── (managed by NestJS app)        │ │
│  └─────────────────────────────────────┘ │
│                                           │
│  ┌─────────────────────────────────────┐ │
│  │  Node NestJS App (node dist/src/main)│ │
│  │  ├── HTTPS API (mTLS)               │ │
│  │  ├── Unix Socket (internal API)     │ │
│  │  ├── gRPC Client → Xray             │ │
│  │  └── nftables (IP blocking)         │ │
│  └─────────────────────────────────────┘ │
│                                           │
│  ┌─────────────────────────────────────┐ │
│  │  Xray-core                          │ │
│  │  ├── gRPC Server (mTLS, localhost)  │ │
│  │  ├── Inbounds (user traffic)        │ │
│  │  └── Outbounds (proxy destinations) │ │
│  └─────────────────────────────────────┘ │
│                                           │
│  Capabilities: NET_ADMIN                  │
│  Network: host (production)               │
└──────────────────────────────────────────┘
```

### 5.3 Communication Protocols

| Протокол | Между | Назначение |
|----------|-------|-----------|
| HTTPS + mTLS | Panel → Node | Все команды управления |
| HTTP (Unix Socket) | Node → Xray (config) | Конфигурация Xray |
| gRPC + mTLS | Node → Xray | Управление users, stats, routing |
| HTTP (REST) | Frontend → Backend | Административный UI |
| HTTP/HTTPS | Client → Backend | Получение подписки |
| Redis Pub/Sub | Backend → Backend | Межпроцессное общение |
| BullMQ (Redis) | Scheduler → Workers | Асинхронные задачи |
| XML-RPC (Unix Socket) | Node → Supervisord | Управление процессом Xray |
| HTTPS (Webhook) | Panel → External | Уведомления (Webhook) |
| HTTPS (Telegram API) | Panel → Telegram | Уведомления |

### 5.4 Environment Variables (Backend — полный список)

| Переменная | Тип | По умолчанию | Описание |
|-----------|-----|-------------|----------|
| `DATABASE_URL` | string | **required** | PostgreSQL DSN |
| `APP_PORT` | int | 3000 | Порт REST API |
| `METRICS_PORT` | int | 3001 | Порт Prometheus /metrics |
| `JWT_AUTH_SECRET` | string | **required** | Секрет JWT (авторизация админов) |
| `JWT_AUTH_LIFETIME` | int | 12 (часов) | Время жизни JWT |
| `JWT_API_TOKENS_SECRET` | string | **required** | Секрет JWT (API токены) |
| `FRONT_END_DOMAIN` | string | **required** | CORS origin |
| `PANEL_DOMAIN` | string | optional | Домен панели |
| `SUB_PUBLIC_DOMAIN` | string | **required** | Публичный домен подписок |
| `IS_DOCS_ENABLED` | bool | false | Включить Swagger/Scalar |
| `SWAGGER_PATH` | string | /docs | Путь к Swagger UI |
| `SCALAR_PATH` | string | /scalar | Путь к Scalar |
| `METRICS_USER` | string | **required** | Basic auth user для /metrics |
| `METRICS_PASS` | string | **required** | Basic auth pass для /metrics |
| `REDIS_HOST` | string | optional | Хост Redis (если не socket) |
| `REDIS_PORT` | int | optional | Порт Redis |
| `REDIS_SOCKET` | string | optional | Путь к Unix socket Redis |
| `REDIS_PASSWORD` | string | optional | Пароль Redis |
| `REDIS_DB` | int | 1 | Номер БД Redis |
| `IS_TELEGRAM_NOTIFICATIONS_ENABLED` | bool | false | Включить Telegram |
| `TELEGRAM_BOT_TOKEN` | string | optional | Токен бота Telegram |
| `TELEGRAM_BOT_API_ROOT` | string | https://api.telegram.org | API root Telegram |
| `TELEGRAM_BOT_PROXY` | string | optional | Прокси для Telegram |
| `TELEGRAM_NOTIFY_USERS` | string | optional | Chat ID для user events |
| `TELEGRAM_NOTIFY_NODES` | string | optional | Chat ID для node events |
| `TELEGRAM_NOTIFY_CRM` | string | optional | Chat ID для CRM events |
| `TELEGRAM_NOTIFY_SERVICE` | string | optional | Chat ID для service events |
| `TELEGRAM_NOTIFY_TBLOCKER` | string | optional | Chat ID для torrent events |
| `WEBHOOK_ENABLED` | bool | false | Включить Webhook |
| `WEBHOOK_URL` | string | optional | URL вебхука |
| `WEBHOOK_SECRET_HEADER` | string | optional | Секретный заголовок |
| `SHORT_UUID_LENGTH` | int | 16 | Длина короткого UUID |
| `IS_HTTP_LOGGING_ENABLED` | bool | false | Включить Morgan |
| `ENABLE_DEBUG_LOGS` | bool | false | Дебаг-логи |
| `SERVICE_CLEAN_USAGE_HISTORY` | bool | false | Очистка истории |
| `SERVICE_DISABLE_USER_USAGE_RECORDS` | bool | false | Отключить запись user usage |
| `BANDWIDTH_USAGE_NOTIFICATIONS_ENABLED` | bool | false | Уведомления о bandwidth |
| `BANDWIDTH_USAGE_NOTIFICATIONS_THRESHOLD` | JSON | optional | Пороги (25-95) |
| `NOT_CONNECTED_USERS_NOTIFICATIONS_ENABLED` | bool | false | Уведомления о неактивных |
| `NOT_CONNECTED_USERS_NOTIFICATIONS_AFTER_HOURS` | JSON | optional | Часы (1-168) |
| `USER_USAGE_IGNORE_BELOW_BYTES` | int | 0 | Игнорировать usage ниже |
| `REMNAWAVE_BRANCH` | string | dev | Ветка (dev/main) |

### 5.5 Environment Variables (Node — полный список)

| Переменная | Тип | По умолчанию | Описание |
|-----------|-----|-------------|----------|
| `NODE_PORT` | int | **required** | Порт HTTPS API |
| `SECRET_KEY` | string | **required** | Base64 JSON (сертификаты + JWT key) |
| `XTLS_API_PORT` | int | 61000 | Порт gRPC Xray |
| `INTERNAL_REST_TOKEN` | string | **generated** | Токен для internal API |
| `SUPERVISORD_USER` | string | **generated** | Supervisord auth |
| `SUPERVISORD_PASSWORD` | string | **generated** | Supervisord auth |
| `INTERNAL_SOCKET_PATH` | string | **generated** | Путь к Unix socket |
| `SUPERVISORD_SOCKET_PATH` | string | **generated** | Supervisord socket |
| `SUPERVISORD_PID_PATH` | string | **generated** | Supervisord pid |
| `DISABLE_HASHED_SET_CHECK` | bool | false | Отключить hash-оптимизацию |

---

## 6. DATA FLOWS (End-to-End)

### 6.1 User Creation Flow
```
Admin (Frontend) → POST /api/users → Backend API
  → UsersService.createUser()
  → Prisma: INSERT INTO users, user_traffic
  → EventEmitter: 'user.created'
  → Queue: NODES_BULK_USERS_QUEUE.add('add-user-to-nodes')
  → Worker: NodeProcessor.addUserToNodes()
    → For each node:
      → AxiosService: POST https://node:NODE_PORT/node/handler/add-user
      → Node HandlerService.addUser()
        → InternalService.addUserToInbound() (update HashedSet)
        → xtlsApi.handler.removeUser() (cleanup)
        → xtlsApi.handler.add{Vless/Trojan/SS}User()

Если node offline:
  → Ставится в очередь
  → Node health check (каждые 10 сек)
  → При reconnect: sync active profile
```

### 6.2 Traffic Monitoring Flow
```
Xray-core (каждый момент) → считает байты per-user
    ↑
    │ gRPC StatsService
    │
Scheduler (каждые 15 сек) → Enqueue: RECORD_USER_USAGE
Worker → POST /node/stats/get-users-stats?reset=true
  → Node StatsService.getUsersStats(reset: true)
    → xtlsSdk.stats.getAllUsersStats(true)
      ← Xray возвращает { user: { uplink, downlink } } и обнуляет счётчики
  → Worker: bulkUpsertHistoryEntry()
    → Prisma: UPSERT INTO nodes_user_usage_history
    → Prisma: UPDATE user_traffic (used_traffic_bytes += new)
    → Prisma: UPDATE nodes (traffic_used_bytes += new)
```

### 6.3 Subscription Request Flow
```
End User Client → GET https://sub.domain/api/sub/:shortUuid/:token
  → Backend SubscriptionController
  → SubscriptionService.getSubscription()
    → Find user by shortUuid
    → Validate token, status, expiration, traffic
    → Parse User-Agent (определить тип клиента)
    → Get hosts (filtered by squads, inbound access)
    → Get template (Xray JSON / Clash / Mihomo / Sing-box / Stash)
    → Apply response rules (middleware pipeline)
    → Render template
      → Inject hosts, users, certificates
      → Apply HWID settings
    → Log request (UserSubscriptionRequestHistory)
    → Return config text
```

---

## 7. CRITICAL ARCHITECTURAL DECISIONS

1. **Hash-based restart avoidance**: Node не перезапускает Xray-core если набор пользователей не изменился — уменьшает downtime.

2. **Три процесса вместо одного**: Разделение API, Scheduler и Workers в разные процессы (через PM2) даёт горизонтальное масштабирование API и Workers независимо.

3. **Contract-first с Zod**: Схемы API разделяются через npm пакет `@remnawave/backend-contract`, гарантируя согласованность frontend/backend без генерации кода.

4. **Двойной доступ к БД (Prisma + Kysely)**: Prisma для простых CRUD, Kysely для сложных аналитических запросов.

5. **mTLS для Node-Panel**: Вместо простого API-key используется полноценный mutual TLS с CA-подписанными сертификатами — zero-trust подход.

6. **Unix sockets для internal API на Node**: Вместо TCP — изоляция, производительность и отсутствие конфликтов портов.

7. **Nftables вместо iptables**: Нативная интеграция с nftables через nftables-napi (C++ binding) для блокировки IP — быстрее чем вызовы iptables из Node.

8. **Sockdestroy вместо ss/conntrack**: Прямое уничтожение TCP сокетов через /proc/net/tcp без форка shell-процессов.

9. **PM2 cluster mode**: Node.js однопоточный, PM2 позволяет использовать все ядра CPU (для API и Workers).

10. **Valkey вместо Redis**: Форк Redis с улучшенной производительностью, используемый через Unix socket (без TCP overhead).

---

*End of Stage 1 — ARCHITECTURE_RECONSTRUCTION.md*
