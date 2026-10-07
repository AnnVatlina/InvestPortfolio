//
//  DividendReportParser.swift
//  InvestPortfolio
//
//  Parses a Freedom24/Tradernet broker report (.xlsx) into BrokerOperation rows.
//  .xlsx is a zip archive containing XML — see Docs/dividends-feature.md for the
//  column layout found in a real export (Операция №, Дата, Операция, Комментарий,
//  Сумма, Валюта). A row with an unrecognized operation label still imports as
//  `.other` (with the report's own label preserved) — only rows missing/mangling a
//  required field (operation number, date, amount, currency) are dropped.
//

import Foundation
import ZIPFoundation

enum DividendReportParser {

    struct ParseResult {
        let operations: [BrokerOperation]
        let failedRowCount: Int   // rows that couldn't be parsed (missing/invalid required fields)
    }

    enum ParseError: Error {
        case cannotOpenArchive
        case missingSheet
    }

    // MARK: - Public API

    static func parse(fileURL: URL) throws -> ParseResult {
        let archive: Archive
        do {
            archive = try Archive(url: fileURL, accessMode: .read)
        } catch {
            throw ParseError.cannotOpenArchive
        }

        guard let sheetEntry = archive["xl/worksheets/sheet1.xml"] else {
            throw ParseError.missingSheet
        }

        var sharedStrings: [String] = []
        if let sharedStringsEntry = archive["xl/sharedStrings.xml"] {
            sharedStrings = try parseSharedStrings(extractData(sharedStringsEntry, from: archive))
        }

        let rows = try parseRows(extractData(sheetEntry, from: archive), sharedStrings: sharedStrings)

        var operations: [BrokerOperation] = []
        var failedRowCount = 0
        for row in rows {
            if let operation = makeOperation(from: row) {
                operations.append(operation)
            } else {
                failedRowCount += 1
            }
        }
        return ParseResult(operations: operations, failedRowCount: failedRowCount)
    }

    // MARK: - Row -> BrokerOperation

    /// `row` is keyed by zero-based column index: A=0 (operation number), B=1 (date),
    /// C=2 (operation label), D=3 (comment), E=4 (amount), F=5 (currency).
    private static func makeOperation(from row: [Int: String]) -> BrokerOperation? {
        guard let operationNumberText = row[0], let operationNumber = Int(operationNumberText),
              let dateText = row[1], let serial = Double(dateText),
              let amountText = row[4], let amount = Decimal(string: amountText),
              let currencyText = row[5], let currency = DepositCurrency(rawValue: currencyText)
        else { return nil }

        let rawLabel = row[2] ?? ""
        let comment = row[3] ?? ""

        return BrokerOperation(
            operationNumber: operationNumber,
            date: date(fromExcelSerial: serial),
            type: operationType(fromRawLabel: rawLabel),
            rawOperationLabel: rawLabel,
            comment: comment,
            ticker: ticker(fromComment: comment),
            amount: amount,
            currency: currency
        )
    }

    // The report's comment column is free text (see Docs/dividends-feature.md). Every row
    // in the one real sample we've seen so far — dividend, tax, and trade-commission
    // comments alike — embeds the security's ticker as an "EXCHANGE-SUFFIXED" token like
    // "VCIT.US" or "BITO.US". This is a heuristic validated only against that one US-market
    // sample: a security whose ticker uses a different suffix length, no suffix at all, or
    // some other convention entirely (e.g. MOEX-listed securities) won't necessarily match.
    // Matches the first such token; returns nil if the comment doesn't contain one — that's
    // not an error, `ticker` is always optional.
    private static let tickerPattern = try! NSRegularExpression(pattern: #"\b[A-Z0-9]{1,10}\.[A-Z]{1,5}\b"#)

    static func ticker(fromComment comment: String) -> String? {
        let range = NSRange(comment.startIndex..., in: comment)
        guard let match = tickerPattern.firstMatch(in: comment, range: range),
              let swiftRange = Range(match.range, in: comment)
        else { return nil }
        return String(comment[swiftRange])
    }

    private static func operationType(fromRawLabel rawLabel: String) -> BrokerOperationType {
        switch rawLabel.trimmingCharacters(in: .whitespaces) {
        case "Дивиденды": return .dividend
        case "Налоги": return .tax
        case "Комиссия за сделки": return .commission
        default: return .other
        }
    }

    // MARK: - Excel serial date (1900 date system, epoch 1899-12-30 UTC)

    private static let excelEpoch: Date = {
        var components = DateComponents()
        components.year = 1899
        components.month = 12
        components.day = 30
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }()

    private static func date(fromExcelSerial serial: Double) -> Date {
        excelEpoch.addingTimeInterval(serial * 86400)
    }

    // MARK: - Zip entry extraction

    private static func extractData(_ entry: Entry, from archive: Archive) throws -> Data {
        var data = Data()
        _ = try archive.extract(entry) { chunk in data.append(chunk) }
        return data
    }

    // MARK: - sharedStrings.xml

    private static func parseSharedStrings(_ data: Data) throws -> [String] {
        let delegate = SharedStringsParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { throw parser.parserError ?? ParseError.missingSheet }
        return delegate.strings
    }

    // MARK: - worksheets/sheet1.xml

    /// Returns one dictionary per data row (header row dropped), keyed by zero-based column index.
    private static func parseRows(_ data: Data, sharedStrings: [String]) throws -> [[Int: String]] {
        let delegate = SheetParserDelegate(sharedStrings: sharedStrings)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { throw parser.parserError ?? ParseError.missingSheet }
        return delegate.rows
    }
}

// MARK: - XML delegates

/// Collects the text of every <si> in sharedStrings.xml, concatenating any <r><t>
/// rich-text runs it contains — mirrors how Excel itself reassembles shared strings.
private final class SharedStringsParserDelegate: NSObject, XMLParserDelegate {
    private(set) var strings: [String] = []
    private var currentString = ""
    private var currentText = ""
    private var isInsideText = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        switch elementName {
        case "si": currentString = ""
        case "t": isInsideText = true; currentText = ""
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInsideText { currentText += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "t": currentString += currentText; isInsideText = false
        case "si": strings.append(currentString)
        default: break
        }
    }
}

/// Walks <sheetData><row><c><v> in sheet1.xml, resolving shared-string cell values
/// (t="s") by index. Row 1 is always the report's header and is dropped here.
private final class SheetParserDelegate: NSObject, XMLParserDelegate {
    private(set) var rows: [[Int: String]] = []
    private let sharedStrings: [String]

    private var currentRowNumber: Int?
    private var currentRowCells: [Int: String] = [:]
    private var currentCellColumn: Int?
    private var currentCellIsSharedString = false
    private var currentValue = ""
    private var isInsideValue = false

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        switch elementName {
        case "row":
            currentRowCells = [:]
            currentRowNumber = attributeDict["r"].flatMap(Int.init)
        case "c":
            currentCellColumn = attributeDict["r"].flatMap(Self.columnIndex(fromCellRef:))
            currentCellIsSharedString = attributeDict["t"] == "s"
        case "v":
            isInsideValue = true
            currentValue = ""
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInsideValue { currentValue += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "v":
            isInsideValue = false
            guard let column = currentCellColumn else { break }
            if currentCellIsSharedString, let index = Int(currentValue), sharedStrings.indices.contains(index) {
                currentRowCells[column] = sharedStrings[index]
            } else {
                currentRowCells[column] = currentValue
            }
        case "row":
            if currentRowNumber != 1 {
                rows.append(currentRowCells)
            }
        default: break
        }
    }

    /// "A" -> 0, "B" -> 1, ... "AA" -> 26. Ignores the trailing row-number digits in a ref like "C2".
    private static func columnIndex(fromCellRef ref: String) -> Int? {
        var index = 0
        for char in ref {
            guard char.isLetter, let ascii = char.uppercased().first?.asciiValue else { break }
            index = index * 26 + Int(ascii - Character("A").asciiValue! + 1)
        }
        return index > 0 ? index - 1 : nil
    }
}
