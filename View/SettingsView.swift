//
//  SettingsView.swift
//  InvestPortfolio
//
//  Created by Anna on 30.12.25.
//

import SwiftUI

struct SettingsView: View {
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Аккаунт")) {
                    Button(role: .none) {
                        showLogoutConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "briefcase")
                            Text("Портфель (войти)")
                        }
                    }
                    .confirmationDialog(
                        "Перейти к авторизации?",
                        isPresented: $showLogoutConfirm,
                        titleVisibility: .visible
                    ) {
                        Button("Перейти к авторизации", role: .destructive) {
                            // Логаут и уведомление о неавторизованности
                            APIClient.shared.logout()
                            NotificationCenter.default.post(name: .unauthorized, object: nil)
                        }
                        Button("Отмена", role: .cancel) { }
                    } message: {
                        Text("Мы выйдем из текущей сессии и откроем форму входа.")
                    }
                }

                Section(header: Text("Приложение")) {
                    NavigationLink {
                        AboutAppView()
                    } label: {
                        Label("О приложении", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("Настройки")
        }
    }
}

// Простой экран "О приложении"
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

