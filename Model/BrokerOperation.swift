//
//  BrokerOperation.swift
//  InvestPortfolio
//
//  A single row imported from a Freedom24/Tradernet broker report: a dividend,
//  a withheld tax, or a trade commission. See Docs/dividends-feature.md.
//

import Foundation
import SwiftData

@Model
final class BrokerOperation {
    var id: UUID = UUID()

    // The report's own "Операция №" — a unique ID per row. `.unique` makes SwiftData
    // upsert on this value, so re-importing the same report row never creates a
    // second record even if the service-level dedup check is ever bypassed.
    @Attribute(.unique) var operationNumber: Int = 0

    var date: Date = Date()

    // Stored as String to avoid SwiftData lazy-load cast failure with custom enums (iOS 26)
    var typeRaw: String = BrokerOperationType.other.rawValue

    // The operation label exactly as it appears in the report (e.g. "Дивиденды",
    // " Комиссия за сделки "), kept verbatim so an unrecognized type mapped to
    // `.other` isn't lost — the user can still see what it originally said.
    var rawOperationLabel: String = ""

    var comment: String = ""
    var amount: Decimal = 0

    // Stored as String for the same reason as typeRaw — see comment above.
    var currencyRaw: String = DepositCurrency.USD.rawValue

    var importedAt: Date = Date()

    /// Typed accessor — computed, not stored by SwiftData.
    var type: BrokerOperationType {
        get { BrokerOperationType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    /// Typed accessor — computed, not stored by SwiftData.
    var currency: DepositCurrency {
        get { DepositCurrency(rawValue: currencyRaw) ?? .USD }
        set { currencyRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        operationNumber: Int,
        date: Date,
        type: BrokerOperationType,
        rawOperationLabel: String,
        comment: String,
        amount: Decimal,
        currency: DepositCurrency,
        importedAt: Date = Date()
    ) {
        self.id = id
        self.operationNumber = operationNumber
        self.date = date
        self.typeRaw = type.rawValue
        self.rawOperationLabel = rawOperationLabel
        self.comment = comment
        self.amount = amount
        self.currencyRaw = currency.rawValue
        self.importedAt = importedAt
    }
}
