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
                    title: String(localized: "home.portfolio.title"),
                    subtitle: isAuthorized ? String(localized: "home.portfolio.open") : String(localized: "home.portfolio.loginRequired")
                ) { openPortfolio() }

                LandingCard(
                    icon: "banknote.fill",
                    iconColor: .white,
                    iconBackground: LinearGradient(colors: [Color.green, Color.teal], startPoint: .topLeading, endPoint: .bottomTrailing),
                    title: String(localized: "deposits.title"),
                    subtitle: String(localized: "deposits.open")
                ) { openDeposits() }

                LandingCard(
                    icon: "gearshape.fill",
                    iconColor: .white,
                    iconBackground: LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                    title: String(localized: "settings.title"),
                    subtitle: String(localized: "about.title")
                ) { openSettings() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
    }
}

