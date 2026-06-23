# AUTHENTICATION SYSTEM REPORT — Remnawave → AURORA

> **Stage 5: Authentication Forensics**
> **Date:** 2026-06-23
> **Status:** COMPLETE

---

## 1. EXECUTIVE SUMMARY

Аутентификация Remnawave реализована как многоуровневая система с раздельными механизмами для разных компонентов:

| Компонент | Алгоритм | Секрет | Время жизни |
|-----------|---------|--------|------------|
| Backend (Админы) | JWT HS256 | `JWT_AUTH_SECRET` | 12-168 часов |
| Backend (API токены) | JWT HS256 | `JWT_API_TOKENS_SECRET` | 99999 дней (~273 года) |
| Node (все эндпоинты) | JWT RS256 | `jwtPublicKey` из `SECRET_KEY` | Контролируется панелью |
| Node (internal) | Query param token | `INTERNAL_REST_TOKEN` (random 64 chars) | Бессрочно (генерируется при старте) |
| Метрики | HTTP Basic Auth | `METRICS_USER` / `METRICS_PASS` | N/A |
| Подписки | URL-embedded token | JWT (проверяется на бэкенде) | N/A |

---

## 2. BACKEND JWT (HS256) — ADMIN AUTHENTICATION

### 2.1 JWT Signing

**Файл:** `src/modules/auth/auth.service.ts`

```typescript
const accessToken = this.jwtService.sign(
    {
        username: admin.response.username,
        uuid: admin.response.uuid,
        role: ROLE.ADMIN,
    },
    { expiresIn: `${this.jwtLifetime}h` },  // default: 12h
);
```

**Payload:** `{ username: string, uuid: string, role: 'ADMIN' }`
**Секрет:** `JWT_AUTH_SECRET` из .env (HS256)
**Время жизни:** `JWT_AUTH_LIFETIME` часов (по умолчанию 12, макс 168)

### 2.2 JWT Verification Chain

```
Request: Authorization: Bearer <jwt>
    │
    ▼
JwtStrategy (passport-jwt)
    │ ExtractJwt.fromAuthHeaderAsBearerToken()
    │ secretOrKey: JWT_AUTH_SECRET
    │ ignoreExpiration: false
    │
    ▼
JwtDefaultGuard.canActivate()
    │
    ├── Role = ROLE.API → verifyApiToken(uuid)
    │   ├── Check Redis cache: api:<uuid>
    │   ├── If cached → ALLOW
    │   ├── If not cached → DB query GetTokenByUuid
    │   ├── Cache result in Redis for 1 hour
    │   └── ALLOW/DENY
    │
    ├── Role = ROLE.ADMIN → require Browser client
    │   ├── Check header: x-remnawave-client-type === 'browser'
    │   ├── If NOT browser → 403 ForbiddenException
    │   ├── Query admin by username FROM DATABASE
    │   ├── Compare stored UUID with JWT UUID
    │   └── ALLOW/DENY
    │
    └── Other roles → DENY
```

**Критическое наблюдение:** При КАЖДОМ запросе админа происходит запрос в БД (`GetAdminByUsernameQuery`). Кэширования админов нет — это защита от использования JWT после удаления админа.

### 2.3 Password Hashing

**Алгоритм:** HMAC-SHA256 + scrypt

```typescript
// Шаг 1: HMAC пароля с JWT_AUTH_SECRET как ключом
const hmacResult = createHmac('sha256', this.jwtSecret).update(password).digest();

// Шаг 2: scrypt(HMAC_result, random_salt, 64 bytes)
const derivedKey = await scryptAsync(hmacResult.toString('hex'), salt, 64);

// Хранение: salt:hash
return `${salt}:${hash}`;
```

**Оценка:**
- ✅ HMAC перед scrypt — дополнительная защита от rainbow table атак
- ✅ scrypt — memory-hard алгоритм, устойчив к GPU/ASIC атакам
- ✅ timingSafeEqual для сравнения хешей
- ⚠️ Параметры scrypt по умолчанию (N=16384, r=8, p=1) — достаточны для 2026
- ⚠️ HMAC ключ = JWT секрет. Если JWT секрет скомпрометирован, злоумышленник может:
  - Подписывать JWT (полный доступ)
  - Вычислять HMAC паролей (облегчает брутфорс паролей)

---

## 3. BACKEND API TOKENS

### 3.1 Генерация

```typescript
const payload: IJWTAuthPayload = {
    uuid: command.uuid,       // UUID API токена (не админа!)
    username: null,           // ВСЕГДА null
    role: ROLE.API,
};

this.jwtService.sign(payload, {
    expiresIn: '99999d',     // ~273 года — практически бессрочный
    secret: JWT_API_TOKENS_SECRET,  // ОТДЕЛЬНЫЙ секрет!
});
```

**Payload:** `{ uuid: string, username: null, role: 'API' }`
**Секрет:** `JWT_API_TOKENS_SECRET` (отдельный от `JWT_AUTH_SECRET`)
**Время жизни:** 99999 дней (~273 года)

### 3.2 Верификация

```
JwtDefaultGuard → role = ROLE.API → verifyApiToken(uuid)
    │
    ├── Кэш Redis: api:<uuid> → ALLOW (1 час)
    └── DB: GetTokenByUuid → Кэш (1 час) → ALLOW/DENY
```

**Особенности:**
- API токены не привязаны к админу — они автономны
- Удаление токена из БД инвалидирует его (но с задержкой до 1 часа из-за кэша)
- Для API токенов НЕТ проверки Browser header — они предназначены для машинного доступа

---

## 4. NODE JWT (RS256) — NODE-PANEL TRUST

### 4.1 Доверительная модель

```
Panel (Backend)
    │
    │ Генерирует SECRET_KEY = base64({
    │   caCertPem,       ← CA сертификат панели
    │   jwtPublicKey,    ← Публичный ключ RS256
    │   nodeCertPem,     ← Сертификат Node
    │   nodeKeyPem       ← Приватный ключ Node
    │ })
    │
    ▼
Node (Edge Agent)
    │
    │ parseNodePayload() → извлекает jwtPublicKey
    │ JwtModule: { secret: jwtPublicKey, algorithms: ['RS256'] }
    │
    │ HTTPS сервер: mTLS (сертификаты из SECRET_KEY)
    │
    ▼
Panel → Node: HTTPS (mTLS) + Authorization: Bearer <jwt RS256>
    │
    ▼
JwtDefaultGuard (Node) → Passport JWT RS256 → ALLOW/DENY
    │
    │ При ошибке: response.socket?.destroy()
    │ Логирует: 'Incorrect SECRET_KEY or JWT!'
```

### 4.2 Ключевые отличия Node JWT

| Аспект | Backend | Node |
|--------|---------|------|
| Алгоритм | HS256 (симметричный) | RS256 (асимметричный) |
| Секрет | Строка из .env | Публичный ключ из SECRET_KEY |
| Кто подписывает | Backend (себе) | Panel (для Node) |
| Роли | ADMIN, API | Нет ролей (проверяется только валидность) |
| DB проверка | Да (admin lookup) | Нет |
| Реакция на ошибку | 401 JSON | 401 + socket.destroy() |

---

## 5. OAUTH2 IMPLEMENTATION

### 5.1 Поддерживаемые провайдеры

| Провайдер | Тип | PKCE | Проверка email | Custom Claim |
|-----------|-----|------|---------------|--------------|
| **GitHub** | arctic.GitHub | ❌ | primary email из API | ❌ |
| **Yandex** | arctic.Yandex | ❌ | default_email | ❌ |
| **PocketID** | arctic.OAuth2Client | ❌ | email из ID token | ✅ remnawaveAccess |
| **Keycloak** | arctic.KeyCloak | ✅ S256 | email из ID token | ✅ remnawaveAccess |
| **Generic** | arctic.OAuth2Client | Опционально | email из ID token | ✅ remnawaveAccess |
| **Telegram** | arctic.OAuth2Client | ✅ S256 | Telegram ID (не email!) | ❌ |

### 5.2 OAuth2 Flow

```
1. Frontend: GET /api/auth/status → узнать доступные провайдеры
2. Frontend: POST /api/auth/oauth2/authorize { provider }
3. Backend:
   ├── Генерирует state (arctic.generateState)
   ├── Генерирует codeVerifier (если PKCE)
   ├── Сохраняет state → Redis (TTL 600s)
   ├── Сохраняет codeVerifier → Redis (TTL 600s, если PKCE)
   └── Возвращает authorizationUrl
4. Frontend: редирект на authorizationUrl
5. Провайдер: редирект обратно на /oauth2/callback/:provider?code=...&state=...
6. Frontend: POST /api/auth/oauth2/callback { provider, code, state }
7. Backend:
   ├── Проверяет state из Redis === state из запроса
   ├── Обменивает code на токены
   ├── Извлекает email из ID token / API
   ├── Проверяет email в allowedEmails ИЛИ наличие remnawaveAccess claim
   ├── Находит первого админа (getFirstAdmin)
   └── Выпускает JWT от имени первого админа
```

### 5.3 OAuth2 Уязвимости

**1. ALL OAuth2 логины выпускают JWT от имени ПЕРВОГО админа (getFirstAdmin)**

```typescript
// ЛЮБОЙ успешный OAuth2 логин выдаёт JWT первого админа
const jwtToken = this.jwtService.sign({
    username: firstAdmin.response.username,  // ← всегда первый админ
    uuid: firstAdmin.response.uuid,          // ← всегда UUID первого админа
    role: ROLE.ADMIN,
});
```

Это значит: **все OAuth2 пользователи разделяют одну учётную запись админа**. Нет разделения на разных админов, нет audit trail кто именно залогинился.

**2. `remnawaveAccess` claim — backdoor**

В ID token может присутствовать claim `remnawaveAccess: true`. Если он есть — email НЕ проверяется по allowedEmails. Это позволяет любому, кто контролирует OAuth2 провайдера (Keycloak/Generic/PocketID), добавить этот claim и обойти проверку email.

```typescript
const isAllowed = emailResult.hasCustomClaim || allowedEmails.includes(emailResult.email);
```

**3. GitHub/Yandex — нет PKCE**

GitHub и Yandex не используют PKCE (Proof Key for Code Exchange), что делает их уязвимыми к interception атакам на authorization code.

**4. State хранится в Redis 10 минут**

Этого достаточно для нормального flow, но state удаляется ДО проверки email (сразу после чтения). Если злоумышленник перехватит state и быстро использует его, есть короткое окно.

---

## 6. PASSKEY (WEBAUTHN/FIDO2)

### 6.1 Authentication Flow

```
1. GET /api/auth/passkey/authentication/options
   ├── Проверяет passkeySettings.enabled
   ├── Получает passkeys первого админа
   ├── Генерирует challenge через @simplewebauthn/server
   ├── Сохраняет challenge → Redis (TTL 60s)
   └── Возвращает PublicKeyCredentialRequestOptionsJSON

2. POST /api/auth/passkey/authentication/verify
   ├── Проверяет passkeySettings.enabled
   ├── Читает challenge из Redis
   ├── Ищет passkey по response.id + admin.uuid
   ├── verifyAuthenticationResponse(...)
   │   ├── expectedChallenge
   │   ├── expectedOrigin
   │   ├── expectedRPID
   │   ├── requireUserVerification: true
   │   └── credential.publicKey из БД (Bytes)
   ├── Обновляет counter в БД
   ├── Удаляет challenge из Redis
   └── Выпускает JWT первого админа
```

### 6.2 Passkey Registration (PasskeyController)

```
1. GET /api/passkeys/registration/options
   ├── JWT + ADMIN role required
   ├── Генерирует registration options
   └── Сохраняет challenge → Redis (TTL 60s)

2. POST /api/passkeys/registration/verify
   ├── JWT + ADMIN role required
   ├── Верифицирует attestation
   └── Сохраняет passkey в БД (publicKey как Bytes)
```

### 6.3 Passkey Security

- ✅ `requireUserVerification: true` — требует биометрию/PIN
- ✅ Counter обновляется после каждой аутентификации
- ✅ Challenge одноразовый (удаляется после проверки)
- ⚠️ Challenge TTL 60 секунд — коротко, может истечь на медленных устройствах
- ⚠️ Passkey привязан к ПЕРВОМУ админу (getFirstAdmin) — все passkey'и выпускают JWT одного пользователя

---

## 7. ROLES AND PERMISSIONS

### 7.1 Role Definitions

```typescript
// Backend (libs/contract/constants/roles/role.ts)
ROLE = { ADMIN: 'ADMIN', API: 'API' }

// Node (libs/contract/constants/roles/role.ts)
ROLE = { USER: 'user', ADMIN: 'admin' }  // НЕ ИСПОЛЬЗУЕТСЯ в guards
```

### 7.2 RBAC Implementation

```typescript
// RolesGuard
const requiredRoles = this.reflector.getAllAndOverride<TRole[]>(ROLE, [
    context.getHandler(),
    context.getClass(),
]);

const hasRole = requiredRoles.some((role) => user.role?.includes(role));
```

**Использование `@Roles()` декоратора:**
- `@Roles(ROLE.ADMIN)` — только админы (используется на 45+ endpoint'ах)
- `@Roles(ROLE.ADMIN, ROLE.API)` — админы или API токены (используется на 12+ endpoint'ах)
- Без декоратора — любой аутентифицированный пользователь

### 7.3 Permission Matrix

| Endpoint Group | ADMIN (Browser) | ADMIN (API header) | API Token |
|---------------|-----------------|-------------------|-----------|
| Auth (login, register, oauth2) | ✅ Публичный | ✅ Публичный | ❌ |
| Users CRUD | ✅ | ❌ | ✅ |
| Users Bulk | ✅ | ❌ | ❌ (ADMIN only) |
| Nodes CRUD | ✅ | ❌ | ✅ |
| Nodes Actions | ✅ | ❌ | ❌ (ADMIN only) |
| Hosts CRUD | ✅ | ❌ | ✅ |
| Templates CRUD | ✅ | ❌ | ✅ |
| Remnawave Settings | ✅ | ❌ | ❌ (ADMIN only) |
| Passkeys | ✅ | ❌ | ❌ (ADMIN only) |
| API Tokens | ✅ | ❌ | ❌ (ADMIN only) |
| System Info | ✅ | ❌ | ✅ |
| Subscription Delivery | ✅ Публичный | ✅ Публичный | ✅ Публичный |

**Защита от API-доступа с админским JWT:**
```typescript
// Если role=ADMIN, но client type ≠ BROWSER → 403
if (clientType !== REMNAWAVE_CLIENT_TYPE_BROWSER) {
    throw new ForbiddenException(
        'For API requests you must create own API-token in the admin dashboard.',
    );
}
```

---

## 8. NODE INTERNAL AUTH

### 8.1 Internal Token

```bash
# Генерируется в docker-entrypoint.sh
INTERNAL_REST_TOKEN=$(generateRandomString 64)
```

**Использование:**
- Xray-core запрашивает конфиг: `GET /internal/get-config?token=<TOKEN>`
- Xray-core отправляет вебхук: `POST /internal/webhook?token=<TOKEN>`

**Проверка:** `TokenAuthMiddleware`
```typescript
// Если токен не совпадает → socket.destroy() без ответа
if (req.query.token !== token) {
    res.socket?.destroy();
    return;
}
```

### 8.2 Безопасность Internal API

- ✅ Unix socket (не TCP) — доступ только изнутри контейнера
- ✅ Случайный 64-символьный токен
- ✅ Socket destroy без информации об ошибке
- ⚠️ Токен передаётся в URL query string — может попасть в логи
- ⚠️ Нет rate limiting на internal endpoints

---

## 9. SESSION MANAGEMENT

### 9.1 Текущее состояние: Stateless JWT

**Refresh токены ОТСУТСТВУЮТ.** Система полностью stateless:
- JWT выпускается при логине на 12-168 часов
- Когда JWT истекает — требуется повторный логин
- Нет механизма отзыва JWT (кроме смены секрета)

### 9.2 Token Storage (Frontend)

```typescript
// Zustand persist middleware → localStorage
const sessionStore = create(
    persist(
        (set) => ({
            token: '',
            setToken: (dto) => set({ token: dto.token }),
            removeToken: () => set({ token: '' })
        }),
        {
            name: 'sessionStore',
            partialize: (state) => ({ token: state.token }),
            storage: createJSONStorage(() => localStorage)
        }
    )
)

// Авто-синхронизация с Axios
useSessionStore.subscribe((state) => {
    setAuthorizationToken(state.token)
})
```

**Риски хранения JWT в localStorage:**
- ⚠️ Уязвимость к XSS (любой JS на домене может прочитать токен)
- ⚠️ Нет HttpOnly cookie опции
- ✅ Автоматический сброс всех stores при logout (resetAllStores)
- ✅ Очистка TanStack Query кэша при logout (clearQueryClient)

---

## 10. VULNERABILITY ANALYSIS

### 10.1 CRITICAL

| # | Уязвимость | Описание | Исправление |
|---|-----------|---------|------------|
| **V1** | **Нет brute-force защиты на login** | `POST /api/auth/login` не имеет rate limiting. Злоумышленник может перебирать пароли неограниченно. | Добавить rate limiting (например, 5 попыток в минуту с IP). |
| **V2** | **Нет refresh token ротации** | JWT живёт до 168 часов без возможности отзыва. Компрометация JWT = полный доступ на весь срок. | Добавить refresh tokens + blacklist для отозванных JWT. |
| **V3** | **JWT в localStorage** | Уязвимость к XSS. Любой скрипт на странице может украсть токен. | Использовать HttpOnly cookie для JWT + CSRF защиту. |

### 10.2 HIGH

| # | Уязвимость | Описание | Исправление |
|---|-----------|---------|------------|
| **V4** | **OAuth2: все логины → один админ** | Все OAuth2 аутентификации выпускают JWT от имени первого админа. Нет audit trail. | Создавать отдельные admin-аккаунты для каждого OAuth2 пользователя. |
| **V5** | **`remnawaveAccess` claim — обход проверки email** | Кастомный claim в ID token позволяет обойти проверку allowedEmails. Контролирующий OAuth2 провайдер может добавить этот claim любому пользователю. | Удалить этот backdoor или ограничить его конкретными провайдерами. |
| **V6** | **API токены бессрочные** | 99999 дней ~ 273 года. Удаление из БД не инвалидирует немедленно (кэш 1 час). | Уменьшить TTL до разумного (30-90 дней) + проверять БД при каждом запросе без кэша. |
| **V7** | **JWT_AUTH_SECRET = HMAC ключ для паролей** | Тот же секрет используется для подписи JWT и для HMAC паролей. Компрометация секрета = полный доступ + облегчение брутфорса. | Использовать раздельные секреты. |

### 10.3 MEDIUM

| # | Уязвимость | Описание | Исправление |
|---|-----------|---------|------------|
| **V8** | **GitHub/Yandex OAuth2 без PKCE** | Без PKCE authorization code interception более вероятен. | Добавить PKCE для всех провайдеров. |
| **V9** | **Admin кэширование отсутствует** | Каждый запрос админа делает DB lookup. Защита от deleted-admin JWT, но добавляет latency. | Добавить короткий кэш (5-10 секунд) с инвалидацией при изменении admin. |
| **V10** | **Passkey challenge TTL 60s** | Может истечь на медленных устройствах/пользователях. | Увеличить до 120-180 секунд. |
| **V11** | **Нет MFA** | Passkey заменяет пароль, а не дополняет его. Нет поддержки TOTP или второго фактора. | Добавить TOTP как второй фактор. |

### 10.4 LOW

| # | Уязвимость | Описание | Исправление |
|---|-----------|---------|------------|
| **V12** | **Внутренний токен в URL** | `?token=...` может логироваться прокси/балансировщиками. | Использовать HTTP header вместо query param. |
| **V13** | **Пароль в теле события LOGIN_ATTEMPT_FAILED** | Пароль попадает в EventEmitter (и потенциально в Telegram/Webhook уведомления). | Не включать пароль в события. |
| **V14** | **Отсутствует account lockout** | После N неудачных попыток аккаунт не блокируется. | Добавить lockout после 5-10 неудачных попыток. |

---

## 11. AUTH SECURITY POSTURE (Сводка)

| Аспект | Оценка | Комментарий |
|--------|--------|------------|
| **Password hashing** | ✅ Хорошо | HMAC+scrypt с timingSafeEqual |
| **JWT algorithm** | ✅ Хорошо | HS256 для backend, RS256 для node |
| **API tokens** | ⚠️ Средне | Бессрочные, но отдельный секрет |
| **OAuth2** | ⚠️ Средне | 6 провайдеров, но все логинятся под одним админом |
| **Passkey** | ✅ Хорошо | WebAuthn Level 2, user verification required |
| **Brute-force protection** | ❌ Отсутствует | Критическая уязвимость |
| **Refresh tokens** | ❌ Отсутствуют | Нет механизма отзыва JWT |
| **XSS protection (JWT)** | ❌ Слабо | JWT в localStorage |
| **MFA** | ⚠️ Частично | Passkey есть, но не second factor |
| **Audit trail** | ⚠️ Частично | События логина эмитятся, но OAuth2 не различает пользователей |
| **Rate limiting** | ❌ Отсутствует | Ни на одном endpoint |
| **Node auth** | ✅ Хорошо | mTLS + RS256 + socket destroy |

---

## 12. RECOMMENDED AURORA IMPROVEMENTS

1. **Refresh Token Architecture**: Ввести refresh tokens (opaque, stored in DB) с ротацией. Access token — 15 минут, refresh token — 7 дней.

2. **Rate Limiting**: Добавить `@nestjs/throttler` на login endpoint (5 попыток/минуту/IP).

3. **HttpOnly Cookies**: Хранить JWT в HttpOnly Secure SameSite cookie вместо localStorage.

4. **Multi-Admin OAuth2**: При OAuth2 логине создавать отдельного админа (или привязывать к существующему) вместо использования первого админа.

5. **Remove `remnawaveAccess` claim**: Или ограничить его включение только при явном админском флаге.

6. **API Token TTL**: Уменьшить время жизни API токенов до 90 дней с автоматическим продлением.

7. **Separate HMAC Secret**: Использовать отдельный секрет для HMAC паролей.

8. **Account Lockout**: Блокировать аккаунт после 10 неудачных попыток на 15 минут.

9. **MFA/TOTP**: Добавить Time-based OTP как второй фактор (passkey + TOTP или password + TOTP).

10. **Audit Trail**: Логировать UUID админа (не только username) во всех действиях.

---

*End of Stage 5 — AUTH_SYSTEM_REPORT.md*
