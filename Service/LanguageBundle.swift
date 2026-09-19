//
//  LanguageBundle.swift
//  InvestPortfolio
//
//  Enables in-app language switching.
//
//  How it works:
//  1. `object_setClass(Bundle.main, LanguageBundle.self)` replaces the class of the
//     Bundle.main singleton so every subsequent `localizedString(forKey:value:table:)` call
//     is intercepted here.
//  2. When the user picks a language, `LanguageBundle.set(languageCode:)` swaps the
//     override bundle to the matching .lproj, and the next SwiftUI render cycle picks up
//     the new strings automatically.
//
//  Call `LanguageBundle.activate()` once in `InvestPortfolioApp.init()` and
//  `LanguageBundle.set(languageCode:)` whenever `App_LocaleIdentifier` changes.
//
//  IMPORTANT: `String(localized:)` does NOT go through this override. It resolves via
//  Swift's newer LocalizedStringResource machinery, which reads resources directly rather
//  than calling the overridden `localizedString(forKey:value:table:)` selector below — so it
//  silently ignores the in-app language choice and always follows the device's system
//  language. Use `LanguageBundle.string(_:)` instead everywhere a `String` (not a SwiftUI
//  `Text`/`LocalizedStringKey`) is needed. Plain `Text("key")` and anything else that takes
//  a `LocalizedStringKey` literal (`.navigationTitle`, `Label`, etc.) is unaffected — that
//  path dispatches through the override correctly on its own.
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

    /// Resolves a key against the in-app language choice. Use this instead of
    /// `String(localized:)` for any localized `String` value — see the note at the top of
    /// this file for why `String(localized:)` doesn't work here.
    static func string(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
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
