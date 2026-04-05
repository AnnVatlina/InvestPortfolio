//
//  Subscription.swift
//
//  Business logic extensions for Subscription (AppSchemaV2.Subscription).
//  Stored properties and the @Model definition live in AppSchema.swift.
//

import Foundation

extension Subscription {

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
