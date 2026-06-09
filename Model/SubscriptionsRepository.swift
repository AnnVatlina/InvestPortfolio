//
//  SubscriptionsRepository.swift
//

import Foundation
import SwiftData

// MARK: - Protocol

protocol SubscriptionsRepository: Sendable {
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

// MARK: - SwiftData implementation

@ModelActor
actor SwiftDataSubscriptionsRepository: @preconcurrency SubscriptionsRepository {

    func fetchAll() async throws -> [Subscription] {
        let descriptor = FetchDescriptor<Subscription>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func add(_ subscription: Subscription) async throws {
        modelContext.insert(subscription)
        try modelContext.save()
    }

    func delete(id: UUID) async throws {
        let predicate = #Predicate<Subscription> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let item = try modelContext.fetch(descriptor).first {
            modelContext.delete(item)
            try modelContext.save()
        }
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
        let predicate = #Predicate<Subscription> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        guard let item = try modelContext.fetch(descriptor).first else { return }
        item.title = title
        item.amount = amount
        item.currency = currency
        item.billingCycle = billingCycle
        item.startDate = startDate
        item.category = category
        item.iconName = iconName
        item.isActive = isActive
        item.endDate = endDate
        try modelContext.save()
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
        let predicate = #Predicate<Subscription> { $0.serverId == serverId }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let existing = try modelContext.fetch(descriptor).first {
            existing.title = title
            existing.amount = amount
            existing.currency = currency
            existing.billingCycle = billingCycle
            existing.startDate = startDate
            existing.endDate = endDate
            existing.category = category
            existing.iconName = iconName
            existing.isActive = isActive
        } else {
            let sub = Subscription(
                title: title,
                amount: amount,
                currency: currency,
                billingCycle: billingCycle,
                startDate: startDate,
                category: category,
                iconName: iconName,
                isActive: isActive,
                endDate: endDate,
                createdAt: createdAt
            )
            sub.serverId = serverId
            modelContext.insert(sub)
        }
        try modelContext.save()
    }

    func deleteByServerId(_ serverId: UUID) async throws {
        let predicate = #Predicate<Subscription> { $0.serverId == serverId }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let item = try modelContext.fetch(descriptor).first {
            modelContext.delete(item)
            try modelContext.save()
        }
    }
}

// MARK: - In-memory implementation (previews / tests)

final class InMemorySubscriptionsRepository: @unchecked Sendable, SubscriptionsRepository {
    private var items: [Subscription] = []

    func fetchAll() async throws -> [Subscription] {
        items.sorted { $0.createdAt > $1.createdAt }
    }

    func add(_ subscription: Subscription) async throws {
        items.append(subscription)
    }

    func delete(id: UUID) async throws {
        items.removeAll { $0.id == id }
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
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].title = title
        items[index].amount = amount
        items[index].currency = currency
        items[index].billingCycle = billingCycle
        items[index].startDate = startDate
        items[index].category = category
        items[index].iconName = iconName
        items[index].isActive = isActive
        items[index].endDate = endDate
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
        if let index = items.firstIndex(where: { $0.serverId == serverId }) {
            items[index].title = title
            items[index].amount = amount
            items[index].currency = currency
            items[index].billingCycle = billingCycle
            items[index].startDate = startDate
            items[index].endDate = endDate
            items[index].category = category
            items[index].iconName = iconName
            items[index].isActive = isActive
        } else {
            let sub = Subscription(
                title: title,
                amount: amount,
                currency: currency,
                billingCycle: billingCycle,
                startDate: startDate,
                category: category,
                iconName: iconName,
                isActive: isActive,
                endDate: endDate,
                createdAt: createdAt
            )
            sub.serverId = serverId
            items.append(sub)
        }
    }

    func deleteByServerId(_ serverId: UUID) async throws {
        items.removeAll { $0.serverId == serverId }
    }
}
