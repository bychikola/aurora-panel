# AURORA BRAND TRANSFORMATION

> **Stage 12: Brand Transformation**
> **Date:** 2026-06-24
> **Status:** COMPLETE (Specification)

---

## 1. BRAND IDENTITY

### 1.1 Brand Concept

```
AURORA — Named after the Russian cruiser "Aurora"
Theme: Military-Naval, Premium Dark
Tagline: "Navigate the storm"
```

### 1.2 Color Palette

```
Background:      #090909  (deepest black)
Surface:         #131313  (near-black)
Border:          #252525  (subtle gray border)
Primary:         #FF7A00  (vibrant orange — "naval flare")
Primary Hover:   #FF8F1F  (lighter orange)
Text:            #F2F2F2  (near-white)
Muted:           #A0A0A0  (muted gray)
Success:         #2EA043  (green)
Error:           #F85149  (red)
Warning:         #D29922  (yellow)
Info:            #58A6FF  (blue)
```

### 1.3 Typography

```
Headings:   Unbounded (already configured) — bold, geometric
Body:       Montserrat (already configured)
Monospace:  Fira Code (was Fira Mono)
```

---

## 2. DESIGN SYSTEM DETAILS

### 2.1 Mantine Theme Migration

**File:** `frontend/src/shared/constants/theme/theme.ts`

```typescript
// CURRENT (Remnawave — GitHub Dark)
colors: {
    dark: ['#c9d1d9','#b1bac4','#8b949e','#6e7681','#484f58','#30363d','#21262d','#161b22','#0d1117','#010409'],
    'shaded-gray': ['#f5f5f5','#e8e8e8','#d4d4d4','#c0c0c0','#a8a8a8','#a0a0a0','#808080','#686868','#505050','#383838']
},
primaryColor: 'cyan',
primaryShade: 8,

// AURORA — Premium Dark Naval
colors: {
    dark: [
        '#F2F2F2',  // 0 — text on dark
        '#E0E0E0',  // 1
        '#B0B0B0',  // 2
        '#A0A0A0',  // 3 — muted
        '#808080',  // 4
        '#505050',  // 5
        '#383838',  // 6
        '#252525',  // 7 — border
        '#131313',  // 8 — surface
        '#090909',  // 9 — background
    ],
    aurora: [
        '#FFF0E0',  // 0
        '#FFD6B3',  // 1
        '#FFB880',  // 2
        '#FF9A4D',  // 3
        '#FF8F1F',  // 4 — primary hover
        '#FF7A00',  // 5 — primary
        '#CC6200',  // 6
        '#994900',  // 7
        '#663100',  // 8
        '#331800',  // 9
    ],
    'shaded-gray': [...] // keep same
},
primaryColor: 'aurora',
primaryShade: 5,
```

### 2.2 CSS Variables

**File:** `frontend/src/global.css`

```css
:root {
    --aurora-bg: #090909;
    --aurora-surface: #131313;
    --aurora-border: #252525;
    --aurora-primary: #FF7A00;
    --aurora-primary-hover: #FF8F1F;
    --aurora-text: #F2F2F2;
    --aurora-muted: #A0A0A0;
}
```

### 2.3 Logo (SVG — Cruiser Aurora Silhouette)

```
┌─────────────────────────────────────────────┐
│           AURORA LOGO CONCEPT                │
├─────────────────────────────────────────────┤
│                                              │
│  Current: Bar chart (Remnawave)              │
│  New: Simplified cruiser silhouette          │
│  Colors: #FF7A00 on #131313 background       │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │           ╔══╗                         │  │
│  │       ╔══╝  ╚══╗                      │  │
│  │    ╔══╝       ╚══╗                    │  │
│  │ ╔══╝            ╚══╗                  │  │
│  │ ╚══╗            ╔══╝                  │  │
│  │    ╚══╗       ╔══╝                   │  │
│  │       ╚══╗  ╔══╝                     │  │
│  │          ╚══╝                        │  │
│  └────────────────────────────────────────┘  │
│  "AURORA" in Unbounded, bold, #F2F2F2       │
│                                              │
└─────────────────────────────────────────────┘
```

---

## 3. FILES TO MODIFY

### 3.1 Frontend — Branding & UI

| # | Файл | Изменение |
|---|------|----------|
| 1 | `src/config.ts` | `name: 'Remnawave'` → `'AURORA'` |
| 2 | `src/config.ts` | GitHub URLs → AURORA org |
| 3 | `src/shared/constants/theme/theme.ts` | Цветовая схема (см. 2.1) |
| 4 | `src/shared/constants/theme/colors-resolver.tsx` | Primary color name → aurora |
| 5 | `src/shared/ui/logo.tsx` | Новый SVG (cruiser silhouette) |
| 6 | `src/shared/ui/sidebar/sidebar-logo.tsx` | Цвет → aurora primary |
| 7 | `src/shared/ui/sidebar/sidebar-title.tsx` | `'Remnawave'` → `'AURORA'` |
| 8 | `src/shared/ui/header-buttons/VersionControl.tsx` | Remnawave → AURORA |
| 9 | `src/shared/constants/menu-sections.ts` (if exists) | Remnawave → AURORA |
| 10 | `src/shared/ui/header-buttons/RecapControl.tsx` | Remnawave → AURORA |
| 11 | `src/global.css` | CSS variables (см. 2.2) |

### 3.2 Frontend — Component Overrides (Mantine)

| # | Файл | Изменение |
|---|------|----------|
| 12 | `src/shared/constants/theme/overrides/buttons.tsx` | Цвета кнопок → aurora |
| 13 | `src/shared/constants/theme/overrides/inputs.ts` | Фокус → aurora |
| 14 | `src/shared/constants/theme/overrides/modal/index.tsx` | Бордеры → #252525 |
| 15 | `src/shared/constants/theme/overrides/drawer/index.tsx` | Бордеры → #252525 |
| 16 | `src/shared/constants/theme/overrides/card/index.ts` | Бордеры → #252525 |
| 17 | `src/shared/constants/theme/overrides/table.ts` | Row hover → aurora highlight |

### 3.3 Frontend — i18n Strings

| # | Файл | Изменение |
|---|------|----------|
| 18 | `public/locales/en/remnawave.json` | `remnawave` → `aurora` namespace |
| 19 | `public/locales/ru/remnawave.json` | Все "Remnawave" → "AURORA" |
| 20 | `public/locales/fa/remnawave.json` | —"— |
| 21 | `public/locales/zh/remnawave.json` | —"— |
| 22 | `src/app/i18n/i18n.ts` | NS name → aurora |

### 3.4 Backend — Branding

| # | Файл | Изменение |
|---|------|----------|
| 23 | `src/common/utils/startup-app/get-start-message.ts` | ASCII art → AURORA |
| 24 | `src/common/config/app-config/config.schema.ts` | `__RW_METADATA_*` → `__AURORA_METADATA_*` |
| 25 | `package.json` | `name: "@remnawave/backend"` → `"@aurora/backend"` |
| 26 | `Dockerfile` | image tags |
| 27 | `docker-compose-*.yml` | container names, image names |

### 3.5 Node — Branding

| # | Файл | Изменение |
|---|------|----------|
| 28 | `src/common/utils/get-start-message.ts` | ASCII art → AURORA |
| 29 | `libs/contract/constants/xray/stats.ts` | `REMNAWAVE_API_INBOUND` → `AURORA_API_INBOUND` |
| 30 | `package.json` | `name: "@remnawave/node"` → `"@aurora/node"` |

### 3.6 Shared Contract Packages

| # | Пакет | Новое имя |
|---|-------|-----------|
| 31 | `@remnawave/backend` | `@aurora/backend` |
| 32 | `@remnawave/frontend` | `@aurora/frontend` |
| 33 | `@remnawave/node` | `@aurora/node` |
| 34 | `@remnawave/backend-contract` | `@aurora/contract` |
| 35 | `@remnawave/node-contract` | `@aurora/node-contract` |
| 36 | `@remnawave/node-plugins` | `@aurora/node-plugins` |
| 37 | `@remnawave/subscription-page-types` | `@aurora/subscription-page-types` |
| 38 | `@remnawave/hashed-set` | `@aurora/hashed-set` |
| 39 | `@remnawave/xtls-sdk` | `@aurora/xtls-sdk` |
| 40 | `@remnawave/xtls-sdk-nestjs` | `@aurora/xtls-sdk-nestjs` |
| 41 | `@remnawave/supervisord-nestjs` | `@aurora/supervisord-nestjs` |

### 3.7 API & URL Paths

| # | Текущий | Новый |
|---|---------|-------|
| 42 | `REMNAWAVE_API_INBOUND` (node) | `AURORA_API_INBOUND` |
| 43 | `REMNAWAVE_API` (node) | `AURORA_API` |
| 44 | `x-remnawave-client-type` header | `x-aurora-client-type` |
| 45 | `x-remnawave-real-ip` header | `x-aurora-real-ip` |
| 46 | `remnawave_settings` table | `aurora_settings` (rename in schema) |

### 3.8 Database

| # | Изменение | Комментарий |
|---|-----------|------------|
| 47 | `remnawave_settings` → `aurora_settings` | Migration rename |
| 48 | All `@@map("remnawave_settings")` in schema | Change to aurora |
| 49 | Seed data references | Update |

---

## 4. NEW LOGO SPECIFICATION

### 4.1 Favicon

```
Size: 32x32, 16x16 (ICO format)
Colors: #FF7A00 on transparent
Symbol: Simplified cruiser bow silhouette
```

### 4.2 PWA Assets

```
All sizes generated via @vite-pwa/assets-generator
Source: SVG of aurora logo
Preset: minimal-2023 (current setup)
```

### 4.3 Loading Screen / Splash

```
Color: #090909 background
Logo: Aurora logo (white/orange)
Animation: Subtle pulse or wave animation
```

---

## 5. IMPLEMENTATION NOTES

### 5.1 Order of Changes

```
1. Package names (npm) → require contract package publications
2. Theme colors → instant UI change
3. Logo → requires new SVG asset
4. API headers → requires backend + frontend sync
5. Database → requires migration (last, after everything)
6. Documentation → parallel with code changes
```

### 5.2 Backward Compatibility

Для постепенного перехода (Phase 0 из Stage 11):

```typescript
// Accept both old and new headers during transition
const clientType = headers['x-aurora-client-type'] 
    ?? headers['x-remnawave-client-type'] 
    ?? REMNAWAVE_CLIENT_TYPE_BROWSER;
```

### 5.3 Contract Package Migration

Поскольку `@remnawave/backend-contract` импортируется и frontend и backend:

```
1. Publish @aurora/contract (copy of @remnawave/backend-contract)
2. Update backend imports → @aurora/contract
3. Update frontend imports → @aurora/contract
4. Deprecate @remnawave/backend-contract
```

---

## 6. BRAND TOUCHPOINTS CHECKLIST

- [ ] Application name everywhere
- [ ] Color scheme (Mantine theme + CSS)
- [ ] Logo (SVG, favicon, PWA)
- [ ] Loading screen
- [ ] Sidebar title and icon
- [ ] Header controls (version, update info)
- [ ] Login page branding
- [ ] Subscription page branding (if applicable)
- [ ] Docker image names
- [ ] Package names (npm)
- [ ] API headers
- [ ] Database table names
- [ ] ASCII art startup messages
- [ ] README and documentation
- [ ] GitHub organization references
- [ ] Social links (Telegram, forum)
- [ ] Error pages (404, 500)
- [ ] Email/webhook notification templates

---

## 7. CURRENT STATE SNAPSHOT (Before Transformation)

### Frontend (current Remnawave theme)
```
Background:  #0d1117  (GitHub dark)
Primary:     cyan (#22d3ee)
Text:        #c9d1d9
Logo:        Bar chart icon
Fonts:       Montserrat, Fira Mono
Sidebar:     "Remnawave" text + icon
```

### Backend
```
Package:     @remnawave/backend
Settings:    remnawave_settings table
Headers:     x-remnawave-client-type, x-remnawave-real-ip
API Tag:     "Remnawave API" (Swagger)
```

### Node
```
Package:     @remnawave/node
Inbound Tag: REMNAWAVE_API_INBOUND
API Tag:     REMNAWAVE_API
```

---

## 8. TARGET STATE (AURORA)

### Frontend (Premium Dark Naval)
```
Background:  #090909
Primary:     #FF7A00 (aurora)
Text:        #F2F2F2
Logo:        Cruiser Aurora silhouette
Fonts:       Montserrat, Fira Code
Sidebar:     "AURORA" in Unbounded bold
```

### Backend
```
Package:     @aurora/backend
Settings:    aurora_settings table
Headers:     x-aurora-client-type, x-aurora-real-ip
API Tag:     "AURORA API"
```

### Node
```
Package:     @aurora/node
Inbound Tag: AURORA_API_INBOUND
API Tag:     AURORA_API
```

---

*End of Stage 12 — Brand Transformation Specification*
