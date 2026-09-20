//
//  DepositsView.swift
//
//  Created by Anna on 30.12.25.
//

import SwiftUI

struct DepositsView: View {
    @StateObject private var vm: DepositsViewModel

    init(container: DIContainer) {
        _vm = StateObject(wrappedValue: DepositsViewModel(
            service: container.makeDepositsService()
        ))
    }

    @Environment(\.locale) private var locale
    @State private var showAddSheet = false
    @State private var depositToEdit: Deposit? = nil
    @State private var depositToDelete: Deposit? = nil

    var body: some View {
        Group {
            if vm.isLoading && vm.deposits.isEmpty {
                ProgressView("deposits.loading")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.errorMessage, vm.deposits.isEmpty {
                errorView(error)
            } else if vm.deposits.isEmpty {
                emptyView
            } else {
                depositsList
            }
        }
        .navigationTitle("deposits.title")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text("deposits.add.title"))
            }
        }
        .sheet(isPresented: $showAddSheet) {
            DepositFormSheet(mode: .add) { formData in
                Task {
                    await vm.addDeposit(
                        title: formData.title,
                        bankName: formData.bankName,
                        amount: formData.amount,
                        currency: formData.currency,
                        openDate: formData.openDate,
                        closeDate: formData.closeDate,
                        annualInterestRate: formData.annualInterestRate
                    )
                }
            }
        }
        .sheet(item: $depositToEdit) { deposit in
            DepositFormSheet(mode: .edit(deposit)) { formData in
                Task {
                    await vm.updateDeposit(
                        id: deposit.id,
                        title: formData.title,
                        bankName: formData.bankName,
                        amount: formData.amount,
                        currency: formData.currency,
                        openDate: formData.openDate,
                        closeDate: formData.closeDate,
                        annualInterestRate: formData.annualInterestRate
                    )
                }
            }
        }
        .alert(LanguageBundle.string("deposits.delete.confirm.title"), isPresented: Binding(
            get: { depositToDelete != nil },
            set: { if !$0 { depositToDelete = nil } }
        )) {
            Button(LanguageBundle.string("deposits.delete.action"), role: .destructive) {
                if let deposit = depositToDelete {
                    Task { await vm.deleteDeposit(deposit) }
                }
                depositToDelete = nil
            }
            Button(LanguageBundle.string("common.cancel"), role: .cancel) {
                depositToDelete = nil
            }
        } message: {
            Text(LanguageBundle.string("deposits.delete.confirm.message"))
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .alert(LanguageBundle.string("common.error"), isPresented: Binding(
            get: { vm.operationError != nil },
            set: { if !$0 { vm.operationError = nil } }
        )) {
            Button(LanguageBundle.string("common.ok"), role: .cancel) { vm.operationError = nil }
        } message: {
            Text(vm.operationError ?? "")
        }
    }

    // MARK: - Subviews

    private var depositsList: some View {
        List {
            ForEach(vm.deposits) { deposit in
                DepositRow(deposit: deposit, summary: vm.incomeSummary(for: deposit))
                    .contentShape(Rectangle())
                    .onTapGesture { depositToEdit = deposit }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
            }
            .onDelete { indexSet in
                if let index = indexSet.first {
                    depositToDelete = vm.deposits[index]
                }
            }
        }
        .listStyle(.plain)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "banknote")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(LanguageBundle.string("deposits.empty"))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 8) {
            Text(LanguageBundle.string("common.error"))
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button(LanguageBundle.string("common.retry")) {
                Task { await vm.load() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Deposit Row

private struct DepositRow: View {
    let deposit: Deposit
    let summary: DepositIncomeSummary

    // Date.formatted(date:time:) ignores the SwiftUI environment locale and follows the
    // device's system language instead — reading it explicitly keeps dates in sync with
    // the in-app language switch (Settings), not just everything else on screen.
    @Environment(\.locale) private var locale

    private var isClosed: Bool {
        guard let closeDate = deposit.closeDate else { return false }
        return closeDate <= Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Заголовок: название + статус
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(deposit.title)
                        .font(.headline)
                    if let bankName = deposit.bankName, !bankName.isEmpty {
                        Text(bankName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    // Бейдж статуса
                    Text(isClosed
                         ? LanguageBundle.string("deposits.status.closed")
                         : LanguageBundle.string("deposits.status.active"))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(isClosed ? Color.secondary.opacity(0.15) : Color.brand.opacity(0.15))
                        .foregroundColor(isClosed ? .secondary : .brand)
                        .clipShape(Capsule())
                    Text(String(format: LanguageBundle.string("deposits.rate.format"), deposit.annualInterestRate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Сумма и даты
            HStack {
                Text("\(deposit.amount, specifier: "%.0f") \(deposit.currency.rawValue)")
                    .fontWeight(.medium)
                Spacer()
                HStack(spacing: 6) {
                    Text(deposit.openDate.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let close = deposit.closeDate {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(close.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale)))
                            .font(.caption)
                            .foregroundColor(isClosed ? .secondary : .orange)
                    }
                }
            }

            // Прогресс срока (только для вкладов с датой закрытия)
            if let closeDate = deposit.closeDate {
                let total = closeDate.timeIntervalSince(deposit.openDate)
                let elapsed = Date().timeIntervalSince(deposit.openDate)
                let progress = total > 0 ? min(1.0, max(0.0, elapsed / total)) : 1.0
                ProgressView(value: progress)
                    .tint(isClosed ? .secondary : .brand)
            }

            // Доход
            HStack(spacing: 16) {
                // Для закрытых: "Заработано", для активных: "На сегодня"
                Label {
                    Text(String(format: LanguageBundle.string(isClosed
                                               ? "deposits.income.earned.format"
                                               : "deposits.income.today.format"),
                                summary.incomeToDate, deposit.currency.rawValue))
                        .font(.subheadline)
                        .foregroundColor(.brand)
                } icon: {
                    Image(systemName: isClosed ? "checkmark.circle" : "clock")
                        .font(.caption)
                        .foregroundColor(.brand)
                }

                if let forecast = summary.forecastIncomeToCloseDate {
                    Label {
                        Text(String(format: LanguageBundle.string("deposits.income.forecast.format"),
                                    forecast, deposit.currency.rawValue))
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    } icon: {
                        Image(systemName: "arrow.right.circle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 6)
        .opacity(isClosed ? 0.75 : 1.0)
    }
}

// MARK: - Deposit Form Sheet

struct DepositFormData {
    var title: String
    var bankName: String
    var amount: Double
    var currency: DepositCurrency
    var openDate: Date
    var closeDate: Date?
    var annualInterestRate: Double
}

enum DepositFormMode {
    case add
    case edit(Deposit)
}

private struct DepositFormSheet: View {
    let mode: DepositFormMode
    let onSave: (DepositFormData) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("Settings_SelectedCurrencies") private var selectedCurrenciesRaw: String = DepositCurrency.defaultSelection
    private var selectedCurrencies: Set<String> { Set(selectedCurrenciesRaw.split(separator: ",").map { String($0) }) }

    @State private var title: String
    @State private var bankName: String
    @State private var amountText: String
    @State private var currency: DepositCurrency
    @State private var openDate: Date
    @State private var hasCloseDate: Bool
    @State private var closeDate: Date
    @State private var interestText: String
    @State private var validationError: String?

    init(mode: DepositFormMode, onSave: @escaping (DepositFormData) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .add:
            _title = State(initialValue: "")
            _bankName = State(initialValue: "")
            _amountText = State(initialValue: "")
            _currency = State(initialValue: .RUB)
            _openDate = State(initialValue: Date())
            _hasCloseDate = State(initialValue: false)
            _closeDate = State(initialValue: Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date())
            _interestText = State(initialValue: "")
        case .edit(let deposit):
            _title = State(initialValue: deposit.title)
            _bankName = State(initialValue: deposit.bankName ?? "")
            _amountText = State(initialValue: String(deposit.amount))
            _currency = State(initialValue: deposit.currency)
            _openDate = State(initialValue: deposit.openDate)
            _hasCloseDate = State(initialValue: deposit.closeDate != nil)
            _closeDate = State(initialValue: deposit.closeDate ?? Calendar.current.date(byAdding: .month, value: 6, to: deposit.openDate) ?? Date())
            _interestText = State(initialValue: String(deposit.annualInterestRate))
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .add: return LanguageBundle.string("deposits.add.title")
        case .edit: return LanguageBundle.string("deposits.edit.title")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(LanguageBundle.string("deposits.field.name"), text: $title)
                    TextField(LanguageBundle.string("deposits.field.bankName"), text: $bankName)
                }

                Section {
                    TextField(LanguageBundle.string("deposits.field.amount"), text: $amountText)
                        .keyboardType(.decimalPad)
                    Picker(LanguageBundle.string("deposits.field.currency"), selection: $currency) {
                        ForEach(DepositCurrency.allCases.filter { selectedCurrencies.contains($0.rawValue) }) { curr in
                            Text(curr.rawValue).tag(curr)
                        }
                    }
                }

                Section {
                    DatePicker(LanguageBundle.string("deposits.field.openDate"), selection: $openDate, displayedComponents: .date)
                    Toggle(LanguageBundle.string("deposits.field.hasCloseDate"), isOn: $hasCloseDate.animation())
                    if hasCloseDate {
                        DatePicker(LanguageBundle.string("deposits.field.closeDate"), selection: $closeDate, in: openDate..., displayedComponents: .date)
                    }
                }

                Section {
                    HStack {
                        TextField(LanguageBundle.string("deposits.field.annualInterest"), text: $interestText)
                            .keyboardType(.decimalPad)
                        Text(LanguageBundle.string("common.percentSign"))
                            .foregroundColor(.secondary)
                    }
                }

                if let error = validationError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LanguageBundle.string("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LanguageBundle.string("common.save")) { save() }
                }
            }
        }
    }

    private func save() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationError = LanguageBundle.string("deposits.error.emptyTitle")
            return
        }
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let interest = Double(interestText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let formData = DepositFormData(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            bankName: bankName.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            currency: currency,
            openDate: openDate,
            closeDate: hasCloseDate ? closeDate : nil,
            annualInterestRate: interest
        )
        onSave(formData)
        dismiss()
    }
}
