//
//  HomeViewModelTests.swift
//  InvestPortfolioTests
//
//  Tests for HomeViewModel — open deposits ordering, nearest upcoming payments,
//  and income-vs-subscriptions coverage.
//

import Testing
import Foundation
@testable import InvestPortfolio

// MARK: - Helpers

@MainActor
private func makeVM(
    deposits: [Deposit] = [],
    subscriptions: [Subscription] = [],
    now: @escaping () -> Date = { Date() }
) async -> HomeViewModel {
    let depRepo = InMemoryDepositsRepository()
    for d in deposits { try? await depRepo.add(d) }
    let subRepo = InMemorySubscriptionsRepository()
    for s in subscriptions { try? await subRepo.add(s) }
    let vm = HomeViewModel(
        depositsService: DefaultDepositsService(repository: depRepo),
        subscriptionsService: DefaultSubscriptionsService(repository: subRepo),
        now: now
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

// MARK: - Coverage

/// Fixed "today" in a 30-day month so interest is exactly 30 days of accrual.
private let june15: Date = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone.current
    return cal.date(from: DateComponents(year: 2026, month: 6, day: 15))!
}()

private let januaryFirst: Date = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone.current
    return cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
}()

/// 12 000 @ 10% simple for 30 days = 12 000 × 0.10 / 365 × 30.
private let juneInterestOn12k = 12_000 * 0.10 / 365 * 30

private func converter(
    base: DepositCurrency = .USD,
    rates: [DepositCurrency: Double] = [:]
) -> CurrencyConverter {
    CurrencyConverter(base: base, rates: rates)
}

@Suite("HomeViewModel — coverage")
@MainActor
struct HomeViewModelCoverageTests {

    @Test("Single currency: income, subscriptions and coverage in that currency")
    func singleCurrency() async throws {
        let vm = await makeVM(
            deposits: [dep(amount: 12_000, currency: .USD, openDate: januaryFirst, rate: 10)],
            subscriptions: [sub(amount: 20, currency: .USD, cycle: .monthly)],
            now: { june15 }
        )
        let c = converter()
        #expect(abs(vm.monthlyIncome(converter: c) - juneInterestOn12k) < 0.01)
        #expect(vm.monthlySubscriptions(converter: c) == 20)
        let coverage = try #require(vm.coverage(converter: c))
        #expect(abs(coverage - juneInterestOn12k / 20) < 0.001)
        #expect(vm.missingRates(converter: c).isEmpty)
    }

    @Test("USD + GEL with a rate: GEL is converted into the base currency")
    func twoCurrenciesWithRate() async {
        let vm = await makeVM(
            deposits: [dep(amount: 12_000, currency: .USD, openDate: januaryFirst, rate: 10)],
            subscriptions: [
                sub(amount: 10, currency: .USD, cycle: .monthly),
                sub(amount: 100, currency: .GEL, cycle: .monthly)
            ],
            now: { june15 }
        )
        let c = converter(rates: [.GEL: 0.37])
        #expect(abs(vm.monthlySubscriptions(converter: c) - 47) < 0.0001)
        #expect(vm.missingRates(converter: c).isEmpty)
        #expect(vm.coverageBreakdown.map(\.currency) == [.GEL, .USD])
    }

    @Test("Currency without a rate is excluded from totals and reported as missing")
    func missingRateExcluded() async {
        let vm = await makeVM(
            subscriptions: [
                sub(amount: 10, currency: .USD, cycle: .monthly),
                sub(amount: 100, currency: .GEL, cycle: .monthly)
            ],
            now: { june15 }
        )
        let c = converter(rates: [:])
        #expect(vm.monthlySubscriptions(converter: c) == 10)
        #expect(vm.missingRates(converter: c) == [.GEL])
    }

    @Test("No subscriptions → no coverage percentage")
    func noSubscriptionsNoPercent() async {
        let vm = await makeVM(
            deposits: [dep(amount: 12_000, currency: .USD, openDate: januaryFirst, rate: 10)],
            now: { june15 }
        )
        #expect(vm.coverage(converter: converter()) == nil)
        #expect(vm.monthlyIncome(converter: converter()) > 0)
    }

    @Test("One-time purchase does not affect the monthly total")
    func oneTimeIgnored() async {
        let vm = await makeVM(
            subscriptions: [
                sub(amount: 10, currency: .USD, cycle: .monthly),
                sub(amount: 500, currency: .USD, cycle: .oneTime)
            ],
            now: { june15 }
        )
        #expect(vm.monthlySubscriptions(converter: converter()) == 10)
    }

    @Test("Cancelled subscription is not counted")
    func cancelledIgnored() async {
        let vm = await makeVM(
            subscriptions: [
                sub(amount: 10, currency: .USD, cycle: .monthly),
                sub(amount: 99, currency: .USD, cycle: .monthly, isActive: false, endDate: daysFromNow(-1))
            ],
            now: { june15 }
        )
        #expect(vm.monthlySubscriptions(converter: converter()) == 10)
    }

    @Test("Billing cycles are normalized to a monthly cost")
    func cyclesNormalized() async {
        let vm = await makeVM(
            subscriptions: [
                sub(amount: 120, currency: .USD, cycle: .yearly),
                sub(amount: 30, currency: .USD, cycle: .quarterly)
            ],
            now: { june15 }
        )
        #expect(abs(vm.monthlySubscriptions(converter: converter()) - 20) < 0.0001)
    }

    @Test("Deposit that has not started accrues nothing this month")
    func futureDepositNoIncome() async {
        let vm = await makeVM(
            deposits: [dep(amount: 12_000, currency: .USD, openDate: daysFromNow(400), rate: 10)]
        )
        #expect(vm.monthlyIncome(converter: converter()) == 0)
        #expect(vm.coverageBreakdown.isEmpty)
    }
}
