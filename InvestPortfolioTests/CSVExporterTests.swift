//
//  CSVExporterTests.swift
//  InvestPortfolioTests
//
//  Tests for CSVExporter — row formatting, RFC 4180 escaping, and temp file writing.
//

import Testing
import Foundation
@testable import InvestPortfolio

// MARK: - Helpers

private func dep(
    id: UUID = UUID(),
    title: String = "Deposit",
    bankName: String? = nil,
    amount: Double = 100_000,
    currency: DepositCurrency = .RUB,
    createdAt: Date = Date(),
    openDate: Date = Date(),
    closeDate: Date? = nil,
    rate: Double = 10.0,
    interestType: DepositInterestType = .simple,
    capitalizationPeriod: CapitalizationPeriod? = nil,
    allowsReplenishment: Bool = false,
    allowsPartialWithdrawal: Bool = false,
    isRevocable: Bool = true,
    earlyWithdrawalRate: Double? = nil
) -> Deposit {
    Deposit(id: id, title: title, bankName: bankName, amount: amount, currency: currency,
            createdAt: createdAt, openDate: openDate, closeDate: closeDate, annualInterestRate: rate,
            interestType: interestType, capitalizationPeriod: capitalizationPeriod,
            allowsReplenishment: allowsReplenishment, allowsPartialWithdrawal: allowsPartialWithdrawal,
            isRevocable: isRevocable, earlyWithdrawalRate: earlyWithdrawalRate)
}

private func transaction(
    id: UUID = UUID(),
    depositId: UUID = UUID(),
    date: Date = Date(),
    amount: Double = 1000
) -> DepositTransaction {
    DepositTransaction(id: id, depositId: depositId, date: date, amount: amount)
}

private func sub(
    id: UUID = UUID(),
    title: String = "Sub",
    amount: Double = 9.99,
    currency: DepositCurrency = .USD,
    cycle: SubscriptionBillingCycle = .monthly,
    startDate: Date = Date(),
    category: String? = nil,
    iconName: String? = nil,
    isActive: Bool = true,
    endDate: Date? = nil,
    createdAt: Date = Date()
) -> Subscription {
    Subscription(id: id, title: title, amount: amount, currency: currency, billingCycle: cycle,
                 startDate: startDate, category: category, iconName: iconName,
                 isActive: isActive, endDate: endDate, createdAt: createdAt)
}

// MARK: - Deposits

@Suite("CSVExporter — deposits")
struct CSVExporterDepositsTests {

    @Test("Header row matches the documented column order")
    func headerRow() {
        let csv = CSVExporter.csv(for: [Deposit]())
        #expect(csv == "ID,Title,Bank,Amount,Currency,OpenDate,CloseDate,AnnualRate%,CreatedAt,InterestType,CapitalizationPeriod,AllowsReplenishment,AllowsPartialWithdrawal,IsRevocable,EarlyWithdrawalRate")
    }

    @Test("Capitalized deposit with all flags set renders the extended columns")
    func extendedColumnsRenderCorrectly() {
        let d = dep(interestType: .capitalized, capitalizationPeriod: .quarterly,
                    allowsReplenishment: true, allowsPartialWithdrawal: true,
                    isRevocable: false, earlyWithdrawalRate: 1.5)
        let csv = CSVExporter.csv(for: [d])
        let fields = csv.components(separatedBy: "\n")[1].components(separatedBy: ",")
        #expect(fields[9] == "capitalized")
        #expect(fields[10] == "quarterly")
        #expect(fields[11] == "true")
        #expect(fields[12] == "true")
        #expect(fields[13] == "false")
        #expect(fields[14] == "1.5")
    }

    @Test("Simple, revocable deposit renders empty fields for the optional extended columns")
    func defaultExtendedColumnsRenderEmpty() {
        let d = dep()
        let csv = CSVExporter.csv(for: [d])
        let fields = csv.components(separatedBy: "\n")[1].components(separatedBy: ",")
        #expect(fields[9] == "simple")
        #expect(fields[10] == "")   // no capitalization period
        #expect(fields[11] == "false")
        #expect(fields[12] == "false")
        #expect(fields[13] == "true")
        #expect(fields[14] == "")  // no early-withdrawal rate
    }

    @Test("Row count equals header plus one line per deposit")
    func rowCountMatchesDepositCount() {
        let csv = CSVExporter.csv(for: [dep(), dep(), dep()])
        #expect(csv.components(separatedBy: "\n").count == 4)
    }

    @Test("Nil bankName and closeDate render as empty fields, not the literal word nil")
    func nilOptionalsRenderEmpty() {
        let d = dep(bankName: nil, closeDate: nil)
        let csv = CSVExporter.csv(for: [d])
        let row = csv.components(separatedBy: "\n")[1]
        let fields = row.components(separatedBy: ",")
        #expect(fields[2] == "")   // Bank
        #expect(fields[6] == "")   // CloseDate
    }

    @Test("Title containing a comma is quoted")
    func titleWithCommaIsQuoted() {
        let d = dep(title: "Cash, Savings")
        let csv = CSVExporter.csv(for: [d])
        #expect(csv.contains("\"Cash, Savings\""))
    }

    @Test("Title containing a double quote is escaped and wrapped")
    func titleWithQuoteIsEscaped() {
        let d = dep(title: "The \"Best\" Deposit")
        let csv = CSVExporter.csv(for: [d])
        #expect(csv.contains("\"The \"\"Best\"\" Deposit\""))
    }

    @Test("Plain title is not wrapped in quotes")
    func plainTitleUnquoted() {
        let d = dep(title: "Savings")
        let csv = CSVExporter.csv(for: [d])
        let row = csv.components(separatedBy: "\n")[1]
        #expect(row.hasPrefix(d.id.uuidString + ",Savings,"))
    }
}

// MARK: - Subscriptions

@Suite("CSVExporter — subscriptions")
struct CSVExporterSubscriptionsTests {

    @Test("Header row matches the documented column order")
    func headerRow() {
        let csv = CSVExporter.csv(for: [Subscription]())
        #expect(csv == "ID,Title,Category,Amount,Currency,BillingCycle,StartDate,EndDate,IsActive,CreatedAt")
    }

    @Test("isActive renders as lowercase true/false")
    func isActiveRendersAsLowercaseBool() {
        let active = sub(isActive: true)
        let cancelled = sub(isActive: false, endDate: Date())
        let csv = CSVExporter.csv(for: [active, cancelled])
        let rows = csv.components(separatedBy: "\n")
        #expect(rows[1].contains(",true,"))
        #expect(rows[2].contains(",false,"))
    }

    @Test("Category containing a comma is quoted")
    func categoryWithCommaIsQuoted() {
        let s = sub(category: "Music, Video")
        let csv = CSVExporter.csv(for: [s])
        #expect(csv.contains("\"Music, Video\""))
    }

    @Test("iconName is not present anywhere in the exported CSV")
    func iconNameIsDropped() {
        // Documents a real limitation: the CSV schema has no iconName column,
        // so exporting and re-importing a subscription always loses its custom icon.
        let s = sub(iconName: "gamecontroller.fill")
        let csv = CSVExporter.csv(for: [s])
        #expect(!csv.contains("gamecontroller.fill"))
    }
}

// MARK: - Deposit Transactions

@Suite("CSVExporter — deposit transactions")
struct CSVExporterTransactionsTests {

    @Test("Header row matches the documented column order")
    func headerRow() {
        let csv = CSVExporter.csv(for: [DepositTransaction]())
        #expect(csv == "ID,DepositID,Date,Amount")
    }

    @Test("Row count equals header plus one line per transaction")
    func rowCountMatchesTransactionCount() {
        let csv = CSVExporter.csv(for: [transaction(), transaction()])
        #expect(csv.components(separatedBy: "\n").count == 3)
    }

    @Test("A withdrawal's negative amount renders with a minus sign")
    func negativeAmountRendersCorrectly() {
        let t = transaction(amount: -500)
        let csv = CSVExporter.csv(for: [t])
        let fields = csv.components(separatedBy: "\n")[1].components(separatedBy: ",")
        #expect(fields[3] == "-500.0")
    }
}

// MARK: - File writing

@Suite("CSVExporter — writeToTempFile")
struct CSVExporterWriteToTempFileTests {

    @Test("Writes the exact CSV content to a file named as requested")
    func writesContentVerbatim() throws {
        let csv = "a,b,c\n1,2,3"
        let url = try #require(CSVExporter.writeToTempFile(csv, named: "test-\(UUID().uuidString).csv"))
        defer { try? FileManager.default.removeItem(at: url) }

        let readBack = try String(contentsOf: url, encoding: .utf8)
        #expect(readBack == csv)
    }

    @Test("Returned URL's last path component matches the requested filename")
    func urlUsesRequestedFilename() throws {
        let name = "custom-\(UUID().uuidString).csv"
        let url = try #require(CSVExporter.writeToTempFile("x", named: name))
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.lastPathComponent == name)
    }
}
