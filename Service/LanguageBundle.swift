//
//  LanguageBundle.swift
//  InvestPortfolio
//
//  Enables in-app language switching.
//
//  How it works:
//  1. `object_setClass(Bundle.main, LanguageBundle.self)` replaces the class of the
//     Bundle.main singleton so every subsequent `localizedString(forKey:value:table:)` call
//     (including `String(localized:)`, SwiftUI `Text("key")`, format strings, etc.) is
//     intercepted here.
//  2. When the user picks a language, `LanguageBundle.set(languageCode:)` swaps the
//     override bundle to the matching .lproj, and the next SwiftUI render cycle picks up
//     the new strings automatically.
//
//  Call `LanguageBundle.activate()` once in `InvestPortfolioApp.init()` and
//  `LanguageBundle.set(languageCode:)` whenever `App_LocaleIdentifier` changes.
//

import Foundation

final class LanguageBundle: Bundle, @unchecked Sendable {

    // The .lproj bundle for the user-selected language (nil = use system default).
    private static var overrideBundle: Bundle?

    // MARK: - Public API

    /// Call once at app startup to install the override.
    static func activate() {
        object_setClass(Bundle.main, LanguageBundle.self)
    }

    /// Switch to a language by its BCP-47 / locale identifier (e.g. "ru", "en", "en_US").
    static func set(languageCode: String) {
        // Strip region suffix: "en_US" → "en"
        let code = languageCode.split(separator: "_").first.map(String.init) ?? languageCode
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            overrideBundle = bundle
        } else {
            overrideBundle = nil
        }
    }

    // MARK: - Override

    override func localizedString(
        forKey key: String,
        value: String?,
        table tableName: String?
    ) -> String {
        guard let override = Self.overrideBundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return override.localizedString(forKey: key, value: value, table: tableName)
    }
}
