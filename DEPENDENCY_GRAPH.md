# DEPENDENCY INTELLIGENCE — Remnawave → AURORA

> **Stage 2: Dependency Intelligence**
> **Date:** 2026-06-23
> **Status:** COMPLETE

---

## 1. CROSS-COMPONENT DEPENDENCY MAP

```
┌─────────────────────────────────────────────────────────────────────┐
│                    REMNAWAVE DEPENDENCY ECOSYSTEM                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────────────┐                                           │
│  │  @remnawave/          │                                           │
│  │  backend-contract     │◄──────────────────────────┐               │
│  │  (API contracts, Zod) │                           │               │
│  └──────────┬───────────┘                            │               │
│             │                                        │               │
│    ┌────────┴────────┐                               │               │
│    ▼                 ▼                                │               │
│  ┌──────────┐  ┌──────────────┐                      │               │
│  │ Backend  │  │   Frontend   │                      │               │
│  │ NestJS   │  │  React SPA   │                      │               │
│  │ v2.7.4   │  │  v2.7.4      │                      │               │
│  └────┬─────┘  └──────────────┘                      │               │
│       │                                               │               │
│       │ @remnawave/node-contract v2.7.0              │               │
│       │                                               │               │
│       ▼                                               │               │
│  ┌──────────┐                                         │               │
│  │  Node    │  ◄── @remnawave/xtls-sdk               │               │
│  │ NestJS   │  ◄── @remnawave/node-plugins            │               │
│  │ v2.7.0   │  ◄── @remnawave/hashed-set              │               │
│  └──────────┘                                         │               │
│       │                                               │               │
│       │ gRPC (nice-grpc)                              │               │
│       ▼                                               │               │
│  ┌──────────┐                                         │               │
│  │ Xray-core│                                         │               │
│  │ (forked) │                                         │               │
│  └──────────┘                                         │               │
│                                                                      │
│  Shared npm packages (Remnawave org):                                │
│  ┌─────────────────────┐  ┌──────────────────┐  ┌───────────────┐  │
│  │ @remnawave/         │  │ @remnawave/       │  │ @remnawave/   │  │
│  │ subscription-page-  │  │ node-plugins      │  │ hashed-set    │  │
│  │ types v0.4.0        │  │ v0.4.4            │  │ v0.0.4        │  │
│  └─────────────────────┘  └──────────────────┘  └───────────────┘  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. BACKEND — MODULE DEPENDENCY GRAPH

### 2.1 Dependency Matrix (Module → Imports)

| Module | Imports (uses) | Imported By (used by) | Conditional |
|--------|---------------|----------------------|-------------|
| **AuthModule** | CqrsModule, JwtModule, HttpModule, AdminModule (queries), RemnawaveSettingsModule | AppModule (via RemnawaveModules) | `isRestApi()` |
| **UsersModule** | CqrsModule | NodesModule (queries), SubscriptionModule, HwidUserDevicesModule | ❌ Always |
| **NodesModule** | CqrsModule, ConfigProfileModule (queries), NodePluginModule (queries), NodesQueuesService (queue) | UsersModule (connected-node lookups), SubscriptionModule, InfraBillingModule | ❌ Always |
| **HostsModule** | CqrsModule, SubscriptionTemplateModule (for Xray JSON templates) | SubscriptionModule (host resolution), InternalSquadModule (exclusions) | ❌ Always |
| **SubscriptionModule** | CqrsModule, SubscriptionTemplateModule, SubscriptionResponseRulesModule, UsersModule, HostsModule, ExternalSquadModule | AppModule (via RemnawaveModules) | `isRestApi()` |
| **SubscriptionTemplateModule** | CqrsModule, KeygenModule (certs), RawCacheModule | SubscriptionModule | `isRestApi()` |
| **SubscriptionSettingsModule** | CqrsModule, RawCacheModule | SubscriptionModule (external squad overrides) | `isRestApi()` |
| **SubscriptionResponseRulesModule** | Middleware, Services | SubscriptionModule | `isRestApi()` |
| **SubscriptionPageConfigModule** | CqrsModule | ExternalSquadModule | `isRestApi()` |
| **KeygenModule** | CqrsModule | SubscriptionTemplateModule (cert resolution), NodesModule | ❌ Always |
| **ConfigProfileModule** | CqrsModule | NodesModule, HostsModule, InternalSquadModule | ❌ Always |
| **InternalSquadModule** | CqrsModule, HostsModule (exclusions), ConfigProfileModule (inbounds) | UsersModule (squad membership) | ❌ Always |
| **ExternalSquadModule** | CqrsModule, RemnawaveSettingsModule, SubscriptionPageConfigModule | UsersModule (external squad assignment), SubscriptionModule | ❌ Always |
| **HwidUserDevicesModule** | CqrsModule, UsersModule | SubscriptionModule (device limit check) | ❌ Always |
| **NodePluginModule** | CqrsModule | NodesModule, NodesQueuesService | ❌ Always |
| **IpControlModule** | CqrsModule | — (standalone) | `isRestApi()` |
| **AdminModule** | CqrsModule | AuthModule (admin lookup) | `isRestApi()` |
| **ApiTokensModule** | CqrsModule | AuthModule (API token JWT verification) | `isRestApi()` |
| **RemnawaveSettingsModule** | CqrsModule, RawCacheModule | AuthModule, ExternalSquadModule, SubscriptionSettingsModule, NodePluginModule | ❌ Always |
| **SystemModule** | CqrsModule, NodesModule, UsersModule | AppModule | `isRestApi()` |
| **InfraBillingModule** | CqrsModule, NodesModule | AppModule | ❌ Always |
| **MetadataModule** | CqrsModule | — (standalone) | `isRestApi()` |
| **NodesUsageHistoryModule** | CqrsModule, NodesModule | SystemModule (stats) | ❌ Always |
| **NodesUserUsageHistoryModule** | CqrsModule, NodesModule, UsersModule | Scheduler (usage recording) | ❌ Always |
| **NodesTrafficUsageHistoryModule** | CqrsModule, NodesModule | Scheduler (traffic reset) | ❌ Always |
| **UserSubscriptionRequestHistoryModule** | CqrsModule, UsersModule | SubscriptionModule (request logging) | ❌ Always |
| **RemnawaveServiceModule** | CqrsModule, EventEmitter2 | — | `isScheduler()` |

### 2.2 Critical Dependency Chains

#### Chain 1: User Subscription Delivery
```
SubscriptionModule
  └─► UsersModule (find user)
  └─► ExternalSquadModule (override settings)
  └─► HostsModule (get accessible hosts)
  └─► HwidUserDevicesModule (device limit check)
  └─► SubscriptionTemplateModule (render config)
        └─► KeygenModule (X25519 certs)
        └─► RawCacheModule (cached templates)
  └─► SubscriptionResponseRulesModule (headers/user-agent)
  └─► UserSubscriptionRequestHistoryModule (audit log)
```
**Risk:** Изменение любого модуля в цепочке ломает доставку подписок клиентам.

#### Chain 2: Node Lifecycle
```
NodesModule
  └─► ConfigProfileModule (active profile)
  └─► NodePluginModule (active plugin)
  └─► NodesQueuesService (BullMQ)
        └─► Node API (HTTP/mTLS)
  └─► NodesUsageHistoryModule (traffic history)
  └─► KeygenModule (JWT generation for node auth)
```
**Risk:** Изменение NodesModule критично — затрагивает все прокси-серверы.

#### Chain 3: Auth Flow
```
AuthModule
  └─► AdminModule (find admin by username)
  └─► ApiTokensModule (API token validation)
  └─► RemnawaveSettingsModule (auth method config)
  └─► JwtModule (token signing)
  └─► RawCacheModule (OAuth2 state, passkey challenges)
```
**Risk:** Изменение AuthModule блокирует доступ админов в панель.

### 2.3 Inter-Process Dependencies

```
┌─────────────────────────────────────────────────────────────┐
│                 INTER-PROCESS COMMUNICATION                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  API Process          Scheduler Process     Worker Process   │
│  (INSTANCE_TYPE=api)  (INSTANCE_TYPE=      (INSTANCE_TYPE=  │
│                        scheduler)           processor)       │
│                                                              │
│  ┌──────────┐         ┌──────────┐         ┌──────────┐    │
│  │ REST API │         │ Cron Jobs│         │ BullMQ   │    │
│  │ Controllers│       │ @Schedule│         │ Processors│    │
│  └────┬─────┘         └────┬─────┘         └────┬─────┘    │
│       │                    │                    │           │
│       │    Enqueue Jobs    │                    │           │
│       ├───────────────────►│                    │           │
│       │                    │    Enqueue Jobs    │           │
│       │                    ├───────────────────►│           │
│       │                    │                    │           │
│       ▼                    ▼                    ▼           │
│  ┌──────────────────────────────────────────────────┐      │
│  │              Redis / Valkey                       │      │
│  │  ┌─────────┐  ┌──────────┐  ┌───────────────┐   │      │
│  │  │ RawCache│  │ BullMQ   │  │ Pub/Sub       │   │      │
│  │  │ (ioredis)│  │ Queues   │  │ (EventEmitter) │   │      │
│  │  └─────────┘  └──────────┘  └───────────────┘   │      │
│  └──────────────────────────────────────────────────┘      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. BACKEND — NPM PACKAGE DEPENDENCY ANALYSIS

### 3.1 Framework Dependencies

| Package | Version | Used By | Risk if Changed |
|---------|---------|---------|-----------------|
| `@nestjs/common` | 11.1.17 | Every module | **CRITICAL** — весь backend |
| `@nestjs/core` | 11.1.17 | Bootstrap | **CRITICAL** — запуск приложения |
| `@nestjs/config` | 4.0.3 | CommonConfig | **HIGH** — вся конфигурация |
| `@nestjs/cqrs` | 11.0.3 | Все бизнес-модули | **CRITICAL** — CQRS паттерн везде |
| `@nestjs/jwt` | 11.0.2 | AuthModule, JwtGuard | **CRITICAL** — вся аутентификация |
| `@nestjs/passport` | 11.0.5 | AuthModule | **HIGH** — стратегии аутентификации |
| `@nestjs/bullmq` | 11.0.4 | QueueModule | **CRITICAL** — все очереди |
| `@nestjs/schedule` | 6.1.1 | SchedulerModule | **HIGH** — все cron-задачи |
| `@nestjs/event-emitter` | 3.0.1 | AppModule (global) | **MEDIUM** — события между модулями |
| `@nestjs/terminus` | 11.1.1 | HealthModule | **LOW** — health checks |
| `@nestjs/swagger` | 11.2.6 | main.ts (docs) | **LOW** — только документация |
| `@nestjs/microservices` | 11.1.17 | QueueModule (Redis) | **HIGH** — транспорт для очередей |

### 3.2 Database Dependencies

| Package | Version | Used By | Risk |
|---------|---------|---------|------|
| `@prisma/client` | 6.19.0 | PrismaService | **CRITICAL** — вся БД |
| `prisma` | 6.19.0 | CLI/migrations | **CRITICAL** — миграции |
| `prisma-kysely` | 2.2.1 | TxKyselyService | **MEDIUM** — сложные запросы |
| `kysely` | 0.28.11 | TxKyselyService | **MEDIUM** — typed SQL |
| `@prisma/adapter-pg` | 6.19.0 | PrismaService | **HIGH** — pg-native driver |

### 3.3 Redis Dependencies

| Package | Version | Used By | Risk |
|---------|---------|---------|------|
| `ioredis` | 5.9.3 | RawCacheModule | **CRITICAL** — весь кэш |
| `@songkeys/nestjs-redis` | 11.0.0 | RawCacheModule | **HIGH** — Redis NestJS модуль |
| `bullmq` | 5.69.3 | QueueModule | **CRITICAL** — все очереди |
| `@bull-board/api` | 6.18.2 | QueueModule (UI) | **LOW** — только мониторинг |

### 3.4 Security Dependencies

| Package | Version | Used By | Risk |
|---------|---------|---------|------|
| `@simplewebauthn/server` | 13.2.3 | AuthModule | **MEDIUM** — Passkey auth |
| `@noble/post-quantum` | 0.5.4 | KeygenModule | **MEDIUM** — постквантовые ключи |
| `@stablelib/x25519` | 2.0.1 | KeygenModule | **HIGH** — X25519 ключи |
| `@stablelib/base64` | 2.0.1 | KeygenModule | **HIGH** — кодирование ключей |
| `@peculiar/x509` | 1.14.3 | KeygenModule | **HIGH** — X.509 сертификаты |
| `@peculiar/webcrypto` | 1.5.0 | KeygenModule | **HIGH** — криптография |
| `jsonwebtoken` | 9.0.3 | AuthModule | **CRITICAL** — JWT signed/verify |
| `helmet` | 8.1.0 | main.ts | **MEDIUM** — security headers |
| `passport` | 0.7.0 | AuthModule | **HIGH** — auth framework |
| `passport-jwt` | 4.0.1 | JwtStrategy | **CRITICAL** — JWT стратегия |

### 3.5 Remnawave Internal Dependencies

| Package | Version | Used By | Risk |
|---------|---------|---------|------|
| `@remnawave/node-contract` | 2.7.0 | NodesModule, NodesQueuesService | **CRITICAL** — API контракт Node↔Backend |
| `@remnawave/xtls-sdk` | 0.8.0 | NodesModule | **HIGH** — Xray gRPC типы |
| `@remnawave/hashed-set` | 0.0.4 | NodesModule (node user tracking) | **MEDIUM** — hash-оптимизация |

### 3.6 Integration Dependencies

| Package | Version | Used By | Risk |
|---------|---------|---------|------|
| `grammy` | 1.41.1 | TelegramBotModule | **MEDIUM** — Telegram бот |
| `@grammyjs/parse-mode` | 1.11.1 | TelegramBotModule | **LOW** — форматирование |
| `arctic` | 3.7.0 | AuthModule (OAuth2) | **MEDIUM** — OAuth2 провайдеры |
| `axios` | 1.13.6 | AxiosModule, NodesQueuesService | **CRITICAL** — HTTP клиент |
| `prom-client` | 15.1.3 | PrometheusReporter | **MEDIUM** — метрики |
| `yaml` | 2.8.2 | SubscriptionTemplateModule | **HIGH** — YAML шаблоны |

---

## 4. FRONTEND — FSD LAYER DEPENDENCY GRAPH

### 4.1 FSD Layer Rules

```
app/       → imports from pages/, widgets/, features/, entities/, shared/
pages/     → imports from widgets/, features/, entities/, shared/
widgets/   → imports from features/, entities/, shared/
features/  → imports from entities/, shared/
entities/  → imports from shared/
shared/    → imports from nothing (leaf layer)
```

### 4.2 Domain Dependency Chains

#### Users Domain
```
pages/dashboard/users/
  └─► widgets/dashboard/users/ (UserTableWidget, modals, drawers)
       └─► features/dashboard/users/ (users-action-group, users-table)
       └─► entities/dashboard/users/ (users-table-store, bulk-store)
       └─► shared/api/hooks/users/ (useGetUsersV2, useCreateUser, ...)
            └─► @remnawave/backend-contract (DTOs, endpoints, schemas)
       └─► shared/ui/ (table, forms, modals, cards, ...)
```

#### Nodes Domain
```
pages/dashboard/nodes/
  └─► widgets/dashboard/nodes/ (NodeTable, modals, metrics)
       └─► features/dashboard/nodes/ (multi-select-nodes)
       └─► entities/dashboard/nodes/ (nodes-store)
       └─► shared/api/hooks/nodes/ (useGetNodes, useRestartNode, ...)
       └─► shared/ui/config-profiles/ (profile assignment)
```

#### Hosts Domain
```
pages/dashboard/hosts/
  └─► widgets/dashboard/hosts/ (HostTable, modals)
       └─► features/dashboard/hosts/ (filters, multi-select)
       └─► entities/dashboard/hosts/ (hosts-store)
       └─► shared/api/hooks/hosts/ (useGetHosts, useCreateHost, ...)
```

#### Templates Domain
```
pages/dashboard/templates/
  └─► widgets/dashboard/templates/ (TemplateEditor)
       └─► features/dashboard/subscription-templates/ (editor-actions)
       └─► features/dashboard/config-profiles/ (monaco-setup)
       └─► shared/api/hooks/subscription-template/
       └─► shared/ui/ (Monaco editor, spotlight)
```

### 4.3 Shared API Hook → Backend Contract Mapping

| Frontend Hook | Backend Contract Command | HTTP Method | Endpoint |
|---------------|-------------------------|-------------|----------|
| `useGetUsersV2` | `GetAllUsersCommand` | GET | `/api/users` |
| `useCreateUser` | `CreateUserCommand` | POST | `/api/users` |
| `useGetNodes` | `GetAllNodesCommand` | GET | `/api/nodes` |
| `useRestartNode` | `RestartNodeCommand` | POST | `/api/nodes/:uuid/restart` |
| `useGetHosts` | `GetAllHostsCommand` | GET | `/api/hosts` |
| `useCreateHost` | `CreateHostCommand` | POST | `/api/hosts` |
| `useLogin` | `LoginCommand` | POST | `/api/auth/login` |
| `useGetAuthStatus` | `GetAuthStatusCommand` | GET | `/api/auth/status` |
| `useGetSystemStats` | `GetSystemStatsCommand` | GET | `/api/system/stats` |
| `useGetSubscriptionSettings` | `GetSubscriptionSettingsCommand` | GET | `/api/subscription-settings` |
| `useGetTemplates` | `GetAllTemplatesCommand` | GET | `/api/subscription-templates` |
| `useGetConfigProfiles` | `GetAllConfigProfilesCommand` | GET | `/api/config-profiles` |
| `useGetInternalSquads` | `GetAllInternalSquadsCommand` | GET | `/api/internal-squads` |
| `useGetExternalSquads` | `GetAllExternalSquadsCommand` | GET | `/api/external-squads` |
| `useGetNodePlugins` | `GetAllNodePluginsCommand` | GET | `/api/node-plugins` |
| `useGetInfraBilling` | `GetInfraBillingCommand` | GET | `/api/infra-billing` |
| `useGetApiTokens` | `GetAllApiTokensCommand` | GET | `/api/api-tokens` |
| `useGetPasskeys` | `GetAllPasskeysCommand` | GET | `/api/admin/passkeys` |
| `useGetRemnawaveSettings` | `GetRemnawaveSettingsCommand` | GET | `/api/remnawave-settings` |
| `useGetBandwidthStats` | `GetBandwidthStatsCommand` | GET | `/api/bandwidth-stats` |
| `useGetHwidDevices` | `GetHwidDevicesCommand` | GET | `/api/hwid-user-devices` |
| `useGetSubpageConfigs` | `GetAllSubpageConfigsCommand` | GET | `/api/subpage-configs` |
| `useGetSnippets` | `GetAllSnippetsCommand` | GET | `/api/snippets` |

### 4.4 Zustand Store Dependencies

| Store | Persisted | Depends On | Used By |
|-------|-----------|------------|---------|
| `sessionStore` | ✅ localStorage | — | Axios interceptor, AuthProvider, AuthGuard |
| `usersTableStore` | ✅ localStorage (v8) | — | UserTableWidget |
| `updatesStore` | ✅ localStorage (24h TTL) | GitHub API (ungh.cc) | Header buttons |
| `nodesStore` | ❌ (reset on logout) | — | Node modals |
| `appshellStore` | ❌ (reset on logout) | — | MainLayout sidebar |
| `userModalStore` | ❌ (reset on logout) | — | User detail modals |
| `bulkUsersActionsStore` | ❌ (reset on logout) | — | Bulk user operations |
| `hostsStore` | ❌ (reset on logout) | — | Host modals |
| `modalStore` | ❌ (reset on logout) | — | Various modals |

### 4.5 Key State Dependencies (from package.json)

| Category | Key Packages | Bundle Size Impact |
|----------|-------------|-------------------|
| **React Core** | react 19, react-dom 19, react-router-dom 6.27 | ~45KB gzip |
| **UI Framework** | @mantine/* 8.3.18 (16 packages) | ~130KB gzip |
| **Data Fetching** | @tanstack/react-query 5.85, axios 1.13 | ~20KB gzip |
| **Tables** | mantine-react-table 2.0, mantine-datatable 8.3 | ~80KB gzip |
| **Charts** | highcharts 12, recharts 2.15 | ~180KB gzip |
| **Code Editor** | monaco-editor 0.52, monaco-yaml 5.4 | ~350KB gzip (lazy) |
| **i18n** | i18next 25, react-i18next 16 | ~15KB gzip |
| **Drag & Drop** | @dnd-kit/* 6-10 | ~12KB gzip |
| **Crypto** | @stablelib/*, @noble/post-quantum | ~30KB gzip |
| **Backend Contract** | @remnawave/backend-contract 2.7.2 | ~3.5KB gzip |

---

## 5. NODE — MODULE DEPENDENCY GRAPH

### 5.1 Internal Module Dependencies

```
RemnawaveNodeModules
├── XrayModule ─────────────────────────────────────┐
│   ├──► InternalService (HashedSet, config store)   │
│   ├──► PluginStateService (torrent blocker state)  │
│   ├──► NetworkStatsService (interface rates)       │
│   └──► SupervisordApi (process control)            │
│                                                     │
├── InternalModule (@Global) ◄───────────────────────┘
│   ├── Stores current Xray config
│   ├── HashedSet per inbound (hash optimization)
│   └── Webhook event publishing
│
├── HandlerModule ──────────────────────────────────┐
│   ├──► XtlsApi.handler (Xray gRPC)                 │
│   ├──► InternalService (HashedSet sync)            │
│   └──► PluginStateService (drop connections)       │
│                                                     │
├── StatsModule ────────────────────────────────────┐
│   ├──► XtlsApi.stats (Xray gRPC)                   │
│   ├──► NetworkStatsService (interface rates)        │
│   └──► PluginStateService (torrent report count)   │
│                                                     │
├── PluginModule (_plugin) ◄────────────────────────┘
│   ├──► NftService (nftables-napi)
│   ├──► PluginStateService
│   ├──► InternalService (Xray restart decision)
│   └──► EventBus (XrayWebhook, DropConnections)
│
└── NetworkStatsModule
    └──► /proc/net/dev polling
```

### 5.2 Node npm Dependencies — Critical Paths

| Category | Package | Used By | Risk |
|----------|---------|---------|------|
| **Xray Communication** | `@remnawave/xtls-sdk` 0.12.1 | XrayModule, Handler, Stats, Plugin | **CRITICAL** |
| | `@remnawave/xtls-sdk-nestjs` 0.6.1 | AppModule (gRPC client) | **CRITICAL** |
| | `nice-grpc` 2.1.14 | XtlsSdk (underlying) | **CRITICAL** |
| **Process Control** | `@remnawave/supervisord-nestjs` 0.3.1 | XrayModule | **CRITICAL** |
| | `@kastov/node-supervisord` 2.0.3 | Supervisord API | **CRITICAL** |
| **Contract** | `@remnawave/node-contract` (libs/) | Все модули | **CRITICAL** |
| **Plugins** | `@remnawave/node-plugins` 0.4.4 | PluginModule | **HIGH** |
| **Optimization** | `@remnawave/hashed-set` 0.0.4 | InternalService | **MEDIUM** |
| **Security** | `nftables-napi` 0.4.2 | NftService | **HIGH** |
| | `sockdestroy` 1.3.0 | DropConnections | **HIGH** |
| | `@peculiar/x509` 1.14.3 | generate-mtls-certs | **CRITICAL** |
| | `@peculiar/webcrypto` 1.5.0 | generate-mtls-certs | **CRITICAL** |
| **Auth** | `passport-jwt` 4.0.1 | JwtGuard | **CRITICAL** |
| | `@nestjs/jwt` 11.0.2 | JwtModule | **CRITICAL** |
| **Networking** | `helmet` 8.1.0 | main.ts | **MEDIUM** |
| | `compression` 1.8.1 | main.ts | **LOW** |
| **Utilities** | `p-retry` 6.2.1 | XrayService (health check) | **MEDIUM** |
| | `p-map` 7.0.4 | StatsService, InternalService | **MEDIUM** |

### 5.3 Xray-Core Dependency

```
Node Agent ──gRPC (mTLS)──► Xray-core (rw-core fork)
    │                          │
    │  HandlerService API      ├── addUser/removeUser (per protocol)
    │  StatsService API        ├── getStats/getSysStats
    │  RoutingService API      ├── addSrcIpRule/removeRule
    │                          └── Webhook → /internal/webhook
    │
    └── Supervisord (XML-RPC) ──► start/stop Xray процесс
```

---

## 6. RISK ASSESSMENT MATRIX

### 6.1 CRITICAL Risk — Изменение затронет production

| Компонент | Причина | Последствия изменения |
|-----------|--------|----------------------|
| `@remnawave/backend-contract` | Общий контракт между frontend и backend | Поломка всех API-вызовов, необходимость синхронного обновления frontend+backend |
| `@remnawave/node-contract` | Общий контракт между backend и node | Поломка управления нодами, невозможность старта/стопа Xray |
| Prisma Schema | 36 таблиц, 84 миграции | Потеря/повреждение данных, несовместимость API |
| `AuthModule` + JWT | Единственная точка входа админов | Блокировка доступа ко всей панели |
| `BullMQ` (Redis) | Все очереди и межпроцессное взаимодействие | Отказ scheduler, workers, потеря асинхронных операций |
| `SubscriptionModule` | Доставка конфигов клиентам | Все клиенты теряют доступ к подпискам |
| `XrayService` (Node) | Управление Xray-core | Все прокси-серверы перестают работать |
| mTLS сертификаты (Node) | Доверенная цепочка сертификатов | Потеря связи Panel↔Node |

### 6.2 HIGH Risk — Значительное влияние

| Компонент | Причина |
|-----------|--------|
| `NodesModule` | Управление всеми прокси-нодами |
| `HostsModule` | Конфигурация inbound/outbound |
| `UsersModule` | Управление пользователями VPN |
| `KeygenModule` | Генерация ключей X25519 и сертификатов |
| `ConfigProfileModule` | Xray конфигурационные профили |
| `InternalSquadModule` | Группировка пользователей |
| `ExternalSquadModule` | Внешние группы с оверрайдами |
| `SubscriptionTemplateModule` | Генераторы конфигов (5 форматов) |
| `PluginModule` (Node) | Nftables блокировки, torrent blocker |
| `InternalService` (Node) | Hash-оптимизация, хранение конфига |
| `HttpJwtAuthGuard` (Frontend) | Защита всех маршрутов |
| `Axios instance` (Frontend) | Все API-вызовы |
| Zustand `create` wrapper (Frontend) | Сброс всех stores при logout |

### 6.3 MEDIUM Risk — Умеренное влияние

| Компонент | Причина |
|-----------|--------|
| `HwidUserDevicesModule` | Отслеживание устройств |
| `RemnawaveSettingsModule` | Глобальные настройки панели |
| `InfraBillingModule` | Билинг инфраструктуры |
| `TelegramBotModule` | Уведомления |
| `PrometheusReporter` | Метрики мониторинга |
| `SchedulerModule` | Cron-задачи |
| `NetworkStatsModule` (Node) | Статистика интерфейсов |
| Mantine theme (Frontend) | Визуальная тема |
| Query key factory (Frontend) | Инвалидация кэша |

### 6.4 LOW Risk — Минимальное влияние

| Компонент | Причина |
|-----------|--------|
| `ApiTokensModule` | API токены (вспомогательная функция) |
| `IpControlModule` | IP-контроль |
| `MetadataModule` | Метаданные (опционально) |
| `HealthModule` | Health-check endpoint |
| Swagger/Scalar | Только документация |
| Bull Board | Только мониторинг очередей |
| i18n translations | Локализация |
| Lottie animations | Декоративные анимации |

---

## 7. CHANGE PROPAGATION ANALYSIS

### 7.1 Если изменить Prisma Schema (добавить поле в users):

```
Prisma Schema
  → prisma generate (PrismaService + Kysely types)
  → Prisma migration
  → Все repositories, использующие Users (8+ модулей)
  → Все NestJS DTOs для users
  → @remnawave/backend-contract (если поле API-доступно)
  → Frontend: Zod схемы, типы, формы, таблицы
  → Node: без изменений (Node не работает с БД)
```

### 7.2 Если изменить backend API endpoint:

```
Backend Controller
  → @remnawave/backend-contract (обновить Command)
  → Frontend: API hook → types → pages/widgets
  → Документация (OpenAPI spec)
  → Node: без изменений (другой контракт)
```

### 7.3 Если изменить Node API endpoint:

```
Node Controller
  → @remnawave/node-contract (обновить Command)
  → Backend: NodesQueuesService → Axios calls
  → Backend: NodesModule
  → Frontend: без прямого влияния (через backend)
```

### 7.4 Если изменить shared npm пакет:

```
@remnawave/backend-contract
  → Backend: все модули (пересборка)
  → Frontend: все API hooks + Zod валидация (пересборка)
  → Необходимость синхронного релиза обоих компонентов

@remnawave/node-contract
  → Node: все модули (пересборка)
  → Backend: NodesQueuesService (пересборка)
  → Необходимость синхронного релиза

@remnawave/node-plugins
  → Node: PluginModule
  → Backend: NodePluginModule
  → Frontend: NodePlugin editor (через backend-contract)
```

---

## 8. CIRCULAR DEPENDENCY ANALYSIS

### 8.1 Найденные циклические зависимости

**Backend:**
- `NodesModule ↔ ConfigProfileModule` (Node имеет активный профиль, профиль привязан к Node через ConfigProfileInboundsToNodes)
- `NodesModule ↔ NodePluginModule` (Node имеет активный плагин, плагин назначается Node)
- `UsersModule ↔ NodesModule` (User связан с Node через UserTraffic.lastConnectedNodeUuid, Node хранит usage per user)
- `HostsModule ↔ ConfigProfileModule` (Host привязан к Profile Inbound, Inbound содержит Hosts)

**Статус:** Все циклические зависимости разорваны через ID-связи (UUID) без прямых импортов модулей друг в друга. NestJS DI разрешает их корректно через `forwardRef()`.

### 8.2 Потенциально опасные связи

- `SubscriptionModule → SubscriptionTemplateModule → KeygenModule → RawCacheModule` — длинная цепочка зависимостей для доставки подписок
- `Scheduler → NodesQueuesService → AxiosService → Node API` — межпроцессная цепочка с сетевым вызовом
- `AuthProvider → sessionStore → axios token → 401 → logoutEvents → AuthProvider` — циклический событийный поток (корректно обрабатывается через guard `isLoggedOut`)

---

## 9. DEPENDENCY HEALTH INDICATORS

### 9.1 Версионная согласованность

| Компонент | Версия | Статус |
|-----------|--------|--------|
| Backend ↔ Frontend | 2.7.4 ↔ 2.7.4 | ✅ Согласовано |
| Backend ↔ Node | 2.7.4 ↔ 2.7.0 | ⚠️ Расхождение minor |
| backend-contract | 2.7.2 | ⚠️ Отстаёт от backend 2.7.4 |
| node-contract | 2.7.0 | ✅ Согласовано с node |
| xtls-sdk (backend) | 0.8.0 | ⚠️ Старая версия |
| xtls-sdk (node) | 0.12.1 | ✅ Актуальная |
| node-plugins | 0.4.4 | ✅ Единая версия |
| NestJS | 11.x (везде) | ✅ Единый мажорный |
| Prisma | 6.19.0 | ✅ Стабильный |

### 9.2 Неиспользуемые зависимости (potential dead weight)

- Backend: `convert-units`, `try`, `transliteration`, `cookie-parser` (закомментировано), `xray-typed` (возможно не используется)
- Frontend: `@formkit/auto-animate`, `@gfazioli/*` пакеты, `react-country-flag`, `react-layout-masonry`
- Node: `undici`, `json-colorizer`

---

*End of Stage 2 — DEPENDENCY_GRAPH.md*
