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

    @AppStorage("App_HasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var showResetConfirm = false
    @State private var isResetting = false

    private let supportedLocales: [(id: String, name: String)] = [
        ("ru", "Русский"),
        ("en", "English")
    ]

    private var languageBinding: Binding<String> {
        Binding(
            get: { localeIdentifier },
            set: { newValue in
                LanguageBundle.set(languageCode: newValue)
                localeIdentifier = newValue
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

            Section {
                NavigationLink {
                    CurrenciesSettingsView()
                } label: {
                    Label("settings.currencies.title", systemImage: "dollarsign.circle")
                }

                NavigationLink {
                    DataSettingsView()
                        .environmentObject(container)
                } label: {
                    Label("settings.data.title", systemImage: "arrow.up.arrow.down.circle")
                }
            }

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
        .alert("settings.reset.confirm.title", isPresented: $showResetConfirm) {
            Button("settings.reset.confirm.action", role: .destructive) {
                Task {
                    isResetting = true
                    defer { isResetting = false }
                    try? await container.resetAllData()
                    hasCompletedOnboarding = false
                }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("settings.reset.confirm.message")
        }
    }
}

// MARK: - Currencies Settings

struct CurrenciesSettingsView: View {
    @AppStorage("Settings_SelectedCurrencies") private var selectedCurrenciesRaw: String = DepositCurrency.defaultSelection

    private var selectedCurrencySet: Set<String> {
        Set(selectedCurrenciesRaw.split(separator: ",").map { String($0) })
    }

    private func currencyBinding(for currency: DepositCurrency) -> Binding<Bool> {
        Binding(
            get: { selectedCurrencySet.contains(currency.rawValue) },
            set: { newValue in
                var current = selectedCurrencySet
                if newValue {
                    current.insert(currency.rawValue)
                } else {
                    guard current.count > 1 else { return }
                    current.remove(currency.rawValue)
                }
                selectedCurrenciesRaw = DepositCurrency.allCases
                    .map(\.rawValue)
                    .filter { current.contains($0) }
                    .joined(separator: ",")
            }
        )
    }

    var body: some View {
        List {
            Section {
                ForEach(DepositCurrency.allCases) { currency in
                    Toggle(isOn: currencyBinding(for: currency)) {
                        Text(currency.rawValue)
                    }
                    .disabled(selectedCurrencySet.count == 1 && selectedCurrencySet.contains(currency.rawValue))
                }
            } footer: {
                Text("settings.currencies.footer")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("settings.currencies.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Data Settings (Import / Export)

struct DataSettingsView: View {
    @EnvironmentObject private var container: DIContainer

    @State private var exportItem: ExportItem?
    @State private var isExporting = false
    @State private var exportError: String?

    private enum ImportType { case deposits, subscriptions }
    @State private var currentImportType: ImportType? = nil
    @State private var isShowingImporter = false
    @State private var isImporting = false
    @State private var importSummary: ImportSummary?

    var body: some View {
        List {
            Section(header: Text("settings.export.title")) {
                exportButton(title: "settings.export.deposits", icon: "banknote", filename: "deposits.csv") {
                    let service = container.makeDepositsService()
                    return CSVExporter.csv(for: try await service.fetchAll())
                }
                exportButton(title: "settings.export.subscriptions", icon: "repeat.circle", filename: "subscriptions.csv") {
                    let service = container.makeSubscriptionsService()
                    return CSVExporter.csv(for: try await service.fetchAll())
                }
            }
            .disabled(isExporting)

            Section(header: Text("settings.import.title")) {
                importButton(title: "settings.import.deposits", icon: "square.and.arrow.down", type: .deposits)
                importButton(title: "settings.import.subscriptions", icon: "square.and.arrow.down", type: .subscriptions)
            }
            .disabled(isImporting || isExporting)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("settings.data.title")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isExporting || isImporting {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .sheet(item: $exportItem) { item in
            ActivityView(url: item.url).ignoresSafeArea()
        }
        .alert("common.error", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("common.ok") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        .alert("settings.import.result.title", isPresented: Binding(
            get: { importSummary != nil },
            set: { if !$0 { importSummary = nil } }
        )) {
            Button("common.ok") { importSummary = nil }
        } message: {
            if let s = importSummary {
                Text(String(format: String(localized: "settings.import.result.format"), s.imported, s.skipped, s.failed))
            }
        }
        .fileImporter(
            isPresented: $isShowingImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            onCompletion: { result in
                let type = currentImportType
                currentImportType = nil
                Task {
                    switch type {
                    case .deposits: await handleDepositImport(result)
                    case .subscriptions: await handleSubscriptionImport(result)
                    case nil: break
                    }
                }
            }
        )
    }

    private func importButton(title: LocalizedStringKey, icon: String, type: ImportType) -> some View {
        Button {
            currentImportType = type
            isShowingImporter = true
        } label: {
            Label(title, systemImage: icon)
        }
    }

    @ViewBuilder
    private func exportButton(title: LocalizedStringKey, icon: String, filename: String, build: @escaping () async throws -> String) -> some View {
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

    private func handleDepositImport(_ result: Result<URL, Error>) async {
        isImporting = true
        defer { isImporting = false }
        do {
            let url = try result.get()
            let csv = try readCSV(from: url)
            let parsed = CSVImporter.parseDeposits(csv)
            let api = container.makeDepositsAPI()
            let service = container.makeDepositsService()
            let existingIDs = Set(try await service.fetchAll().map { $0.id })
            let toAdd = parsed.items.filter { !existingIDs.contains($0.id) }
            var imported = 0
            var failed = parsed.failed
            for d in toAdd {
                do {
                    let body = DepositCreate(
                        title: d.title,
                        bankName: d.bankName,
                        amount: d.amount,
                        currency: d.currency,
                        openDate: d.openDate,
                        closeDate: d.closeDate,
                        annualInterestRate: d.annualInterestRate
                    )
                    let dto = try await api.createDeposit(body)
                    try await service.upsert(
                        serverId: dto.id,
                        title: dto.title,
                        bankName: dto.bankName,
                        amount: dto.amountDouble,
                        currency: dto.depositCurrency,
                        openDate: dto.openDate,
                        closeDate: dto.closeDate,
                        annualInterestRate: dto.annualRateDouble,
                        createdAt: dto.createdAt
                    )
                    imported += 1
                } catch {
                    failed += 1
                }
            }
            importSummary = ImportSummary(imported: imported, skipped: parsed.items.count - toAdd.count, failed: failed)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func handleSubscriptionImport(_ result: Result<URL, Error>) async {
        isImporting = true
        defer { isImporting = false }
        do {
            let url = try result.get()
            let csv = try readCSV(from: url)
            let parsed = CSVImporter.parseSubscriptions(csv)
            let api = container.makeSubscriptionsAPI()
            let service = container.makeSubscriptionsService()
            let existingIDs = Set(try await service.fetchAll().map { $0.id })
            let toAdd = parsed.items.filter { !existingIDs.contains($0.id) }
            var imported = 0
            var failed = parsed.failed
            for s in toAdd {
                do {
                    let dto = try await api.createSubscription(SubscriptionCreate(from: s))
                    try await service.upsert(
                        serverId: dto.id,
                        title: dto.title,
                        amount: dto.amountDouble,
                        currency: dto.depositCurrency,
                        billingCycle: dto.subscriptionBillingCycle,
                        startDate: dto.startDate,
                        endDate: dto.endDate,
                        category: dto.category,
                        iconName: dto.iconName,
                        isActive: dto.isActive,
                        createdAt: dto.createdAt
                    )
                    imported += 1
                } catch {
                    failed += 1
                }
            }
            importSummary = ImportSummary(imported: imported, skipped: parsed.items.count - toAdd.count, failed: failed)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func readCSV(from url: URL) throws -> String {
        let needsStop = url.startAccessingSecurityScopedResource()
        defer { if needsStop { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        for encoding: String.Encoding in [.utf8, .windowsCP1252, .isoLatin1, .utf16] {
            if let str = String(data: data, encoding: encoding) {
                return str.hasPrefix("\u{FEFF}") ? String(str.dropFirst()) : str
            }
        }
        throw CocoaError(.fileReadUnknownStringEncoding)
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
