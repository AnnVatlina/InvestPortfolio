//
//  HomeTabView.swift
//
//  Created by Anna on 26.12.25.
//
//  Home: nearest upcoming subscription payments and currently open deposits —
//  the two things worth checking at a glance, without duplicating the tabs below.
//

import SwiftUI

struct HomeTabView: View {
    @StateObject private var vm: HomeViewModel

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
