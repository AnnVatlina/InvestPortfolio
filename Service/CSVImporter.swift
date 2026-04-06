//
//  CSVImporter.swift
//  InvestPortfolio
//
//  Parses CSV files exported by CSVExporter back into model objects.
//  Follows RFC 4180 for quoted fields. Unknown/invalid rows are counted as failed.
//

import Foundation

enum CSVImporter {

    // MARK: - Public API

    struct ParseResult<T> {
        let items: [T]
        let failed: Int     // rows that couldn't be parsed
    }

    /// Parses a deposits CSV (header: ID,Title,Bank,Amount,Currency,OpenDate,CloseDate,AnnualRate%,CreatedAt)
    static func parseDeposits(_ csv: String) -> ParseResult<Deposit> {
        let lines = splitLines(csv).dropFirst() // skip header
        var items: [Deposit] = []
        var failed = 0
        let fmt = isoFormatter()

        for line in lines {
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let f = parseRow(line)
            guard f.count >= 9,
                  let id = UUID(uuidString: f[0]),
                  let amount = Double(f[3]),
                  let currency = DepositCurrency(rawValue: f[4]),
                  let openDate = fmt.date(from: f[5]),
                  let rate = Double(f[7]),
                  let createdAt = fmt.date(from: f[8])
            else { failed += 1; continue }

            let title = f[1].isEmpty ? "—" : f[1]
            let bankName: String? = f[2].isEmpty ? nil : f[2]
            let closeDate: Date? = f[6].isEmpty ? nil : fmt.date(from: f[6])

            items.append(Deposit(
                id: id,
                title: title,
                bankName: bankName,
                amount: amount,
                currency: currency,
                createdAt: createdAt,
                openDate: openDate,
                closeDate: closeDate,
                annualInterestRate: rate
            ))
        }
        return ParseResult(items: items, failed: failed)
    }

    /// Parses a subscriptions CSV (header: ID,Title,Category,Amount,Currency,BillingCycle,StartDate,EndDate,IsActive,CreatedAt)
    static func parseSubscriptions(_ csv: String) -> ParseResult<Subscription> {
        let lines = splitLines(csv).dropFirst()
        var items: [Subscription] = []
        var failed = 0
        let fmt = isoFormatter()

        for line in lines {
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let f = parseRow(line)
            guard f.count >= 10,
                  let id = UUID(uuidString: f[0]),
                  let amount = Double(f[3]),
                  let currency = DepositCurrency(rawValue: f[4]),
                  let cycle = SubscriptionBillingCycle(rawValue: f[5]),
                  let startDate = fmt.date(from: f[6]),
                  let createdAt = fmt.date(from: f[9])
            else { failed += 1; continue }

            let title = f[1].isEmpty ? "—" : f[1]
            let category: String? = f[2].isEmpty ? nil : f[2]
            let endDate: Date? = f[7].isEmpty ? nil : fmt.date(from: f[7])
            let isActive = f[8].lowercased() == "true"

            items.append(Subscription(
                id: id,
                title: title,
                amount: amount,
                currency: currency,
                billingCycle: cycle,
                startDate: startDate,
                category: category,
                iconName: nil,
                isActive: isActive,
                endDate: endDate,
                createdAt: createdAt
            ))
        }
        return ParseResult(items: items, failed: failed)
    }

    // MARK: - RFC 4180 Row Parser

    private static func parseRow(_ line: String) -> [String] {
        var fields: [String] = []
        var field = ""
        var inQuotes = false
        var idx = line.startIndex

        while idx < line.endIndex {
            let ch = line[idx]
            if inQuotes {
                if ch == "\"" {
                    let next = line.index(after: idx)
                    if next < line.endIndex && line[next] == "\"" {
                        // Escaped quote ""
                        field.append("\"")
                        idx = line.index(after: next)
                        continue
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(ch)
                }
            } else {
                switch ch {
                case "\"": inQuotes = true
                case ",":
                    fields.append(field)
                    field = ""
                default:
                    field.append(ch)
                }
            }
            idx = line.index(after: idx)
        }
        fields.append(field)
        return fields
    }

    // MARK: - Helpers

    /// Splits CSV text into non-empty lines, handling \r\n and \n.
    private static func splitLines(_ csv: String) -> [String] {
        csv.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    private static func isoFormatter() -> ISO8601DateFormatter {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        return fmt
    }
}
