//
//  CapitalizationPeriod.swift
//  InvestPortfolio
//
//  Only meaningful when Deposit.interestType == .capitalized.
//

enum CapitalizationPeriod: String, CaseIterable, Codable, Equatable, Identifiable {
    case monthly
    case quarterly
    case yearly

    var id: String { rawValue }
}
