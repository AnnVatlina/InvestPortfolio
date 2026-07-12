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
        let modelContainer: ModelContainer
        do {
            modelContainer = try ModelContainer(for: schema)
        } catch {
            // Файл базы недоступен (напр. после смены Bundle ID) — удаляем и создаём заново.
            let storeURL = URL.applicationSupportDirectory.appending(path: "default.store")
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
            do {
                modelContainer = try ModelContainer(for: schema)
            } catch {
                fatalError("Не удалось создать ModelContainer: \(error)")
            }
        }
        _container = StateObject(wrappedValue: DIContainer(modelContainer: modelContainer))
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
