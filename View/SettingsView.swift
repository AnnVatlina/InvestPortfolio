//
//  SettingsView.swift
//  InvestPortfolio
//
//  Created by Anna on 30.12.25.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("App_LocaleIdentifier") private var localeIdentifier: String = Locale.current.identifier
    @Environment(\.locale) private var locale
    @EnvironmentObject private var container: DIContainer

    @State private var exportItem: ExportItem?
    @State private var isExporting = false
    @State private var exportError: String?

    // Import state
    @State private var isImportingDeposits = false
    @State private var isImportingSubscriptions = false
    @State private var isImporting = false
    @State private var importSummary: ImportSummary?

    // Reset state
    @AppStorage("App_HasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var showResetConfirm = false
    @State private var isResetting = false

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


            }
            .disabled(isExporting)

            // MARK: Import
            Section(header: Text("settings.import.title")) {
                importButton(
                    title: "settings.import.deposits",
                    icon: "square.and.arrow.down",
                    isPresented: $isImportingDeposits
                )
                importButton(
                    title: "settings.import.subscriptions",
                    icon: "square.and.arrow.down",
                    isPresented: $isImportingSubscriptions
                )
            }
            .disabled(isImporting || isExporting)

            // MARK: Danger zone
            Section {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("settings.reset.action", systemImage: "trash")
                }
                .disabled(isResetting)
            } header: {
                Text("settings.reset.title")
            } footer: {
                Text("settings.reset.footer")
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
        .overlay {
            if isExporting || isImporting {
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
            "common.error",
            isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )
        ) {
            Button("common.ok") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        .alert(
            "settings.import.result.title",
            isPresented: Binding(
                get: { importSummary != nil },
                set: { if !$0 { importSummary = nil } }
            )
        ) {
            Button("common.ok") { importSummary = nil }
        } message: {
            if let s = importSummary {
                Text(String(format: String(localized: "settings.import.result.format"), s.imported, s.skipped, s.failed))
            }
        }
        .alert("settings.reset.confirm.title", isPresented: $showResetConfirm) {
            Button("settings.reset.confirm.action", role: .destructive) {
                Task {
                    isResetting = true
                    defer { isResetting = false }
                    try? await container.resetAllData()
                    hasCompletedOnboarding = false   // показать онбординг снова
                }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("settings.reset.confirm.message")
        }
        .fileImporter(
            isPresented: $isImportingDeposits,
            allowedContentTypes: [.commaSeparatedText],
            onCompletion: { result in
                Task { await handleDepositImport(result) }
            }
        )
        .fileImporter(
            isPresented: $isImportingSubscriptions,
            allowedContentTypes: [.commaSeparatedText],
            onCompletion: { result in
                Task { await handleSubscriptionImport(result) }
            }
        )
    }

    // MARK: - Import Handlers

    private func handleDepositImport(_ result: Result<URL, Error>) async {
        isImporting = true
        defer { isImporting = false }
        do {
            let url = try result.get()
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            let csv = try String(contentsOf: url, encoding: .utf8)
            let parsed = CSVImporter.parseDeposits(csv)

            let service = container.makeDepositsService()
            let existing = try await service.fetchAll()
            let existingIDs = Set(existing.map { $0.id })

            let toAdd = parsed.items.filter { !existingIDs.contains($0.id) }
            let skipped = parsed.items.count - toAdd.count
            for d in toAdd { try await service.add(d) }

            importSummary = ImportSummary(imported: toAdd.count, skipped: skipped, failed: parsed.failed)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func handleSubscriptionImport(_ result: Result<URL, Error>) async {
        isImporting = true
        defer { isImporting = false }
        do {
            let url = try result.get()
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            let csv = try String(contentsOf: url, encoding: .utf8)
            let parsed = CSVImporter.parseSubscriptions(csv)

            let service = container.makeSubscriptionsService()
            let existing = try await service.fetchAll()
            let existingIDs = Set(existing.map { $0.id })

            let toAdd = parsed.items.filter { !existingIDs.contains($0.id) }
            let skipped = parsed.items.count - toAdd.count
            for s in toAdd { try await service.add(s) }

            importSummary = ImportSummary(imported: toAdd.count, skipped: skipped, failed: parsed.failed)
        } catch {
            exportError = error.localizedDescription
        }
    }

    // MARK: - Import Button

    @ViewBuilder
    private func importButton(
        title: LocalizedStringKey,
        icon: String,
        isPresented: Binding<Bool>
    ) -> some View {
        Button {
            isPresented.wrappedValue = true
        } label: {
            Label(title, systemImage: icon)
        }
    }

    // MARK: - Export Helpers

    @ViewBuilder
    private func exportButton(
        title: LocalizedStringKey,
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
            Label(title, systemImage: icon)
        }
    }
}

// MARK: - Supporting Types

private struct ImportSummary: Identifiable {
    let id = UUID()
    let imported: Int
    let skipped: Int
    let failed: Int
}

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
