# App Store Submission — Полный чеклист

## Статус готовности к модерации

| Блок | Статус |
|------|--------|
| Privacy Manifest (PrivacyInfo.xcprivacy) | ✅ |
| Privacy Policy | ✅ |
| HTTPS для всех запросов | ✅ |
| Данные в Keychain | ✅ |
| Debug-логирование убрано из APIClient.swift | ✅ |
| Bundle ID зарегистрирован в Developer Portal | ⏳ сделать |
| Privacy Policy опубликована по URL | ⏳ сделать |
| Display name в Xcode изменён на Rentivo | ⏳ сделать |

---

## 1. App Store Connect — обязательные поля

### Идентификаторы
- **Bundle ID**: `io.rentivo.app`
- **Version**: `1.0.0`
- **Build Number**: `1`
- **SKU**: уникальный внутренний идентификатор, например `rentivo-ios-1`
- **Apple ID**: назначается автоматически при создании приложения

### Основная информация
- **Название**: `Rentivo: Личные финансы` (RU) / `Rentivo: Finance Tracker` (EN) — до 30 символов
- **Подзаголовок**: `Вклады, подписки, портфель` / `Deposits, Subs & Portfolio` — до 30 символов
- **Категория**: Finance
- **Дополнительная категория**: Productivity
- **Возрастной рейтинг**: 4+

### Ключевые слова (100 символов)
```
RU: вклады,подписки,финансы,бюджет,трекер,банк,расходы,доходы,портфель,инвестиции,депозит,расчёт
EN: deposits,subscriptions,budget,finance,tracker,expenses,income,portfolio,investment,bank,savings
```

### Описания
→ Полные тексты в `Docs/app-store-semantics.md`

### URL-ссылки
- **Privacy Policy URL** — обязательно: нужен публичный URL, например:
  `https://rentivo.io/privacy` или GitHub Pages с `Docs/privacy-policy.html`
- **Support URL** — обязательно: сайт или форма поддержки
- **Marketing URL** — опционально

---

## 2. Скриншоты — требования Apple

Скриншоты обязательны для каждого поддерживаемого типа устройств.

### Обязательные размеры (2025)
| Устройство | Размер | Обязательно |
|------------|--------|-------------|
| iPhone 6.9" (iPhone 16 Pro Max) | 1320×2868 px | ✅ Обязательно |
| iPhone 6.5" (iPhone 11 Pro Max) | 1242×2688 px | опционально |
| iPad Pro 13" (если поддерживается) | 2064×2752 px | если iPad |

- Минимум **1 скриншот**, рекомендуется **5–10**
- Форматы: PNG или JPEG, без закруглённых углов, без рамки устройства (Apple сама накладывает)
- Текст на скриншотах должен совпадать с языком локали

### Рекомендуемые кадры для скриншотов
1. **Главный экран** — Home с карточками вкладов и подписок
2. **Вклады** — список с накопленным доходом и прогрессом
3. **Подписки** — список с ближайшими платежами
4. **Аналитика** — график доходов vs. расходов
5. **Добавление вклада** — форма (демонстрирует простоту)

---

## 3. Видео-превью (App Preview) — опционально

- Длительность: 15–30 секунд
- Должно показывать реальный UI, снятый на устройстве или симуляторе
- Не рекламный ролик — только демонстрация функционала
- Форматы: H.264 или HEVC

---

## 4. Конфигурация версии

### Info.plist — обязательные ключи
На iOS `NSUserNotificationsUsageDescription` не требуется — локальные уведомления через `UNUserNotificationCenter` работают без ключа в Info.plist.

### Capabilities (Xcode → Signing & Capabilities)
- **Push Notifications** — нужен entitlement, если используются локальные уведомления через UNUserNotification (локальные не требуют сертификата, но entitlement нужен для remote в будущем)
- **iCloud / CloudKit** — если планируется синхронизация (сейчас не используется → не нужен)
- **Keychain Sharing** — не нужен (используется базовый Keychain без групп)

---

## 5. Privacy — требования для модерации

### PrivacyInfo.xcprivacy — текущее состояние (OK)
```xml
NSPrivacyTracking: false
NSPrivacyCollectedDataTypes: [] (пусто — данные не собираются)
NSPrivacyAccessedAPITypes:
  - NSPrivacyAccessedAPICategoryUserDefaults → CA92.1
  - NSPrivacyAccessedAPICategoryFileTimestamp → C617.1
```

### Privacy Policy URL
Политика конфиденциальности в `Docs/privacy-policy.html` готова.
**Нужно**: опубликовать по публичному URL и вписать его в App Store Connect.

Варианты хостинга:
- GitHub Pages (бесплатно)
- Netlify / Vercel (бесплатно)
- Собственный домен `rentivo.io`

### App Privacy "Nutrition Label" (App Store Connect)
Отвечаем на вопросы в разделе "App Privacy":

| Категория данных | Собирается? | Ответ |
|------------------|-------------|-------|
| Contact Info | Нет | No |
| Health & Fitness | Нет | No |
| Financial Info | **Локально** — да, но не передаётся | No (stored on device only) |
| Location | Нет | No |
| Identifiers | Нет | No |
| Usage Data | Нет | No |
| Diagnostics | Нет | No |
| Third-Party Advertising | Нет | No |

> Ответ на "Data Linked to You" и "Data Used to Track You" — **No** для всего.
> Tradernet API — опциональная фича, данные передаются пользователем напрямую в Tradernet.

---

## 6. Возрастной рейтинг — анкета Apple

| Вопрос | Ответ |
|--------|-------|
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Sexual Content | None |
| Nudity | None |
| Profanity or Crude Humor | None |
| Mature/Suggestive Themes | None |
| Horror/Fear Themes | None |
| Medical/Treatment Information | None |
| Alcohol, Tobacco, Drugs | None |
| Gambling | None |
| Contests | None |
| **Unrestricted Web Access** | **No** |
| **User Generated Content** | **No** |

**Итоговый рейтинг: 4+**

---

## 7. Что нужно сделать до публикации

### КРИТИЧНО

#### 7.1 Зарегистрировать Bundle ID в Developer Portal
`io.rentivo.app` должен быть создан в Certificates, Identifiers & Profiles.
Без этого архив не загрузится в App Store Connect.

#### 7.2 Опубликовать Privacy Policy по публичному URL
Файл `Docs/privacy-policy.html` готов — нужно разместить на хостинге.
Варианты: GitHub Pages, Netlify, Vercel (все бесплатно).

#### 7.3 Поменять Display Name в Xcode
`Build Settings → INFOPLIST_KEY_CFBundleDisplayName` → `Rentivo`

#### 7.4 Поменять Bundle ID в Xcode
`Build Settings → PRODUCT_BUNDLE_IDENTIFIER` → `io.rentivo.app`

### ВАЖНО

#### 7.5 Убедиться что email поддержки рабочий
`privacy@rentivo.io` в политике конфиденциальности должен принимать письма.
Support URL в App Store Connect тоже должен быть доступен.

### РЕКОМЕНДУЕТСЯ

#### 7.6 App Review Notes
При отправке указать ревьюеру:
```
No login required to use the app.
Tap "Start Fresh" on onboarding to access Deposits, Subscriptions and Analytics.
All core features are available without authentication.
```

---

## 8. Технические требования сборки

### Подписание (Signing)
- **Team**: выбрать Apple Developer аккаунт
- **Provisioning Profile**: App Store Distribution
- **Certificate**: Apple Distribution (не Development)

### Сборка для отправки
1. В Xcode: Product → Archive
2. Distribute App → App Store Connect → Upload
3. После загрузки: проверить статус в App Store Connect → TestFlight или сразу на ревью

### Минимальный Deployment Target
Текущий: **iOS 17** (требуется SwiftData).
iOS 17 охват ~85% устройств (2025) — приемлемо.

---

## 9. Дополнительные материалы для App Store Connect

| Поле | Заполнить |
|------|-----------|
| What's New (для обновлений) | не нужно для v1.0 |
| Promotional Text | можно менять без ревью |
| Copyright | `© 2026 Anna Vatlina` |
| Developer name | Anna Vatlina |
| Email для Apple Review | рабочий адрес |

---

## 10. Чеклист перед отправкой

- [ ] `INFOPLIST_KEY_CFBundleDisplayName` → `Rentivo` в Xcode Build Settings
- [ ] `PRODUCT_BUNDLE_IDENTIFIER` → `io.rentivo.app` в Xcode Build Settings
- [ ] Bundle ID `io.rentivo.app` зарегистрирован в Developer Portal
- [ ] Distribution сертификат и provisioning profile созданы
- [ ] Privacy Policy опубликована по публичному URL
- [ ] URL политики вписан в App Store Connect
- [ ] Support URL вписан в App Store Connect
- [ ] App Privacy Nutrition Label заполнена (все поля — No)
- [ ] Скриншоты загружены (минимум 1 для iPhone 6.9")
- [ ] Описание и ключевые слова вписаны на всех поддерживаемых языках
- [ ] App Review Notes написаны
- [ ] Возрастной рейтинг выставлен (4+)
- [ ] Copyright поле заполнено (`© 2026 Anna Vatlina`)
- [ ] Архив собран через Product → Archive с Release конфигурацией
