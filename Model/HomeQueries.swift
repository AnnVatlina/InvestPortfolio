//
//  HomeQueries.swift
//  InvestPortfolio
//
//  Pure filtering/sorting rules for "what's relevant right now" — shared between
//  HomeViewModel (in-app) and the widget extension (out-of-process), so both read
//  the same definition of "open" and "upcoming" instead of two copies drifting apart.
//

import Foundation

extension Array where Element == Deposit {
    /// Deposits that haven't closed yet, soonest end date first.
    /// Deposits with no end date sort last — there's nothing to be soon about.
    var openSortedByCloseDate: [Deposit] {
        let now = Date()
        return filter { $0.closeDate == nil || $0.closeDate! > now }
            .sorted { ($0.closeDate ?? .distantFuture) < ($1.closeDate ?? .distantFuture) }
    }
}

extension Array where Element == Subscription {
    /// The nearest upcoming payments across active subscriptions, soonest first.
    /// One-time purchases already made are not "upcoming" and are excluded.
    func nearestUpcoming(limit: Int = 5) -> [Subscription] {
        // A subscription due "today" has its dueDate normalized to midnight — comparing
        // against the exact current instant (rather than the start of today) would drop
        // it off this list the moment any time passes after midnight on its due day.
        let now = Calendar.current.startOfDay(for: Date())
        return Array(
            filter { $0.isActive && $0.dueDate >= now }
                .sorted { $0.dueDate < $1.dueDate }
                .prefix(limit)
        )
    }
}

extension Subscription {
    var dueDate: Date {
        billingCycle.isRecurring ? nextPaymentDate : startDate
    }
}
