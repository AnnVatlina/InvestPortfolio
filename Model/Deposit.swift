//
//  Deposit.swift
//
//  Created by Anna on 30.12.25.
//

import Foundation

struct Deposit: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var amount: Double
    var currency: DepositCurrency
    var createdAt: Date

    var openDate: Date
    var closeDate: Date?
    var annualInterestRate: Double

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        currency: DepositCurrency,
        createdAt: Date = Date(),
        openDate: Date,
        closeDate: Date? = nil,
        annualInterestRate: Double
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.currency = currency
        self.createdAt = createdAt
        self.openDate = openDate
        self.closeDate = closeDate
        self.annualInterestRate = annualInterestRate
    }
}

