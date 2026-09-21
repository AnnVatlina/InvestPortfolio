//
//  DepositDetailViewModel.swift
//
//  Builds the transaction history and balance-over-time chart series for a single deposit.
//

import Foundation

struct DepositBalancePoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let balance: Double
    // True for points after "now" — drawn as a dashed forecast, not an actual measurement.
    let isProjected: Bool
}

@MainActor
final class DepositDetailViewModel: ObservableObject {
    @Published private(set) var transactions: [DepositTransaction] = []
    @Published private(set) var chartPoints: [DepositBalancePoint] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: any DepositsService
    private var deposit: Deposit
    private let calendar: Calendar

    init(deposit: Deposit, service: any DepositsService, calendar: Calendar = .current) {
        self.deposit = deposit
        self.service = service
        self.calendar = calendar
    }

    func load() async {
        await refresh(deposit: deposit)
    }

    /// Re-fetches transactions and rebuilds the chart for a (possibly updated) deposit —
    /// call after an edit, since SwiftData mutations don't update the instance held here in place.
    func refresh(deposit: Deposit) async {
        self.deposit = deposit
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            transactions = try await service.transactions(forDepositId: deposit.id)
            chartPoints = buildChartPoints()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Running balance immediately after each transaction, oldest first.
    func transactionsWithRunningBalance() -> [(transaction: DepositTransaction, balanceAfter: Double)] {
        var balance = deposit.amount
        var result: [(DepositTransaction, Double)] = []
        for transaction in transactions.sorted(by: { $0.date < $1.date }) {
            balance += transaction.amount
            result.append((transaction, balance))
        }
        return result
    }

    /// Principal on deposit right now (original amount plus all contributions/withdrawals so
    /// far) — used to cap withdrawal amounts. Deliberately excludes accrued interest, which
    /// isn't available to withdraw until the deposit is actually closed.
    var currentPrincipalBalance: Double {
        deposit.amount + transactions.reduce(0.0) { $0 + $1.amount }
    }

    // MARK: - Add transaction

    func addTransaction(amount: Double, date: Date) async throws {
        let transaction = DepositTransaction(depositId: deposit.id, date: date, amount: amount)
        try await service.addTransaction(transaction)
        await refresh(deposit: deposit)
    }

    // MARK: - Early closure

    /// Interest that would be forfeited if the deposit were closed right now instead of held
    /// to term — zero unless it's irrevocable, has an early-withdrawal rate, and hasn't
    /// reached its planned close date yet. Used to warn before confirming an early closure.
    func projectedEarlyClosureLoss() -> Double {
        let now = Date()
        guard !deposit.isRevocable, deposit.earlyWithdrawalRate != nil,
              let close = deposit.closeDate, close > now else { return 0 }

        let normalIncome = service.incomeSummary(for: deposit, transactions: transactions, asOf: now).incomeToDate

        let previewDeposit = Deposit(
            id: deposit.id, title: deposit.title, bankName: deposit.bankName, amount: deposit.amount,
            currency: deposit.currency, createdAt: deposit.createdAt, openDate: deposit.openDate,
            closeDate: deposit.closeDate, annualInterestRate: deposit.annualInterestRate,
            interestType: deposit.interestType, capitalizationPeriod: deposit.capitalizationPeriod,
            allowsReplenishment: deposit.allowsReplenishment, allowsPartialWithdrawal: deposit.allowsPartialWithdrawal,
            isRevocable: deposit.isRevocable, earlyWithdrawalRate: deposit.earlyWithdrawalRate, actualCloseDate: now
        )
        let penalizedIncome = service.incomeSummary(for: previewDeposit, transactions: transactions, asOf: now).incomeToDate

        return max(0, normalIncome - penalizedIncome)
    }

    // MARK: - Chart

    private func buildChartPoints() -> [DepositBalancePoint] {
        let now = Date()
        let end = deposit.actualCloseDate ?? deposit.closeDate ?? now
        let chartEnd = max(end, deposit.openDate)

        var sampleDates: Set<Date> = [deposit.openDate, min(now, chartEnd)]

        // Forecast tail endpoint — only meaningful for a still-open deposit with a planned close date.
        if deposit.actualCloseDate == nil, let close = deposit.closeDate, close > now {
            sampleDates.insert(close)
        }

        for transaction in transactions where transaction.date > deposit.openDate && transaction.date <= chartEnd {
            sampleDates.insert(transaction.date)
        }

        // Capitalization boundaries give an accurate step curve; for simple interest, monthly
        // steps just keep the line's resolution consistent — the growth itself is linear either way.
        if deposit.interestType == .capitalized, let period = deposit.capitalizationPeriod {
            var boundary = deposit.openDate
            while let next = calendar.date(byAdding: period.dateComponents, to: boundary), next <= chartEnd {
                sampleDates.insert(next)
                boundary = next
            }
        } else {
            var monthBoundary = deposit.openDate
            while let next = calendar.date(byAdding: .month, value: 1, to: monthBoundary), next <= chartEnd {
                sampleDates.insert(next)
                monthBoundary = next
            }
        }

        return sampleDates.sorted().map { date in
            let netTransactions = transactions
                .filter { $0.date > deposit.openDate && $0.date <= date }
                .reduce(0.0) { $0 + $1.amount }
            let income = service.incomeSummary(for: deposit, transactions: transactions, asOf: date).incomeToDate
            let balance = deposit.amount + netTransactions + income
            return DepositBalancePoint(date: date, balance: balance, isProjected: date > now)
        }
    }
}
