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

            // 0: Home
            NavigationStack {
                HomeTabView(container: container)
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle("home.tab.title")
            }
            .tabItem { Label("home.tab.title", systemImage: "house.fill") }
            .tag(0)

            // 1: Deposits
            NavigationStack {
                DepositsView(container: container)
            }
            .tabItem { Label("deposits.title", systemImage: "banknote.fill") }
            .tag(1)

            // 2: Subscriptions
            NavigationStack {
                SubscriptionsView(container: container)
            }
            .tabItem { Label("subscriptions.title", systemImage: "repeat.circle.fill") }
            .tag(2)

            // 3: Analytics
            NavigationStack {
                AnalyticsView(container: container)
                    .navigationTitle("analytics.title")
            }
            .tabItem { Label("analytics.title", systemImage: "chart.bar.fill") }
            .tag(3)

            // 4: Dividends
            NavigationStack {
                DividendsView(container: container)
            }
            .tabItem { Label("dividends.title", systemImage: "chart.line.uptrend.xyaxis") }
            .tag(4)

        }
        .onAppear {
            // Settings used to be tab 4 (moved into the dashboard toolbar); 4 is now
            // Dividends, so a stale saved index from that era still lands validly here.
            if !(0...4).contains(selectedIndex) { selectedIndex = 0 }
        }

    }
}
