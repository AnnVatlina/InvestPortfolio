//
//  HomeTabView.swift
//  
//
//  Created by Anna on 26.12.25.
//

import SwiftUI

struct HomeTabView: View {
    var openDeposits: () -> Void
    var openSubscriptions: () -> Void
    var openAnalytics: () -> Void
    var openSettings: () -> Void

    @EnvironmentObject private var container: DIContainer
    @AppStorage("Settings_SelectedCurrencies") private var selectedCurrenciesRaw: String = DepositCurrency.defaultSelection

    @State private var depositSums: [(currency: DepositCurrency, amount: Double)] = []
    @State private var monthlyExpenses: [(currency: DepositCurrency, amount: Double)] = []
    @State private var isLoaded = false

    private var selectedCurrencies: [DepositCurrency] {
        selectedCurrenciesRaw.split(separator: ",")
            .compactMap { DepositCurrency(rawValue: String($0)) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoaded {
                    summaryCard
                }

                LandingCard(
                    icon: "banknote.fill",
                    iconColor: .white,
                    iconBackground: LinearGradient(colors: [.brand, .teal], startPoint: .topLeading, endPoint: .bottomTrailing),
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
        .task { await loadSummary() }
        .onChange(of: selectedCurrenciesRaw) {
            Task { await loadSummary() }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(
                    colors: [.brand, Color(red: 0.05, green: 0.35, blue: 0.27)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            HStack(alignment: .top, spacing: 0) {
                // Левая колонка: вклады
                VStack(alignment: .leading, spacing: 6) {
                    Text("home.summary.deposits")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .textCase(.uppercase)
                        .opacity(0.75)
                    if depositSums.isEmpty {
                        Text("—").font(.subheadline).fontWeight(.semibold)
                    } else {
                        ForEach(depositSums, id: \.currency) { item in
                            Text("\(item.amount, specifier: "%.0f") \(item.currency.rawValue)")
                                .font(.subheadline).fontWeight(.bold)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 1)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 16)

                // Правая колонка: подписки/мес
                VStack(alignment: .leading, spacing: 6) {
                    Text("home.summary.monthly")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .textCase(.uppercase)
                        .opacity(0.75)
                    if monthlyExpenses.isEmpty {
                        Text("—").font(.subheadline).fontWeight(.semibold)
                    } else {
                        ForEach(monthlyExpenses, id: \.currency) { item in
                            Text("−\(item.amount, specifier: "%.0f") \(item.currency.rawValue)")
                                .font(.subheadline).fontWeight(.bold)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundColor(.white)
            .padding(20)
        }
    }

    // MARK: - Data Loading

    private func loadSummary() async {
        do {
            let depositsService = container.makeDepositsService()
            let subsService = container.makeSubscriptionsService()

            let allDeposits = try await depositsService.fetchAll()
            let allSubs = try await subsService.fetchAll()

            let activeDeposits = allDeposits.filter {
                guard let closeDate = $0.closeDate else { return true }
                return closeDate > Date()
            }
            let activeSubs = allSubs.filter { $0.isActive }

            depositSums = selectedCurrencies.compactMap { cur in
                let total = activeDeposits.filter { $0.currency == cur }.reduce(0) { $0 + $1.amount }
                return total > 0 ? (cur, total) : nil
            }

            monthlyExpenses = selectedCurrencies.compactMap { cur in
                let total = subsService.totalMonthlyCost(in: cur, subscriptions: activeSubs)
                return total > 0 ? (cur, total) : nil
            }
        } catch {}
        isLoaded = true
    }
}

