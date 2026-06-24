#!/bin/sh
# ═══════════════════════════════════════════════════════════════
# AURORA — Build frontend THEN start Docker
# ═══════════════════════════════════════════════════════════════
set -e

echo "=== Step 1: Build Frontend ==="
cd frontend_source

if [ ! -d "node_modules" ]; then
    echo "Installing frontend dependencies..."
    npm ci --legacy-peer-deps
fi

echo "Building frontend (vite)..."
NODE_OPTIONS="--max-old-space-size=2048" npx vite build

cd ..

echo ""
echo "=== Step 2: Start Docker ==="
docker compose up -d --build

echo ""
echo "=== Done! ==="
echo "API:    http://$(hostname -I | awk '{print $1}'):3000"
echo "Panel:  http://$(hostname -I | awk '{print $1}'):3000"
echo ""
echo "Create admin: docker exec aurora-panel npx prisma db seed"
