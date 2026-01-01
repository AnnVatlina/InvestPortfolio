//
//  MainTabView.swift
//  
//
//  Created by Anna on 26.12.25.
//

import SwiftUI

struct MainTabView: View {
    @AppStorage("MainTab_SelectedIndex") private var selectedIndex: Int = 0
    @EnvironmentObject private var container: DIContainer

    // Внешние зависимости: состояние авторизации и колбэк при успешном входе
    var isAuthorized: Bool = (KeychainService.loadToken() != nil)
    var onAuthorized: (() -> Void)? = nil

    var body: some View {
        TabView(selection: $selectedIndex) {
            // 0: Главная
            NavigationStack {
                HomeTabView(
                    isAuthorized: isAuthorized,
                    openPortfolio: { selectedIndex = 1 },
                    openDeposits: { selectedIndex = 2 },
                    openSettings: { selectedIndex = 3 }
                )
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("home.tab.title")
            }
            .tabItem { Label("home.tab.title", systemImage: "house.fill") }
            .tag(0)

            // 1: Портфель (если не авторизован — показываем AuthView вместо портфеля)
            NavigationStack {
                Group {
                    if isAuthorized {
                        PortfolioView(container: container)
                            .navigationTitle("home.portfolio.title")
                    } else {
                        AuthView(
                            onAuthorized: {
                                onAuthorized?()
                            },
                            onOpenDeposits: {
                                selectedIndex = 2
                            },
                            onOpenSettings: {
                                selectedIndex = 3
                            }
                        )
                    }
                }
            }
            .tabItem { Label("home.portfolio.title", systemImage: "chart.pie.fill") }
            .tag(1)

            // 2: Вклады
            NavigationStack {
                DepositsView(container: container)
            }
            .tabItem { Label("deposits.title", systemImage: "banknote.fill") }
            .tag(2)

            // 3: Настройки
            NavigationStack {
                SettingsView()
                    .navigationTitle("settings.title")
            }
            .tabItem { Label("settings.title", systemImage: "gearshape.fill") }
            .tag(3)
        }
        .onAppear {
            if !(0...3).contains(selectedIndex) { selectedIndex = 0 }
        }
    }
}

