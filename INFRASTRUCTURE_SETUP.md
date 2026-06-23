# AURORA Infrastructure Setup

> **Phase 6: Infrastructure**
> **Date:** 2026-06-24
> **Status:** COMPLETE

---

## 1. MONO-REPO STRUCTURE

```
aurora/
├── packages/
│   ├── backend/          # @aurora/backend (NestJS API)
│   ├── frontend/         # @aurora/frontend (React SPA)
│   └── node/             # @aurora/node (Edge Agent)
├── libs/
│   ├── contract/         # @aurora/contract (shared Zod schemas)
│   ├── node-contract/    # @aurora/node-contract
│   ├── node-plugins/     # @aurora/node-plugins
│   ├── hashed-set/       # @aurora/hashed-set
│   └── xtls-sdk/         # @aurora/xtls-sdk
├── docker/
│   ├── docker-compose.yml
│   ├── docker-compose.prod.yml
│   └── docker-compose.dev.yml
├── .github/
│   └── workflows/
│       ├── ci.yml
│       ├── deploy-backend.yml
│       ├── deploy-frontend.yml
│       └── deploy-node.yml
├── package.json          # root workspace
├── tsconfig.base.json    # shared TS config
└── README.md
```

## 2. CI/CD Pipeline

```yaml
# .github/workflows/ci.yml
name: CI
on: [pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run lint

  typecheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npx tsc --noEmit

  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm audit --audit-level=high
      - run: npx trivy fs . --severity HIGH,CRITICAL

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm test
```

## 3. Version Sync Strategy

```bash
# Single root version, synchronized across all packages
AURORA_VERSION=3.0.0

# Update all package.json files
jq --arg v "$AURORA_VERSION" '.version = $v' packages/backend/package.json > tmp && mv tmp packages/backend/package.json
jq --arg v "$AURORA_VERSION" '.version = $v' packages/frontend/package.json > tmp && mv tmp packages/frontend/package.json
jq --arg v "$AURORA_VERSION" '.version = $v' packages/node/package.json > tmp && mv tmp packages/node/package.json
```

## 4. OpenAPI Setup

```bash
# Auto-generate OpenAPI spec from backend
cd packages/backend
npm run generate:openapi
# Output: openapi.json

# Serve via Scalar at /scalar (already implemented)
# Add Node API spec (new)
```

## 5. Read Replicas

```yaml
# docker-compose.prod.yml extension
services:
  aurora-db-primary:
    image: postgres:17.6
    environment:
      POSTGRES_DB: aurora
      PRIMARY: "true"

  aurora-db-replica:
    image: postgres:17.6
    depends_on: [aurora-db-primary]
    environment:
      PRIMARY_HOST: aurora-db-primary
```

## 6. Docker Files

```dockerfile
# Dockerfile (multi-stage)
FROM node:24-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:24-alpine AS runner
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
EXPOSE 3000
CMD ["node", "dist/main"]
```
