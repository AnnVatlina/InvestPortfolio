//
//  DepositResponse.swift
//  InvestPortfolio
//
//  Codable DTOs for the Rentivo deposits API.
//  Amounts arrive as strings (API convention); dates decoded via iso8601 strategy.
//

import Foundation

// MARK: - API Response DTO

struct DepositResponse: Decodable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let bankName: String?
    let amount: String
    let currency: String
    let openDate: Date
    let closeDate: Date?
    let annualRate: String
    let interestType: String?
    let compoundFrequency: String?
    let incomeToDate: String?
    let daysElapsed: Int?
    let createdAt: Date

    // MARK: - Convenience helpers

    var amountDouble: Double { Double(amount) ?? 0 }
    var annualRateDouble: Double { Double(annualRate) ?? 0 }
    var depositCurrency: DepositCurrency { DepositCurrency(rawValue: currency) ?? .RUB }
}

// MARK: - Request bodies

struct DepositCreate: Encodable {
    let title: String
    let bankName: String?
    let amount: String
    let currency: String
    let openDate: String
    let closeDate: String?
    let annualRate: String
}

struct DepositUpdate: Encodable {
    let title: String
    let bankName: String?
    let amount: String
    let currency: String
    let openDate: String
    let closeDate: String?
    let annualRate: String
}

// MARK: - Factory helpers

private let depositDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    return f
}()

extension DepositCreate {
    init(
        title: String,
        bankName: String?,
        amount: Double,
        currency: DepositCurrency,
        openDate: Date,
        closeDate: Date?,
        annualInterestRate: Double
    ) {
        self.title = title
        self.bankName = bankName
        self.amount = String(amount)
        self.currency = currency.rawValue
        self.openDate = depositDateFormatter.string(from: openDate)
        self.closeDate = closeDate.map { depositDateFormatter.string(from: $0) }
        self.annualRate = String(annualInterestRate)
    }
}

extension DepositUpdate {
    init(
        title: String,
        bankName: String?,
        amount: Double,
        currency: DepositCurrency,
        openDate: Date,
        closeDate: Date?,
        annualInterestRate: Double
    ) {
        self.title = title
        self.bankName = bankName
        self.amount = String(amount)
        self.currency = currency.rawValue
        self.openDate = depositDateFormatter.string(from: openDate)
        self.closeDate = closeDate.map { depositDateFormatter.string(from: $0) }
        self.annualRate = String(annualInterestRate)
    }
}
