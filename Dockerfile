# ═══════════════════════════════════════════════════════════════
# AURORA — Production Docker Image
# Same approach as Remnawave: frontend is prebuilt, backend only in Docker
# ═══════════════════════════════════════════════════════════════

# ─── Stage 1: Copy Prebuilt Frontend ─────────────────────────
FROM alpine:3.21 AS frontend
WORKDIR /opt/frontend

# Frontend must be prebuilt BEFORE docker build:
#   cd frontend_source && npm install && npx vite build
# This copies the resulting dist/
COPY frontend_source/dist/ ./frontend_temp/dist/

# Fallback: if dist doesn't exist, create placeholder
RUN if [ ! -f frontend_temp/dist/index.html ]; then \
      mkdir -p frontend_temp/dist; \
      echo '<html><body><h1>AURORA</h1><p>Frontend build pending — run: cd frontend_source && npm install && npx vite build</p></body></html>' > frontend_temp/dist/index.html; \
    fi

# ─── Stage 2: Build Backend ─────────────────────────────────
FROM node:24.14-trixie-slim AS backend-build
WORKDIR /opt/app

ENV NODE_OPTIONS="--max-old-space-size=1400"
ENV PRISMA_CLI_BINARY_TARGETS=debian-openssl-3.0.x,linux-arm64-openssl-3.0.x

COPY backend_source/package*.json ./
COPY backend_source/prisma ./prisma
COPY backend_source/prisma.config.ts ./
COPY backend_source/patches ./patches
COPY backend_source/.npmrc ./

RUN npm ci --legacy-peer-deps

COPY backend_source/ ./

RUN npm run migrate:generate
RUN npm run build
RUN npm cache clean --force
RUN npm prune --omit=dev

# ─── Stage 3: Production Image ──────────────────────────────
FROM node:24.14-trixie-slim

LABEL org.opencontainers.image.title="AURORA Panel"
LABEL org.opencontainers.image.description="Powerful proxy management tool built on Xray-core"
LABEL org.opencontainers.image.url="https://github.com/bychikola/aurora-panel"
LABEL org.opencontainers.image.vendor="AURORA"
LABEL org.opencontainers.image.licenses="AGPL-3.0"

WORKDIR /opt/app

ENV PRISMA_HIDE_UPDATE_MESSAGE=true
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1
ENV PM2_DISABLE_VERSION_CHECK=true
ENV NODE_OPTIONS="--max-old-space-size=2048"

RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

COPY --from=backend-build /opt/app/dist ./dist
COPY --from=frontend /opt/frontend/frontend_temp/dist ./frontend
COPY --from=backend-build /opt/app/prisma ./prisma
COPY --from=backend-build /opt/app/patches ./patches
COPY --from=backend-build /opt/app/node_modules ./node_modules

COPY backend_source/configs /var/lib/aurora/configs
COPY backend_source/package*.json ./
COPY backend_source/prisma.config.ts ./
COPY backend_source/libs ./libs
COPY backend_source/ecosystem.config.js ./
COPY backend_source/docker-entrypoint.sh ./

RUN npm install pm2 -g && npm link

ENTRYPOINT [ "/bin/sh", "docker-entrypoint.sh" ]
CMD [ "pm2-runtime", "start", "ecosystem.config.js", "--env", "production" ]
