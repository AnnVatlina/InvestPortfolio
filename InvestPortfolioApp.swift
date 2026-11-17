//
//  InvestPortfolioApp.swift
//
//  Created by Anna on 26.12.25.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct InvestPortfolioApp: App {

    @StateObject private var container: DIContainer
    @AppStorage("App_LocaleIdentifier") private var localeIdentifier: String = Locale.current.identifier

    // Held statically so it outlives this struct's init and stays the strong owner behind
    // UNUserNotificationCenter's weak `delegate` property for the lifetime of the process.
    private static let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = Self.notificationDelegate

        // Install bundle override BEFORE any localized string is read.
        // Falls back to device language so first-launch strings match the system language.
        LanguageBundle.activate()
        let savedLocale = UserDefaults.standard.string(forKey: "App_LocaleIdentifier")
            ?? Locale.current.language.languageCode?.identifier
            ?? "en"
        LanguageBundle.set(languageCode: savedLocale)

        let schema = AppModels.schema
        let storeURL = Self.sharedStoreURL()
        let config = ModelConfiguration(url: storeURL)
        let modelContainer: ModelContainer
        do {
            modelContainer = try ModelContainer(for: schema, configurations: config)
        } catch {
            // The store couldn't be opened (failed migration, inaccessible file, ...).
            // Never delete it: move it aside so the data survives, tell the user, and start
            // empty. If even the move fails, run in memory and leave the files untouched.
            modelContainer = Self.recoverContainer(schema: schema, config: config, storeURL: storeURL)
        }
        _container = StateObject(wrappedValue: DIContainer(modelContainer: modelContainer))
    }

    private static func recoverContainer(
        schema: Schema,
        config: ModelConfiguration,
        storeURL: URL
    ) -> ModelContainer {
        let defaults = UserDefaults.standard
        do {
            let backup = try StoreRecovery.backUpStore(at: storeURL)
            let container = try ModelContainer(for: schema, configurations: config)
            if let backup {
                defaults.set(
                    StoreRecovery.Notice.backedUp(fileName: backup.lastPathComponent).rawValue,
                    forKey: StoreRecovery.noticeKey
                )
            }
            return container
        } catch {
            defaults.set(StoreRecovery.Notice.unavailable.rawValue, forKey: StoreRecovery.noticeKey)
            let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            guard let container = try? ModelContainer(for: schema, configurations: memoryConfig) else {
                fatalError("Не удалось создать ModelContainer: \(error)")
            }
            return container
        }
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
        // Pass the container into the SwiftUI environment (for @Query and @Environment(\.modelContext))
        .modelContainer(container.modelContainer)
    }
}
