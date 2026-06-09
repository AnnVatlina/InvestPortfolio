# InvestPortfolio — Architecture Design

> Версия: 1.0 | 2026-04-04
> Стек: SwiftUI + SwiftData + Spring Boot proxy + async/await

---

## 1. Общая схема слоёв

```
┌─────────────────────────────────────────────────────────────┐
│                        SwiftUI Views                        │
│          (только отображение, zero business logic)          │
└───────────────────────────┬─────────────────────────────────┘
                            │  @StateObject / @EnvironmentObject
┌───────────────────────────▼─────────────────────────────────┐
│                        ViewModels                           │
│          @MainActor, ObservableObject                       │
│          Координирует UI-состояние, вызывает сервисы        │
└────────────────┬──────────────────────┬─────────────────────┘
                 │                      │
   ┌─────────────▼────────┐  ┌──────────▼──────────────────┐
   │   Local Services     │  │    Remote Services           │
   │  (бизнес-логика,     │  │   (рыночные данные,          │
   │   расчёты, CRUD)     │  │    котировки, мета-данные)   │
   └─────────────┬────────┘  └──────────┬──────────────────┘
                 │                      │
   ┌─────────────▼────────┐  ┌──────────▼──────────────────┐
   │  Local Repositories  │  │  Remote Repositories         │
   │  (протоколы)         │  │  (протоколы)                 │
   └─────────────┬────────┘  └──────────┬──────────────────┘
                 │                      │
   ┌─────────────▼────────┐  ┌──────────▼──────────────────┐
   │     SwiftData        │  │   Spring Boot Proxy          │
   │  (offline-first)     │  │   (рыночные данные, кеш,     │
   │                      │  │    авторизация с API-ключами)│
   └─────────────────────-┘  └─────────────────────────────┘
```

**Ключевые принципы:**
- ViewModels не знают об SwiftData / URLSession — только о протоколах сервисов
- Сервисы не знают о конкретных реализациях репозиториев — только о протоколах
- Замена SwiftData → REST = замена одной реализации репозитория, ничего больше

---

## 2. Разделение данных: Local vs Remote

| Тип данных | Источник | Где хранится |
|------------|----------|-------------|
| Транзакции | Пользователь / CSV / Tradernet | SwiftData (offline-first) |
| Вклады | Пользователь | SwiftData |
| Подписки | Пользователь | SwiftData |
| Активы (метаданные) | Spring Boot proxy | SwiftData (кеш) |
| Котировки текущие | Spring Boot proxy | NSCache / SwiftData (TTL 5 мин) |
| Исторические цены | Spring Boot proxy | SwiftData (кеш) |
| Дивиденды | Пользователь + proxy | SwiftData |

---

## 3. Repository Protocol Pattern

### Правило: каждый репозиторий — это протокол

```swift
// Пример: локальный репозиторий транзакций
protocol TransactionRepository: Sendable {
    func fetchAll() async throws -> [Transaction]
    func fetch(assetId: UUID) async throws -> [Transaction]
    func fetch(from: Date, to: Date) async throws -> [Transaction]
    func save(_ transaction: Transaction) async throws
    func delete(id: UUID) async throws
    func deleteAll() async throws
}

// Реализация 1: SwiftData (production)
@ModelActor
actor SwiftDataTransactionRepository: TransactionRepository {
    func fetchAll() async throws -> [Transaction] {
        try modelContext.fetch(FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ))
    }
    func save(_ transaction: Transaction) async throws {
        modelContext.insert(transaction)
        try modelContext.save()
    }
    // ...
}

// Реализация 2: In-Memory (тесты / Preview)
final class InMemoryTransactionRepository: TransactionRepository {
    private var store: [Transaction] = []
    func fetchAll() async throws -> [Transaction] { store }
    func save(_ t: Transaction) async throws { store.append(t) }
    // ...
}

// Реализация 3 (будущее): REST API
final class RESTTransactionRepository: TransactionRepository {
    private let client: APIClient
    func fetchAll() async throws -> [Transaction] {
        try await client.get("/transactions")
    }
    // ...
}
```

### Репозитории рыночных данных (Remote)

```swift
protocol MarketDataRepository: Sendable {
    func fetchQuote(ticker: String) async throws -> QuoteDTO
    func fetchQuotes(tickers: [String]) async throws -> [QuoteDTO]
    func fetchHistoricalPrices(
        ticker: String,
        from: Date,
        to: Date,
        interval: PriceInterval
    ) async throws -> [PricePointDTO]
    func searchAssets(query: String) async throws -> [AssetSearchResultDTO]
}

// Реализация через Spring Boot proxy
final class SpringBootMarketDataRepository: MarketDataRepository {
    private let client: MarketAPIClient

    func fetchQuote(ticker: String) async throws -> QuoteDTO {
        try await client.get("/market/quote/\(ticker)")
    }
    func fetchQuotes(tickers: [String]) async throws -> [QuoteDTO] {
        try await client.post("/market/quotes", body: QuotesRequest(tickers: tickers))
    }
    func fetchHistoricalPrices(...) async throws -> [PricePointDTO] {
        try await client.get("/market/history/\(ticker)", params: [...])
    }
}

// Реализация-заглушка для тестов
final class MockMarketDataRepository: MarketDataRepository {
    var quotesMap: [String: QuoteDTO] = [:]
    func fetchQuote(ticker: String) async throws -> QuoteDTO {
        guard let q = quotesMap[ticker] else { throw MarketError.notFound }
        return q
    }
}
```

---

## 4. Service Layer

Сервис содержит бизнес-логику и комбинирует данные из нескольких репозиториев.

```swift
// Портфель: считает позиции из транзакций + обогащает текущими ценами
protocol PortfolioService: Sendable {
    func buildPortfolio() async throws -> Portfolio
    func position(for ticker: String) async throws -> PortfolioPosition?
    func refreshPrices() async throws
}

final class DefaultPortfolioService: PortfolioService {
    private let transactionRepo: any TransactionRepository
    private let marketRepo: any MarketDataRepository
    private let priceCache: PriceCache          // NSCache-обёртка, TTL 5 мин

    func buildPortfolio() async throws -> Portfolio {
        // 1. Загружаем транзакции локально (offline-first)
        let transactions = try await transactionRepo.fetchAll()

        // 2. Считаем позиции (средняя цена, количество) — pure function
        let positions = PortfolioCalculator.positions(from: transactions)

        // 3. Обогащаем текущими ценами (network, с fallback на кеш)
        let tickers = positions.map(\.ticker)
        let quotes = try await fetchQuotesCached(tickers: tickers)

        // 4. Возвращаем готовый портфель
        return Portfolio(positions: positions, quotes: quotes)
    }

    private func fetchQuotesCached(tickers: [String]) async throws -> [String: QuoteDTO] {
        let stale = tickers.filter { priceCache.isExpired($0) }
        if !stale.isEmpty {
            let fresh = try await marketRepo.fetchQuotes(tickers: stale)
            fresh.forEach { priceCache.set($0, for: $0.ticker) }
        }
        return Dictionary(tickers.compactMap { t in
            priceCache.get(t).map { (t, $0) }
        }, uniquingKeysWith: { $1 })
    }
}
```

### Чистые функции — PortfolioCalculator

```swift
// Не зависит от SwiftData / API — легко тестировать
enum PortfolioCalculator {

    // Позиции из транзакций (средневзвешенная цена)
    static func positions(from transactions: [Transaction]) -> [PortfolioPosition] {
        var grouped = [String: [Transaction]]()
        for t in transactions { grouped[t.ticker, default: []].append(t) }

        return grouped.compactMap { ticker, txs -> PortfolioPosition? in
            let buys  = txs.filter { $0.type == .buy  }
            let sells = txs.filter { $0.type == .sell }
            let qty   = buys.reduce(0) { $0 + $1.quantity }
                      - sells.reduce(0) { $0 + $1.quantity }
            guard qty > 0 else { return nil }

            let totalCost = buys.reduce(0) { $0 + $1.quantity * $1.price + $1.fee }
            let avgPrice  = totalCost / buys.reduce(0) { $0 + $1.quantity }

            return PortfolioPosition(ticker: ticker, quantity: qty, avgPrice: avgPrice)
        }
    }

    // XIRR (внутренняя норма доходности)
    static func xirr(cashFlows: [(date: Date, amount: Double)]) -> Double? {
        // Newton-Raphson итерация
        // ...
    }
}
```

---

## 5. Dependency Injection через DIContainer

```swift
// Единственное место, где знают о конкретных реализациях
@MainActor
final class DIContainer: ObservableObject {
    let modelContainer: ModelContainer
    private let marketRepo: any MarketDataRepository
    private let priceCache = PriceCache()

    init(modelContainer: ModelContainer, isPreview: Bool = false) {
        self.modelContainer = modelContainer
        if isPreview {
            self.marketRepo = MockMarketDataRepository()
        } else {
            let client = MarketAPIClient(baseURL: Config.springBootBaseURL)
            self.marketRepo = SpringBootMarketDataRepository(client: client)
        }
    }

    // MARK: - ViewModels (фабричные методы)

    func makePortfolioViewModel() -> PortfolioViewModel {
        PortfolioViewModel(service: makePortfolioService())
    }

    func makeDepositsViewModel() -> DepositsViewModel {
        DepositsViewModel(service: makeDepositsService())
    }

    // MARK: - Services

    func makePortfolioService() -> any PortfolioService {
        DefaultPortfolioService(
            transactionRepo: SwiftDataTransactionRepository(modelContainer: modelContainer),
            marketRepo: marketRepo,
            priceCache: priceCache
        )
    }

    func makeDepositsService() -> any DepositsService {
        DefaultDepositsService(
            repository: SwiftDataDepositsRepository(modelContainer: modelContainer)
        )
    }

    // MARK: - Preview container (статический)

    static let preview: DIContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Transaction.self, Asset.self, Deposit.self,
                Subscription.self, Dividend.self, Settings.self,
            configurations: config
        )
        return DIContainer(modelContainer: container, isPreview: true)
    }()
}
```

### Подключение в App

```swift
@main
struct InvestPortfolioApp: App {
    @StateObject private var container: DIContainer

    init() {
        let mc = try! ModelContainer(
            for: Transaction.self, Asset.self, Deposit.self,
                Subscription.self, Dividend.self, CashOperation.self,
                PortfolioPosition.self, Settings.self
        )
        _container = StateObject(wrappedValue: DIContainer(modelContainer: mc))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
        }
        .modelContainer(container.modelContainer)
    }
}
```

### Использование в View

```swift
struct PortfolioView: View {
    // Вариант А: ViewModel создаётся из контейнера один раз
    @StateObject private var vm: PortfolioViewModel

    init(container: DIContainer) {
        _vm = StateObject(wrappedValue: container.makePortfolioViewModel())
    }

    var body: some View { ... }
}

// Вариант Б: через EnvironmentObject (если ViewModel живёт долго)
struct DepositsView: View {
    @EnvironmentObject private var container: DIContainer
    @StateObject private var vm: DepositsViewModel

    init() {
        // lazy init через onAppear или через container в init
    }
}
```

---

## 6. Spring Boot Proxy — Интеграция

### Зачем прокси
- API-ключи к платным провайдерам (Alpha Vantage, Finnhub) **не попадают в приложение**
- Кеширование котировок на сервере → меньше запросов к провайдеру
- Нормализация данных под формат iOS-приложения
- Возможность добавить облачный sync в будущем

### Эндпоинты Spring Boot (ожидаемый контракт)

```
GET  /market/quote/{ticker}              → QuoteDTO
POST /market/quotes                      → [QuoteDTO]   (body: { tickers: [...] })
GET  /market/history/{ticker}?from=&to=&interval=  → [PricePointDTO]
GET  /market/search?q={query}            → [AssetSearchResultDTO]
GET  /market/asset/{ticker}              → AssetMetaDTO
```

### Клиент для Spring Boot

```swift
final class MarketAPIClient: Sendable {
    private let baseURL: URL
    private let session: URLSession

    // Универсальный метод с автодекодингом
    func get<T: Decodable>(_ path: String, params: [String: String] = [:]) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)!
        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        let (data, response) = try await session.data(from: components.url!)
        try validate(response)
        return try JSONDecoder.iso8601.decode(T.self, from: data)
    }

    func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try JSONDecoder.iso8601.decode(Response.self, from: data)
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299: break
        case 401: throw APIError.unauthorized
        case 429: throw APIError.rateLimited
        default: throw APIError.httpError(statusCode: http.statusCode)
        }
    }
}
```

### DTO структуры (iOS сторона)

```swift
struct QuoteDTO: Decodable, Sendable {
    let ticker: String
    let price: Double
    let change: Double          // абсолютное изменение за день
    let changePercent: Double   // % изменение за день
    let currency: String
    let updatedAt: Date
}

struct PricePointDTO: Decodable, Sendable {
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int?
}

struct AssetSearchResultDTO: Decodable, Identifiable, Sendable {
    let ticker: String
    let name: String
    let type: String
    let exchange: String
    let currency: String
    var id: String { ticker }
}

enum PriceInterval: String {
    case day = "1d"
    case week = "1w"
    case month = "1mo"
}
```

---

## 7. Offline-First: стратегия кеширования

```
Запрос данных:
┌──────────────────────────────────────────────┐
│ 1. Есть локальные данные в SwiftData?         │
│    ДА → вернуть немедленно (stale-while-reval)│
│    НЕТ → перейти к п.2                       │
├──────────────────────────────────────────────┤
│ 2. Есть интернет?                            │
│    ДА → загрузить из Spring Boot, сохранить  │
│         в SwiftData, вернуть свежие          │
│    НЕТ → вернуть ошибку с флагом isOffline   │
└──────────────────────────────────────────────┘
```

```swift
// PriceCache — лёгкий NSCache для котировок в памяти
final class PriceCache: @unchecked Sendable {
    private let cache = NSCache<NSString, CacheEntry>()
    private let ttl: TimeInterval

    init(ttl: TimeInterval = 300) { // 5 минут
        self.ttl = ttl
        cache.countLimit = 500
    }

    func get(_ ticker: String) -> QuoteDTO? {
        guard let entry = cache.object(forKey: ticker as NSString),
              Date().timeIntervalSince(entry.timestamp) < ttl
        else { return nil }
        return entry.quote
    }

    func set(_ quote: QuoteDTO, for ticker: String) {
        cache.setObject(CacheEntry(quote: quote, timestamp: Date()), forKey: ticker as NSString)
    }

    func isExpired(_ ticker: String) -> Bool { get(ticker) == nil }

    private final class CacheEntry: NSObject {
        let quote: QuoteDTO
        let timestamp: Date
        init(quote: QuoteDTO, timestamp: Date) {
            self.quote = quote; self.timestamp = timestamp
        }
    }
}
```

---

## 8. Конкурентность и безопасность

| Слой | Изоляция | Причина |
|------|----------|---------|
| ViewModels | `@MainActor` | Обновляют `@Published` — только main thread |
| SwiftData Repositories | `@ModelActor` | ModelContext не Sendable |
| Services | `Sendable` протоколы | Могут вызываться из любого контекста |
| APIClient / MarketClient | `final + Sendable` | URLSession уже Sendable |
| PriceCache | `@unchecked Sendable` + NSCache | Потокобезопасен внутри |

```swift
// Правильный паттерн: ViewModel запускает Task и получает результат на main thread
@MainActor
final class PortfolioViewModel: ObservableObject {
    @Published var portfolio: Portfolio?
    @Published var isLoading = false
    @Published var error: String?

    private let service: any PortfolioService

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            portfolio = try await service.buildPortfolio()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refresh() {
        Task { await load() }  // Task наследует @MainActor контекст
    }
}
```

---

## 9. Путь миграции SwiftData → REST API

Именно для этого и нужен паттерн Repository:

```
Шаг 1 (сейчас):
  PortfolioService ← SwiftDataTransactionRepository

Шаг 2 (добавить облачный sync):
  PortfolioService ← HybridTransactionRepository
                         ├── SwiftDataTransactionRepository (local write)
                         └── RESTTransactionRepository     (remote sync)

Шаг 3 (полный переезд на REST):
  PortfolioService ← RESTTransactionRepository
```

```swift
// HybridTransactionRepository — write-through cache
final class HybridTransactionRepository: TransactionRepository {
    private let local: any TransactionRepository
    private let remote: any TransactionRepository

    func save(_ transaction: Transaction) async throws {
        // Сначала локально (мгновенно для UI)
        try await local.save(transaction)
        // Потом синхронизируем (в фоне, с retry)
        Task.detached(priority: .background) {
            try? await self.remote.save(transaction)
        }
    }

    func fetchAll() async throws -> [Transaction] {
        // Офлайн-first: сначала локальные
        let local = try await local.fetchAll()
        // Фоновое обновление
        Task.detached(priority: .background) {
            if let remote = try? await self.remote.fetchAll() {
                try? await self.sync(remote: remote)
            }
        }
        return local
    }
}
```

---

## 10. Конфигурация (Config.swift)

```swift
enum Config {
    // Spring Boot proxy URL
    #if DEBUG
    static let springBootBaseURL = URL(string: "http://localhost:8080/api")!
    #else
    static let springBootBaseURL = URL(string: "https://your-server.com/api")!
    #endif

    // Tradernet
    static let tradernetBaseURL = URL(string: "https://tradernet.ru/api")!

    // Cache TTLs
    static let quoteCacheTTL: TimeInterval = 300       // 5 мин
    static let historyCacheTTL: TimeInterval = 3600    // 1 час
    static let assetMetaCacheTTL: TimeInterval = 86400 // 24 часа
}
```

---

## 11. Структура файлов (целевая)

```
InvestPortfolio/
├── App/
│   ├── InvestPortfolioApp.swift
│   ├── DIContainer.swift          ← Dependency Injection
│   └── Config.swift               ← Конфигурация
│
├── Model/                         ← @Model классы (SwiftData)
│   ├── Asset.swift
│   ├── Transaction.swift
│   ├── Dividend.swift
│   ├── Deposit.swift
│   ├── Subscription.swift
│   ├── CashOperation.swift
│   └── Settings.swift
│
├── Repository/                    ← Протоколы + реализации
│   ├── TransactionRepository.swift
│   ├── AssetRepository.swift
│   ├── DividendRepository.swift
│   ├── DepositRepository.swift
│   └── SubscriptionRepository.swift
│
├── APIClient/                     ← Сетевой слой
│   ├── MarketAPIClient.swift      ← Spring Boot proxy
│   ├── TradernetAPIClient.swift   ← Tradernet
│   ├── DTOs/
│   │   ├── MarketDTOs.swift
│   │   └── TradernetDTOs.swift
│   └── APIError.swift
│
├── Service/                       ← Бизнес-логика
│   ├── PortfolioService.swift
│   ├── TransactionService.swift
│   ├── MarketDataService.swift    ← обёртка над репозиторием + PriceCache
│   ├── DepositsService.swift
│   ├── SubscriptionsService.swift
│   ├── DividendService.swift
│   ├── NetWorthService.swift
│   ├── KeychainService.swift
│   └── PortfolioCalculator.swift  ← pure functions, легко тестировать
│
├── ViewModel/
│   ├── DashboardViewModel.swift
│   ├── PortfolioViewModel.swift
│   ├── TransactionsViewModel.swift
│   ├── DepositsViewModel.swift
│   ├── SubscriptionsViewModel.swift
│   ├── AnalyticsViewModel.swift
│   └── AuthViewModel.swift
│
├── View/
│   ├── Dashboard/
│   ├── Portfolio/
│   ├── Transactions/
│   ├── Deposits/
│   ├── Subscriptions/
│   ├── Analytics/
│   ├── Settings/
│   └── Shared/                    ← LandingCard, LoadingView, ErrorView...
│
└── Resources/
    └── Localizable.strings/
```

---

## 12. Checklist перед началом каждой фазы

- [ ] Все новые `@Model` добавлены в `ModelContainer` в App
- [ ] Для каждого репозитория есть протокол + SwiftData + InMemory реализации
- [ ] ViewModels получают сервисы через `DIContainer`, не создают сами
- [ ] Сервисы принимают протоколы репозиториев, не конкретные классы
- [ ] Новые DTO структуры помечены `Sendable`
- [ ] Preview-контейнер использует `InMemory` реализации
