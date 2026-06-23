# AURORA — Production Deployment Guide

## Требования

- Сервер: Linux (Ubuntu 22.04+ / Debian 12+)
- Docker Engine 24+ & Docker Compose v2
- Минимум: 2 CPU, 4GB RAM, 20GB SSD
- Рекомендуется: 4 CPU, 8GB RAM, 50GB SSD

## Быстрый старт

```bash
# 1. Клонировать репозиторий
git clone https://github.com/aurora/panel.git /opt/aurora
cd /opt/aurora

# 2. Настроить окружение
cp .env.prod.example .env
nano .env   # Заполнить все "change_me" значения

# 3. Запустить
docker compose -f docker-compose.prod.yml up -d

# 4. Проверить
docker compose -f docker-compose.prod.yml ps
docker logs aurora-backend -f
```

## Пошаговая инструкция

### Шаг 1: Подготовка сервера

```bash
apt update && apt upgrade -y
apt install -y docker.io docker-compose-v2
systemctl enable --now docker

# Настройка firewall
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 22/tcp
ufw enable
```

### Шаг 2: Настройка .env

```bash
cp .env.prod.example .env
# Обязательно изменить:
# - POSTGRES_PASSWORD (случайная строка 32+ символов)
# - JWT_AUTH_SECRET (случайная строка 32+ символов)
# - JWT_API_TOKENS_SECRET (случайная строка 32+ символов)
# - PASSWORD_HMAC_SECRET (случайная строка 32+ символов)
# - METRICS_PASS (пароль для метрик)
```

### Шаг 3: Настройка домена

```bash
# В Caddyfile заменить your-domain.com на ваш домен
nano Caddyfile

# Убедиться, что DNS A-запись указывает на сервер
```

### Шаг 4: Запуск

```bash
docker compose -f docker-compose.prod.yml up -d

# Ждать запуска (может занять 1-2 минуты):
docker compose -f docker-compose.prod.yml logs -f
```

### Шаг 5: Первоначальная настройка

```bash
# Запустить миграции БД:
docker exec -it aurora-backend npx prisma migrate deploy

# Запустить seed (создать первого админа):
docker exec -it aurora-backend npx prisma db seed

# Проверить, что всё работает:
curl http://localhost:3001/health
curl https://your-domain.com/api/auth/status
```

### Шаг 6: Добавление ноды

```bash
# 1. Войти в админ-панель https://your-domain.com
# 2. Создать ноду в разделе Nodes
# 3. Развернуть AURORA Node на прокси-сервере:
docker run -d \
  --name aurora-node \
  --restart always \
  --network host \
  --cap-add NET_ADMIN \
  -e NODE_PORT=2222 \
  -e SECRET_KEY="<из панели>" \
  ghcr.io/aurora/node:2
```

## Проверка работоспособности

```bash
# Backend health
curl https://your-domain.com/health
# Ожидаемый ответ: {"status":"ok"}

# Auth status
curl https://your-domain.com/api/auth/status
# Ожидаемый ответ: {"response":{"isLoginAllowed":true,...}}

# API docs
# Открыть в браузере: https://your-domain.com/docs
```

## Мониторинг

```bash
# Prometheus метрики
curl http://localhost:3001/metrics

# Логи
docker compose -f docker-compose.prod.yml logs -f aurora-backend
docker compose -f docker-compose.prod.yml logs -f aurora-caddy

# Bull Board (очереди)
# https://your-domain.com/queues (только с internal IP)
```

## Безопасность

1. **Всегда менять пароли** в `.env` перед запуском
2. **Ограничить доступ** к `/metrics` и `/queues` по IP в Caddyfile
3. **Регулярно обновлять** образы: `docker compose pull`
4. **Резервное копирование** БД:
   ```bash
   docker exec aurora-db pg_dump -U aurora aurora > backup_$(date +%Y%m%d).sql
   ```
5. **Мониторинг логов** через `journalctl` или внешнюю систему

## Обновление

```bash
cd /opt/aurora
git pull
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
docker exec aurora-backend npx prisma migrate deploy
```

## Решение проблем

| Проблема | Решение |
|----------|---------|
| `connect ECONNREFUSED` | Проверить что контейнеры запущены: `docker ps` |
| `Cannot connect to the database` | Проверить DATABASE_URL в .env |
| `JWT_AUTH_SECRET cannot be change_me` | Изменить все "change_me" значения |
| Caddy 502 Bad Gateway | Проверить что backend запустился: `docker logs aurora-backend` |
| SSL сертификат не выпускается | Убедиться что DNS A-запись указывает на сервер |
