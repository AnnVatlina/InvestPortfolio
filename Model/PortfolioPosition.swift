//
//  PortfolioPosition.swift
//
//  Created by Anna on 26.12.25.
//

import Foundation
import SwiftData

@Model
final class PortfolioPosition {
    var id: UUID
    var ticker: String
    var quantity: Double
    var avgPrice: Double
    var currentPrice: Double
    var profit: Double
    var name: String?
    var currency: String?
    var fetchedAt: Date

    init(
        id: UUID = UUID(),
        ticker: String,
        quantity: Double,
        avgPrice: Double,
        currentPrice: Double,
        profit: Double,
        name: String? = nil,
        currency: String? = nil,
        fetchedAt: Date = Date()
    ) {
        self.id = id
        self.ticker = ticker
        self.quantity = quantity
        self.avgPrice = avgPrice
        self.currentPrice = currentPrice
        self.profit = profit
        self.name = name
        self.currency = currency
        self.fetchedAt = fetchedAt
    }
}
