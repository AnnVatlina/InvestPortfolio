//
//  DepositsRepository.swift
//
//  Created by Anna on 30.12.25.
//

import Foundation
import SwiftData

protocol DepositsRepository {
    func fetchAll() async throws -> [Deposit]
    func add(_ deposit: Deposit) async throws
    func delete(id: UUID) async throws
    func update(id: UUID, title: String, bankName: String?, amount: Double, currency: DepositCurrency, openDate: Date, closeDate: Date?, annualInterestRate: Double, interestType: DepositInterestType, capitalizationPeriod: CapitalizationPeriod?, allowsReplenishment: Bool, allowsPartialWithdrawal: Bool, isRevocable: Bool, earlyWithdrawalRate: Double?, actualCloseDate: Date?) async throws

    // MARK: - Transactions (contributions / partial withdrawals)

    func transactions(forDepositId depositId: UUID) async throws -> [DepositTransaction]
    func addTransaction(_ transaction: DepositTransaction) async throws
    func deleteTransaction(id: UUID) async throws
}

final class InMemoryDepositsRepository: DepositsRepository {
    private var deposits: [Deposit] = []
    private var depositTransactions: [DepositTransaction] = []

    func fetchAll() async throws -> [Deposit] {
        deposits
    }

    func add(_ deposit: Deposit) async throws {
        deposits.append(deposit)
    }

    func delete(id: UUID) async throws {
        deposits.removeAll { $0.id == id }
        depositTransactions.removeAll { $0.depositId == id }
    }

    func update(id: UUID, title: String, bankName: String?, amount: Double, currency: DepositCurrency, openDate: Date, closeDate: Date?, annualInterestRate: Double, interestType: DepositInterestType, capitalizationPeriod: CapitalizationPeriod?, allowsReplenishment: Bool, allowsPartialWithdrawal: Bool, isRevocable: Bool, earlyWithdrawalRate: Double?, actualCloseDate: Date?) async throws {
        guard let index = deposits.firstIndex(where: { $0.id == id }) else { return }
        deposits[index].title = title
        deposits[index].bankName = bankName
        deposits[index].amount = amount
        deposits[index].currency = currency
        deposits[index].openDate = openDate
        deposits[index].closeDate = closeDate
        deposits[index].annualInterestRate = annualInterestRate
        deposits[index].interestType = interestType
        deposits[index].capitalizationPeriod = capitalizationPeriod
        deposits[index].allowsReplenishment = allowsReplenishment
        deposits[index].allowsPartialWithdrawal = allowsPartialWithdrawal
        deposits[index].isRevocable = isRevocable
        deposits[index].earlyWithdrawalRate = earlyWithdrawalRate
        deposits[index].actualCloseDate = actualCloseDate
    }

    func transactions(forDepositId depositId: UUID) async throws -> [DepositTransaction] {
        depositTransactions
            .filter { $0.depositId == depositId }
            .sorted { $0.date < $1.date }
    }

    func addTransaction(_ transaction: DepositTransaction) async throws {
        depositTransactions.append(transaction)
    }

    func deleteTransaction(id: UUID) async throws {
        depositTransactions.removeAll { $0.id == id }
    }

}

@ModelActor
actor SwiftDataDepositsRepository: @preconcurrency DepositsRepository {
    func fetchAll() async throws -> [Deposit] {
        let descriptor = FetchDescriptor<Deposit>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func add(_ deposit: Deposit) async throws {
        modelContext.insert(deposit)
        try modelContext.save()
    }

    func delete(id: UUID) async throws {
        let predicate = #Predicate<Deposit> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        guard let deposit = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(deposit)

        let transactionPredicate = #Predicate<DepositTransaction> { $0.depositId == id }
        let transactions = try modelContext.fetch(FetchDescriptor(predicate: transactionPredicate))
        transactions.forEach { modelContext.delete($0) }

        try modelContext.save()
    }

    func update(id: UUID, title: String, bankName: String?, amount: Double, currency: DepositCurrency, openDate: Date, closeDate: Date?, annualInterestRate: Double, interestType: DepositInterestType, capitalizationPeriod: CapitalizationPeriod?, allowsReplenishment: Bool, allowsPartialWithdrawal: Bool, isRevocable: Bool, earlyWithdrawalRate: Double?, actualCloseDate: Date?) async throws {
        let predicate = #Predicate<Deposit> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        guard let deposit = try modelContext.fetch(descriptor).first else { return }
        deposit.title = title
        deposit.bankName = bankName
        deposit.amount = amount
        deposit.currency = currency
        deposit.openDate = openDate
        deposit.closeDate = closeDate
        deposit.annualInterestRate = annualInterestRate
        deposit.interestType = interestType
        deposit.capitalizationPeriod = capitalizationPeriod
        deposit.allowsReplenishment = allowsReplenishment
        deposit.allowsPartialWithdrawal = allowsPartialWithdrawal
        deposit.isRevocable = isRevocable
        deposit.earlyWithdrawalRate = earlyWithdrawalRate
        deposit.actualCloseDate = actualCloseDate
        try modelContext.save()
    }

    func transactions(forDepositId depositId: UUID) async throws -> [DepositTransaction] {
        let predicate = #Predicate<DepositTransaction> { $0.depositId == depositId }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date, order: .forward)])
        return try modelContext.fetch(descriptor)
    }

    func addTransaction(_ transaction: DepositTransaction) async throws {
        modelContext.insert(transaction)
        try modelContext.save()
    }

    func deleteTransaction(id: UUID) async throws {
        let predicate = #Predicate<DepositTransaction> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        guard let transaction = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(transaction)
        try modelContext.save()
    }

}
