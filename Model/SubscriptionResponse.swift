//
//  SubscriptionResponse.swift
//  InvestPortfolio
//
//  Codable DTOs for the Rentivo subscriptions API.
//  Amounts arrive as strings; dates as "yyyy-MM-dd" strings decoded via the
//  custom RentivoAPIClient date decoder.
//

import Foundation

// MARK: - API Response DTO

struct SubscriptionResponse: Decodable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let amount: String
    let currency: String
    let billingCycle: String
    let startDate: Date
    let endDate: Date?
    let category: String?
    let iconName: String?
    let isActive: Bool
    let createdAt: Date

    var amountDouble: Double { Double(amount) ?? 0 }
    var depositCurrency: DepositCurrency { DepositCurrency(rawValue: currency) ?? .RUB }
    var subscriptionBillingCycle: SubscriptionBillingCycle {
        SubscriptionBillingCycle(rawValue: billingCycle) ?? .monthly
    }
}

// MARK: - Request bodies

private let subscriptionDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    return f
}()

struct SubscriptionCreate: Encodable {
    let title: String
    let amount: String
    let currency: String
    let billingCycle: String
    let startDate: String
    let endDate: String?
    let category: String?
    let iconName: String?
}

struct SubscriptionUpdate: Encodable {
    let title: String
    let amount: String
    let currency: String
    let billingCycle: String
    let startDate: String
    let endDate: String?
    let category: String?
    let iconName: String?
    let isActive: Bool
}

// MARK: - Factory helpers

extension SubscriptionCreate {
    init(
        title: String,
        amount: Double,
        currency: DepositCurrency,
        billingCycle: SubscriptionBillingCycle,
        startDate: Date,
        category: String?,
        iconName: String?
    ) {
        self.title = title
        self.amount = String(amount)
        self.currency = currency.rawValue
        self.billingCycle = billingCycle.rawValue
        self.startDate = subscriptionDateFormatter.string(from: startDate)
        self.endDate = nil
        self.category = category
        self.iconName = iconName
    }

    init(from subscription: Subscription) {
        self.title = subscription.title
        self.amount = String(subscription.amount)
        self.currency = subscription.currency.rawValue
        self.billingCycle = subscription.billingCycle.rawValue
        self.startDate = subscriptionDateFormatter.string(from: subscription.startDate)
        self.endDate = subscription.endDate.map { subscriptionDateFormatter.string(from: $0) }
        self.category = subscription.category
        self.iconName = subscription.iconName
    }
}

extension SubscriptionUpdate {
    init(
        title: String,
        amount: Double,
        currency: DepositCurrency,
        billingCycle: SubscriptionBillingCycle,
        startDate: Date,
        endDate: Date?,
        category: String?,
        iconName: String?,
        isActive: Bool
    ) {
        self.title = title
        self.amount = String(amount)
        self.currency = currency.rawValue
        self.billingCycle = billingCycle.rawValue
        self.startDate = subscriptionDateFormatter.string(from: startDate)
        self.endDate = endDate.map { subscriptionDateFormatter.string(from: $0) }
        self.category = category
        self.iconName = iconName
        self.isActive = isActive
    }
}
