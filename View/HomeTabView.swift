//
//  HomeTabView.swift
//  
//
//  Created by Anna on 26.12.25.
//

import SwiftUI

struct HomeTabView: View {
    var isAuthorized: Bool
    var openPortfolio: () -> Void
    var openDeposits: () -> Void
    var openSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LandingCard(
                    icon: "building.columns.fill",
                    iconColor: .white,
                    iconBackground: LinearGradient(colors: [Color.purple, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                    title: "Мой портфель",
                    subtitle: isAuthorized ? "Перейти к портфелю" : "Требуется вход"
                ) { openPortfolio() }

                LandingCard(
                    icon: "banknote.fill",
                    iconColor: .white,
                    iconBackground: LinearGradient(colors: [Color.green, Color.teal], startPoint: .topLeading, endPoint: .bottomTrailing),
                    title: "Вклады",
                    subtitle: "Просмотреть вклады"
                ) { openDeposits() }

                LandingCard(
                    icon: "gearshape.fill",
                    iconColor: .white,
                    iconBackground: LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                    title: "Настройки",
                    subtitle: "О приложении"
                ) { openSettings() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
    }
}

