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
    var title: String = ""
    var amount: Double = 0.0
    var currency: DepositCurrency = DepositCurrency.RUB
    var billingCycle: SubscriptionBillingCycle = SubscriptionBillingCycle.monthly
    var startDate: Date = Date()
    var category: String?
    var iconName: String?
    var isActive: Bool = true
    var endDate: Date?             // Date the subscription was cancelled
    var createdAt: Date = Date()

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
        self.currency = currency
        self.billingCycle = billingCycle
        self.startDate = startDate
        self.category = category
        self.iconName = iconName
        self.isActive = isActive
        self.endDate = endDate
        self.createdAt = createdAt
    }
}
