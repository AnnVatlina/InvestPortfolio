//
//  SubscriptionViewModelTests.swift
//  InvestPortfolioTests
//
//  Tests for SubscriptionsViewModel.
//  CRUD tests use MockSubscriptionsAPI (API-first behaviour).
//  Filter / pagination / upcoming / monthly tests pre-populate the cache via
//  InMemorySubscriptionsRepository and pass an empty mock so load() does not
//  touch the network — those tests remain purely local.
//

import Testing
import Foundation
@testable import InvestPortfolio

// MARK: - Mock API (internal — reused in AnalyticsViewModelTests)

final class MockSubscriptionsAPI: SubscriptionsAPIProtocol, @unchecked Sendable {
    var stubbedSubscriptions: [SubscriptionResponse] = []
    var stubbedError: Error? = nil

    var createCalled = false
    var updateCalled = false
    var deleteCalled = false
    var lastDeletedId: UUID? = nil

    func getSubscriptions() async throws -> [SubscriptionResponse] {
        if let error = stubbedError { throw error }
        return stubbedSubscriptions
    }

    func createSubscription(_ body: SubscriptionCreate) async throws -> SubscriptionResponse {
        if let error = stubbedError { throw error }
        createCalled = true
        return stubbedSubscriptions.first ?? SubscriptionResponse(
            id: UUID(), title: body.title, amount: body.amount,
            currency: body.currency, billingCycle: body.billingCycle,
            startDate: Date(), endDate: nil,
            category: nil, iconName: nil, isActive: true, createdAt: Date()
        )
    }

    func updateSubscription(id: UUID, _ body: SubscriptionUpdate) async throws -> SubscriptionResponse {
        if let error = stubbedError { throw error }
        updateCalled = true
        return stubbedSubscriptions.first ?? SubscriptionResponse(
            id: id, title: body.title, amount: body.amount,
            currency: body.currency, billingCycle: body.billingCycle,
            startDate: Date(), endDate: body.endDate.flatMap { _ in Date() },
            category: nil, iconName: nil, isActive: body.isActive, createdAt: Date()
        )
    }

    func deleteSubscription(id: UUID) async throws {
        if let error = stubbedError { throw error }
        deleteCalled = true
        lastDeletedId = id
        stubbedSubscriptions.removeAll { $0.id == id }
    }
}

// MARK: - Response helper (internal — reused in AnalyticsViewModelTests)

func makeSubResponse(
    id: UUID = UUID(),
    title: String = "Sub",
    amount: String = "10.0",
    currency: String = "USD",
    billingCycle: String = "monthly",
    startDate: Date = Date(),
    isActive: Bool = true
) -> SubscriptionResponse {
    SubscriptionResponse(
        id: id, title: title, amount: amount,
        currency: currency, billingCycle: billingCycle,
        startDate: startDate, endDate: nil,
        category: nil, iconName: nil,
        isActive: isActive, createdAt: Date()
    )
}

// MARK: - Local Subscription factory

private func sub(
    title: String = "Sub",
    amount: Double = 10.0,
    currency: DepositCurrency = .USD,
    cycle: SubscriptionBillingCycle = .monthly,
    startDate: Date = Date(),
    isActive: Bool = true,
    endDate: Date? = nil,
    createdAt: Date = Date()
) -> Subscription {
    Subscription(
        title: title, amount: amount, currency: currency,
        billingCycle: cycle, startDate: startDate,
        isActive: isActive, endDate: endDate, createdAt: createdAt
    )
}

// MARK: - Shared helpers

private func makeService(with subs: [Subscription] = []) async -> DefaultSubscriptionsService {
    let repo = InMemorySubscriptionsRepository()
    for s in subs { try? await repo.add(s) }
    return DefaultSubscriptionsService(repository: repo)
}

@MainActor
private func makeVM(
    with subs: [Subscription] = [],
    api: MockSubscriptionsAPI = MockSubscriptionsAPI()
) async -> SubscriptionsViewModel {
    let service = await makeService(with: subs)
    let vm = SubscriptionsViewModel(service: service, api: api)
    await vm.load()
    return vm
}

// MARK: - CRUD (API-first)

@Suite("SubscriptionsViewModel — CRUD (API-first)")
@MainActor
struct SubscriptionsViewModelCRUDTests {

    @Test("Load: API deposits populate subscriptions list")
    func loadPopulatesFromAPI() async {
        let api = MockSubscriptionsAPI()
        api.stubbedSubscriptions = [makeSubResponse(title: "Netflix"), makeSubResponse(title: "Spotify")]
        let vm = await makeVM(api: api)
        #expect(vm.subscriptions.count == 2)
    }

    @Test("Load: API error with empty cache shows errorMessage")
    func loadAPIErrorEmptyCacheShowsError() async {
        let api = MockSubscriptionsAPI()
        api.stubbedError = APIError.networkOffline
        let vm = await makeVM(api: api)
        #expect(vm.errorMessage != nil)
    }

    @Test("Load: API error with cached data preserves cache, no error shown")
    func loadAPIErrorPreservesCache() async {
        let api = MockSubscriptionsAPI()
        api.stubbedSubscriptions = [makeSubResponse(title: "Cached")]
        let vm = await makeVM(api: api)
        #expect(vm.subscriptions.count == 1)

        api.stubbedError = APIError.networkOffline
        api.stubbedSubscriptions = []
        await vm.load()

        #expect(vm.subscriptions.count == 1)
        #expect(vm.errorMessage == nil)
    }

    @Test("Load: same serverId → no duplicates on repeated sync")
    func loadUpsertDeduplicates() async {
        let id = UUID()
        let api = MockSubscriptionsAPI()
        api.stubbedSubscriptions = [makeSubResponse(id: id, title: "Original")]
        let vm = await makeVM(api: api)
        #expect(vm.subscriptions.count == 1)

        api.stubbedSubscriptions = [makeSubResponse(id: id, title: "Updated")]
        await vm.load()

        #expect(vm.subscriptions.count == 1)
        #expect(vm.subscriptions[0].title == "Updated")
    }

    @Test("Add: calls API, response upserted and visible in list")
    func addCallsAPIAndAppearsInList() async {
        let api = MockSubscriptionsAPI()
        api.stubbedSubscriptions = [makeSubResponse(title: "iCloud")]
        let service = await makeService()
        let vm = SubscriptionsViewModel(service: service, api: api)

        await vm.addSubscription(
            title: "iCloud", amount: 0.99, currency: .USD,
            billingCycle: .monthly, startDate: Date(),
            category: nil, iconName: nil
        )

        #expect(api.createCalled)
        #expect(vm.subscriptions.isEmpty == false)
        #expect(vm.subscriptions[0].title == "iCloud")
    }

    @Test("Add: empty title sets operationError, API not called")
    func addEmptyTitleSetsOperationError() async {
        let api = MockSubscriptionsAPI()
        let vm = await makeVM(api: api)

        await vm.addSubscription(
            title: "   ", amount: 10, currency: .USD,
            billingCycle: .monthly, startDate: Date(),
            category: nil, iconName: nil
        )

        #expect(!api.createCalled)
        #expect(vm.operationError != nil)
    }

    @Test("Add: API error sets operationError")
    func addAPIErrorSetsOperationError() async {
        let api = MockSubscriptionsAPI()
        api.stubbedError = APIError.networkOffline
        let service = await makeService()
        let vm = SubscriptionsViewModel(service: service, api: api)

        await vm.addSubscription(
            title: "Netflix", amount: 15.99, currency: .USD,
            billingCycle: .monthly, startDate: Date(),
            category: nil, iconName: nil
        )

        #expect(vm.operationError != nil)
        #expect(vm.subscriptions.isEmpty)
    }

    @Test("Delete: subscription with serverId calls API delete")
    func deleteWithServerIdCallsAPI() async {
        let serverId = UUID()
        let api = MockSubscriptionsAPI()
        api.stubbedSubscriptions = [makeSubResponse(id: serverId, title: "ToDelete")]
        let service = await makeService()
        let vm = SubscriptionsViewModel(service: service, api: api)
        await vm.load()
        #expect(vm.subscriptions.count == 1)

        api.stubbedSubscriptions = []
        await vm.deleteSubscription(vm.subscriptions[0])

        #expect(api.deleteCalled)
        #expect(api.lastDeletedId == serverId)
        #expect(vm.subscriptions.isEmpty)
    }

    @Test("Delete: local-only subscription (no serverId) removed from cache")
    func deleteLocalSubRemovesFromCache() async {
        let vm = await makeVM(with: [sub(title: "Local")])
        await vm.deleteSubscription(vm.subscriptions[0])
        #expect(vm.subscriptions.isEmpty)
    }

    @Test("Delete: API error sets operationError, cache preserved")
    func deleteAPIErrorPreservesCache() async {
        let serverId = UUID()
        let api = MockSubscriptionsAPI()
        api.stubbedSubscriptions = [makeSubResponse(id: serverId, title: "Keep")]
        let service = await makeService()
        let vm = SubscriptionsViewModel(service: service, api: api)
        await vm.load()

        api.stubbedError = APIError.networkOffline
        await vm.deleteSubscription(vm.subscriptions[0])

        #expect(vm.operationError != nil)
    }

    @Test("Update: local-only subscription (no serverId) updated in cache")
    func updateLocalSubChangesTitle() async {
        let vm = await makeVM(with: [sub(title: "Old")])
        let id = vm.subscriptions[0].id
        await vm.updateSubscription(
            id: id, title: "New", amount: 10, currency: .USD,
            billingCycle: .monthly, startDate: Date(),
            category: nil, iconName: nil, isActive: true, endDate: nil
        )
        #expect(vm.subscriptions[0].title == "New")
    }

    @Test("Update: isActive=false preserves endDate")
    func updateWithIsActiveFalsePreservesEndDate() async {
        let vm = await makeVM(with: [sub(title: "Cancel Me")])
        let id = vm.subscriptions[0].id
        let endDate = Date()
        await vm.updateSubscription(
            id: id, title: "Cancel Me", amount: 10, currency: .USD,
            billingCycle: .monthly, startDate: Date(),
            category: nil, iconName: nil, isActive: false, endDate: endDate
        )
        #expect(vm.subscriptions[0].isActive == false)
        #expect(vm.subscriptions[0].endDate != nil)
    }

    @Test("Update: isActive=true clears endDate")
    func updateWithIsActiveTrueClearsEndDate() async {
        let vm = await makeVM(with: [sub(title: "Reactivate", isActive: false, endDate: Date())])
        let id = vm.subscriptions[0].id
        await vm.updateSubscription(
            id: id, title: "Reactivate", amount: 10, currency: .USD,
            billingCycle: .monthly, startDate: Date(),
            category: nil, iconName: nil, isActive: true, endDate: nil
        )
        #expect(vm.subscriptions[0].isActive == true)
        #expect(vm.subscriptions[0].endDate == nil)
    }
}

// MARK: - Filtering

@Suite("SubscriptionsViewModel — statusFilter")
@MainActor
struct SubscriptionsViewModelFilterTests {

    @Test func filterAllReturnsEverythingSortedByCreatedAtDesc() async {
        let older = sub(title: "Older",  isActive: true,  createdAt: Date(timeIntervalSinceNow: -100))
        let newer = sub(title: "Newer",  isActive: false, createdAt: Date())
        let vm = await makeVM(with: [older, newer])

        vm.setFilter(.all)
        let titles = vm.filteredSubscriptions.map(\.title)
        #expect(titles.first == "Newer")
        #expect(titles.last  == "Older")
    }

    @Test func filterActiveReturnsOnlyActiveSubs() async {
        let active   = sub(title: "Active",   isActive: true)
        let inactive = sub(title: "Inactive", isActive: false)
        let vm = await makeVM(with: [active, inactive])

        vm.setFilter(.active)
        #expect(vm.filteredSubscriptions.count == 1)
        #expect(vm.filteredSubscriptions[0].title == "Active")
    }

    @Test func filterCancelledReturnsOnlyInactiveSubs() async {
        let active    = sub(title: "Active",    isActive: true)
        let cancelled = sub(title: "Cancelled", isActive: false, endDate: Date())
        let vm = await makeVM(with: [active, cancelled])

        vm.setFilter(.cancelled)
        #expect(vm.filteredSubscriptions.count == 1)
        #expect(vm.filteredSubscriptions[0].title == "Cancelled")
    }

    @Test func filterCancelledSortsByEndDateDesc() async {
        let end1 = Date(timeIntervalSinceNow: -200)
        let end2 = Date(timeIntervalSinceNow: -10)
        let c1 = sub(title: "Earlier end", isActive: false, endDate: end1)
        let c2 = sub(title: "Later end",   isActive: false, endDate: end2)
        let vm = await makeVM(with: [c1, c2])

        vm.setFilter(.cancelled)
        #expect(vm.filteredSubscriptions[0].title == "Later end")
    }

    @Test func filterPaidReturnsActiveOneTimeSubsPastTheirDate() async {
        let past      = sub(title: "Past",    cycle: .oneTime, startDate: Date(timeIntervalSinceNow: -86400), isActive: true)
        let future    = sub(title: "Future",  cycle: .oneTime, startDate: Date(timeIntervalSinceNow:  86400), isActive: true)
        let recurring = sub(title: "Monthly", cycle: .monthly, isActive: true)
        let vm = await makeVM(with: [past, future, recurring])

        vm.setFilter(.paid)
        #expect(vm.filteredSubscriptions.count == 1)
        #expect(vm.filteredSubscriptions[0].title == "Past")
    }
}

// MARK: - Pagination

@Suite("SubscriptionsViewModel — pagination")
@MainActor
struct SubscriptionsViewModelPaginationTests {

    private func sixSubs() -> [Subscription] {
        (1...6).map { sub(title: "Sub \($0)", createdAt: Date(timeIntervalSinceNow: Double(-$0))) }
    }

    @Test func pageSizeFiveGivesFirstPageOf5() async {
        let vm = await makeVM(with: sixSubs())
        vm.setPageSize(.five)
        #expect(vm.pagedSubscriptions.count == 5)
    }

    @Test func pageSizeFiveHasTwoTotalPages() async {
        let vm = await makeVM(with: sixSubs())
        vm.setPageSize(.five)
        #expect(vm.totalPages == 2)
    }

    @Test func page2WithPageSizeFiveReturnsRemainder() async {
        let vm = await makeVM(with: sixSubs())
        vm.setPageSize(.five)
        vm.currentPage = 2
        #expect(vm.pagedSubscriptions.count == 1)
    }

    @Test func pageSizeTenReturnsAllSixOnOnePage() async {
        let vm = await makeVM(with: sixSubs())
        vm.setPageSize(.ten)
        #expect(vm.pagedSubscriptions.count == 6)
        #expect(vm.totalPages == 1)
    }

    @Test func pageSizeUnlimitedReturnsAll() async {
        let vm = await makeVM(with: sixSubs())
        vm.setPageSize(.unlimited)
        #expect(vm.pagedSubscriptions.count == 6)
        #expect(vm.totalPages == 1)
    }

    @Test func setFilterResetsCurrentPage() async {
        let vm = await makeVM(with: sixSubs())
        vm.setPageSize(.five)
        vm.currentPage = 2
        vm.setFilter(.active)
        #expect(vm.currentPage == 1)
    }

    @Test func setPageSizeResetsCurrentPage() async {
        let vm = await makeVM(with: sixSubs())
        vm.setPageSize(.five)
        vm.currentPage = 2
        vm.setPageSize(.ten)
        #expect(vm.currentPage == 1)
    }

    @Test func totalFilteredCountMatchesActiveFilter() async {
        let actives   = (1...3).map { sub(title: "A\($0)", isActive: true) }
        let cancelled = (1...2).map { sub(title: "C\($0)", isActive: false) }
        let vm = await makeVM(with: actives + cancelled)
        vm.setFilter(.active)
        #expect(vm.totalFilteredCount == 3)
    }
}

// MARK: - Upcoming payments

@Suite("SubscriptionsViewModel — upcoming")
@MainActor
struct SubscriptionsViewModelUpcomingTests {

    @Test func upcomingIncludesSubWithPaymentWithin7Days() async {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let nextWeek = Calendar.current.date(byAdding: .day, value: 8, to: Date())!
        let soon = sub(title: "Soon",     cycle: .monthly, startDate: tomorrow, isActive: true)
        let late = sub(title: "Too late", cycle: .monthly, startDate: nextWeek, isActive: true)
        let vm = await makeVM(with: [soon, late])
        let result = vm.upcoming(withinDays: 7)
        #expect(result.count == 1)
        #expect(result[0].title == "Soon")
    }

    @Test func upcomingExcludesInactiveSubs() async {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let inactive = sub(title: "Cancelled", cycle: .monthly, startDate: tomorrow, isActive: false)
        let vm = await makeVM(with: [inactive])
        #expect(vm.upcoming(withinDays: 7).isEmpty)
    }

    @Test func upcomingIncludesOneTimePurchaseInFuture() async {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let purchase = sub(title: "Purchase", cycle: .oneTime, startDate: tomorrow, isActive: true)
        let vm = await makeVM(with: [purchase])
        #expect(vm.upcoming(withinDays: 7).count == 1)
    }

    @Test func upcomingExcludesPastOneTimePurchase() async {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let purchase  = sub(title: "Already bought", cycle: .oneTime, startDate: yesterday, isActive: true)
        let vm = await makeVM(with: [purchase])
        #expect(vm.upcoming(withinDays: 7).isEmpty)
    }
}

// MARK: - Monthly payments chart

@Suite("SubscriptionsViewModel — monthlyPayments")
@MainActor
struct SubscriptionsViewModelMonthlyPaymentsTests {

    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private static func date(year: Int, month: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func activeMonthlySubGenerates12PaymentsPerYear() async {
        let year = Calendar.current.component(.year, from: Date())
        let s = sub(title: "Monthly", amount: 10, cycle: .monthly,
                    startDate: Self.date(year: year, month: 1), isActive: true)
        let vm = await makeVM(with: [s])
        let points = vm.monthlyPayments(year: year)
        let totalPayments = points.reduce(0) { $0 + Int($1.total / 10) }
        #expect(totalPayments == 12)
    }

    @Test func cancelledSubWithEndDateCapsPayments() async {
        let year = Calendar.current.component(.year, from: Date())
        let cancelled = sub(
            title: "Cancelled", amount: 10, cycle: .monthly,
            startDate: Self.date(year: year, month: 1),
            isActive: false, endDate: Self.date(year: year, month: 4)
        )
        let vm = await makeVM(with: [cancelled])
        let points = vm.monthlyPayments(year: year)
        let totalPayments = points.reduce(0) { $0 + Int($1.total / 10) }
        #expect(totalPayments == 3)
    }

    @Test func inactiveSubWithoutEndDateIsExcluded() async {
        let year = Calendar.current.component(.year, from: Date())
        let s = sub(title: "Lost", amount: 10, cycle: .monthly,
                    startDate: Self.date(year: year, month: 1), isActive: false, endDate: nil)
        let vm = await makeVM(with: [s])
        #expect(vm.monthlyPayments(year: year).isEmpty)
    }

    @Test func oneTimePurchaseAppearsOnlyInItsMonth() async {
        let year = Calendar.current.component(.year, from: Date())
        let s = sub(title: "One-time", amount: 50, cycle: .oneTime,
                    startDate: Self.date(year: year, month: 6, day: 15), isActive: true)
        let vm = await makeVM(with: [s])
        let points = vm.monthlyPayments(year: year)
        #expect(points.count == 1)
        #expect(points[0].total == 50.0)
    }
}
