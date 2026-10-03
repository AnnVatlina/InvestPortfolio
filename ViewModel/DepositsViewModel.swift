//
//  DepositsViewModel.swift
//
//  Created by Anna on 30.12.25.
//

import Foundation
@preconcurrency import UserNotifications
import WidgetKit

@MainActor
final class DepositsViewModel: ObservableObject {
    @Published private(set) var deposits: [Deposit] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var operationError: String?

    @Published private(set) var incomes: [UUID: DepositIncomeSummary] = [:]

    private let service: any DepositsService

    init(service: any DepositsService) {
        self.service = service
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let all = try await service.fetchAll()
            deposits = sorted(all)
            recomputeIncomes()
            rescheduleAllCloseNotifications()
        } catch {
            if deposits.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Create

    func addDeposit(
        title: String,
        bankName: String,
        amount: Double,
        currency: DepositCurrency,
        openDate: Date,
        closeDate: Date?,
        annualInterestRate: Double,
        interestType: DepositInterestType = .simple,
        capitalizationPeriod: CapitalizationPeriod? = nil,
        allowsReplenishment: Bool = false,
        allowsPartialWithdrawal: Bool = false,
        isRevocable: Bool = true,
        earlyWithdrawalRate: Double? = nil
    ) async {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = LanguageBundle.string("deposits.error.emptyTitle")
            return
        }

        let bankNameOpt = bankName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : bankName.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let deposit = Deposit(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                bankName: bankNameOpt,
                amount: amount,
                currency: currency,
                openDate: openDate,
                closeDate: closeDate,
                annualInterestRate: annualInterestRate,
                interestType: interestType,
                capitalizationPeriod: capitalizationPeriod,
                allowsReplenishment: allowsReplenishment,
                allowsPartialWithdrawal: allowsPartialWithdrawal,
                isRevocable: isRevocable,
                earlyWithdrawalRate: earlyWithdrawalRate
            )
            try await service.add(deposit)
            if let close = closeDate {
                scheduleCloseNotification(depositId: deposit.id, title: title, closeDate: close)
            }
            WidgetCenter.shared.reloadAllTimelines()
            await load()
        } catch {
            operationError = error.localizedDescription
        }
    }

    // MARK: - Delete

    func deleteDeposit(_ deposit: Deposit) async {
        do {
            cancelCloseNotification(depositId: deposit.id)
            try await service.delete(id: deposit.id)
            WidgetCenter.shared.reloadAllTimelines()
            await load()
        } catch {
            operationError = error.localizedDescription
        }
    }

    // MARK: - Update

    func updateDeposit(
        id: UUID,
        title: String,
        bankName: String,
        amount: Double,
        currency: DepositCurrency,
        openDate: Date,
        closeDate: Date?,
        annualInterestRate: Double,
        interestType: DepositInterestType = .simple,
        capitalizationPeriod: CapitalizationPeriod? = nil,
        allowsReplenishment: Bool = false,
        allowsPartialWithdrawal: Bool = false,
        isRevocable: Bool = true,
        earlyWithdrawalRate: Double? = nil,
        actualCloseDate: Date? = nil
    ) async {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = LanguageBundle.string("deposits.error.emptyTitle")
            return
        }

        let bankNameOpt = bankName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : bankName.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await service.update(
                id: id,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                bankName: bankNameOpt,
                amount: amount,
                currency: currency,
                openDate: openDate,
                closeDate: closeDate,
                annualInterestRate: annualInterestRate,
                interestType: interestType,
                capitalizationPeriod: capitalizationPeriod,
                allowsReplenishment: allowsReplenishment,
                allowsPartialWithdrawal: allowsPartialWithdrawal,
                isRevocable: isRevocable,
                earlyWithdrawalRate: earlyWithdrawalRate,
                actualCloseDate: actualCloseDate
            )
            cancelCloseNotification(depositId: id)
            if let close = closeDate {
                scheduleCloseNotification(depositId: id, title: title, closeDate: close)
            }
            WidgetCenter.shared.reloadAllTimelines()
            await load()
        } catch {
            operationError = error.localizedDescription
        }
    }

    // MARK: - Income summary

    func incomeSummary(for deposit: Deposit) -> DepositIncomeSummary {
        if let cached = incomes[deposit.id] { return cached }
        let summary = service.incomeSummary(for: deposit, asOf: Date())
        incomes[deposit.id] = summary
        return summary
    }

    // MARK: - Notifications

    private func scheduleCloseNotification(depositId: UUID, title: String, closeDate: Date) {
        let notifTitle = LanguageBundle.string("deposits.notification.title")
        let bodyFormat = LanguageBundle.string("deposits.notification.body.format")
        guard let request = Self.closeNotificationRequest(
            depositId: depositId, title: title, closeDate: closeDate,
            notifTitle: notifTitle, bodyFormat: bodyFormat
        ) else { return }

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            center.add(request)
        }
    }

    private func cancelCloseNotification(depositId: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["deposit-\(depositId.uuidString)"])
    }

    /// Reschedules close-date reminders for every currently loaded deposit, clearing stale
    /// `deposit-*` requests first. Runs on every `load()` so deposits created outside
    /// `addDeposit`/`updateDeposit` — demo data and CSV import, which both call the service
    /// directly — still get a reminder the next time the Deposits tab opens, the same way
    /// `SubscriptionsViewModel.rescheduleAllNotifications()` already self-heals subscriptions.
    private func rescheduleAllCloseNotifications() {
        let notifTitle = LanguageBundle.string("deposits.notification.title")
        let bodyFormat = LanguageBundle.string("deposits.notification.body.format")
        let requests: [UNNotificationRequest] = deposits.compactMap { deposit in
            guard deposit.actualCloseDate == nil, let closeDate = deposit.closeDate else { return nil }
            return Self.closeNotificationRequest(
                depositId: deposit.id, title: deposit.title, closeDate: closeDate,
                notifTitle: notifTitle, bodyFormat: bodyFormat
            )
        }

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            center.getPendingNotificationRequests { pending in
                let staleIds = pending.map(\.identifier).filter { $0.hasPrefix("deposit-") }
                center.removePendingNotificationRequests(withIdentifiers: staleIds)
                for request in requests { center.add(request) }
            }
        }
    }

    private static func closeNotificationRequest(
        depositId: UUID, title: String, closeDate: Date, notifTitle: String, bodyFormat: String
    ) -> UNNotificationRequest? {
        guard let fireDate = Calendar.current.date(byAdding: .day, value: -7, to: closeDate),
              fireDate > Date() else { return nil }
        let content = UNMutableNotificationContent()
        content.title = notifTitle
        content.body = String(format: bodyFormat, title)
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: "deposit-\(depositId.uuidString)", content: content, trigger: trigger)
    }

    // MARK: - Private

    private func sorted(_ items: [Deposit]) -> [Deposit] {
        let now = Date()
        return items.sorted { a, b in
            let aActive = a.closeDate.map { $0 > now } ?? true
            let bActive = b.closeDate.map { $0 > now } ?? true
            if aActive != bActive { return aActive }
            if aActive {
                switch (a.closeDate, b.closeDate) {
                case (nil, nil): return a.openDate > b.openDate
                case (nil, _):   return false
                case (_, nil):   return true
                case (let d1?, let d2?): return d1 < d2
                }
            } else {
                return (a.closeDate ?? .distantPast) > (b.closeDate ?? .distantPast)
            }
        }
    }

    private func recomputeIncomes() {
        var dict: [UUID: DepositIncomeSummary] = [:]
        let now = Date()
        for d in deposits { dict[d.id] = service.incomeSummary(for: d, asOf: now) }
        incomes = dict
    }
}
