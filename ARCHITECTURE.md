# InvestPortfolio — Архитектура

> Версия: 2.0 | 2026-09-30
> Стек: SwiftUI + SwiftData + async/await (Swift Testing для тестов)
> **Важно:** приложение полностью локальное — нет сети, нет backend, нет авторизации.
> Более ранняя версия этого документа описывала план с Tradernet/Spring Boot proxy/портфелем
> акций — от этого плана отказались до того, как появился текущий код; см. историю коммитов
> `cleanup/remove-networking` и `cleanup/remove-broker-api`. Всё нижеописанное соответствует
> реальному коду в репозитории на дату версии документа.

---

## 1. Что делает приложение

Личные финансы: учёт банковских **вкладов** (`Deposit`), регулярных **подписок**
(`Subscription`) и **аналитика** доходов/расходов по ним. Есть два домашних виджета
(iOS Home Screen) и CSV-экспорт/импорт для бэкапа/переноса данных. Никакой синхронизации
между устройствами нет — данные живут в SwiftData-хранилище на устройстве (плюс App Group
для доступа из виджетов).

---

## 2. Слои

```
┌─────────────────────────────────────────────────────────────┐
│                        SwiftUI Views                        │
│   DepositsView, SubscriptionsView, AnalyticsView, HomeTabView│
└───────────────────────────┬───────────────────────────────---┘
                            │  @StateObject / @EnvironmentObject
┌───────────────────────────▼─────────────────────────────────┐
│                        ViewModels                           │
│   @MainActor, ObservableObject — состояние экрана,          │
│   валидация форм, вызовы сервисов                           │
└───────────────────────────┬───────────────────────────────---┘
                            │  протоколы сервисов
┌───────────────────────────▼─────────────────────────────────┐
│                          Services                           │
│   DepositsService, SubscriptionsService — бизнес-логика,    │
│   расчёты (проценты по вкладам, даты платежей подписок)     │
└───────────────────────────┬───────────────────────────────---┘
                            │  протоколы репозиториев
┌───────────────────────────▼─────────────────────────────────┐
│                        Repositories                         │
│   DepositsRepository, SubscriptionsRepository — протоколы;  │
│   SwiftData (prod) / InMemory (тесты, previews)             │
└───────────────────────────┬───────────────────────────────---┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                          SwiftData                           │
│   ModelContainer в App Group (общий с виджетами)             │
└───────────────────────────────────────────────────────────---┘
```

**Ключевые принципы (соблюдаются в реальном коде):**
- ViewModel не знают про SwiftData — только про протоколы сервисов (`any DepositsService` и т.д.)
- Сервисы не знают про SwiftData напрямую — только про протоколы репозиториев
- Каждый репозиторий существует в двух реализациях: `SwiftData*Repository` (production,
  `@ModelActor`) и `InMemory*Repository` (тесты/превью)
- Единственное место, которое знает про конкретные реализации — `DIContainer`

---

## 3. Модели данных (SwiftData)

| Модель | Файл(ы) | Назначение |
|---|---|---|
| `Deposit` | `Model/Deposit.swift` | Банковский вклад |
| `DepositInterestType` | `Model/DepositInterestType.swift` | `.simple` / `.capitalized` |
| `CapitalizationPeriod` | `Model/CapitalizationPeriod.swift` | `.monthly` / `.quarterly` / `.yearly` |
| `DepositTransaction` | `Model/DepositTransaction.swift` | Пополнение/снятие по вкладу (знаковая сумма) |
| `Subscription` | `Model/AppSchema.swift` (хранимые свойства + `@Model`), `Model/Subscription.swift` (бизнес-логика: `nextPaymentDate`, `advance`) | Регулярная/разовая подписка |
| `SubscriptionBillingCycle` | `Model/SubscriptionBillingCycle.swift` | `.weekly/.monthly/.quarterly/.yearly/.oneTime` |
| `DepositCurrency` | `Model/DepositCurrency.swift` | Общий enum валюты для вкладов и подписок |
| `Settings` | `Model/Settings.swift` | Выбранные валюты, локаль, дата последней синхронизации (поле есть, но не используется — sync отсутствует) |

> `AppSchema.swift` — не про версионирование схемы, это просто файл, где живёт сам
> `@Model final class Subscription` со всеми `@Model`-полями. Комментарий в файле
> напоминает: если меняешь хранимые свойства — подумай про lightweight-миграцию
> (задавай default-значения прямо в объявлении, как уже сделано для `Deposit`).

### `Deposit` — актуальный набор полей

```swift
@Model
final class Deposit {
    var id: UUID
    var title: String
    var bankName: String?
    var amount: Double
    var currencyRaw: String            // typed-доступ через `currency`
    var createdAt: Date
    var openDate: Date
    var closeDate: Date?               // плановая дата закрытия
    var annualInterestRate: Double

    // Добавлено при расширении функциональности вкладов (см. §9) — у всех новых
    // хранимых полей есть значения по умолчанию в объявлении, чтобы SwiftData сделала
    // lightweight-миграцию автоматически, без VersionedSchema/SchemaMigrationPlan.
    var interestTypeRaw: String = DepositInterestType.simple.rawValue
    var capitalizationPeriodRaw: String? = nil
    var allowsReplenishment: Bool = false
    var allowsPartialWithdrawal: Bool = false
    var isRevocable: Bool = true
    var earlyWithdrawalRate: Double? = nil
    var actualCloseDate: Date? = nil   // фактическая дата закрытия (может быть раньше closeDate)
}
```

`currencyRaw`/`interestTypeRaw`/`capitalizationPeriodRaw` хранятся как `String`, а не
как сам enum — это обходит баг SwiftData с ленивой загрузкой кастомных enum-полей
(комментарий в коде указывает на iOS 26). Typed-доступ даёт вычисляемое свойство
(`currency`, `interestType`, `capitalizationPeriod`) поверх `*Raw`-поля.

`DepositTransaction` — отдельная модель, не relationship на `Deposit` (в проекте
relationships не используются вообще — всё через `UUID`-поля вроде `depositId`,
по аналогии с тем, как остальные модели ссылаются друг на друга):

```swift
@Model
final class DepositTransaction {
    var id: UUID
    var depositId: UUID
    var date: Date
    var amount: Double   // положительная — пополнение, отрицательная — снятие
}
```

---

## 4. Repository Protocol Pattern

Пример реального кода — `DepositsRepository` (в `Model/DepositsRepository.swift`, да, репозитории
лежат в группе `Model`, не в отдельной группе `Repository`):

```swift
protocol DepositsRepository {
    func fetchAll() async throws -> [Deposit]
    func add(_ deposit: Deposit) async throws
    func delete(id: UUID) async throws
    func update(id: UUID, title: String, bankName: String?, amount: Double,
                 currency: DepositCurrency, openDate: Date, closeDate: Date?,
                 annualInterestRate: Double, interestType: DepositInterestType,
                 capitalizationPeriod: CapitalizationPeriod?, allowsReplenishment: Bool,
                 allowsPartialWithdrawal: Bool, isRevocable: Bool,
                 earlyWithdrawalRate: Double?, actualCloseDate: Date?) async throws

    func transactions(forDepositId depositId: UUID) async throws -> [DepositTransaction]
    func fetchAllTransactions() async throws -> [DepositTransaction]
    func addTransaction(_ transaction: DepositTransaction) async throws
    func deleteTransaction(id: UUID) async throws
}

@ModelActor
actor SwiftDataDepositsRepository: @preconcurrency DepositsRepository {
    func fetchAll() async throws -> [Deposit] {
        try modelContext.fetch(FetchDescriptor<Deposit>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))
    }
    func add(_ deposit: Deposit) async throws {
        modelContext.insert(deposit)
        try modelContext.save()
    }
    // ...
}

final class InMemoryDepositsRepository: DepositsRepository {
    private var deposits: [Deposit] = []
    private var depositTransactions: [DepositTransaction] = []
    // ...
}
```

`update(...)` принимает все поля явно (не сам объект `Deposit`) — это сознательный
выбор с самого начала проекта: репозиторий не должен угадывать, какие поля менялись.
При добавлении нового поля в `Deposit` новый параметр обычно добавляется в конец
сигнатуры `update` (и на уровне `DepositsService`, и на уровне `DepositsViewModel`) —
а на уровне ViewModel ему обычно дают default-значение, чтобы существующие вызовы
(из View, из тестов) не требовали правок.

`SubscriptionsRepository` в `Model/SubscriptionsRepository.swift` построен по тому же
шаблону (протокол + `SwiftDataSubscriptionsRepository` + `InMemorySubscriptionsRepository`).

---

## 5. Service Layer

Сервисы — единственное место с бизнес-логикой. `DepositsService`
(`Service/DepositsService.swift`) считает доход по вкладу:

```swift
protocol DepositsService {
    func fetchAll() async throws -> [Deposit]
    func add(_ deposit: Deposit) async throws
    func delete(id: UUID) async throws
    func update(...) async throws
    func incomeSummary(for deposit: Deposit, transactions: [DepositTransaction], asOf date: Date) -> DepositIncomeSummary

    func transactions(forDepositId depositId: UUID) async throws -> [DepositTransaction]
    func fetchAllTransactions() async throws -> [DepositTransaction]
    func addTransaction(_ transaction: DepositTransaction) async throws
    func deleteTransaction(id: UUID) async throws
}

extension DepositsService {
    // Удобный оверлоад для мест, где история операций не нужна/не загружена.
    func incomeSummary(for deposit: Deposit, asOf date: Date) -> DepositIncomeSummary {
        incomeSummary(for: deposit, transactions: [], asOf: date)
    }
}
```

### Расчёт дохода — единый алгоритм на все случаи

`DefaultDepositsService.income(for:transactions:until:rateOverride:)` — одна функция,
которая покрывает: простой процент, капитализацию (помесячно/поквартально/погодично),
пополнения/снятия и досрочное закрытие безотзывного вклада по пониженной ставке.
Идея: пройти по хронологически отсортированным «чекпоинтам» (границы периодов
капитализации + даты транзакций), на каждом — либо капитализировать накопленные
проценты в тело вклада, либо применить пополнение/снятие к телу.

```swift
private enum Checkpoint {
    case capitalization(Date)
    case transaction(Date, amount: Double)
}

private func income(for deposit: Deposit, transactions: [DepositTransaction],
                     until end: Date, rateOverride: Double? = nil) -> Double {
    let dailyRate = ((rateOverride ?? deposit.annualInterestRate) / 100.0) / 365.0
    // ... собрать чекпоинты, пройти по ним, капитализируя/применяя транзакции ...
}
```

`incomeSummary(...)`:
- ограничивает «доход на сегодня» датой `actualCloseDate` (если вклад закрыт
  вручную) или плановой `closeDate` (если она уже наступила)
- для безотзывного вклада, закрытого раньше `closeDate`, пересчитывает весь доход
  по `earlyWithdrawalRate` через `rateOverride` — без дублирования логики капитализации
- прогноз (`forecastIncomeToCloseDate`) всегда считается по обычной ставке и `nil`,
  если вклад уже закрыт

`SubscriptionsService` (`Service/SubscriptionsService.swift`) проще — считает
`monthlyCost`/`annualCost` по типу цикла оплаты и суммирует активные подписки в валюте.

---

## 6. Dependency Injection — `DIContainer`

Реальный код (`Service/DIContainer.swift`):

```swift
final class DIContainer: ObservableObject {
    let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func makeDepositsService() -> any DepositsService {
        DefaultDepositsService(repository: SwiftDataDepositsRepository(modelContainer: modelContainer))
    }

    func makeSubscriptionsService() -> any SubscriptionsService {
        DefaultSubscriptionsService(repository: SwiftDataSubscriptionsRepository(modelContainer: modelContainer))
    }

    /// Удаляет все вклады и подписки (используется экраном сброса в Настройках).
    func resetAllData() async throws { ... }

    /// In-memory контейнер для SwiftUI Preview и тестов.
    static let preview: DIContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Deposit.self, DepositTransaction.self, Settings.self, Subscription.self,
            configurations: config
        )
        return DIContainer(modelContainer: container)
    }()
}
```

Никаких `isPreview`-флагов, никакого `marketRepo`, никакого `PriceCache` — контейнер
знает только про SwiftData. `ViewModel`ы создаются в `init(container:)` конкретного
View (`DepositsView.init(container:)` и т.п.) и хранятся как `@StateObject`.

**Важно при добавлении новой `@Model` модели:** она должна попасть в список схемы
в трёх местах одновременно, иначе что-то из трёх не увидит новую таблицу:
1. `InvestPortfolioApp.swift` — `Schema([...])` основного приложения
2. `DIContainer.preview` — `ModelContainer(for: ...)` для тестов/превью
3. `InvestPortfolioWidgets/SharedModelContainer.swift` — `Schema([...])` виджетов

---

## 7. Виджеты (App Group)

`InvestPortfolioWidgets` — отдельное расширение (widget extension), читающее тот же
SwiftData-стор через App Group `group.io.rentivo.app`:

```swift
// InvestPortfolioWidgets/SharedModelContainer.swift
enum SharedModelContainer {
    static func make() -> ModelContainer? {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.io.rentivo.app"
        ) else { return nil }
        let schema = Schema([Deposit.self, DepositTransaction.self, Settings.self, Subscription.self])
        return try? ModelContainer(for: schema, configurations: ModelConfiguration(url: storeURL))
    }
}
```

Виджет только читает (`DepositsWidget.swift`, `SubscriptionsWidget.swift`) — никогда
не пишет в стор. Логика «что показать» (открытые вклады, ближайшие платежи) переиспользует
те же чистые функции из `Model/HomeQueries.swift`, что и `HomeViewModel` в основном
приложении — см. §9, чтобы определение «открытый вклад» не разошлось между таргетами.

Приложение и виджет имеют независимые `.strings`-ресурсы
(`Resources/Localizable.strings/*` и `InvestPortfolioWidgets/Localizable.strings/*`) —
при добавлении строки, которая нужна и там, и там, её придётся продублировать в оба
набора файлов.

---

## 8. Онбординг и демо-данные

```
InvestPortfolioApp → RootView
                        ├── MainTabView (всегда)
                        └── fullScreenCover: OnboardingView
                              (пока !App_HasCompletedOnboarding)
```

`OnboardingView` — два пути: «Попробовать с примером данных» (грузит
`SampleDataService.load(into:)`, который просто добавляет заготовленные `Deposit`/
`Subscription` через обычные сервисы) или «Начать с чистого листа» (просто ставит
флаг заполнения онбординга).

---

## 9. Home и Analytics — общая логика между экраном и виджетом

`Model/HomeQueries.swift` — чистые `extension Array where Element == Deposit/Subscription`
без зависимостей от SwiftData/сервисов, специально чтобы одно и то же определение
«открытый вклад»/«ближайший платёж» использовалось и в `HomeViewModel` (внутри приложения),
и в виджетах (отдельный процесс, свой `ModelContainer`) без риска, что они разойдутся:

```swift
extension Array where Element == Deposit {
    var openSortedByCloseDate: [Deposit] { ... }
}
extension Array where Element == Subscription {
    func nearestUpcoming(limit: Int = 5) -> [Subscription] { ... }
}
```

`AnalyticsViewModel` считает доход/расход **по месяцам** для выбранного года и валюты,
разбивая депозитный доход на помесячные срезы через два вызова
`depositsService.incomeSummary(asOf:)` (на конец месяца и на день перед его началом,
разница — доход за месяц) — это тот же приём, которым сам `DepositDetailViewModel`
строит точки графика роста вклада (см. следующий пункт).

---

## 10. Вклады — модельная фича проекта (эпик #24)

Самая развитая по слоям часть приложения — вклады с капитализацией, пополнением/снятием
и отзывностью, реализованная в GitHub-issues #17–#24 на ветке `feature/deposit-types`:

- **#17** — `DepositInterestType`/`CapitalizationPeriod` на модели `Deposit`
- **#18** — расчёт дохода с капитализацией в `DefaultDepositsService`
- **#19** — `DepositTransaction` (пополнения/снятия) + CRUD в репозитории/сервисе
- **#20** — `isRevocable`/`earlyWithdrawalRate`/`actualCloseDate`, штраф за досрочное закрытие
- **#21** — адаптивная форма (`DepositFormSheet` в `View/DepositsView.swift`) с прогрессивным
  раскрытием секций под выбранный тип вклада
- **#22** — `DepositDetailView`/`DepositDetailViewModel` (`View/DepositDetailView.swift`,
  `ViewModel/DepositDetailViewModel.swift`): экран деталей с графиком роста (Swift Charts),
  историей операций, кнопками пополнения/снятия и досрочного закрытия
- **#23** — CSV-колонки для новых полей вклада + отдельный CSV-формат для
  `DepositTransaction` (см. §11)

`DepositDetailViewModel` строит точки графика, вызывая `incomeSummary` в наборе дат
(границы капитализации/транзакций/сегодня/плановая дата закрытия) и складывая
`amount + netTransactions(до даты) + incomeToDate` — без отдельной «формулы для графика»,
поверх той же точки входа, что и всё остальное.

---

## 11. CSV Import/Export

`Service/CSVExporter.swift` / `Service/CSVImporter.swift` — RFC 4180, без внешних
зависимостей. Три независимых формата (экспортируются/импортируются по отдельности
из экрана «Настройки → Данные», `View/SettingsView.swift`):

| Формат | Заголовок |
|---|---|
| Вклады | `ID,Title,Bank,Amount,Currency,OpenDate,CloseDate,AnnualRate%,CreatedAt,InterestType,CapitalizationPeriod,AllowsReplenishment,AllowsPartialWithdrawal,IsRevocable,EarlyWithdrawalRate` |
| Подписки | `ID,Title,Category,Amount,Currency,BillingCycle,StartDate,EndDate,IsActive,CreatedAt` |
| Операции по вкладам | `ID,DepositID,Date,Amount` |

Колонки `InterestType`…`EarlyWithdrawalRate` были добавлены позже (#23) **в конец**
строки вкладов и опциональны при импорте: если их меньше, чем в текущем формате,
недостающие получают те же default-значения, что и сам `Deposit.init` (простой процент,
без капитализации, не пополняемый, отзывный). Это единственный способ, которым CSV
сохраняет обратную совместимость — миграций формата файла нет, только «столбец не нашли
→ подставили значение по умолчанию».

Известные ограничения (задокументированы тестами, не фиксятся специально):
- Заголовок/название с буквальным переводом строки внутри ломает построчный парсинг
  (строка теряется, остальные — нет)
- У подписок нет колонки `iconName` — кастомная иконка не переживает экспорт/импорт

---

## 12. Локализация — `LanguageBundle`

Переключение языка **внутри приложения** (не следуя системному языку устройства)
реализовано подменой класса `Bundle.main`:

```swift
final class LanguageBundle: Bundle, @unchecked Sendable {
    static func activate() { object_setClass(Bundle.main, LanguageBundle.self) }
    static func set(languageCode: String) { /* подставить .lproj для нового языка */ }
    static func string(_ key: String) -> String { /* для String, не Text */ }

    override func localizedString(forKey key: String, value: String?, table: String?) -> String {
        // если выбран не системный язык — отдать строку из его .lproj
    }
}
```

`LanguageBundle.activate()` — самый первый вызов в `InvestPortfolioApp.init()`, до
любого чтения локализованной строки. `Text("key")`/`Label`/`.navigationTitle` работают
через этот механизм автоматически; но **`String(localized:)` этот оверрайд не видит**
(использует другой, более новый путь резолва) — поэтому везде, где нужен `String`,
а не `Text`, используется `LanguageBundle.string("key")`, а не `String(localized:)`.

Три набора строк на ru/en/Base в `Resources/Localizable.strings/{ru,en,Base}.lproj` —
формат `.strings` (`"key" = "value";`), не String Catalog (`.xcstrings`).

---

## 13. Конкурентность

| Слой | Изоляция | Почему |
|---|---|---|
| ViewModels | `@MainActor` | Обновляют `@Published`, должны быть на main thread |
| SwiftData-репозитории | `@ModelActor` | `ModelContext` не `Sendable` |
| In-memory репозитории | обычный класс | Используются только из `@MainActor`-тестов/ViewModel, изоляция не нужна |
| `DefaultDepositsService`/`DefaultSubscriptionsService` | обычный класс, синхронные вычисления + `await` на репозиторий | Чистые расчёты (`incomeSummary`, `monthlyCost`) не требуют актора — работают с уже переданными значениями |

Паттерн ViewModel: `func load() async { ... }`, вызывается из `.task { await vm.load() }`
во View — никаких `Task.detached`, никакого ручного управления потоками.

---

## 14. Тестирование

- Framework: **Swift Testing** (`import Testing`, `@Test`, `@Suite`, `#expect`) — не XCTest,
  кроме там, где XCUIAutomation могла бы понадобиться для UI-тестов (их пока нет)
- Юнит-тесты сервисов/репозиториев всегда идут через `InMemory*Repository`, а не мокают
  протокол вручную — так тестируется весь путь service → repository целиком
- `DepositsServiceTests.swift` — самый крупный набор: простой/капитализированный процент,
  транзакции, отзывность/штраф за досрочное закрытие, каждый сценарий — через точное
  значение (руками посчитанная формула) или отношение («с капитализацией доход больше»)
- CSV-тесты (`CSVExporterTests`/`CSVImporterTests`) всегда проверяют round-trip
  (export → import → сравнить с оригиналом), а не только форматирование
- Для UI-изменений (SwiftUI-экраны) юнит-тестов нет — проверка делается вручную через
  симулятор (см. историю правок вкладов — там баг с бейджем «Активен»/«Закрыт» после
  досрочного закрытия был найден именно так, юнит-тестами такое не поймать, так как это
  чисто View-логика)

---

## 15. Структура файлов (реальная, не целевая)

```
InvestPortfolio/                          ← корень Xcode-проекта (сам таргет приложения)
├── InvestPortfolioApp.swift              ← @main, Schema(...), sharedStoreURL()
├── PrivacyInfo.xcprivacy
├── InvestPortfolio.entitlements          ← App Group
│
├── Model/                                ← @Model классы + протоколы репозиториев + чистые extensions
│   ├── Deposit.swift
│   ├── DepositInterestType.swift
│   ├── CapitalizationPeriod.swift
│   ├── DepositTransaction.swift
│   ├── DepositsRepository.swift          ← протокол + SwiftData + InMemory
│   ├── DepositCurrency.swift
│   ├── Subscription.swift                ← бизнес-логика (nextPaymentDate, advance)
│   ├── SubscriptionBillingCycle.swift
│   ├── SubscriptionsRepository.swift     ← протокол + SwiftData + InMemory
│   ├── AppSchema.swift                   ← @Model final class Subscription (хранимые поля)
│   ├── HomeQueries.swift                 ← чистые extensions, общие с виджетом
│   └── Settings.swift
│
├── Service/                              ← бизнес-логика + инфраструктура
│   ├── DepositsService.swift
│   ├── SubscriptionsService.swift
│   ├── DIContainer.swift
│   ├── LanguageBundle.swift
│   ├── CSVExporter.swift
│   ├── CSVImporter.swift
│   ├── SampleDataService.swift
│   └── RootView.swift
│
├── ViewModel/
│   ├── DepositsViewModel.swift
│   ├── DepositDetailViewModel.swift
│   ├── SubscriptionsViewModel.swift
│   ├── AnalyticsViewModel.swift
│   └── HomeViewModel.swift
│
├── View/
│   ├── MainTabView.swift
│   ├── HomeTabView.swift
│   ├── DepositsView.swift                ← список + DepositFormSheet + DepositRow
│   ├── DepositDetailView.swift           ← экран деталей, график, история операций
│   ├── SubscriptionsView.swift
│   ├── AnalyticsView.swift
│   ├── SettingsView.swift                ← язык, валюты, импорт/экспорт, сброс данных
│   ├── OnboardingView.swift
│   ├── Color+Brand.swift
│   └── Color+TertiaryLabel.swift
│
├── Assets.xcassets
│
├── Resources/
│   └── Localizable.strings/{Base,ru,en}.lproj
│
├── InvestPortfolioWidgets/               ← отдельный таргет (widget extension)
│   ├── InvestPortfolioWidgetsBundle.swift
│   ├── SharedModelContainer.swift        ← App Group ModelContainer, read-only
│   ├── DepositsWidget.swift
│   ├── SubscriptionsWidget.swift
│   ├── InvestPortfolioWidgetsExtension.entitlements  ← тот же App Group
│   ├── Info.plist
│   ├── Assets.xcassets
│   └── Localizable.strings/{Base,ru,en}.lproj   ← свой набор строк, отдельный от приложения
│
└── InvestPortfolioTests/                 ← отдельный таргет (юнит-тесты, Swift Testing)
    ├── DepositsServiceTests.swift
    ├── DepositsViewModelTests.swift
    ├── DepositDetailViewModelTests.swift
    ├── SubscriptionServiceTests.swift
    ├── SubscriptionRepositoryTests.swift
    ├── SubscriptionViewModelTests.swift
    ├── AnalyticsViewModelTests.swift
    ├── HomeViewModelTests.swift
    ├── CSVExporterTests.swift
    └── CSVImporterTests.swift
```

---

## 16. Чеклист перед добавлением новой фичи

- [ ] Новая `@Model` модель добавлена в **три** места со схемой (см. §6): `InvestPortfolioApp.swift`,
      `DIContainer.preview`, `InvestPortfolioWidgets/SharedModelContainer.swift`
- [ ] У всех новых хранимых свойств есть значения по умолчанию в объявлении — для
      автоматической lightweight-миграции без ручного `VersionedSchema`
- [ ] Для нового репозитория есть и протокол, и SwiftData-реализация, и InMemory-реализация
- [ ] `update(...)` в репозитории/сервисе/ViewModel принимает новые поля явно; новым
      параметрам во View-слое (ViewModel) стоит давать значения по умолчанию, чтобы не
      ломать существующие вызовы
- [ ] Новые комментарии в коде — на английском (см. память проекта `feedback-comments-in-english`)
- [ ] Новые строки — во все три `.strings`-файла (`ru`/`en`/`Base`), и в отдельный набор
      виджетов, если строка нужна и там
- [ ] Если фича меняет CSV-формат — новые колонки только в конец строки, импорт обязан
      остаться обратно совместим со старым числом колонок (см. §11)
- [ ] Для UI-изменений — нет юнит-тестов на SwiftUI-код в этом проекте; проверка руками
      через симулятор (Xcode MCP device-interaction) перед тем, как считать фичу готовой
