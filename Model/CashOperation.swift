//
//  CashOperation.swift
//
//  Created by Anna on 26.12.25.
//

import Foundation
import SwiftData

@Model
final class CashOperation {
    var id: UUID
    var date: String
    var type: String
    var amount: Double
    var currency: String
    var comment: String?
    var fetchedAt: Date

    init(
        id: UUID = UUID(),
        date: String,
        type: String,
        amount: Double,
        currency: String,
        comment: String? = nil,
        fetchedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.amount = amount
        self.currency = currency
        self.comment = comment
        self.fetchedAt = fetchedAt
    }
}
