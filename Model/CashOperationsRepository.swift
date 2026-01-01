//
//  CashOperationsRepository.swift
//  InvestPortfolio
//
//  Created by Anna on 04.04.26.
//

import Foundation
import SwiftData

protocol CashOperationsRepository {
    func fetchAll() async throws -> [CashOperation]
    func replaceAll(with operations: [CashOperation]) async throws
    func cacheAge() async throws -> TimeInterval?
}

@ModelActor
actor SwiftDataCashOperationsRepository: CashOperationsRepository {
    func fetchAll() async throws -> [CashOperation] {
        let descriptor = FetchDescriptor<CashOperation>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func replaceAll(with operations: [CashOperation]) async throws {
        try modelContext.delete(model: CashOperation.self)
        for op in operations {
            modelContext.insert(op)
        }
        try modelContext.save()
    }

    func cacheAge() async throws -> TimeInterval? {
        var descriptor = FetchDescriptor<CashOperation>(
            sortBy: [SortDescriptor(\.fetchedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let latest = try modelContext.fetch(descriptor).first else { return nil }
        return Date().timeIntervalSince(latest.fetchedAt)
    }
}
