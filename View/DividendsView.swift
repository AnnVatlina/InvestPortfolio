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

// MARK: - Row

private struct OperationRow: View {
    let operation: BrokerOperation
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(typeLabel)
                    .font(.subheadline).fontWeight(.medium)
                Text(operation.comment)
                    .font(.caption).foregroundColor(.secondary)
                    .lineLimit(1)
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

    private var typeLabel: String {
        switch operation.type {
        case .dividend:   return LanguageBundle.string("dividends.type.dividend")
        case .tax:        return LanguageBundle.string("dividends.type.tax")
        case .commission: return LanguageBundle.string("dividends.type.commission")
        case .other:      return operation.rawOperationLabel.trimmingCharacters(in: .whitespaces)
        }
    }

    private var iconName: String {
        switch operation.type {
        case .dividend:   return "banknote.fill"
        case .tax:        return "percent"
        case .commission: return "arrow.left.arrow.right"
        case .other:      return "questionmark.circle"
        }
    }

    private var iconColor: Color {
        switch operation.type {
        case .dividend:   return .green
        case .tax:        return .orange
        case .commission: return .red
        case .other:      return .secondary
        }
    }
}

// MARK: - Formatting

private func formattedAmount(_ amount: Decimal, currency: DepositCurrency) -> String {
    let sign = amount < 0 ? "" : "+"
    return "\(sign)\(amount) \(currency.rawValue)"
}
