# AURORA NEXT GENERATION — Architecture Blueprint

> **Stage 13: Next Generation Features**
> **Date:** 2026-06-24
> **Status:** COMPLETE

---

## 1. SYSTEM VISION

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      AURORA NEXT GENERATION                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    CURRENT (v2) → TARGET (v3)                     │   │
│  ├──────────────────────────────────────────────────────────────────┤   │
│  │                                                                   │   │
│  │  Single Panel → Multi Master Cluster                             │   │
│  │  Manual Node Selection → Geo Routing + Smart LB                  │   │
│  │  Basic White Label → Full White Label Platform                   │   │
│  │  External Squads → Reseller Platform                              │   │
│  │  Telegram Notifications → Telegram Ecosystem                      │   │
│  │  No Billing → Billing Core + API Marketplace                     │   │
│  │  Xray Only → Xray + Sing-box Support                             │   │
│  │  Single Point of Failure → High Availability Mode                │   │
│  │                                                                   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. MULTI MASTER CLUSTER

### 2.1 Problem

Current: Single Backend panel. If it goes down — no subscription delivery, no user management, no stats.

### 2.2 Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       AURORA MULTI MASTER CLUSTER                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐       ┌──────────────┐       ┌──────────────┐        │
│  │  Aurora-1    │       │  Aurora-2    │       │  Aurora-3    │        │
│  │  (Active)    │◄─────►│  (Active)    │◄─────►│  (Active)    │        │
│  └──────┬───────┘       └──────┬───────┘       └──────┬───────┘        │
│         │                      │                      │                 │
│         └──────────────────────┼──────────────────────┘                 │
│                                │                                        │
│                        ┌───────┴────────┐                               │
│                        │  PostgreSQL    │                               │
│                        │  (Patroni HA)  │                               │
│                        │  Primary + Repl│                               │
│                        └────────────────┘                               │
│                                                                          │
│                        ┌───────┴────────┐                               │
│                        │  Valkey/Redis  │                               │
│                        │  (Cluster/Sent)│                               │
│                        └────────────────┘                               │
│                                                                          │
│  ┌──────────────┐       ┌──────────────┐       ┌──────────────┐        │
│  │  HAProxy/LB  │       │  HAProxy/LB  │       │  HAProxy/LB  │        │
│  │  (Region EU) │       │  (Region US) │       │  (Region AS) │        │
│  └──────────────┘       └──────────────┘       └──────────────┘        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.3 Key Design Decisions

| Аспект | Решение | Обоснование |
|--------|---------|-------------|
| **DB** | PostgreSQL Patroni (Active-Active) | Синхронная репликация, auto-failover |
| **Redis** | Valkey Cluster (3+ nodes) | No single point of failure |
| **API** | Active-Active (all instances serve) | Stateless JWT, any instance works |
| **Scheduler** | Distributed lock (Redis Redlock) | Только 1 scheduler активен |
| **Workers** | Active-Active (auto-distribution) | BullMQ handles concurrency |
| **Node → Panel** | HAProxy frontend | Node знает только один endpoint |

### 2.4 Database Migration

```
Current: Single PostgreSQL
Target: Patroni HA Cluster (Primary + 2 Standby)
Migration: 
  1. Set up streaming replication
  2. Configure Patroni
  3. Switch application connection to HAProxy
  4. Verify no data loss
```

---

## 3. GEO ROUTING + SMART LOAD BALANCER

### 3.1 Problem

Current: Each user gets ALL nodes. No geo-aware node selection. No load-aware distribution.

### 3.2 Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    AURORA GEO ROUTING ENGINE                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Subscription Request → GeoIP → Node Scoring → Top N Nodes              │
│                                                                          │
│  GeoIP Service:                                                         │
│  ├── MaxMind GeoLite2 / ip2location                                     │
│  ├── Определяет страну и регион пользователя                            │
│  └── Сопоставляет с регионами нод                                       │
│                                                                          │
│  Node Scoring Algorithm:                                                │
│  ├── Geo distance (weight: 0.5)                                        │
│  ├── Current load (weight: 0.2)                                        │
│  ├── Available bandwidth (weight: 0.2)                                  │
│  └── Random offset (weight: 0.1) — для распределения                   │
│                                                                          │
│  Smart LB:                                                              │
│  ├── User → ближайший регион                                            │
│  ├── Внутри региона: load-balanced по текущей загрузке                  │
│  ├── Если регион перегружен → spillover к соседнему                     │
│  └── Узлы с низкой latency имеют приоритет                              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.3 Data Model

```prisma
model AuroraGeoRegion {
    id      String @id
    name    String @unique
    lat     Float
    lon     Float
    nodes   Nodes[]
}

model AuroraNodeMetric {
    nodeId      BigInt
    cpuLoad     Float
    memoryUsed  Float
    bandwidthUsed BigInt
    onlineUsers   Int
    latencyMs     Float
    recordedAt    DateTime
}
```

### 3.4 Implementation Phases

| Phase | Features | Time |
|-------|----------|------|
| **P1** | GeoIP-based sorting (MaxMind) | 1 week |
| **P2** | Load-based scoring (node metrics) | 1 week |
| **P3** | Spillover to nearest region | 1 week |
| **P4** | Auto-scaling (add/remove nodes) | 2 weeks |

---

## 4. WHITE LABEL PLATFORM

### 4.1 Problem

Current: External Squads provide basic White Label (custom headers, host overrides). No full whitelabel.

### 4.2 AURORA White Label

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       AURORA WHITE LABEL                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Current (External Squads):                                             │
│  ├── Custom subscription settings                                       │
│  ├── Custom host overrides                                              │
│  ├── Custom response headers                                            │
│  ├── Custom remarks                                                     │
│  └── Custom subscription page config                                    │
│                                                                          │
│  AURORA adds:                                                           │
│  ├── ✅ Custom domain (dedicated sub domain)                            │
│  ├── ✅ Custom branding (logo, colors, name)                            │
│  ├── ✅ Custom Telegram bot (per-whitelabel)                            │
│  ├── ✅ Custom subscription page (full CSS/HTML)                        │
│  ├── ✅ Custom pricing tiers                                             │
│  ├── ✅ Admin panel access (limited to own users)                       │
│  └── ✅ API access (scoped to own resources)                            │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 4.3 Data Model Extensions

```prisma
model AuroraWhiteLabel {
    id          String @id
    squadUuid   String @unique  // links to external squad
    domain      String @unique
    themeConfig Json   // colors, logo, fonts, etc.
    tgBotToken  String?
    adminUsers  String[] // admin UUIDs allowed to manage
    pricingJson Json?
}
```

---

## 5. TELEGRAM ECOSYSTEM

### 5.1 Problem

Current: Telegram bot only for notifications (node up/down, user events). No interactive commands.

### 5.2 AURORA Telegram Ecosystem

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       AURORA TELEGRAM ECOSYSTEM                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Current: Passive notifications                                         │
│  ├── Node status changes                                                │
│  ├── User login attempts                                                │
│  ├── Bandwidth notifications                                            │
│  └── Torrent blocker reports                                            │
│                                                                          │
│  AURORA adds:                                                           │
│  ├── ✅ Interactive commands:                                            │
│  │    /users — user list                                                │
│  │    /stats — system stats                                             │
│  │    /nodes — node status                                              │
│  │    /create — quick user creation                                     │
│  │    /revoke — revoke user                                             │
│  │    /traffic — traffic stats                                          │
│  ├── ✅ Inline mode:                                                     │
│  │    @aurorabot search users                                           │
│  ├── ✅ Payment notifications                                            │
│  ├── ✅ 2FA approval requests                                            │
│  └── ✅ User self-service via Telegram Mini App                          │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.3 Bot Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    TELEGRAM BOT ARCHITECTURE                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Telegram API ← Grammy ← TelegramBotModule (NestJS)                     │
│                              │                                           │
│                              ├── Command Handlers (CQRS)                 │
│                              │    ├── /users → UsersQuery               │
│                              │    ├── /stats → SystemQuery              │
│                              │    └── /create → CreateUserCommand       │
│                              │                                           │
│                              ├── Inline Queries                          │
│                              │    └── Search users                      │
│                              │                                           │
│                              ├── Callback Queries                        │
│                              │    └── Admin actions                      │
│                              │                                           │
│                              └── Mini App (via WebApp)                   │
│                                   └── /apps/telegram (Next.js?)          │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 6. BILLING CORE

### 6.1 Problem

Current: Infrastructure billing only (tracking provider costs). No user billing, no payment processing.

### 6.2 AURORA Billing

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        AURORA BILLING CORE                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Payment Gateways:                                                      │
│  ├── Crypto (USDT TRC20/BEP20, TRX, BTC, ETH)                          │
│  ├── Stripe (Credit cards)                                              │
│  ├── PayPal                                                              │
│  └── Telegram Stars (TON blockchain)                                    │
│                                                                          │
│  Pricing Models:                                                        │
│  ├── Traffic-based (GB/TB)                                              │
│  ├── Time-based (daily/weekly/monthly/yearly)                           │
│  ├── Speed-tier (slow/medium/unspeed)                                   │
│  ├── Node-tier (specific regions)                                       │
│  └── Custom (reseller-defined)                                          │
│                                                                          │
│  Invoice System:                                                        │
│  ├── Auto-invoicing on payment                                          │
│  ├── Subscription renewal management                                    │
│  ├── Trial periods                                                      │
│  └── Discount codes / promo campaigns                                   │
│                                                                          │
│  Wallet System:                                                         │
│  ├── Balance top-up                                                     │
│  ├── Auto-debit from balance                                            │
│  └── Referral bonuses                                                   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 6.3 Data Model

```prisma
model AuroraPaymentGateway {
    id     String @id
    type   String // crypto | stripe | paypal | tgstars
    config Json
    enabled Boolean @default(true)
}

model AuroraInvoice {
    id         String   @id
    userUuid   String
    amount     Float
    currency   String   @default("USD")
    status     String   // pending | paid | expired | refunded
    gatewayId  String
    txHash     String?  // blockchain tx hash
    paidAt     DateTime?
    createdAt  DateTime @default(now())
}

model AuroraSubscription {
    id        String   @id
    userUuid  String
    planId    String
    startAt   DateTime
    endAt     DateTime
    autoRenew Boolean  @default(true)
    status    String   // active | cancelled | expired
}

model AuroraWallet {
    userUuid   String  @id
    balance    BigInt  @default(0) // in smallest unit
    createdAt  DateTime @default(now())
}
```

---

## 7. RESELLER PLATFORM

### 7.1 Problem

Current: External Squads allow some reselling (custom configs). No management UI for resellers.

### 7.2 AURORA Reseller Platform

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       AURORA RESELLER PLATFORM                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Reseller Tiers:                                                        │
│  ├── Silver: up to 100 users                                            │
│  ├── Gold: up to 1000 users                                             │
│  └── Platinum: unlimited                                                │
│                                                                          │
│  Reseller Features:                                                     │
│  ├── ✅ Own admin panel (limited to own users)                          │
│  ├── ✅ User CRUD (create/delete/revoke)                                │
│  ├── ✅ Bulk import (CSV)                                               │
│  ├── ✅ Custom pricing (set own prices)                                 │
│  ├── ✅ Traffic monitoring dashboard                                    │
│  ├── ✅ Automated top-up via billing core                               │
│  └── ✅ White label (custom domain + branding)                          │
│                                                                          │
│  Pricing:                                                               │
│  ├── Admin sets wholesale price                                          │
│  ├── Reseller sets retail price                                          │
│  └── Profit = (retail - wholesale) × users                              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 7.3 Data Model

```prisma
model AuroraReseller {
    uuid        String @id
    adminUuid   String @unique  // links to admin user
    tier        String // silver | gold | platinum
    userLimit   Int
    userCount   Int     @default(0)
    wholesalePrice Float
    balance      BigInt @default(0)
    parentUuid  String? // upline reseller (multi-level)
}
```

---

## 8. SING-BOX SUPPORT

### 8.1 Problem

Current: Xray-core only. Sing-box (clash-meta successor) is increasingly popular, especially on mobile (iOS).

### 8.2 Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     AURORA SING-BOX SUPPORT                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Current: Xray-core (rw-core fork)                                      │
│                                                                          │
│  AURORA adds:                                                           │
│  ├── Sing-box binary support on Nodes                                   │
│  │   ├── Config generation for Sing-box                                 │
│  │   ├── gRPC API parity (HandlerService, StatsService)                 │
│  │   └── Supervisord process management                                 │
│  │                                                                       │
│  ├── Subscription templates for Sing-box                                │
│  │   ├── JSON format (native Sing-box)                                  │
│  │   └── Compatibility with Xray configs                                 │
│  │                                                                       │
│  └── Hybrid mode: Xray + Sing-box on same node                          │
│      ├── Different inbounds for different cores                         │
│      └── User protocol detection → appropriate core                    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 8.3 Node Agent Extension

```typescript
// Node agent — dual core selection
interface INodeCores {
    activeCore: 'xray' | 'sing-box' | 'hybrid';
    
    // Per-core users
    xrayUsers: HashedSet;
    singBoxUsers: HashedSet;
    
    // Per-core stats
    xrayStats: StatsService;
    singBoxStats: SingBoxStatsService;
}
```

---

## 9. API MARKETPLACE

### 9.1 Concept

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       AURORA API MARKETPLACE                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Public API for developers:                                             │
│  ├── User management (CRUD)                                             │
│  ├── Traffic stats (per user, per node)                                 │
│  ├── Node health monitoring                                              │
│  ├── Subscription management                                            │
│  └── Webhook events (push)                                              │
│                                                                          │
│  Developer Features:                                                    │
│  ├── API key management (with TTL, scopes, rate limits)                 │
│  ├── API documentation (OpenAPI 3.0)                                    │
│  ├── SDK generators (TypeScript, Python, Go)                            │
│  ├── Webhook subscriptions (select events)                              │
│  └── Rate limiting tiers (free/pro/enterprise)                          │
│                                                                          │
│  Monetization:                                                          │
│  ├── Free tier: 1000 requests/day                                       │
│  ├── Pro tier: 100000 requests/day                                      │
│  └── Enterprise: unlimited                                              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 10. HIGH AVAILABILITY MODE

### 10.1 HA Design

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     AURORA HIGH AVAILABILITY MODE                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Component          │  Solution                    │ RTO  │ RPO         │
│─────────────────────│─────────────────────────────│──────│─────────────│
│  Backend API        │  Multi-instance (PM2 + LB) │ 0    │ N/A         │
│  PostgreSQL         │  Patroni HA + repmgr       │ 30s  │ < 1 MB      │
│  Valkey/Redis       │  Cluster (3+ nodes)        │ 0    │ N/A         │
│  Scheduler          │  Redlock + standby         │ 10s  │ N/A         │
│  Workers            │  BullMQ (auto-rebalance)   │ 0    │ N/A         │
│  Node communication │  DNS-based failover        │ 60s  │ N/A         │
│  Frontend           │  CDN (Cloudflare/static)   │ 0    │ N/A         │
│  Subscription       │  CDN cache + stale-while   │ 0    │ < 60min     │
│                     │  -revalidate               │      │             │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 10.2 Disaster Recovery Scenarios

| Сценарий | Автоматическое восстановление | Время |
|----------|------------------------------|-------|
| Backend instance crash | PM2 restart (immediate) | < 1s |
| Full region outage | DNS failover + DB replica promotion | < 5min |
| DB primary failure | Patroni auto-failover | < 30s |
| Redis node failure | Cluster rebalance | < 1s |
| Network partition | Circuit breaker + retry | < 1min |

---

## 11. IMPLEMENTATION ROADMAP

```
2026 Q3                    2026 Q4                    2027 Q1
────────────────┼──────────────────────┼──────────────────────►

Phase 1 (Core):             Phase 2 (Ecosystem):      Phase 3 (Scale):
├── Sing-box support        ├── Telegram Ecosystem    ├── Multi Master
├── HA Mode (DB cluster)    ├── Billing Core (crypto) ├── Reseller Platform
├── Geo Routing (GeoIP)     ├── API Marketplace       ├── Smart Load Balancer
├── White Label (extended)  ├── Webhook system        └── Auto-scaling
└── Performance fixes       └── SDK packages
```

| Phase | Features | Effort | Dependencies |
|-------|----------|--------|-------------|
| **1** | Sing-box, HA, GeoIP, WL perf | 8-10 weeks | Stage 11 migration must be complete |
| **2** | Telegram, Billing, Marketplace | 10-12 weeks | Phase 1 APIs stable |
| **3** | Cluster, Reseller, Smart LB | 12-16 weeks | Phases 1-2 complete |

---

## 12. FUTURE ARCHITECTURE DIAGRAM (Target v3)

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│                         AURORA v3 — TARGET ARCHITECTURE                              │
├────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│                    ┌────────────────────────────────────────────┐                    │
│                    │              AURORA ADMIN UI                │                    │
│                    │  (React SPA + White Label + Reseller UI)    │                    │
│                    └──────────────────┬─────────────────────────┘                    │
│                                       │                                              │
│  ┌──────────────┐  ┌──────────────────┼──────────────────┐  ┌──────────────────┐   │
│  │  Telegram    │  │                  │                   │  │  API Market      │   │
│  │  Bot + Mini  │  │       HAProxy / LB                   │  │  (OpenAPI)       │   │
│  │  App         │  └──────────────────┼──────────────────┘  └──────────────────┘   │
│  └──────────────┘                     │                                              │
│                                       ▼                                              │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                         AURORA CLUSTER (Active-Active)                        │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐             │   │
│  │  │ Aurora-1   │  │ Aurora-2   │  │ Aurora-3   │  │ Aurora-4   │             │   │
│  │  │ (region EU)│  │ (region US)│  │ (region AS)│  │ (reserved) │             │   │
│  │  └──────┬─────┘  └──────┬─────┘  └──────┬─────┘  └────────────┘             │   │
│  └─────────┼───────────────┼───────────────┼────────────────────────────────────┘   │
│            │               │               │                                       │
│            └───────────────┼───────────────┘                                       │
│                            │                                                        │
│                    ┌───────┴────────┐                                               │
│                    │  Patroni HA    │                                               │
│                    │  PostgreSQL    │                                               │
│                    │  (Primary + 2) │                                               │
│                    └────────────────┘                                               │
│                                                                                      │
│                    ┌───────┴────────┐                                               │
│                    │  Valkey Cluster│                                               │
│                    │  (3 + 2)       │                                               │
│                    └────────────────┘                                               │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                          EDGE NODES (Data Plane)                             │   │
│  │                                                                              │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │   │
│  │  │ Node EU-1    │  │ Node US-1    │  │ Node AS-1    │  │ Node LATAM-1 │   │   │
│  │  │ Xray/Singbox │  │ Xray/Singbox │  │ Xray/Singbox │  │ Xray/Singbox │   │   │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘   │   │
│  │         │                 │                 │                │           │   │
│  │  ┌──────┴───────┐  ┌──────┴───────┐  ┌──────┴───────┐  ┌──────┴───────┐   │   │
│  │  │ Node EU-2    │  │ Node US-2    │  │ Node AS-2    │  │ Node LATAM-2 │   │   │
│  │  │ Xray/Singbox │  │ Xray/Singbox │  │ Xray/Singbox │  │ Xray/Singbox │   │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │  INTEGRATIONS                                                                  │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │   │
│  │  │ Stripe   │ │ Crypto   │ │ Telegram │ │ Cloudflare│ │ MaxMind  │           │   │
│  │  │ (CC)     │ │ (USDT)   │ │ (Bot/App)│ │ (CDN/DNS)│ │ (GeoIP)  │           │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘           │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 13. RISK & FEASIBILITY

| Feature | Risk | Feasibility | Key Challenge |
|---------|------|-------------|---------------|
| Multi Master Cluster | MEDIUM | ✅ 8/10 | Database replication, distributed locks |
| Geo Routing | LOW | ✅ 9/10 | MaxMind integration |
| Smart Load Balancer | MEDIUM | ✅ 7/10 | Real-time node metrics |
| White Label | LOW | ✅ 9/10 | Extension of existing External Squads |
| Telegram Ecosystem | MEDIUM | ✅ 8/10 | State management for interactive commands |
| Billing Core | HIGH | ✅ 6/10 | Payment compliance, fraud prevention |
| Reseller Platform | MEDIUM | ✅ 7/10 | Multi-tenancy, RBAC, pricing |
| Sing-box Support | HIGH | ✅ 7/10 | Custom fork for remote config |
| API Marketplace | LOW | ✅ 8/10 | Rate limiting, API keys |
| High Availability | MEDIUM | ✅ 8/10 | Infrastructure cost, testing |

---

*End of Stage 13 — AURORA_NEXT_GEN.md*
