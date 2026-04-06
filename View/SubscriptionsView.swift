//
//  SubscriptionsView.swift
//

import SwiftUI
import Charts

struct SubscriptionsView: View {
    @StateObject private var vm: SubscriptionsViewModel

    init(container: DIContainer) {
        _vm = StateObject(wrappedValue: SubscriptionsViewModel(
            service: container.makeSubscriptionsService()
        ))
    }

    @Environment(\.locale) private var locale
    @State private var showAddSheet = false
    @State private var subscriptionToEdit: Subscription? = nil
    @State private var subscriptionToDelete: Subscription? = nil

    private enum ViewMode { case list, report }
    @State private var viewMode: ViewMode = .list

    var body: some View {
        Group {
            if viewMode == .report {
                SubscriptionsReportView(vm: vm)
            } else if vm.isLoading && vm.subscriptions.isEmpty {
                ProgressView("subscriptions.loading")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.errorMessage, vm.subscriptions.isEmpty {
                errorView(error)
            } else if vm.subscriptions.isEmpty {
                emptyView
            } else {
                subscriptionsList
            }
        }
        .navigationTitle("subscriptions.title")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus")
                }
                .opacity(viewMode == .list ? 1 : 0)
                .disabled(viewMode == .report)
            }
            ToolbarItem(placement: .topBarLeading) {
                Picker("", selection: $viewMode.animation()) {
                    Image(systemName: "list.bullet").tag(ViewMode.list)
                    Image(systemName: "chart.bar.fill").tag(ViewMode.report)
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            SubscriptionFormSheet(mode: .add) { formData in
                Task {
                    await vm.addSubscription(
                        title: formData.title,
                        amount: formData.amount,
                        currency: formData.currency,
                        billingCycle: formData.billingCycle,
                        startDate: formData.startDate,
                        category: formData.category,
                        iconName: formData.iconName
                    )
                }
            }
        }
        .sheet(item: $subscriptionToEdit) { sub in
            SubscriptionFormSheet(mode: .edit(sub)) { formData in
                Task {
                    await vm.updateSubscription(
                        id: sub.id,
                        title: formData.title,
                        amount: formData.amount,
                        currency: formData.currency,
                        billingCycle: formData.billingCycle,
                        startDate: formData.startDate,
                        category: formData.category,
                        iconName: formData.iconName,
                        isActive: formData.isActive,
                        endDate: formData.endDate
                    )
                }
            }
        }
        .alert("subscriptions.delete.confirm.title", isPresented: Binding(
            get: { subscriptionToDelete != nil },
            set: { if !$0 { subscriptionToDelete = nil } }
        )) {
            Button("subscriptions.delete.action", role: .destructive) {
                if let sub = subscriptionToDelete {
                    Task { await vm.deleteSubscription(sub) }
                }
                subscriptionToDelete = nil
            }
            Button("common.cancel", role: .cancel) {
                subscriptionToDelete = nil
            }
        } message: {
            Text("subscriptions.delete.confirm.message")
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }

    // MARK: - List

    private var subscriptionsList: some View {
        VStack(spacing: 0) {
            filterBar
            List {
                // Upcoming payments (next 7 days)
                let soon = vm.upcoming(withinDays: 7)
                if !soon.isEmpty {
                    Section("subscriptions.section.upcoming") {
                        ForEach(soon) { sub in upcomingRow(sub) }
                    }
                }

                // Monthly cost summary (recurring only, always from active subs)
                if !vm.activeCurrencies.filter({ vm.totalMonthlyCost(in: $0) > 0 }).isEmpty {
                    Section("subscriptions.section.summary") {
                        ForEach(vm.activeCurrencies, id: \.self) { currency in
                            let cost = vm.totalMonthlyCost(in: currency)
                            if cost > 0 {
                                HStack {
                                    Text("subscriptions.summary.monthly")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(String(format: "%.2f %@", cost, currency.rawValue))
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }

                // Filtered & paginated section
                Section {
                    if vm.pagedSubscriptions.isEmpty {
                        Text("subscriptions.filter.empty")
                            .font(.subheadline).foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                            .listRowBackground(Color.clear)
                    }
                    ForEach(vm.pagedSubscriptions) { sub in
                        SubscriptionRow(
                            subscription: sub,
                            monthlyCost: vm.monthlyCost(for: sub)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { subscriptionToEdit = sub }
                    }
                    .onDelete { indexSet in
                        if let index = indexSet.first {
                            subscriptionToDelete = vm.pagedSubscriptions[index]
                        }
                    }

                    // Pagination row
                    if vm.totalPages > 1 {
                        paginationRow
                    }
                } header: {
                    filteredSectionHeader
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SubscriptionStatusFilter.allCases) { filter in
                    Button { vm.setFilter(filter) } label: {
                        Text(filterLabel(for: filter))
                            .font(.subheadline)
                            .fontWeight(vm.statusFilter == filter ? .semibold : .regular)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(vm.statusFilter == filter
                                        ? Color.accentColor
                                        : Color(.secondarySystemFill))
                            .foregroundColor(vm.statusFilter == filter ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.18), value: vm.statusFilter)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Section header (filter label + count + page size picker)

    private var filteredSectionHeader: some View {
        HStack(spacing: 4) {
            Text("\(filterLabel(for: vm.statusFilter)) · \(vm.totalFilteredCount)")
                .foregroundColor(.secondary)
            Spacer()
            Picker("", selection: Binding(
                get: { vm.pageSize },
                set: { vm.setPageSize($0) }
            )) {
                ForEach(SubscriptionPageSize.allCases) { size in
                    Text(size == .unlimited
                         ? String(localized: "subscriptions.pageSize.all")
                         : "\(size.rawValue)")
                        .tag(size)
                }
            }
            .pickerStyle(.menu)
            .font(.caption)
        }
        .textCase(nil)
    }

    // MARK: - Pagination row

    private var paginationRow: some View {
        HStack {
            Button { vm.currentPage -= 1 } label: {
                Image(systemName: "chevron.left").padding(.trailing, 4)
            }
            .disabled(vm.currentPage <= 1)

            Spacer()

            Text(String(
                format: String(localized: "subscriptions.pagination.format"),
                vm.currentPage, vm.totalPages
            ))
            .font(.footnote).monospacedDigit().foregroundColor(.secondary)

            Spacer()

            Button { vm.currentPage += 1 } label: {
                Image(systemName: "chevron.right").padding(.leading, 4)
            }
            .disabled(vm.currentPage >= vm.totalPages)
        }
        .buttonStyle(.borderless)
        .foregroundColor(.accentColor)
        .listRowBackground(Color.clear)
    }

    // MARK: - Helpers

    private func filterLabel(for filter: SubscriptionStatusFilter) -> String {
        switch filter {
        case .all:       return String(localized: "subscriptions.filter.all")
        case .active:    return String(localized: "subscriptions.filter.active")
        case .cancelled: return String(localized: "subscriptions.filter.cancelled")
        case .paid:      return String(localized: "subscriptions.filter.paid")
        }
    }

    private func upcomingRow(_ sub: Subscription) -> some View {
        let payDate = sub.billingCycle.isRecurring ? sub.nextPaymentDate : sub.startDate
        return HStack(spacing: 12) {
            SubscriptionIcon(name: sub.iconName ?? "repeat.circle.fill", size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(sub.title).font(.subheadline).fontWeight(.medium)
                Text(payDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundColor(.orange)
            }
            Spacer()
            Text(String(format: "%.2f %@", sub.amount, sub.currency.rawValue))
                .font(.subheadline).fontWeight(.semibold)
        }
    }

    // MARK: - Empty / Error

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "repeat.circle")
                .font(.system(size: 48)).foregroundColor(.secondary)
            Text("subscriptions.empty")
                .foregroundColor(.secondary)
            Button("subscriptions.add.title") {
                showAddSheet = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 8) {
            Text("common.error").font(.headline)
            Text(error).font(.caption).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)
            Button("common.retry") { Task { await vm.load() } }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Subscription Row

private struct SubscriptionRow: View {
    let subscription: Subscription
    let monthlyCost: Double

    private var isOneTime: Bool { !subscription.billingCycle.isRecurring }
    private var isPurchased: Bool { isOneTime && subscription.startDate <= Date() }

    var body: some View {
        HStack(spacing: 12) {
            SubscriptionIcon(name: subscription.iconName ?? "repeat.circle.fill", size: 40)

            VStack(alignment: .leading, spacing: 3) {
                // Title + amount
                HStack {
                    Text(subscription.title).font(.headline)
                    Spacer()
                    Text(String(format: "%.2f %@", subscription.amount, subscription.currency.rawValue))
                        .font(.subheadline).fontWeight(.medium)
                }
                // Category + cycle badge + status
                HStack {
                    if let cat = subscription.category, !cat.isEmpty {
                        Text(cat).font(.caption).foregroundColor(.secondary)
                        Text("·").font(.caption).foregroundColor(.secondary)
                    }
                    Text(String(localized: billingCycleKey))
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text(statusLabel)
                        .font(.caption2).fontWeight(.medium)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(statusColor.opacity(0.15))
                        .foregroundColor(statusColor)
                        .clipShape(Capsule())
                }
                // Payment info row
                if subscription.isActive {
                    if isOneTime {
                        // One-time: show purchase date
                        HStack(spacing: 4) {
                            Image(systemName: isPurchased ? "checkmark.circle" : "calendar")
                                .font(.caption2)
                                .foregroundColor(isPurchased ? .secondary : .orange)
                            Text(isPurchased
                                 ? String(localized: "subscriptions.oneTime.purchased")
                                 : String(localized: "subscriptions.oneTime.scheduledFor")
                                     + " " + subscription.startDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(isPurchased ? .secondary : .orange)
                        }
                    } else {
                        // Recurring: show next payment date + normalized monthly cost
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.caption2).foregroundColor(.orange)
                            Text(String(localized: "subscriptions.nextPayment")
                                 + ": " + subscription.nextPaymentDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption).foregroundColor(.orange)
                            if subscription.billingCycle != .monthly {
                                Spacer()
                                Text(String(format: String(localized: "subscriptions.monthly.cost.format"),
                                            monthlyCost, subscription.currency.rawValue))
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                } else if let end = subscription.endDate {
                    // Cancelled with recorded end date
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                            .font(.caption2).foregroundColor(.secondary)
                        Text(String(format: String(localized: "subscriptions.cancelled.on.format"),
                                    end.formatted(date: .abbreviated, time: .omitted)))
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(subscription.isActive ? 1.0 : 0.6)
    }

    private var billingCycleKey: String.LocalizationValue {
        switch subscription.billingCycle {
        case .weekly:    return "subscriptions.cycle.weekly"
        case .monthly:   return "subscriptions.cycle.monthly"
        case .quarterly: return "subscriptions.cycle.quarterly"
        case .yearly:    return "subscriptions.cycle.yearly"
        case .oneTime:   return "subscriptions.cycle.oneTime"
        }
    }

    private var statusLabel: String {
        if !subscription.isActive { return String(localized: "subscriptions.status.cancelled") }
        if isOneTime && isPurchased { return String(localized: "subscriptions.status.paid") }
        return String(localized: "subscriptions.status.active")
    }

    private var statusColor: Color {
        if !subscription.isActive { return .secondary }
        if isOneTime && isPurchased { return .blue }
        return .green
    }
}

// MARK: - Icon helper

struct SubscriptionIcon: View {
    let name: String
    let size: CGFloat

    private static let knownSymbols: Set<String> = [
        "repeat.circle.fill", "tv.fill", "music.note", "gamecontroller.fill",
        "cloud.fill", "book.fill", "heart.fill", "gym.bag.fill",
        "fork.knife", "cart.fill", "newspaper.fill", "mic.fill",
        "waveform", "cpu.fill", "phone.fill", "envelope.fill"
    ]

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: size, height: size)
            Image(systemName: Self.knownSymbols.contains(name) ? name : "repeat.circle.fill")
                .font(.system(size: size * 0.45))
                .foregroundColor(.accentColor)
        }
    }
}

// MARK: - Report View

private struct SubscriptionsReportView: View {
    @ObservedObject var vm: SubscriptionsViewModel

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }

    private static let palette: [Color] = [
        Color(red: 0.957, green: 0.596, blue: 0.188),
        Color(red: 0.259, green: 0.522, blue: 0.957),
        Color(red: 0.298, green: 0.749, blue: 0.435),
        Color(red: 0.612, green: 0.369, blue: 0.929),
        Color(red: 0.922, green: 0.341, blue: 0.349),
    ]

    private var currencyColorMap: [String: Color] {
        let currencies = vm.activeCurrencies.map { $0.rawValue }
        return Dictionary(uniqueKeysWithValues: currencies.enumerated().map { idx, cur in
            (cur, Self.palette[idx % Self.palette.count])
        })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summarySection
                monthlyChartSection
                if !vm.subscriptions.filter({ $0.isActive }).isEmpty {
                    upcomingSection
                    annualBreakdownSection
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            // Clamp selected year to valid range
            if !vm.yearRange.contains(selectedYear) {
                selectedYear = currentYear
            }
        }
    }

    // MARK: Summary cards

    private var summarySection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(vm.activeCurrencies, id: \.self) { currency in
                    let monthly = vm.totalMonthlyCost(in: currency)
                    let annual  = vm.totalAnnualCost(in: currency)
                    let count   = vm.subscriptions.filter { $0.isActive && $0.currency == currency }.count
                    ReportSummaryCard(
                        currency: currency.rawValue,
                        monthly: monthly,
                        annual: annual,
                        count: count
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: Monthly payment bar chart

    private var monthlyChartSection: some View {
        let points  = vm.monthlyPayments(year: selectedYear)
        let totals  = vm.monthlyTotals(year: selectedYear)
        let colorMap = currencyColorMap
        let domain  = Array(Set(points.map { $0.currency })).sorted()
        let range   = domain.map { colorMap[$0] ?? Self.palette[0] }
        let yearRange = vm.yearRange

        return VStack(alignment: .leading, spacing: 16) {
            // Header row: title + year selector
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("subscriptions.report.chart.title")
                        .font(.subheadline).foregroundColor(.secondary)
                    if points.isEmpty {
                        Text("—").font(.title3).fontWeight(.bold)
                    } else {
                        let annualTotal = totals.reduce(0.0) { $0 + $1.total }
                        ForEach(vm.activeCurrencies, id: \.self) { cur in
                            let t = points.filter { $0.currency == cur.rawValue }
                                         .reduce(0.0) { $0 + $1.total }
                            if t > 0 {
                                Text(String(format: "%.0f %@", t, cur.rawValue))
                                    .font(.title3).fontWeight(.bold)
                            }
                        }
                    }
                }
                Spacer()
                // Year picker
                HStack(spacing: 4) {
                    Button { selectedYear -= 1 } label: {
                        Image(systemName: "chevron.left")
                            .font(.footnote.weight(.semibold))
                    }
                    .disabled(selectedYear <= yearRange.lowerBound)

                    Text(String(selectedYear))
                        .font(.headline).monospacedDigit()
                        .frame(minWidth: 44)

                    Button { selectedYear += 1 } label: {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                    }
                    .disabled(selectedYear >= yearRange.upperBound)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)

            if points.isEmpty {
                Text("subscriptions.report.chart.empty")
                    .font(.callout).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                // Stacked bar chart
                Chart {
                    ForEach(points) { point in
                        BarMark(
                            x: .value("Month", point.month, unit: .month),
                            y: .value("Amount", point.total),
                            stacking: .standard
                        )
                        .foregroundStyle(by: .value("Currency", point.currency))
                        .cornerRadius(4)
                    }
                    // Total annotations above each bar
                    ForEach(totals, id: \.month) { item in
                        PointMark(
                            x: .value("Month", item.month, unit: .month),
                            y: .value("Total", item.total)
                        )
                        .opacity(0)
                        .annotation(position: .top, alignment: .center, spacing: 2) {
                            Text(item.total.formatted(
                                .number.notation(.compactName).precision(.fractionLength(0))
                            ))
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
                                Text(v.formatted(
                                    .number.notation(.compactName).precision(.fractionLength(0))
                                ))
                                .font(.caption2)
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                    }
                }
                .chartBackground { proxy in
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

                // Currency legend
                let currencies = domain
                HStack(spacing: 16) {
                    ForEach(currencies, id: \.self) { currency in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(colorMap[currency] ?? Self.palette[0])
                                .frame(width: 12, height: 12)
                            Text(currency).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }

    // MARK: Upcoming payments

    private var upcomingSection: some View {
        let upcoming = vm.upcoming(withinDays: 30)
        guard !upcoming.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "subscriptions.report.upcoming"))
                    .font(.subheadline).foregroundColor(.secondary)
                    .padding(.horizontal, 16)

                ForEach(upcoming) { sub in
                    let payDate = sub.billingCycle.isRecurring ? sub.nextPaymentDate : sub.startDate
                    HStack(spacing: 12) {
                        SubscriptionIcon(name: sub.iconName ?? "repeat.circle.fill", size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sub.title).font(.subheadline).fontWeight(.medium)
                            Text(payDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption).foregroundColor(.orange)
                        }
                        Spacer()
                        Text(String(format: "%.2f %@", sub.amount, sub.currency.rawValue))
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            .padding(.horizontal)
        )
    }

    // MARK: Annual breakdown

    private var annualBreakdownSection: some View {
        let active = vm.subscriptions.filter { $0.isActive && $0.billingCycle.isRecurring }
        guard !active.isEmpty else { return AnyView(EmptyView()) }
        let colorMap = currencyColorMap

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "subscriptions.report.annual"))
                    .font(.subheadline).foregroundColor(.secondary)
                    .padding(.horizontal, 16)

                ForEach(vm.activeCurrencies.filter { cur in active.contains { $0.currency == cur } }, id: \.self) { currency in
                    let subs = active.filter { $0.currency == currency }
                    let total = vm.totalAnnualCost(in: currency)
                    VStack(spacing: 0) {
                        ForEach(subs) { sub in
                            let cost = vm.annualCost(for: sub)
                            HStack {
                                SubscriptionIcon(name: sub.iconName ?? "repeat.circle.fill", size: 28)
                                Text(sub.title).font(.subheadline)
                                Spacer()
                                Text(String(format: "%.2f %@", cost, currency.rawValue))
                                    .font(.subheadline).foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            Divider().padding(.leading, 56)
                        }
                        HStack {
                            Text(String(localized: "subscriptions.report.total"))
                                .fontWeight(.semibold)
                            Spacer()
                            Text(String(format: "%.2f %@", total, currency.rawValue))
                                .fontWeight(.bold)
                                .foregroundColor(colorMap[currency.rawValue] ?? .accentColor)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 16)
        )
    }
}

// MARK: - Report summary card

private struct ReportSummaryCard: View {
    let currency: String
    let monthly: Double
    let annual: Double
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(currency).font(.headline)
                Spacer()
                Text("\(count) \(String(localized: "subscriptions.report.card.count"))")
                    .font(.caption).foregroundColor(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "subscriptions.report.card.monthly"))
                    .font(.caption2).foregroundColor(.secondary)
                Text(monthly > 0 ? String(format: "%.2f", monthly) : "—")
                    .font(.title3).fontWeight(.bold)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "subscriptions.report.card.annual"))
                    .font(.caption2).foregroundColor(.secondary)
                Text(annual > 0 ? String(format: "%.0f", annual) : "—")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(width: 160)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Form data types

struct SubscriptionFormData {
    var title: String
    var amount: Double
    var currency: DepositCurrency
    var billingCycle: SubscriptionBillingCycle
    var startDate: Date
    var category: String
    var iconName: String
    var isActive: Bool
    var endDate: Date?
}

enum SubscriptionFormMode {
    case add
    case edit(Subscription)
}

// MARK: - Form Sheet

struct SubscriptionFormSheet: View {
    let mode: SubscriptionFormMode
    let onSave: (SubscriptionFormData) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("Settings_SelectedCurrencies") private var selectedCurrenciesRaw: String = "USD,EUR,GBP,RUB"
    private var selectedCurrencies: Set<String> {
        Set(selectedCurrenciesRaw.split(separator: ",").map { String($0) })
    }

    @State private var title: String
    @State private var amountText: String
    @State private var currency: DepositCurrency
    @State private var billingCycle: SubscriptionBillingCycle
    @State private var startDate: Date
    @State private var category: String
    @State private var selectedIcon: String
    @State private var isActive: Bool
    @State private var endDate: Date
    @State private var validationError: String?

    static let iconPresets: [(symbol: String, label: String)] = [
        ("repeat.circle.fill", "Default"),
        ("tv.fill", "TV"),
        ("music.note", "Music"),
        ("gamecontroller.fill", "Games"),
        ("cloud.fill", "Cloud"),
        ("book.fill", "Books"),
        ("gym.bag.fill", "Fitness"),
        ("fork.knife", "Food"),
        ("newspaper.fill", "News"),
        ("mic.fill", "Podcast"),
        ("cart.fill", "Shopping"),
        ("phone.fill", "Phone"),
    ]

    init(mode: SubscriptionFormMode, onSave: @escaping (SubscriptionFormData) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .add:
            _title = State(initialValue: "")
            _amountText = State(initialValue: "")
            _currency = State(initialValue: .RUB)
            _billingCycle = State(initialValue: .monthly)
            _startDate = State(initialValue: Date())
            _category = State(initialValue: "")
            _selectedIcon = State(initialValue: "repeat.circle.fill")
            _isActive = State(initialValue: true)
            _endDate = State(initialValue: Date())
        case .edit(let sub):
            _title = State(initialValue: sub.title)
            _amountText = State(initialValue: String(sub.amount))
            _currency = State(initialValue: sub.currency)
            _billingCycle = State(initialValue: sub.billingCycle)
            _startDate = State(initialValue: sub.startDate)
            _category = State(initialValue: sub.category ?? "")
            _selectedIcon = State(initialValue: sub.iconName ?? "repeat.circle.fill")
            _isActive = State(initialValue: sub.isActive)
            _endDate = State(initialValue: sub.endDate ?? Date())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Icon picker
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Self.iconPresets, id: \.symbol) { preset in
                                Button {
                                    selectedIcon = preset.symbol
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(selectedIcon == preset.symbol
                                                  ? Color.accentColor.opacity(0.2)
                                                  : Color(.systemFill))
                                            .frame(width: 48, height: 48)
                                        Image(systemName: preset.symbol)
                                            .font(.system(size: 22))
                                            .foregroundColor(selectedIcon == preset.symbol
                                                             ? .accentColor : .secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text(String(localized: "subscriptions.field.icon"))
                }

                Section {
                    TextField(String(localized: "subscriptions.field.name"), text: $title)
                    TextField(String(localized: "subscriptions.field.category"), text: $category)
                }

                Section {
                    TextField(String(localized: "subscriptions.field.amount"), text: $amountText)
                        .keyboardType(.decimalPad)
                    Picker(String(localized: "subscriptions.field.currency"), selection: $currency) {
                        ForEach(DepositCurrency.allCases.filter { selectedCurrencies.contains($0.rawValue) }) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                    Picker(String(localized: "subscriptions.field.billingCycle"), selection: $billingCycle) {
                        ForEach(SubscriptionBillingCycle.allCases) { cycle in
                            Text(String(localized: billingCycleLabel(cycle))).tag(cycle)
                        }
                    }
                }

                // Start date label adapts to billing cycle
                Section {
                    DatePicker(
                        billingCycle.isRecurring
                            ? String(localized: "subscriptions.field.startDate")
                            : String(localized: "subscriptions.field.purchaseDate"),
                        selection: $startDate,
                        displayedComponents: .date
                    )
                }

                if case .edit = mode {
                    Section {
                        Toggle(String(localized: "subscriptions.field.isActive"), isOn: $isActive)
                        if !isActive {
                            DatePicker(
                                String(localized: "subscriptions.field.endDate"),
                                selection: $endDate,
                                displayedComponents: .date
                            )
                        }
                    }
                }

                if let error = validationError {
                    Section {
                        Text(error).foregroundColor(.red).font(.caption)
                    }
                }
            }
            .navigationTitle(formTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) { save() }
                }
            }
        }
    }

    private var formTitle: String {
        switch mode {
        case .add:  return String(localized: "subscriptions.add.title")
        case .edit: return String(localized: "subscriptions.edit.title")
        }
    }

    private func billingCycleLabel(_ cycle: SubscriptionBillingCycle) -> String.LocalizationValue {
        switch cycle {
        case .weekly:    return "subscriptions.cycle.weekly"
        case .monthly:   return "subscriptions.cycle.monthly"
        case .quarterly: return "subscriptions.cycle.quarterly"
        case .yearly:    return "subscriptions.cycle.yearly"
        case .oneTime:   return "subscriptions.cycle.oneTime"
        }
    }

    private func save() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationError = String(localized: "subscriptions.error.emptyTitle")
            return
        }
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        onSave(SubscriptionFormData(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            currency: currency,
            billingCycle: billingCycle,
            startDate: startDate,
            category: category.trimmingCharacters(in: .whitespacesAndNewlines),
            iconName: selectedIcon,
            isActive: isActive,
            endDate: isActive ? nil : endDate
        ))
        dismiss()
    }
}
