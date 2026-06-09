//
//  DepositsService.swift
//  InvestPortfolio
//
//  Created by Anna on 30.12.25.
//

import Foundation

// Результат расчетов по вкладу
struct DepositIncomeSummary: Equatable {
    let incomeToDate: Double
    let forecastIncomeToCloseDate: Double?
}

protocol DepositsService {
    func fetchAll() async throws -> [Deposit]
    func add(_ deposit: Deposit) async throws
    func delete(id: UUID) async throws
    func update(id: UUID, title: String, bankName: String?, amount: Double, currency: DepositCurrency, openDate: Date, closeDate: Date?, annualInterestRate: Double) async throws
    /// Insert-or-update cache record matched by serverId (from API response).
    func upsert(serverId: UUID, title: String, bankName: String?, amount: Double, currency: DepositCurrency, openDate: Date, closeDate: Date?, annualInterestRate: Double, createdAt: Date) async throws
    func deleteByServerId(_ serverId: UUID) async throws
    func incomeSummary(for deposit: Deposit, asOf date: Date) -> DepositIncomeSummary
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

    func update(id: UUID, title: String, bankName: String?, amount: Double, currency: DepositCurrency, openDate: Date, closeDate: Date?, annualInterestRate: Double) async throws {
        try await repository.update(id: id, title: title, bankName: bankName, amount: amount, currency: currency, openDate: openDate, closeDate: closeDate, annualInterestRate: annualInterestRate)
    }

    func upsert(serverId: UUID, title: String, bankName: String?, amount: Double, currency: DepositCurrency, openDate: Date, closeDate: Date?, annualInterestRate: Double, createdAt: Date) async throws {
        try await repository.upsert(serverId: serverId, title: title, bankName: bankName, amount: amount, currency: currency, openDate: openDate, closeDate: closeDate, annualInterestRate: annualInterestRate, createdAt: createdAt)
    }

    func deleteByServerId(_ serverId: UUID) async throws {
        try await repository.deleteByServerId(serverId)
    }

    func incomeSummary(for deposit: Deposit, asOf date: Date) -> DepositIncomeSummary {
        // Для закрытых вкладов доход считается до даты закрытия, не до сегодня
        let cappedDate = deposit.closeDate.map { min(date, $0) } ?? date
        let incomeEarned = income(for: deposit, until: cappedDate)

        // Прогноз показываем только если дата закрытия ещё не наступила
        let forecast: Double?
        if let close = deposit.closeDate, close > deposit.openDate, close > date {
            forecast = income(for: deposit, until: close)
        } else {
            forecast = nil
        }
        return DepositIncomeSummary(incomeToDate: incomeEarned, forecastIncomeToCloseDate: forecast)
    }

    private func income(for deposit: Deposit, until date: Date) -> Double {
        let end = max(deposit.openDate, date)
        let days = daysBetween(deposit.openDate - 1, end)
        let dailyRate = (deposit.annualInterestRate / 100.0) / 365.0
        return deposit.amount * dailyRate * Double(days)
    }

    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let comps = calendar.dateComponents([.day], from: startDay, to: endDay)
        return max(0, comps.day ?? 0)
    }
}
