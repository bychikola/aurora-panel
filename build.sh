#!/bin/sh
# ═══════════════════════════════════════════════════════════════
# AURORA — Deploy script
# ═══════════════════════════════════════════════════════════════
set -e

echo "=== AURORA Panel Deploy ==="

# Frontend is built automatically by GitHub Actions
# If you see a placeholder page, go to:
#   https://github.com/bychikola/aurora-panel/actions
# And run the "Build Frontend" workflow, then git pull

# Copy .env if not exists
if [ ! -f ".env" ]; then
    cp .env.example .env
    echo "Created .env — please edit it with your values!"
fi

echo ""
echo "=== Starting Docker ==="
docker compose up -d --build

echo ""
echo "=== Done! ==="
echo ""
echo "Create admin user:"
echo "  docker exec aurora-panel npx prisma db seed"
echo ""
echo "If frontend shows placeholder — run 'Build Frontend' workflow at:"
echo "  https://github.com/bychikola/aurora-panel/actions"
