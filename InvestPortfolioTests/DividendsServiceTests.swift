//
//  DividendsServiceTests.swift
//  InvestPortfolioTests
//
//  Importing a report is idempotent: rows whose operation number is already stored are
//  counted as duplicates and never re-added. The fixture report (see
//  DividendReportParserTests) has 4 valid rows, numbered 100001...100004, and 1 unreadable row.
//

import Testing
import Foundation
import SwiftData
@testable import InvestPortfolio

// MARK: - Helpers

private func existingOperation(number: Int) -> BrokerOperation {
    BrokerOperation(
        operationNumber: number,
        date: Date(),
        type: .dividend,
        rawOperationLabel: "Дивиденды",
        comment: "already imported",
        amount: 1,
        currency: .USD
    )
}

// MARK: - In-memory repository

@Suite("DividendsService — import without duplicates")
struct DividendsServiceImportTests {

    @Test("First import adds every readable row")
    func firstImportAddsAll() async throws {
        let service = DefaultDividendsService(repository: InMemoryBrokerOperationsRepository())
        let summary = try await service.importReport(fileURL: makeFixtureReportURL())

        #expect(summary == DividendImportSummary(addedCount: 4, duplicateCount: 0, failedRowCount: 1))
        #expect(try await service.fetchAll().count == 4)
    }

    @Test("Re-importing the same report adds nothing and stores no second copy")
    func reimportIsNoOp() async throws {
        let service = DefaultDividendsService(repository: InMemoryBrokerOperationsRepository())
        let file = try makeFixtureReportURL()
        _ = try await service.importReport(fileURL: file)

        let second = try await service.importReport(fileURL: file)

        #expect(second == DividendImportSummary(addedCount: 0, duplicateCount: 4, failedRowCount: 1))
        let stored = try await service.fetchAll()
        #expect(stored.count == 4)
        #expect(Set(stored.map(\.operationNumber)).count == 4)
    }

    @Test("Overlapping report: only rows not already stored are added")
    func overlappingReportAddsOnlyNewRows() async throws {
        let repo = InMemoryBrokerOperationsRepository()
        try await repo.addAll([existingOperation(number: 100001), existingOperation(number: 100003)])
        let service = DefaultDividendsService(repository: repo)

        let summary = try await service.importReport(fileURL: makeFixtureReportURL())

        #expect(summary.addedCount == 2)
        #expect(summary.duplicateCount == 2)
        #expect(Set(try await service.fetchAll().map(\.operationNumber)) == [100001, 100002, 100003, 100004])
    }

    @Test("A stored row is kept as-is, not overwritten by the re-imported one")
    func existingRowIsNotOverwritten() async throws {
        let repo = InMemoryBrokerOperationsRepository()
        try await repo.addAll([existingOperation(number: 100001)])
        let service = DefaultDividendsService(repository: repo)

        _ = try await service.importReport(fileURL: makeFixtureReportURL())

        let kept = try #require(try await service.fetchAll().first { $0.operationNumber == 100001 })
        #expect(kept.comment == "already imported")
    }

    @Test("After deleteAll the same report imports in full again")
    func importAfterDeleteAll() async throws {
        let service = DefaultDividendsService(repository: InMemoryBrokerOperationsRepository())
        let file = try makeFixtureReportURL()
        _ = try await service.importReport(fileURL: file)
        try await service.deleteAll()

        let summary = try await service.importReport(fileURL: file)

        #expect(summary.addedCount == 4)
        #expect(summary.duplicateCount == 0)
    }
}

// MARK: - SwiftData repository

@Suite("DividendsService — import without duplicates (SwiftData)")
struct DividendsServiceSwiftDataImportTests {

    @Test("Re-import against the real SwiftData repository stores each row once")
    func reimportStoresEachRowOnce() async throws {
        let container = try ModelContainer(
            for: AppModels.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let service = DefaultDividendsService(
            repository: SwiftDataBrokerOperationsRepository(modelContainer: container)
        )
        let file = try makeFixtureReportURL()

        let first = try await service.importReport(fileURL: file)
        let second = try await service.importReport(fileURL: file)

        #expect(first.addedCount == 4)
        #expect(second.addedCount == 0)
        #expect(second.duplicateCount == 4)
        #expect(try await service.fetchAll().count == 4)
    }
}
