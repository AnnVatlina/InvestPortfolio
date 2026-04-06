//
//  SubscriptionsViewModel.swift
//

import Foundation
@preconcurrency import UserNotifications

// MARK: - Filter & Pagination types

enum SubscriptionStatusFilter: String, CaseIterable, Identifiable, Equatable {
    case all       = "all"
    case active    = "active"
    case cancelled = "cancelled"
    case paid      = "paid"
    var id: String { rawValue }
}

enum SubscriptionPageSize: Int, CaseIterable, Identifiable, Equatable {
    case five      = 5
    case ten       = 10
    case unlimited = 0  // show all
    var id: Int { rawValue }
}

// MARK: - ViewModel

@MainActor
final class SubscriptionsViewModel: ObservableObject {
    @Published private(set) var subscriptions: [Subscription] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Filter & pagination state
    @Published var statusFilter: SubscriptionStatusFilter = .all
    @Published var pageSize: SubscriptionPageSize = .ten
    @Published var currentPage: Int = 1

    private let service: any SubscriptionsService

    init(service: any SubscriptionsService) {
        self.service = service
    }

    // MARK: - Filter & pagination computed

    /// Subscriptions matching the current status filter, sorted appropriately.
    var filteredSubscriptions: [Subscription] {
        let now = Date()
        switch statusFilter {
        case .all:
            // Reverse chronological — most recently added first
            return subscriptions.sorted { $0.createdAt > $1.createdAt }
        case .active:
            // Keep the smart sort (by next payment date) applied in load()
            return subscriptions.filter { $0.isActive }
        case .cancelled:
            return subscriptions
                .filter { !$0.isActive }
                .sorted { ($0.endDate ?? $0.createdAt) > ($1.endDate ?? $1.createdAt) }
        case .paid:
            return subscriptions
                .filter { $0.isActive && !$0.billingCycle.isRecurring && $0.startDate <= now }
                .sorted { $0.startDate > $1.startDate }
        }
    }

    var totalFilteredCount: Int { filteredSubscriptions.count }

    var totalPages: Int {
        guard pageSize != .unlimited, pageSize.rawValue > 0 else { return 1 }
        return max(1, (totalFilteredCount + pageSize.rawValue - 1) / pageSize.rawValue)
    }

    /// Current page's slice of `filteredSubscriptions`.
    var pagedSubscriptions: [Subscription] {
        guard pageSize != .unlimited else { return filteredSubscriptions }
        let count = pageSize.rawValue
        let start = (currentPage - 1) * count
        guard start < filteredSubscriptions.count else { return [] }
        return Array(filteredSubscriptions[start..<min(start + count, filteredSubscriptions.count)])
    }

    func setFilter(_ filter: SubscriptionStatusFilter) {
        guard statusFilter != filter else { return }
        statusFilter = filter
        currentPage = 1
    }

    func setPageSize(_ size: SubscriptionPageSize) {
        guard pageSize != size else { return }
        pageSize = size
        currentPage = 1
    }

    // MARK: - Monthly payment chart data

    struct MonthlyPaymentPoint: Identifiable {
        let id = UUID()
        let month: Date       // first day of the month
        let currency: String
        let total: Double
    }

    /// All unique years covered by subscriptions (open → current year).
    var yearRange: ClosedRange<Int> {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        let startYears = subscriptions.map { cal.component(.year, from: $0.startDate) }
        let minYear = startYears.min() ?? currentYear
        return minYear...currentYear
    }

    /// Actual payment amounts per month for a given year (not normalized monthly cost).
    /// One-time purchases appear in the month of their startDate.
    func monthlyPayments(year: Int) -> [MonthlyPaymentPoint] {
        let cal = Calendar.current
        guard let yearStart = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
              let yearEnd   = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1))
        else { return [] }

        // Accumulate: [monthStart: [currency: total]]
        var acc: [Date: [String: Double]] = [:]

        // Include active subscriptions + cancelled ones that have an explicit end date recorded
        for sub in subscriptions where sub.isActive || sub.endDate != nil {
            let dates = paymentDates(for: sub, from: yearStart, to: yearEnd, calendar: cal)
            for date in dates {
                let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
                acc[monthStart, default: [:]][sub.currency.rawValue, default: 0] += sub.amount
            }
        }

        var points: [MonthlyPaymentPoint] = []
        for (month, byCurrency) in acc {
            for (currency, total) in byCurrency where total > 0 {
                points.append(MonthlyPaymentPoint(month: month, currency: currency, total: total))
            }
        }
        return points.sorted { $0.month < $1.month }
    }

    /// Monthly payment totals per month (sum across all currencies).
    func monthlyTotals(year: Int) -> [(month: Date, total: Double)] {
        let points = monthlyPayments(year: year)
        let grouped = Dictionary(grouping: points) { $0.month }
        return grouped.map { month, pts in
            (month: month, total: pts.reduce(0.0) { $0 + $1.total })
        }.sorted { $0.month < $1.month }
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let items = try await service.fetchAll()
            let now = Date()
            subscriptions = items.sorted { a, b in
                if a.isActive != b.isActive { return a.isActive }
                if a.isActive && b.isActive {
                    // One-time past purchases sink to the bottom
                    let aPast = !a.billingCycle.isRecurring && a.startDate < now
                    let bPast = !b.billingCycle.isRecurring && b.startDate < now
                    if aPast != bPast { return !aPast }
                    if aPast && bPast {
                        return a.title.localizedCompare(b.title) == .orderedAscending
                    }
                    return a.nextPaymentDate < b.nextPaymentDate
                }
                return a.title.localizedCompare(b.title) == .orderedAscending
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - CRUD

    func addSubscription(
        title: String,
        amount: Double,
        currency: DepositCurrency,
        billingCycle: SubscriptionBillingCycle,
        startDate: Date,
        category: String?,
        iconName: String?
    ) async {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = String(localized: "subscriptions.error.emptyTitle")
            return
        }
        let sub = Subscription(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            currency: currency,
            billingCycle: billingCycle,
            startDate: startDate,
            category: emptyToNil(category),
            iconName: emptyToNil(iconName)
        )
        do {
            try await service.add(sub)
            if billingCycle.isRecurring { scheduleNotification(for: sub) }
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSubscription(_ subscription: Subscription) async {
        cancelNotification(for: subscription)
        do {
            try await service.delete(id: subscription.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateSubscription(
        id: UUID,
        title: String,
        amount: Double,
        currency: DepositCurrency,
        billingCycle: SubscriptionBillingCycle,
        startDate: Date,
        category: String?,
        iconName: String?,
        isActive: Bool,
        endDate: Date?
    ) async {
        do {
            try await service.update(
                id: id,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                amount: amount,
                currency: currency,
                billingCycle: billingCycle,
                startDate: startDate,
                category: emptyToNil(category),
                iconName: emptyToNil(iconName),
                isActive: isActive,
                endDate: isActive ? nil : endDate
            )
            await load()
            if let updated = subscriptions.first(where: { $0.id == id }) {
                cancelNotification(for: updated)
                if updated.isActive && updated.billingCycle.isRecurring {
                    scheduleNotification(for: updated)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Business logic

    func monthlyCost(for subscription: Subscription) -> Double {
        service.monthlyCost(for: subscription)
    }

    func annualCost(for subscription: Subscription) -> Double {
        service.annualCost(for: subscription)
    }

    func totalMonthlyCost(in currency: DepositCurrency) -> Double {
        service.totalMonthlyCost(in: currency, subscriptions: subscriptions)
    }

    func totalAnnualCost(in currency: DepositCurrency) -> Double {
        service.totalAnnualCost(in: currency, subscriptions: subscriptions)
    }

    var activeCurrencies: [DepositCurrency] {
        Array(Set(subscriptions.filter { $0.isActive }.map { $0.currency }))
            .sorted { $0.rawValue < $1.rawValue }
    }

    /// Recurring subscriptions with nextPaymentDate within the next N days.
    func upcoming(withinDays days: Int = 7) -> [Subscription] {
        let now = Calendar.current.startOfDay(for: Date())
        guard let limit = Calendar.current.date(byAdding: .day, value: days, to: now) else { return [] }
        return subscriptions.filter { sub in
            guard sub.isActive else { return false }
            if sub.billingCycle.isRecurring {
                return sub.nextPaymentDate >= now && sub.nextPaymentDate <= limit
            } else {
                // One-time: show only if purchase date is still in the future
                return sub.startDate >= now && sub.startDate <= limit
            }
        }
        .sorted { $0.nextPaymentDate < $1.nextPaymentDate }
    }

    // MARK: - Notifications

    private func scheduleNotification(for subscription: Subscription) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "subscriptions.notification.title")
            content.body = String(format: String(localized: "subscriptions.notification.body.format"),
                                  subscription.title,
                                  String(format: "%.2f", subscription.amount),
                                  subscription.currency.rawValue)
            content.sound = .default

            let nextPayment = subscription.nextPaymentDate
            guard let triggerDate = Calendar.current.date(byAdding: .day, value: -1, to: nextPayment),
                  triggerDate > Date() else { return }
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: "subscription-\(subscription.id.uuidString)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    private func cancelNotification(for subscription: Subscription) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["subscription-\(subscription.id.uuidString)"])
    }

    // MARK: - Private helpers

    /// All payment dates for a subscription that fall within [from, to).
    /// For cancelled subscriptions with `endDate`, payments are capped at the end date.
    private func paymentDates(for sub: Subscription, from: Date, to: Date, calendar: Calendar) -> [Date] {
        // Cap the window at endDate for cancelled subscriptions
        let effectiveTo = sub.endDate.map { min($0, to) } ?? to
        if !sub.billingCycle.isRecurring {
            // One-time: appears only in the year it was purchased
            return (sub.startDate >= from && sub.startDate < effectiveTo) ? [sub.startDate] : []
        }
        var dates: [Date] = []
        var current = sub.startDate
        // Fast-forward to within range
        while current < from {
            current = Subscription.advance(current, by: sub.billingCycle, calendar: calendar)
        }
        while current < effectiveTo {
            dates.append(current)
            current = Subscription.advance(current, by: sub.billingCycle, calendar: calendar)
        }
        return dates
    }

    private func emptyToNil(_ s: String?) -> String? {
        s.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
    }
}
