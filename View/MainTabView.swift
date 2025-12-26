//
//  MainTabView.swift
//  
//
//  Created by Anna on 26.12.25.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationView { PortfolioView() }
                .tabItem { Label("Portfolio", systemImage: "chart.pie") }

            NavigationView { CashView() }
                .tabItem { Label("Cash", systemImage: "dollarsign.circle") }
        }
    }
}
