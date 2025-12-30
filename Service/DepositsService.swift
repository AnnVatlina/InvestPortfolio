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

    func incomeSummary(for deposit: Deposit, asOf date: Date) -> DepositIncomeSummary {
        let incomeToday = income(for: deposit, until: date)
        let forecast: Double?
        if let close = deposit.closeDate, close > deposit.openDate {
            forecast = income(for: deposit, until: close)
        } else {
            forecast = nil
        }
        return DepositIncomeSummary(incomeToDate: incomeToday, forecastIncomeToCloseDate: forecast)
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

