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
}
