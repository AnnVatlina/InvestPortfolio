//
//  CSVExporter.swift
//  InvestPortfolio
//
//  Builds CSV strings for each data model and writes them to temp files for sharing.
//

import Foundation

enum CSVExporter {

    // MARK: - Deposits

    static func csv(for deposits: [Deposit]) -> String {
        var rows: [String] = ["ID,Title,Bank,Amount,Currency,OpenDate,CloseDate,AnnualRate%,CreatedAt,InterestType,CapitalizationPeriod,AllowsReplenishment,AllowsPartialWithdrawal,IsRevocable,EarlyWithdrawalRate"]
        let fmt = iso8601Formatter()
        for d in deposits {
            rows.append([
                d.id.uuidString,
                escape(d.title),
                escape(d.bankName ?? ""),
                String(d.amount),
                d.currency.rawValue,
                fmt.string(from: d.openDate),
                d.closeDate.map { fmt.string(from: $0) } ?? "",
                String(d.annualInterestRate),
                fmt.string(from: d.createdAt),
                d.interestType.rawValue,
                d.capitalizationPeriod?.rawValue ?? "",
                d.allowsReplenishment ? "true" : "false",
                d.allowsPartialWithdrawal ? "true" : "false",
                d.isRevocable ? "true" : "false",
                d.earlyWithdrawalRate.map { String($0) } ?? ""
            ].joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    // MARK: - Deposit Transactions

    static func csv(for transactions: [DepositTransaction]) -> String {
        var rows: [String] = ["ID,DepositID,Date,Amount"]
        let fmt = iso8601Formatter()
        for t in transactions {
            rows.append([
                t.id.uuidString,
                t.depositId.uuidString,
                fmt.string(from: t.date),
                String(t.amount)
            ].joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    // MARK: - Subscriptions

    static func csv(for subscriptions: [Subscription]) -> String {
        var rows: [String] = ["ID,Title,Category,Amount,Currency,BillingCycle,StartDate,EndDate,IsActive,CreatedAt"]
        let fmt = iso8601Formatter()
        for s in subscriptions {
            rows.append([
                s.id.uuidString,
                escape(s.title),
                escape(s.category ?? ""),
                String(s.amount),
                s.currency.rawValue,
                s.billingCycle.rawValue,
                fmt.string(from: s.startDate),
                s.endDate.map { fmt.string(from: $0) } ?? "",
                s.isActive ? "true" : "false",
                fmt.string(from: s.createdAt)
            ].joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    // MARK: - File Writing

    /// Writes CSV content to a temp file and returns its URL.
    static func writeToTempFile(_ csv: String, named filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        guard let data = csv.data(using: .utf8) else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    /// Wraps a string in quotes and escapes any internal quotes per RFC 4180.
    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private static func iso8601Formatter() -> ISO8601DateFormatter {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        return fmt
    }
}
