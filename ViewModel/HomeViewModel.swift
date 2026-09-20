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
    var openDeposits: [Deposit] {
        deposits.openSortedByCloseDate
    }

    /// The nearest upcoming payments across active subscriptions, soonest first.
    func upcomingSubscriptions(limit: Int = 5) -> [Subscription] {
        subscriptions.nearestUpcoming(limit: limit)
    }
}
