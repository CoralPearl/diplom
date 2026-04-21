# ModeLink Backend (Express + PostgreSQL + Prisma)

## Быстрый старт

### Вариант A — с Docker (PostgreSQL)

1) Поднять Postgres:

```bash
docker compose up -d
```

2) Установить зависимости:

```bash
npm i
```

3) Создать файл `.env` по примеру `.env.example`.

> Если используешь `docker-compose.yml` из репозитория, то `DATABASE_URL` по умолчанию подходит:
> `postgresql://postgres:postgres@localhost:5432/modelink?schema=public`

4) Применить миграции:

```bash
npm run prisma:migrate
```

5) Запустить сервер:

```bash
npm run dev
```

### Вариант B — без Docker

1) Установить зависимости:

```bash
npm i
```

2) Создать файл `.env` по примеру `.env.example`.

3) Поднять PostgreSQL и создать базу `modelink` (или свою).

4) Применить миграции:

```bash
npm run prisma:migrate
```

5) Запустить сервер:

```bash
npm run dev
```

## Основные эндпоинты

- `POST /auth/otp/request` — запрос OTP на email
- `POST /auth/otp/verify` — подтверждение OTP + создание пользователя
- `POST /auth/login` — логин по email+пароль (JWT)
- `GET /auth/me` — получить текущего пользователя

- `POST /projects` / `GET /projects` / `PUT /projects/:id` / `DELETE /projects/:id`
- `POST /portfolio` / `GET /portfolio` / `DELETE /portfolio/:id`

- `GET /models` — список моделей (q/page/limit/sortBy/order)
- `GET /models/:id` — карточка модели (profile + projects + portfolio)

- `GET /admin/users` — список пользователей (admin)
- `PATCH /admin/users/:id` — смена роли / блокировка (admin)

## Документация API (Swagger)

- Swagger UI: `GET /docs`
- OpenAPI JSON: `GET /openapi.json`

## Postman

В папке `postman/` лежит:

- `ModeLink.postman_collection.json`
- `ModeLink.postman_environment.json`

Импортируй оба файла в Postman, выбери environment **ModeLink Local**, затем:

1) `POST /auth/otp/request` (код придёт на email, либо выведется в консоль сервера в режиме dev)
2) `POST /auth/otp/verify` (в ответе тест-скрипт сохранит `token` в environment)
3) `GET /auth/me` (тест-скрипт сохранит `modelId` если роль model)

После этого можно вызывать `Projects` и `Portfolio`.

## Файлы

По умолчанию (без S3) изображения сохраняются локально в папку `/uploads` и доступны по URL:

`GET {APP_BASE_URL}/uploads/<filename>`

Если настроен S3 (env переменные), backend загружает файл в бакет и сохраняет публичный URL.

## Примечание по безопасности

Саморегистрация роли `admin` отключена по умолчанию.

Создать админа локально можно скриптом:

```bash
npm run create:admin -- admin@example.com Passw0rd!
```

Включить можно:

- `ALLOW_ADMIN_REGISTRATION=true` (не рекомендуется для продакшена), или
- установить `ADMIN_REGISTRATION_SECRET` и передавать `adminRegistrationSecret` в запросе `/auth/otp/verify`.

