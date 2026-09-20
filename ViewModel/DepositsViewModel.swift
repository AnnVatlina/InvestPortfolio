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
        annualInterestRate: Double
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
                annualInterestRate: annualInterestRate
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
        annualInterestRate: Double
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
                annualInterestRate: annualInterestRate
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
        let notificationDate = Calendar.current.date(byAdding: .day, value: -7, to: closeDate)
        guard let fireDate = notificationDate, fireDate > Date() else { return }

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = LanguageBundle.string("deposits.notification.title")
            content.body = String(format: LanguageBundle.string("deposits.notification.body.format"), title)
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "deposit-\(depositId.uuidString)", content: content, trigger: trigger)
            center.add(request)
        }
    }

    private func cancelCloseNotification(depositId: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["deposit-\(depositId.uuidString)"])
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
