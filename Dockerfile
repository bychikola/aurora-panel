# ═══════════════════════════════════════════════════════════════
# AURORA — Production Docker Image
# Builds frontend (Vite React SPA) + backend (NestJS API)
# ═══════════════════════════════════════════════════════════════

# ─── Stage 1: Frontend Build ─────────────────────────────────
FROM node:24-alpine AS frontend-build
WORKDIR /app/frontend

COPY frontend_source/package*.json ./
RUN npm ci

COPY frontend_source/ ./
RUN npm run build

# ─── Stage 2: Backend Build ──────────────────────────────────
FROM node:24-trixie-slim AS backend-build
WORKDIR /app/backend

COPY backend_source/package*.json ./
COPY backend_source/prisma ./prisma
COPY backend_source/prisma.config.ts ./
COPY backend_source/patches ./patches
COPY backend_source/.npmrc ./

RUN npm ci

COPY backend_source/ ./
RUN npm run migrate:generate
RUN npm run build
RUN npm cache clean --force
RUN npm prune --omit=dev

# ─── Stage 3: Production Image ───────────────────────────────
FROM node:24-trixie-slim

LABEL org.opencontainers.image.title="AURORA Panel"
LABEL org.opencontainers.image.description="Powerful proxy management tool built on Xray-core"
LABEL org.opencontainers.image.url="https://github.com/aurora/panel"
LABEL org.opencontainers.image.source="https://github.com/aurora/panel"
LABEL org.opencontainers.image.vendor="AURORA"
LABEL org.opencontainers.image.licenses="AGPL-3.0"

WORKDIR /opt/app

RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

ENV PRISMA_HIDE_UPDATE_MESSAGE=true
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1
ENV PM2_DISABLE_VERSION_CHECK=true
ENV NODE_OPTIONS="--max-old-space-size=16384"

COPY --from=backend-build /app/backend/dist ./dist
COPY --from=frontend-build /app/frontend/dist ./frontend
COPY --from=backend-build /app/backend/prisma ./prisma
COPY --from=backend-build /app/backend/patches ./patches
COPY --from=backend-build /app/backend/node_modules ./node_modules

COPY backend_source/configs /var/lib/aurora/configs
COPY backend_source/package*.json ./
COPY backend_source/prisma.config.ts ./
COPY backend_source/libs ./libs
COPY backend_source/ecosystem.config.js ./
COPY backend_source/docker-entrypoint.sh ./

RUN npm install pm2 -g && npm link

ENTRYPOINT ["/bin/sh", "docker-entrypoint.sh"]
CMD ["pm2-runtime", "start", "ecosystem.config.js", "--env", "production"]
