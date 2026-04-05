//
//  SubscriptionViewModelTests.swift
//  InvestPortfolioTests
//
//  Integration tests for SubscriptionsViewModel.
//  Each test uses a real DefaultSubscriptionsService backed by an InMemory repository,
//  exercising the full subscription stack: ViewModel → Service → Repository.
//

import Testing
@testable import InvestPortfolio

// MARK: - Helpers

private func makeService(with subs: [Subscription] = []) async -> DefaultSubscriptionsService {
    let repo = InMemorySubscriptionsRepository()
    for sub in subs { try? await repo.add(sub) }
    return DefaultSubscriptionsService(repository: repo)
}

@MainActor
private func makeVM(with subs: [Subscription] = []) async -> SubscriptionsViewModel {
    let service = await makeService(with: subs)
    let vm = SubscriptionsViewModel(service: service)
    await vm.load()
    return vm
}

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

// MARK: - Load & CRUD

@Suite("SubscriptionsViewModel — load & CRUD")
@MainActor
struct SubscriptionsViewModelCRUDTests {

    @Test func loadPopulatesSubscriptions() async {
        let vm = await makeVM(with: [sub(title: "Netflix"), sub(title: "Spotify")])
        #expect(vm.subscriptions.count == 2)
    }

    @Test func addSubscriptionAppearsInList() async {
        let vm = await makeVM()
        await vm.addSubscription(
            title: "iCloud", amount: 0.99, currency: .USD,
            billingCycle: .monthly, startDate: Date(),
            category: nil, iconName: nil
        )
        #expect(vm.subscriptions.count == 1)
        #expect(vm.subscriptions[0].title == "iCloud")
    }

    @Test func addSubscriptionWithEmptyTitleSetsError() async {
        let vm = await makeVM()
        await vm.addSubscription(
            title: "   ", amount: 10, currency: .USD,
            billingCycle: .monthly, startDate: Date(),
            category: nil, iconName: nil
        )
        #expect(vm.subscriptions.isEmpty)
        #expect(vm.errorMessage != nil)
    }

    @Test func deleteSubscriptionRemovesFromList() async {
        let s = sub(title: "ToDelete")
        let vm = await makeVM(with: [s])
        await vm.deleteSubscription(vm.subscriptions[0])
        #expect(vm.subscriptions.isEmpty)
    }

    @Test func updateSubscriptionChangesTitle() async {
        let s = sub(title: "Old")
        let vm = await makeVM(with: [s])
        let id = vm.subscriptions[0].id
        await vm.updateSubscription(
            id: id, title: "New", amount: 10, currency: .USD,
            billingCycle: .monthly, startDate: Date(),
            category: nil, iconName: nil, isActive: true, endDate: nil
        )
        #expect(vm.subscriptions[0].title == "New")
    }

    @Test func updateSubscriptionWithIsActiveFalsePreservesEndDate() async {
        let s = sub(title: "Cancel Me")
        let vm = await makeVM(with: [s])
        let id = vm.subscriptions[0].id
        let endDate = Date()
        await vm.updateSubscription(
            id: id, title: s.title, amount: s.amount, currency: s.currency,
            billingCycle: s.billingCycle, startDate: s.startDate,
            category: nil, iconName: nil, isActive: false, endDate: endDate
        )
        #expect(vm.subscriptions[0].isActive == false)
        #expect(vm.subscriptions[0].endDate != nil)
    }

    @Test func updateSubscriptionWithIsActiveTrueClearsEndDate() async {
        let s = sub(title: "Reactivate", isActive: false, endDate: Date())
        let vm = await makeVM(with: [s])
        let id = vm.subscriptions[0].id
        await vm.updateSubscription(
            id: id, title: s.title, amount: s.amount, currency: s.currency,
            billingCycle: s.billingCycle, startDate: s.startDate,
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
        let older  = sub(title: "Older",  isActive: true,  createdAt: Date(timeIntervalSinceNow: -100))
        let newer  = sub(title: "Newer",  isActive: false, createdAt: Date())
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
        let past   = sub(title: "Past purchase",   cycle: .oneTime,  startDate: Date(timeIntervalSinceNow: -86400), isActive: true)
        let future = sub(title: "Future purchase",  cycle: .oneTime,  startDate: Date(timeIntervalSinceNow:  86400), isActive: true)
        let recurring = sub(title: "Recurring",    cycle: .monthly,  isActive: true)
        let vm = await makeVM(with: [past, future, recurring])

        vm.setFilter(.paid)
        #expect(vm.filteredSubscriptions.count == 1)
        #expect(vm.filteredSubscriptions[0].title == "Past purchase")
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

    @Test func upcomingIncludesSubWithPaymentTodayOrWithin7Days() async {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let nextWeek = Calendar.current.date(byAdding: .day, value: 8, to: Date())!

        let soon = sub(title: "Soon",     startDate: tomorrow, cycle: .monthly, isActive: true)
        let late = sub(title: "Too late", startDate: nextWeek, cycle: .monthly, isActive: true)
        let vm = await makeVM(with: [soon, late])

        let result = vm.upcoming(withinDays: 7)
        #expect(result.count == 1)
        #expect(result[0].title == "Soon")
    }

    @Test func upcomingExcludesInactiveSubs() async {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let inactive = sub(title: "Cancelled", startDate: tomorrow, cycle: .monthly, isActive: false)
        let vm = await makeVM(with: [inactive])
        #expect(vm.upcoming(withinDays: 7).isEmpty)
    }

    @Test func upcomingIncludesOneTimePurchaseInFuture() async {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let purchase = sub(title: "Purchase", startDate: tomorrow, cycle: .oneTime, isActive: true)
        let vm = await makeVM(with: [purchase])
        #expect(vm.upcoming(withinDays: 7).count == 1)
    }

    @Test func upcomingExcludesPastOneTimePurchase() async {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let purchase = sub(title: "Already bought", startDate: yesterday, cycle: .oneTime, isActive: true)
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
        let startDate = Self.date(year: year, month: 1)
        let s = sub(title: "Monthly", amount: 10, cycle: .monthly, startDate: startDate, isActive: true)
        let vm = await makeVM(with: [s])

        let points = vm.monthlyPayments(year: year)
        // One point per month = 12 entries for a full-year monthly sub
        let totalPayments = points.reduce(0) { $0 + Int($1.total / 10) }
        #expect(totalPayments == 12)
    }

    @Test func cancelledSubWithEndDateCapsPayments() async {
        let year = Calendar.current.component(.year, from: Date())
        let startDate = Self.date(year: year, month: 1)
        let endDate   = Self.date(year: year, month: 4)  // cancelled in April → pays Jan, Feb, Mar only

        let cancelled = sub(
            title: "Cancelled", amount: 10, cycle: .monthly,
            startDate: startDate, isActive: false, endDate: endDate
        )
        let vm = await makeVM(with: [cancelled])

        let points = vm.monthlyPayments(year: year)
        let totalPayments = points.reduce(0) { $0 + Int($1.total / 10) }
        #expect(totalPayments == 3)  // Jan, Feb, Mar only
    }

    @Test func inactiveSubWithoutEndDateIsExcluded() async {
        let year = Calendar.current.component(.year, from: Date())
        let s = sub(
            title: "Lost sub", amount: 10, cycle: .monthly,
            startDate: Self.date(year: year, month: 1),
            isActive: false, endDate: nil
        )
        let vm = await makeVM(with: [s])
        let points = vm.monthlyPayments(year: year)
        #expect(points.isEmpty)
    }

    @Test func oneTimePurchaseAppearsOnlyInItsMonth() async {
        let year = Calendar.current.component(.year, from: Date())
        let purchaseDate = Self.date(year: year, month: 6, day: 15)
        let s = sub(title: "One-time", amount: 50, cycle: .oneTime,
                    startDate: purchaseDate, isActive: true)
        let vm = await makeVM(with: [s])

        let points = vm.monthlyPayments(year: year)
        #expect(points.count == 1)
        #expect(points[0].total == 50.0)
    }
}
