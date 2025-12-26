//
//  PortfolioPosition.swift
//  
//
//  Created by Anna on 26.12.25.
//

import Foundation

struct PortfolioPosition: Identifiable, Decodable {
    let id = UUID()
    let ticker: String
    let quantity: Double
    let avgPrice: Double
    let currentPrice: Double

    var profit: Double {
        (currentPrice - avgPrice) * quantity
    }
}
