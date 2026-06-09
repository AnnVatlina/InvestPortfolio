//
//  TokenStorage.swift
//  InvestPortfolio
//
//  Keychain storage for Rentivo JWT tokens.
//  Keys: "rentivo.access_token", "rentivo.refresh_token"
//

import Foundation
import Security

final class TokenStorage: @unchecked Sendable {

    static let shared = TokenStorage()

    private let accessKey: String
    private let refreshKey: String

    /// Default init uses production Keychain keys.
    init(accessKey: String = "rentivo.access_token",
         refreshKey: String = "rentivo.refresh_token") {
        self.accessKey = accessKey
        self.refreshKey = refreshKey
    }

    // MARK: - Public API

    var hasTokens: Bool { loadAccessToken() != nil }

    func save(_ token: AuthToken) {
        write(token.accessToken, forKey: accessKey)
        write(token.refreshToken, forKey: refreshKey)
    }

    func loadAccessToken() -> String? { read(forKey: accessKey) }

    func loadRefreshToken() -> String? { read(forKey: refreshKey) }

    func clearTokens() {
        delete(forKey: accessKey)
        delete(forKey: refreshKey)
    }

    // MARK: - Keychain primitives

    private func write(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func read(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    private func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
