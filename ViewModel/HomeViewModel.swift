//
//  HomeViewModel.swift
//  InvestPortfolio
//
//  Feeds the home screen: nearest upcoming subscription payments, currently
//  open deposits sorted by end date, and the income-vs-subscriptions coverage card.
//

import Foundation

/// One currency's slice of the coverage card, in its original (unconverted) currency.
struct CoverageLine: Identifiable, Equatable {
    let currency: DepositCurrency
    let income: Double
    let subscriptions: Double

    var id: DepositCurrency { currency }
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var deposits: [Deposit] = []
    @Published private(set) var subscriptions: [Subscription] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let depositsService: any DepositsService
    private let subscriptionsService: any SubscriptionsService
    private let now: () -> Date
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        return cal
    }()

    init(
        depositsService: any DepositsService,
        subscriptionsService: any SubscriptionsService,
        now: @escaping () -> Date = { Date() }
    ) {
        self.depositsService = depositsService
        self.subscriptionsService = subscriptionsService
        self.now = now
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let deps = depositsService.fetchAll()
            async let subs = subscriptionsService.fetchAll()
            (deposits, subscriptions) = try await (deps, subs)
        } catch {
            if deposits.isEmpty && subscriptions.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Deposits that haven't closed yet, soonest end date first.
    var openDeposits: [Deposit] {
        deposits.openSortedByCloseDate
    }

    /// The nearest upcoming payments across active subscriptions, soonest first.
    func upcomingSubscriptions(limit: Int = 5) -> [Subscription] {
        subscriptions.nearestUpcoming(limit: limit)
    }

    // MARK: - Coverage

    /// Deposit interest accrued in the current calendar month, per original currency.
    /// Same calculation as `AnalyticsViewModel._allPoints`: interest at month end minus
    /// interest the day before the month began.
    private var monthlyIncomeByCurrency: [DepositCurrency: Double] {
        let today = now()
        guard let monthStart = calendar.dateInterval(of: .month, for: today)?.start,
              let dayBefore = calendar.date(byAdding: .day, value: -1, to: monthStart),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart),
              let monthEnd = calendar.date(byAdding: .day, value: -1, to: nextMonth)
        else { return [:] }

        var result: [DepositCurrency: Double] = [:]
        for deposit in deposits {
            let atEnd = depositsService.incomeSummary(for: deposit, asOf: monthEnd).incomeToDate
            let atStart = depositsService.incomeSummary(for: deposit, asOf: dayBefore).incomeToDate
            result[deposit.currency, default: 0] += max(0, atEnd - atStart)
        }
        return result
    }

    /// Normalized monthly cost of active recurring subscriptions, per original currency.
    /// One-time purchases are not a regular expense and are left out.
    private var monthlySubscriptionsByCurrency: [DepositCurrency: Double] {
        var result: [DepositCurrency: Double] = [:]
        for sub in subscriptions where sub.isActive && sub.billingCycle.isRecurring {
            result[sub.currency, default: 0] += sub.amount * sub.billingCycle.monthlyFactor
        }
        return result
    }

    /// Per-currency breakdown, only for currencies that have income or subscriptions.
    var coverageBreakdown: [CoverageLine] {
        let income = monthlyIncomeByCurrency
        let subs = monthlySubscriptionsByCurrency
        return Set(income.keys).union(subs.keys)
            .map { CoverageLine(currency: $0, income: income[$0] ?? 0, subscriptions: subs[$0] ?? 0) }
            .filter { $0.income > 0 || $0.subscriptions > 0 }
            .sorted { $0.currency.rawValue < $1.currency.rawValue }
    }

    /// Currencies with income or subscriptions that have no usable rate — their amounts
    /// are excluded from the converted totals, so the UI must say so.
    func missingRates(converter: CurrencyConverter) -> [DepositCurrency] {
        converter.missingRates(for: coverageBreakdown.map(\.currency))
    }

    /// Monthly deposit interest in the base currency, skipping currencies without a rate.
    func monthlyIncome(converter: CurrencyConverter) -> Double {
        converted(monthlyIncomeByCurrency, converter: converter)
    }

    /// Monthly cost of active recurring subscriptions in the base currency,
    /// skipping currencies without a rate.
    func monthlySubscriptions(converter: CurrencyConverter) -> Double {
        converted(monthlySubscriptionsByCurrency, converter: converter)
    }

    /// Income divided by subscriptions, as a fraction (1.0 == 100%).
    /// `nil` when there are no subscriptions to cover — a percentage would be meaningless.
    func coverage(converter: CurrencyConverter) -> Double? {
        let subs = monthlySubscriptions(converter: converter)
        guard subs > 0 else { return nil }
        return monthlyIncome(converter: converter) / subs
    }

    private func converted(_ amounts: [DepositCurrency: Double], converter: CurrencyConverter) -> Double {
        amounts.reduce(0.0) { sum, entry in
            sum + (converter.convert(entry.value, from: entry.key) ?? 0)
        }
    }
}
