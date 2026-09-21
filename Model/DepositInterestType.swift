//
//  DepositInterestType.swift
//  InvestPortfolio
//

enum DepositInterestType: String, CaseIterable, Codable, Equatable, Identifiable {
    case simple
    case capitalized

    var id: String { rawValue }
}
