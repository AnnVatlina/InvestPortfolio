//
//  AuthToken.swift
//  InvestPortfolio
//

import Foundation

/// In-memory token pair — not persisted by SwiftData. Stored in Keychain via TokenStorage.
struct AuthToken: Sendable {
    let accessToken: String
    let refreshToken: String
}
