# PERFORMANCE REPORT — Remnawave → AURORA

> **Stage 9: Performance Audit**
> **Date:** 2026-06-23
> **Status:** COMPLETE

---

## 1. EXECUTIVE SUMMARY

| Область | Оценка | Ключевые проблемы |
|---------|--------|------------------|
| **Backend: Database** | ⚠️ Средне | N+1 риски в queries, raw SQL в 30+ местах, нет индексов на даты в usage_history |
| **Backend: Node Communication** | ⚠️ Средне | Последовательные вызовы к нодам, Redis pipeline на 5 ключей на ноду |
| **Backend: Scheduler** | ✅ Хорошо | Batch processing с FOR UPDATE, pMap concurrency, чанкование |
| **Frontend: Rendering** | ⚠️ Средне | 25 React.memo, 5 virtualized lists, 12 keepPreviousData hooks |
| **Frontend: Bundle** | ⚠️ Средне | Monaco Editor 350KB, Mantine ~130KB, Highcharts ~180KB |
| **Node: Optimization** | ✅ Хорошо | Hash-based config comparison, pRetry, pMap |
| **Infrastructure** | ✅ Хорошо | Redis caching, Valkey Unix socket, BullMQ dedup |

---

## 2. BACKEND PERFORMANCE

### 2.1 Database Query Analysis

#### Heavy Queries (Raw SQL)

| Файл | Тип | Частота | Описание | Risk |
|------|-----|---------|----------|------|
| `users.repository.ts:114` | $queryRaw | Каждые 15с | Bulk update user traffic | 🔴 HIGH |
| `users.repository.ts:121` | $queryRaw | Раз в 45с | Trigger threshold notifications | 🟡 MED |
| `users.repository.ts:686` | $executeRaw | On demand | Bulk delete by status (FOR UPDATE) | 🟢 LOW |
| `NUUH.repository.ts:55` | $executeRaw | Каждые 15с | Bulk upsert user usage history | 🔴 HIGH |
| `NUUH.repository.ts:172` | $queryRaw | On demand | Get user nodes usage by range | 🟡 MED |
| `NUUH.repository.ts:224` | $queryRaw | On demand | Get daily usage series (date unnest) | 🟡 MED |
| `nodes-usage-history.repository.ts:80` | $queryRaw | On demand | Get 7-day stats | 🟡 MED |
| `nodes-usage-history.repository.ts:131` | $queryRaw | On demand | Get nodes usage by range | 🟡 MED |

#### N+1 Query Risks

| # | Проблема | Описание |
|---|----------|----------|
| **VP-N1** | `getAllNodes()` вызывает `NodesSystemCacheService.getMany()` | Для каждой ноды — Redis pipeline из 5 ключей. Корректно через batch pipeline (✅) |
| **VP-N2** | Subscription: каждый хост резолвится индивидуально | `ResolveProxyConfigService` — последовательная обработка хостов через for |
| **VP-N3** | Users without `include` on connected relations | `users.repository.ts` может вызывать N+1 через Prisma relation loading |

#### Index Analysis

Существующие индексы (из Stage 3):

| Таблица | Индекс | Назначение | Достаточность |
|---------|--------|-----------|---------------|
| `nodes_usage_history` | `[nodeUuid, createdAt DESC]` | Запросы по дате | ✅ OK |
| `nodes_user_usage_history` | PK: `[nodeId, date, userId]` | UPSERT по дате | ⚠️ Нет индекса по дате отдельно |
| `user_subscription_request_history` | `[userUuid]`, `[requestAt ASC]` | История запросов | ✅ OK |
| `passkeys` | `[adminUuid]` | Поиск passkeys админа | ✅ OK |

**Отсутствующие индексы (рекомендуемые):**
```sql
-- nodes_user_usage_history — частые запросы за период
CREATE INDEX ON nodes_user_usage_history (created_at DESC);

-- users — частые запросы по статусу
CREATE INDEX ON users (status) WHERE status = 'ACTIVE';

-- users — поиск по shortUuid (каждый запрос подписки)
-- ✅ уже есть UNIQUE на shortUuid

-- torrent_blocker_reports — запросы по пользователю
CREATE INDEX ON torrent_blocker_reports (user_id, created_at);
```

#### Batch Processing Patterns

**Правильно реализовано:**
```typescript
// Чанкование FOR UPDATE (users.repository.ts:595)
for (let i = 0; i < targetIds.length; i += batchSize) {
    const batchIds = targetIds.slice(i, i + batchSize);
    // ... FOR UPDATE + UPSERT
}
```

**Проблема:** в scheduler `reset-user-traffic.processor.ts` используется сырой `string_to_array` с `join(',')` — неэффективная конвертация массива bigint в строку и обратно.

### 2.2 Redis Performance

| Ключ | Размер | TTL | Частота записи |
|------|--------|-----|---------------|
| `NODE_SYSTEM_INFO(uuid)` | ~200B | ∞ | Каждые 10с на ноду |
| `NODE_SYSTEM_STATS(uuid)` | ~100B | 30s | Каждые 10с на ноду |
| `NODE_USERS_ONLINE(uuid)` | ~8B | 16s | Каждые 10с на ноду |
| `NODE_VERSIONS(uuid)` | ~50B | ∞ | Каждые 10с на ноду |
| `NODE_XRAY_UPTIME(uuid)` | ~8B | 16s | Каждые 10с на ноду |

**Оценка:** для 100 нод → ~36KB данных, ~500 записей/сек в Redis. OK.

**Pipeline batch pattern** (правильно):
```typescript
const pipe = this.rawCacheService.createPipeline();
for (const node of nodes) {
    pipe.get(CACHE_KEYS.NODE_SYSTEM_INFO(node.uuid));
    // ... 5 keys per node
}
const results = await pipe.exec();
```

### 2.3 Queue Performance

| Queue | Процессоров | Concurrency | Частота |
|-------|------------|------------|---------|
| HEALTH_CHECK | 1 | Default | Каждые 10с (bulk) |
| RECORD_USER_USAGE | 1 | Default | Каждые 15с (bulk) |
| RECORD_NODE_USAGE | 1 | Default | Каждые 30с (bulk) |
| START_ALL_NODES | 1 | **1** | Первый запуск |
| START_ALL_BY_PROFILE | 1 | **3** | При изменении профиля |

**Job removal:** Все jobs удаляются после успеха/неудачи (`removeOnComplete: true`, `removeOnFail: true`). Это предотвращает накопление в Redis.

### 2.4 Node Communication

```
Каждые 15 секунд: N запросов (где N = количество enabled нод)
- POST /node/stats/get-users-stats (HTTP + mTLS handshake)
- Обработка ответа + База данных (UPSERT)
```

**Problem:** HTTP keep-alive timeout всего 60с на Node, headers timeout 61с. При 10+ нодах может быть много TCP handshake'ов.

---

## 3. FRONTEND PERFORMANCE

### 3.1 Bundle Size Analysis

| Чанк | Размер (gzip) | Комментарий |
|------|--------------|-------------|
| `monaco` | ~350KB | **Медленная загрузка** — но lazy loaded (только на странице редактора) |
| `mantine` | ~130KB | Статический, хорошо кэшируется |
| `charts` | ~180KB (Highcharts) + Recharts | Overlap: 2 chart библиотеки |
| `markdown` | ~50KB | Только для help-статей |
| `react` | ~45KB | Стандартный |
| `remnawave` (contract) | ~3.5KB | ✅ Очень маленький |

**Проблемы:**
1. **Highcharts + Recharts** — дублирование (2 библиотеки для графиков)
2. **Monaco Editor** — огромный чанк, хотя используется нечасто (но lazy loaded)
3. **MRT (Mantine React Table)** — ~80KB

### 3.2 Rendering Performance

**React.memo: 25 компонентов** используют `memo()` (хорошо):

| Группа | Количество | Комментарий |
|--------|-----------|-------------|
| Nodes | 11 | ✅ Node cards, badges, metrics |
| Hosts | 2 | ✅ Host table, edit modal |
| Users | 3 | ✅ Internal squad lists, user form |
| Shared UI | 9 | ✅ Help drawer, config cards, virtualized lists |

**Virtualization: 5 компонентов** используют `@tanstack/react-virtual` или `react-virtuoso`:
- `virtualized-inbounds-list` — виртуальный список inbound
- `virtualized-flat-inbounds-list` — плоский виртуальный список
- `virtualized-dnd-grid` — виртуальный DnD грид
- `internal-squads-list-simple` — простая виртуализация

**keepPreviousData: 12 хуков** используют `placeholderData: keepPreviousData`:
- Users, Nodes, Hosts, Templates, HWID, Infra Billing, etc.

Это предотвращает "моргание" таблиц при пагинации.

### 3.3 State Performance

**Zustand — 9 stores. Все не-persisted stores имеют `resetAllStores()` на logout.**

Проблем нет. Zustand минимален по сравнению с Redux.

### 3.4 Network Performance

**React Query configuration:**
```typescript
staleTime: 60_000,   // 1 минута — данные считаются свежими
gcTime: 120_000,     // 2 минуты — в кэше
refetchOnWindowFocus: false,  // Нет рефетча при фокусе
retry: false          // Нет ретраев при ошибках
```

**Per-endpoint overrides:**
- Node health: `refetchInterval: 20_000` (20 сек)
- Users table: `staleTime: 20_000` + `refetchInterval: 25_000`
- System info: staleTime по умолчанию

---

## 4. NODE PERFORMANCE

### 4.1 Config Generation

**Hash-based optimization** предотвращает перезапуск Xray если пользователи не изменились:
```
HashedSet.contains() → O(1) per inbound
isNeedRestartCore()  → O(inbounds) — очень быстро
```

**generateApiConfig() — выполняется при каждом start:**
- Операции: spread + Array prepend + объектная манипуляция
- Время: <1ms на V8 (чисто JS, нет I/O)

### 4.2 pMap Concurrency

| Расположение | Concurrency | Задача |
|-------------|------------|--------|
| `InternalService.extractUsersFromConfig()` | 20 | Извлечение пользователей из inbounds |
| `StatsService.getUsersIpList()` | 50 | Получение IP всех online пользователей |
| `HandlerService.addUser()` | 1 (serial) | Добавление пользователя |
| `HandlerService.removeUser()` | 1 (serial) | Удаление пользователя |

✅ Concurrency параметры адекватны.

### 4.3 Xray gRPC Communication

| Параметр | Значение |
|----------|---------|
| Протокол | gRPC over mTLS |
| Адрес | `127.0.0.1:XTLS_API_PORT` |
| Max message | 100MB |
| mTLS | `rejectUnauthorized: true` |
| Ssl target | `internal.remnawave.local` |

**Все коммуникации — localhost** (нет сетевых задержек). ✅

---

## 5. CRITICAL PERFORMANCE BOTTLENECKS

### 🔴 HIGH: Subscription Delivery Pipeline

**Проблема:** Каждый запрос подписки вызывает цепочку из 7+ последовательных операций:
1. Find user (DB)
2. Check traffic/status (DB)
3. Apply external squad overrides (Redis)
4. Query hosts with filters (DB)
5. Randomize hosts (JS)
6. Apply HWID check (DB)
7. Resolve proxy config (JS loop over hosts)
8. Render template (YAML/JSON generation)
9. Apply response rules (header matching)
10. Log request (DB/Redis Queue)

**Для 1000+ одновременных запросов** может быть проблема.

**Рекомендация:** 
- Кэшировать rendered конфиги (учитывая изменение хостов/шаблонов)
- Увеличить Redis TTL для subscription settings
- Добавить CDN (Cloudflare) перед subscription endpoint

### 🟡 MEDIUM: NodesSystemCacheService Redis Pipeline

**Проблема:** Каждый раз при `GET /api/nodes` создаётся Redis pipeline на 5 ключей на ноду.
Для 100 нод: 500 команд, 100+KB transferred.

**Рекомендация:** 
- Кэшировать результат на 2-3 секунды в in-memory
- Уменьшить ключи до 1 JSON-ключа на ноду

### 🟡 MEDIUM: pMap vs for-of в scheduler

Найдены 3 цикла `for (const node of nodes)` в scheduler, которые вызывают Node API последовательно. Для 50 нод — 50 последовательных HTTP запросов:
- `reset-node-traffic.service.ts:40` — последовательный сброс
- `review-nodes.task.ts:47` — последовательный review
- `infra-billing-nodes-notifications.task.ts:38` — последовательные уведомления

**Рекомендация:** Заменить на `pMap` с concurrency 10-20.

---

## 6. SCALABILITY ANALYSIS

### 6.1 Backend Scalability

| Компонент | Масштабирование | Лимиты |
|-----------|----------------|--------|
| **API** | PM2 cluster (N instances) | CPU-bound |
| **Scheduler** | Fork (1 instance) | **Single point** — REQUIRED |
| **Worker** | PM2 cluster (M instances) | Redis connection pool |
| **Database** | PostgreSQL (read replica) | Write master |
| **Redis/Valkey** | Single instance | Memory |

**Проблема:** Scheduler — 1 instance. Если scheduler падает:
- Node healthcheck останавливается (но ноды продолжают работать)
- User traffic recording останавливается (теряются данные)
- Traffic reset не выполняется (пользователи не блокируются)

**Решение:** Добавить healthcheck для scheduler + автоматический restart (PM2 `max_restarts` уже конфигурируется).

### 6.2 Node Scalability

| Параметр | Значение | Комментарий |
|----------|---------|-------------|
| **Нод на панель** | Практически безлимит | Backend не хранит состояние нод |
| **Пользователей на ноду** | Зависит от Xray | gRPC в Xray не bottleneck |
| **Трафик на ноду** | Зависит от железа | nftables требует NET_ADMIN |

### 6.3 Maximum Load Estimates

| Метрика | Оценка | Потолок |
|---------|--------|---------|
| Users per panel | ~500,000 | PostgreSQL лимиты пользователей |
| Nodes per panel | ~1,000 | Redis pipeline + healthcheck 10с |
| Subscriptions per second | ~500 | CPU-bound (YAML generation) |
| Traffic recordings | ~1000/s | Batch UPSERT OK |

---

## 7. PERFORMANCE RECOMMENDATIONS (AURORA)

### P0 — Immediate
1. **Subscription caching** — render once, cache in Redis, invalidate on changes
2. **Reduce memory allocations** in subscription template rendering (reuse compiled templates)

### P1 — Before Launch
3. **Merge Redis keys**: 5 keys per node → 1 JSON key (reduce pipeline overhead)
4. **pMap concurrency** for scheduler for-loops (use concurrency 10-20)
5. **Remove duplicate chart library**: keep only Highcharts OR Recharts
6. **CDN for subscriptions** — Cloudflare caching of rendered configs

### P2 — Scaling
7. **Read replicas** for PostgreSQL heavy queries
8. **Redis Cluster** for Valkey (multiple shards)
9. **Horizontal scaling**: multiple scheduler instances with distributed locks
10. **Streaming stats**: use REDIS STREAMS instead of Pub/Sub for metrics

### P3 — Optimization
11. Database VACUUM schedule (already configured — weekly)
12. Connection pooling for Prisma (check pool size)
13. HTTP/2 for Node communication (reduce mTLS overhead)
14. Enable gRPC compression between Node and Xray

---

*End of Stage 9 — PERFORMANCE_REPORT.md*
