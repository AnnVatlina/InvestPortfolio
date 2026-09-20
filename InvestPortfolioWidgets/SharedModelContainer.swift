//
//  SharedModelContainer.swift
//  InvestPortfolioWidgets
//
//  Points the widget extension's own ModelContainer at the same App Group store
//  the main app writes to. Read-only usage from here — the widget never mutates data.
//

import Foundation
import SwiftData

enum SharedModelContainer {
    private static let appGroupID = "group.io.rentivo.app"

    /// Returns nil if the App Group container isn't available (e.g. a provisioning
    /// issue) — callers should fall back to an empty/placeholder widget state, not crash.
    static func make() -> ModelContainer? {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            return nil
        }
        let storeURL = groupURL.appendingPathComponent("default.store")
        let schema = Schema([Deposit.self, Settings.self, Subscription.self])
        let config = ModelConfiguration(url: storeURL)
        return try? ModelContainer(for: schema, configurations: config)
    }
}
