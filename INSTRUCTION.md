# Инструкция по развёртыванию AURORA Panel

## 1. Подготовка сервера

**Требования:** Linux (Ubuntu 22.04+/Debian 12+), 2 CPU, 4GB RAM, 20GB SSD

```bash
# Подключиться к серверу по SSH
ssh root@ваш-сервер

# Обновить систему
apt update && apt upgrade -y

# Установить Docker
apt install -y docker.io docker-compose-v2
systemctl enable --now docker

# Открыть порты
ufw allow 22/tcp       # SSH
ufw allow 80/tcp       # HTTP
ufw allow 443/tcp      # HTTPS
ufw --force enable
```

---

## 2. Клонировать репозиторий

```bash
cd /opt
git clone https://github.com/bychikola/aurora-panel.git
cd aurora-panel
```

---

## 3. Настроить .env

```bash
cp .env.example .env
nano .env
```

**Обязательно изменить следующие значения** (сгенерировать случайные строки):

| Параметр | Что вписать | Пример |
|----------|------------|--------|
| `POSTGRES_PASSWORD` | Сложный пароль 32+ символа | `m9Kx2pR7vL4nQ8wJ3bH6fD1cG5tY0eA` |
| `JWT_AUTH_SECRET` | Случайная строка 32+ символа | `zX8kP4mR2vL9nQ5wJ3bH7fD1cG6tY0eA` |
| `JWT_API_TOKENS_SECRET` | Другая случайная строка | `hY5nB3vC7xZ9kL1pQ4wM8rT2jF6dG0eR` |
| `PASSWORD_HMAC_SECRET` | Ещё одна случайная строка | `qW2eR4tY6uI8oP0aSdF5gH7jK9lZ1xCv` |
| `METRICS_PASS` | Пароль для метрик | `m3tr1c5_p4ss` |

**Если есть домен — изменить:**
```
FRONT_END_DOMAIN=https://ваш-домен.ru
PANEL_DOMAIN=https://ваш-домен.ru
SUB_PUBLIC_DOMAIN=https://ваш-домен.ru
```

**Если НЕТ домена — можно запустить на IP** (HTTP, без HTTPS):
```
FRONT_END_DOMAIN=http://IP-адрес:3000
PANEL_DOMAIN=http://IP-адрес:3000
SUB_PUBLIC_DOMAIN=http://IP-адрес:3000
```

---

## 4. Запустить панель

```bash
docker compose up -d
```

Подождать 1-2 минуты, проверить:

```bash
# Все контейнеры запущены?
docker compose ps

# Смотреть логи
docker compose logs aurora-panel -f
```

**Ожидаемый вывод:**
```
aurora-db        healthy
aurora-redis     healthy
aurora-panel     running
```

---

## 5. Настроить домен (если есть)

**Перед запуском:** в DNS-панели вашего домена создать A-запись:
```
ваш-домен.ru → IP-адрес сервера
```

В файле `Caddyfile` заменить `your-domain.com` на ваш домен:

```bash
nano Caddyfile
```

Перезапустить Caddy (если он есть в docker-compose) или создать отдельный reverse proxy.

**Без Caddy:** панель будет доступна по адресу `http://IP-адрес:3000` (HTTP, без HTTPS).

---

## 6. Создать первого админа

```bash
# Запустить миграции БД
docker exec aurora-panel npx prisma migrate deploy

# Запустить seed (создаст первого админа)
docker exec aurora-panel npx prisma db seed
```

После seed'а — перейти по адресу панели и залогиниться.

---

## 7. Добавить Node-агента

После входа в панель:

1. **Nodes → Create Node** — создать ноду (IP прокси-сервера, порт)
2. Скопировать `SECRET_KEY` из окна создания ноды
3. На **прокси-сервере** выполнить:

```bash
docker run -d \
  --name aurora-node \
  --restart always \
  --network host \
  --cap-add NET_ADMIN \
  -e NODE_PORT=2222 \
  -e SECRET_KEY="СЮДА_СКОПИРОВАТЬ_КЛЮЧ_ИЗ_ПАНЕЛИ" \
  -e XTLS_API_PORT=61000 \
  ghcr.io/aurora/node:2
```

---

## Проверка работоспособности

```bash
# Health check
curl http://localhost:3001/health
# → {"status":"ok"}

# Проверить API
curl http://localhost:3000/api/auth/status
# → {"response":{"isLoginAllowed":true,...}}
```

---

## Команды для управления

```bash
# Остановить панель
docker compose down

# Обновить панель
git pull
docker compose pull
docker compose up -d
docker exec aurora-panel npx prisma migrate deploy

# Посмотреть логи
docker compose logs -f aurora-panel

# Резервное копирование БД
docker exec aurora-db pg_dump -U aurora aurora > backup_$(date +%Y%m%d).sql
```
