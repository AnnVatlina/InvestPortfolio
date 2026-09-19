//
//  DashboardViewModelTests.swift
//  InvestPortfolioTests
//
//  Tests for DashboardViewModel — net worth aggregation, allocation and upcoming events.
//

import Testing
import Foundation
@testable import InvestPortfolio

// MARK: - Helpers

@MainActor
private func makeVM(
    deposits: [Deposit] = [],
    subscriptions: [Subscription] = []
) async -> DashboardViewModel {
    let depRepo = InMemoryDepositsRepository()
    for d in deposits { try? await depRepo.add(d) }
    let subRepo = InMemorySubscriptionsRepository()
    for s in subscriptions { try? await subRepo.add(s) }
    let vm = DashboardViewModel(
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
    rate: Double = 0
) -> Deposit {
    Deposit(title: title, amount: amount, currency: currency,
            openDate: openDate, closeDate: closeDate, annualInterestRate: rate)
}

private func sub(
    title: String = "Sub",
    amount: Double = 10,
    currency: DepositCurrency = .USD,
    cycle: SubscriptionBillingCycle = .monthly,
    startDate: Date = Date(),
    isActive: Bool = true,
    endDate: Date? = nil
) -> Subscription {
    Subscription(title: title, amount: amount, currency: currency,
                 billingCycle: cycle, startDate: startDate,
                 isActive: isActive, endDate: endDate)
}

private func daysFromNow(_ days: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: days, to: Date())!
}

/// Rate-complete converter for the currencies these tests use.
private let fullConverter = CurrencyConverter(base: .RUB, rates: [.USD: 90, .EUR: 100, .GEL: 33])

// MARK: - Load

@Suite("DashboardViewModel — load")
@MainActor
struct DashboardViewModelLoadTests {

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

    @Test("Empty store → net worth is zero and complete")
    func emptyNetWorthIsZero() async {
        let vm = await makeVM()
        let result = vm.netWorth(using: fullConverter)
        #expect(result.value == 0)
        #expect(result.isComplete)
    }
}

// MARK: - Totals

@Suite("DashboardViewModel — totals")
@MainActor
struct DashboardViewModelTotalsTests {

    @Test("Principal counts only deposits that have not closed")
    func principalExcludesClosed() async {
        let vm = await makeVM(deposits: [
            dep(title: "Open", amount: 100_000, closeDate: daysFromNow(30)),
            dep(title: "NoEnd", amount: 50_000, closeDate: nil),
            dep(title: "Closed", amount: 999_999, openDate: daysFromNow(-400), closeDate: daysFromNow(-10))
        ])
        let result = vm.depositsPrincipal(using: fullConverter)
        #expect(abs(result.value - 150_000) < 0.001)
        #expect(result.isComplete)
    }

    @Test("Principal converts foreign currencies into the base")
    func principalConverts() async {
        let vm = await makeVM(deposits: [
            dep(amount: 100_000, currency: .RUB),
            dep(amount: 1_000, currency: .USD)     // × 90 = 90_000
        ])
        let result = vm.depositsPrincipal(using: fullConverter)
        #expect(abs(result.value - 190_000) < 0.001)
    }

    @Test("Annual subscription cost normalizes billing cycles and converts")
    func annualSubscriptionCost() async {
        let vm = await makeVM(subscriptions: [
            sub(amount: 10, currency: .USD, cycle: .monthly),   // 120 USD/yr → 10_800 RUB
            sub(amount: 100, currency: .USD, cycle: .yearly)    // 100 USD/yr →  9_000 RUB
        ])
        let result = vm.annualSubscriptionCost(using: fullConverter)
        #expect(abs(result.value - 19_800) < 0.001)
        #expect(result.isComplete)
    }

    @Test("Inactive subscriptions are excluded from the annual cost")
    func inactiveSubscriptionsExcluded() async {
        let vm = await makeVM(subscriptions: [
            sub(amount: 10, currency: .USD, cycle: .monthly, isActive: true),
            sub(amount: 999, currency: .USD, cycle: .monthly, isActive: false, endDate: daysFromNow(-5))
        ])
        let result = vm.annualSubscriptionCost(using: fullConverter)
        #expect(abs(result.value - 10_800) < 0.001)
    }

    @Test("Net worth is principal plus accrued interest minus a year of subscriptions")
    func netWorthCombines() async {
        let vm = await makeVM(
            deposits: [dep(amount: 100_000, currency: .RUB, rate: 0)],
            subscriptions: [sub(amount: 10, currency: .USD, cycle: .monthly)]
        )
        // 100_000 principal + 0 interest − 10_800 subscriptions
        let result = vm.netWorth(using: fullConverter)
        #expect(abs(result.value - 89_200) < 0.001)
        #expect(result.isComplete)
    }

    @Test("Accrued interest is counted for a deposit with a positive rate")
    func accruedInterestPositive() async {
        let vm = await makeVM(deposits: [
            dep(amount: 100_000, currency: .RUB, openDate: daysFromNow(-30), rate: 12)
        ])
        #expect(vm.depositsAccruedIncome(using: fullConverter).value > 0)
    }
}

// MARK: - Missing rates

@Suite("DashboardViewModel — missing rates")
@MainActor
struct DashboardViewModelMissingRatesTests {

    private var partialConverter: CurrencyConverter {
        CurrencyConverter(base: .RUB, rates: [.USD: 90])   // no EUR rate
    }

    @Test("Unconvertible currency is reported and left out of the total")
    func reportsAndExcludes() async {
        let vm = await makeVM(deposits: [
            dep(amount: 100_000, currency: .RUB),
            dep(amount: 1_000, currency: .EUR)
        ])
        let result = vm.depositsPrincipal(using: partialConverter)
        #expect(abs(result.value - 100_000) < 0.001)
        #expect(result.missing == [.EUR])
        #expect(!result.isComplete)
    }

    @Test("Net worth merges missing currencies from every component")
    func netWorthMergesMissing() async {
        let vm = await makeVM(
            deposits: [dep(amount: 1_000, currency: .EUR)],
            subscriptions: [sub(amount: 10, currency: .GEL, cycle: .monthly)]
        )
        #expect(vm.netWorth(using: partialConverter).missing == [.EUR, .GEL])
    }

    @Test("A zero-amount entry in an unrated currency does not raise a false alarm")
    func zeroAmountNotReported() async {
        let vm = await makeVM(deposits: [dep(amount: 0, currency: .EUR)])
        #expect(vm.depositsPrincipal(using: partialConverter).missing.isEmpty)
    }
}

// MARK: - Allocation

@Suite("DashboardViewModel — allocation")
@MainActor
struct DashboardViewModelAllocationTests {

    @Test("Shares sum to 1.0")
    func sharesSumToOne() async {
        let vm = await makeVM(deposits: [
            dep(amount: 100_000, currency: .RUB),
            dep(amount: 1_000, currency: .USD),
            dep(amount: 500, currency: .EUR)
        ])
        let total = vm.allocationByCurrency(using: fullConverter).reduce(0) { $0 + $1.share }
        #expect(abs(total - 1.0) < 0.0001)
    }

    @Test("Slices are ordered largest first")
    func orderedLargestFirst() async {
        let vm = await makeVM(deposits: [
            dep(amount: 10_000, currency: .RUB),
            dep(amount: 1_000, currency: .USD)   // × 90 = 90_000 → bigger
        ])
        #expect(vm.allocationByCurrency(using: fullConverter).map(\.currency) == [.USD, .RUB])
    }

    @Test("Deposits in the same currency merge into one slice")
    func sameCurrencyMerges() async {
        let vm = await makeVM(deposits: [
            dep(amount: 100, currency: .RUB),
            dep(amount: 300, currency: .RUB)
        ])
        let slices = vm.allocationByCurrency(using: fullConverter)
        #expect(slices.count == 1)
        #expect(abs(slices[0].converted - 400) < 0.001)
    }

    @Test("Currencies without a rate are dropped — an unknown slice cannot be drawn")
    func unratedDropped() async {
        let partial = CurrencyConverter(base: .RUB, rates: [:])
        let vm = await makeVM(deposits: [
            dep(amount: 100_000, currency: .RUB),
            dep(amount: 1_000, currency: .EUR)
        ])
        #expect(vm.allocationByCurrency(using: partial).map(\.currency) == [.RUB])
    }

    @Test("No deposits → no slices")
    func emptyGivesNoSlices() async {
        let vm = await makeVM()
        #expect(vm.allocationByCurrency(using: fullConverter).isEmpty)
    }
}

// MARK: - Upcoming events

@Suite("DashboardViewModel — upcoming events")
@MainActor
struct DashboardViewModelUpcomingTests {

    @Test("Deposit closing inside the window is listed")
    func depositClosingListed() async {
        let vm = await makeVM(deposits: [dep(title: "Maturing", closeDate: daysFromNow(10))])
        let events = vm.upcomingEvents(withinDays: 30)
        #expect(events.count == 1)
        #expect(events[0].title == "Maturing")
        #expect(events[0].kind == .depositClosing)
    }

    @Test("Deposit closing beyond the window is excluded")
    func depositBeyondWindowExcluded() async {
        let vm = await makeVM(deposits: [dep(closeDate: daysFromNow(90))])
        #expect(vm.upcomingEvents(withinDays: 30).isEmpty)
    }

    @Test("Monthly subscription produces a payment inside the window")
    func subscriptionPaymentListed() async {
        let vm = await makeVM(subscriptions: [
            sub(title: "Netflix", cycle: .monthly, startDate: daysFromNow(-60))
        ])
        let events = vm.upcomingEvents(withinDays: 30)
        #expect(events.contains { $0.title == "Netflix" && $0.kind == .subscriptionPayment })
    }

    @Test("Cancelled subscriptions produce no events")
    func cancelledProducesNothing() async {
        let vm = await makeVM(subscriptions: [
            sub(cycle: .monthly, startDate: daysFromNow(-60), isActive: false, endDate: daysFromNow(-1))
        ])
        #expect(vm.upcomingEvents(withinDays: 30).isEmpty)
    }

    @Test("Events are sorted by date, soonest first")
    func sortedByDate() async {
        let vm = await makeVM(deposits: [
            dep(title: "Later", closeDate: daysFromNow(20)),
            dep(title: "Sooner", closeDate: daysFromNow(5))
        ])
        #expect(vm.upcomingEvents(withinDays: 30).map(\.title) == ["Sooner", "Later"])
    }

    @Test("Nothing scheduled → empty list")
    func emptyWhenNothingScheduled() async {
        let vm = await makeVM(deposits: [dep(closeDate: nil)])
        #expect(vm.upcomingEvents(withinDays: 30).isEmpty)
    }
}
