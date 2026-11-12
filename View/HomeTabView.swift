//
//  HomeTabView.swift
//
//  Created by Anna on 26.12.25.
//
//  Home: income-vs-subscriptions coverage, nearest upcoming subscription payments and
//  currently open deposits — the things worth checking at a glance, without
//  duplicating the tabs below.
//

import SwiftUI

struct HomeTabView: View {
    @StateObject private var vm: HomeViewModel
    @AppStorage(CurrencySettings.baseCurrencyKey) private var baseCurrencyRaw: String = CurrencySettings.defaultBaseCurrency.rawValue
    @AppStorage(CurrencySettings.ratesKey) private var ratesJSON: String = CurrencySettings.defaultRatesJSON

    private var converter: CurrencyConverter {
        CurrencySettings.converter(baseRaw: baseCurrencyRaw, ratesJSON: ratesJSON)
    }

    init(container: DIContainer) {
        _vm = StateObject(wrappedValue: HomeViewModel(
            depositsService: container.makeDepositsService(),
            subscriptionsService: container.makeSubscriptionsService()
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if vm.isLoading && vm.deposits.isEmpty && vm.subscriptions.isEmpty {
                    ProgressView("home.loading")
                        .padding(.top, 40)
                } else {
                    coverageCard
                    upcomingPaymentsCard
                    openDepositsCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(Text("settings.title"))
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }

    // MARK: - Coverage

    @ViewBuilder
    private var coverageCard: some View {
        let breakdown = vm.coverageBreakdown
        if !breakdown.isEmpty {
            let converter = converter
            let missing = vm.missingRates(converter: converter)
            let base = converter.base.rawValue

            VStack(alignment: .leading, spacing: 12) {
                Text("home.coverage.title")
                    .font(.headline)

                coverageRow("home.coverage.income", amount: vm.monthlyIncome(converter: converter), currency: base)
                coverageRow("home.coverage.subscriptions", amount: vm.monthlySubscriptions(converter: converter), currency: base)

                // No percentage without subscriptions: dividing by zero says nothing.
                if let coverage = vm.coverage(converter: converter) {
                    HStack {
                        Text("home.coverage.percent")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(coverage, format: .percent.precision(.fractionLength(0)))
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    }
                }

                if !missing.isEmpty {
                    NavigationLink {
                        CurrenciesSettingsView()
                    } label: {
                        Label(
                            String(
                                format: String(localized: "home.coverage.rates.missing.format"),
                                missing.map(\.rawValue).joined(separator: ", ")
                            ),
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.leading)
                    }
                }

                Divider()

                Text("home.coverage.byCurrency")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(breakdown) { line in
                    HStack {
                        Text(line.currency.rawValue)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("+\(String(format: "%.2f", line.income)) / −\(String(format: "%.2f", line.subscriptions))")
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }

    private func coverageRow(_ title: LocalizedStringKey, amount: Double, currency: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text("\(String(format: "%.2f", amount)) \(currency)")
                .font(.subheadline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: - Upcoming payments

    private var upcomingPaymentsCard: some View {
        let items = vm.upcomingSubscriptions()
        return VStack(alignment: .leading, spacing: 12) {
            Text("home.upcomingPayments.title")
                .font(.headline)

            if items.isEmpty {
                Text("home.upcomingPayments.empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    ForEach(items) { sub in
                        HStack(spacing: 12) {
                            SubscriptionIcon(name: sub.iconName ?? "repeat.circle.fill", size: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(sub.title)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                Text(sub.nextPaymentDate, format: .dateTime.day().month(.abbreviated))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)

                            Text("\(String(format: "%.2f", sub.amount)) \(sub.currency.rawValue)")
                                .font(.subheadline)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Open deposits

    private var openDepositsCard: some View {
        let items = vm.openDeposits
        return VStack(alignment: .leading, spacing: 12) {
            Text("home.openDeposits.title")
                .font(.headline)

            if items.isEmpty {
                Text("home.openDeposits.empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    ForEach(items) { deposit in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.brand.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "banknote.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.brand)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(deposit.title)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                if let closeDate = deposit.closeDate {
                                    Text(closeDate, format: .dateTime.day().month(.abbreviated).year())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("home.openDeposits.noEndDate")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer(minLength: 0)

                            Text("\(String(format: "%.2f", deposit.amount)) \(deposit.currency.rawValue)")
                                .font(.subheadline)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}
