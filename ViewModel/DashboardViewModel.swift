//
//  DashboardViewModel.swift
//  InvestPortfolio
//
//  Aggregates deposits and subscriptions into a single net worth figure,
//  converted into the user's base currency.
//

import Foundation

// MARK: - Output types

/// A total plus the currencies that could not be folded into it for lack of a rate.
/// Keeping the gap explicit stops the UI from presenting an under-reported number as complete.
struct ConvertedTotal: Equatable {
    let value: Double
    let missing: [DepositCurrency]

    var isComplete: Bool { missing.isEmpty }

    static let zero = ConvertedTotal(value: 0, missing: [])
}

struct AllocationSlice: Identifiable, Equatable {
    var id: DepositCurrency { currency }
    let currency: DepositCurrency
    let converted: Double
    let share: Double
}

struct DashboardEvent: Identifiable, Equatable {
    enum Kind: Equatable {
        case depositClosing
        case subscriptionPayment
    }

    let id: UUID
    let date: Date
    let title: String
    let amount: Double
    let currency: DepositCurrency
    let kind: Kind
}

// MARK: - ViewModel

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var deposits: [Deposit] = []
    @Published private(set) var subscriptions: [Subscription] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let depositsService: any DepositsService
    private let subscriptionsService: any SubscriptionsService
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        return cal
    }()

    init(
        depositsService: any DepositsService,
        subscriptionsService: any SubscriptionsService
    ) {
        self.depositsService = depositsService
        self.subscriptionsService = subscriptionsService
    }

    // MARK: - Load

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

    // MARK: - Source collections

    /// Deposits that have not closed yet.
    var activeDeposits: [Deposit] {
        let now = Date()
        return deposits.filter { deposit in
            guard let close = deposit.closeDate else { return true }
            return close > now
        }
    }

    var activeSubscriptions: [Subscription] {
        subscriptions.filter { $0.isActive }
    }

    // MARK: - Totals

    /// Principal of every deposit still open.
    func depositsPrincipal(using converter: CurrencyConverter) -> ConvertedTotal {
        sum(activeDeposits.map { ($0.amount, $0.currency) }, using: converter)
    }

    /// Interest accrued to date across every deposit, closed ones included.
    func depositsAccruedIncome(using converter: CurrencyConverter) -> ConvertedTotal {
        let now = Date()
        let entries = deposits.map { deposit in
            (depositsService.incomeSummary(for: deposit, asOf: now).incomeToDate, deposit.currency)
        }
        return sum(entries, using: converter)
    }

    /// What the active recurring subscriptions cost over a year.
    func annualSubscriptionCost(using converter: CurrencyConverter) -> ConvertedTotal {
        let subs = activeSubscriptions
        let currencies = Set(subs.map(\.currency))
        let entries = currencies.map { currency in
            (subscriptionsService.totalAnnualCost(in: currency, subscriptions: subs), currency)
        }
        return sum(entries, using: converter)
    }

    /// Deposits + accrued interest − a year of subscriptions.
    func netWorth(using converter: CurrencyConverter) -> ConvertedTotal {
        let principal = depositsPrincipal(using: converter)
        let income = depositsAccruedIncome(using: converter)
        let annualSubs = annualSubscriptionCost(using: converter)

        let missing = Array(Set(principal.missing + income.missing + annualSubs.missing))
            .sorted { $0.rawValue < $1.rawValue }

        return ConvertedTotal(
            value: principal.value + income.value - annualSubs.value,
            missing: missing
        )
    }

    // MARK: - Allocation

    /// Share of open-deposit principal held in each currency, largest first.
    /// Currencies without a rate are dropped — a slice of unknown size cannot be drawn.
    func allocationByCurrency(using converter: CurrencyConverter) -> [AllocationSlice] {
        var totals: [DepositCurrency: Double] = [:]
        for deposit in activeDeposits {
            guard let converted = converter.convert(deposit.amount, from: deposit.currency) else { continue }
            totals[deposit.currency, default: 0] += converted
        }

        let grandTotal = totals.values.reduce(0, +)
        guard grandTotal > 0 else { return [] }

        return totals
            .map { AllocationSlice(currency: $0.key, converted: $0.value, share: $0.value / grandTotal) }
            .sorted { lhs, rhs in
                lhs.converted == rhs.converted
                    ? lhs.currency.rawValue < rhs.currency.rawValue
                    : lhs.converted > rhs.converted
            }
    }

    // MARK: - Upcoming events

    /// Deposit maturities and subscription charges falling inside the window, soonest first.
    func upcomingEvents(withinDays days: Int = 30) -> [DashboardEvent] {
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: days, to: start) else { return [] }

        var events: [DashboardEvent] = []

        for deposit in deposits {
            guard let close = deposit.closeDate, close >= start, close <= end else { continue }
            events.append(DashboardEvent(
                id: deposit.id,
                date: close,
                title: deposit.title,
                amount: deposit.amount,
                currency: deposit.currency,
                kind: .depositClosing
            ))
        }

        for sub in activeSubscriptions {
            for date in paymentDates(for: sub, from: start, to: end) {
                events.append(DashboardEvent(
                    id: UUID(),
                    date: date,
                    title: sub.title,
                    amount: sub.amount,
                    currency: sub.currency,
                    kind: .subscriptionPayment
                ))
            }
        }

        return events.sorted { $0.date < $1.date }
    }

    // MARK: - Private helpers

    private func sum(
        _ entries: [(Double, DepositCurrency)],
        using converter: CurrencyConverter
    ) -> ConvertedTotal {
        var total = 0.0
        var missing: Set<DepositCurrency> = []

        for (amount, currency) in entries {
            if let converted = converter.convert(amount, from: currency) {
                total += converted
            } else if amount != 0 {
                missing.insert(currency)
            }
        }

        return ConvertedTotal(
            value: total,
            missing: missing.sorted { $0.rawValue < $1.rawValue }
        )
    }

    /// Mirrors the cadence logic in AnalyticsViewModel — capped at `endDate` for cancelled subscriptions.
    private func paymentDates(for sub: Subscription, from: Date, to: Date) -> [Date] {
        let effectiveTo = sub.endDate.map { min($0, to) } ?? to
        if !sub.billingCycle.isRecurring {
            return (sub.startDate >= from && sub.startDate <= effectiveTo) ? [sub.startDate] : []
        }
        var dates: [Date] = []
        var current = sub.startDate
        while current < from {
            current = Subscription.advance(current, by: sub.billingCycle, calendar: calendar)
        }
        while current <= effectiveTo {
            dates.append(current)
            current = Subscription.advance(current, by: sub.billingCycle, calendar: calendar)
        }
        return dates
    }
}
