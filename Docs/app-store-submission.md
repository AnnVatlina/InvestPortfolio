# App Store Submission — Полный чеклist

> Приложение уже опубликовано в App Store (версии 1.0–1.2). Этот документ описывает
> подготовку **очередного обновления — 1.3**: вкладка «Дивиденды» (импорт отчёта
> Freedom24, #38–#41), карточка «Доход и подписки» на главном экране с пересчётом в
> основную валюту по курсам, заданным вручную, и защита данных при сбое открытия базы.
> Версия 1.2 (вклады из #17–#24: капитализация, пополнение/снятие, отзывность, экран
> деталей) уже опубликована. Это не первая публикация — более ранняя версия файла была
> написана для v1.0.

## Статус на основе реальных настроек Xcode-проекта

Проверено через `GetTargetBuildSettings` — это факт, а не предположение:

| Параметр | Значение | Статус |
|---|---|---|
| `PRODUCT_BUNDLE_IDENTIFIER` | `io.rentivo.app` | ✅ настроен |
| `INFOPLIST_KEY_CFBundleDisplayName` | `Rentivo` | ✅ настроен |
| `DEVELOPMENT_TEAM` | `SVVTWN6V74` | ✅ привязан |
| `MARKETING_VERSION` | `1.3` | ✅ выставлено под этот релиз (было `1.2`), синхронизировано с виджет-расширением |
| `CURRENT_PROJECT_VERSION` (build) | `8` | ✅ выставлено под этот релиз (было `7`), одинаково на приложении и виджет-расширении |
| `IPHONEOS_DEPLOYMENT_TARGET` | `17.0` | ✅ (нужен для SwiftData) |
| Privacy Manifest (`PrivacyInfo.xcprivacy`) | — | ✅ (проверено раньше, не менялось в этом релизе) |

**Про версию/билд:** `1.3`/`8` выставлены на обоих таргетах (приложение + виджет-расширение).
Исходим из того, что `1.2` (build `7`) уже опубликована в App Store. Доступа к App Store Connect
у меня нет — **перед архивацией проверьте**, что `1.3` действительно следующий свободный
номер и что build `8` больше любого уже загруженного билда.

**Что я не могу проверить или сделать отсюда** (требует входа в Developer Portal /
App Store Connect под вашим Apple ID):
- зарегистрирован ли Bundle ID в Developer Portal (для уже опубликованного приложения — почти наверняка да)
- опубликована ли Privacy Policy по публичному URL и вписана ли в App Store Connect
- Distribution-сертификат и provisioning profile для архивации
- сама загрузка архива и отправка на ревью

---

## 1. Что нового в этой версии (для раздела "What's New")

Обновление уже опубликованного приложения — текст для "What's New" обязателен.
Черновик (подробные формулировки — в `Docs/app-store-semantics.md`):

**RU:**
```
Доход против подписок — в одном числе:
• На главном экране новая карточка: сколько в месяц приносят вклады, сколько уходит на подписки и какую часть подписок покрывает доход
• Основная валюта и курсы в Настройках → Валюты: суммы в USD, GEL, RUB и других сводятся в одну валюту. Курсы вводятся вручную; валюта без курса в итог не попадает, и приложение подскажет, какого курса не хватает

Новая вкладка «Дивиденды»:
• Импорт отчёта Freedom24 (.xlsx): дивиденды, налоги и комиссии
• Повторная загрузка того же отчёта не создаёт дублей
• Дивиденды отдельным блоком в аналитике

Надёжнее хранение: если после обновления данные не удалось открыть, приложение больше не удаляет их, а сохраняет копию и сообщает об этом
```

**EN:**
```
Income vs. subscriptions in one number:
• New card on the Home screen: how much your deposits earn per month, how much subscriptions cost, and how much of that your income covers
• Base currency and exchange rates in Settings → Currencies: amounts in USD, GEL, RUB and others are combined into one currency. Rates are entered manually; a currency without a rate is left out of the totals, and the app tells you which rate is missing

New Dividends tab:
• Import a Freedom24 report (.xlsx): dividends, taxes and commissions
• Re-importing the same report never creates duplicates
• Dividends get their own section in Analytics

Safer storage: if your data can't be opened after an update, the app no longer deletes it — it keeps a backup copy and tells you
```

---

## 2. App Store Connect — поля, которые могут понадобиться обновить

### Идентификаторы
- **Bundle ID**: `io.rentivo.app` (не меняется между версиями)
- **Version**: следующий номер после текущего live (см. предупреждение выше)
- **Build Number**: должен быть больше предыдущего загруженного для этой версии

### Описания и ключевые слова
→ Актуальный текст (с учётом вкладов) в `Docs/app-store-semantics.md`. Полное
описание там уже обновлено под капитализацию/отзывность; название, подзаголовок и
ключевые слова можно оставить прежними, если они уже работают (не требуют ревью при
обновлении отдельно от Promotional Text — но сам текст описания ревью проходит).

### URL-ссылки
Если приложение уже публиковалось — Privacy Policy URL и Support URL уже должны
быть в App Store Connect с предыдущего раза. Проверьте, что они ещё открываются
(особенно если `Docs/privacy-policy.html` размещён не на постоянном хостинге).

---

## 3. Скриншоты

В `Docs/screenshots/` уже есть 11 актуальных скриншотов приложения (сняты на
симуляторе при подготовке `Docs/user-guide.md`), покрывающих онбординг, вклады
(список/форма/детали с графиком), подписки, настройки и аналитику. **Но они сняты
на iPhone 17 и не гарантированно совпадают с требуемым размером для App Store —
перед загрузкой в App Store Connect пересними на симуляторе нужного устройства.**

### Обязательные размеры
| Устройство | Размер | Обязательно |
|------------|--------|-------------|
| iPhone 6.9" (iPhone 16/17 Pro Max) | 1320×2868 px | ✅ обязательно |
| iPhone 6.5" (iPhone 11 Pro Max) | 1242×2688 px | опционально |
| iPad Pro 13" (если поддерживается) | 2064×2752 px | если заявлен iPad |

- Минимум 1 скриншот на нужный размер, рекомендуется 5–10
- PNG/JPEG, без рамки устройства (Apple добавляет её сама), текст — на языке локали
- Если обновляете существующий листинг, можно оставить старые скриншоты и добавить
  1–2 новых, показывающих капитализацию/график вклада — необязательно менять весь набор

### Рекомендуемые новые кадры (из текущего релиза)
1. `deposits_list.png` — список с бейджами капитализации/отзывности
2. `deposit_detail.png` — график роста и история операций
3. `deposit_form_2.png` — форма с раскрытыми секциями (капитализация, пополнение, отзывность)

---

## 4. Видео-превью (App Preview) — опционально, не менялось

- Длительность: 15–30 секунд, реальный UI, без рекламных вставок
- Форматы: H.264 или HEVC

---

## 5. Privacy — без изменений в этом релизе

Функциональность вкладов (#17–#24) не добавляет новых прав доступа, сетевых вызовов
или сбора данных — приложение остаётся полностью локальным. Разделы ниже не должны
требовать правок в App Store Connect, но стоит перепроверить перед отправкой, что
ответы там всё ещё соответствуют коду.

### PrivacyInfo.xcprivacy — ожидаемое состояние
```xml
NSPrivacyTracking: false
NSPrivacyCollectedDataTypes: [] (пусто — данные не собираются)
NSPrivacyAccessedAPITypes:
  - NSPrivacyAccessedAPICategoryUserDefaults → CA92.1
  - NSPrivacyAccessedAPICategoryFileTimestamp → C617.1
```

### App Privacy "Nutrition Label"
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

> "Data Linked to You" и "Data Used to Track You" — **No** для всего.
> Приложение полностью локальное — нет сети, нет сторонних API, данные никуда не передаются.

---

## 6. Возрастной рейтинг — без изменений

Функциональность вкладов не меняет ответы анкеты. Итоговый рейтинг: **4+**.

---

## 7. Технические требования сборки

### Подписание (Signing)
- **Team**: уже привязан (`SVVTWN6V74`) — проверьте, что выбран правильный аккаунт при архивации
- **Provisioning Profile**: App Store Distribution
- **Certificate**: Apple Distribution (не Development — сборка выше снята с `SDKROOT=iphonesimulator`/Debug, для архива нужна Release-конфигурация с дистрибутивным сертификатом)

### Сборка для отправки
1. В Xcode: **Product → Archive** (на Release-конфигурации, устройство "Any iOS Device")
2. **Window → Organizer → Distribute App → App Store Connect → Upload**
3. После загрузки — статус в App Store Connect → TestFlight, затем "Submit for Review"

### Минимальный Deployment Target
**iOS 17** (нужен для SwiftData) — не менялось.

---

## 8. Дополнительные поля App Store Connect

| Поле | Значение |
|------|-----------|
| What's New | текст из §1 выше |
| Promotional Text | можно менять без ревью — см. `Docs/app-store-semantics.md` |
| Copyright | `© 2026 Anna Vatlina` |
| Developer name | Anna Vatlina |
| Email для Apple Review | рабочий адрес |

### App Review Notes (если ревьюер попросит обойти онбординг)
```
No login required to use the app.
Tap "Start Fresh" on onboarding to access Deposits, Subscriptions and Analytics.
All core features are available without authentication.
```

---

## 9. Чеклист перед отправкой этого обновления

- [x] `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` выставлены на `1.2`/`7` (приложение + виджет-расширение)
- [ ] В App Store Connect проверено, что `1.2`/`7` действительно свободны (не конфликтуют с уже загруженным билдом)
- [ ] Текст "What's New" на RU и EN вписан (см. §1)
- [ ] Описание в App Store Connect обновлено под капитализацию/отзывность (текст готов в `Docs/app-store-semantics.md`)
- [ ] Privacy Policy URL и Support URL из предыдущей публикации всё ещё доступны
- [ ] 1–2 новых скриншота добавлены (пересняты в правильном размере устройства, не напрямую из `Docs/screenshots/`)
- [ ] App Privacy Nutrition Label — без изменений, но перепроверена
- [ ] Возрастной рейтинг — без изменений (4+)
- [ ] Archive собран через Product → Archive с Release-конфигурацией и Distribution-сертификатом
- [ ] Загружен через Organizer → Distribute App → App Store Connect
