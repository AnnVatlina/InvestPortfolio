//
//  SubscriptionsAPI.swift
//  InvestPortfolio
//
//  Rentivo subscriptions CRUD endpoints.
//

import Foundation

// MARK: - Protocol (enables mock injection in tests)

protocol SubscriptionsAPIProtocol: Sendable {
    func getSubscriptions() async throws -> [SubscriptionResponse]
    func createSubscription(_ body: SubscriptionCreate) async throws -> SubscriptionResponse
    func updateSubscription(id: UUID, _ body: SubscriptionUpdate) async throws -> SubscriptionResponse
    func deleteSubscription(id: UUID) async throws
}

// MARK: - Implementation

final class SubscriptionsAPI: SubscriptionsAPIProtocol {

    private let client: RentivoAPIClient

    init(client: RentivoAPIClient = .shared) {
        self.client = client
    }

    func getSubscriptions() async throws -> [SubscriptionResponse] {
        try await client.get(path: "/subscriptions")
    }

    func createSubscription(_ body: SubscriptionCreate) async throws -> SubscriptionResponse {
        try await client.post(path: "/subscriptions", body: body)
    }

    func updateSubscription(id: UUID, _ body: SubscriptionUpdate) async throws -> SubscriptionResponse {
        try await client.put(path: "/subscriptions/\(id.uuidString.lowercased())", body: body)
    }

    func deleteSubscription(id: UUID) async throws {
        try await client.delete(path: "/subscriptions/\(id.uuidString.lowercased())")
    }
}
