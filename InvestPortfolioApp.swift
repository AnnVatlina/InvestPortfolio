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
        // Install bundle override BEFORE any localized string is read
        LanguageBundle.activate()
        let savedLocale = UserDefaults.standard.string(forKey: "App_LocaleIdentifier") ?? ""
        LanguageBundle.set(languageCode: savedLocale)

        do {
            let modelContainer = try ModelContainer(
                for: Deposit.self,
                     CashOperation.self,
                     PortfolioPosition.self,
                     Settings.self,
                     Subscription.self,
                migrationPlan: AppMigrationPlan.self
            )
            _container = StateObject(wrappedValue: DIContainer(modelContainer: modelContainer))
        } catch {
            fatalError("Не удалось создать ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .environment(\.locale, Locale(identifier: localeIdentifier))
                .onChange(of: localeIdentifier) { _, newValue in
                    // Re-point the bundle override so String(localized:) picks up the change
                    LanguageBundle.set(languageCode: newValue)
                }
        }
        // Передаём контейнер в среду SwiftUI (для @Query и @Environment(\.modelContext))
        .modelContainer(container.modelContainer)
    }
}
