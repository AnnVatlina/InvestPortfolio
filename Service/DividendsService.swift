//
//  DividendsService.swift
//  InvestPortfolio
//

import Foundation

struct DividendImportSummary: Equatable {
    let addedCount: Int
    let duplicateCount: Int    // rows whose operation number was already imported
    let failedRowCount: Int    // rows the parser couldn't read at all
}

protocol DividendsService {
    func fetchAll() async throws -> [BrokerOperation]
    func importReport(fileURL: URL) async throws -> DividendImportSummary
    func deleteAll() async throws
}

final class DefaultDividendsService: DividendsService {
    private let repository: BrokerOperationsRepository

    init(repository: BrokerOperationsRepository) {
        self.repository = repository
    }

    func fetchAll() async throws -> [BrokerOperation] {
        try await repository.fetchAll()
    }

    /// Re-importing the same (or an overlapping) report is safe: rows whose operation
    /// number was already stored are counted as duplicates and skipped, never re-added.
    func importReport(fileURL: URL) async throws -> DividendImportSummary {
        let parsed = try DividendReportParser.parse(fileURL: fileURL)
        let existing = try await repository.existingOperationNumbers()

        let newOperations = parsed.operations.filter { !existing.contains($0.operationNumber) }
        if !newOperations.isEmpty {
            try await repository.addAll(newOperations)
        }

        return DividendImportSummary(
            addedCount: newOperations.count,
            duplicateCount: parsed.operations.count - newOperations.count,
            failedRowCount: parsed.failedRowCount
        )
    }

    func deleteAll() async throws {
        try await repository.deleteAll()
    }
}
