//
//  DividendReportParserTests.swift
//  InvestPortfolioTests
//
//  Builds a minimal .xlsx fixture in memory (via ZIPFoundation's writer) that mirrors
//  the real Freedom24 report layout reverse-engineered in Docs/dividends-feature.md,
//  rather than bundling the real binary file as a project resource.
//

import Testing
import Foundation
import ZIPFoundation
@testable import InvestPortfolio

// MARK: - Fixture

/// Shared strings referenced by index from the sheet fixture below.
private let fixtureSharedStrings = [
    "Операция №", "Дата", "Операция", "Комментарий", "Сумма", "Валюта",  // 0-5: header
    "Дивиденды", "dividend comment", "USD",                              // 6-8
    "Налоги", "tax comment",                                             // 9-10
    " Комиссия за сделки ", "commission comment",                        // 11-12
    "НеизвестныйТип", "other comment"                                    // 13-14
]

private let fixtureSheetXML = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<sheetData>
<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="C1" t="s"><v>2</v></c><c r="D1" t="s"><v>3</v></c><c r="E1" t="s"><v>4</v></c><c r="F1" t="s"><v>5</v></c></row>
<row r="2"><c r="A2"><v>100001</v></c><c r="B2"><v>46301.5</v></c><c r="C2" t="s"><v>6</v></c><c r="D2" t="s"><v>7</v></c><c r="E2"><v>7.14</v></c><c r="F2" t="s"><v>8</v></c></row>
<row r="3"><c r="A3"><v>100002</v></c><c r="B3"><v>46301.5</v></c><c r="C3" t="s"><v>9</v></c><c r="D3" t="s"><v>10</v></c><c r="E3"><v>-2.14</v></c><c r="F3" t="s"><v>8</v></c></row>
<row r="4"><c r="A4"><v>100003</v></c><c r="B4"><v>46268.65</v></c><c r="C4" t="s"><v>11</v></c><c r="D4" t="s"><v>12</v></c><c r="E4"><v>-2.18</v></c><c r="F4" t="s"><v>8</v></c></row>
<row r="5"><c r="A5"><v>100004</v></c><c r="B5"><v>46200.0</v></c><c r="C5" t="s"><v>13</v></c><c r="D5" t="s"><v>14</v></c><c r="E5"><v>5.00</v></c><c r="F5" t="s"><v>8</v></c></row>
<row r="6"><c r="A6"><v>100005</v></c><c r="B6"><v>46200.0</v></c><c r="C6" t="s"><v>6</v></c><c r="D6" t="s"><v>7</v></c><c r="F6" t="s"><v>8</v></c></row>
</sheetData>
</worksheet>
"""

private func fixtureSharedStringsXML() -> String {
    let items = fixtureSharedStrings.map { "<si><t xml:space=\"preserve\">\($0)</t></si>" }.joined()
    return """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="\(fixtureSharedStrings.count)" uniqueCount="\(fixtureSharedStrings.count)">\(items)</sst>
    """
}

/// Zips the two XML fixtures together into a throwaway .xlsx — our parser only ever
/// looks up these two paths by name, so no other OOXML scaffolding is needed.
private func makeFixtureReportURL() throws -> URL {
    let archiveURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".xlsx")
    let archive = try Archive(url: archiveURL, accessMode: .create)

    func addXML(_ xml: String, at path: String) throws {
        let data = Data(xml.utf8)
        try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count)) { position, size in
            data.subdata(in: Int(position)..<Int(position) + size)
        }
    }
    try addXML(fixtureSharedStringsXML(), at: "xl/sharedStrings.xml")
    try addXML(fixtureSheetXML, at: "xl/worksheets/sheet1.xml")
    return archiveURL
}

/// Compares a parsed Date to expected UTC calendar components — avoids relying on
/// exact floating-point equality for the Excel-serial-date conversion.
private func assertUTCDate(_ date: Date, year: Int, month: Int, day: Int, hour: Int, minute: Int) {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    #expect(components.year == year)
    #expect(components.month == month)
    #expect(components.day == day)
    #expect(components.hour == hour)
    #expect(components.minute == minute)
}

// MARK: - Tests

@Suite struct DividendReportParserTests {

    @Test func parsesKnownOperationTypes() throws {
        let result = try DividendReportParser.parse(fileURL: makeFixtureReportURL())

        #expect(result.operations.count == 4)
        #expect(result.failedRowCount == 1)   // row 6 is missing its amount cell

        let dividend = try #require(result.operations.first { $0.operationNumber == 100001 })
        #expect(dividend.type == .dividend)
        #expect(dividend.comment == "dividend comment")
        #expect(dividend.amount == Decimal(string: "7.14"))
        #expect(dividend.currency == .USD)
        assertUTCDate(dividend.date, year: 2026, month: 10, day: 6, hour: 12, minute: 0)

        let tax = try #require(result.operations.first { $0.operationNumber == 100002 })
        #expect(tax.type == .tax)
        #expect(tax.amount == Decimal(string: "-2.14"))

        let commission = try #require(result.operations.first { $0.operationNumber == 100003 })
        #expect(commission.type == .commission)
        #expect(commission.amount == Decimal(string: "-2.18"))
        assertUTCDate(commission.date, year: 2026, month: 9, day: 3, hour: 15, minute: 36)
    }

    @Test func unrecognizedOperationLabelImportsAsOtherInsteadOfBeingDropped() throws {
        let result = try DividendReportParser.parse(fileURL: makeFixtureReportURL())

        let other = try #require(result.operations.first { $0.operationNumber == 100004 })
        #expect(other.type == .other)
        #expect(other.rawOperationLabel == "НеизвестныйТип")   // preserved verbatim, not lost
        assertUTCDate(other.date, year: 2026, month: 6, day: 27, hour: 0, minute: 0)
    }

    @Test func rowMissingARequiredFieldIsSkippedNotThrown() throws {
        // Row 6 has no amount cell at all — makeOperation(from:) should return nil for
        // it, counted in failedRowCount, without aborting the parse of the other rows.
        let result = try DividendReportParser.parse(fileURL: makeFixtureReportURL())
        #expect(result.operations.contains { $0.operationNumber == 100005 } == false)
        #expect(result.failedRowCount == 1)
    }

    @Test func throwsWhenTheWorksheetEntryIsMissing() throws {
        let archiveURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".xlsx")
        _ = try Archive(url: archiveURL, accessMode: .create)   // empty archive, no entries

        #expect(throws: DividendReportParser.ParseError.missingSheet) {
            try DividendReportParser.parse(fileURL: archiveURL)
        }
    }
}
