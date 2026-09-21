//
//  DepositDetailView.swift
//
//  Read-only overview of a single deposit: current balance, growth chart, and
//  transaction history. Editing happens via the explicit "Edit" button, not a tap.
//

import SwiftUI
import Charts

struct DepositDetailView: View {
    @ObservedObject var depositsViewModel: DepositsViewModel
    @StateObject private var detailViewModel: DepositDetailViewModel
    @State private var deposit: Deposit
    @State private var showEditSheet = false
    @State private var transactionSheetKind: TransactionKind? = nil
    @State private var showCloseConfirm = false
    @Environment(\.locale) private var locale

    init(deposit: Deposit, depositsViewModel: DepositsViewModel, container: DIContainer) {
        self._deposit = State(initialValue: deposit)
        self.depositsViewModel = depositsViewModel
        self._detailViewModel = StateObject(wrappedValue: DepositDetailViewModel(
            deposit: deposit,
            service: container.makeDepositsService()
        ))
    }

    private var isClosed: Bool {
        if deposit.actualCloseDate != nil { return true }
        guard let closeDate = deposit.closeDate else { return false }
        return closeDate <= Date()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                chartSection
                transactionsSection
            }
            .padding()
        }
        .navigationTitle(deposit.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(LanguageBundle.string("deposits.detail.editAction")) {
                    showEditSheet = true
                }
            }
        }
        .task { await detailViewModel.load() }
        .sheet(isPresented: $showEditSheet) {
            DepositFormSheet(mode: .edit(deposit)) { formData in
                Task {
                    await depositsViewModel.updateDeposit(
                        id: deposit.id,
                        title: formData.title,
                        bankName: formData.bankName,
                        amount: formData.amount,
                        currency: formData.currency,
                        openDate: formData.openDate,
                        closeDate: formData.closeDate,
                        annualInterestRate: formData.annualInterestRate,
                        interestType: formData.interestType,
                        capitalizationPeriod: formData.capitalizationPeriod,
                        allowsReplenishment: formData.allowsReplenishment,
                        allowsPartialWithdrawal: formData.allowsPartialWithdrawal,
                        isRevocable: formData.isRevocable,
                        earlyWithdrawalRate: formData.earlyWithdrawalRate,
                        actualCloseDate: deposit.actualCloseDate
                    )
                    // SwiftData mutations from the repository don't update this instance in
                    // place — pick up the freshly-reloaded object from the shared view model.
                    if let refreshed = depositsViewModel.deposits.first(where: { $0.id == deposit.id }) {
                        deposit = refreshed
                        await detailViewModel.refresh(deposit: refreshed)
                    }
                }
            }
        }
        .sheet(item: $transactionSheetKind) { kind in
            AddTransactionSheet(
                kind: kind,
                openDate: deposit.openDate,
                currency: deposit.currency.rawValue,
                maxWithdrawal: detailViewModel.currentPrincipalBalance
            ) { amount, date in
                Task {
                    do {
                        try await detailViewModel.addTransaction(amount: amount, date: date)
                    } catch {
                        detailViewModel.errorMessage = error.localizedDescription
                    }
                }
            }
        }
        .alert(LanguageBundle.string("common.error"), isPresented: Binding(
            get: { detailViewModel.errorMessage != nil },
            set: { if !$0 { detailViewModel.errorMessage = nil } }
        )) {
            Button(LanguageBundle.string("common.ok"), role: .cancel) { detailViewModel.errorMessage = nil }
        } message: {
            Text(detailViewModel.errorMessage ?? "")
        }
        .alert(LanguageBundle.string("deposits.detail.closeConfirm.title"), isPresented: $showCloseConfirm) {
            Button(LanguageBundle.string("deposits.detail.closeConfirm.action"), role: .destructive) {
                Task { await closeDepositNow() }
            }
            Button(LanguageBundle.string("common.cancel"), role: .cancel) {}
        } message: {
            let loss = detailViewModel.projectedEarlyClosureLoss()
            if loss > 0 {
                Text(String(format: LanguageBundle.string("deposits.detail.closeConfirm.penaltyMessage.format"), loss, deposit.currency.rawValue))
            } else {
                Text(LanguageBundle.string("deposits.detail.closeConfirm.message"))
            }
        }
    }

    private var isOpen: Bool {
        !isClosed && deposit.actualCloseDate == nil
    }

    private func closeDepositNow() async {
        await depositsViewModel.updateDeposit(
            id: deposit.id,
            title: deposit.title,
            bankName: deposit.bankName ?? "",
            amount: deposit.amount,
            currency: deposit.currency,
            openDate: deposit.openDate,
            closeDate: deposit.closeDate,
            annualInterestRate: deposit.annualInterestRate,
            interestType: deposit.interestType,
            capitalizationPeriod: deposit.capitalizationPeriod,
            allowsReplenishment: deposit.allowsReplenishment,
            allowsPartialWithdrawal: deposit.allowsPartialWithdrawal,
            isRevocable: deposit.isRevocable,
            earlyWithdrawalRate: deposit.earlyWithdrawalRate,
            actualCloseDate: Date()
        )
        if let refreshed = depositsViewModel.deposits.first(where: { $0.id == deposit.id }) {
            deposit = refreshed
            await detailViewModel.refresh(deposit: refreshed)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let bankName = deposit.bankName, !bankName.isEmpty {
                Text(bankName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Text("\(deposit.amount, specifier: "%.0f") \(deposit.currency.rawValue)")
                .font(.largeTitle)
                .fontWeight(.bold)
                .accessibilityLabel(String(format: LanguageBundle.string("deposits.detail.amount.accessibility.format"), deposit.amount, deposit.currency.rawValue))

            HStack(spacing: 8) {
                badge(
                    text: isClosed ? LanguageBundle.string("deposits.status.closed") : LanguageBundle.string("deposits.status.active"),
                    tint: isClosed ? .secondary : .brand
                )
                badge(text: String(format: LanguageBundle.string("deposits.rate.format"), deposit.annualInterestRate), tint: .secondary)
                if deposit.interestType == .capitalized {
                    badge(text: LanguageBundle.string("deposits.interestType.capitalized"), icon: "arrow.triangle.2.circlepath", tint: .secondary)
                }
                if !deposit.isRevocable {
                    badge(text: LanguageBundle.string("deposits.field.irrevocable"), icon: "lock.fill", tint: .secondary)
                }
            }
            .accessibilityElement(children: .combine)

            if isOpen {
                Button(LanguageBundle.string("deposits.detail.closeAction")) {
                    showCloseConfirm = true
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
    }

    private func badge(text: String, icon: String? = nil, tint: Color) -> some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
            }
            Text(text)
        }
        .font(.caption2)
        .fontWeight(.medium)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(tint.opacity(0.15))
        .foregroundColor(tint)
        .clipShape(Capsule())
    }

    // MARK: - Chart

    private var actualPoints: [DepositBalancePoint] {
        detailViewModel.chartPoints.filter { !$0.isProjected }
    }

    private var projectedPoints: [DepositBalancePoint] {
        // Prepend the last actual point so the dashed segment visually connects to the solid line.
        let projected = detailViewModel.chartPoints.filter { $0.isProjected }
        guard let lastActual = actualPoints.last, !projected.isEmpty else { return [] }
        return [lastActual] + projected
    }

    private var chartAccessibilityLabel: String {
        guard let first = detailViewModel.chartPoints.first,
              let last = detailViewModel.chartPoints.last else { return "" }
        return String(format: LanguageBundle.string("deposits.detail.chart.accessibility.format"),
                      first.balance, last.balance, deposit.currency.rawValue)
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LanguageBundle.string("deposits.detail.chart.title"))
                .font(.headline)

            if detailViewModel.chartPoints.count > 1 {
                Chart {
                    ForEach(actualPoints) { point in
                        LineMark(x: .value("Date", point.date),
                                 y: .value("Balance", point.balance))
                            .foregroundStyle(Color.brand)
                    }
                    ForEach(projectedPoints) { point in
                        LineMark(x: .value("Date", point.date),
                                 y: .value("Balance", point.balance))
                            .foregroundStyle(Color.orange)
                            .lineStyle(StrokeStyle(dash: [4, 4]))
                    }
                }
                .frame(height: 180)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(chartAccessibilityLabel)
            } else {
                Text(LanguageBundle.string("deposits.detail.chart.empty"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
    }

    // MARK: - Transaction history

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(LanguageBundle.string("deposits.detail.transactions.title"))
                    .font(.headline)
                Spacer()
                if isOpen && deposit.allowsReplenishment {
                    Button(LanguageBundle.string("deposits.detail.addContribution.action")) {
                        transactionSheetKind = .contribution
                    }
                    .font(.caption)
                }
                if isOpen && deposit.allowsPartialWithdrawal {
                    Button(LanguageBundle.string("deposits.detail.addWithdrawal.action")) {
                        transactionSheetKind = .withdrawal
                    }
                    .font(.caption)
                }
            }

            if detailViewModel.transactions.isEmpty {
                Text(LanguageBundle.string("deposits.detail.transactions.empty"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(detailViewModel.transactionsWithRunningBalance(), id: \.transaction.id) { entry in
                        transactionRow(entry.transaction, balanceAfter: entry.balanceAfter)
                        if entry.transaction.id != detailViewModel.transactionsWithRunningBalance().last?.transaction.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func transactionRow(_ transaction: DepositTransaction, balanceAfter: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale)))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: LanguageBundle.string("deposits.detail.transaction.balanceAfter.format"),
                            balanceAfter, deposit.currency.rawValue))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("\(transaction.amount > 0 ? "+" : "")\(transaction.amount, specifier: "%.0f") \(deposit.currency.rawValue)")
                .fontWeight(.medium)
                .foregroundColor(transaction.amount > 0 ? .brand : .red)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Add Transaction Sheet

private enum TransactionKind: Identifiable, Equatable {
    case contribution
    case withdrawal
    var id: Self { self }
}

private struct AddTransactionSheet: View {
    let kind: TransactionKind
    let openDate: Date
    let currency: String
    let maxWithdrawal: Double
    let onSave: (Double, Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var amountText = ""
    @State private var validationError: String?

    private var title: String {
        switch kind {
        case .contribution: return LanguageBundle.string("deposits.detail.addContribution.title")
        case .withdrawal: return LanguageBundle.string("deposits.detail.addWithdrawal.title")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(LanguageBundle.string("deposits.detail.transactionDate"), selection: $date, in: openDate...Date(), displayedComponents: .date)
                    HStack {
                        TextField(LanguageBundle.string("deposits.detail.transactionAmount"), text: $amountText)
                            .keyboardType(.decimalPad)
                        Text(currency)
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
            .navigationTitle(title)
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
        guard let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")), amount > 0 else {
            validationError = LanguageBundle.string("deposits.detail.error.invalidAmount")
            return
        }
        if kind == .withdrawal, amount > maxWithdrawal {
            validationError = LanguageBundle.string("deposits.detail.error.withdrawalTooLarge")
            return
        }
        let signedAmount = kind == .contribution ? amount : -amount
        onSave(signedAmount, date)
        dismiss()
    }
}
