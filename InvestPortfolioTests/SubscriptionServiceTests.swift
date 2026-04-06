//
//  SubscriptionServiceTests.swift
//  InvestPortfolioTests
//
//  Integration tests for DefaultSubscriptionsService.
//  Uses InMemorySubscriptionsRepository so the service layer is tested
//  end-to-end against a real (in-memory) persistence layer.
//

import Testing
import Foundation
@testable import InvestPortfolio

// MARK: - Cost calculation tests

@Suite("DefaultSubscriptionsService — monthlyCost")
struct SubscriptionServiceMonthlyCostTests {

    let service = DefaultSubscriptionsService(repository: InMemorySubscriptionsRepository())

    private func sub(_ amount: Double, _ cycle: SubscriptionBillingCycle) -> Subscription {
        Subscription(title: "T", amount: amount, currency: .USD, billingCycle: cycle)
    }

    @Test func weeklyIsAmountTimes52Over12() {
        let result = service.monthlyCost(for: sub(12.0, .weekly))
        #expect(abs(result - 12.0 * 52 / 12) < 0.001)
    }

    @Test func monthlyEqualsAmount() {
        #expect(service.monthlyCost(for: sub(9.99, .monthly)) == 9.99)
    }

    @Test func quarterlyIsAmountDividedBy3() {
        #expect(service.monthlyCost(for: sub(30.0, .quarterly)) == 10.0)
    }

    @Test func yearlyIsAmountDividedBy12() {
        #expect(service.monthlyCost(for: sub(120.0, .yearly)) == 10.0)
    }

    @Test func oneTimeIsZero() {
        #expect(service.monthlyCost(for: sub(99.0, .oneTime)) == 0.0)
    }
}

@Suite("DefaultSubscriptionsService — annualCost")
struct SubscriptionServiceAnnualCostTests {

    let service = DefaultSubscriptionsService(repository: InMemorySubscriptionsRepository())

    private func sub(_ amount: Double, _ cycle: SubscriptionBillingCycle) -> Subscription {
        Subscription(title: "T", amount: amount, currency: .USD, billingCycle: cycle)
    }

    @Test func weeklyIsAmountTimes52() {
        #expect(service.annualCost(for: sub(10.0, .weekly)) == 520.0)
    }

    @Test func monthlyIsAmountTimes12() {
        #expect(abs(service.annualCost(for: sub(9.99, .monthly)) - 119.88) < 0.001)
    }

    @Test func quarterlyIsAmountTimes4() {
        #expect(service.annualCost(for: sub(30.0, .quarterly)) == 120.0)
    }

    @Test func yearlyEqualsAmount() {
        #expect(service.annualCost(for: sub(200.0, .yearly)) == 200.0)
    }

    @Test func oneTimeIsZero() {
        #expect(service.annualCost(for: sub(99.0, .oneTime)) == 0.0)
    }
}

// MARK: - Total cost aggregation tests

@Suite("DefaultSubscriptionsService — totalMonthlyCost")
struct SubscriptionServiceTotalMonthlyCostTests {

    let service = DefaultSubscriptionsService(repository: InMemorySubscriptionsRepository())

    private func sub(
        amount: Double,
        cycle: SubscriptionBillingCycle = .monthly,
        currency: DepositCurrency = .USD,
        isActive: Bool = true
    ) -> Subscription {
        Subscription(title: "T", amount: amount, currency: currency,
                     billingCycle: cycle, isActive: isActive)
    }

    @Test func sumsActiveRecurringInCurrency() {
        let subs = [sub(amount: 10), sub(amount: 20)]
        #expect(service.totalMonthlyCost(in: .USD, subscriptions: subs) == 30.0)
    }

    @Test func excludesInactiveSubscriptions() {
        let active   = sub(amount: 10, isActive: true)
        let inactive = sub(amount: 20, isActive: false)
        #expect(service.totalMonthlyCost(in: .USD, subscriptions: [active, inactive]) == 10.0)
    }

    @Test func excludesDifferentCurrency() {
        let usd = sub(amount: 10, currency: .USD)
        let eur = sub(amount: 20, currency: .EUR)
        #expect(service.totalMonthlyCost(in: .USD, subscriptions: [usd, eur]) == 10.0)
    }

    @Test func excludesOneTimeSubscriptions() {
        let recurring = sub(amount: 10, cycle: .monthly)
        let oneTime   = sub(amount: 50, cycle: .oneTime)
        #expect(service.totalMonthlyCost(in: .USD, subscriptions: [recurring, oneTime]) == 10.0)
    }

    @Test func returnsZeroWhenNoMatchingSubscriptions() {
        #expect(service.totalMonthlyCost(in: .USD, subscriptions: []) == 0.0)
    }

    @Test func mixedBillingCyclesAreNormalizedToMonthly() {
        let monthly   = sub(amount: 12.0, cycle: .monthly)   // → 12.0 / month
        let yearly    = sub(amount: 120.0, cycle: .yearly)   // → 10.0 / month
        let quarterly = sub(amount: 30.0, cycle: .quarterly) // → 10.0 / month
        let total = service.totalMonthlyCost(
            in: .USD, subscriptions: [monthly, yearly, quarterly]
        )
        #expect(abs(total - 32.0) < 0.001)
    }
}

@Suite("DefaultSubscriptionsService — totalAnnualCost")
struct SubscriptionServiceTotalAnnualCostTests {

    let service = DefaultSubscriptionsService(repository: InMemorySubscriptionsRepository())

    private func sub(
        amount: Double,
        cycle: SubscriptionBillingCycle = .monthly,
        currency: DepositCurrency = .USD,
        isActive: Bool = true
    ) -> Subscription {
        Subscription(title: "T", amount: amount, currency: currency,
                     billingCycle: cycle, isActive: isActive)
    }

    @Test func sumsMonthlyAndYearly() {
        let monthly = sub(amount: 10.0, cycle: .monthly)   // → 120 / year
        let yearly  = sub(amount: 120.0, cycle: .yearly)  // → 120 / year
        let total = service.totalAnnualCost(in: .USD, subscriptions: [monthly, yearly])
        #expect(abs(total - 240.0) < 0.001)
    }

    @Test func excludesOneTimeFromTotal() {
        let recurring = sub(amount: 10.0, cycle: .monthly)
        let oneTime   = sub(amount: 500.0, cycle: .oneTime)
        let total = service.totalAnnualCost(in: .USD, subscriptions: [recurring, oneTime])
        #expect(abs(total - 120.0) < 0.001)
    }
}

// MARK: - CRUD integration tests

@Suite("DefaultSubscriptionsService — CRUD")
struct SubscriptionServiceCRUDTests {

    var repo: InMemorySubscriptionsRepository
    var service: DefaultSubscriptionsService

    init() {
        repo = InMemorySubscriptionsRepository()
        service = DefaultSubscriptionsService(repository: repo)
    }

    @Test func addAndFetch() async throws {
        let sub = Subscription(title: "Netflix", amount: 9.99, currency: .USD, billingCycle: .monthly)
        try await service.add(sub)
        let all = try await service.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].title == "Netflix")
    }

    @Test func deleteRemovesItem() async throws {
        let sub = Subscription(title: "Spotify", amount: 4.99, currency: .USD, billingCycle: .monthly)
        try await service.add(sub)
        try await service.delete(id: sub.id)
        #expect(try await service.fetchAll().isEmpty)
    }

    @Test func updateChangesItemAndSetsEndDate() async throws {
        let sub = Subscription(title: "Old", amount: 5.0, currency: .USD, billingCycle: .monthly)
        try await service.add(sub)
        let endDate = Date()
        try await service.update(
            id: sub.id, title: "New", amount: 15.0,
            currency: .EUR, billingCycle: .yearly,
            startDate: sub.startDate, category: nil, iconName: nil,
            isActive: false, endDate: endDate
        )
        let updated = try #require(try await service.fetchAll().first)
        #expect(updated.title == "New")
        #expect(updated.isActive == false)
        #expect(updated.endDate != nil)
    }

    @Test func updateReactivationClearsEndDate() async throws {
        let sub = Subscription(
            title: "Paused", amount: 5.0, currency: .USD, billingCycle: .monthly,
            isActive: false, endDate: Date()
        )
        try await service.add(sub)
        try await service.update(
            id: sub.id, title: sub.title, amount: sub.amount,
            currency: sub.currency, billingCycle: sub.billingCycle,
            startDate: sub.startDate, category: nil, iconName: nil,
            isActive: true, endDate: nil
        )
        let updated = try #require(try await service.fetchAll().first)
        #expect(updated.isActive == true)
        #expect(updated.endDate == nil)
    }
}
