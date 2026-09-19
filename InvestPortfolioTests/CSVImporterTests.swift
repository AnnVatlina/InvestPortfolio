//
//  CSVImporterTests.swift
//  InvestPortfolioTests
//
//  Tests for CSVImporter — round-tripping CSVExporter output, malformed rows,
//  and two known limitations (documented, not yet fixed): subscriptions lose
//  their iconName on export, and a title/category containing a literal newline
//  corrupts that one row instead of round-tripping.
//

import Testing
import Foundation
@testable import InvestPortfolio

// MARK: - Helpers

/// ISO8601DateFormatter (as used by both CSVExporter and CSVImporter) only has
/// second precision, so round-trip fixtures must already be second-aligned or
/// equality checks will spuriously fail on sub-second noise.
private func wholeSecondDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, _ second: Int = 0) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
}

private func dep(
    id: UUID = UUID(),
    title: String = "Deposit",
    bankName: String? = nil,
    amount: Double = 100_000,
    currency: DepositCurrency = .RUB,
    createdAt: Date = wholeSecondDate(2026, 1, 1),
    openDate: Date = wholeSecondDate(2026, 1, 2),
    closeDate: Date? = nil,
    rate: Double = 10.0
) -> Deposit {
    Deposit(id: id, title: title, bankName: bankName, amount: amount, currency: currency,
            createdAt: createdAt, openDate: openDate, closeDate: closeDate, annualInterestRate: rate)
}

private func sub(
    id: UUID = UUID(),
    title: String = "Sub",
    amount: Double = 9.99,
    currency: DepositCurrency = .USD,
    cycle: SubscriptionBillingCycle = .monthly,
    startDate: Date = wholeSecondDate(2026, 1, 2),
    category: String? = nil,
    iconName: String? = nil,
    isActive: Bool = true,
    endDate: Date? = nil,
    createdAt: Date = wholeSecondDate(2026, 1, 1)
) -> Subscription {
    Subscription(id: id, title: title, amount: amount, currency: currency, billingCycle: cycle,
                 startDate: startDate, category: category, iconName: iconName,
                 isActive: isActive, endDate: endDate, createdAt: createdAt)
}

// MARK: - Deposits round-trip

@Suite("CSVImporter — deposits round-trip")
struct CSVImporterDepositsRoundTripTests {

    @Test("Every field survives export then import unchanged")
    func fullRoundTrip() {
        let original = dep(
            title: "Вклад «Сохраняй»", bankName: "Сбербанк", amount: 500_000.5, currency: .RUB,
            createdAt: wholeSecondDate(2026, 1, 10), openDate: wholeSecondDate(2026, 1, 15),
            closeDate: wholeSecondDate(2027, 1, 15), rate: 12.5
        )
        let result = CSVImporter.parseDeposits(CSVExporter.csv(for: [original]))
        #expect(result.failed == 0)
        let recovered = try! #require(result.items.first)

        #expect(recovered.id == original.id)
        #expect(recovered.title == original.title)
        #expect(recovered.bankName == original.bankName)
        #expect(abs(recovered.amount - original.amount) < 0.001)
        #expect(recovered.currency == original.currency)
        #expect(recovered.createdAt == original.createdAt)
        #expect(recovered.openDate == original.openDate)
        #expect(recovered.closeDate == original.closeDate)
        #expect(abs(recovered.annualInterestRate - original.annualInterestRate) < 0.001)
    }

    @Test("Nil bankName and closeDate round-trip as nil, not empty string")
    func nilOptionalsRoundTrip() {
        let original = dep(bankName: nil, closeDate: nil)
        let result = CSVImporter.parseDeposits(CSVExporter.csv(for: [original]))
        let recovered = try! #require(result.items.first)
        #expect(recovered.bankName == nil)
        #expect(recovered.closeDate == nil)
    }

    @Test("Title with an embedded comma round-trips intact")
    func titleWithCommaRoundTrips() {
        let original = dep(title: "Cash, Savings")
        let result = CSVImporter.parseDeposits(CSVExporter.csv(for: [original]))
        #expect(result.items.first?.title == "Cash, Savings")
    }

    @Test("Title with an embedded quote round-trips intact")
    func titleWithQuoteRoundTrips() {
        let original = dep(title: "The \"Best\" Deposit")
        let result = CSVImporter.parseDeposits(CSVExporter.csv(for: [original]))
        #expect(result.items.first?.title == "The \"Best\" Deposit")
    }

    @Test("Multiple deposits all round-trip, in order")
    func multipleDepositsRoundTrip() {
        let originals = [dep(title: "A"), dep(title: "B"), dep(title: "C")]
        let result = CSVImporter.parseDeposits(CSVExporter.csv(for: originals))
        #expect(result.failed == 0)
        #expect(result.items.map(\.title) == ["A", "B", "C"])
    }

    @Test("Empty title falls back to a placeholder instead of an empty string")
    func emptyTitleFallsBackToPlaceholder() {
        let original = dep(title: "")
        let result = CSVImporter.parseDeposits(CSVExporter.csv(for: [original]))
        #expect(result.items.first?.title == "—")
    }
}

// MARK: - Subscriptions round-trip

@Suite("CSVImporter — subscriptions round-trip")
struct CSVImporterSubscriptionsRoundTripTests {

    @Test("Every exported field survives round-trip except iconName")
    func fullRoundTripExceptIcon() {
        let original = sub(
            title: "Netflix", amount: 15.49, currency: .USD, cycle: .monthly,
            startDate: wholeSecondDate(2026, 2, 15), category: "Streaming",
            iconName: "tv.fill", isActive: true,
            createdAt: wholeSecondDate(2026, 1, 1)
        )
        let result = CSVImporter.parseSubscriptions(CSVExporter.csv(for: [original]))
        #expect(result.failed == 0)
        let recovered = try! #require(result.items.first)

        #expect(recovered.id == original.id)
        #expect(recovered.title == original.title)
        #expect(abs(recovered.amount - original.amount) < 0.001)
        #expect(recovered.currency == original.currency)
        #expect(recovered.billingCycle == original.billingCycle)
        #expect(recovered.startDate == original.startDate)
        #expect(recovered.category == original.category)
        #expect(recovered.isActive == original.isActive)
        #expect(recovered.createdAt == original.createdAt)
    }

    @Test("KNOWN LIMITATION: iconName is always nil after a round-trip, since CSV has no column for it")
    func iconNameIsLostOnRoundTrip() {
        let original = sub(iconName: "gamecontroller.fill")
        let result = CSVImporter.parseSubscriptions(CSVExporter.csv(for: [original]))
        #expect(result.items.first?.iconName == nil)
    }

    @Test("Cancelled subscription's endDate round-trips")
    func cancelledEndDateRoundTrips() {
        let original = sub(isActive: false, endDate: wholeSecondDate(2026, 6, 1))
        let result = CSVImporter.parseSubscriptions(CSVExporter.csv(for: [original]))
        let recovered = try! #require(result.items.first)
        #expect(recovered.isActive == false)
        #expect(recovered.endDate == wholeSecondDate(2026, 6, 1))
    }

    @Test("Nil category round-trips as nil, not empty string")
    func nilCategoryRoundTrips() {
        let original = sub(category: nil)
        let result = CSVImporter.parseSubscriptions(CSVExporter.csv(for: [original]))
        #expect(result.items.first?.category == nil)
    }
}

// MARK: - Malformed input

@Suite("CSVImporter — malformed rows")
struct CSVImporterMalformedRowsTests {

    @Test("Header-only CSV parses to zero items and zero failures")
    func headerOnlyIsEmpty() {
        let result = CSVImporter.parseDeposits("ID,Title,Bank,Amount,Currency,OpenDate,CloseDate,AnnualRate%,CreatedAt")
        #expect(result.items.isEmpty)
        #expect(result.failed == 0)
    }

    @Test("Invalid UUID marks the row as failed")
    func invalidUUIDFails() {
        let csv = "ID,Title,Bank,Amount,Currency,OpenDate,CloseDate,AnnualRate%,CreatedAt\n" +
                  "not-a-uuid,Title,Bank,100,RUB,2026-01-01T00:00:00Z,,10,2026-01-01T00:00:00Z"
        let result = CSVImporter.parseDeposits(csv)
        #expect(result.items.isEmpty)
        #expect(result.failed == 1)
    }

    @Test("Unknown currency code marks the row as failed")
    func unknownCurrencyFails() {
        let csv = "ID,Title,Bank,Amount,Currency,OpenDate,CloseDate,AnnualRate%,CreatedAt\n" +
                  "\(UUID().uuidString),Title,Bank,100,XYZ,2026-01-01T00:00:00Z,,10,2026-01-01T00:00:00Z"
        let result = CSVImporter.parseDeposits(csv)
        #expect(result.items.isEmpty)
        #expect(result.failed == 1)
    }

    @Test("Non-numeric amount marks the row as failed")
    func nonNumericAmountFails() {
        let csv = "ID,Title,Bank,Amount,Currency,OpenDate,CloseDate,AnnualRate%,CreatedAt\n" +
                  "\(UUID().uuidString),Title,Bank,not-a-number,RUB,2026-01-01T00:00:00Z,,10,2026-01-01T00:00:00Z"
        let result = CSVImporter.parseDeposits(csv)
        #expect(result.items.isEmpty)
        #expect(result.failed == 1)
    }

    @Test("Too few columns marks the row as failed rather than crashing")
    func tooFewColumnsFails() {
        let csv = "ID,Title,Bank,Amount,Currency,OpenDate,CloseDate,AnnualRate%,CreatedAt\n" +
                  "\(UUID().uuidString),Title,Bank"
        let result = CSVImporter.parseDeposits(csv)
        #expect(result.items.isEmpty)
        #expect(result.failed == 1)
    }

    @Test("Unknown billing cycle marks a subscription row as failed")
    func unknownBillingCycleFails() {
        let csv = "ID,Title,Category,Amount,Currency,BillingCycle,StartDate,EndDate,IsActive,CreatedAt\n" +
                  "\(UUID().uuidString),Netflix,,9.99,USD,biweekly,2026-01-01T00:00:00Z,,true,2026-01-01T00:00:00Z"
        let result = CSVImporter.parseSubscriptions(csv)
        #expect(result.items.isEmpty)
        #expect(result.failed == 1)
    }

    @Test("One bad row among good ones is skipped without affecting the others")
    func oneBadRowAmongGoodOnes() {
        let good1 = dep(title: "Good1")
        let good2 = dep(title: "Good2")
        var lines = CSVExporter.csv(for: [good1, good2]).components(separatedBy: "\n")
        lines.insert("garbage,row,too,few,columns", at: 1)
        let result = CSVImporter.parseDeposits(lines.joined(separator: "\n"))
        #expect(result.failed == 1)
        #expect(result.items.map(\.title) == ["Good1", "Good2"])
    }
}

// MARK: - Known limitation: embedded newlines

@Suite("CSVImporter — embedded newlines (known limitation)")
struct CSVImporterEmbeddedNewlineTests {

    @Test("KNOWN LIMITATION: a title containing a literal newline does not round-trip — the row is dropped and counted as failed")
    func titleWithNewlineIsDroppedNotCorrupted() {
        // CSVExporter correctly RFC4180-quotes the embedded newline, but CSVImporter's
        // line-splitter runs before the quote-aware row parser, so a quoted newline
        // is treated as a line break. The record is lost (counted as failed), but
        // this does not cascade into corrupting the deposits around it.
        let before = dep(title: "Before")
        let broken = dep(title: "Line1\nLine2")
        let after = dep(title: "After")

        let csv = CSVExporter.csv(for: [before, broken, after])
        let result = CSVImporter.parseDeposits(csv)

        #expect(result.failed > 0)
        #expect(result.items.map(\.title) == ["Before", "After"])
        #expect(!result.items.contains { $0.title.contains("Line1") })
    }
}
