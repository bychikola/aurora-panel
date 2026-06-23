# API CATALOG — Remnawave → AURORA

> **Stage 4: API Intelligence**
> **Date:** 2026-06-23
> **Status:** COMPLETE

---

## 1. API OVERVIEW

| API | Base URL | Auth | Transport |
|-----|---------|------|-----------|
| **Backend REST** | `/api/*` | JWT Bearer (HS256) | HTTPS |
| **Backend Public** | `/api/sub/*`, `/api/subscriptions/*` | Subscription Token (URL param) | HTTPS |
| **Backend Metrics** | `/metrics` | Basic Auth | HTTPS |
| **Backend Health** | `/health` | None | HTTP |
| **Node REST** | `/node/*` | JWT Bearer (RS256) | HTTPS (mTLS) |
| **Node Internal** | `/internal/*` | Token (query param) | HTTP (Unix Socket) |
| **Node Vision** | `/block-ip`, `/unblock-ip` | JWT Bearer | HTTPS (mTLS) |

---

## 2. BACKEND AUTHENTICATED API (JWT Bearer)

> **Global Prefix:** `/api`
> **Auth:** `Authorization: Bearer <jwt>` (JwtDefaultGuard)
> **Role-based:** Some endpoints require `@Roles('ADMIN')` or `@Roles('API')`

---

### 2.1 Auth — `/api/auth`

| Method | URL | Auth | DTO | Response | Description |
|--------|-----|------|-----|----------|-------------|
| `POST` | `/api/auth/login` | Public | `LoginCommand.RequestSchema` | `{ accessToken }` | Password login |
| `POST` | `/api/auth/register` | Public | `RegisterCommand.RequestSchema` | `{ accessToken }` | First-run registration (only if 0 admins exist) |
| `GET` | `/api/auth/status` | Public | — | Auth methods status | Get enabled auth methods (password, passkey, oauth2 providers) |
| `GET` | `/api/auth/oauth2/authorize` | Public | Query: `provider` | `{ redirectUrl }` | Start OAuth2 flow |
| `GET` | `/api/auth/oauth2/callback` | Public | Query: `code`, `state`, `provider` | `{ accessToken }` | OAuth2 callback |
| `GET` | `/api/auth/oauth2/tg/callback` | Public | Query: Telegram data | `{ accessToken }` | Telegram OAuth callback |
| `GET` | `/api/auth/passkey/authentication/options` | Public | — | `{ options }` | Get WebAuthn challenge |
| `POST` | `/api/auth/passkey/authentication/verify` | Public | `VerifyPasskeyAuthCommand` | `{ accessToken }` | Verify WebAuthn response |

---

### 2.2 Users — `/api/users`

| Method | URL | Auth | DTO | Description |
|--------|-----|------|-----|-------------|
| `POST` | `/api/users` | JWT (ADMIN) | `CreateUserCommand` | Create VPN user |
| `PATCH` | `/api/users` | JWT (ADMIN) | `UpdateUserCommand` | Update user |
| `GET` | `/api/users` | JWT (ADMIN/API) | Query: pagination, filters | List all users |
| `DELETE` | `/api/users/:uuid` | JWT (ADMIN) | — | Delete user |
| `GET` | `/api/users/:uuid` | JWT (ADMIN/API) | — | Get user by UUID |
| `GET` | `/api/users/:uuid/accessible-nodes` | JWT | — | Get nodes accessible to user |
| `GET` | `/api/users/:uuid/subscription-request-history` | JWT | — | Get user's subscription request history |
| `POST` | `/api/users/:uuid/actions/enable` | JWT (ADMIN) | — | Enable user |
| `POST` | `/api/users/:uuid/actions/disable` | JWT (ADMIN) | — | Disable user |
| `POST` | `/api/users/:uuid/actions/reset-traffic` | JWT (ADMIN) | — | Reset user traffic |
| `POST` | `/api/users/:uuid/actions/revoke` | JWT (ADMIN) | — | Revoke user subscription |
| `GET` | `/api/users/by-id/:id` | JWT | — | Find user by id |
| `GET` | `/api/users/by-short-uuid/:shortUuid` | JWT | — | Find user by short UUID |
| `GET` | `/api/users/by-username/:username` | JWT | — | Find user by username |
| `GET` | `/api/users/by-subscription-uuid/:uuid` | JWT | — | Find user by subscription UUID |
| `GET` | `/api/users/by-telegram-id/:id` | JWT | — | Find user by Telegram ID |
| `GET` | `/api/users/by-email/:email` | JWT | — | Find user by email |
| `GET` | `/api/users/by-tag/:tag` | JWT | — | Find user by tag |
| `POST` | `/api/users/resolve` | JWT (ADMIN) | `ResolveUserCommand` | Resolve user by various fields |
| `GET` | `/api/users/tags` | JWT | — | Get all user tags |

**Bulk Operations:**
| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `POST` | `/api/users/bulk/delete-by-status` | JWT (ADMIN) | Delete users by status |
| `POST` | `/api/users/bulk/update` | JWT (ADMIN) | Bulk update selected users |
| `POST` | `/api/users/bulk/reset-traffic` | JWT (ADMIN) | Reset traffic for selected users |
| `POST` | `/api/users/bulk/revoke-subscription` | JWT (ADMIN) | Revoke subscriptions |
| `POST` | `/api/users/bulk/delete` | JWT (ADMIN) | Delete selected users |
| `POST` | `/api/users/bulk/update-squads` | JWT (ADMIN) | Update squad assignments |
| `POST` | `/api/users/bulk/extend-expiration-date` | JWT (ADMIN) | Extend expiry |
| `POST` | `/api/users/bulk/all/update` | JWT (ADMIN) | Update ALL users |
| `POST` | `/api/users/bulk/all/reset-traffic` | JWT (ADMIN) | Reset traffic for ALL users |
| `POST` | `/api/users/bulk/all/extend-expiration-date` | JWT (ADMIN) | Extend expiry for ALL users |

---

### 2.3 Nodes — `/api/nodes`

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `POST` | `/api/nodes` | JWT (ADMIN) | Create node (+ enqueue start) |
| `PATCH` | `/api/nodes` | JWT (ADMIN/API) | Update node |
| `GET` | `/api/nodes` | JWT (ADMIN/API) | Get all nodes |
| `GET` | `/api/nodes/:uuid` | JWT (ADMIN/API) | Get node by UUID |
| `DELETE` | `/api/nodes/:uuid` | JWT (ADMIN) | Delete node (+ stop) |
| `GET` | `/api/nodes/tags` | JWT | Get all node tags |
| `POST` | `/api/nodes/:uuid/actions/enable` | JWT (ADMIN) | Enable node |
| `POST` | `/api/nodes/:uuid/actions/disable` | JWT (ADMIN) | Disable node (+ stop) |
| `POST` | `/api/nodes/:uuid/actions/restart` | JWT (ADMIN) | Restart node |
| `POST` | `/api/nodes/:uuid/actions/reset-traffic` | JWT (ADMIN) | Reset node traffic |
| `POST` | `/api/nodes/actions/restart-all` | JWT (ADMIN) | Restart all enabled nodes |
| `POST` | `/api/nodes/actions/reorder` | JWT (ADMIN) | Reorder nodes |
| `POST` | `/api/nodes/bulk-actions/profile-modification` | JWT (ADMIN) | Bulk profile assignment |
| `POST` | `/api/nodes/bulk-actions` | JWT (ADMIN) | Bulk enable/disable/restart/reset |
| `POST` | `/api/nodes/bulk-actions/update` | JWT (ADMIN) | Bulk field update |

---

### 2.4 Hosts — `/api/hosts`

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `POST` | `/api/hosts` | JWT (ADMIN) | Create host |
| `PATCH` | `/api/hosts` | JWT (ADMIN) | Update host |
| `GET` | `/api/hosts` | JWT (ADMIN/API) | Get all hosts |
| `GET` | `/api/hosts/:uuid` | JWT (ADMIN/API) | Get host by UUID |
| `DELETE` | `/api/hosts/:uuid` | JWT (ADMIN) | Delete host |
| `POST` | `/api/hosts/actions/reorder` | JWT (ADMIN) | Reorder hosts |
| `POST` | `/api/hosts/bulk/enable` | JWT (ADMIN) | Bulk enable hosts |
| `POST` | `/api/hosts/bulk/disable` | JWT (ADMIN) | Bulk disable hosts |
| `POST` | `/api/hosts/bulk/delete` | JWT (ADMIN) | Bulk delete hosts |
| `POST` | `/api/hosts/bulk/set-inbound` | JWT (ADMIN) | Bulk set inbound |
| `POST` | `/api/hosts/bulk/set-port` | JWT (ADMIN) | Bulk set port |
| `GET` | `/api/hosts/tags` | JWT | Get all host tags |

---

### 2.5 Subscription Templates — `/api/subscription-template`

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `GET` | `/api/subscription-template` | JWT (ADMIN/API) | Get all templates |
| `POST` | `/api/subscription-template` | JWT (ADMIN) | Create template |
| `GET` | `/api/subscription-template/:uuid` | JWT (ADMIN/API) | Get template by UUID |
| `PATCH` | `/api/subscription-template` | JWT (ADMIN) | Update template (YAML/JSON) |
| `DELETE` | `/api/subscription-template/:uuid` | JWT (ADMIN) | Delete template |
| `POST` | `/api/subscription-template/actions/reorder` | JWT (ADMIN) | Reorder templates |

---

### 2.6 Subscription Settings — `/api/subscription-settings`

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `GET` | `/api/subscription-settings` | JWT (ADMIN/API) | Get subscription settings |
| `PATCH` | `/api/subscription-settings` | JWT (ADMIN) | Update subscription settings |

---

### 2.7 Subscription Page Configs — `/api/subscription-page-configs`

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `GET` | `/api/subscription-page-configs` | JWT (ADMIN/API) | Get all page configs |
| `POST` | `/api/subscription-page-configs` | JWT (ADMIN) | Create page config |
| `GET` | `/api/subscription-page-configs/:uuid` | JWT (ADMIN/API) | Get config by UUID |
| `PATCH` | `/api/subscription-page-configs` | JWT (ADMIN) | Update page config |
| `DELETE` | `/api/subscription-page-configs/:uuid` | JWT (ADMIN) | Delete page config |
| `POST` | `/api/subscription-page-configs/actions/reorder` | JWT (ADMIN) | Reorder |
| `POST` | `/api/subscription-page-configs/actions/clone` | JWT (ADMIN) | Clone config |

---

### 2.8 Config Profiles — `/api/config-profiles`

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `GET` | `/api/config-profiles` | JWT (ADMIN/API) | Get all profiles |
| `POST` | `/api/config-profiles` | JWT (ADMIN) | Create profile |
| `GET` | `/api/config-profiles/:uuid` | JWT (ADMIN/API) | Get profile by UUID |
| `PATCH` | `/api/config-profiles` | JWT (ADMIN) | Update profile |
| `DELETE` | `/api/config-profiles/:uuid` | JWT (ADMIN) | Delete profile |
| `GET` | `/api/config-profiles/:uuid/inbounds` | JWT | Get inbounds for profile |
| `GET` | `/api/config-profiles/:uuid/computed` | JWT | Get computed Xray config |
| `GET` | `/api/config-profiles/inbounds` | JWT | Get all inbounds |
| `POST` | `/api/config-profiles/actions/reorder` | JWT (ADMIN) | Reorder profiles |

---

### 2.9 Snippets — `/api/snippets`

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `GET` | `/api/snippets` | JWT | Get all snippets |
| `POST` | `/api/snippets` | JWT (ADMIN) | Create snippet |
| `PATCH` | `/api/snippets` | JWT (ADMIN) | Update snippet |
| `DELETE` | `/api/snippets` | JWT (ADMIN) | Delete snippet |

---

### 2.10 Internal Squads — `/api/internal-squads`

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `GET` | `/api/internal-squads` | JWT | Get all squads |
| `POST` | `/api/internal-squads` | JWT (ADMIN) | Create squad |
| `GET` | `/api/internal-squads/:uuid` | JWT | Get squad by UUID |
| `PATCH` | `/api/internal-squads` | JWT (ADMIN) | Update squad |
| `DELETE` | `/api/internal-squads/:uuid` | JWT (ADMIN) | Delete squad |
| `GET` | `/api/internal-squads/:uuid/accessible-nodes` | JWT | Get accessible nodes |
| `POST` | `/api/internal-squads/:uuid/bulk-actions/add-users` | JWT (ADMIN) | Add users to squad |
| `POST` | `/api/internal-squads/:uuid/bulk-actions/remove-users` | JWT (ADMIN) | Remove users from squad |
| `POST` | `/api/internal-squads/actions/reorder` | JWT (ADMIN) | Reorder squads |

---

### 2.11 External Squads — `/api/external-squads`

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `GET` | `/api/external-squads` | JWT | Get all external squads |
| `POST` | `/api/external-squads` | JWT (ADMIN) | Create external squad |
| `GET` | `/api/external-squads/:uuid` | JWT | Get squad by UUID |
| `PATCH` | `/api/external-squads` | JWT (ADMIN) | Update squad (overrides, settings) |
| `DELETE` | `/api/external-squads/:uuid` | JWT (ADMIN) | Delete squad |
| `POST` | `/api/external-squads/:uuid/bulk-actions/add-users` | JWT (ADMIN) | Add users |
| `POST` | `/api/external-squads/:uuid/bulk-actions/remove-users` | JWT (ADMIN) | Remove users |
| `POST` | `/api/external-squads/actions/reorder` | JWT (ADMIN) | Reorder squads |

---

### 2.12 HWID User Devices — `/api/hwid`

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `GET` | `/api/hwid` | JWT | Get all HWID devices (leaderboard) |
| `POST` | `/api/hwid` | JWT (ADMIN) | Create user HWID device |
| `GET` | `/api/hwid/:userUuid` | JWT | Get user's HWID devices |
| `DELETE` | `/api/hwid` | JWT (ADMIN) | Delete user HWID device |
| `DELETE` | `/api/hwid/all` | JWT (ADMIN) | Delete all user HWID devices |
| `GET` | `/api/hwid/stats` | JWT | Get HWID stats |
| `GET` | `/api/hwid/top` | JWT | Top users by device count |

---

### 2.13 Node Plugins — `/api/node-plugins`

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `GET` | `/api/node-plugins` | JWT | Get all plugins |
| `POST` | `/api/node-plugins` | JWT (ADMIN) | Create plugin |
| `GET` | `/api/node-plugins/:uuid` | JWT | Get plugin by UUID |
| `PATCH` | `/api/node-plugins` | JWT (ADMIN) | Update plugin |
| `DELETE` | `/api/node-plugins/:uuid` | JWT (ADMIN) | Delete plugin |
| `POST` | `/api/node-plugins/actions/reorder` | JWT (ADMIN) | Reorder |
| `POST` | `/api/node-plugins/actions/clone` | JWT (ADMIN) | Clone plugin |
| `POST` | `/api/node-plugins/executor` | JWT (ADMIN) | Execute plugin action |
| `GET` | `/api/node-plugins/torrent-blocker/reports` | JWT | Get torrent reports |
| `GET` | `/api/node-plugins/torrent-blocker/reports/stats` | JWT | Torrent report stats |
| `DELETE` | `/api/node-plugins/torrent-blocker/reports` | JWT (ADMIN) | Truncate reports |

---

### 2.14 API Tokens — `/api/api-tokens`

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `GET` | `/api/api-tokens` | JWT (ADMIN) | Get all tokens |
| `POST` | `/api/api-tokens` | JWT (ADMIN) | Create token |
| `DELETE` | `/api/api-tokens/:uuid` | JWT (ADMIN) | Delete token |

---

### 2.15 Passkeys — `/api/passkeys`

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `GET` | `/api/passkeys` | JWT (ADMIN) | Get all passkeys |
| `DELETE` | `/api/passkeys/:id` | JWT (ADMIN) | Delete passkey |
| `PATCH` | `/api/passkeys/:id` | JWT (ADMIN) | Update passkey name |
| `GET` | `/api/passkeys/registration/options` | JWT (ADMIN) | Get registration challenge |
| `POST` | `/api/passkeys/registration/verify` | JWT (ADMIN) | Verify registration |

---

### 2.16 Remnawave Settings — `/api/remnawave-settings`

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `GET` | `/api/remnawave-settings` | JWT (ADMIN) | Get panel settings |
| `PATCH` | `/api/remnawave-settings` | JWT (ADMIN) | Update settings (passkey, oauth2, branding) |

---

### 2.17 Keygen — `/api/keygen`

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `GET` | `/api/keygen` | JWT (ADMIN/API) | Get X25519 keys and certificates |

---

### 2.18 System — `/api/system`

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `GET` | `/api/system/health` | JWT | System healthcheck |
| `GET` | `/api/system/metadata` | JWT | System metadata (version, build) |
| `GET` | `/api/system/stats` | JWT | System statistics |
| `GET` | `/api/system/stats/bandwidth` | JWT | Bandwidth stats |
| `GET` | `/api/system/stats/nodes` | JWT | Node statistics |
| `GET` | `/api/system/stats/recap` | JWT | Recap/summary |
| `GET` | `/api/system/nodes/metrics` | JWT | Node metrics |
| `POST` | `/api/system/tools/x25519/generate` | JWT | Generate X25519 keypair |
| `POST` | `/api/system/tools/happ/encrypt` | JWT (ADMIN) | Encrypt HAPP crypto link |
| `POST` | `/api/system/testers/srr-matcher` | JWT (ADMIN) | Test SRR matcher |

---

### 2.19 Bandwidth Stats — `/api/bandwidth`

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `GET` | `/api/bandwidth/nodes` | JWT | Node bandwidth stats |
| `GET` | `/api/bandwidth/nodes/realtime` | JWT | Node realtime bandwidth |
| `GET` | `/api/bandwidth/nodes/:uuid` | JWT | Node users bandwidth |
| `GET` | `/api/bandwidth/users/:uuid` | JWT | User bandwidth |
| `GET` | `/api/bandwidth/nodes/:uuid/legacy` | JWT | Legacy node users bandwidth |
| `GET` | `/api/bandwidth/users/:uuid/legacy` | JWT | Legacy user bandwidth |

---

### 2.20 Infra Billing — `/api/infra-billing`

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `GET` | `/api/infra-billing/providers` | JWT | Get all providers |
| `POST` | `/api/infra-billing/providers` | JWT (ADMIN) | Create provider |
| `PATCH` | `/api/infra-billing/providers` | JWT (ADMIN) | Update provider |
| `DELETE` | `/api/infra-billing/providers/:uuid` | JWT (ADMIN) | Delete provider |
| `GET` | `/api/infra-billing/providers/:uuid` | JWT | Get provider by UUID |
| `GET` | `/api/infra-billing/nodes` | JWT | Get billing nodes |
| `POST` | `/api/infra-billing/nodes` | JWT (ADMIN) | Create billing node |
| `PATCH` | `/api/infra-billing/nodes` | JWT (ADMIN) | Update billing node |
| `DELETE` | `/api/infra-billing/nodes/:uuid` | JWT (ADMIN) | Delete billing node |
| `GET` | `/api/infra-billing/history` | JWT | Get billing history |
| `POST` | `/api/infra-billing/history` | JWT (ADMIN) | Create billing record |
| `DELETE` | `/api/infra-billing/history/:uuid` | JWT (ADMIN) | Delete billing record |

---

### 2.21 IP Control — `/api/ip-control`

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `POST` | `/api/ip-control/:uuid/fetch-ips` | JWT (ADMIN) | Fetch IPs from node |
| `GET` | `/api/ip-control/:jobId/result` | JWT | Get fetch result |
| `POST` | `/api/ip-control/drop-connections` | JWT (ADMIN) | Drop connections by IP |
| `POST` | `/api/ip-control/:nodeUuid/fetch-users-ips` | JWT (ADMIN) | Fetch user IPs from node |
| `GET` | `/api/ip-control/:jobId/users-result` | JWT | Get fetch users result |

---

### 2.22 Subscription Request History — `/api/subscription-request-history`

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `GET` | `/api/subscription-request-history` | JWT | Get request history |
| `GET` | `/api/subscription-request-history/stats` | JWT | Request stats |

---

### 2.23 Metadata — `/api/metadata`

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `GET` | `/api/metadata/nodes/:uuid` | JWT | Get node metadata |
| `PATCH` | `/api/metadata/nodes/:uuid` | JWT (ADMIN) | Upsert node metadata |
| `GET` | `/api/metadata/users/:uuid` | JWT | Get user metadata |
| `PATCH` | `/api/metadata/users/:uuid` | JWT (ADMIN) | Upsert user metadata |

---

### 2.24 Special Endpoints

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `GET` | `/health` | None | Terminus health check |
| `GET` | `/metrics` | Basic Auth | Prometheus metrics |
| `GET` | `/queues` | Basic Auth | Bull Board UI |
| `GET` | `/docs` | None (if enabled) | Swagger UI |
| `GET` | `/scalar` | None (if enabled) | Scalar API docs |

---

## 3. BACKEND PUBLIC API (No JWT, Subscription)

### 3.1 Client Subscription — `/api/sub`

| Method | URL | Auth | Response | Description |
|--------|-----|------|----------|-------------|
| `GET` | `/api/sub/:shortUuid` | URL token | Config text/JSON | **Main endpoint** — client gets VPN config |
| `GET` | `/api/sub/:shortUuid/info` | URL token | JSON | Subscription metadata (traffic, expiry) |

**Request flow:** `GET /api/sub/:shortUuid#:token` where `:token` is appended as URL fragment.
**Response content-type:** Varies by client — `text/plain`, `application/json`, `application/x-yaml`
**Client detection:** User-Agent header analyzed by ResponseRulesMiddleware

---

### 3.2 Admin Subscriptions — `/api/subscriptions`

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `GET` | `/api/subscriptions` | JWT (ADMIN/API) | Paginated subscription list |
| `GET` | `/api/subscriptions/by-username/:username` | JWT | Find by username |
| `GET` | `/api/subscriptions/by-uuid/:uuid` | JWT | Find by UUID |
| `GET` | `/api/subscriptions/by-short-uuid/:shortUuid` | JWT | Find by short UUID (info) |
| `GET` | `/api/subscriptions/by-short-uuid/:shortUuid/raw` | JWT (ADMIN) | Raw subscription debug |
| `GET` | `/api/subscriptions/subpage-config/:shortUuid` | Public | Get subpage config |
| `GET` | `/api/subscriptions/connection-keys/:uuid` | JWT | Get connection keys (enabled/disabled/hidden) |

---

## 4. NODE REST API (JWT RS256 + mTLS)

> **Global Prefix:** `/node`
> **Auth:** JWT Bearer (RS256) + mTLS at transport
> **Excluded from prefix:** `/block-ip`, `/unblock-ip`, `/internal/*`

---

### 4.1 Xray Control — `/node/xray`

| Method | URL | Auth | DTO | Description |
|--------|-----|------|-----|-------------|
| `POST` | `/node/xray/start` | JWT | `StartXrayCommand` | Start/restart Xray with config |
| `GET` | `/node/xray/stop` | JWT | Query: `withPluginCleanup`, `withOnlineCheck` | Stop Xray |
| `GET` | `/node/xray/healthcheck` | JWT | — | Get node health (version, xray status) |

---

### 4.2 Handler (User CRUD) — `/node/handler`

| Method | URL | Auth | DTO | Description |
|--------|-----|------|-----|-------------|
| `POST` | `/node/handler/add-user` | JWT | `AddUserCommand` | Add user to Xray core |
| `POST` | `/node/handler/remove-user` | JWT | `RemoveUserCommand` | Remove user from Xray core |
| `POST` | `/node/handler/get-inbound-users` | JWT | `GetInboundUsersCommand` | List users on inbound |
| `POST` | `/node/handler/get-inbound-users-count` | JWT | `GetInboundUsersCountCommand` | Count users on inbound |
| `POST` | `/node/handler/add-users` | JWT | `AddUsersCommand` | Bulk add users |
| `POST` | `/node/handler/remove-users` | JWT | `RemoveUsersCommand` | Bulk remove users |
| `POST` | `/node/handler/drop-users-connections` | JWT | `DropUsersConnectionsCommand` | Drop connections by userId |
| `POST` | `/node/handler/drop-ips` | JWT | `DropIpsCommand` | Drop connections by IP |

---

### 4.3 Stats — `/node/stats`

| Method | URL | Auth | DTO | Description |
|--------|-----|------|-----|-------------|
| `POST` | `/node/stats/get-user-online-status` | JWT | `GetUserOnlineStatusCommand` | Check if user is online |
| `POST` | `/node/stats/get-users-stats` | JWT | `GetUsersStatsCommand` | Get all user traffic stats (reset=true to reset) |
| `POST` | `/node/stats/get-system-stats` | JWT | `GetSystemStatsCommand` | System + network + Xray stats |
| `POST` | `/node/stats/get-inbound-stats` | JWT | `GetInboundStatsCommand` | Per-inbound traffic |
| `POST` | `/node/stats/get-outbound-stats` | JWT | `GetOutboundStatsCommand` | Per-outbound traffic |
| `POST` | `/node/stats/get-all-outbounds-stats` | JWT | `GetAllOutboundsStatsCommand` | All outbounds |
| `POST` | `/node/stats/get-all-inbounds-stats` | JWT | `GetAllInboundsStatsCommand` | All inbounds |
| `POST` | `/node/stats/get-combined-stats` | JWT | `GetCombinedStatsCommand` | Inbounds + outbounds |
| `POST` | `/node/stats/get-user-ip-list` | JWT | `GetUserIpListCommand` | Get IPs for one user |
| `POST` | `/node/stats/get-users-ip-list` | JWT | `GetUsersIpListCommand` | Get IPs for all online users |

---

### 4.4 Vision (IP Block/Unblock) — No prefix

| Method | URL | Auth | DTO | Description |
|--------|-----|------|-----|-------------|
| `POST` | `/block-ip` | JWT | `BlockIpCommand` | Add IP to Xray routing blacklist |
| `POST` | `/unblock-ip` | JWT | `UnblockIpCommand` | Remove IP from Xray routing blacklist |

---

### 4.5 Plugin — `/node/plugin`

| Method | URL | Auth | DTO | Description |
|--------|-----|------|-----|-------------|
| `POST` | `/node/plugin/sync` | JWT | `SyncPluginCommand` | Sync plugin config from panel |
| `POST` | `/node/plugin/torrent-blocker/collect` | JWT | — | Collect torrent reports |
| `POST` | `/node/plugin/nftables/block-ips` | JWT | `BlockIpsSchema` | Block IPs via nftables |
| `POST` | `/node/plugin/nftables/unblock-ips` | JWT | `UnblockIpsSchema` | Unblock IPs |
| `POST` | `/node/plugin/nftables/recreate-tables` | JWT | `RecreateTablesSchema` | Recreate nftables tables |

---

## 5. NODE INTERNAL API (Unix Socket, Query Token)

> **Transport:** HTTP over Unix Socket
> **Auth:** `?token=<INTERNAL_REST_TOKEN>` query parameter

| Method | URL | Description |
|--------|-----|-------------|
| `GET` | `/internal/get-config?token=<token>` | **Called by Xray-core** — returns merged Xray JSON config |
| `POST` | `/internal/webhook?token=<token>` | **Called by Xray-core** — torrent detection webhook |

---

## 6. API STATISTICS

| Category | Count |
|----------|-------|
| Backend authenticated endpoints | ~120 |
| Backend public endpoints | ~8 |
| Node REST endpoints | ~25 |
| Node internal endpoints | 2 |
| **Total documented endpoints** | **~155** |

### HTTP Method Distribution (Backend)

| Method | Usage |
|--------|-------|
| `GET` | 55% (reads, lookups, status) |
| `POST` | 30% (creates, actions, bulk ops) |
| `PATCH` | 10% (updates) |
| `DELETE` | 5% (deletes) |

### Auth Distribution (Backend)

| Auth Level | Endpoints |
|-----------|-----------|
| Public (no auth) | 8 (login, register, oauth2, passkey options, subpage config) |
| JWT (any role) | ~55 |
| JWT (ADMIN only) | ~45 |
| JWT (ADMIN or API) | ~12 |
| Basic Auth | 2 (/metrics, /queues) |

---

## 7. API PATTERNS & CONVENTIONS

### 7.1 URL Naming

- **Controller:** lowercase, RESTful (`users`, `nodes`, `hosts`)
- **Actions:** `/<uuid>/actions/<verb>` (e.g., `/nodes/:uuid/actions/restart`)
- **Bulk:** `/<resource>/bulk/<operation>` (e.g., `/users/bulk/delete`)
- **Lookup by field:** `/<resource>/by-<field>/<value>` (e.g., `/users/by-username/:name`)
- **Tags:** `/<resource>/tags` (GET for unique tags)

### 7.2 Request/Response Pattern

All responses follow a unified structure:
```json
{
  "isOk": true,
  "response": { /* DTO data */ },
  "errors": []
}
```

Error responses:
```json
{
  "isOk": false,
  "response": null,
  "errors": [{ "code": "ERROR_CODE", "message": "Human readable" }]
}
```

### 7.3 Validation

- All DTOs validated with **Zod** schemas (via `nestjs-zod` `ZodValidationPipe`)
- Backend and Frontend share schemas through `@remnawave/backend-contract`
- Node uses schemas from `@remnawave/node-contract`
- Response schemas are validated in frontend via `createGetQueryHook`/`createMutationHook`

### 7.4 Pagination (List Endpoints)

Standard pagination query parameters (used in users, hosts, nodes, subscriptions):
```
?page=1&pageSize=50&sortBy=createdAt&sortOrder=desc
```

---

## 8. API SECURITY MODEL

| Layer | Mechanism | Scope |
|-------|----------|-------|
| **Transport** | HTTPS (TLS) | All external traffic |
| **Transport (Node)** | HTTPS + mTLS | Backend ↔ Node communication |
| **App (Backend)** | JWT Bearer (HS256, 12h TTL) | Admin/API access |
| **App (Node)** | JWT Bearer (RS256, signed by Panel) | Node access |
| **API Tokens** | JWT Bearer (separate secret) | Programmatic API access |
| **Metrics** | HTTP Basic Auth | Prometheus /metrics |
| **Subscription** | URL token (embedded in shortUuid URL) | Client subscription delivery |
| **Internal (Node)** | Query param token | Xray ↔ Node (Unix Socket) |
| **RBAC** | `@Roles('ADMIN' | 'API')` via `RolesGuard` | Backend granular access |
| **CORS** | `*` in dev, `FRONT_END_DOMAIN` in prod | Browser access control |
| **Helmet** | CSP, COOP, CORP, Referrer-Policy | Security headers |

---

*End of Stage 4 — API_CATALOG.md*
