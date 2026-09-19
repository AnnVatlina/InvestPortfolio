//
//  AnalyticsViewModelTests.swift
//  InvestPortfolioTests
//
//  Tests for AnalyticsViewModel — local service behaviour and analytics computation.
//

import Testing
import Foundation
@testable import InvestPortfolio

// MARK: - Helpers

private func dep(
    title: String = "Deposit",
    amount: Double = 100_000,
    currency: DepositCurrency = .RUB,
    annualRate: Double = 10.0,
    openDate: Date = Date(),
    closeDate: Date? = nil
) -> Deposit {
    Deposit(title: title, amount: amount, currency: currency,
            openDate: openDate, closeDate: closeDate, annualInterestRate: annualRate)
}

private func sub(
    title: String = "Sub",
    amount: Double = 10.0,
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

@MainActor
private func makeVM(
    deposits: [Deposit] = [],
    subscriptions: [Subscription] = []
) async -> AnalyticsViewModel {
    let depRepo = InMemoryDepositsRepository()
    for d in deposits { try? await depRepo.add(d) }
    let subRepo = InMemorySubscriptionsRepository()
    for s in subscriptions { try? await subRepo.add(s) }
    return AnalyticsViewModel(
        depositsService: DefaultDepositsService(repository: depRepo),
        subscriptionsService: DefaultSubscriptionsService(repository: subRepo)
    )
}

private func date(year: Int, month: Int, day: Int = 1) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal.date(from: DateComponents(year: year, month: month, day: day))!
}

// MARK: - Load

@Suite("AnalyticsViewModel — load")
@MainActor
struct AnalyticsViewModelLoadTests {

    @Test("Load from empty services → deposits and subscriptions empty")
    func loadEmpty() async {
        let vm = await makeVM()
        await vm.load()
        #expect(vm.deposits.isEmpty)
        #expect(vm.subscriptions.isEmpty)
        #expect(vm.errorMessage == nil)
    }

    @Test("Load with deposits → vm.deposits populated")
    func loadDeposits() async {
        let vm = await makeVM(deposits: [dep(title: "Savings"), dep(title: "Term")])
        await vm.load()
        #expect(vm.deposits.count == 2)
        #expect(vm.errorMessage == nil)
    }

    @Test("Load with subscriptions → vm.subscriptions populated")
    func loadSubscriptions() async {
        let vm = await makeVM(subscriptions: [sub(title: "Netflix"), sub(title: "Spotify")])
        await vm.load()
        #expect(vm.subscriptions.count == 2)
        #expect(vm.errorMessage == nil)
    }

    @Test("Load with deposits and subscriptions → both populated")
    func loadBoth() async {
        let vm = await makeVM(deposits: [dep(title: "Bank")], subscriptions: [sub(title: "iCloud")])
        await vm.load()
        #expect(vm.deposits.count == 1)
        #expect(vm.subscriptions.count == 1)
    }

    @Test("Repeated load does not duplicate data")
    func repeatedLoadNoDuplicates() async {
        let vm = await makeVM(deposits: [dep(title: "Once")])
        await vm.load()
        await vm.load()
        #expect(vm.deposits.count == 1)
    }
}

// MARK: - Analytics computation

@Suite("AnalyticsViewModel — analytics computation")
@MainActor
struct AnalyticsViewModelComputationTests {

    @Test("activeCurrencies includes currency of a deposit with income")
    func activeCurrenciesIncludeDepositCurrency() async {
        let year = Calendar.current.component(.year, from: Date())
        let openDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let vm = await makeVM(deposits: [dep(currency: .USD, annualRate: 5.0, openDate: openDate)])
        vm.selectedYear = year
        await vm.load()
        #expect(vm.activeCurrencies.map(\.rawValue).contains("USD"))
    }

    @Test("activeCurrencies includes currency of a subscription")
    func activeCurrenciesIncludeSubCurrency() async {
        let year = Calendar.current.component(.year, from: Date())
        let startDate = date(year: year, month: 1)
        let vm = await makeVM(subscriptions: [sub(amount: 9.99, currency: .EUR, cycle: .monthly, startDate: startDate)])
        vm.selectedYear = year
        await vm.load()
        #expect(vm.activeCurrencies.map(\.rawValue).contains("EUR"))
    }

    @Test("Deposit with positive rate generates income > 0 for selected year")
    func depositIncomeIsPositive() async {
        let year = Calendar.current.component(.year, from: Date())
        let openDate = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        let vm = await makeVM(deposits: [dep(amount: 100_000, currency: .RUB, annualRate: 10.0, openDate: openDate)])
        vm.selectedYear = year
        await vm.load()
        #expect(vm.totalIncome(currency: .RUB) > 0)
    }

    @Test("Monthly subscription for full year generates 12 months of expenses")
    func monthlySubExpenseSpans12Months() async {
        let year = Calendar.current.component(.year, from: Date())
        let startDate = date(year: year, month: 1)
        let vm = await makeVM(subscriptions: [sub(amount: 10.0, currency: .USD, cycle: .monthly, startDate: startDate)])
        vm.selectedYear = year
        await vm.load()
        let points = vm.monthlyPoints(currency: .USD)
        #expect(points.filter { $0.expense > 0 }.count == 12)
    }

    @Test("yearRange lower bound includes deposit open year")
    func yearRangeCoversDepositOpenYear() async {
        let pastYear = Calendar.current.component(.year, from: Date()) - 3
        let openDate = date(year: pastYear, month: 6)
        let vm = await makeVM(deposits: [dep(openDate: openDate)])
        await vm.load()
        #expect(vm.yearRange.lowerBound <= pastYear)
    }

    @Test("netBalance equals income minus expenses for same currency")
    func netBalanceIsIncomeMinusExpenses() async {
        let year = Calendar.current.component(.year, from: Date())
        let openDate = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        let vm = await makeVM(deposits: [dep(amount: 100_000, currency: .RUB, annualRate: 10.0, openDate: openDate)])
        vm.selectedYear = year
        await vm.load()
        let income   = vm.totalIncome(currency: .RUB)
        let expenses = vm.totalExpenses(currency: .RUB)
        #expect(vm.netBalance(currency: .RUB) == income - expenses)
    }
}

// MARK: - By month

@Suite("AnalyticsViewModel — by month")
@MainActor
struct AnalyticsViewModelByMonthTests {

    @Test("Monthly subscription charge only counts in the month it's due")
    func expenseOnlyInDueMonth() async {
        let year = Calendar.current.component(.year, from: Date())
        let startDate = date(year: year, month: 3)
        let vm = await makeVM(subscriptions: [sub(amount: 9.99, currency: .USD, cycle: .yearly, startDate: startDate)])
        vm.selectedYear = year
        await vm.load()

        vm.selectedMonth = 3
        #expect(abs(vm.monthExpense(currency: .USD) - 9.99) < 0.001)

        vm.selectedMonth = 4
        #expect(vm.monthExpense(currency: .USD) == 0)
    }

    @Test("Deposit income for a month equals that month's slice, not the whole year")
    func incomeIsSlicedByMonth() async {
        let year = Calendar.current.component(.year, from: Date())
        let openDate = date(year: year, month: 1)
        let vm = await makeVM(deposits: [dep(amount: 100_000, currency: .RUB, annualRate: 12.0, openDate: openDate)])
        vm.selectedYear = year
        await vm.load()

        vm.selectedMonth = 1
        let januaryIncome = vm.monthIncome(currency: .RUB)
        let yearIncome = vm.totalIncome(currency: .RUB)
        #expect(januaryIncome > 0)
        #expect(januaryIncome < yearIncome)
    }

    @Test("monthNet equals monthIncome minus monthExpense")
    func monthNetIsIncomeMinusExpense() async {
        let year = Calendar.current.component(.year, from: Date())
        let openDate = date(year: year, month: 1)
        let vm = await makeVM(
            deposits: [dep(amount: 100_000, currency: .RUB, annualRate: 10.0, openDate: openDate)],
            subscriptions: [sub(amount: 500, currency: .RUB, cycle: .monthly, startDate: openDate)]
        )
        vm.selectedYear = year
        vm.selectedMonth = 6
        await vm.load()
        let income = vm.monthIncome(currency: .RUB)
        let expense = vm.monthExpense(currency: .RUB)
        #expect(vm.monthNet(currency: .RUB) == income - expense)
    }

    @Test("Month with no data returns zero for income, expense and net")
    func emptyMonthReturnsZero() async {
        let vm = await makeVM()
        vm.selectedMonth = 5
        #expect(vm.monthIncome(currency: .USD) == 0)
        #expect(vm.monthExpense(currency: .USD) == 0)
        #expect(vm.monthNet(currency: .USD) == 0)
    }

    @Test("selectedMonth defaults to the current calendar month")
    func defaultsToCurrentMonth() async {
        let vm = await makeVM()
        #expect(vm.selectedMonth == Calendar.current.component(.month, from: Date()))
    }
}
