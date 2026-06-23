# TECHNICAL DEBT REPORT — Remnawave → AURORA

> **Stage 10: Technical Debt Audit**
> **Date:** 2026-06-23
> **Status:** COMPLETE

---

## 1. EXECUTIVE SUMMARY

| Метрика | Backend | Frontend | Node | Всего |
|---------|---------|----------|------|-------|
| TODO/FIXME/HACK | 6 | 3 | 1 | **10** |
| @deprecated methods | 4 | 0 | 0 | **4** |
| `as unknown` / `as any` casts | 16 | 10 | 0 | **26** |
| `@ts-ignore` / `eslint-disable` | 12 | 17 | 0 | **29** |
| Dead code (commented out) | 5+ | 3+ | 0 | **8+** |
| Duplicate logic | 2 | 3 | 0 | **5** |
| Unused npm deps | 4 | 3 | 2 | **9** |
| FSD violations | — | 45 | — | **45** |
| **Total items** | **49+** | **84+** | **3** | **136+** |

---

## 2. BACKEND TECH DEBT

### 2.1 TODO / FIXME (6)

| # | Файл | Строка | Описание |
|---|------|--------|----------|
| TD-B1 | `queue/_users/users-queues.service.ts` | 69 | `// TODO: carefully` — concurrency=5 без обоснования |
| TD-B2 | `modules/config-profiles/config-profile.service.ts` | 351 | `// TODO: need additional checks` — в profile modification |
| TD-B3 | `modules/internal-squads/repositories/...` | 115 | `// TODO: add members list` — неполная имплементация |
| TD-B4 | `queue/_nodes/processors/stop-node.processor.ts` | 49 | `// TODO: disable plugins?` — нереализованная логика |
| TD-B5 | `queue/_nodes/processors/node-plugins.processor.ts` | 118 | `// TODO: retry` — отсутствует retry логика |
| TD-B6 | `modules/subscription/utils/get-user-info.headers.ts` | 19 | `// TODO: remove after XTLS Standards published` — временный код |

### 2.2 Deprecated Code (4)

| # | Файл | Метод | Статус |
|---|------|-------|--------|
| TD-B7 | `modules/nodes-user-usage-history/repository.ts` | `getLegacyStatsUserUsage()` | `@deprecated` |
| TD-B8 | `modules/nodes-user-usage-history/repository.ts` | `getLegacyStatsNodesUsersUsage()` | `@deprecated` |
| TD-B9 | `modules/nodes-user-usage-history/service.ts` | Соответствующие методы | `@deprecated` |

Эти deprecated методы дублируют функциональность новых API эндпоинтов (legacy `bandwidth-stats` endpoints).

### 2.3 Type Safety Issues (28)

**BigInt serialization monkey-patch (3 файла):**
```typescript
(BigInt.prototype as any).toJSON = function () { return this.toString(); };
// main.ts, scheduler.ts, processors.ts — дублирование!
```

**`as unknown as Type` casts (16 мест):**
- Config parsing (JSONB → TypeScript) — 8 мест
- Xray config type assertions — 4 места
- Response model casts — 4 места

### 2.4 Duplicate Logic

| # | Описание | Файлы |
|---|----------|-------|
| TD-B10 | **BigInt.toJSON patch** повторён 3 раза | `main.ts`, `scheduler.ts`, `processors.ts` |
| TD-B11 | **Host JSON field parsing** повторено в create/edit | `hosts/create-host-modal` and `hosts/edit-host-modal` |
| TD-B12 | **Nodes queue service** — методы `startAllNodesByProfile` и `startAllNodes` почти идентичны | `nodes-queues.service.ts` |

### 2.5 Commented-Out Code

| # | Файл | Строки | Содержание |
|---|------|--------|-----------|
| TD-B13 | `main.ts` | 124-132 | Cookie auth middleware (закомментирован) |
| TD-B14 | `main.ts` | 112-119 | Skip metrics в morgan (закомментирован) |
| TD-B15 | `app.module.ts` | несколько | Cookie auth config (закомментирован) |
| TD-B16 | `config.schema.ts` | 112-116, 263-295 | Cookie auth validation (закомментирован) |
| TD-B17 | `stats.service.ts` | 127-136 | Demo data generation (закомментирован блок) |

### 2.6 Unused Dependencies (из package.json)

| Пакет | Риск |
|-------|------|
| `convert-units` | Не используется в коде |
| `try` | Не используется (пакет-заглушка) |
| `transliteration` | Не найдено использований |
| `cookie-parser` | Только для COOKIE_AUTH (выключено) |

### 2.7 Pattern Inconsistencies

| # | Проблема | Примеры |
|---|----------|---------|
| TD-B18 | **Смешение CQRS и direct service calls** | Часть контроллеров через CommandBus, часть напрямую |
| TD-B19 | **Prisma + Kysely дублирование** | Некоторые запросы можно сделать на Prisma, но сделаны на Kysely |
| TD-B20 | **@nestjs/config vs dotenv** | ConfigSchema через Zod, но часть кода читает `process.env` напрямую |

---

## 3. FRONTEND TECH DEBT

### 3.1 FSD Architecture Violations (45)

Подробно в DEPENDENCY_GRAPH.md. Кратко:

| Тип | Количество | Описание |
|-----|-----------|----------|
| `shared` → `entities` (modal-store) | 14 | Самое частое нарушение |
| `shared` → `features` | 13 | Формы в shared используют features |
| `shared` → `widgets` | 5 | Shared UI компоненты импортируют виджеты |
| `entities` → `widgets` | 1 | Entity использует widget badge |
| `features` → `widgets` | 9 | Features открывают виджеты |
| `features` → `pages` | 2 | Features импортируют типы из pages |

**Рекомендация:** Переместить `shared/ui/forms/` в `widgets/` (это не shared компоненты). Вынести modal-store из entities в shared.

### 3.2 Type Safety Issues (27)

| Тип | Количество | Примеры |
|-----|-----------|---------|
| `eslint-disable` | 17 | `no-nested-ternary`, `no-param-reassign`, `no-await-in-loop` |
| `as any` / `as unknown` | 10 | JSON parsing, Monaco editor types |

**Проблема:** Host JSON field parsing с `as unknown as string`:
```typescript
xHttpExtraParams = JSON.parse(values.xHttpExtraParams as unknown as string)
```
Повторяется 8 раз в create/edit host формах.

### 3.3 Duplicate Logic (3)

| # | Описание | Файлы |
|---|----------|-------|
| TD-F1 | **Host form JSON parsing** (8 идентичных блоков) | `create-host-modal`, `edit-host-modal` |
| TD-F2 | **Response rules editor** — повторяет логику из редактора шаблонов | `response-rules-editor`, `template-editor` |
| TD-F3 | **Subscription link renderSVG** — кастомный рендер вместо библиотеки | `get-user-subscription-links.feature.tsx` |

### 3.4 Potential Dead Code (unused dependencies)

| Пакет | Причина |
|-------|---------|
| `@formkit/auto-animate` | Возможно не используется |
| `react-country-flag` | Страны отображаются через эмодзи |
| `react-layout-masonry` | Только 1 компонент |

### 3.5 State Management Debt

| # | Проблема | Описание |
|---|----------|----------|
| TD-F4 | **modal-store coupling** | 10+ shared компонентов импортируют modal-store — создаёт циклические зависимости |
| TD-F5 | **table store versioning** | users-table-store имеет `version: 8` — это означает 8 миграций схемы. При каждом новом релизе нужно поддерживать совместимость. |

---

## 4. NODE TECH DEBT

Агент Node — значительно чище:

| # | Описание | Риск |
|---|----------|------|
| TD-N1 | `handler.service.ts: TODO: add a better way to return users` | Низкий |
| TD-N2 | Unused route constant `XRAY_ROUTES.STATUS` в контракте | Низкий |
| TD-N3 | `json-colorizer` в dependencies — не критичен | Низкий |
| TD-N4 | Demo data generation закомментирован: stats.service.ts:127-136 | Низкий |

Node код преимущественно чистый — минимальный технический долг.

---

## 5. CROSS-CUTTING CONCERNS

### 5.1 Versioning Inconsistencies

| Пакет | Версия в Backend | Версия в Frontend | Версия в Node |
|-------|-----------------|-------------------|---------------|
| `@remnawave/xtls-sdk` | 0.8.0 | — | 0.12.1 | ⚠️ **MISMATCH** |
| `zod` | 3.25.76 | 3.25.76 | 3.25.76 | ✅ |
| `@nestjs/common` | 11.1.17 | — | 11.1.17 | ✅ |

### 5.2 Monorepo vs Separate Repos

**Проблема:** Backend и Node используют разные версии `@remnawave/xtls-sdk` (0.8.0 vs 0.12.1). Это разные репозитории — синхронизация версий не автоматизирована.

### 5.3 Documentation Debt

| # | Проблема | Описание |
|---|----------|----------|
| TD-C1 | `.env.sample` устарел | Не все переменные документированы |
| TD-C2 | Нет auto-generated API docs для Node | Swagger только для Backend |
| TD-C3 | Нет CHANGELOG в репозиториях | Только в package version |

---

## 6. SUMMARY & AURORA RECOMMENDATIONS

### 6.1 Quick Fixes (неделя)
1. **Удалить deprecated методы** в nodes-user-usage-history
2. **Заменить `as unknown` casts** на Zod validation
3. **Вынести BigInt.toJSON** в shared модуль (не дублировать)
4. **Удалить закомментированный код** (cookie auth, etc.)
5. **Вынести modal-store** из entities в shared (FSD fix)

### 6.2 Medium (фаза миграции)
6. **Переместить `shared/ui/forms/`** в `widgets/` (FSD violation)
7. **Убрать 2-ю chart библиотеку** (Highcharts или Recharts)
8. **Объединить Host form JSON parsing** в shared utility
9. **Синхронизировать версии xtls-sdk** между backend и node

### 6.3 Long-term (AURORA architecture)
10. **Пересмотреть Cookie Auth** — удалить или реализовать
11. **Монорепозиторий** — унифицировать сборку backend+frontend+node
12. **Auto-generated OpenAPI** для всех компонентов
13. **Type-safe JSONB** через Zod генерацию из Prisma схемы

### 6.4 Tech Debt Score (1-10, lower is better)

| Компонент | Score | Пояснение |
|-----------|-------|-----------|
| **Backend** | 6/10 | 49+ issues, deprecated code, type casts |
| **Frontend** | 5/10 | 84+ issues, 45 FSD violations, but clean patterns |
| **Node** | 9/10 | Почти без долга |
| **Cross-cutting** | 7/10 | Версионный mismatch, документация |

---

*End of Stage 10 — TECH_DEBT_REPORT.md*
