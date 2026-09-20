//
//  HomeViewModelTests.swift
//  InvestPortfolioTests
//
//  Tests for HomeViewModel — open deposits ordering and nearest upcoming payments.
//

import Testing
import Foundation
@testable import InvestPortfolio

// MARK: - Helpers

@MainActor
private func makeVM(
    deposits: [Deposit] = [],
    subscriptions: [Subscription] = []
) async -> HomeViewModel {
    let depRepo = InMemoryDepositsRepository()
    for d in deposits { try? await depRepo.add(d) }
    let subRepo = InMemorySubscriptionsRepository()
    for s in subscriptions { try? await subRepo.add(s) }
    let vm = HomeViewModel(
        depositsService: DefaultDepositsService(repository: depRepo),
        subscriptionsService: DefaultSubscriptionsService(repository: subRepo)
    )
    await vm.load()
    return vm
}

private func dep(
    title: String = "Deposit",
    amount: Double = 100_000,
    currency: DepositCurrency = .RUB,
    openDate: Date = Date(),
    closeDate: Date? = nil,
    rate: Double = 10.0
) -> Deposit {
    Deposit(title: title, amount: amount, currency: currency,
            openDate: openDate, closeDate: closeDate, annualInterestRate: rate)
}

private func sub(
    title: String = "Sub",
    amount: Double = 9.99,
    currency: DepositCurrency = .USD,
    cycle: SubscriptionBillingCycle = .monthly,
    startDate: Date = Date(),
    isActive: Bool = true,
    endDate: Date? = nil
) -> Subscription {
    Subscription(title: title, amount: amount, currency: currency, billingCycle: cycle,
                 startDate: startDate, isActive: isActive, endDate: endDate)
}

private func daysFromNow(_ days: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: days, to: Date())!
}

// MARK: - Load

@Suite("HomeViewModel — load")
@MainActor
struct HomeViewModelLoadTests {

    @Test("Empty store → no data, no error")
    func loadEmpty() async {
        let vm = await makeVM()
        #expect(vm.deposits.isEmpty)
        #expect(vm.subscriptions.isEmpty)
        #expect(vm.errorMessage == nil)
    }

    @Test("Seeded store → both collections populated")
    func loadPopulates() async {
        let vm = await makeVM(deposits: [dep(), dep()], subscriptions: [sub()])
        #expect(vm.deposits.count == 2)
        #expect(vm.subscriptions.count == 1)
    }
}

// MARK: - Open deposits

@Suite("HomeViewModel — openDeposits")
@MainActor
struct HomeViewModelOpenDepositsTests {

    @Test("Closed deposits are excluded")
    func closedDepositsExcluded() async {
        let vm = await makeVM(deposits: [
            dep(title: "Open", closeDate: daysFromNow(30)),
            dep(title: "Closed", openDate: daysFromNow(-400), closeDate: daysFromNow(-10))
        ])
        #expect(vm.openDeposits.map(\.title) == ["Open"])
    }

    @Test("Sorted by close date, soonest first")
    func sortedBySoonestClose() async {
        let vm = await makeVM(deposits: [
            dep(title: "Later", closeDate: daysFromNow(90)),
            dep(title: "Sooner", closeDate: daysFromNow(5))
        ])
        #expect(vm.openDeposits.map(\.title) == ["Sooner", "Later"])
    }

    @Test("Deposits with no end date sort last")
    func noEndDateSortsLast() async {
        let vm = await makeVM(deposits: [
            dep(title: "NoEnd", closeDate: nil),
            dep(title: "HasEnd", closeDate: daysFromNow(30))
        ])
        #expect(vm.openDeposits.map(\.title) == ["HasEnd", "NoEnd"])
    }

    @Test("No deposits → empty list")
    func emptyWhenNoDeposits() async {
        let vm = await makeVM()
        #expect(vm.openDeposits.isEmpty)
    }
}

// MARK: - Upcoming subscriptions

@Suite("HomeViewModel — upcomingSubscriptions")
@MainActor
struct HomeViewModelUpcomingSubscriptionsTests {

    @Test("Sorted by nearest due date first")
    func sortedByDueDate() async {
        // Future start dates make nextPaymentDate == startDate exactly (no cycle
        // math to reason about), so the ordering only tests the sort itself.
        let vm = await makeVM(subscriptions: [
            sub(title: "Later", cycle: .monthly, startDate: daysFromNow(20)),
            sub(title: "Sooner", cycle: .monthly, startDate: daysFromNow(3))
        ])
        let titles = vm.upcomingSubscriptions().map(\.title)
        #expect(titles.first == "Sooner")
    }

    @Test("Subscription due earlier today is still upcoming, not stale")
    func dueEarlierTodayIsStillUpcoming() async {
        // nextPaymentDate for a subscription due today normalizes to today's midnight.
        // Comparing against the exact current instant (rather than start-of-day) would
        // wrongly drop it the moment any time passes after midnight — this is exactly the
        // scenario a test run any time after 00:00 exercises.
        let todayMidnight = Calendar.current.startOfDay(for: Date())
        let vm = await makeVM(subscriptions: [
            sub(title: "DueToday", cycle: .monthly, startDate: todayMidnight)
        ])
        #expect(vm.upcomingSubscriptions().map(\.title) == ["DueToday"])
    }

    @Test("Respects the limit parameter")
    func respectsLimit() async {
        let subs = (0..<10).map { sub(title: "Sub\($0)", cycle: .monthly, startDate: daysFromNow(-1)) }
        let vm = await makeVM(subscriptions: subs)
        #expect(vm.upcomingSubscriptions(limit: 5).count == 5)
        #expect(vm.upcomingSubscriptions(limit: 3).count == 3)
    }

    @Test("Inactive subscriptions are excluded")
    func inactiveExcluded() async {
        let vm = await makeVM(subscriptions: [
            sub(title: "Active", cycle: .monthly, startDate: daysFromNow(-1)),
            sub(title: "Cancelled", cycle: .monthly, startDate: daysFromNow(-1), isActive: false, endDate: daysFromNow(-1))
        ])
        #expect(vm.upcomingSubscriptions().map(\.title) == ["Active"])
    }

    @Test("Past one-time purchases are not upcoming")
    func pastOneTimeExcluded() async {
        let vm = await makeVM(subscriptions: [
            sub(title: "PastPurchase", cycle: .oneTime, startDate: daysFromNow(-30))
        ])
        #expect(vm.upcomingSubscriptions().isEmpty)
    }

    @Test("Future one-time purchase is upcoming")
    func futureOneTimeIncluded() async {
        let vm = await makeVM(subscriptions: [
            sub(title: "FuturePurchase", cycle: .oneTime, startDate: daysFromNow(5))
        ])
        #expect(vm.upcomingSubscriptions().map(\.title) == ["FuturePurchase"])
    }

    @Test("No subscriptions → empty list")
    func emptyWhenNoSubscriptions() async {
        let vm = await makeVM()
        #expect(vm.upcomingSubscriptions().isEmpty)
    }
}
