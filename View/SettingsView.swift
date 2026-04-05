//
//  SettingsView.swift
//  InvestPortfolio
//
//  Created by Anna on 30.12.25.
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @AppStorage("App_LocaleIdentifier") private var localeIdentifier: String = Locale.current.identifier
    @EnvironmentObject private var container: DIContainer

    @State private var exportItem: ExportItem?
    @State private var isExporting = false
    @State private var exportError: String?

    private let supportedLocales: [(id: String, name: String)] = [
        ("ru", "Русский"),
        ("en", "English")
    ]

    // Custom binding: updates LanguageBundle BEFORE changing @AppStorage so the bundle
    // is ready when SwiftUI schedules the next render (onChange fires AFTER rendering).
    private var languageBinding: Binding<String> {
        Binding(
            get: { localeIdentifier },
            set: { newValue in
                LanguageBundle.set(languageCode: newValue)   // bundle first
                localeIdentifier = newValue                   // then trigger re-render
            }
        )
    }

    var body: some View {
        List {
            Section(header: Text("settings.language")) {
                Picker("settings.language", selection: languageBinding) {
                    ForEach(supportedLocales, id: \.id) { item in
                        Text(item.name).tag(item.id as String)
                    }
                }
            }

            // MARK: Export
            Section(header: Text("settings.export.title")) {
                exportButton(
                    title: "settings.export.deposits",
                    icon: "banknote",
                    filename: "deposits.csv"
                ) {
                    let service = container.makeDepositsService()
                    let data = try await service.fetchAll()
                    return CSVExporter.csv(for: data)
                }

                exportButton(
                    title: "settings.export.subscriptions",
                    icon: "repeat.circle",
                    filename: "subscriptions.csv"
                ) {
                    let service = container.makeSubscriptionsService()
                    let data = try await service.fetchAll()
                    return CSVExporter.csv(for: data)
                }

                exportButton(
                    title: "settings.export.cashOperations",
                    icon: "arrow.left.arrow.right",
                    filename: "cash_operations.csv"
                ) {
                    let service = container.makeCashService()
                    let data = try await service.fetchAll()
                    return CSVExporter.csv(for: data)
                }

                exportButton(
                    title: "settings.export.portfolio",
                    icon: "chart.line.uptrend.xyaxis",
                    filename: "portfolio.csv"
                ) {
                    let service = container.makePortfolioService()
                    let data = try await service.fetchAll()
                    return CSVExporter.csv(for: data)
                }
            }
            .disabled(isExporting)

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
        .overlay {
            if isExporting {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .sheet(item: $exportItem) { item in
            ActivityView(url: item.url)
                .ignoresSafeArea()
        }
        .alert(
            String(localized: "common.error"),
            isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )
        ) {
            Button(String(localized: "common.ok")) { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func exportButton(
        title: String.LocalizationValue,
        icon: String,
        filename: String,
        build: @escaping () async throws -> String
    ) -> some View {
        Button {
            Task {
                isExporting = true
                defer { isExporting = false }
                do {
                    let csv = try await build()
                    guard let url = CSVExporter.writeToTempFile(csv, named: filename) else {
                        exportError = String(localized: "settings.export.error")
                        return
                    }
                    exportItem = ExportItem(url: url)
                } catch {
                    exportError = String(format: String(localized: "common.unknownError.format"), error.localizedDescription)
                }
            }
        } label: {
            Label(String(localized: title), systemImage: icon)
        }
    }
}

// MARK: - Supporting Types

private struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivityView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - About

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
