# InvestPortfolio — Roadmap развития

> Последнее обновление: 2026-04-04
> Текущее состояние: MVP запускается, SwiftData подключён, Tradernet интеграция базовая

---

## Текущее состояние (что есть сейчас)

| Модуль | Статус | Заметки |
|--------|--------|---------|
| Авторизация Tradernet | ✅ Работает | KeychainService, APIClient |
| Портфель (Tradernet) | ⚠️ Частично | Нет кеша, нет сервисного слоя |
| Денежные операции | ⚠️ Частично | Нет кеша, нет сервисного слоя |
| Вклады | ⚠️ Частично | In-memory, данные не сохраняются |
| SwiftData | ⚠️ Подключён | ModelContainer не инициализирован |
| Подписки | ❌ Нет | |
| Транзакции (ручные) | ❌ Нет | |
| Дашборд / Аналитика | ❌ Нет | |

---

## Архитектурные решения

- **UI**: SwiftUI
- **Паттерн**: MVVM + Repository + Service
- **Персистентность**: SwiftData (iOS 17+)
- **Сеть**: async/await, без Combine
- **Рыночные данные**: публичный API (Yahoo Finance / Alpha Vantage / MOEX) + ручной ввод при сделке
- **Транзакции**: этап 1 — ручной ввод; этап 2 — CSV/Excel; этап 3 — Tradernet API

---

## Фаза 0 — Фундамент и архитектура
> Цель: правильная база, без которой всё остальное не работает

### 0.1 Инициализация SwiftData ✅
- [x] Настроить `ModelContainer` в `InvestPortfolioApp` со всеми `@Model`
- [x] Передавать `ModelContainer` через `.modelContainer()` в `WindowGroup`
- [x] `ServiceFactory` заменён на `DIContainer` (`Service/DIContainer.swift`), передаётся через `.environmentObject()`
- [ ] Убрать `InMemoryDepositsRepository` как дефолт в `DepositsViewModel` — использовать SwiftData (задача 0.2)

### 0.2 Рефакторинг ViewModels ✅
- [x] `DepositsViewModel` — принимает `any DepositsService` через `init`, убран `InMemoryDepositsRepository`
- [x] `PortfolioViewModel` — использует `PortfolioService` (кеш SwiftData), убраны прямые вызовы `APIClient`; добавлен `refresh(sid:)` для pull-to-refresh
- [x] `CashViewModel` — использует `CashService` (кеш SwiftData), убраны прямые вызовы `APIClient`; добавлен `refresh()` для pull-to-refresh
- [x] `DepositsView`, `PortfolioView`, `CashView` — `init(container:)`, `@StateObject` создаётся с сервисом из контейнера
- [x] `MainTabView` — `@EnvironmentObject container`, передаёт в дочерние views

### 0.3 Интеграция публичного API для цен
- [ ] Выбрать и подключить API (Yahoo Finance / Alpha Vantage / MOEX для RU-акций)
- [ ] `MarketDataService` — `fetchPrice(ticker:) -> Double?`
- [ ] Кеш цен на 5 минут через SwiftData или `NSCache`
- [ ] Fallback: при отсутствии интернета — последняя известная цена

### 0.4 Навигация
- [ ] Заменить `HomeTabView` на полноценный дашборд (в рамках фазы 4)
- [ ] Обновить `MainTabView` на 5 вкладок: Дашборд / Портфель / Транзакции / Аналитика / Настройки
- [ ] Убрать отдельные вкладки для Вкладов/Кеша — перенести в соответствующие разделы

---

## Фаза 1 — Вклады и Подписки
> Цель: полнофункциональное ведение вкладов и подписок с персистентностью

### 1.1 Вклады (Deposits) — доработка ✅
- [x] Исправить модель `Deposit` — добавить `bankName: String`
- [x] Подключить `SwiftDataDepositsRepository` (убрать InMemory)
- [x] Удаление вклада свайпом
- [x] Подтверждение удаления (Alert)
- [x] Редактирование существующего вклада (лист редактирования)
- [ ] Расчёт дохода с учётом капитализации процентов (опционально)
- [x] Уведомление за 7 дней до окончания вклада (UNUserNotificationCenter)

### 1.2 Подписки (Subscriptions) — новый модуль

**Модель:**
```swift
@Model final class Subscription {
    var id: UUID
    var name: String
    var price: Double
    var currency: String
    var billingPeriod: BillingPeriod  // monthly / yearly / weekly
    var nextPaymentDate: Date
    var isActive: Bool
    var iconName: String?     // SF Symbol
    var colorHex: String?
    var createdAt: Date
}

enum BillingPeriod: String, Codable {
    case weekly, monthly, quarterly, yearly
}
```

**Что реализовать:**
- [ ] `SubscriptionsRepository` (протокол + SwiftData реализация)
- [ ] `SubscriptionsService` (CRUD + расчёт месячных/годовых расходов)
- [ ] `SubscriptionsViewModel`
- [ ] `SubscriptionsView` — список активных подписок, сумма в месяц/год
- [ ] `AddSubscriptionView` — форма добавления
- [ ] Автоматический пересчёт `nextPaymentDate` после списания
- [ ] Push-уведомление за 1 день до платежа

### 1.3 Настройки — расширение
- [ ] Выбор валют для отображения вкладов и подписок
- [ ] Управление уведомлениями (вкл/выкл по типам)
- [ ] Раздел безопасности (Face ID — фаза 5)

---

## Фаза 2 — Транзакции (ручной ввод)
> Цель: вести историю сделок и считать позиции из них

### 2.1 Новые модели

```swift
@Model final class Asset {
    var id: UUID
    var ticker: String
    var name: String
    var type: AssetType       // stock / etf / crypto / bond / other
    var currency: String
    var exchange: String?
    var lastPrice: Double?
    var lastPriceUpdatedAt: Date?
}

enum AssetType: String, Codable {
    case stock, etf, crypto, bond, other
}

@Model final class Transaction {
    var id: UUID
    var asset: Asset?
    var date: Date
    var type: TransactionType  // buy / sell
    var quantity: Double
    var price: Double
    var fee: Double
    var currency: String
    var notes: String?
}

enum TransactionType: String, Codable {
    case buy, sell
}

@Model final class Dividend {
    var id: UUID
    var asset: Asset?
    var date: Date
    var amount: Double
    var tax: Double
    var currency: String
}
```

### 2.2 Что реализовать
- [ ] `AssetRepository` + `AssetService`
- [ ] `TransactionRepository` + `TransactionService`
- [ ] `DividendRepository` + `DividendService`
- [ ] `TransactionsView` — список сделок с фильтрами (по активу, дате, типу)
- [ ] `AddTransactionView` — форма (поиск тикера → подтягивает цену из API → можно отредактировать)
- [ ] `AssetSearchView` — поиск актива по тикеру/названию через публичный API
- [ ] `AssetDetailView` — сводка по активу, история сделок, дивиденды
- [ ] Расчёт средней цены (FIFO / средняя — настройка)
- [ ] Swipe-to-delete и редактирование транзакций

### 2.3 Расчёт портфеля из транзакций
- [ ] `PortfolioCalculator` — агрегирует транзакции → список позиций с количеством, средней ценой, P&L
- [ ] Поддержка нескольких валют в позициях

---

## Фаза 3 — Портфель с рыночными данными
> Цель: актуальный портфель с реальными ценами и P&L

### 3.1 Обновление PortfolioView
- [ ] Список позиций рассчитывается из `TransactionService` (не из Tradernet)
- [ ] Текущие цены подтягиваются из `MarketDataService`
- [ ] Отображение: тикер, количество, средняя цена, текущая цена, P&L (абс. + %)
- [ ] Поддержка нескольких счетов / брокеров
- [ ] Pull-to-refresh для обновления цен

### 3.2 Синхронизация с Tradernet (опционально)
- [ ] Импорт текущих позиций из Tradernet как транзакции
- [ ] Маппинг Tradernet-позиций → `Asset` + `Transaction`

### 3.3 Дивиденды
- [ ] `DividendsView` — история дивидендов по всем активам
- [ ] Суммарный доход по дивидендам за период (месяц / год)
- [ ] Чарт: дивиденды по месяцам

---

## Фаза 4 — Дашборд и Аналитика
> Цель: красивая визуализация всего капитала

### 4.1 Дашборд (главная вкладка)
- [ ] Карточка: стоимость портфеля (с динамикой за день / неделю)
- [ ] Карточка: вложено / прибыль / доходность (%)
- [ ] Карточка: доход от дивидендов за год
- [ ] Карточка: net worth (портфель + вклады + кеш − подписки за год)
- [ ] Мини-чарт роста портфеля (Swift Charts)

### 4.2 Net Worth
- [ ] `NetWorthView` — суммарный капитал
- [ ] Разбивка: инвестиции / вклады / кеш / обязательства (подписки)
- [ ] Чарт роста net worth по месяцам (история на основе транзакций)

### 4.3 Аналитика (отдельная вкладка)
- [ ] Аллокация по типам активов (круговая диаграмма)
- [ ] Аллокация по валютам
- [ ] Аллокация по секторам / странам (если API предоставляет)
- [ ] Чарт ежемесячных инвестиций (столбчатый)
- [ ] Чарт дивидендного дохода по месяцам
- [ ] ROI общий и по активам
- [ ] XIRR (внутренняя норма доходности с учётом дат сделок)

---

## Фаза 5 — Импорт и Безопасность
> Цель: удобный онбординг и защита данных

### 5.1 Импорт CSV/Excel
- [ ] `ImportService` — парсинг CSV-отчётов брокеров
- [ ] Поддержка форматов: Tradernet, Тинькофф, ВТБ, общий формат
- [ ] Preview перед импортом — показать что будет загружено
- [ ] Дедупликация транзакций по дате + тикеру + сумме

### 5.2 Импорт из Tradernet API
- [ ] Загрузка истории сделок через `getUserOrders` / аналог
- [ ] Преобразование в `Transaction` модели
- [ ] Дедупликация с уже существующими транзакциями

### 5.3 Безопасность
- [ ] Face ID / Touch ID при открытии приложения (LocalAuthentication)
- [ ] Настройка: требовать биометрию при запуске / через N минут фоновой работы
- [ ] Шифрование чувствительных данных (токен уже в Keychain — ок)

### 5.4 Экспорт
- [ ] Экспорт в CSV — все транзакции / вклады / подписки
- [ ] Share sheet

---

## Технический долг (параллельно с фазами)

| Задача | Фаза |
|--------|------|
| Добавить unit-тесты для `DepositsService` (расчёт дохода) | 0–1 |
| Добавить unit-тесты для `PortfolioCalculator` | 2 |
| Локализовать все хардкод-строки (сейчас много RU/EN вперемешку) | 0–1 |
| Обработка ошибок сети с retry-логикой | 1–2 |
| Логирование / аналитика ошибок (OSLog) | 2 |
| Accessibility (Dynamic Type, VoiceOver labels) | 3–4 |
| iPad layout поддержка | 4–5 |

---

## Зависимости между фазами

```
Фаза 0 (Фундамент)
    └── Фаза 1 (Вклады + Подписки)
            └── Фаза 4 (Дашборд — net worth включает вклады/подписки)
    └── Фаза 2 (Транзакции)
            └── Фаза 3 (Портфель с ценами)
                    └── Фаза 4 (Дашборд + Аналитика)
                            └── Фаза 5 (Импорт)
```

---

## Открытые вопросы

- [ ] Какой конкретно публичный API для цен? Рассмотреть: Yahoo Finance (неофициальный), Alpha Vantage (бесплатный лимит 25 req/day), MOEX API (бесплатный для RU-бумаг), Finnhub (60 req/min бесплатно)
- [ ] Нужен ли iCloud/CloudKit sync между устройствами?
- [ ] Метод расчёта средней цены: FIFO или средневзвешенная?
- [ ] Нужна ли поддержка нескольких портфелей / счетов?
