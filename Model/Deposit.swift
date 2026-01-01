//
//  Deposit.swift
//
//  Created by Anna on 30.12.25.
//

import Foundation
import SwiftData

@Model
final class Deposit {
    var id: UUID
    var title: String
    var bankName: String?
    var amount: Double
    var currency: DepositCurrency
    var createdAt: Date

    var openDate: Date
    var closeDate: Date?
    var annualInterestRate: Double

    init(
        id: UUID = UUID(),
        title: String,
        bankName: String? = nil,
        amount: Double,
        currency: DepositCurrency,
        createdAt: Date = Date(),
        openDate: Date,
        closeDate: Date? = nil,
        annualInterestRate: Double
    ) {
        self.id = id
        self.title = title
        self.bankName = bankName
        self.amount = amount
        self.currency = currency
        self.createdAt = createdAt
        self.openDate = openDate
        self.closeDate = closeDate
        self.annualInterestRate = annualInterestRate
    }
}
