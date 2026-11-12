//
//  DividendsViewModel.swift
//  InvestPortfolio
//

import Foundation

@MainActor
final class DividendsViewModel: ObservableObject {
    @Published private(set) var operations: [BrokerOperation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var operationError: String?
    @Published var lastImportSummary: DividendImportSummary?

    private let service: any DividendsService

    init(service: any DividendsService) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            operations = try await service.fetchAll()
        } catch {
            if operations.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// `fileURL` typically comes straight from a `.fileImporter` picker, which hands back
    /// a security-scoped URL — access must be requested before reading it and released
    /// afterwards, or the read fails/leaks the scope.
    func importReport(fileURL: URL) async {
        let didStartAccessing = fileURL.startAccessingSecurityScopedResource()
        defer { if didStartAccessing { fileURL.stopAccessingSecurityScopedResource() } }
        do {
            lastImportSummary = try await service.importReport(fileURL: fileURL)
            await load()
        } catch {
            operationError = error.localizedDescription
        }
    }

    func deleteAll() async {
        do {
            try await service.deleteAll()
            operations = []
        } catch {
            operationError = error.localizedDescription
        }
    }

    // MARK: - Grouping for UI

    struct MonthSection: Identifiable {
        var id: Date { month }
        let month: Date
        let operations: [BrokerOperation]
    }

    /// Operations grouped by calendar month, newest month first, newest operation first
    /// within each month.
    var sections: [MonthSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: operations) { operation in
            calendar.date(from: calendar.dateComponents([.year, .month], from: operation.date)) ?? operation.date
        }
        return grouped
            .map { month, ops in
                MonthSection(month: month, operations: ops.sorted { $0.date > $1.date })
            }
            .sorted { $0.month > $1.month }
    }

    struct TypeTotal: Identifiable {
        var id: String { "\(type.rawValue)-\(currency.rawValue)" }
        let type: BrokerOperationType
        let currency: DepositCurrency
        let total: Decimal
    }

    /// Sum of all currently loaded operations, broken down by type and currency.
    var totals: [TypeTotal] {
        var totalsByKey: [String: TypeTotal] = [:]
        for operation in operations {
            let key = "\(operation.type.rawValue)-\(operation.currency.rawValue)"
            let existing = totalsByKey[key]
            totalsByKey[key] = TypeTotal(
                type: operation.type,
                currency: operation.currency,
                total: (existing?.total ?? 0) + operation.amount
            )
        }
        return totalsByKey.values.sorted {
            $0.type.rawValue == $1.type.rawValue ? $0.currency.rawValue < $1.currency.rawValue : $0.type.rawValue < $1.type.rawValue
        }
    }
}
