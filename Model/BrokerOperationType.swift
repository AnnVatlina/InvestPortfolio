//
//  BrokerOperationType.swift
//  InvestPortfolio
//

import Foundation

/// The kind of operation found in a Freedom24/Tradernet broker report row.
/// `.other` covers any operation label not recognized by the parser — rows are
/// never dropped just because their type is unfamiliar.
enum BrokerOperationType: String, CaseIterable, Codable, Equatable, Identifiable {
    case dividend
    case tax
    case commission
    case other

    var id: String { rawValue }
}
