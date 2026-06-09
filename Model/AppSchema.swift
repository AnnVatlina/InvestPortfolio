//
//  AppSchema.swift
//  InvestPortfolio
//
//  SwiftData model for Subscription.
//  Add a new VersionedSchema + SchemaMigrationPlan here if stored properties ever change.
//

import Foundation
import SwiftData

@Model
final class Subscription {
    var id: UUID = UUID()
    var serverId: UUID?
    var title: String = ""
    var amount: Double = 0.0
    // Stored as String to avoid SwiftData lazy-load cast failure with custom enums (iOS 26)
    var currencyRaw: String = DepositCurrency.RUB.rawValue
    var billingCycleRaw: String = SubscriptionBillingCycle.monthly.rawValue
    var startDate: Date = Date()
    var category: String?
    var iconName: String?
    var isActive: Bool = true
    var endDate: Date?
    var createdAt: Date = Date()

    /// Typed accessor — computed, not stored by SwiftData.
    var currency: DepositCurrency {
        get { DepositCurrency(rawValue: currencyRaw) ?? .RUB }
        set { currencyRaw = newValue.rawValue }
    }

    /// Typed accessor — computed, not stored by SwiftData.
    var billingCycle: SubscriptionBillingCycle {
        get { SubscriptionBillingCycle(rawValue: billingCycleRaw) ?? .monthly }
        set { billingCycleRaw = newValue.rawValue }
    }

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
        endDate: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.currencyRaw = currency.rawValue
        self.billingCycleRaw = billingCycle.rawValue
        self.startDate = startDate
        self.category = category
        self.iconName = iconName
        self.isActive = isActive
        self.endDate = endDate
        self.createdAt = createdAt
    }
}
