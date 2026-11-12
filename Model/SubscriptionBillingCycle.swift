//
//  SubscriptionBillingCycle.swift
//

import Foundation

enum SubscriptionBillingCycle: String, CaseIterable, Codable, Equatable, Identifiable {
    case weekly    = "weekly"
    case monthly   = "monthly"
    case quarterly = "quarterly"
    case yearly    = "yearly"
    case oneTime   = "oneTime"   // one-time purchase

    var id: String { rawValue }

    /// True for subscriptions that repeat on a schedule.
    var isRecurring: Bool { self != .oneTime }

    /// Multiplier that turns one payment into its average monthly cost.
    /// One-time purchases have no recurring cost, so they contribute 0.
    var monthlyFactor: Double {
        switch self {
        case .weekly:    return 52.0 / 12.0
        case .monthly:   return 1
        case .quarterly: return 1.0 / 3.0
        case .yearly:    return 1.0 / 12.0
        case .oneTime:   return 0
        }
    }
}
