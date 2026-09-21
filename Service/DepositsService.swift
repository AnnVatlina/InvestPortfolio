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
    func update(id: UUID, title: String, bankName: String?, amount: Double, currency: DepositCurrency, openDate: Date, closeDate: Date?, annualInterestRate: Double, interestType: DepositInterestType, capitalizationPeriod: CapitalizationPeriod?) async throws
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

    func update(id: UUID, title: String, bankName: String?, amount: Double, currency: DepositCurrency, openDate: Date, closeDate: Date?, annualInterestRate: Double, interestType: DepositInterestType, capitalizationPeriod: CapitalizationPeriod?) async throws {
        try await repository.update(id: id, title: title, bankName: bankName, amount: amount, currency: currency, openDate: openDate, closeDate: closeDate, annualInterestRate: annualInterestRate, interestType: interestType, capitalizationPeriod: capitalizationPeriod)
    }

    func incomeSummary(for deposit: Deposit, asOf date: Date) -> DepositIncomeSummary {
        // For closed deposits, income is calculated up to the close date, not today
        let cappedDate = deposit.closeDate.map { min(date, $0) } ?? date
        let incomeEarned = income(for: deposit, until: cappedDate)

        // Show the forecast only if the close date hasn't arrived yet
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
        switch deposit.interestType {
        case .simple:
            return simpleIncome(for: deposit, until: end)
        case .capitalized:
            return capitalizedIncome(for: deposit, until: end)
        }
    }

    private func simpleIncome(for deposit: Deposit, until end: Date) -> Double {
        let days = daysBetween(deposit.openDate - 1, end)
        let dailyRate = (deposit.annualInterestRate / 100.0) / 365.0
        return deposit.amount * dailyRate * Double(days)
    }

    // Начисляет проценты на каждой границе периода капитализации к телу вклада,
    // затем считает простой процент на остатке (неполном периоде) до даты `end`.
    private func capitalizedIncome(for deposit: Deposit, until end: Date) -> Double {
        guard let period = deposit.capitalizationPeriod else {
            return simpleIncome(for: deposit, until: end)
        }
        let dailyRate = (deposit.annualInterestRate / 100.0) / 365.0
        var principal = deposit.amount
        var periodStart = deposit.openDate
        // Тот же сдвиг на 1 секунду, что и в simpleIncome — включает день открытия в счёт
        // дней только для самого первого периода, дальше границы периодов считаются как есть.
        var dayCountAnchor = deposit.openDate - 1

        while let periodEnd = calendar.date(byAdding: period.dateComponents, to: periodStart),
              periodEnd <= end {
            let days = daysBetween(dayCountAnchor, periodEnd)
            principal += principal * dailyRate * Double(days)
            periodStart = periodEnd
            dayCountAnchor = periodEnd
        }

        let remainingDays = daysBetween(dayCountAnchor, end)
        let finalAmount = principal + principal * dailyRate * Double(remainingDays)
        return finalAmount - deposit.amount
    }

    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let comps = calendar.dateComponents([.day], from: startDay, to: endDay)
        return max(0, comps.day ?? 0)
    }
}
