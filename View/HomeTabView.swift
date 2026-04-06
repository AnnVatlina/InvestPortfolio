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
    var openSubscriptions: () -> Void
    var openAnalytics: () -> Void
    var openSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LandingCard(
                    icon: "banknote.fill",
                    iconColor: .white,
                    iconBackground: LinearGradient(colors: [Color.green, Color.teal], startPoint: .topLeading, endPoint: .bottomTrailing),
                    title: "deposits.title",
                    subtitle: "deposits.open"
                ) { openDeposits() }

                LandingCard(
                    icon: "repeat.circle.fill",
                    iconColor: .white,
                    iconBackground: LinearGradient(colors: [Color.orange, Color.pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                    title: "subscriptions.title",
                    subtitle: "subscriptions.open"
                ) { openSubscriptions() }

                LandingCard(
                    icon: "chart.bar.fill",
                    iconColor: .white,
                    iconBackground: LinearGradient(colors: [Color.purple, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing),
                    title: "analytics.title",
                    subtitle: "analytics.open"
                ) { openAnalytics() }

                LandingCard(
                    icon: "gearshape.fill",
                    iconColor: .white,
                    iconBackground: LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                    title: "settings.title",
                    subtitle: "about.title"
                ) { openSettings() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
    }
}

