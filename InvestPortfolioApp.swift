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
        do {
            let modelContainer = try ModelContainer(
                for: Deposit.self,
                     CashOperation.self,
                     PortfolioPosition.self,
                     Settings.self,
                     Subscription.self
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
        }
        // Передаём контейнер в среду SwiftUI (для @Query и @Environment(\.modelContext))
        .modelContainer(container.modelContainer)
    }
}
