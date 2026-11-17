//
//  StoreRecoveryTests.swift
//  InvestPortfolioTests
//
//  The store must never be deleted when it fails to open, and an older on-disk store
//  must open with the current schema without losing data.
//

import Testing
import Foundation
import SwiftData
@testable import InvestPortfolio

// MARK: - Helpers

private func makeTempDir() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("StoreRecoveryTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

// MARK: - Backup

@Suite("StoreRecovery — backUpStore")
struct StoreRecoveryBackupTests {

    @Test("Store and its -shm/-wal sidecars are moved, not deleted")
    func movesAllFiles() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = dir.appendingPathComponent("default.store")
        for suffix in ["", "-shm", "-wal"] {
            try "data\(suffix)".write(toFile: store.path + suffix, atomically: true, encoding: .utf8)
        }

        let backup = try #require(try StoreRecovery.backUpStore(at: store))

        for suffix in ["", "-shm", "-wal"] {
            #expect(!FileManager.default.fileExists(atPath: store.path + suffix))
            let moved = try String(contentsOfFile: backup.path + suffix, encoding: .utf8)
            #expect(moved == "data\(suffix)")
        }
        #expect(backup.lastPathComponent.hasPrefix("default.store.backup-"))
    }

    @Test("No store file → nothing to back up")
    func missingStoreReturnsNil() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = dir.appendingPathComponent("default.store")
        #expect(try StoreRecovery.backUpStore(at: store) == nil)
    }

    @Test("Notice survives a round trip through its raw string")
    func noticeRoundTrip() {
        let backedUp = StoreRecovery.Notice.backedUp(fileName: "default.store.backup-20261117-101500")
        #expect(StoreRecovery.Notice(rawValue: backedUp.rawValue) == backedUp)
        #expect(StoreRecovery.Notice(rawValue: StoreRecovery.Notice.unavailable.rawValue) == .unavailable)
        #expect(StoreRecovery.Notice(rawValue: "") == nil)
    }
}

// MARK: - Migration

/// The Deposit shape from before interest types, transactions and revocability were added.
private enum LegacySchema {
    @Model
    final class Deposit {
        var id: UUID
        var title: String
        var bankName: String?
        var amount: Double
        var currencyRaw: String
        var createdAt: Date
        var openDate: Date
        var closeDate: Date?
        var annualInterestRate: Double

        init(title: String, amount: Double) {
            self.id = UUID()
            self.title = title
            self.bankName = nil
            self.amount = amount
            self.currencyRaw = DepositCurrency.USD.rawValue
            self.createdAt = Date()
            self.openDate = Date()
            self.closeDate = nil
            self.annualInterestRate = 5
        }
    }
}

@Suite("Store migration")
struct StoreMigrationTests {

    @Test("A store written by an older schema opens with the current schema, data intact")
    func legacyStoreOpensWithCurrentSchema() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("default.store")

        // Write with the old schema, then release that container before reopening.
        do {
            let legacy = try ModelContainer(
                for: Schema([LegacySchema.Deposit.self]),
                configurations: ModelConfiguration(url: url)
            )
            let context = ModelContext(legacy)
            context.insert(LegacySchema.Deposit(title: "Old deposit", amount: 1234))
            try context.save()
        }

        let current = try ModelContainer(
            for: AppModels.schema,
            configurations: ModelConfiguration(url: url)
        )
        let deposits = try ModelContext(current).fetch(FetchDescriptor<Deposit>())

        #expect(deposits.count == 1)
        #expect(deposits.first?.title == "Old deposit")
        #expect(deposits.first?.amount == 1234)
        // Columns added since then take their declared defaults.
        #expect(deposits.first?.interestType == .simple)
        #expect(deposits.first?.isRevocable == true)
    }
}
