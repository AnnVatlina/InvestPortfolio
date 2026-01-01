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

    @State private var showAddSheet = false
    @State private var depositToEdit: Deposit? = nil
    @State private var depositToDelete: Deposit? = nil

    var body: some View {
        Group {
            if vm.isLoading && vm.deposits.isEmpty {
                ProgressView(String(localized: "deposits.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.errorMessage, vm.deposits.isEmpty {
                errorView(error)
            } else if vm.deposits.isEmpty {
                emptyView
            } else {
                depositsList
            }
        }
        .navigationTitle(String(localized: "deposits.title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
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
        .alert(String(localized: "deposits.delete.confirm.title"), isPresented: Binding(
            get: { depositToDelete != nil },
            set: { if !$0 { depositToDelete = nil } }
        )) {
            Button(String(localized: "deposits.delete.action"), role: .destructive) {
                if let deposit = depositToDelete {
                    Task { await vm.deleteDeposit(deposit) }
                }
                depositToDelete = nil
            }
            Button(String(localized: "common.cancel"), role: .cancel) {
                depositToDelete = nil
            }
        } message: {
            Text(String(localized: "deposits.delete.confirm.message"))
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }

    // MARK: - Subviews

    private var depositsList: some View {
        List {
            ForEach(vm.deposits) { deposit in
                DepositRow(deposit: deposit, summary: vm.incomeSummary(for: deposit))
                    .contentShape(Rectangle())
                    .onTapGesture { depositToEdit = deposit }
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
            Text(String(localized: "deposits.empty"))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 8) {
            Text(String(localized: "common.error"))
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button(String(localized: "common.retry")) {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
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
                Text(String(format: String(localized: "deposits.rate.format"), deposit.annualInterestRate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("\(deposit.amount, specifier: "%.2f") \(deposit.currency.rawValue)")
                Spacer()
                HStack(spacing: 12) {
                    Text(String(format: String(localized: "deposits.opened.format"), deposit.openDate.formatted(date: .abbreviated, time: .omitted)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let close = deposit.closeDate {
                        Text(String(format: String(localized: "deposits.closed.format"), close.formatted(date: .abbreviated, time: .omitted)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: String(localized: "deposits.income.today.format"), summary.incomeToDate, deposit.currency.rawValue))
                    .font(.subheadline)
                    .foregroundColor(summary.incomeToDate >= 0 ? .green : .red)

                if let forecast = summary.forecastIncomeToCloseDate {
                    Text(String(format: String(localized: "deposits.income.forecast.format"), forecast, deposit.currency.rawValue))
                        .font(.subheadline)
                        .foregroundColor(forecast >= 0 ? .green : .red)
                }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
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
    @AppStorage("Settings_SelectedCurrencies") private var selectedCurrenciesRaw: String = "USD,EUR,GBP,RUB"
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
        case .add: return String(localized: "deposits.add.title")
        case .edit: return String(localized: "deposits.edit.title")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "deposits.field.name"), text: $title)
                    TextField(String(localized: "deposits.field.bankName"), text: $bankName)
                }

                Section {
                    TextField(String(localized: "deposits.field.amount"), text: $amountText)
                        .keyboardType(.decimalPad)
                    Picker(String(localized: "deposits.field.currency"), selection: $currency) {
                        ForEach(DepositCurrency.allCases.filter { selectedCurrencies.contains($0.rawValue) }) { curr in
                            Text(curr.rawValue).tag(curr)
                        }
                    }
                }

                Section {
                    DatePicker(String(localized: "deposits.field.openDate"), selection: $openDate, displayedComponents: .date)
                    Toggle(String(localized: "deposits.field.hasCloseDate"), isOn: $hasCloseDate.animation())
                    if hasCloseDate {
                        DatePicker(String(localized: "deposits.field.closeDate"), selection: $closeDate, in: openDate..., displayedComponents: .date)
                    }
                }

                Section {
                    HStack {
                        TextField(String(localized: "deposits.field.annualInterest"), text: $interestText)
                            .keyboardType(.decimalPad)
                        Text(String(localized: "common.percentSign"))
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
                    Button(String(localized: "common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) { save() }
                }
            }
        }
    }

    private func save() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationError = String(localized: "deposits.error.emptyTitle")
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
