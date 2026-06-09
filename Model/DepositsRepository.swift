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
    func update(id: UUID, title: String, bankName: String?, amount: Double, currency: DepositCurrency, openDate: Date, closeDate: Date?, annualInterestRate: Double) async throws
    /// Insert or update a cache record matched by serverId.
    func upsert(serverId: UUID, title: String, bankName: String?, amount: Double, currency: DepositCurrency, openDate: Date, closeDate: Date?, annualInterestRate: Double, createdAt: Date) async throws
    func deleteByServerId(_ serverId: UUID) async throws
}

final class InMemoryDepositsRepository: DepositsRepository {
    private var deposits: [Deposit] = []

    func fetchAll() async throws -> [Deposit] {
        deposits
    }

    func add(_ deposit: Deposit) async throws {
        deposits.append(deposit)
    }

    func delete(id: UUID) async throws {
        deposits.removeAll { $0.id == id }
    }

    func update(id: UUID, title: String, bankName: String?, amount: Double, currency: DepositCurrency, openDate: Date, closeDate: Date?, annualInterestRate: Double) async throws {
        guard let index = deposits.firstIndex(where: { $0.id == id }) else { return }
        deposits[index].title = title
        deposits[index].bankName = bankName
        deposits[index].amount = amount
        deposits[index].currency = currency
        deposits[index].openDate = openDate
        deposits[index].closeDate = closeDate
        deposits[index].annualInterestRate = annualInterestRate
    }

    func upsert(serverId: UUID, title: String, bankName: String?, amount: Double, currency: DepositCurrency, openDate: Date, closeDate: Date?, annualInterestRate: Double, createdAt: Date) async throws {
        if let index = deposits.firstIndex(where: { $0.serverId == serverId }) {
            deposits[index].title = title
            deposits[index].bankName = bankName
            deposits[index].amount = amount
            deposits[index].currency = currency
            deposits[index].openDate = openDate
            deposits[index].closeDate = closeDate
            deposits[index].annualInterestRate = annualInterestRate
        } else {
            let deposit = Deposit(
                serverId: serverId,
                title: title,
                bankName: bankName,
                amount: amount,
                currency: currency,
                createdAt: createdAt,
                openDate: openDate,
                closeDate: closeDate,
                annualInterestRate: annualInterestRate
            )
            deposits.append(deposit)
        }
    }

    func deleteByServerId(_ serverId: UUID) async throws {
        deposits.removeAll { $0.serverId == serverId }
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
        try modelContext.save()
    }

    func update(id: UUID, title: String, bankName: String?, amount: Double, currency: DepositCurrency, openDate: Date, closeDate: Date?, annualInterestRate: Double) async throws {
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
        try modelContext.save()
    }

    func upsert(serverId: UUID, title: String, bankName: String?, amount: Double, currency: DepositCurrency, openDate: Date, closeDate: Date?, annualInterestRate: Double, createdAt: Date) async throws {
        let predicate = #Predicate<Deposit> { $0.serverId == serverId }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let existing = try modelContext.fetch(descriptor).first {
            existing.title = title
            existing.bankName = bankName
            existing.amount = amount
            existing.currency = currency
            existing.openDate = openDate
            existing.closeDate = closeDate
            existing.annualInterestRate = annualInterestRate
        } else {
            let deposit = Deposit(
                serverId: serverId,
                title: title,
                bankName: bankName,
                amount: amount,
                currency: currency,
                createdAt: createdAt,
                openDate: openDate,
                closeDate: closeDate,
                annualInterestRate: annualInterestRate
            )
            modelContext.insert(deposit)
        }
        try modelContext.save()
    }

    func deleteByServerId(_ serverId: UUID) async throws {
        let predicate = #Predicate<Deposit> { $0.serverId == serverId }
        let descriptor = FetchDescriptor(predicate: predicate)
        guard let deposit = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(deposit)
        try modelContext.save()
    }
}
