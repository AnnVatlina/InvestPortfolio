//
//  DepositsService.swift
//  InvestPortfolio
//
//  Created by Anna on 30.12.25.
//

import Foundation

// Result of a deposit's interest calculations
struct DepositIncomeSummary: Equatable {
    let incomeToDate: Double
    let forecastIncomeToCloseDate: Double?
}

protocol DepositsService {
    func fetchAll() async throws -> [Deposit]
    func add(_ deposit: Deposit) async throws
    func delete(id: UUID) async throws
    func update(id: UUID, title: String, bankName: String?, amount: Double, currency: DepositCurrency, openDate: Date, closeDate: Date?, annualInterestRate: Double, interestType: DepositInterestType, capitalizationPeriod: CapitalizationPeriod?, allowsReplenishment: Bool, allowsPartialWithdrawal: Bool, isRevocable: Bool, earlyWithdrawalRate: Double?, actualCloseDate: Date?) async throws
    func incomeSummary(for deposit: Deposit, transactions: [DepositTransaction], asOf date: Date) -> DepositIncomeSummary

    // MARK: - Transactions (contributions / partial withdrawals)

    func transactions(forDepositId depositId: UUID) async throws -> [DepositTransaction]
    func fetchAllTransactions() async throws -> [DepositTransaction]
    func addTransaction(_ transaction: DepositTransaction) async throws
    func deleteTransaction(id: UUID) async throws
}

extension DepositsService {
    /// Convenience for callers that don't have the deposit's transaction history at hand —
    /// equivalent to passing an empty transactions array.
    func incomeSummary(for deposit: Deposit, asOf date: Date) -> DepositIncomeSummary {
        incomeSummary(for: deposit, transactions: [], asOf: date)
    }
}

final class DefaultDepositsService: DepositsService {
    private let repository: DepositsRepository
    private let calendar: Calendar

    init(repository: DepositsRepository, calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.repository = repository
        self.calendar = calendar
    }

    func fetchAll() async throws -> [Deposit] {
        try await repository.fetchAll()
    }

    func add(_ deposit: Deposit) async throws {
        try await repository.add(deposit)
    }

    func delete(id: UUID) async throws {
        try await repository.delete(id: id)
    }

    func update(id: UUID, title: String, bankName: String?, amount: Double, currency: DepositCurrency, openDate: Date, closeDate: Date?, annualInterestRate: Double, interestType: DepositInterestType, capitalizationPeriod: CapitalizationPeriod?, allowsReplenishment: Bool, allowsPartialWithdrawal: Bool, isRevocable: Bool, earlyWithdrawalRate: Double?, actualCloseDate: Date?) async throws {
        try await repository.update(id: id, title: title, bankName: bankName, amount: amount, currency: currency, openDate: openDate, closeDate: closeDate, annualInterestRate: annualInterestRate, interestType: interestType, capitalizationPeriod: capitalizationPeriod, allowsReplenishment: allowsReplenishment, allowsPartialWithdrawal: allowsPartialWithdrawal, isRevocable: isRevocable, earlyWithdrawalRate: earlyWithdrawalRate, actualCloseDate: actualCloseDate)
    }

    func transactions(forDepositId depositId: UUID) async throws -> [DepositTransaction] {
        try await repository.transactions(forDepositId: depositId)
    }

    func fetchAllTransactions() async throws -> [DepositTransaction] {
        try await repository.fetchAllTransactions()
    }

    func addTransaction(_ transaction: DepositTransaction) async throws {
        try await repository.addTransaction(transaction)
    }

    func deleteTransaction(id: UUID) async throws {
        try await repository.deleteTransaction(id: id)
    }

    func incomeSummary(for deposit: Deposit, transactions: [DepositTransaction], asOf date: Date) -> DepositIncomeSummary {
        // For deposits reaching their planned close date, income is calculated up to that
        // date, not today. An explicit actualCloseDate (the depositor closed it themselves,
        // possibly early) takes precedence and caps income there instead.
        let plannedCap = deposit.closeDate.map { min(date, $0) } ?? date
        let cappedDate = deposit.actualCloseDate.map { min(date, $0) } ?? plannedCap

        // An irrevocable deposit closed before its planned close date loses its agreed rate —
        // the whole term is recalculated at the (lower) early-withdrawal rate instead.
        let earlyWithdrawalPenaltyApplies: Bool = {
            guard !deposit.isRevocable,
                  let actualClose = deposit.actualCloseDate,
                  let plannedClose = deposit.closeDate,
                  actualClose < plannedClose,
                  deposit.earlyWithdrawalRate != nil
            else { return false }
            return true
        }()
        let rateOverride = earlyWithdrawalPenaltyApplies ? deposit.earlyWithdrawalRate : nil

        let incomeEarned = income(for: deposit, transactions: transactions, until: cappedDate, rateOverride: rateOverride)

        // The forecast always assumes the deposit is held to its planned close date at the
        // agreed rate — it's moot once the deposit has actually been closed.
        let forecast: Double?
        if deposit.actualCloseDate == nil, let close = deposit.closeDate, close > deposit.openDate, close > date {
            forecast = income(for: deposit, transactions: transactions, until: close, rateOverride: nil)
        } else {
            forecast = nil
        }
        return DepositIncomeSummary(incomeToDate: incomeEarned, forecastIncomeToCloseDate: forecast)
    }

    // A point in time where the deposit's principal changes (a contribution/withdrawal)
    // or where accrued interest folds into the principal (a capitalization boundary).
    private enum Checkpoint {
        case capitalization(Date)
        case transaction(Date, amount: Double)

        var date: Date {
            switch self {
            case .capitalization(let date): return date
            case .transaction(let date, _): return date
            }
        }
    }

    // Walks the deposit's timeline from openDate to `end`, applying transactions to the
    // principal as they occur and folding accrued interest into the principal at each
    // capitalization boundary (for capitalized deposits). Reduces to the plain simple/
    // capitalized formulas when there are no transactions.
    private func income(for deposit: Deposit, transactions: [DepositTransaction], until end: Date, rateOverride: Double? = nil) -> Double {
        let end = max(deposit.openDate, end)
        let dailyRate = ((rateOverride ?? deposit.annualInterestRate) / 100.0) / 365.0

        var checkpoints: [Checkpoint] = transactions
            .filter { $0.date > deposit.openDate && $0.date <= end }
            .map { .transaction($0.date, amount: $0.amount) }

        if deposit.interestType == .capitalized, let period = deposit.capitalizationPeriod {
            var boundary = deposit.openDate
            while let next = calendar.date(byAdding: period.dateComponents, to: boundary), next <= end {
                checkpoints.append(.capitalization(next))
                boundary = next
            }
        }

        checkpoints.sort { $0.date < $1.date }

        var principal = deposit.amount
        var pendingInterest = 0.0
        var netTransactions = 0.0
        // The 1-second shift includes the opening day in the day count only for the very
        // first segment — later checkpoint boundaries are counted as-is.
        var anchor = deposit.openDate - 1

        for checkpoint in checkpoints {
            let days = daysBetween(anchor, checkpoint.date)
            pendingInterest += principal * dailyRate * Double(days)
            switch checkpoint {
            case .capitalization:
                principal += pendingInterest
                pendingInterest = 0
            case .transaction(_, let amount):
                principal += amount
                netTransactions += amount
            }
            anchor = checkpoint.date
        }

        let remainingDays = daysBetween(anchor, end)
        pendingInterest += principal * dailyRate * Double(remainingDays)

        let finalAmount = principal + pendingInterest
        return finalAmount - deposit.amount - netTransactions
    }

    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let comps = calendar.dateComponents([.day], from: startDay, to: endDay)
        return max(0, comps.day ?? 0)
    }
}
