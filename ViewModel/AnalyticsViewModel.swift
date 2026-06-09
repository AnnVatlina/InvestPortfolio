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

@MainActor final class AnalyticsViewModel: ObservableObject {
    @Published var selectedYear: Int
    @Published private(set) var deposits: [Deposit] = []
    @Published private(set) var subscriptions: [Subscription] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let depositsService: any DepositsService
    private let subscriptionsService: any SubscriptionsService
    private let depositsAPI: any DepositsAPIProtocol
    private let subscriptionsAPI: any SubscriptionsAPIProtocol
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        return cal
    }()

    init(
        depositsService: any DepositsService,
        subscriptionsService: any SubscriptionsService,
        depositsAPI: any DepositsAPIProtocol = DepositsAPI(),
        subscriptionsAPI: any SubscriptionsAPIProtocol = SubscriptionsAPI()
    ) {
        self.depositsService = depositsService
        self.subscriptionsService = subscriptionsService
        self.depositsAPI = depositsAPI
        self.subscriptionsAPI = subscriptionsAPI
        self.selectedYear = Calendar.current.component(.year, from: Date())
    }

    // MARK: - Load (cache-first, then sync from API)

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // 1. Show cached data immediately
        if let cached = try? await depositsService.fetchAll() { deposits = cached }
        if let cached = try? await subscriptionsService.fetchAll() { subscriptions = cached }

        // 2. Sync both from API concurrently
        do {
            async let depsRemote = depositsAPI.getDeposits()
            async let subsRemote = subscriptionsAPI.getSubscriptions()
            let (depsResult, subsResult) = try await (depsRemote, subsRemote)

            for dto in depsResult {
                try await depositsService.upsert(
                    serverId: dto.id,
                    title: dto.title,
                    bankName: dto.bankName,
                    amount: dto.amountDouble,
                    currency: dto.depositCurrency,
                    openDate: dto.openDate,
                    closeDate: dto.closeDate,
                    annualInterestRate: dto.annualRateDouble,
                    createdAt: dto.createdAt
                )
            }
            for dto in subsResult {
                try await subscriptionsService.upsert(
                    serverId: dto.id,
                    title: dto.title,
                    amount: dto.amountDouble,
                    currency: dto.depositCurrency,
                    billingCycle: dto.subscriptionBillingCycle,
                    startDate: dto.startDate,
                    endDate: dto.endDate,
                    category: dto.category,
                    iconName: dto.iconName,
                    isActive: dto.isActive,
                    createdAt: dto.createdAt
                )
            }

            async let deps = depositsService.fetchAll()
            async let subs = subscriptionsService.fetchAll()
            (deposits, subscriptions) = try await (deps, subs)
        } catch {
            // Keep cached data visible; only surface error if nothing to show
            if deposits.isEmpty && subscriptions.isEmpty {
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
        let lo = years.min() ?? currentYear
        let hi = max(years.max() ?? currentYear, currentYear)
        return lo...hi
    }

    // MARK: - Active currencies (have data in selected year)

    var activeCurrencies: [DepositCurrency] {
        let pts = _allPoints(year: selectedYear)
        let set = Set(pts.filter { $0.income > 0 || $0.expense > 0 }.map { $0.currency })
        return set.sorted { $0.rawValue < $1.rawValue }
    }

    // MARK: - Per-currency monthly points

    func monthlyPoints(currency: DepositCurrency) -> [MonthlyAnalyticsPoint] {
        _allPoints(year: selectedYear).filter { $0.currency == currency }
    }

    // MARK: - Year totals (full year, including future months as projection)

    func totalIncome(currency: DepositCurrency) -> Double {
        monthlyPoints(currency: currency).reduce(0) { $0 + $1.income }
    }

    func totalExpenses(currency: DepositCurrency) -> Double {
        monthlyPoints(currency: currency).reduce(0) { $0 + $1.expense }
    }

    func netBalance(currency: DepositCurrency) -> Double {
        totalIncome(currency: currency) - totalExpenses(currency: currency)
    }

    // MARK: - To date (actual amounts from Jan 1 of selectedYear up to today)

    /// True if selectedYear is current or past — "to date" values are meaningful
    var isPastOrCurrentYear: Bool {
        selectedYear <= calendar.component(.year, from: Date())
    }

    /// Actual deposit income earned from Jan 1 of selectedYear up to today
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

    /// Actual subscription payments made from Jan 1 of selectedYear up to today
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

                // Deposit income earned within this calendar month
                let income = deposits
                    .filter { $0.currency == currency }
                    .reduce(0.0) { sum, dep in
                        let atEnd   = depositsService.incomeSummary(for: dep, asOf: monthEnd).incomeToDate
                        let atStart = depositsService.incomeSummary(for: dep, asOf: dayBefore).incomeToDate
                        return sum + max(0, atEnd - atStart)
                    }

                // Subscription payments falling within [monthStart, nextMonth)
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
}
