# AURORA MIGRATION STRATEGY

> **Stage 11: Migration Plan**
> **Date:** 2026-06-23
> **Status:** COMPLETE
> **Based on:** Stages 0-10 analysis

---

## 1. DECISION MATRIX

```
┌─────────────────────────────────────────────────────────────────────┐
│                    AURORA MIGRATION DECISIONS                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  KEEP (без изменений)                  30%                           │
│  ├── Database Schema (core)                                         │
│  ├── Application Logic (core)                                        │
│  ├── Infrastructure (core)                                          │
│  ├── API Contracts (structure)                                       │
│  └── Architecture Patterns (CQRS, FSD)                               │
│                                                                      │
│  REFACTOR (переделать)                50%                            │
│  ├── Security Hardening                                              │
│  ├── Performance Optimizations                                       │
│  ├── UI Polish + Branding                                           │
│  ├── Node Agent Modernization                                        │
│  ├── Type Safety Improvements                                        │
│  └── FSD Architecture Fixes                                          │
│                                                                      │
│  REWRITE (написать заново)            20%                            │
│  ├── Authentication System                                           │
│  ├── Subscription Engine (cache layer)                               │
│  ├── Frontend Shared Forms Layer                                     │
│  ├── Cookie Auth Module                                              │
│  └── Cross-Cutting Infrastructure                                    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. KEEP — ОСТАВИТЬ БЕЗ ИЗМЕНЕНИЙ

Эти компоненты работают хорошо и не требуют изменений.

### 2.1 Database Schema (структура, не данные)

| Компонент | Обоснование |
|-----------|------------|
| **36 Prisma моделей** | Продуманная схема, 98 миграций |
| **UUID primary keys** | ✅ Правильно для распределённой системы |
| **M:N junction tables** | ✅ Стандартные composite keys |
| **CASCADE delete chains** | ✅ Правильные foreign keys |
| **JSONB для конфигов** | ✅ Гибко, валидация через Zod |
| **Seed data strategy** | ✅ 12 seeders покрывают всю инициализацию |
| **Migration history** | ✅ Чистая хронология, rollback support |

**Изменения:** Только добавить недостающие индексы (из Stage 9).

### 2.2 Application Architecture Patterns

| Компонент | Обоснование |
|-----------|------------|
| **CQRS (Backend + Node)** | ✅ Чёткое разделение команд/запросов |
| **FSD (Frontend)** | ✅ Правильная идея, только имплементация хромает |
| **Multi-process PM2** | ✅ API cluster + Scheduler fork + Worker cluster |
| **BullMQ queues** | ✅ 19 корректно настроенных очередей |
| **Contract-first design** | ✅ Zod схемы общие для frontend/backend |

### 2.3 Infrastructure Core

| Компонент | Обоснование |
|-----------|------------|
| **Docker Compose (3 сервиса)** | ✅ PostgreSQL + Valkey + Backend |
| **Node Docker (supervisord + Xray)** | ✅ Продуманный entrypoint |
| **mTLS for Panel↔Node** | ✅ Zero-trust подход |
| **Unix socket for internal API** | ✅ Безопаснее TCP |
| **PM2 cluster mode** | ✅ Горизонтальное масштабирование |

### 2.4 API Contracts (структура, не реализация)

| Компонент | Обоснование |
|-----------|------------|
| **REST_API route structure** | ✅ Чистые URL паттерны |
| **Command/Response Schema** | ✅ Zod validation |
| **Result pattern (`TResult<T>`)** | ✅ Единый формат ответа |

---

## 3. REFACTOR — ПЕРЕДЕЛАТЬ

Эти компоненты требуют изменений, но не полной переписки.

### 3.1 Security Hardening (P0 — немедленно)

| Компонент | Проблема | Рекомендация |
|-----------|---------|-------------|
| `JwtDefaultGuard` | Каждый запрос — DB lookup | Добавить Redis cache (5-10s TTL) с инвалидацией |
| `AuthService.login` | Нет rate limiting | Добавить `@nestjs/throttler` (5 попыток/мин/IP) |
| `AuthService` | Нет refresh token | Добавить opaque refresh tokens с ротацией |
| `SignApiTokenHandler` | 99999 дней TTL | Уменьшить до 90 дней с авто-продлением |
| `AuthService.verifyPassword` | HMAC ключ = JWT secret | Разделить на JWT_AUTH_SECRET и PASSWORD_HMAC_SECRET |
| `RemnawaveSettings` | `remnawaveAccess` backdoor claim | Удалить или ограничить |

### 3.2 Performance Optimizations

| Компонент | Проблема | Рекомендация |
|-----------|---------|-------------|
| Subscription rendering | 7+ операций на запрос | Добавить Redis caching rendered configs |
| `NodesSystemCacheService` | 5 Redis keys/node | Объединить в 1 JSON key |
| Scheduler for-loops | 3 sequential node loops | Заменить на pMap concurrency 10-20 |
| Frontend bundle | Highcharts + Recharts | Выбрать одну библиотеку |

### 3.3 UI Polish (under AURORA brand)

| Компонент | Что менять |
|-----------|-----------|
| **Color scheme** | #090909 bg, #131313 surface, #FF7A00 primary, #252525 border |
| **Typography** | Premium dark theme |
| **Logo & Favicon** | Крейсер Аврора тематика |
| **All branding strings** | Remnawave → AURORA |
| **i18n strings** | Update all references |

### 3.4 Node Agent Modernization

| Компонент | Проблема | Рекомендация |
|-----------|---------|-------------|
| `TokenAuthMiddleware` | Token в URL (query param) | Перейти на HTTP header |
| `InternalService` | Только `@Global()` импорт | Явные импорты |
| `StatsService` | Demo data commented code | Удалить |
| Docker entrypoint | Random strings generated in shell | Move to Node.js startup |

### 3.5 Type Safety

| Компонент | Проблема | Рекомендация |
|-----------|---------|-------------|
| `(BigInt.prototype as any).toJSON` | 3 копии | Вынести в shared bootstrap |
| `as unknown as Type` (26 мест) | JSONB → TypeScript | Zod parse вместо as casts |
| `any` (Frontend) | 10+ eslint-disable | Добавить корректные типы |

### 3.6 FSD Architecture Fixes

| # | Нарушение | Исправление |
|---|----------|------------|
| 1 | `shared/ui/forms/` содержит domain-specific формы | Переместить в `widgets/dashboard/forms/` |
| 2 | `shared` → `entities/modal-store` | Переместить modal-store в shared |
| 3 | `features` → `widgets` (9 случаев) | Использовать event callbacks |
| 4 | `entities` → `widgets` (1 случай) | Вынести UserStatusBadge в shared |
| 5 | `features` → `pages` (2 случая) | Вынести константы во features |

---

## 4. REWRITE — НАПИСАТЬ ЗАНОВО

Эти компоненты настолько проблемны, что проще написать заново.

### 4.1 Authentication System

**Почему:** 3 CRITICAL + 4 HIGH уязвимости из Stage 5.

| Старый компонент | Новый подход |
|-----------------|-------------|
| Stateless JWT (12-168ч) | Access token (15min) + Refresh token (7д) с ротацией |
| JWT в localStorage | HttpOnly Secure SameSite cookie |
| OAuth2 → первый админ | Multi-admin: отдельный admin per OAuth2 user |
| Passkey challenge TTL 60s | 120-180 секунд |
| No MFA | TOTP optional second factor |
| No brute-force protection | Rate limiting + account lockout |
| No audit trail | Логирование UUID админа во все действия |

**Объём:**
- AuthService — полностью переписать (~500 строк)
- JwtGuard — добавить refresh validation
- OAuth2 handlers — multi-admin routing
- Frontend auth flow — HttpOnly cookie handling

### 4.2 Subscription Engine (Cache Layer)

**Почему:** 7+ последовательных операций, CPU-bound.

| Старый компонент | Новый подход |
|-----------------|-------------|
| No caching | Redis cache rendered configs (TTL: 60s) |
| Per-request DB queries | Cache subscription settings (TTL: 3600s) |
| Sequential host resolution | Parallel resolve with concurrency |
| No CDN support | Cache headers for CDN (Cloudflare) |

**Объём:**
- SubscriptionService — рефакторинг с кэшированием
- ResponseRulesMiddleware — кэширование User-Agent matching
- New CacheInvalidationService — сброс кэша при изменении

### 4.3 Frontend Shared Forms Layer

**Почему:** 45 FSD violations, основная причина — `shared/ui/forms/`.

**Новая структура:**
```
widgets/dashboard/forms/
├── users/
│   ├── user-identification-card.tsx
│   └── access-settings-card.tsx
├── nodes/
│   └── base-node-form.tsx
├── hosts/
│   ├── base-host-form.tsx
│   └── host-tags-input.tsx
```

**Объём:** ~15 файлов переместить, переписать импорты.

### 4.4 Cookie Auth Module

**Почему:** Полностью закомментирован, но частично реализован.

**Решение:** Либо удалить весь код, либо корректно реализовать (SameSite=Strict + CSRF token).

---

## 5. PHASED MIGRATION PLAN

### PHASE 0: BRANDING (1-2 дня)

```
Stage 12: AURORA Brand Transformation
├── Package names: @remnawave/* → @aurora/*
├── CSS Theme цвета #090909, #131313, #FF7A00
├── Логотип, favicon, название
├── i18n строки с Remnawave → AURORA
└── README, документация
```

### PHASE 1: SECURITY CRITICAL (1 неделя)

```
Priority: P0 — немедленно
Prerequisites: Stage 5 findings
├── Rate limiting (5 попыток/мин)
├── Refresh token архитектура
├── HttpOnly cookie для JWT
├── Account lockout (10 попыток → 15 мин)
└── Разделение JWT/Password HMAC secret
```

### PHASE 2: TECH DEBT CLEANUP (1-2 недели)

```
Priority: P1 — до запуска
Prerequisites: Stage 10 findings
├── Удалить deprecated методы usage history
├── Заменить as unknown casts на Zod parse
├── BigInt.toJSON → shared bootstrap
├── Удалить закомментированный код
├── FSD fixes (shared/ui/forms → widgets)
└── Выбрать 1 chart библиотеку
```

### PHASE 3: AUTH REWRITE (2 недели)

```
Priority: P0 — до запуска
Prerequisites: Phase 1
├── Multi-admin OAuth2 (не первый админ)
├── TOTP MFA support
├── OAuth2 PKCE для всех провайдеров
├── Audit trail (admin UUID в actions)
└── Remove remnawaveAccess backdoor
```

### PHASE 4: PERFORMANCE (1 неделя)

```
Priority: P1 — до запуска
Prerequisites: Stage 9 findings
├── Subscription caching (Redis)
├── Nodes cache: 5 keys → 1 key
├── pMap scheduler loops
├── CDN headers for subscriptions
└── Database index optimization
```

### PHASE 5: NODE MODERNIZATION (1-2 недели)

```
Priority: P1 — до запуска
Prerequisites: Stage 6, 7 findings
├── Internal token header (not query param)
├── Config validation improvements
├── Rate limiting on internal endpoints
└── Startup credential generation in Node.js
```

### PHASE 6: INFRASTRUCTURE (1 неделя)

```
Priority: P2 — после запуска
├── Mono-repo setup (Backend + Frontend + Node)
├── CI/CD with security scanning
├── Cross-component version sync
├── OpenAPI for all components
└── Read replicas for PostgreSQL
```

---

## 6. MIGRATION RISK ASSESSMENT

| Риск | Вероятность | Влияние | Митигация |
|------|------------|---------|-----------|
| **Data loss при refactor БД** | Низкая | Критическое | Новые индексы без изменения схемы |
| **Auth rewrite — downtime** | Средняя | Критическое | Graceful migration: old JWT + new refresh tokens |
| **Branding breakage** | Высокая | Среднее | Staging проверка перед деплоем |
| **Subscription cache invalidation** | Средняя | Высокое | TTL-based cache + manual purge endpoint |
| **FSD refactor — build errors** | Высокая | Среднее | Пошаговая миграция, проверка каждого PR |
| **Node token header change** | Средняя | Высокое | Backward-compatible token check (header OR query) |

---

## 7. KEEP / REFACTOR / REWRITE SUMMARY

### By Component

| Компонент | Решение | Обоснование |
|-----------|---------|------------|
| Database Schema | ✅ KEEP | Продуманная, 98 миграций |
| Prisma + Kysely pattern | ✅ KEEP | Стабильный dual access |
| CQRS pattern (Backend) | ✅ KEEP | Чистое разделение |
| FSD architecture (concept) | ✅ KEEP | Правильная идея |
| PM2 process management | ✅ KEEP | Стабильный |
| BullMQ queue system | ✅ KEEP | 19 очередей работают |
| mTLS + JWT (Node) | ✅ KEEP | Zero-trust корректно |
| Docker infrastructure | ✅ KEEP | Стабильный |

| Компонент | Решение | Обоснование |
|-----------|---------|------------|
| Security middleware | ♻️ REFACTOR | Rate limiting + refresh tokens |
| AuthService | ♻️ REFACTOR | Multi-admin, MFA, audit |
| Subscription rendering | ♻️ REFACTOR | Cache + parallel resolve |
| FSD layer violations | ♻️ REFACTOR | 45 violations to fix |
| BigInt serialization | ♻️ REFACTOR | 3 copies → 1 shared |
| Host JSON parsing | ♻️ REFACTOR | 8 duplicates → 1 utility |
| Scheduler for-loops | ♻️ REFACTOR | Sequential → parallel |
| CSS Theme | ♻️ REFACTOR | Brand transformation |

| Компонент | Решение | Обоснование |
|-----------|---------|------------|
| JWT auth (stateless) | 🆕 REWRITE | 3 critical vulns |
| OAuth2 → single admin | 🆕 REWRITE | Multi-admin needed |
| Cookie Auth module | 🆕 REWRITE | Dead code or full impl |
| `shared/ui/forms/` | 🆕 REWRITE | FSD violations root |
| Node internal token auth | 🆕 REWRITE | Query param → header |

### By Volume

| Категория | Кол-во | Трудоёмкость |
|-----------|--------|-------------|
| ✅ KEEP | 10 компонентов | 0 человек-недель |
| ♻️ REFACTOR | 12+ компонентов | 4-6 человек-недель |
| 🆕 REWRITE | 5+ компонентов | 4-6 человек-недель |
| **Total** | **27+** | **8-12 человек-недель** |

---

## 8. POST-MIGRATION CHECKLIST

После завершения миграции должно быть:

- [ ] Все пакеты: `@aurora/*` вместо `@remnawave/*`
- [ ] Black theme: #090909 bg, #FF7A00 primary
- [ ] Rate limiting на всех публичных endpoint'ах
- [ ] Refresh token ротация
- [ ] HttpOnly cookie для JWT
- [ ] Multi-admin OAuth2
- [ ] FSD violations устранены (0 violations)
- [ ] Subscription caching
- [ ] No deprecated code
- [ ] No BigInt patching in 3 files
- [ ] Internal token в Header
- [ ] CI/CD security scan
- [ ] Все тесты проходят
- [ ] Staging deploy прошёл

---

*End of Stage 11 — AURORA_MIGRATION_PLAN.md*
