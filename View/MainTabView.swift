//
//  MainTabView.swift
//
//  Created by Anna on 26.12.25.
//

import SwiftUI

struct MainTabView: View {
    @AppStorage("MainTab_SelectedIndex") private var selectedIndex: Int = 0
    @EnvironmentObject private var container: DIContainer
    @Environment(\.locale) private var locale

    var isAuthorized: Bool = (KeychainService.loadToken() != nil)
    var onAuthorized: (() -> Void)? = nil

    var body: some View {
        _ = locale // re-render on language change
        return TabView(selection: $selectedIndex) {

            // 0: Главная
            NavigationStack {
                HomeTabView(
                    isAuthorized: isAuthorized,
                    openPortfolio: { /* Portfolio tab hidden */ },
                    openDeposits: { selectedIndex = 1 },
                    openSubscriptions: { selectedIndex = 2 },
                    openAnalytics: { selectedIndex = 3 },
                    openSettings: { selectedIndex = 4 }
                )
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("home.tab.title")
            }
            .tabItem { Label("home.tab.title", systemImage: "house.fill") }
            .tag(0)

            // 1: Вклады
            NavigationStack {
                DepositsView(container: container)
            }
            .tabItem { Label("deposits.title", systemImage: "banknote.fill") }
            .tag(1)

            // 2: Подписки
            NavigationStack {
                SubscriptionsView(container: container)
            }
            .tabItem { Label("subscriptions.title", systemImage: "repeat.circle.fill") }
            .tag(2)

            // 3: Аналитика
            NavigationStack {
                AnalyticsView(container: container)
                    .navigationTitle("analytics.title")
            }
            .tabItem { Label("analytics.title", systemImage: "chart.bar.fill") }
            .tag(3)

            // 4: Настройки
            NavigationStack {
                SettingsView()
                    .navigationTitle("settings.title")
            }
            .tabItem { Label("settings.title", systemImage: "gearshape.fill") }
            .tag(4)

            // Портфель скрыт из TabBar (код сохранён в PortfolioView.swift)
            // Для восстановления: добавить таб с tag(5) и PortfolioView(container:)
        }
        .onAppear {
            if !(0...4).contains(selectedIndex) { selectedIndex = 0 }
        }

    }
}
