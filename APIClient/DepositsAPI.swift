//
//  DepositsAPI.swift
//  InvestPortfolio
//
//  Rentivo deposits CRUD endpoints.
//

import Foundation

// MARK: - Protocol (enables mock injection in tests)

protocol DepositsAPIProtocol: Sendable {
    func getDeposits() async throws -> [DepositResponse]
    func createDeposit(_ body: DepositCreate) async throws -> DepositResponse
    func updateDeposit(id: UUID, _ body: DepositUpdate) async throws -> DepositResponse
    func deleteDeposit(id: UUID) async throws
}

// MARK: - Implementation

final class DepositsAPI: DepositsAPIProtocol {

    private let client: RentivoAPIClient

    init(client: RentivoAPIClient = .shared) {
        self.client = client
    }

    func getDeposits() async throws -> [DepositResponse] {
        try await client.get(path: "/deposits")
    }

    func createDeposit(_ body: DepositCreate) async throws -> DepositResponse {
        try await client.post(path: "/deposits", body: body)
    }

    func updateDeposit(id: UUID, _ body: DepositUpdate) async throws -> DepositResponse {
        try await client.put(path: "/deposits/\(id.uuidString.lowercased())", body: body)
    }

    func deleteDeposit(id: UUID) async throws {
        try await client.delete(path: "/deposits/\(id.uuidString.lowercased())")
    }
}
