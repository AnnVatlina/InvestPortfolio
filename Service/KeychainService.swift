//
//  KeychainService.swift
//  
//
//  Created by Anna on 26.12.25.
//

import Foundation
import Security

final class KeychainService {
    private static let authTokenKey = "tradernet_auth_token"
    
    static func saveToken(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: authTokenKey,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: authTokenKey,
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        SecItemCopyMatching(query as CFDictionary, &item)
        guard let data = item as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
    
    static func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: authTokenKey
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    // Обратная совместимость (для старого кода)
    @available(*, deprecated, message: "Use saveToken instead")
    static func save(key: String) {
        saveToken(key)
    }
    
    @available(*, deprecated, message: "Use loadToken instead")
    static func load() -> String? {
        return loadToken()
    }
}
