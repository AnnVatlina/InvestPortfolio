//
//  DepositCurrency.swift
//  InvestPortfolio
//
//  Created by Anna on 30.12.25.
//

enum DepositCurrency: String, CaseIterable, Codable, Equatable, Identifiable {
    case USD, BYN, GEL, EUR, RUB
    var id: String { rawValue }

    /// Comma-separated rawValues of all cases — used as the default for AppStorage("Settings_SelectedCurrencies").
    static let defaultSelection: String = allCases.map(\.rawValue).sorted().joined(separator: ",")
}
