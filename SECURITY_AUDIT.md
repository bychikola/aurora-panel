# SECURITY AUDIT — Remnawave → AURORA

> **Stage 8: Security Audit**
> **Date:** 2026-06-23
> **Status:** COMPLETE

---

## EXECUTIVE SUMMARY

| Категория | CRITICAL | HIGH | MEDIUM | LOW |
|-----------|----------|------|--------|-----|
| SQL Injection | 0 | 0 | 0 | 0 |
| XSS | 0 | 2 | 1 | 0 |
| CSRF | 0 | 1 | 0 | 0 |
| SSRF | 0 | 1 | 1 | 0 |
| RCE | 0 | 0 | 0 | 1 |
| Privilege Escalation | 0 | 0 | 1 | 0 |
| Transport Security | 0 | 0 | 1 | 1 |
| Auth (from Stage 5) | 3 | 4 | 4 | 3 |
| **Total** | **3** | **8** | **8** | **5** |

---

## 1. SQL INJECTION

### Risk Level: ✅ NOT VULNERABLE

**Проверка:** Все 30+ случаев использования `$queryRaw` / `$executeRaw` используют:
- `Prisma.sql` tagged template literals — безопасные параметризованные запросы
- `Prisma.join()` для списков — санитизация через Prisma
- `Prisma.raw()` используется только в CLI для имени БД из .env (не user input)
- Builder-паттерн (`BulkUpdateUserUsedTrafficBuilder`, `BulkDeleteByStatusBuilder`) — все параметры через Prisma.sql placeholders

**Пример безопасного кода:**
```typescript
const values = Prisma.join(
    list.map((h) => Prisma.sql`(${h.b}::bigint, ${h.u}::bigint, ${h.n}::uuid)`),
);
```

**Вердикт:** Нет SQL injection нигде в коде.

---

## 2. XSS (CROSS-SITE SCRIPTING)

### 🔴 HIGH: XSS через dangerouslySetInnerHTML (5 файлов, 8 вхождений)

| # | Файл | Контекст | Риск |
|---|------|---------|------|
| **V-XSS1** | `frontend/src/shared/ui/forms/users/forms-components/user-identification-card.tsx` | QR-код подписки | **HIGH** — если QR содержит XSS-код |
| **V-XSS2** | `widgets/dashboard/subpage-configs/*-components/*.tsx` (6 вхождений) | SVG иконки | **MEDIUM** — SVG-контент из библиотеки приложения |
| **V-XSS3** | `features/ui/dashboard/users/get-user-subscription-links/get-user-subscription-links.feature.tsx` | Генерация SVG ссылок | **MEDIUM** — отрендеренный SVG с user data |

**Подробно V-XSS1:**
```tsx
<div dangerouslySetInnerHTML={{
    __html: subscriptionQrCode  // QR-код с user-контентом
}} />
```
QR-код содержит ссылки подписки с `shortUuid` (user input). Если злоумышленник контролирует shortUuid, может внедрить XSS.

**Рекомендации:**
1. Заменить `dangerouslySetInnerHTML` на безопасный `DOMPurify.sanitize()` для SVG
2. Для QR-кодов использовать специализированную библиотеку (`qrcode.react`)
3. Для SVG из библиотеки — валидировать что это реально SVG перед рендером

---

## 3. CSRF (CROSS-SITE REQUEST FORGERY)

### 🔴 HIGH: Отсутствует CSRF защита

**Проблема (V-CSRF1):** Backend не использует CSRF токены. Аутентификация через JWT в `Authorization: Bearer` header — это защищает от простого CSRF (браузер не добавит header автоматически), но:

- **Cookie auth** закомментирован в коде, но если включить — уязвимость
- **CORS** разрешён для `*` в dev mode
- **Subscription endpoints** (`/api/sub/*`) не имеют CSRF защиты (но они public)

**Рекомендация:** Убедиться что cookie auth остаётся выключенным. При включении — добавить SameSite=Strict + CSRF токен.

---

## 4. SSRF (SERVER-SIDE REQUEST FORGERY)

### 🔴 HIGH: WEBHOOK_URL без валидации (V-SSRF1)

**Файл:** `backend_source/src/common/config/app-config/config.schema.ts`
```typescript
WEBHOOK_URL: z.string().optional()
    .refine(val => val.startsWith('http://') || val.startsWith('https://'));
```

Валидирует только http/https префикс. Нет проверки:
- На loopback адреса (`127.0.0.1`, `localhost`, `169.254.x.x`)
- На internal сети (`10.x.x.x`, `172.16.x.x`, `192.168.x.x`)
- На DNS rebinding

**Потенциальное использование:** Злоумышленник с доступом к `.env` может настроить WEBHOOK_URL на internal сервисы.

### MEDIUM: Node адрес не валидируется на SSRF (V-SSRF2)

**Файл:** Backend подключается к Node по address:port из БД.
```typescript
POST https://{node.address}:{node.port}/node/xray/start
```
Если злоумышленник создаст Node с address=127.0.0.1, Backend будет слать запросы к себе.

**Рекомендации:**
1. Проверять WEBHOOK_URL через allowlist (только внешние домены)
2. Валидировать node.address — запретить loopback/internal IP

---

## 5. RCE (REMOTE CODE EXECUTION)

### Risk Level: ✅ NOT VULNERABLE

**Проверка:**
- `exec()` / `execSync()` / `spawn()` — **не найдены** в приложении
- `eval()` — **не найдено**
- `child_process` — **не импортируется**
- Template rendering — YAML/JSON через библиотеки без eval
- Единственный `Prisma.raw()` — в CLI для обновления collation из .env

### LOW: CLI команды (V-RCE1)

**Файл:** `backend_source/src/bin/cli/cli.ts`
```typescript
await prisma.$executeRaw`ALTER DATABASE ${Prisma.raw(dbName)} REFRESH COLLATION VERSION;`;
```
`dbName` берётся из .env, но `Prisma.raw()` в теории может быть опасен, если кто-то модифицирует .env. **Только CLI, не API.**

---

## 6. PRIVILEGE ESCALATION

### MEDIUM: RolesGuard не проверяет наличие JWT (V-PE1)

**Файл:** `backend_source/src/common/guards/roles/roles.guard.ts`
```typescript
const { user } = context.switchToHttp().getRequest();
const hasRole = requiredRoles.some((role) => user.role?.includes(role));
```
Если `user` undefined (нет JWT), `user.role` упадёт с ошибкой, но:
- `@Roles()` работает только в паре с `@UseGuards(JwtDefaultGuard)`
- Если разработчик поставит `@Roles()` без `JwtDefaultGuard` — будет 500 error

### Проверка ролей на endpoint'ах:

**Admin-only (без API role) — правильные ограничения:**
- Passkeys, API Tokens, Remnawave Settings, Bulk ops

**Admin + API token — корректно:**
- Users, Nodes, Hosts CRUD, Templates, System Info

✅ Разделение ролей корректное. Для ADMIN role дополнительно проверяется Client-Type header.

---

## 7. TRANSPORT SECURITY

### MEDIUM: CSP слишком либеральный (V-TS1)

**Файл:** `backend_source/src/main.ts`
```typescript
contentSecurityPolicy: {
    directives: {
        defaultSrc: ["'self'", '*'],
        scriptSrc: ["'self'", "'unsafe-inline'", "'unsafe-eval'", '*'],
        imgSrc: ["'self'", 'data:', '*'],
        connectSrc: ["'self'", '*'],
        // ...
    },
}
```

**Проблемы:**
- `script-src: 'unsafe-inline' 'unsafe-eval' *` — разрешает любые скрипты
- `default-src: *` — разрешает загрузку откуда угодно
- CSP практически бесполезен

**Рекомендация:**
```
script-src: 'self';  // убрать unsafe-inline/eval если возможно
frame-src: 'self';   // убрать oauth.telegram.org если не используется
```

### LOW: Отсутствуют HSTS headers (V-TS2)

**Вердикт:** Helmet установлен, но некоторые важные заголовки не настроены:
- `Strict-Transport-Security` (HSTS) — не установлен
- `X-Content-Type-Options: nosniff` — не проверен

---

## 8. AUTHENTICATION VULNERABILITIES (from Stage 5)

Подробно в `AUTH_SYSTEM_REPORT.md`. Кратко:

### CRITICAL (3)
| ID | Уязвимость | Статус |
|----|-----------|--------|
| V-A1 | **Нет brute-force защиты** на /api/auth/login | ❌ |
| V-A2 | **Нет refresh token ротации** JWT (до 168ч жизни) | ❌ |
| V-A3 | **JWT в localStorage** — уязвимость к XSS | ❌ |

### HIGH (4)
| ID | Уязвимость |
|----|-----------|
| V-A4 | OAuth2 все логины → один админ (нет audit trail) |
| V-A5 | `remnawaveAccess` claim в ID token — обход email проверки |
| V-A6 | API токены бессрочные (99999 дней) |
| V-A7 | JWT_AUTH_SECRET = HMAC ключ для паролей (общий секрет) |

---

## 9. NODE-SPECIFIC SECURITY FINDINGS

### MEDIUM: Internal Token передаётся в URL query string (V-N1)

**Файл:** supervisord.conf
```xml
command=/usr/local/bin/rw-core -config http+unix://...
    /internal/get-config?token=${INTERNAL_REST_TOKEN} -format json
```

Токен в URL может:
- Попасть в логи (supervisord, nginx, application logs)
- Быть виден через `ps aux` при ошибках

**Рекомендация:** Использовать HTTP header вместо query param.

### MEDIUM: No rate limiting на internal API (V-N2)

**Файл:** `internal.controller.ts`
- GET `/internal/get-config` — нет rate limiting
- POST `/internal/webhook` — нет rate limiting
- Защита только через Unix socket + token

**Рекомендация:** Добавить rate limiting даже на Unix socket.

### LOW: SUPERVISORD/PANEL_STARTED credentials в логах (V-N3)

**Файл:** `node_source/src/main.ts`
```typescript
this.logger.debug(JSON.stringify(headers));
```
Логирует все заголовки, включая возможные credentials.

---

## 10. DEPENDENCY VULNERABILITIES

### Проверенные версии:

| Пакет | Версия | Комментарий |
|-------|--------|------------|
| `react` | 19.2.4 | ✅ Latest stable |
| `next` (не используется) | — | ❌ Отсутствует (Vite вместо Next.js) |
| `monaco-editor` | 0.52.2 | ✅ Security patches applied |
| `prisma` | 6.19.0 | ✅ Current major |
| `ioredis` | 5.9.3 | ✅ No known vulns |
| `helmet` | 8.1.0 | ✅ Latest |
| `zod` | 3.25.76 | ✅ Active development |
| `passport` | 0.7.0 | ✅ Latest |
| `axios` | 1.13.6 | ✅ Current |
| `bullmq` | 5.69.3 | ✅ Active development |

### Потенциальные риски:
- `@remnawave/hashed-set` v0.0.4 — внутренняя разработка, непроверенный аудит
- `nftables-napi` v0.4.2 — native C++ addon, может содержать memory safety issues
- `sockdestroy` v1.3.0 — native addon, низкоуровневая работа с /proc/net/tcp

---

## 11. AURORA SECURITY IMPROVEMENT PLAN

### P0 — Критические (немедленно)
1. **Rate Limiting** на `/api/auth/login` (5 attempts/min/IP)
2. **Refresh Token архитектура** — замена stateless JWT на access+refresh с ротацией
3. **HttpOnly cookie** для JWT вместо localStorage

### P1 — Высокие (до Stage 12)
4. **CSP hardening** — убрать `unsafe-inline`, `unsafe-eval`, `*` из script-src
5. **XSS защита** — заменить `dangerouslySetInnerHTML` на DOMPurify или React-компоненты
6. **Multi-Admin для OAuth2** — раздельные учётки вместо единого первого админа
7. **Удалить `remnawaveAccess` claim** или ограничить его
8. **API Token TTL** — уменьшить с 273 лет до 90 дней

### P2 — Средние
9. **SSRF защита** — валидация WEBHOOK_URL и node.address
10. **Account lockout** — 10 попыток → 15 мин блокировки
11. **JWT + HMAC раздельные секреты**
12. **MFA/TOTP** — второй фактор для админов
13. **HSTS заголовки** — добавить `Strict-Transport-Security`
14. **Internal token** — перейти на Header вместо query param

### P3 — Низкие
15. **Test coverage** для security-critical функций
16. **Secrets scanning** — проверка на утечки в логах
17. **Dependency audit** — регулярный `npm audit` в CI/CD
18. **Security headers** — X-Content-Type-Options, Permissions-Policy

---

*End of Stage 8 — SECURITY_AUDIT.md*
