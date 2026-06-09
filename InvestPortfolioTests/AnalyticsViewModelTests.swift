//
//  AnalyticsViewModelTests.swift
//  InvestPortfolioTests
//
//  Tests for AnalyticsViewModel (Step 4 of Rentivo migration).
//  Verifies API-first sync behaviour and that analytics computations reflect
//  data fetched from both the deposits and subscriptions APIs.
//

import Testing
import Foundation
@testable import InvestPortfolio

// MARK: - Helpers

private func makeDepResponse(
    id: UUID = UUID(),
    title: String = "Deposit",
    amount: String = "100000",
    currency: String = "RUB",
    annualRate: String = "10.0",
    openDate: Date = Date(),
    closeDate: Date? = nil
) -> DepositResponse {
    DepositResponse(
        id: id, title: title, bankName: nil,
        amount: amount, currency: currency,
        openDate: openDate, closeDate: closeDate,
        annualRate: annualRate, interestType: nil,
        compoundFrequency: nil, incomeToDate: nil,
        daysElapsed: nil, createdAt: Date()
    )
}

@MainActor
private func makeVM(
    depositsAPI: MockDepositsAPI = MockDepositsAPI(),
    subsAPI: MockSubscriptionsAPI = MockSubscriptionsAPI()
) -> AnalyticsViewModel {
    AnalyticsViewModel(
        depositsService: DefaultDepositsService(repository: InMemoryDepositsRepository()),
        subscriptionsService: DefaultSubscriptionsService(repository: InMemorySubscriptionsRepository()),
        depositsAPI: depositsAPI,
        subscriptionsAPI: subsAPI
    )
}

// MARK: - Load / sync

@Suite("AnalyticsViewModel — API-first sync")
@MainActor
struct AnalyticsViewModelLoadTests {

    @Test("Deposits API data appears in vm.deposits after load")
    func loadSyncsDeposits() async {
        let api = MockDepositsAPI()
        api.stubbedDeposits = [makeDepResponse(title: "Savings"), makeDepResponse(title: "Term")]
        let vm = makeVM(depositsAPI: api)

        await vm.load()

        #expect(vm.deposits.count == 2)
        #expect(vm.errorMessage == nil)
    }

    @Test("Subscriptions API data appears in vm.subscriptions after load")
    func loadSyncsSubscriptions() async {
        let api = MockSubscriptionsAPI()
        api.stubbedSubscriptions = [
            makeSubResponse(title: "Netflix"),
            makeSubResponse(title: "Spotify")
        ]
        let vm = makeVM(subsAPI: api)

        await vm.load()

        #expect(vm.subscriptions.count == 2)
        #expect(vm.errorMessage == nil)
    }

    @Test("Both APIs are synced in a single load call")
    func loadSyncsBothAPIs() async {
        let depAPI = MockDepositsAPI()
        depAPI.stubbedDeposits = [makeDepResponse(title: "Bank")]
        let subAPI = MockSubscriptionsAPI()
        subAPI.stubbedSubscriptions = [makeSubResponse(title: "iCloud")]
        let vm = makeVM(depositsAPI: depAPI, subsAPI: subAPI)

        await vm.load()

        #expect(vm.deposits.count == 1)
        #expect(vm.subscriptions.count == 1)
    }

    @Test("Repeated load with same serverId → no duplicates in deposits")
    func upsertDeduplicatesDeposits() async {
        let id = UUID()
        let api = MockDepositsAPI()
        api.stubbedDeposits = [makeDepResponse(id: id, title: "Original")]
        let vm = makeVM(depositsAPI: api)
        await vm.load()
        #expect(vm.deposits.count == 1)

        api.stubbedDeposits = [makeDepResponse(id: id, title: "Updated")]
        await vm.load()

        #expect(vm.deposits.count == 1)
        #expect(vm.deposits[0].title == "Updated")
    }

    @Test("Repeated load with same serverId → no duplicates in subscriptions")
    func upsertDeduplicatesSubscriptions() async {
        let id = UUID()
        let api = MockSubscriptionsAPI()
        api.stubbedSubscriptions = [makeSubResponse(id: id, title: "Original")]
        let vm = makeVM(subsAPI: api)
        await vm.load()
        #expect(vm.subscriptions.count == 1)

        api.stubbedSubscriptions = [makeSubResponse(id: id, title: "Updated")]
        await vm.load()

        #expect(vm.subscriptions.count == 1)
        #expect(vm.subscriptions[0].title == "Updated")
    }

    @Test("Deposits API error with no cache → errorMessage shown")
    func depositAPIErrorEmptyCacheShowsError() async {
        let api = MockDepositsAPI()
        api.stubbedError = APIError.networkOffline
        let vm = makeVM(depositsAPI: api)

        await vm.load()

        #expect(vm.errorMessage != nil)
    }

    @Test("Subscriptions API starts failing after first success → deposits cache preserved, no error shown")
    func subsAPIErrorAfterSuccessPreservesDepositsCache() async {
        let depAPI = MockDepositsAPI()
        depAPI.stubbedDeposits = [makeDepResponse(title: "Savings")]
        let subAPI = MockSubscriptionsAPI()
        let vm = makeVM(depositsAPI: depAPI, subsAPI: subAPI)

        // First load: both APIs succeed → deposits cached
        await vm.load()
        #expect(vm.deposits.count == 1)

        // Now subscriptions API starts failing; deposits API still works
        subAPI.stubbedError = APIError.networkOffline
        await vm.load()

        // Cache is non-empty (deposits still there) → no global error
        #expect(vm.deposits.count == 1)
        #expect(vm.errorMessage == nil)
    }

    @Test("API error after successful load preserves cached data, no error shown")
    func apiErrorAfterSuccessfulLoadPreservesCache() async {
        let api = MockDepositsAPI()
        api.stubbedDeposits = [makeDepResponse(title: "Cached")]
        let vm = makeVM(depositsAPI: api)
        await vm.load()
        #expect(vm.deposits.count == 1)

        api.stubbedError = APIError.networkOffline
        api.stubbedDeposits = []
        await vm.load()

        #expect(vm.deposits.count == 1)
        #expect(vm.errorMessage == nil)
    }
}

// MARK: - Analytics computation

@Suite("AnalyticsViewModel — analytics computation")
@MainActor
struct AnalyticsViewModelComputationTests {

    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private static func date(year: Int, month: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test("activeCurrencies includes currency of synced deposit")
    func activeCurrenciesIncludeDepositCurrency() async {
        let year = Calendar.current.component(.year, from: Date())
        let openDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let api = MockDepositsAPI()
        api.stubbedDeposits = [makeDepResponse(currency: "USD", annualRate: "5.0", openDate: openDate)]
        let vm = makeVM(depositsAPI: api)
        vm.selectedYear = year

        await vm.load()

        let rawValues = vm.activeCurrencies.map { $0.rawValue }
        #expect(rawValues.contains("USD"))
    }

    @Test("activeCurrencies includes currency of synced subscription")
    func activeCurrenciesIncludeSubCurrency() async {
        let year = Calendar.current.component(.year, from: Date())
        let startDate = Self.date(year: year, month: 1)
        let api = MockSubscriptionsAPI()
        api.stubbedSubscriptions = [makeSubResponse(amount: "9.99", currency: "EUR",
                                                    billingCycle: "monthly", startDate: startDate)]
        let vm = makeVM(subsAPI: api)
        vm.selectedYear = year

        await vm.load()

        let rawValues = vm.activeCurrencies.map { $0.rawValue }
        #expect(rawValues.contains("EUR"))
    }

    @Test("Deposit with positive rate generates income > 0 for selected year")
    func depositIncomeIsPositive() async {
        let year = Calendar.current.component(.year, from: Date())
        let openDate = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        let api = MockDepositsAPI()
        api.stubbedDeposits = [makeDepResponse(
            amount: "100000", currency: "RUB",
            annualRate: "10.0", openDate: openDate
        )]
        let vm = makeVM(depositsAPI: api)
        vm.selectedYear = year

        await vm.load()

        #expect(vm.totalIncome(currency: .RUB) > 0)
    }

    @Test("Monthly subscription for full year generates 12 months of expenses")
    func monthlySubExpenseSpans12Months() async {
        let year = Calendar.current.component(.year, from: Date())
        let startDate = Self.date(year: year, month: 1)
        let api = MockSubscriptionsAPI()
        api.stubbedSubscriptions = [makeSubResponse(
            amount: "10.0", currency: "USD",
            billingCycle: "monthly", startDate: startDate
        )]
        let vm = makeVM(subsAPI: api)
        vm.selectedYear = year

        await vm.load()

        let points = vm.monthlyPoints(currency: .USD)
        let monthsWithExpense = points.filter { $0.expense > 0 }.count
        #expect(monthsWithExpense == 12)
    }

    @Test("yearRange lower bound includes deposit open year")
    func yearRangeCoversDepositOpenYear() async {
        let pastYear = Calendar.current.component(.year, from: Date()) - 3
        let openDate = Self.date(year: pastYear, month: 6)
        let api = MockDepositsAPI()
        api.stubbedDeposits = [makeDepResponse(openDate: openDate)]
        let vm = makeVM(depositsAPI: api)

        await vm.load()

        #expect(vm.yearRange.lowerBound <= pastYear)
    }

    @Test("netBalance equals income minus expenses for same currency")
    func netBalanceIsIncomMinusExpenses() async {
        let year = Calendar.current.component(.year, from: Date())
        let openDate = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        let startDate = Self.date(year: year, month: 1)

        let depAPI = MockDepositsAPI()
        depAPI.stubbedDeposits = [makeDepResponse(
            amount: "100000", currency: "RUB",
            annualRate: "10.0", openDate: openDate
        )]
        // No subscriptions in RUB
        let vm = makeVM(depositsAPI: depAPI)
        vm.selectedYear = year

        await vm.load()

        let income   = vm.totalIncome(currency: .RUB)
        let expenses = vm.totalExpenses(currency: .RUB)
        #expect(vm.netBalance(currency: .RUB) == income - expenses)
    }
}
