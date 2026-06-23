# REPOSITORY MAP — Remnawave → AURORA

> **Stage 0: Project Forensics**
> **Date:** 2026-06-23
> **Status:** COMPLETE

---

## 1. SYSTEM OVERVIEW

Remnawave — это модульная система управления прокси-серверами на базе Xray-core. Состоит из 4-х основных репозиториев и нескольких вспомогательных.

### Архитектурная схема

```
┌──────────────────────────────────────────────────────────────┐
│                    REMNAWAVE ECOSYSTEM                        │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │   FRONTEND   │    │   BACKEND    │    │  SUBSCRIPTION │   │
│  │  (React SPA)  │◄──►│  (NestJS API)│    │     PAGE      │   │
│  │              │    │              │    │  (Next.js?)   │   │
│  └──────────────┘    └──────┬───────┘    └──────────────┘   │
│                             │                                 │
│                             │ Redis/Valkey                   │
│                             │ BullMQ                          │
│                             ▼                                 │
│                      ┌──────────────┐                        │
│                      │  PostgreSQL  │                        │
│                      └──────────────┘                        │
│                             │                                 │
│                             │ HTTP/HTTPS (mTLS)               │
│                             ▼                                 │
│               ┌─────────────────────────┐                    │
│               │      NODE (Edge Agent)  │                    │
│               │  ┌───────────────────┐  │                    │
│               │  │    Xray-core      │  │                    │
│               │  │  (gRPC + mTLS)    │  │                    │
│               │  └───────────────────┘  │                    │
│               └─────────────────────────┘                    │
│                                                               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │  PANEL DOCS  │    │  XTLS-SDK    │    │  MIGRATE (Go) │   │
│  │  (Docusaurus)│    │ (TypeScript) │    │              │   │
│  └──────────────┘    └──────────────┘    └──────────────┘   │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

---

## 2. PRIMARY REPOSITORIES

### 2.1 BACKEND (`remnawave/backend`) — ⭐ CRITICAL

| Параметр | Значение |
|----------|---------|
| **Назначение** | Центральный API-сервер. Оркестрация пользователей, нод, подписок, конфигов. |
| **Уровень критичности** | `CRITICAL` — ядро системы |
| **Язык** | TypeScript (strict mode) |
| **Фреймворк** | NestJS 11 (CommonJS) |
| **База данных** | PostgreSQL (Prisma ORM + Kysely Query Builder) |
| **Кэш/Очереди** | Redis/Valkey (BullMQ + Pub/Sub) |
| **Версия** | v2.7.4 |
| **Лицензия** | AGPL-3.0-only |
| **Размер** | ~1790 файлов |

#### Дерево ключевых директорий

```
backend_source/
├── src/
│   ├── main.ts                          # 🔷 ENTRY: REST API (Express + Swagger)
│   ├── app.module.ts                    # Root NestJS module
│   ├── bin/
│   │   ├── scheduler/scheduler.ts       # 🔷 ENTRY: Cron scheduler process
│   │   └── processors/processors.ts     # 🔷 ENTRY: BullMQ worker process
│   ├── common/                          # ⚙️ Инфраструктура
│   │   ├── config/                      # JWT, App конфигурация (Zod)
│   │   ├── database/                    # PrismaService, TxKyselyService
│   │   ├── decorators/                  # @GetIp, @GetJwtPayload, @Roles, etc.
│   │   ├── guards/                      # JWT Guards, Roles Guard, Proxy Check
│   │   ├── middlewares/                 # Basic Auth, Real IP, Cookie Check
│   │   └── utils/                       # Certs, HWID, VLESS, NanoID, etc.
│   ├── modules/                         # 📦 Бизнес-модули (20+ модулей)
│   │   ├── auth/                        # Аутентификация (JWT, OAuth2, Passkey)
│   │   ├── users/                       # Управление пользователями VPN
│   │   ├── nodes/                       # Управление прокси-нодами
│   │   ├── hosts/                       # Управление хостами (inbound destinations)
│   │   ├── subscription/                # Публичные endpoint'ы подписок
│   │   ├── subscription-template/       # Генераторы конфигов (Xray, Clash, Sing-box...)
│   │   ├── subscription-settings/       # Настройки подписок
│   │   ├── subscription-response-rules/ # Правила ответа подписок
│   │   ├── subscription-page-configs/   # Конфиг страницы подписки
│   │   ├── keygen/                      # X25519, сертификаты
│   │   ├── config-profiles/             # Профили конфигурации Xray
│   │   ├── internal-squads/             # Внутренние группы пользователей
│   │   ├── external-squads/             # Внешние группы пользователей
│   │   ├── hwid-user-devices/           # Hardware ID tracking
│   │   ├── node-plugins/                # Плагины нод (торрент-блокер)
│   │   ├── ip-control/                  # IP-based access control
│   │   ├── api-tokens/                  # Управление API токенами
│   │   ├── admin/                       # Управление админами
│   │   ├── remnawave-settings/          # Глобальные настройки панели
│   │   ├── system/                      # Системная статистика
│   │   ├── infra-billing/               # Билинг инфраструктуры
│   │   ├── nodes-usage-history/         # История использования нод
│   │   ├── nodes-user-usage-history/    # История использования пользователей
│   │   ├── nodes-traffic-usage-history/ # История трафика нод
│   │   ├── user-subscription-request-history/ # История запросов подписок
│   │   └── metadata/                    # Метаданные пользователей/нод
│   ├── queue/                           # 🔄 BullMQ система очередей
│   │   ├── _nodes/                      # Очереди нод (health-check, usage, sync)
│   │   ├── _users/                      # Очереди пользователей (watchdog, reset, bulk)
│   │   ├── _squads/                     # Очереди групп
│   │   ├── notifications/               # Telegram + Webhook уведомления
│   │   ├── push-from-redis/             # Redis Pub/Sub → BullMQ мост
│   │   └── service/                     # Сервисные задачи (vacuum, cleanup)
│   ├── scheduler/                       # ⏰ Cron-задачи
│   │   ├── enqueue/                     # Задачи, ставящие jobs в BullMQ
│   │   └── tasks/                       # Прямые задачи (crm, metrics, reset)
│   └── integration-modules/             # 🔌 Интеграции
│       ├── health/                      # Health-check endpoint
│       ├── notifications/               # Telegram Bot (Grammy) + Webhook
│       └── prometheus-reporter/         # Prometheus /metrics
├── prisma/
│   ├── schema.prisma                    # 36 моделей данных
│   ├── migrations/                      # 84 миграции
│   └── seed/                            # Сиды (настройки, шаблоны, админ)
├── libs/
│   ├── contract/                        # @remnawave/backend-contract (API контракты)
│   ├── hashed-set/                      # Утилита: hashed-set
│   ├── node-plugins/                    # Модели плагинов нод
│   └── subscription-page/               # Схемы/валидаторы страницы подписки
├── configs/
│   ├── notifications/                   # YAML шаблоны уведомлений
│   └── xray/ssl/                        # SSL сертификаты Xray
├── docker-compose-*.yml                 # 7 Docker Compose файлов
├── Dockerfile                           # Multi-stage (Alpine → Debian Trixie)
├── ecosystem.config.js                  # PM2: api (cluster), scheduler (fork), jobs (cluster)
└── docker-entrypoint.sh                 # Миграции + seeds + PM2 запуск
```

#### Точки входа

| Entry Point | Файл | Процесс | Порт |
|------------|------|---------|------|
| REST API | `src/main.ts` | PM2 cluster | 3003 |
| Scheduler | `bin/scheduler/scheduler.ts` | PM2 fork (1 instance) | — |
| Job Worker | `bin/processors/processors.ts` | PM2 cluster | — |
| CLI | `bin/cli/cli.ts` | `remnawave` command | — |
| OpenAPI Gen | `bin/gen-doc/gen-doc.ts` | CLI only | — |

#### Зависимости

| Зависимость | Роль |
|------------|------|
| `@remnawave/backend-contract` | Общие контракты API (свой lib) |
| `@remnawave/node-contract` | Контракты для общения с node |
| `@remnawave/subscription-page-types` | Типы страницы подписки |
| PostgreSQL | Персистентное хранение |
| Redis/Valkey | Кэширование, очереди BullMQ, Pub/Sub |
| Grammy | Telegram Bot API |
| Prometheus | Метрики |

---

### 2.2 FRONTEND (`remnawave/frontend`) — ⭐ CRITICAL

| Параметр | Значение |
|----------|---------|
| **Назначение** | Административная панель управления (SPA) |
| **Уровень критичности** | `CRITICAL` — основной интерфейс управления |
| **Язык** | TypeScript 5.9 |
| **Фреймворк** | React 19 + Vite 7.3 |
| **Архитектура** | Feature-Sliced Design (FSD) |
| **UI Kit** | Mantine v8.3.18 |
| **State** | Zustand 5.0 + TanStack React Query 5.85 |
| **Версия** | v2.7.4 |
| **Лицензия** | AGPL-3.0-only |
| **Размер** | ~1190 файлов |

#### Дерево ключевых директорий

```
frontend_source/
├── src/
│   ├── main.tsx                         # 🔷 ENTRY: React mount point
│   ├── app.tsx                          # Root component (providers)
│   ├── app/
│   │   ├── router/router.tsx            # React Router v6 tree
│   │   ├── layouts/
│   │   │   ├── auth/auth.layout.tsx     # Auth layout (login page)
│   │   │   └── dashboard/main-layout/   # Main shell (AppShell + navbar)
│   │   └── i18n/i18n.ts                # i18next (en, ru, fa, zh)
│   ├── pages/                           # 📄 Страницы (маршруты → страницы)
│   │   ├── auth/login/                  # Страница входа
│   │   ├── dashboard/
│   │   │   ├── home/                    # Дашборд с метриками
│   │   │   ├── users/                   # Управление пользователями
│   │   │   ├── hosts/                   # Управление хостами
│   │   │   ├── nodes/                   # Управление нодами
│   │   │   ├── config-profiles/         # Профили конфигурации
│   │   │   ├── templates/               # Редактор шаблонов конфигов
│   │   │   ├── subscription-settings/   # Настройки подписки
│   │   │   ├── subpage-config/          # Кастомизация страницы подписки
│   │   │   ├── internal-squads/         # Внутренние группы
│   │   │   ├── external-squads/         # Внешние группы
│   │   │   ├── remnawave-settings/      # Глобальные настройки
│   │   │   ├── node-plugins/            # Плагины нод
│   │   │   ├── nodes-bandwidth-table/   # Таблица bandwidth
│   │   │   ├── nodes-metrics/           # Метрики нод
│   │   │   ├── statistic-nodes/         # Статистика нод
│   │   │   ├── hwid-inspector/          # HWID инспектор
│   │   │   ├── srh-inspector/           # Инспектор запросов подписок
│   │   │   ├── sessions-explorer/       # Активные сессии
│   │   │   ├── torrent-blocker-reports/ # Отчеты торрент-блокера
│   │   │   └── crm/infra-billing/       # Билинг инфраструктуры
│   │   └── errors/                      # 404, 500 страницы
│   ├── widgets/                         # 🧩 Составные UI блоки
│   │   └── dashboard/                   # Виджеты по доменам
│   │       ├── users/                   # User table, modals, bulk actions
│   │       ├── nodes/                   # Node cards, tables, metrics
│   │       ├── hosts/                   # Host modals, tables
│   │       ├── templates/              # Template editor widgets
│   │       ├── config-profiles/         # Config editor, keypair generator
│   │       ├── internal-squads/         # Squad cards, grids
│   │       ├── external-squads/         # Squad cards, grids
│   │       ├── subscription-settings/   # Settings widgets
│   │       ├── subpage-configs/         # Subpage editor widgets
│   │       ├── response-rules/          # Response rules editor
│   │       ├── hwid-inspector/          # HWID table, leaderboard
│   │       ├── srh-inspector/           # SRH table
│   │       ├── sessions-explorer/       # Sessions grid
│   │       ├── node-plugins/            # Plugin cards, editors
│   │       ├── nodes-bandwidth-table/   # Bandwidth widget
│   │       ├── nodes-statistic/         # Charts
│   │       ├── torrent-blocker-reports/ # TB reports
│   │       ├── infra-billing/           # Billing widgets
│   │       └── recap/                   # Recap content
│   ├── features/                        # 🎯 Пользовательские взаимодействия
│   │   ├── auth/                        # Login/Register/Passkey/OAuth2 forms
│   │   └── dashboard/                   # Domain-specific features
│   ├── entities/                        # 🏗️ Бизнес-сущности (Zustand stores)
│   │   ├── auth/session-store/          # Auth token store
│   │   └── dashboard/                   # Domain stores (users, nodes, hosts, modals...)
│   └── shared/                          # 🔧 Инфраструктура
│       ├── api/                         # Axios + React Query hooks
│       │   ├── axios.ts                 # HTTP client (JWT interceptor)
│       │   ├── query-client.ts          # TanStack Query config
│       │   ├── tsq-helpers/             # Generic hook factories
│       │   └── hooks/                   # Domain-specific API hooks (22 домена)
│       ├── ui/                          # Общие UI компоненты (45+ компонентов)
│       ├── constants/                   # Роуты, тема, формы
│       ├── hocs/                        # AuthGuard, ErrorBoundary, StoreWrapper
│       ├── utils/                       # Утилиты (bytes, time, misc)
│       ├── hooks/                       # useAuth, usePreventBackNavigation
│       └── workers/                     # Web Workers (Highcharts data)
├── public/
│   ├── locales/                         # i18n JSON (en, ru, fa, zh)
│   ├── favicons/                        # PWA иконки
│   └── lotties/                         # Lottie анимации
└── vite.config.ts                       # Vite: port 3333, manual chunks
```

#### Точки входа

| Entry Point | Файл | Описание |
|------------|------|---------|
| SPA Entry | `src/main.tsx` | Монтирование React в DOM |
| HTML | `index.html` | Точка входа браузера (PWA, шрифты, splash) |
| Router | `src/app/router/router.tsx` | Дерево маршрутов React Router |

#### Зависимости

| Зависимость | Роль |
|------------|------|
| `@remnawave/backend-contract` | Zod-схемы API, общие типы |
| `@remnawave/subscription-page-types` | Типы страницы подписки |
| Backend API | Все данные через REST API |
| Mantine | Полный UI kit |
| Monaco Editor | Редактор YAML/JSON конфигов |
| Highcharts + Recharts | Графики и чарты |
| @dnd-kit | Drag & Drop |

---

### 2.3 NODE (`remnawave/node`) — ⭐ CRITICAL

| Параметр | Значение |
|----------|---------|
| **Назначение** | Edge-агент на прокси-серверах. Управляет Xray-core. |
| **Уровень критичности** | `CRITICAL` — data plane, обработка трафика |
| **Язык** | TypeScript |
| **Фреймворк** | NestJS 11 (CommonJS) |
| **Язык общения с Xray** | gRPC (mTLS) |
| **Управление Xray** | Supervisord (XML-RPC) |
| **Версия** | v2.7.0 |
| **Лицензия** | AGPL-3.0-only |
| **Размер** | ~271 файлов |

#### Дерево ключевых директорий

```
node_source/
├── src/
│   ├── main.ts                          # 🔷 ENTRY: HTTPS + Unix Socket серверы
│   ├── app.module.ts                    # Root NestJS module
│   ├── common/
│   │   ├── config/                      # JWT, App конфигурация (Zod)
│   │   ├── guards/jwt-guards/           # JWT Auth Guard (RS256)
│   │   ├── middlewares/token-auth.middleware.ts  # Token auth для internal
│   │   └── utils/
│   │       ├── generate-api-config.ts   # ⭐ КЛЮЧ: слияние конфига панели + Xray API
│   │       ├── generate-mtls-certs/     # ⭐ Генерация mTLS сертификатов
│   │       ├── decode-node-payload/     # ⭐ Декодирование SECRET_KEY → сертификаты
│   │       └── get-system-stats/        # CPU/load метрики
│   ├── modules/
│   │   ├── xray-core/                   # ⭐ Управление жизненным циклом Xray
│   │   │   ├── xray.service.ts         # startXray, stopXray, healthcheck
│   │   │   └── xray.controller.ts      # POST /node/xray/start|stop|healthcheck
│   │   ├── internal/                    # ⭐ Внутренний API (Unix Socket)
│   │   │   ├── internal.service.ts     # HashedSet users, hash comparison
│   │   │   └── internal.controller.ts  # GET /internal/get-config, POST /internal/webhook
│   │   ├── handler/                     # 👤 Управление пользователями Xray
│   │   │   ├── handler.service.ts      # addUser, removeUser, dropConnections
│   │   │   └── handler.controller.ts   # REST endpoints
│   │   ├── stats/                       # 📊 Статистика трафика
│   │   │   ├── stats.service.ts        # gRPC запросы к Xray StatsService
│   │   │   └── stats.controller.ts     # REST endpoints
│   │   ├── vision/                      # 🚫 IP Block/Unblock
│   │   │   └── vision.service.ts       # Xray RoutingService: addSrcIpRule
│   │   ├── _plugin/                     # 🔌 Плагины
│   │   │   ├── plugin.service.ts       # Синхронизация плагинов
│   │   │   ├── services/nft.service.ts # nftables (блокировка IP)
│   │   │   ├── services/plugin-state.service.ts
│   │   │   ├── events/xray-webhook/    # Обработчик вебхуков от Xray (торрент)
│   │   │   └── events/drop-connections/ # sockdestroy-based disconnect
│   │   └── network-stats/               # 📡 Мониторинг /proc/net/dev (1s polling)
│   └── bin/cli/cli.ts                   # 🔷 ENTRY: CLI (dump-config, kill-sockets)
├── libs/contract/                        # @remnawave/node-contract
│   ├── api/routes.ts                    # Все пути REST API
│   ├── api/controllers/                 # Контроллеры (handler, stats, xray, vision, plugin)
│   ├── commands/                        # CQRS Command/Query определения
│   ├── constants/                       # Ошибки, роли, Xray defaults
│   └── models/                          # Zod схемы
├── Dockerfile                            # Multi-stage (Alpine build → production)
├── docker-entrypoint.sh                  # Генерация креденшелов, supervisord, Xray
├── supervisord.conf                      # Конфиг supervisord: xray program
└── docker-compose-*.yml                  # 3 Docker Compose файла
```

#### Точки входа

| Entry Point | Файл | Протокол | Порт/Socket |
|------------|------|---------|------------|
| Public API | `src/main.ts` | HTTPS (mTLS) | `NODE_PORT` (2222) |
| Internal API | `src/main.ts` | HTTP (Unix Socket) | `/run/remnawave-internal-XXXXX.sock` |
| CLI | `bin/cli/cli.ts` | CLI | — |
| Xray Config | `internal.controller.ts` | `http+unix://` | Fetch by Xray-core |

#### Зависимости

| Зависимость | Роль |
|------------|------|
| `@remnawave/xtls-sdk` | gRPC клиент для Xray-core API |
| `@remnawave/xtls-sdk-nestjs` | NestJS-обёртка xtls-sdk |
| `@remnawave/supervisord-nestjs` | XML-RPC клиент supervisord |
| `@remnawave/node-contract` | Контракты API (свой lib) |
| `@remnawave/node-plugins` | Схемы плагинов |
| `@remnawave/hashed-set` | Оптимизация сравнения конфигов |
| `nftables-napi` | Нативные nftables (блокировка IP) |
| `sockdestroy` | Дестрой TCP соединений |
| Xray-core | Бинарник, управляемый через gRPC |

---

### 2.4 PANEL (`remnawave/panel`) — 📚 DOCUMENTATION

| Параметр | Значение |
|----------|---------|
| **Назначение** | Официальный сайт документации |
| **Уровень критичности** | `LOW` — не влияет на работу системы |
| **Фреймворк** | Docusaurus 3.9.2 |
| **Деплой** | Docker (Caddy + статика) → Railway |
| **Версия** | v0.0.1 |

```
panel_source/
├── docs/                        # 📖 MDX документация
│   ├── overview/                # Обзор, Quick Start, сравнение с Marzban
│   ├── learn/                   # RU руководства (44 скриншота)
│   ├── learn-en/                # EN руководства (52 скриншота)
│   ├── install/                 # Инструкции по установке
│   ├── guides/                  # Гайды, ошибки, шаблоны
│   ├── features/                # Фичи (HWID, OAuth2, Rescue CLI)
│   ├── migrate/                 # Миграция с Marzban
│   ├── sdk/                     # Документация SDK
│   ├── awesome-remnawave/       # Community проекты
│   ├── contributing/            # Как контрибьютить
│   └── partials/                # Переиспользуемые MDX фрагменты
├── src/
│   ├── components/              # Кастомные React компоненты
│   │   ├── HeroSection, CategoryNav, ProjectCard
│   │   ├── ClientCard, ClientsList, GitHubStars
│   │   └── StatsBar, FeatureHighlight, ReleaseEntry
│   └── data/clients.ts         # Данные о 30+ прокси-клиентах
├── static/                      # Скриншоты, иконки, логотипы
├── _panel-docs/help-articles/   # Хелп-статьи внутри UI панели (en/ru/fa/zh)
└── Caddyfile                    # Конфиг Caddy reverse proxy
```

---

## 3. SECONDARY REPOSITORIES

| Репозиторий | Назначение | Критичность | Язык |
|------------|-----------|------------|------|
| `remnawave/subscription-page` | End-user страница подписки | MEDIUM | TypeScript |
| `remnawave/xtls-sdk` | TypeScript SDK для Xray gRPC API | HIGH | TypeScript |
| `remnawave/templates` | Шаблоны конфигов Xray | MEDIUM | — |
| `remnawave/migrate` | Миграция с других панелей | LOW | Go |
| `remnawave/python-sdk` | Python SDK для API | LOW | Python |
| `remnawave/asn-index` | ASN индексация | LOW | JavaScript |

---

## 4. КЛЮЧЕВЫЕ АРХИТЕКТУРНЫЕ ПАТТЕРНЫ

### 4.1 CQRS (Command Query Responsibility Segregation)
- **Backend**: Команды/запросы через `@nestjs/cqrs`. Каждый модуль имеет `commands/` и `queries/`.
- **Node**: Аналогичный паттерн, но меньше масштаб.

### 4.2 Multi-Process Architecture (Backend)
```
PM2 Process Manager
├── remnawave-api        (cluster)  → REST API на порту 3003
├── remnawave-scheduler  (fork)     → Cron задачи (@nestjs/schedule)
└── remnawave-jobs       (cluster)  → BullMQ workers
```
Общение между процессами через Redis Pub/Sub и BullMQ.

### 4.3 Contract-First Design
```
libs/contract/  ←  Общие контракты (Zod схемы, типы, константы)
     ↓
Используется и backend, и frontend через npm пакет @remnawave/backend-contract
```

### 4.4 Hash-Based Change Detection (Node)
```
Panel → Node: "Запусти Xray с этим конфигом"
Node: Сравнивает HashedSet пользователей в каждом inbound
  ├── Хэши совпадают → Пропускает перезапуск (оптимизация)
  └── Хэши разные → Перезапускает Xray
```

### 4.5 Dual mTLS (Node)
```
Внешний mTLS: Node ↔ Panel (сертификаты из SECRET_KEY)
Внутренний mTLS: Node (gRPC клиент) ↔ Xray-core (gRPC сервер) на localhost
```

### 4.6 Feature-Sliced Design (Frontend)
```
app/        → Инициализация, роутинг, провайдеры
pages/      → Композиция страниц
widgets/    → Составные бизнес-блоки
features/   → Пользовательские взаимодействия
entities/   → Бизнес-сущности (Zustand stores)
shared/     → Инфраструктура (API, UI kit, utils)
```

---

## 5. ПОТОКИ ДАННЫХ

### 5.1 Создание пользователя VPN
```
Frontend → POST /api/users → Backend
  ├── Валидация DTO (Zod)
  ├── Сохранение в PostgreSQL
  ├── Enqueue job: users.add-user-to-nodes
  └── BullMQ → Node: POST /node/handler/add-user
      └── Node → Xray gRPC: addUser()
```

### 5.2 Получение подписки
```
Client → GET /api/sub/:token → Backend
  ├── Валидация токена
  ├── Поиск пользователя
  ├── Загрузка хостов (с учетом squads)
  ├── Применение шаблона (Xray JSON / Clash / Sing-box / ...)
  ├── Применение правил ответа (SRR)
  └── Возврат конфига
```

### 5.3 Сбор статистики
```
Cron (Scheduler) → Enqueue job → BullMQ Worker
  └→ Node: POST /node/stats/get-users-stats
    └→ Xray gRPC StatsService: getStats(reset: true)
      └→ Backend: Сохранение в NodesUserUsageHistory
```

---

## 6. СХЕМА БАЗЫ ДАННЫХ (Кратко)

36 таблиц PostgreSQL. Ключевые группы:

| Группа | Таблицы |
|--------|---------|
| **Пользователи** | `users`, `user_traffic`, `hwid_user_devices`, `user_meta` |
| **Ноды** | `nodes`, `nodes_usage_history`, `nodes_user_usage_history`, `nodes_traffic_usage_history`, `node_meta` |
| **Хосты** | `hosts`, `hosts_to_nodes` |
| **Подписки** | `subscription_templates`, `subscription_settings`, `subscription_page_config`, `user_subscription_request_history` |
| **Группы** | `internal_squads`, `internal_squad_members`, `internal_squad_inbounds`, `internal_squad_host_exclusions`, `external_squads`, `external_squads_templates` |
| **Конфиги** | `config_profiles`, `config_profile_inbounds`, `config_profile_inbounds_to_nodes`, `config_profile_snippets` |
| **Администрирование** | `admin`, `passkeys`, `api_tokens`, `remnawave_settings` |
| **Билинг** | `infra_providers`, `infra_billing_nodes`, `infra_billing_history` |
| **Плагины** | `node_plugin`, `torrent_blocker_reports` |
| **Ключи** | `keygen` |

---

## 7. ТЕХНОЛОГИЧЕСКИЙ СТЕК (Сводка)

| Слой | Технология |
|------|-----------|
| **Backend Framework** | NestJS 11 |
| **Frontend Framework** | React 19 + Vite 7.3 |
| **Node Agent** | NestJS 11 |
| **База данных** | PostgreSQL (Prisma ORM + Kysely) |
| **Кэш/Очереди** | Redis/Valkey (BullMQ) |
| **Процесс-менеджер** | PM2 |
| **API документация** | Swagger/OpenAPI + Scalar |
| **Метрики** | Prometheus |
| **Мониторинг** | Terminus Health Checks |
| **Уведомления** | Telegram (Grammy) + Webhook |
| **Авторизация** | JWT (RS256) + Passkey (WebAuthn) + OAuth2 |
| **Контейнеризация** | Docker (multi-stage) |
| **CI/CD** | GitHub Actions |
| **gRPC (Xray)** | nice-grpc + @remnawave/xtls-sdk |

---

## 8. РЕЗУЛЬТАТЫ STAGE 0

### Обнаруженные особенности

1. **panel ≠ приложение**: Репозиторий `remnawave/panel` — это сайт документации, а не код приложения. Реальное приложение разделено на `backend` + `frontend` + `node`.

2. **Три процесса в backend**: API, Scheduler и Job Worker работают как отдельные процессы PM2, общаясь через Redis.

3. **Hash-based оптимизация**: Node использует `HashedSet` для определения необходимости перезапуска Xray — умная оптимизация.

4. **Двойной mTLS на node**: Отдельные сертификаты для связи с панелью и с Xray-core.

5. **CQRS везде**: И backend, и node используют CQRS паттерн с разделением команд и запросов.

6. **Contract-first**: Контракты API вынесены в отдельные npm пакеты, общие для frontend и backend.

7. **84 миграции БД**: Проект активно развивается с ноября 2024.

8. **Мультиязычность**: 4 языка (EN, RU, FA, ZH) во frontend и документации.

---

*End of Stage 0 — REPOSITORY_MAP.md*
