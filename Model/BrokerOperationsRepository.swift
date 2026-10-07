//
//  BrokerOperationsRepository.swift
//  InvestPortfolio
//

import Foundation
import SwiftData

protocol BrokerOperationsRepository {
    func fetchAll() async throws -> [BrokerOperation]
    func addAll(_ operations: [BrokerOperation]) async throws
    func deleteAll() async throws

    /// Operation numbers already stored locally — used by the import service to skip
    /// rows that were already imported, so re-importing the same report is a no-op.
    func existingOperationNumbers() async throws -> Set<Int>
}

final class InMemoryBrokerOperationsRepository: BrokerOperationsRepository {
    private var operations: [BrokerOperation] = []

    func fetchAll() async throws -> [BrokerOperation] {
        operations.sorted { $0.date > $1.date }
    }

    func addAll(_ operations: [BrokerOperation]) async throws {
        self.operations.append(contentsOf: operations)
    }

    func deleteAll() async throws {
        operations.removeAll()
    }

    func existingOperationNumbers() async throws -> Set<Int> {
        Set(operations.map(\.operationNumber))
    }
}

@ModelActor
actor SwiftDataBrokerOperationsRepository: @preconcurrency BrokerOperationsRepository {
    func fetchAll() async throws -> [BrokerOperation] {
        let descriptor = FetchDescriptor<BrokerOperation>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func addAll(_ operations: [BrokerOperation]) async throws {
        operations.forEach { modelContext.insert($0) }
        try modelContext.save()
    }

    func deleteAll() async throws {
        let all = try modelContext.fetch(FetchDescriptor<BrokerOperation>())
        all.forEach { modelContext.delete($0) }
        try modelContext.save()
    }

    func existingOperationNumbers() async throws -> Set<Int> {
        let all = try modelContext.fetch(FetchDescriptor<BrokerOperation>())
        return Set(all.map(\.operationNumber))
    }
}
