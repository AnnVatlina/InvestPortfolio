//
//  DepositsRepository.swift
//
//  Created by Anna on 30.12.25.
//

import Foundation

protocol DepositsRepository {
    func fetchAll() async throws -> [Deposit]
    func add(_ deposit: Deposit) async throws
}

final class InMemoryDepositsRepository: DepositsRepository {
    private var storage: [Deposit] = []
    private let queue = DispatchQueue(label: "DepositsRepository.queue", qos: .userInitiated)

    func fetchAll() async throws -> [Deposit] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.storage)
            }
        }
    }

    func add(_ deposit: Deposit) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.storage.append(deposit)
                continuation.resume()
            }
        }
    }
}

