//
//  AnalyticsViewModel.swift
//  InvestPortfolio
//

import Foundation

struct MonthlyAnalyticsPoint: Identifiable {
    let id = UUID()
    let month: Date
    let currency: DepositCurrency
    let income: Double      // earned from deposits
    let expense: Double     // spent on subscriptions
    var net: Double { income - expense }
}

/// Broker operations (dividends/tax/commissions) are deliberately kept as their own series,
/// shown in a separate "Дивиденды" section rather than folded into `MonthlyAnalyticsPoint` —
/// mixing brokerage cash flow into the deposits/subscriptions totals would make neither
/// number mean what its label says.
struct YearlyDividendPoint: Identifiable {
    var id: Int { year }
    let year: Int
    let currency: DepositCurrency
    let income: Double
    let expense: Double
    var net: Double { income - expense }
}

struct MonthlyDividendPoint: Identifiable {
    let id = UUID()
    let month: Date
    let currency: DepositCurrency
    let income: Double      // dividends
    let expense: Double     // taxes + commissions
    var net: Double { income - expense }
}

@MainActor final class AnalyticsViewModel: ObservableObject {
    @Published var selectedYear: Int
    @Published var selectedMonth: Int
    @Published private(set) var deposits: [Deposit] = []
    @Published private(set) var subscriptions: [Subscription] = []
    @Published private(set) var brokerOperations: [BrokerOperation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let depositsService: any DepositsService
    private let subscriptionsService: any SubscriptionsService
    private let dividendsService: any DividendsService
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        return cal
    }()

    init(
        depositsService: any DepositsService,
        subscriptionsService: any SubscriptionsService,
        dividendsService: any DividendsService
    ) {
        self.depositsService = depositsService
        self.subscriptionsService = subscriptionsService
        self.dividendsService = dividendsService
        self.selectedYear = Calendar.current.component(.year, from: Date())
        self.selectedMonth = Calendar.current.component(.month, from: Date())
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let deps = depositsService.fetchAll()
            async let subs = subscriptionsService.fetchAll()
            async let ops = dividendsService.fetchAll()
            (deposits, subscriptions, brokerOperations) = try await (deps, subs, ops)
        } catch {
            if deposits.isEmpty && subscriptions.isEmpty && brokerOperations.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Year range

    var yearRange: ClosedRange<Int> {
        let currentYear = calendar.component(.year, from: Date())
        var years: [Int] = [currentYear]
        for d in deposits {
            years.append(calendar.component(.year, from: d.openDate))
            if let close = d.closeDate { years.append(calendar.component(.year, from: close)) }
        }
        for s in subscriptions {
            years.append(calendar.component(.year, from: s.startDate))
        }
        for op in brokerOperations {
            years.append(calendar.component(.year, from: op.date))
        }
        let lo = years.min() ?? currentYear
        let hi = max(years.max() ?? currentYear, currentYear)
        return lo...hi
    }

    // MARK: - Active currencies (have data in selected year)

    var activeCurrencies: [DepositCurrency] {
        let pts = _allPoints(year: selectedYear)
        var set = Set(pts.filter { $0.income > 0 || $0.expense > 0 }.map { $0.currency })
        // Union in currencies that only have dividend activity — the currency picker (shared
        // between the deposits/subscriptions analytics and the separate dividends section)
        // still needs to offer them even when there's no deposit/subscription data at all.
        set.formUnion(
            brokerOperations
                .filter { calendar.component(.year, from: $0.date) == selectedYear }
                .map { $0.currency }
        )
        return set.sorted { $0.rawValue < $1.rawValue }
    }

    // MARK: - Per-currency monthly points

    func monthlyPoints(currency: DepositCurrency) -> [MonthlyAnalyticsPoint] {
        _allPoints(year: selectedYear).filter { $0.currency == currency }
    }

    // MARK: - Year totals

    func totalIncome(currency: DepositCurrency) -> Double {
        monthlyPoints(currency: currency).reduce(0) { $0 + $1.income }
    }

    func totalExpenses(currency: DepositCurrency) -> Double {
        monthlyPoints(currency: currency).reduce(0) { $0 + $1.expense }
    }

    func netBalance(currency: DepositCurrency) -> Double {
        totalIncome(currency: currency) - totalExpenses(currency: currency)
    }

    // MARK: - To date

    var isPastOrCurrentYear: Bool {
        selectedYear <= calendar.component(.year, from: Date())
    }

    func totalEarnedToDate(currency: DepositCurrency) -> Double {
        guard isPastOrCurrentYear else { return 0 }
        let today = Date()
        guard let yearStart = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1)),
              let dayBefore = calendar.date(byAdding: .day, value: -1, to: yearStart)
        else { return 0 }
        return deposits
            .filter { $0.currency == currency }
            .reduce(0.0) { sum, dep in
                let atToday = depositsService.incomeSummary(for: dep, asOf: today).incomeToDate
                let atStart = depositsService.incomeSummary(for: dep, asOf: dayBefore).incomeToDate
                return sum + max(0, atToday - atStart)
            }
    }

    func totalPaidToDate(currency: DepositCurrency) -> Double {
        guard isPastOrCurrentYear else { return 0 }
        let today = Date()
        guard let yearStart = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1))
        else { return 0 }
        return subscriptions
            .filter { $0.currency == currency }
            .reduce(0.0) { sum, sub in
                let dates = _paymentDates(for: sub, from: yearStart, to: today)
                return sum + Double(dates.count) * sub.amount
            }
    }

    func netToDate(currency: DepositCurrency) -> Double {
        totalEarnedToDate(currency: currency) - totalPaidToDate(currency: currency)
    }

    // MARK: - By month (selectedMonth within selectedYear)

    /// Deposit interest and subscription charges are already computed per calendar month
    /// by `_allPoints` — a future month naturally comes out as a projection (same as the
    /// full-year total already does), a past month as the actual amount for that month.

    func monthIncome(currency: DepositCurrency) -> Double {
        point(currency: currency, month: selectedMonth)?.income ?? 0
    }

    func monthExpense(currency: DepositCurrency) -> Double {
        point(currency: currency, month: selectedMonth)?.expense ?? 0
    }

    func monthNet(currency: DepositCurrency) -> Double {
        monthIncome(currency: currency) - monthExpense(currency: currency)
    }

    private func point(currency: DepositCurrency, month: Int) -> MonthlyAnalyticsPoint? {
        monthlyPoints(currency: currency).first { calendar.component(.month, from: $0.month) == month }
    }

    // MARK: - Dividends (separate section — see MonthlyDividendPoint)

    func dividendMonthlyPoints(currency: DepositCurrency) -> [MonthlyDividendPoint] {
        (1...12).compactMap { monthIdx -> MonthlyDividendPoint? in
            let comps = DateComponents(year: selectedYear, month: monthIdx, day: 1)
            guard let monthStart = calendar.date(from: comps),
                  let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart)
            else { return nil }
            return MonthlyDividendPoint(
                month: monthStart,
                currency: currency,
                income: _dividendIncome(currency: currency, from: monthStart, to: nextMonth),
                expense: _dividendExpense(currency: currency, from: monthStart, to: nextMonth)
            )
        }
    }

    func totalDividendIncome(currency: DepositCurrency) -> Double {
        dividendMonthlyPoints(currency: currency).reduce(0) { $0 + $1.income }
    }

    func totalDividendExpense(currency: DepositCurrency) -> Double {
        dividendMonthlyPoints(currency: currency).reduce(0) { $0 + $1.expense }
    }

    func dividendNetBalance(currency: DepositCurrency) -> Double {
        totalDividendIncome(currency: currency) - totalDividendExpense(currency: currency)
    }

    /// Whether the selected year has any dividend activity at all for this currency — lets
    /// the view hide the section instead of showing an all-zero "Дивиденды" block.
    func hasDividendActivity(currency: DepositCurrency) -> Bool {
        totalDividendIncome(currency: currency) > 0 || totalDividendExpense(currency: currency) > 0
    }

    func dividendIncomeToDate(currency: DepositCurrency) -> Double {
        guard isPastOrCurrentYear,
              let yearStart = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1)),
              let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))
        else { return 0 }
        return _dividendIncome(currency: currency, from: yearStart, to: endOfToday)
    }

    func dividendExpenseToDate(currency: DepositCurrency) -> Double {
        guard isPastOrCurrentYear,
              let yearStart = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1)),
              let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))
        else { return 0 }
        return _dividendExpense(currency: currency, from: yearStart, to: endOfToday)
    }

    func dividendNetToDate(currency: DepositCurrency) -> Double {
        dividendIncomeToDate(currency: currency) - dividendExpenseToDate(currency: currency)
    }

    func monthDividendIncome(currency: DepositCurrency) -> Double {
        dividendPoint(currency: currency, month: selectedMonth)?.income ?? 0
    }

    func monthDividendExpense(currency: DepositCurrency) -> Double {
        dividendPoint(currency: currency, month: selectedMonth)?.expense ?? 0
    }

    func monthDividendNet(currency: DepositCurrency) -> Double {
        monthDividendIncome(currency: currency) - monthDividendExpense(currency: currency)
    }

    private func dividendPoint(currency: DepositCurrency, month: Int) -> MonthlyDividendPoint? {
        dividendMonthlyPoints(currency: currency).first { calendar.component(.month, from: $0.month) == month }
    }

    /// One row per year in `yearRange` that actually has dividend activity — lets the
    /// view show the whole multi-year history at a glance instead of only the single
    /// year `selectedYear` currently points at.
    func dividendYearlyPoints(currency: DepositCurrency) -> [YearlyDividendPoint] {
        yearRange.compactMap { year -> YearlyDividendPoint? in
            guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
                  let yearEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))
            else { return nil }
            let income = _dividendIncome(currency: currency, from: yearStart, to: yearEnd)
            let expense = _dividendExpense(currency: currency, from: yearStart, to: yearEnd)
            guard income > 0 || expense > 0 else { return nil }
            return YearlyDividendPoint(year: year, currency: currency, income: income, expense: expense)
        }
    }

    // MARK: - Private computation

    private func _allPoints(year: Int) -> [MonthlyAnalyticsPoint] {
        var currencies: Set<DepositCurrency> = []
        deposits.forEach { currencies.insert($0.currency) }
        subscriptions.forEach { currencies.insert($0.currency) }

        var result: [MonthlyAnalyticsPoint] = []

        for currency in currencies {
            for monthIdx in 1...12 {
                let comps = DateComponents(year: year, month: monthIdx, day: 1)
                guard let monthStart = calendar.date(from: comps),
                      let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart),
                      let dayBefore = calendar.date(byAdding: .day, value: -1, to: monthStart) else { continue }
                let monthEnd = calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? monthStart

                let income = deposits
                    .filter { $0.currency == currency }
                    .reduce(0.0) { sum, dep in
                        let atEnd   = depositsService.incomeSummary(for: dep, asOf: monthEnd).incomeToDate
                        let atStart = depositsService.incomeSummary(for: dep, asOf: dayBefore).incomeToDate
                        return sum + max(0, atEnd - atStart)
                    }

                let expense = subscriptions
                    .filter { $0.currency == currency }
                    .reduce(0.0) { sum, sub in
                        let dates = _paymentDates(for: sub, from: monthStart, to: nextMonth)
                        return sum + Double(dates.count) * sub.amount
                    }

                result.append(MonthlyAnalyticsPoint(
                    month: monthStart,
                    currency: currency,
                    income: income,
                    expense: expense
                ))
            }
        }

        return result.sorted { $0.month < $1.month }
    }

    private func _paymentDates(for sub: Subscription, from: Date, to: Date) -> [Date] {
        let effectiveTo = sub.endDate.map { min($0, to) } ?? to
        if !sub.billingCycle.isRecurring {
            return (sub.startDate >= from && sub.startDate < effectiveTo) ? [sub.startDate] : []
        }
        var dates: [Date] = []
        var current = sub.startDate
        while current < from {
            current = Subscription.advance(current, by: sub.billingCycle, calendar: calendar)
        }
        while current < effectiveTo {
            dates.append(current)
            current = Subscription.advance(current, by: sub.billingCycle, calendar: calendar)
        }
        return dates
    }

    // Dividends are positive amounts (income); taxes/commissions are negative (expense) —
    // the report's own sign already tells us which is which, so there's no need to switch
    // on BrokerOperationType here. `to` is exclusive, matching `_paymentDates` above.
    private func _dividendIncome(currency: DepositCurrency, from: Date, to: Date) -> Double {
        brokerOperations
            .filter { $0.currency == currency && $0.date >= from && $0.date < to }
            .reduce(0.0) { sum, op in sum + max(0, (op.amount as NSDecimalNumber).doubleValue) }
    }

    private func _dividendExpense(currency: DepositCurrency, from: Date, to: Date) -> Double {
        brokerOperations
            .filter { $0.currency == currency && $0.date >= from && $0.date < to }
            .reduce(0.0) { sum, op in sum + max(0, -(op.amount as NSDecimalNumber).doubleValue) }
    }
}
