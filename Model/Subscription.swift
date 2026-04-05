//
//  Subscription.swift
//

import Foundation
import SwiftData

@Model
final class Subscription {
    var id: UUID
    var title: String
    var amount: Double
    var currency: DepositCurrency
    var billingCycle: SubscriptionBillingCycle
    var startDate: Date
    var category: String?
    var iconName: String?        // SF Symbol name
    var isActive: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        currency: DepositCurrency,
        billingCycle: SubscriptionBillingCycle,
        startDate: Date = Date(),
        category: String? = nil,
        iconName: String? = nil,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.currency = currency
        self.billingCycle = billingCycle
        self.startDate = startDate
        self.category = category
        self.iconName = iconName
        self.isActive = isActive
        self.createdAt = createdAt
    }

    /// Next upcoming payment date.
    /// For one-time purchases this equals startDate (no future recurrence).
    var nextPaymentDate: Date {
        guard billingCycle.isRecurring else { return startDate }
        let cal = Calendar.current
        let now = cal.startOfDay(for: Date())
        let cycleStart = cal.startOfDay(for: startDate)
        guard cycleStart < now else { return startDate }
        var candidate = cycleStart
        while candidate < now {
            candidate = Self.advance(candidate, by: billingCycle, calendar: cal)
        }
        // Restore time-of-day from original startDate
        let t = cal.dateComponents([.hour, .minute, .second], from: startDate)
        return cal.date(bySettingHour: t.hour ?? 0, minute: t.minute ?? 0,
                        second: t.second ?? 0, of: candidate) ?? candidate
    }

    static func advance(_ date: Date, by cycle: SubscriptionBillingCycle, calendar: Calendar) -> Date {
        switch cycle {
        case .weekly:    return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .monthly:   return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarterly: return calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case .yearly:    return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        case .oneTime:   return date
        }
    }
}
