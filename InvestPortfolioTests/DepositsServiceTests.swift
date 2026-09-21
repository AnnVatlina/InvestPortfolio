//
//  DepositsServiceTests.swift
//  InvestPortfolioTests
//
//  Unit tests for DefaultDepositsService.incomeSummary — simple vs. capitalized interest.
//

import Testing
import Foundation
@testable import InvestPortfolio

// MARK: - Helpers

private var utcCalendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal
}

private func utcDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    utcCalendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
}

private func makeDeposit(
    amount: Double = 100_000,
    openDate: Date,
    closeDate: Date? = nil,
    rate: Double = 12.0,
    interestType: DepositInterestType = .simple,
    capitalizationPeriod: CapitalizationPeriod? = nil
) -> Deposit {
    Deposit(
        title: "T",
        amount: amount,
        currency: .RUB,
        openDate: openDate,
        closeDate: closeDate,
        annualInterestRate: rate,
        interestType: interestType,
        capitalizationPeriod: capitalizationPeriod
    )
}

// MARK: - Simple interest (regression)

@Suite("DefaultDepositsService — simple interest")
struct DepositsServiceSimpleInterestTests {

    let service = DefaultDepositsService(repository: InMemoryDepositsRepository())

    @Test("Simple interest over 100 days matches the linear formula")
    func simpleInterestMatchesLinearFormula() {
        let openDate = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        let deposit = makeDeposit(amount: 100_000, openDate: openDate, rate: 12.0)
        let summary = service.incomeSummary(for: deposit, asOf: Date())

        let dailyRate = 0.12 / 365.0
        let expected = 100_000 * dailyRate * 100
        #expect(abs(summary.incomeToDate - expected) < 1.0)
    }
}

// MARK: - Capitalized interest

@Suite("DefaultDepositsService — capitalized interest")
struct DepositsServiceCapitalizedInterestTests {

    let utcService = DefaultDepositsService(repository: InMemoryDepositsRepository(), calendar: utcCalendar)
    let service = DefaultDepositsService(repository: InMemoryDepositsRepository())

    @Test("A single capitalization period matches plain simple interest for the same span")
    func capitalizedSinglePeriodMatchesSimpleInterest() {
        let open = utcDate(2025, 1, 1)
        let end = utcDate(2025, 2, 1) // exactly one monthly boundary, no compounding has kicked in yet
        let capitalized = makeDeposit(openDate: open, closeDate: end, interestType: .capitalized, capitalizationPeriod: .monthly)
        let simple = makeDeposit(openDate: open, closeDate: end, interestType: .simple)

        let capitalizedSummary = utcService.incomeSummary(for: capitalized, asOf: end)
        let simpleSummary = utcService.incomeSummary(for: simple, asOf: end)

        #expect(abs(capitalizedSummary.incomeToDate - simpleSummary.incomeToDate) < 0.01)
    }

    @Test("Capitalized income exceeds simple interest once more than one period has elapsed")
    func capitalizedExceedsSimpleOverMultiplePeriods() {
        let openDate = Calendar.current.date(byAdding: .day, value: -400, to: Date())!
        let capitalized = makeDeposit(openDate: openDate, rate: 12.0, interestType: .capitalized, capitalizationPeriod: .monthly)
        let simple = makeDeposit(openDate: openDate, rate: 12.0, interestType: .simple)

        let capitalizedIncome = service.incomeSummary(for: capitalized, asOf: Date()).incomeToDate
        let simpleIncome = service.incomeSummary(for: simple, asOf: Date()).incomeToDate

        #expect(capitalizedIncome > simpleIncome)
    }

    @Test("More frequent capitalization yields more income over the same span")
    func moreFrequentCapitalizationYieldsMoreIncome() {
        let openDate = Calendar.current.date(byAdding: .day, value: -730, to: Date())!

        func income(_ period: CapitalizationPeriod) -> Double {
            let deposit = makeDeposit(openDate: openDate, rate: 12.0, interestType: .capitalized, capitalizationPeriod: period)
            return service.incomeSummary(for: deposit, asOf: Date()).incomeToDate
        }

        let monthly = income(.monthly)
        let quarterly = income(.quarterly)
        let yearly = income(.yearly)

        #expect(monthly > quarterly)
        #expect(quarterly > yearly)
    }

    @Test("Capitalized deposit without a period falls back to simple interest")
    func capitalizedWithoutPeriodFallsBackToSimple() {
        let openDate = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        let capitalizedNoPeriod = makeDeposit(openDate: openDate, rate: 12.0, interestType: .capitalized, capitalizationPeriod: nil)
        let simple = makeDeposit(openDate: openDate, rate: 12.0, interestType: .simple)

        let capitalizedIncome = service.incomeSummary(for: capitalizedNoPeriod, asOf: Date()).incomeToDate
        let simpleIncome = service.incomeSummary(for: simple, asOf: Date()).incomeToDate

        #expect(abs(capitalizedIncome - simpleIncome) < 0.01)
    }

    @Test("Zero rate produces zero income even when capitalized")
    func capitalizedZeroRateProducesZeroIncome() {
        let openDate = Calendar.current.date(byAdding: .day, value: -400, to: Date())!
        let deposit = makeDeposit(openDate: openDate, rate: 0.0, interestType: .capitalized, capitalizationPeriod: .monthly)
        let income = service.incomeSummary(for: deposit, asOf: Date()).incomeToDate
        #expect(income == 0)
    }

    @Test("Forecast for an active capitalized deposit exceeds today's accrued income")
    func forecastExceedsIncomeToDateForCapitalizedDeposit() {
        let openDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let closeDate = Calendar.current.date(byAdding: .day, value: 335, to: Date())!
        let deposit = makeDeposit(openDate: openDate, closeDate: closeDate, rate: 12.0, interestType: .capitalized, capitalizationPeriod: .monthly)

        let summary = service.incomeSummary(for: deposit, asOf: Date())
        #expect(summary.forecastIncomeToCloseDate != nil)
        #expect(summary.forecastIncomeToCloseDate! > summary.incomeToDate)
    }
}
