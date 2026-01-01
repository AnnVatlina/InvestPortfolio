//
//  DepositsViewModel.swift
//
//  Created by Anna on 30.12.25.
//

import Foundation
@preconcurrency import UserNotifications

@MainActor
final class DepositsViewModel: ObservableObject {
    @Published private(set) var deposits: [Deposit] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published private(set) var incomes: [UUID: DepositIncomeSummary] = [:]

    private let service: any DepositsService

    init(service: any DepositsService) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let items = try await service.fetchAll()
            deposits = items
            recomputeIncomes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

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
            errorMessage = String(localized: "deposits.error.emptyTitle")
            return
        }

        let bankNameOpt = bankName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bankName.trimmingCharacters(in: .whitespacesAndNewlines)
        let newDeposit = Deposit(
            title: title,
            bankName: bankNameOpt,
            amount: amount,
            currency: currency,
            openDate: openDate,
            closeDate: closeDate,
            annualInterestRate: annualInterestRate
        )

        do {
            try await service.add(newDeposit)
            if let close = closeDate {
                scheduleCloseNotification(depositId: newDeposit.id, title: title, closeDate: close)
            }
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteDeposit(_ deposit: Deposit) async {
        do {
            cancelCloseNotification(depositId: deposit.id)
            try await service.delete(id: deposit.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

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
            errorMessage = String(localized: "deposits.error.emptyTitle")
            return
        }

        let bankNameOpt = bankName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bankName.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await service.update(
                id: id,
                title: title,
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
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func incomeSummary(for deposit: Deposit) -> DepositIncomeSummary {
        if let cached = incomes[deposit.id] {
            return cached
        }
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
            content.title = String(localized: "deposits.notification.title")
            content.body = String(format: String(localized: "deposits.notification.body.format"), title)
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "deposit-\(depositId.uuidString)", content: content, trigger: trigger)
            center.add(request)
        }
    }

    private func cancelCloseNotification(depositId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["deposit-\(depositId.uuidString)"])
    }

    // MARK: - Private

    private func recomputeIncomes() {
        var dict: [UUID: DepositIncomeSummary] = [:]
        let now = Date()
        for d in deposits {
            dict[d.id] = service.incomeSummary(for: d, asOf: now)
        }
        incomes = dict
    }
}

