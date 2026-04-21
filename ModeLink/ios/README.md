# ModeLink iOS (актуально)

Это **drop‑in набор SwiftUI файлов** (MVVM), который добавляется в твой Xcode‑проект.

Реализовано:
- Auth (OTP register + login), JWT в Keychain
- Routing по ролям: model / booker / manager / admin
- Model: Profile + Projects + Portfolio (upload progress)
- Disk+Memory cache изображений (LRU по размеру)
- Retry/offline UX + offline queue (Profile PUT, Project POST)
- **Idempotency-Key** на POST (нет дублей при повторе)
- **Booker/Manager**: список моделей с **поиском + сортировкой + пагинацией**
- **Admin**: вкладка **Пользователи** (список, смена роли, блокировка)

Требования:
- iOS 16+
- Swift Concurrency (async/await)

Подключение:
1) Создай Xcode проект (SwiftUI, iOS 16).
2) Перетащи папку `Sources` в проект (Copy items if needed).
3) Настрой `baseURL` в `Sources/ModeLinkCore/API/APIClient.swift`.
