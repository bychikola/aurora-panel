# ═══════════════════════════════════════════════════════════════
# AURORA — Production Docker Image
# Frontend + Backend are PREBUILT by GitHub Actions
# Docker only installs production dependencies and copies dists
# ═══════════════════════════════════════════════════════════════

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

# Install production dependencies only (no compilation)
COPY backend_source/package*.json ./
COPY backend_source/prisma ./prisma
COPY backend_source/prisma.config.ts ./
COPY backend_source/patches ./patches
COPY backend_source/.npmrc ./
RUN npm ci --omit=dev

# Copy prebuilt dists (from GitHub Actions)
COPY backend_source/dist/ ./dist/
COPY frontend_source/dist/ ./frontend/

COPY backend_source/configs /var/lib/aurora/configs
COPY backend_source/libs ./libs
COPY backend_source/ecosystem.config.js ./
COPY backend_source/docker-entrypoint.sh ./

RUN npm install pm2 -g && npm link

ENTRYPOINT [ "/bin/sh", "docker-entrypoint.sh" ]
CMD [ "pm2-runtime", "start", "ecosystem.config.js", "--env", "production" ]
