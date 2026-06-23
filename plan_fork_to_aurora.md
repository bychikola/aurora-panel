# AURORA REVERSE ENGINEERING PROTOCOL

## MISSION

Проект AURORA создается на основе анализа существующего проекта Remnawave.

Запрещено вносить любые изменения в код до полного завершения исследования архитектуры.

Цель первого этапа НЕ разработка.

Цель первого этапа — получить полное понимание системы.

Ты выступаешь как:

* Principal Software Architect
* Security Engineer
* DevOps Engineer
* Reverse Engineer

Твоя первая задача:

Понять систему лучше, чем ее первоначальные разработчики.

---

# CRITICAL RULE

ДО ЗАВЕРШЕНИЯ АУДИТА ЗАПРЕЩЕНО:

* менять код
* удалять код
* рефакторить код
* менять базу данных
* менять API
* менять UI

Разрешено только:

* анализировать
* документировать
* строить карты зависимостей
* искать узкие места

---

# STAGE 0

PROJECT FORENSICS

Полностью исследовать репозиторий. https://github.com/remnawave/panel and https://github.com/remnawave

Построить дерево проекта.

Сформировать:

REPOSITORY_MAP.md

Для каждого каталога определить:

* назначение
* уровень критичности
* зависимости
* точки входа

---

# STAGE 1

ARCHITECTURE RECONSTRUCTION

Построить архитектуру системы.

Определить:

## Frontend

* Framework
* Routing
* Layout System
* Components
* State Managers
* API Layer

## Backend

* Modules
* Services
* Controllers
* Repositories
* DTO
* Middleware
* Guards

## Infrastructure

* Docker
* Redis
* PostgreSQL
* Message Brokers

Создать:

ARCHITECTURE_RECONSTRUCTION.md

---

# STAGE 2

DEPENDENCY INTELLIGENCE

Провести полный анализ зависимостей.

Для каждого модуля определить:

Что использует.

Кто использует его.

Какие риски создаст изменение.

Создать:

DEPENDENCY_GRAPH.md

---

# STAGE 3

DATABASE INTELLIGENCE

Построить полную карту БД.

Определить:

* все таблицы
* все связи
* все индексы
* все ограничения

Построить ER Diagram.

Создать:

DATABASE_FORENSICS.md

---

# STAGE 4

API INTELLIGENCE

Обнаружить все API.

Для каждого endpoint определить:

* URL
* метод
* авторизацию
* DTO
* возвращаемые данные

Создать:

API_CATALOG.md

---

# STAGE 5

AUTHENTICATION FORENSICS

Полностью исследовать:

* JWT
* Session
* Refresh Tokens
* Roles
* Permissions

Определить возможные уязвимости.

Создать:

AUTH_SYSTEM_REPORT.md

---

# STAGE 6

XRAY REVERSE ENGINEERING

Исследовать весь код взаимодействия с Xray.

Определить:

* генерацию конфигов
* генерацию UUID
* учет трафика
* создание клиентов
* обновление клиентов
* работу inbound
* работу outbound

Создать:

XRAY_INTERNALS.md

---

# STAGE 7

NODE SYSTEM ANALYSIS

Исследовать:

* работу агентов
* регистрацию серверов
* синхронизацию
* heartbeat
* передачу статистики

Создать:

NODE_OPERATIONS_REPORT.md

---

# STAGE 8

SECURITY AUDIT

Провести аудит безопасности.

Проверить:

* SQL Injection
* XSS
* CSRF
* SSRF
* RCE
* Privilege Escalation

Сформировать:

SECURITY_AUDIT.md

Для каждой проблемы указать:

* риск
* критичность
* способ исправления

---

# STAGE 9

PERFORMANCE AUDIT

Исследовать:

* тяжелые запросы
* циклические зависимости
* лишние рендеры
* проблемы масштабирования

Создать:

PERFORMANCE_REPORT.md

---

# STAGE 10

TECHNICAL DEBT AUDIT

Определить:

* legacy code
* dead code
* unused files
* duplicated logic

Создать:

TECH_DEBT_REPORT.md

---

# STAGE 11

AURORA MIGRATION STRATEGY

После полного анализа подготовить план миграции.

Разделить систему на:

## KEEP

Оставить без изменений.

## REFACTOR

Переделать.

## REWRITE

Полностью переписать.

Создать:

AURORA_MIGRATION_PLAN.md

---

# STAGE 12

AURORA BRAND TRANSFORMATION

После завершения анализа:

Удалить бренд Remnawave.

Заменить на:

AURORA

Тематика:

Военно-морская.

Основа:

Крейсер Аврора.

Стиль:

Premium Dark.

Цветовая схема:

Background:
#090909

Surface:
#131313

Border:
#252525

Primary:
#FF7A00

Primary Hover:
#FF8F1F

Text:
#F2F2F2

Muted:
#A0A0A0

---

# STAGE 13

AURORA NEXT GENERATION FEATURES

После завершения миграции подготовить архитектуру:

* Multi Master Cluster
* Geo Routing
* Smart Load Balancer
* White Label
* Telegram Ecosystem
* Billing Core
* Reseller Platform
* Sing-box Support
* API Marketplace
* High Availability Mode

---

# FINAL OBJECTIVE

После завершения всех этапов должно существовать:

1. Полное понимание Remnawave.
2. Полная карта архитектуры.
3. Полная карта БД.
4. Полная карта API.
5. Полный аудит безопасности.
6. План миграции.
7. План масштабирования.

Только после этого разрешается писать код AURORA.

Правило:

UNDERSTAND.
DOCUMENT.
PLAN.
THEN BUILD.
NEVER BUILD BLIND.
