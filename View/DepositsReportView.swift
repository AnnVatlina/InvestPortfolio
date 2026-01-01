//
//  DepositsReportView.swift
//
//  Created by Anna on 05.04.26.
//

import SwiftUI
import Charts

struct DepositsReportView: View {
    let deposits: [Deposit]
    let incomes: [UUID: DepositIncomeSummary]

    // MARK: - Inner types

    struct MonthlyPoint: Identifiable {
        let id = UUID()
        let month: Date
        let currency: String
        let income: Double
    }

    struct MonthlyTotal: Identifiable {
        let id = UUID()
        let month: Date
        let total: Double
    }

    // MARK: - Palette

    private static let palette: [Color] = [
        Color(red: 0.298, green: 0.749, blue: 0.435),
        Color(red: 0.259, green: 0.522, blue: 0.957),
        Color(red: 0.957, green: 0.596, blue: 0.188),
        Color(red: 0.612, green: 0.369, blue: 0.929),
        Color(red: 0.922, green: 0.341, blue: 0.349),
        Color(red: 0.188, green: 0.749, blue: 0.839),
        Color(red: 0.957, green: 0.769, blue: 0.149),
        Color(red: 0.533, green: 0.588, blue: 0.647),
    ]

    // MARK: - Year state

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }

    private var yearRange: ClosedRange<Int> {
        let cal = Calendar.current
        let openYears = deposits.map { cal.component(.year, from: $0.openDate) }
        let closeYears = deposits.compactMap { $0.closeDate }.map { cal.component(.year, from: $0) }
        let minYear = (openYears + closeYears).min() ?? currentYear
        let maxYear = max(currentYear, closeYears.max() ?? currentYear)
        return minYear...maxYear
    }

    // MARK: - Computed data

    private func activeIncome(deposit: Deposit, from start: Date, to end: Date) -> Double {
        let s = max(deposit.openDate, start)
        let e = min(deposit.closeDate ?? .distantFuture, end)
        guard s < e else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: s, to: e).day ?? 0
        return deposit.amount * (deposit.annualInterestRate / 100.0 / 365.0) * Double(days)
    }

    private var monthlyPoints: [MonthlyPoint] {
        var result: [MonthlyPoint] = []
        let cal = Calendar.current
        let year = selectedYear

        for m in 1...12 {
            let comps = DateComponents(year: year, month: m, day: 1)
            guard let start = cal.date(from: comps),
                  let end = cal.date(byAdding: .month, value: 1, to: start)
            else { continue }

            let byCurrency = Dictionary(grouping: deposits) { $0.currency.rawValue }
            for (currency, items) in byCurrency {
                let total = items.reduce(0.0) { $0 + activeIncome(deposit: $1, from: start, to: end) }
                if total > 0 {
                    result.append(MonthlyPoint(month: start, currency: currency, income: total))
                }
            }
        }
        return result.sorted { $0.month < $1.month }
    }

    private var annualByCurrency: [(currency: String, income: Double)] {
        let cal = Calendar.current
        let year = selectedYear
        guard let yearStart = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
              let yearEnd = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1))
        else { return [] }

        let byCurrency = Dictionary(grouping: deposits) { $0.currency.rawValue }
        return byCurrency.compactMap { currency, items -> (String, Double)? in
            let total = items.reduce(0.0) { $0 + activeIncome(deposit: $1, from: yearStart, to: yearEnd) }
            return total > 0 ? (currency, total) : nil
        }.sorted { $0.0 < $1.0 }
    }

    private func annualIncome(for currency: DepositCurrency) -> Double {
        annualByCurrency.first(where: { $0.currency == currency.rawValue })?.income ?? 0
    }

    private var monthlyTotals: [MonthlyTotal] {
        let grouped = Dictionary(grouping: monthlyPoints) { $0.month }
        return grouped.map { month, points in
            MonthlyTotal(month: month, total: points.reduce(0.0) { $0 + $1.income })
        }.sorted { $0.month < $1.month }
    }

    private var currencyColorMap: [String: Color] {
        let currencies = Array(Set(deposits.map { $0.currency.rawValue })).sorted()
        return Dictionary(uniqueKeysWithValues: currencies.enumerated().map { idx, cur in
            (cur, Self.palette[idx % Self.palette.count])
        })
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summarySection
                monthlySection
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Summary cards

    private var summarySection: some View {
        let currencyGroups = Dictionary(grouping: deposits) { $0.currency }
        let sorted = currencyGroups.keys.sorted { $0.rawValue < $1.rawValue }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(sorted, id: \.self) { currency in
                    let items = currencyGroups[currency]!
                    let totalAmount = items.reduce(0.0) { $0 + $1.amount }
                    let todayIncome = items.reduce(0.0) { $0 + (incomes[$1.id]?.incomeToDate ?? 0) }
                    SummaryCard(
                        currency: currency.rawValue,
                        amount: totalAmount,
                        incomeToDate: todayIncome,
                        annualIncome: annualIncome(for: currency),
                        count: items.count
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Monthly income chart

    private var monthlySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "report.monthly.title"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if annualByCurrency.isEmpty {
                        Text("—")
                            .font(.title3)
                            .fontWeight(.bold)
                    } else {
                        ForEach(annualByCurrency, id: \.currency) { item in
                            Text(String(format: "+%.0f %@", item.income, item.currency))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                }
                Spacer()
                // Переключатель года
                HStack(spacing: 4) {
                    Button {
                        selectedYear -= 1
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.footnote.weight(.semibold))
                    }
                    .disabled(selectedYear <= yearRange.lowerBound)

                    Text(String(selectedYear))
                        .font(.headline)
                        .monospacedDigit()
                        .frame(minWidth: 44)

                    Button {
                        selectedYear += 1
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                    }
                    .disabled(selectedYear >= yearRange.upperBound)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)

            if monthlyPoints.isEmpty {
                Text(String(localized: "report.monthly.empty"))
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                monthlyBarChart
                monthlyCurrencyLegend
            }
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }

    private var monthlyBarChart: some View {
        let colorMap = currencyColorMap
        let domain = Array(Set(monthlyPoints.map { $0.currency })).sorted()
        let range = domain.map { colorMap[$0] ?? Self.palette[0] }
        let totals = monthlyTotals

        return Chart {
            ForEach(monthlyPoints) { point in
                BarMark(
                    x: .value("Month", point.month, unit: .month),
                    y: .value("Income", point.income),
                    stacking: .standard
                )
                .foregroundStyle(by: .value("Currency", point.currency))
                .cornerRadius(4)
            }
            ForEach(totals) { item in
                PointMark(
                    x: .value("Month", item.month, unit: .month),
                    y: .value("Total", item.total)
                )
                .opacity(0)
                .annotation(position: .top, alignment: .center, spacing: 2) {
                    Text(item.total.formatted(.number.notation(.compactName).precision(.fractionLength(0))))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .chartForegroundStyleScale(domain: domain, range: range)
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date.formatted(.dateTime.month(.abbreviated)))
                            .font(.caption2)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.2))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                if let v = value.as(Double.self), v > 0 {
                    AxisValueLabel {
                        Text(v.formatted(.number.notation(.compactName).precision(.fractionLength(0))))
                            .font(.caption2)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.2))
            }
        }
        .chartBackground { proxy in
            // Подсвечиваем текущий месяц только если выбран текущий год
            if selectedYear == currentYear {
                let cal = Calendar.current
                let now = cal.startOfDay(for: Date())
                let comps = DateComponents(
                    year: cal.component(.year, from: now),
                    month: cal.component(.month, from: now),
                    day: 1
                )
                if let monthStart = cal.date(from: comps),
                   let x = proxy.position(forX: monthStart) {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.08))
                        .frame(width: proxy.plotSize.width / 13)
                        .offset(x: x - proxy.plotSize.width / 26)
                }
            }
        }
        .frame(height: 200)
        .padding(.horizontal, 12)
    }

    private var monthlyCurrencyLegend: some View {
        let colorMap = currencyColorMap
        let currencies = Array(Set(monthlyPoints.map { $0.currency })).sorted()
        return HStack(spacing: 16) {
            ForEach(currencies, id: \.self) { currency in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorMap[currency] ?? Self.palette[0])
                        .frame(width: 12, height: 12)
                    Text(currency)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
}

// MARK: - Summary card

private struct SummaryCard: View {
    let currency: String
    let amount: Double
    let incomeToDate: Double
    let annualIncome: Double
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(currency)
                    .font(.headline)
                Spacer()
                Text("\(count) \(String(localized: "report.card.deposits"))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(amount.formatted(.number.precision(.fractionLength(0))))
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Divider()

            HStack(spacing: 4) {
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: "report.card.today"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "+%.2f", incomeToDate))
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: "report.card.annual"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(annualIncome > 0 ? String(format: "+%.0f", annualIncome) : "—")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(16)
        .frame(width: 168)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 2)
    }
}
