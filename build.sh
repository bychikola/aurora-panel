#!/bin/sh
set -e

echo "=== AURORA Panel Deploy ==="

if [ ! -f ".env" ]; then
    cp .env.example .env
    echo "Created .env — please edit it with your values!"
    exit 1
fi

echo "=== Starting Docker ==="
docker compose up -d --build

echo ""
echo "=== Done! ==="
echo "Access: http://$(hostname -I | awk '{print $1}'):3000"
echo "Create admin: docker exec aurora-panel npx prisma db seed"
