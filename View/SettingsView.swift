//
//  SettingsView.swift
//  InvestPortfolio
//
//  Created by Anna on 30.12.25.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    AboutAppView()
                } label: {
                    Label("О приложении", systemImage: "info.circle")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Настройки")
    }
}

struct AboutAppView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "app")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("InvestPortfolio")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Версия 1.0")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle("О приложении")
    }
}

