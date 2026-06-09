//
//  Settings.swift
//  InvestPortfolio
//
//  Created by Anna on 04.04.26.
//

import Foundation
import SwiftData

@Model
final class Settings {
    var id: UUID
    var selectedCurrencies: [String]
    var localeIdentifier: String
    var lastSyncDate: Date?

    init(
        id: UUID = UUID(),
        selectedCurrencies: [String] = DepositCurrency.allCases.map(\.rawValue),
        localeIdentifier: String = Locale.current.identifier,
        lastSyncDate: Date? = nil
    ) {
        self.id = id
        self.selectedCurrencies = selectedCurrencies
        self.localeIdentifier = localeIdentifier
        self.lastSyncDate = lastSyncDate
    }
}
