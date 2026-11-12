//
//  AnalyticsView.swift
//  InvestPortfolio
//

import SwiftUI
import Charts

struct AnalyticsView: View {
    @StateObject private var vm: AnalyticsViewModel
    @Environment(\.locale) private var locale
    @State private var selectedCurrencyIndex: Int = 0

    init(container: DIContainer) {
        _vm = StateObject(wrappedValue: AnalyticsViewModel(
            depositsService: container.makeDepositsService(),
            subscriptionsService: container.makeSubscriptionsService(),
            dividendsService: container.makeDividendsService()
        ))
    }

    private var currency: DepositCurrency? {
        let c = vm.activeCurrencies
        guard !c.isEmpty, selectedCurrencyIndex < c.count else { return nil }
        return c[selectedCurrencyIndex]
    }

    var body: some View {
        _ = locale // force re-render on language change
        return ScrollView {
            VStack(spacing: 20) {
                if vm.isLoading {
                    ProgressView("analytics.loading")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let error = vm.errorMessage {
                    errorView(error)
                } else {
                    yearPicker

                    let currencies = vm.activeCurrencies
                    if currencies.isEmpty {
                        emptyView
                    } else {
                        if currencies.count > 1 {
                            currencyPicker(currencies: currencies)
                        }
                        if let cur = currency {
                            // Block 1: actual amounts up to today
                            if vm.isPastOrCurrentYear {
                                toDateSection(currency: cur)
                            }

                            // Block 2: a single selected month
                            byMonthSection(currency: cur)

                            // Block 3: full year projection
                            yearTotalSection(currency: cur)

                            // Block 4: monthly chart
                            chartSection(currency: cur)

                            // Block 5: dividends — a separate section with its own
                            // numbers, deliberately not mixed into the blocks above.
                            if vm.hasDividendActivity(currency: cur) {
                                dividendsSection(currency: cur)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("analytics.title")
        .task { await vm.load() }
    }

    // MARK: - Year picker

    private var yearPicker: some View {
        HStack {
            Button {
                if vm.selectedYear > vm.yearRange.lowerBound { vm.selectedYear -= 1 }
            } label: {
                Image(systemName: "chevron.left").font(.title3.bold())
            }
            .accessibilityLabel(Text("a11y.previousYear"))
            .disabled(vm.selectedYear <= vm.yearRange.lowerBound)

            Spacer()
            Text(String(vm.selectedYear)).font(.title3.bold())
            Spacer()

            Button {
                if vm.selectedYear < vm.yearRange.upperBound { vm.selectedYear += 1 }
            } label: {
                Image(systemName: "chevron.right").font(.title3.bold())
            }
            .accessibilityLabel(Text("a11y.nextYear"))
            .disabled(vm.selectedYear >= vm.yearRange.upperBound)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - By month section

    private var monthDate: Date? {
        Calendar.current.date(from: DateComponents(year: vm.selectedYear, month: vm.selectedMonth, day: 1))
    }

    private var monthPicker: some View {
        HStack {
            Button {
                if vm.selectedMonth > 1 { vm.selectedMonth -= 1 }
            } label: {
                Image(systemName: "chevron.left").font(.subheadline.bold())
            }
            .accessibilityLabel(Text("a11y.previousMonth"))
            .disabled(vm.selectedMonth <= 1)

            Spacer()
            if let date = monthDate {
                Text(date, format: .dateTime.month(.wide).year())
                    .font(.subheadline.bold())
            }
            Spacer()

            Button {
                if vm.selectedMonth < 12 { vm.selectedMonth += 1 }
            } label: {
                Image(systemName: "chevron.right").font(.subheadline.bold())
            }
            .accessibilityLabel(Text("a11y.nextMonth"))
            .disabled(vm.selectedMonth >= 12)
        }
    }

    private func byMonthSection(currency: DepositCurrency) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "analytics.month.title", subtitle: "analytics.month.subtitle")
            monthPicker

            HStack(spacing: 12) {
                summaryCard(
                    title: "analytics.income",
                    value: vm.monthIncome(currency: currency),
                    currency: currency.rawValue,
                    color: .teal
                )
                summaryCard(
                    title: "analytics.expenses",
                    value: vm.monthExpense(currency: currency),
                    currency: currency.rawValue,
                    color: .orange
                )
                let net = vm.monthNet(currency: currency)
                summaryCard(
                    title: "analytics.net",
                    value: net,
                    currency: currency.rawValue,
                    color: net >= 0 ? .green : .red
                )
            }
        }
    }

    // MARK: - Currency picker

    private func currencyPicker(currencies: [DepositCurrency]) -> some View {
        Picker("", selection: $selectedCurrencyIndex) {
            ForEach(currencies.indices, id: \.self) { idx in
                Text(currencies[idx].rawValue).tag(idx)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: currencies.count) { _, _ in selectedCurrencyIndex = 0 }
    }

    // MARK: - To date section (actual values, Jan 1 → today)

    private func toDateSection(currency: DepositCurrency) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "analytics.todate.title", subtitle: "analytics.todate.subtitle")

            HStack(spacing: 12) {
                summaryCard(
                    title: "analytics.income",
                    value: vm.totalEarnedToDate(currency: currency),
                    currency: currency.rawValue,
                    color: .teal
                )
                summaryCard(
                    title: "analytics.expenses",
                    value: vm.totalPaidToDate(currency: currency),
                    currency: currency.rawValue,
                    color: .orange
                )
                let net = vm.netToDate(currency: currency)
                summaryCard(
                    title: "analytics.net",
                    value: net,
                    currency: currency.rawValue,
                    color: net >= 0 ? .green : .red
                )
            }
        }
    }

    // MARK: - Year total section (full year including future months)

    private func yearTotalSection(currency: DepositCurrency) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "analytics.year.title", subtitle: "analytics.year.subtitle")

            HStack(spacing: 12) {
                summaryCard(
                    title: "analytics.income",
                    value: vm.totalIncome(currency: currency),
                    currency: currency.rawValue,
                    color: .teal
                )
                summaryCard(
                    title: "analytics.expenses",
                    value: vm.totalExpenses(currency: currency),
                    currency: currency.rawValue,
                    color: .orange
                )
                let net = vm.netBalance(currency: currency)
                summaryCard(
                    title: "analytics.net",
                    value: net,
                    currency: currency.rawValue,
                    color: net >= 0 ? .green : .red
                )
            }
        }
    }

    // MARK: - Dividends (separate section)

    private func dividendsSection(currency: DepositCurrency) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider().padding(.top, 4)
            sectionHeader(title: "dividends.title", subtitle: "analytics.dividends.subtitle")

            if vm.isPastOrCurrentYear {
                dividendRow(
                    caption: "analytics.todate.title",
                    income: vm.dividendIncomeToDate(currency: currency),
                    expense: vm.dividendExpenseToDate(currency: currency),
                    net: vm.dividendNetToDate(currency: currency),
                    currency: currency
                )
            }
            dividendRow(
                caption: "analytics.month.title",
                income: vm.monthDividendIncome(currency: currency),
                expense: vm.monthDividendExpense(currency: currency),
                net: vm.monthDividendNet(currency: currency),
                currency: currency
            )
            dividendRow(
                caption: "analytics.year.title",
                income: vm.totalDividendIncome(currency: currency),
                expense: vm.totalDividendExpense(currency: currency),
                net: vm.dividendNetBalance(currency: currency),
                currency: currency
            )

            dividendsChartSection(currency: currency)

            let yearlyPoints = vm.dividendYearlyPoints(currency: currency)
            if !yearlyPoints.isEmpty {
                dividendYearlyBreakdown(points: yearlyPoints, currency: currency)
            }
        }
    }

    private func dividendYearlyBreakdown(points: [YearlyDividendPoint], currency: DepositCurrency) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("analytics.dividends.byYear.title").font(.subheadline.bold())
            ForEach(points) { point in
                dividendRow(
                    caption: LocalizedStringKey(String(point.year)),
                    income: point.income,
                    expense: point.expense,
                    net: point.net,
                    currency: currency
                )
            }
        }
    }

    private func dividendRow(caption: LocalizedStringKey, income: Double, expense: Double, net: Double, currency: DepositCurrency) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(caption).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                summaryCard(title: "analytics.income", value: income, currency: currency.rawValue, color: .teal)
                summaryCard(title: "analytics.expenses", value: expense, currency: currency.rawValue, color: .orange)
                summaryCard(title: "analytics.net", value: net, currency: currency.rawValue, color: net >= 0 ? .green : .red)
            }
        }
    }

    // MARK: - Section header

    private func sectionHeader(title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Summary card

    private func summaryCard(title: LocalizedStringKey, value: Double, currency: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(format: "%.2f", value))
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(currency)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Chart

    private func chartSection(currency: DepositCurrency) -> some View {
        let points = vm.monthlyPoints(currency: currency)
        let hasData = points.contains { $0.income > 0 || $0.expense > 0 }
        let entries: [(month: Date, series: String, value: Double)] = points.flatMap { pt in
            var rows: [(Date, String, Double)] = []
            if pt.income > 0 { rows.append((pt.month, "income", pt.income)) }
            if pt.expense > 0 { rows.append((pt.month, "expense", pt.expense)) }
            return rows
        }
        return monthlyChartCard(title: "analytics.chart.title", hasData: hasData, entries: entries)
    }

    // MARK: - Dividends monthly chart (separate from chartSection above)

    private func dividendsChartSection(currency: DepositCurrency) -> some View {
        let points = vm.dividendMonthlyPoints(currency: currency)
        let hasData = points.contains { $0.income > 0 || $0.expense > 0 }
        let entries: [(month: Date, series: String, value: Double)] = points.flatMap { pt in
            var rows: [(Date, String, Double)] = []
            if pt.income > 0 { rows.append((pt.month, "income", pt.income)) }
            if pt.expense > 0 { rows.append((pt.month, "expense", pt.expense)) }
            return rows
        }
        return monthlyChartCard(title: "dividends.title", hasData: hasData, entries: entries)
    }

    /// Shared bar-chart card used by both the deposits/subscriptions chart and the
    /// separate dividends chart — same look, independent data.
    private func monthlyChartCard(title: LocalizedStringKey, hasData: Bool, entries: [(month: Date, series: String, value: Double)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)

            if !hasData {
                Text("analytics.chart.empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                // Use fixed (non-localized) keys for chart series so language switch
                // doesn't break the color scale mapping
                let incomeKey = "income"
                let expenseKey = "expense"

                Chart {
                    ForEach(entries.indices, id: \.self) { i in
                        let entry = entries[i]
                        BarMark(
                            x: .value("Month", entry.month, unit: .month),
                            y: .value("Amount", entry.value)
                        )
                        .foregroundStyle(by: .value("Type", entry.series))
                        .position(by: .value("Type", entry.series))
                    }
                }
                .chartForegroundStyleScale([incomeKey: Color.teal, expenseKey: Color.orange])
                .chartLegend {
                    HStack(spacing: 16) {
                        legendDot(color: .teal, label: "analytics.legend.income")
                        legendDot(color: .orange, label: "analytics.legend.expenses")
                    }
                    .font(.caption)
                    .padding(.bottom, 4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        if value.as(Date.self) != nil {
                            AxisValueLabel(format: .dateTime.month(.narrow))
                        }
                    }
                }
                .frame(height: 220)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private func legendDot(color: Color, label: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
        }
    }

    // MARK: - Empty / Error

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("analytics.empty")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text("common.error").font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("common.retry") {
                Task { await vm.load() }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 40)
    }
}
