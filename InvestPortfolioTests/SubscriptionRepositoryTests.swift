//
//  SubscriptionRepositoryTests.swift
//  InvestPortfolioTests
//
//  Integration tests for SubscriptionsRepository implementations.
//  Tests InMemorySubscriptionsRepository and SwiftDataSubscriptionsRepository
//  against the same contract.
//

import Testing
import SwiftData
@testable import InvestPortfolio

// MARK: - Shared factory

private func makeSub(
    title: String = "Netflix",
    amount: Double = 9.99,
    currency: DepositCurrency = .USD,
    billingCycle: SubscriptionBillingCycle = .monthly,
    isActive: Bool = true,
    endDate: Date? = nil,
    createdAt: Date = Date()
) -> Subscription {
    Subscription(
        title: title, amount: amount, currency: currency,
        billingCycle: billingCycle, isActive: isActive,
        endDate: endDate, createdAt: createdAt
    )
}

// MARK: - InMemory tests

@Suite("InMemorySubscriptionsRepository")
struct InMemorySubscriptionsRepositoryTests {

    var repo: InMemorySubscriptionsRepository

    init() {
        repo = InMemorySubscriptionsRepository()
    }

    @Test func addThenFetchReturnsSubscription() async throws {
        try await repo.add(makeSub(title: "Netflix"))
        let all = try await repo.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].title == "Netflix")
    }

    @Test func addMultipleThenFetchReturnsAll() async throws {
        try await repo.add(makeSub(title: "A"))
        try await repo.add(makeSub(title: "B"))
        try await repo.add(makeSub(title: "C"))
        let all = try await repo.fetchAll()
        #expect(all.count == 3)
    }

    @Test func deleteRemovesSubscription() async throws {
        let sub = makeSub(title: "Spotify")
        try await repo.add(sub)
        try await repo.delete(id: sub.id)
        let all = try await repo.fetchAll()
        #expect(all.isEmpty)
    }

    @Test func deleteWithUnknownIdIsNoop() async throws {
        try await repo.add(makeSub())
        try await repo.delete(id: UUID())
        let all = try await repo.fetchAll()
        #expect(all.count == 1)
    }

    @Test func updateChangesAllFields() async throws {
        let sub = makeSub(title: "Old", amount: 5.0, currency: .USD, billingCycle: .monthly)
        try await repo.add(sub)
        let endDate = Date()
        try await repo.update(
            id: sub.id, title: "New", amount: 15.0,
            currency: .EUR, billingCycle: .yearly,
            startDate: sub.startDate, category: "Media", iconName: "tv",
            isActive: false, endDate: endDate
        )
        let updated = try #require(try await repo.fetchAll().first)
        #expect(updated.title == "New")
        #expect(updated.amount == 15.0)
        #expect(updated.currency == .EUR)
        #expect(updated.billingCycle == .yearly)
        #expect(updated.category == "Media")
        #expect(updated.iconName == "tv")
        #expect(updated.isActive == false)
        #expect(updated.endDate != nil)
    }

    @Test func updateClearsEndDateWhenReactivated() async throws {
        let endDate = Date()
        let sub = makeSub(isActive: false, endDate: endDate)
        try await repo.add(sub)
        try await repo.update(
            id: sub.id, title: sub.title, amount: sub.amount,
            currency: sub.currency, billingCycle: sub.billingCycle,
            startDate: sub.startDate, category: nil, iconName: nil,
            isActive: true, endDate: nil
        )
        let updated = try #require(try await repo.fetchAll().first)
        #expect(updated.isActive == true)
        #expect(updated.endDate == nil)
    }

    @Test func updateWithUnknownIdIsNoop() async throws {
        try await repo.add(makeSub(title: "Present"))
        try await repo.update(
            id: UUID(), title: "Ghost", amount: 0, currency: .USD,
            billingCycle: .monthly, startDate: Date(),
            category: nil, iconName: nil, isActive: true, endDate: nil
        )
        let all = try await repo.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].title == "Present")
    }

    @Test func fetchAllSortedByCreatedAtDescending() async throws {
        let older = makeSub(title: "Older", createdAt: Date(timeIntervalSinceNow: -200))
        let newer = makeSub(title: "Newer", createdAt: Date(timeIntervalSinceNow: -10))
        try await repo.add(older)
        try await repo.add(newer)
        let all = try await repo.fetchAll()
        #expect(all[0].title == "Newer")
        #expect(all[1].title == "Older")
    }
}

// MARK: - SwiftData tests

@Suite("SwiftDataSubscriptionsRepository")
struct SwiftDataSubscriptionsRepositoryTests {

    let container: ModelContainer
    let repo: SwiftDataSubscriptionsRepository

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Subscription.self, configurations: config)
        repo = SwiftDataSubscriptionsRepository(modelContainer: container)
    }

    @Test func addThenFetchReturnsSubscription() async throws {
        try await repo.add(makeSub(title: "Spotify"))
        let all = try await repo.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].title == "Spotify")
    }

    @Test func deleteRemovesSubscription() async throws {
        let sub = makeSub(title: "iCloud")
        try await repo.add(sub)
        try await repo.delete(id: sub.id)
        let all = try await repo.fetchAll()
        #expect(all.isEmpty)
    }

    @Test func updatePersistsChanges() async throws {
        let sub = makeSub(title: "Before", amount: 5.0)
        try await repo.add(sub)
        try await repo.update(
            id: sub.id, title: "After", amount: 20.0,
            currency: .EUR, billingCycle: .quarterly,
            startDate: sub.startDate, category: "Work", iconName: nil,
            isActive: false, endDate: Date()
        )
        let updated = try #require(try await repo.fetchAll().first)
        #expect(updated.title == "After")
        #expect(updated.amount == 20.0)
        #expect(updated.currency == .EUR)
        #expect(updated.isActive == false)
        #expect(updated.endDate != nil)
    }

    @Test func fetchAllSortedByCreatedAtDescending() async throws {
        let earlier = Subscription(
            title: "Early", amount: 1, currency: .USD, billingCycle: .monthly,
            createdAt: Date(timeIntervalSinceNow: -120)
        )
        let later = Subscription(
            title: "Late", amount: 2, currency: .USD, billingCycle: .monthly,
            createdAt: Date()
        )
        try await repo.add(earlier)
        try await repo.add(later)
        let all = try await repo.fetchAll()
        #expect(all.first?.title == "Late")
    }

    @Test func addMultipleAndDeleteOne() async throws {
        let a = makeSub(title: "Keep")
        let b = makeSub(title: "Delete")
        try await repo.add(a)
        try await repo.add(b)
        try await repo.delete(id: b.id)
        let all = try await repo.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].title == "Keep")
    }
}
