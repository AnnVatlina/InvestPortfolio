//
//  InvestPortfolioApp.swift
//
//  Created by Anna on 26.12.25.
//

import SwiftUI
import SwiftData

@main
struct InvestPortfolioApp: App {

    @StateObject private var container: DIContainer
    @AppStorage("App_LocaleIdentifier") private var localeIdentifier: String = Locale.current.identifier

    init() {
        // Install bundle override BEFORE any localized string is read.
        // Falls back to device language so first-launch strings match the system language.
        LanguageBundle.activate()
        let savedLocale = UserDefaults.standard.string(forKey: "App_LocaleIdentifier")
            ?? Locale.current.language.languageCode?.identifier
            ?? "en"
        LanguageBundle.set(languageCode: savedLocale)

        let schema = Schema([
            Deposit.self,
            Settings.self,
            Subscription.self
        ])
        let storeURL = Self.sharedStoreURL()
        let config = ModelConfiguration(url: storeURL)
        let modelContainer: ModelContainer
        do {
            modelContainer = try ModelContainer(for: schema, configurations: config)
        } catch {
            // Файл базы недоступен (напр. после смены Bundle ID) — удаляем и создаём заново.
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
            do {
                modelContainer = try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("Не удалось создать ModelContainer: \(error)")
            }
        }
        _container = StateObject(wrappedValue: DIContainer(modelContainer: modelContainer))
    }

    /// The store lives in the App Group container so the widget extension can read the same
    /// data. Falls back to the app's own container if the group is unavailable for some reason
    /// (e.g. provisioning issue) so the app still works, just without widget access.
    private static func sharedStoreURL() -> URL {
        let legacyStoreURL = URL.applicationSupportDirectory.appending(path: "default.store")
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.io.rentivo.app"
        ) else {
            return legacyStoreURL
        }

        let sharedStoreURL = groupURL.appending(path: "default.store")

        // One-time migration: earlier versions (before the widget extension existed)
        // stored data outside the App Group. Copy it over so existing users don't lose data.
        if !FileManager.default.fileExists(atPath: sharedStoreURL.path),
           FileManager.default.fileExists(atPath: legacyStoreURL.path) {
            for suffix in ["", "-shm", "-wal"] {
                let from = URL(fileURLWithPath: legacyStoreURL.path + suffix)
                let to = URL(fileURLWithPath: sharedStoreURL.path + suffix)
                guard FileManager.default.fileExists(atPath: from.path) else { continue }
                try? FileManager.default.copyItem(at: from, to: to)
            }
        }
        return sharedStoreURL
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .id(localeIdentifier)           // rebuild full view tree on language change
                .environmentObject(container)
                .tint(.brand)
                .environment(\.locale, Locale(identifier: localeIdentifier))
        }
        // Передаём контейнер в среду SwiftUI (для @Query и @Environment(\.modelContext))
        .modelContainer(container.modelContainer)
    }
}
