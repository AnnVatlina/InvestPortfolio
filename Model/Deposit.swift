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
    var currency: String
    var createdAt: Date

    init(id: UUID = UUID(), title: String, amount: Double, currency: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.amount = amount
        self.currency = currency
        self.createdAt = createdAt
    }
}

