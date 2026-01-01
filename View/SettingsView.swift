//
//  SettingsView.swift
//  InvestPortfolio
//
//  Created by Anna on 30.12.25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("App_LocaleIdentifier") private var localeIdentifier: String = Locale.current.identifier

    private let supportedLocales: [(id: String, name: String)] = [
        ("ru", "Русский"),
        ("en", "English")
    ]

    var body: some View {
        List {
            Section(header: Text("settings.language")) {
                Picker("settings.language", selection: $localeIdentifier) {
                    ForEach(supportedLocales, id: \.id) { item in
                        Text(item.name).tag(item.id as String)
                    }
                }
            }

            Section {
                NavigationLink {
                    AboutAppView()
                } label: {
                    Label("about.title", systemImage: "info.circle")
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.locale, Locale(identifier: localeIdentifier))
        .navigationTitle(Text("settings.title"))
    }
}

struct AboutAppView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "app")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("app.name")
                .font(.title2)
                .fontWeight(.semibold)
            Text("about.version")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle(Text("about.title"))
    }
}

