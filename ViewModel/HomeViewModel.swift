//
//  HomeViewModel.swift
//  InvestPortfolio
//
//  Feeds the home screen: nearest upcoming subscription payments and
//  currently open deposits, sorted by end date.
//

import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var deposits: [Deposit] = []
    @Published private(set) var subscriptions: [Subscription] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let depositsService: any DepositsService
    private let subscriptionsService: any SubscriptionsService

    init(
        depositsService: any DepositsService,
        subscriptionsService: any SubscriptionsService
    ) {
        self.depositsService = depositsService
        self.subscriptionsService = subscriptionsService
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let deps = depositsService.fetchAll()
            async let subs = subscriptionsService.fetchAll()
            (deposits, subscriptions) = try await (deps, subs)
        } catch {
            if deposits.isEmpty && subscriptions.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Deposits that haven't closed yet, soonest end date first.
    /// Deposits with no end date sort last — there's nothing to be soon about.
    var openDeposits: [Deposit] {
        let now = Date()
        return deposits
            .filter { $0.closeDate == nil || $0.closeDate! > now }
            .sorted { ($0.closeDate ?? .distantFuture) < ($1.closeDate ?? .distantFuture) }
    }

    /// The nearest upcoming payments across active subscriptions, soonest first.
    /// One-time purchases already made are not "upcoming" and are excluded.
    func upcomingSubscriptions(limit: Int = 5) -> [Subscription] {
        let now = Date()
        return Array(
            subscriptions
                .filter { $0.isActive && dueDate(for: $0) >= now }
                .sorted { dueDate(for: $0) < dueDate(for: $1) }
                .prefix(limit)
        )
    }

    private func dueDate(for subscription: Subscription) -> Date {
        subscription.billingCycle.isRecurring ? subscription.nextPaymentDate : subscription.startDate
    }
}
