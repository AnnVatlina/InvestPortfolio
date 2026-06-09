//
//  SubscriptionsService.swift
//

import Foundation

// MARK: - Protocol

protocol SubscriptionsService: Sendable {
    func fetchAll() async throws -> [Subscription]
    func add(_ subscription: Subscription) async throws
    func delete(id: UUID) async throws
    func update(
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
    ) async throws

    /// Cost normalized to one month
    func monthlyCost(for subscription: Subscription) -> Double
    /// Cost normalized to one year
    func annualCost(for subscription: Subscription) -> Double
    /// Total monthly cost across active subscriptions in given currency
    func totalMonthlyCost(in currency: DepositCurrency, subscriptions: [Subscription]) -> Double
    /// Total annual cost across active subscriptions in given currency
    func totalAnnualCost(in currency: DepositCurrency, subscriptions: [Subscription]) -> Double

    func upsert(
        serverId: UUID,
        title: String,
        amount: Double,
        currency: DepositCurrency,
        billingCycle: SubscriptionBillingCycle,
        startDate: Date,
        endDate: Date?,
        category: String?,
        iconName: String?,
        isActive: Bool,
        createdAt: Date
    ) async throws
    func deleteByServerId(_ serverId: UUID) async throws
}

// MARK: - Default implementation

final class DefaultSubscriptionsService: SubscriptionsService {
    private let repository: any SubscriptionsRepository

    init(repository: any SubscriptionsRepository) {
        self.repository = repository
    }

    func fetchAll() async throws -> [Subscription] {
        try await repository.fetchAll()
    }

    func add(_ subscription: Subscription) async throws {
        try await repository.add(subscription)
    }

    func delete(id: UUID) async throws {
        try await repository.delete(id: id)
    }

    func update(
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
    ) async throws {
        try await repository.update(
            id: id, title: title, amount: amount,
            currency: currency, billingCycle: billingCycle,
            startDate: startDate, category: category,
            iconName: iconName, isActive: isActive,
            endDate: endDate
        )
    }

    func monthlyCost(for subscription: Subscription) -> Double {
        switch subscription.billingCycle {
        case .weekly:    return subscription.amount * 52.0 / 12.0
        case .monthly:   return subscription.amount
        case .quarterly: return subscription.amount / 3.0
        case .yearly:    return subscription.amount / 12.0
        case .oneTime:   return 0  // не повторяется
        }
    }

    func annualCost(for subscription: Subscription) -> Double {
        switch subscription.billingCycle {
        case .weekly:    return subscription.amount * 52.0
        case .monthly:   return subscription.amount * 12.0
        case .quarterly: return subscription.amount * 4.0
        case .yearly:    return subscription.amount
        case .oneTime:   return 0  // не повторяется
        }
    }

    func totalMonthlyCost(in currency: DepositCurrency, subscriptions: [Subscription]) -> Double {
        subscriptions
            .filter { $0.isActive && $0.currency == currency && $0.billingCycle.isRecurring }
            .reduce(0.0) { $0 + monthlyCost(for: $1) }
    }

    func totalAnnualCost(in currency: DepositCurrency, subscriptions: [Subscription]) -> Double {
        subscriptions
            .filter { $0.isActive && $0.currency == currency && $0.billingCycle.isRecurring }
            .reduce(0.0) { $0 + annualCost(for: $1) }
    }

    func upsert(
        serverId: UUID,
        title: String,
        amount: Double,
        currency: DepositCurrency,
        billingCycle: SubscriptionBillingCycle,
        startDate: Date,
        endDate: Date?,
        category: String?,
        iconName: String?,
        isActive: Bool,
        createdAt: Date
    ) async throws {
        try await repository.upsert(
            serverId: serverId,
            title: title,
            amount: amount,
            currency: currency,
            billingCycle: billingCycle,
            startDate: startDate,
            endDate: endDate,
            category: category,
            iconName: iconName,
            isActive: isActive,
            createdAt: createdAt
        )
    }

    func deleteByServerId(_ serverId: UUID) async throws {
        try await repository.deleteByServerId(serverId)
    }
}
