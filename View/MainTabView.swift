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

    var body: some View {
        _ = locale // re-render on language change
        return TabView(selection: $selectedIndex) {

            // 0: Главная
            NavigationStack {
                HomeTabView(container: container)
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

        }
        .onAppear {
            // Настройки переехали в тулбар дашборда — сохранённый индекс 4 больше невалиден
            if !(0...3).contains(selectedIndex) { selectedIndex = 0 }
        }

    }
}
