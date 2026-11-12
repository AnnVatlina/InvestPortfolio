//
//  DividendsView.swift
//  InvestPortfolio
//
//  Manual entry is intentionally not offered here — the only way to get data onto this
//  screen is importing a Freedom24 report. See Docs/dividends-feature.md.
//

import SwiftUI
import UniformTypeIdentifiers

struct DividendsView: View {
    @StateObject private var vm: DividendsViewModel

    init(container: DIContainer) {
        _vm = StateObject(wrappedValue: DividendsViewModel(
            service: container.makeDividendsService()
        ))
    }

    @Environment(\.locale) private var locale
    @State private var showFileImporter = false
    @State private var showDeleteConfirmation = false
    @State private var selectedOperation: BrokerOperation?

    var body: some View {
        Group {
            if vm.isLoading && vm.operations.isEmpty {
                ProgressView(LanguageBundle.string("dividends.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.errorMessage, vm.operations.isEmpty {
                errorView(error)
            } else if vm.operations.isEmpty {
                emptyView
            } else {
                operationsList
            }
        }
        .navigationTitle("dividends.title")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showFileImporter = true
                    } label: {
                        Label(LanguageBundle.string("dividends.import.action"), systemImage: "square.and.arrow.down")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label(LanguageBundle.string("dividends.deleteAll.action"), systemImage: "trash")
                    }
                    .disabled(vm.operations.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(Text("dividends.title"))
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [UTType(filenameExtension: "xlsx") ?? .data],
            onCompletion: { result in
                switch result {
                case .success(let url):
                    Task { await vm.importReport(fileURL: url) }
                case .failure(let error):
                    vm.operationError = error.localizedDescription
                }
            }
        )
        .alert("dividends.deleteAll.confirm.title", isPresented: $showDeleteConfirmation) {
            Button("dividends.deleteAll.action", role: .destructive) {
                Task { await vm.deleteAll() }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("subscriptions.delete.confirm.message")
        }
        .alert(LanguageBundle.string("settings.import.result.title"), isPresented: Binding(
            get: { vm.lastImportSummary != nil },
            set: { if !$0 { vm.lastImportSummary = nil } }
        )) {
            Button(LanguageBundle.string("common.ok"), role: .cancel) { vm.lastImportSummary = nil }
        } message: {
            if let summary = vm.lastImportSummary {
                Text(String(
                    format: LanguageBundle.string("settings.import.result.format"),
                    summary.addedCount, summary.duplicateCount, summary.failedRowCount
                ))
            }
        }
        .alert(LanguageBundle.string("common.error"), isPresented: Binding(
            get: { vm.operationError != nil },
            set: { if !$0 { vm.operationError = nil } }
        )) {
            Button(LanguageBundle.string("common.ok"), role: .cancel) { vm.operationError = nil }
        } message: {
            Text(vm.operationError ?? "")
        }
        .sheet(item: $selectedOperation) { operation in
            DividendDetailSheet(operation: operation)
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }

    // MARK: - List

    private var operationsList: some View {
        List {
            if !vm.totals.isEmpty {
                Section(LanguageBundle.string("dividends.totals.title")) {
                    ForEach(vm.totals) { total in
                        HStack {
                            Text(typeLabel(total.type))
                            Spacer()
                            Text(formattedAmount(total.total, currency: total.currency))
                                .fontWeight(.medium)
                                .foregroundColor(total.total < 0 ? .red : .green)
                        }
                    }
                }
            }
            ForEach(vm.sections) { section in
                Section(monthTitle(section.month)) {
                    ForEach(section.operations) { operation in
                        OperationRow(operation: operation)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedOperation = operation }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func monthTitle(_ month: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: month)
    }

    private func typeLabel(_ type: BrokerOperationType) -> String {
        switch type {
        case .dividend:   return LanguageBundle.string("dividends.type.dividend")
        case .tax:        return LanguageBundle.string("dividends.type.tax")
        case .commission: return LanguageBundle.string("dividends.type.commission")
        case .other:      return LanguageBundle.string("dividends.type.other")
        }
    }

    // MARK: - Empty / Error

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48)).foregroundColor(.secondary)
            Text("dividends.empty")
                .foregroundColor(.secondary)
            Button(LanguageBundle.string("dividends.import.action")) {
                showFileImporter = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 8) {
            Text("common.error").font(.headline)
            Text(error).font(.caption).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)
            Button("common.retry") { Task { await vm.load() } }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Display helpers shared by the row and the detail sheet

extension BrokerOperation {
    fileprivate var displayTypeLabel: String {
        switch type {
        case .dividend:   return LanguageBundle.string("dividends.type.dividend")
        case .tax:        return LanguageBundle.string("dividends.type.tax")
        case .commission: return LanguageBundle.string("dividends.type.commission")
        case .other:      return rawOperationLabel.trimmingCharacters(in: .whitespaces)
        }
    }

    fileprivate var displayIconName: String {
        switch type {
        case .dividend:   return "banknote.fill"
        case .tax:        return "percent"
        case .commission: return "arrow.left.arrow.right"
        case .other:      return "questionmark.circle"
        }
    }

    fileprivate var displayIconColor: Color {
        switch type {
        case .dividend:   return .green
        case .tax:        return .orange
        case .commission: return .red
        case .other:      return .secondary
        }
    }
}

// MARK: - Row

private struct OperationRow: View {
    let operation: BrokerOperation
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: operation.displayIconName)
                .font(.system(size: 18))
                .foregroundColor(operation.displayIconColor)
                .frame(width: 32, height: 32)
                .background(operation.displayIconColor.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                if let ticker = operation.ticker {
                    Text(ticker)
                        .font(.subheadline).fontWeight(.semibold)
                    Text(operation.displayTypeLabel)
                        .font(.caption).foregroundColor(.secondary)
                } else {
                    Text(operation.displayTypeLabel)
                        .font(.subheadline).fontWeight(.medium)
                    Text(operation.comment)
                        .font(.caption).foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Text(operation.date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale)))
                    .font(.caption2).foregroundColor(.secondary)
            }

            Spacer()

            Text(formattedAmount(operation.amount, currency: operation.currency))
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(operation.amount < 0 ? .red : .green)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Detail sheet

/// Read-only — there's nothing to edit on an imported broker operation. Exists mainly
/// to show the full comment, which the list row truncates to one line.
private struct DividendDetailSheet: View {
    let operation: BrokerOperation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: operation.displayIconName)
                            .font(.system(size: 20))
                            .foregroundColor(operation.displayIconColor)
                            .frame(width: 36, height: 36)
                            .background(operation.displayIconColor.opacity(0.15))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(operation.ticker ?? operation.displayTypeLabel).font(.headline)
                            if operation.ticker != nil {
                                Text(operation.displayTypeLabel)
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Text(operation.date.formatted(Date.FormatStyle(date: .long, time: .shortened).locale(locale)))
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(formattedAmount(operation.amount, currency: operation.currency))
                            .font(.title3).fontWeight(.semibold)
                            .foregroundColor(operation.amount < 0 ? .red : .green)
                    }
                    .padding(.vertical, 4)
                }

                Section(LanguageBundle.string("dividends.detail.comment")) {
                    Text(operation.comment)
                        .textSelection(.enabled)
                }

                Section {
                    if let ticker = operation.ticker {
                        LabeledContent(LanguageBundle.string("dividends.detail.ticker"), value: ticker)
                    }
                    LabeledContent(LanguageBundle.string("dividends.detail.operationNumber"), value: "\(operation.operationNumber)")
                }
            }
            .navigationTitle(operation.ticker ?? operation.displayTypeLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LanguageBundle.string("common.done")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Formatting

private func formattedAmount(_ amount: Decimal, currency: DepositCurrency) -> String {
    let sign = amount < 0 ? "" : "+"
    return "\(sign)\(amount) \(currency.rawValue)"
}
