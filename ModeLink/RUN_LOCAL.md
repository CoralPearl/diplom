# ModeLink — запуск локально (Backend + iOS)

## Требования
- **Node.js 18+** и **npm**
- **Docker Desktop** (рекомендуется) — для PostgreSQL  
  *(или установленный PostgreSQL вручную)*
- **Xcode 15+**, iOS **16+** (для `PhotosPicker`)
- (опционально) Postman

---

## 1) Backend (Express + PostgreSQL + Prisma)

### 1.1 Запуск PostgreSQL (через Docker)
```bash
cd backend
docker compose up -d
```

### 1.2 Настройка переменных окружения
```bash
cd backend
cp .env.example .env
```

Если запускаешь Postgres через `docker compose`, строка `DATABASE_URL` в `.env` уже подходит.

> Для iPhone (не симулятора) позже нужно будет изменить `APP_BASE_URL` на IP твоего компьютера.

### 1.3 Установка зависимостей и миграции
```bash
cd backend
npm i
npm run prisma:migrate
```

### 1.4 Запуск сервера
```bash
cd backend
npm run dev
```

Проверка:
- `http://localhost:3000/health`
- `http://localhost:3000/docs` (Swagger UI)

### 1.5 OTP (Email коды)
Если SendGrid **не** настроен, backend печатает OTP в консоль:
```
[DEV] OTP for test@example.com: 123456
```

---

## 2) iOS (SwiftUI + MVVM)

> Папка `ios/` — это набор файлов `Sources/…`, который добавляется в Xcode-проект.

### 2.1 Создать проект в Xcode
1) Xcode → **File → New → Project…**
2) iOS → **App**
3) Interface: **SwiftUI**
4) Minimum iOS: **16.0**

### 2.2 Добавить исходники ModeLink
1) В Finder открой папку `ios/Sources`
2) Перетащи папку **Sources** в Xcode (в Project Navigator слева)
3) В диалоге включи **Copy items if needed**

### 2.3 Настроить baseURL API
Открой файл:
`Sources/ModeLinkCore/API/APIClient.swift`

- Для **симулятора**:
  - `http://localhost:3000`
- Для **физического iPhone**:
  - `http://<IP_твоего_компьютера>:3000`

### 2.4 Включить HTTP для разработки (ATS)
Если backend работает по `http://...`, добавь в `Info.plist` проекта:

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
```

### 2.5 Важно для iPhone: APP_BASE_URL
Если запускаешь приложение на **физическом устройстве**, в `backend/.env` поставь:

```
APP_BASE_URL=http://<IP_твоего_компьютера>:3000
```

Перезапусти backend после изменения `.env`.

Иначе ссылки на фото будут вида `http://localhost:3000/uploads/...` и на iPhone не откроются.

---

## 3) Быстрый Smoke‑тест (5–10 минут)

### 3.1 Model (профиль/проекты/портфолио + оффлайн очередь)
1) В приложении: **Register**
2) Введи email → запроси OTP
3) Возьми OTP из консоли backend (`[DEV] OTP for ...`)
4) Подтверди OTP, задай пароль, выбери роль **model**
5) Логин → откроется Dashboard
6) **Profile**: заполни поля → **Save** (inline ошибки, если неверно)
7) **Projects**: создай проект
8) **Portfolio**: загрузить фото → увидишь **progress**
9) Отключи интернет → появится баннер **«Нет подключения»**
10) Пока оффлайн:
   - в **Profile** нажми Save → изменения сохранятся **в очередь**
   - в **Projects** создай проект → он появится в секции **«Ожидает синхронизации»**
11) Включи интернет → очередь отправится автоматически (без дублей благодаря **Idempotency‑Key**)

### 3.2 Booker/Manager (список моделей: поиск/сортировка/пагинация)
1) Зарегистрируй пользователя с ролью **booker** или **manager**
2) Логин → откроется список моделей
3) Проверь:
   - поиск (строка поиска)
   - сортировка (иконка стрелок)
   - пагинация (доскролль до конца списка → догрузка)

### 3.3 Admin (мини‑админка пользователей)
1) Создай админа (в терминале):
```bash
cd backend
npm run create:admin -- admin@example.com Passw0rd!
```
2) Логин в iOS под **admin** → вкладки **Модели / Пользователи**
3) Во вкладке **Пользователи**:
   - открой пользователя → поменяй роль
   - заблокируй/разблокируй
   - заблокированный пользователь не сможет логиниться (403 `AccountBlocked`)

---

## 4) Частые проблемы (кратко)

- **iPhone не видит backend**: нельзя `localhost`. Используй IP компьютера и одну Wi‑Fi сеть.
- **Фото не открываются на iPhone**: проверь `APP_BASE_URL` в backend `.env`, перезапусти сервер.
- **Prisma migrate падает**: проверь, что Postgres поднят (`docker compose ps`) и `DATABASE_URL` корректный.
- **HTTP блокируется iOS**: добавь ATS-параметр в `Info.plist` (см. выше).

---

## Где смотреть API
- Swagger: `GET http://localhost:3000/docs`
- OpenAPI JSON: `GET http://localhost:3000/openapi.json`
- Postman коллекция: `backend/postman/`
