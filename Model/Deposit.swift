//
//  Deposit.swift
//
//  Created by Anna on 30.12.25.
//

import Foundation
import SwiftData

@Model
final class Deposit {
    var id: UUID
    var title: String
    var bankName: String?
    var amount: Double
    // Stored as String to avoid SwiftData lazy-load cast failure with custom enums (iOS 26)
    var currencyRaw: String
    var createdAt: Date

    var openDate: Date
    var closeDate: Date?
    var annualInterestRate: Double

    // Stored as String/String? for the same reason as currencyRaw — see comment above.
    // Default values here let SwiftData perform an automatic lightweight migration
    // for existing deposits created before interest types were introduced.
    var interestTypeRaw: String = DepositInterestType.simple.rawValue
    var capitalizationPeriodRaw: String? = nil

    // Whether this deposit accepts additional contributions / partial withdrawals
    // as DepositTransaction entries after it's opened.
    var allowsReplenishment: Bool = false
    var allowsPartialWithdrawal: Bool = false

    // Whether the deposit can be closed before `closeDate` without losing interest.
    // If false, closing before `closeDate` recalculates the whole term at earlyWithdrawalRate.
    var isRevocable: Bool = true
    var earlyWithdrawalRate: Double? = nil
    // Set when the depositor actually closes the deposit — may be before, at, or (rarely,
    // for backdated entry) after `closeDate`. Distinct from `closeDate`, which is the plan.
    var actualCloseDate: Date? = nil

    /// Typed accessor — computed, not stored by SwiftData.
    var currency: DepositCurrency {
        get { DepositCurrency(rawValue: currencyRaw) ?? .RUB }
        set { currencyRaw = newValue.rawValue }
    }

    /// Typed accessor — computed, not stored by SwiftData.
    var interestType: DepositInterestType {
        get { DepositInterestType(rawValue: interestTypeRaw) ?? .simple }
        set { interestTypeRaw = newValue.rawValue }
    }

    /// Typed accessor — computed, not stored by SwiftData. Only meaningful when `interestType == .capitalized`.
    var capitalizationPeriod: CapitalizationPeriod? {
        get { capitalizationPeriodRaw.flatMap(CapitalizationPeriod.init(rawValue:)) }
        set { capitalizationPeriodRaw = newValue?.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        bankName: String? = nil,
        amount: Double,
        currency: DepositCurrency,
        createdAt: Date = Date(),
        openDate: Date,
        closeDate: Date? = nil,
        annualInterestRate: Double,
        interestType: DepositInterestType = .simple,
        capitalizationPeriod: CapitalizationPeriod? = nil,
        allowsReplenishment: Bool = false,
        allowsPartialWithdrawal: Bool = false,
        isRevocable: Bool = true,
        earlyWithdrawalRate: Double? = nil,
        actualCloseDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.bankName = bankName
        self.amount = amount
        self.currencyRaw = currency.rawValue
        self.createdAt = createdAt
        self.openDate = openDate
        self.closeDate = closeDate
        self.annualInterestRate = annualInterestRate
        self.interestTypeRaw = interestType.rawValue
        self.capitalizationPeriodRaw = capitalizationPeriod?.rawValue
        self.allowsReplenishment = allowsReplenishment
        self.allowsPartialWithdrawal = allowsPartialWithdrawal
        self.isRevocable = isRevocable
        self.earlyWithdrawalRate = earlyWithdrawalRate
        self.actualCloseDate = actualCloseDate
    }
}
