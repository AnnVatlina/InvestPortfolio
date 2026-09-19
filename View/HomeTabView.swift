//
//  HomeTabView.swift
//
//  Created by Anna on 26.12.25.
//
//  Dashboard: net worth in the base currency, allocation by currency,
//  upcoming events, and shortcuts into the other tabs.
//

import SwiftUI
import Charts

struct HomeTabView: View {
    private let openDeposits: () -> Void
    private let openSubscriptions: () -> Void
    private let openAnalytics: () -> Void

    @StateObject private var vm: DashboardViewModel

    @AppStorage(CurrencySettings.baseCurrencyKey) private var baseCurrencyRaw: String = CurrencySettings.defaultBaseCurrency.rawValue
    @AppStorage(CurrencySettings.ratesKey) private var ratesJSON: String = CurrencySettings.defaultRatesJSON

    init(
        container: DIContainer,
        openDeposits: @escaping () -> Void,
        openSubscriptions: @escaping () -> Void,
        openAnalytics: @escaping () -> Void
    ) {
        self.openDeposits = openDeposits
        self.openSubscriptions = openSubscriptions
        self.openAnalytics = openAnalytics
        _vm = StateObject(wrappedValue: DashboardViewModel(
            depositsService: container.makeDepositsService(),
            subscriptionsService: container.makeSubscriptionsService()
        ))
    }

    private var converter: CurrencyConverter {
        CurrencySettings.converter(baseRaw: baseCurrencyRaw, ratesJSON: ratesJSON)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                netWorthCard

                let netWorth = vm.netWorth(using: converter)
                if !netWorth.missing.isEmpty {
                    missingRatesBanner(netWorth.missing)
                }

                let allocation = vm.allocationByCurrency(using: converter)
                if allocation.count > 1 {
                    allocationCard(allocation)
                }

                let events = vm.upcomingEvents()
                if !events.isEmpty {
                    upcomingCard(events)
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

    // MARK: - Net worth

    private var netWorthCard: some View {
        let principal = vm.depositsPrincipal(using: converter)
        let income = vm.depositsAccruedIncome(using: converter)
        let annualSubs = vm.annualSubscriptionCost(using: converter)
        let netWorth = vm.netWorth(using: converter)

        return ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(
                    colors: [.brand, Color(red: 0.05, green: 0.35, blue: 0.27)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            VStack(alignment: .leading, spacing: 14) {
                Text("dashboard.netWorth.title")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .opacity(0.75)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(amountText(netWorth.value))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(converter.base.rawValue)
                        .font(.headline)
                        .opacity(0.8)
                }

                Divider().overlay(.white.opacity(0.25))

                breakdownRow(title: "dashboard.breakdown.deposits", total: principal, isNegative: false)
                breakdownRow(title: "dashboard.breakdown.income", total: income, isNegative: false)
                breakdownRow(title: "dashboard.breakdown.subscriptions", total: annualSubs, isNegative: true)
            }
            .foregroundColor(.white)
            .padding(20)
        }
    }

    private func breakdownRow(title: LocalizedStringKey, total: ConvertedTotal, isNegative: Bool) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .opacity(0.8)
            Spacer()
            Text("\(isNegative ? "−" : "")\(amountText(total.value))")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
    }

    // MARK: - Missing rates

    private func missingRatesBanner(_ missing: [DepositCurrency]) -> some View {
        NavigationLink {
            CurrenciesSettingsView()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("dashboard.rates.missing.title")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(String(
                        format: String(localized: "dashboard.rates.missing.format"),
                        missing.map(\.rawValue).joined(separator: ", ")
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.tertiaryLabel)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Allocation

    private func allocationCard(_ slices: [AllocationSlice]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("dashboard.allocation.title")
                .font(.headline)

            Chart(slices) { slice in
                // Series keys are currency rawValues, never localized strings —
                // otherwise switching language remaps the color scale.
                SectorMark(
                    angle: .value("Share", slice.converted),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(by: .value("Currency", slice.currency.rawValue))
            }
            .chartLegend(.hidden)
            .frame(height: 180)

            VStack(spacing: 8) {
                ForEach(slices) { slice in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color(for: slice.currency, in: slices))
                            .frame(width: 12, height: 12)
                        Text(slice.currency.rawValue)
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.0f%%", slice.share * 100))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    /// Mirrors Swift Charts' default categorical palette so the hand-drawn legend matches the donut.
    private func color(for currency: DepositCurrency, in slices: [AllocationSlice]) -> Color {
        let palette: [Color] = [.blue, .green, .orange, .purple, .red, .teal, .pink]
        guard let index = slices.firstIndex(where: { $0.currency == currency }) else { return .gray }
        return palette[index % palette.count]
    }

    // MARK: - Upcoming

    private func upcomingCard(_ events: [DashboardEvent]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("dashboard.upcoming.title")
                .font(.headline)

            ForEach(events) { event in
                HStack(spacing: 12) {
                    Image(systemName: event.kind == .depositClosing ? "banknote.fill" : "repeat.circle.fill")
                        .foregroundStyle(event.kind == .depositClosing ? Color.brand : Color.orange)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Text(event.date, format: .dateTime.day().month(.abbreviated))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Text("\(amountText(event.amount)) \(event.currency.rawValue)")
                        .font(.subheadline)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Formatting

    private func amountText(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
