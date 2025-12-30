//
//  DepositCurrency.swift
//  InvestPortfolio
//
//  Created by Anna on 30.12.25.
//

enum DepositCurrency: String, CaseIterable, Codable, Equatable, Identifiable {
    case USD, BYN, GEL, EUR, RUB
    var id: String { rawValue }
}
