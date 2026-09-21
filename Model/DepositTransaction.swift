//
//  DepositTransaction.swift
//  InvestPortfolio
//
//  A contribution or partial withdrawal on a replenishable/flexible deposit.
//

import Foundation
import SwiftData

@Model
final class DepositTransaction {
    var id: UUID = UUID()
    var depositId: UUID = UUID()
    var date: Date = Date()
    // Positive = contribution, negative = withdrawal.
    var amount: Double = 0.0

    init(
        id: UUID = UUID(),
        depositId: UUID,
        date: Date = Date(),
        amount: Double
    ) {
        self.id = id
        self.depositId = depositId
        self.date = date
        self.amount = amount
    }
}
