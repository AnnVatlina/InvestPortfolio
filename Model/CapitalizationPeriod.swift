//
//  CapitalizationPeriod.swift
//  InvestPortfolio
//
//  Only meaningful when Deposit.interestType == .capitalized.
//

import Foundation

enum CapitalizationPeriod: String, CaseIterable, Codable, Equatable, Identifiable {
    case monthly
    case quarterly
    case yearly

    var id: String { rawValue }

    /// Interval added to a period's start date to find the next capitalization boundary.
    var dateComponents: DateComponents {
        switch self {
        case .monthly: return DateComponents(month: 1)
        case .quarterly: return DateComponents(month: 3)
        case .yearly: return DateComponents(year: 1)
        }
    }
}
