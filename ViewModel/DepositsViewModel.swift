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
    @Published var operationError: String?

    @Published private(set) var incomes: [UUID: DepositIncomeSummary] = [:]

    private let service: any DepositsService
    private let api: any DepositsAPIProtocol

    init(service: any DepositsService, api: any DepositsAPIProtocol = DepositsAPI()) {
        self.service = service
        self.api = api
    }

    // MARK: - Load (cache-first, then sync from API)

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // 1. Show cached data immediately
        if let cached = try? await service.fetchAll() {
            deposits = sorted(cached)
            recomputeIncomes()
        }

        // 2. Fetch from API, upsert into cache, remove stale entries, reload
        do {
            let remoteList = try await api.getDeposits()
            for dto in remoteList {
                try await service.upsert(
                    serverId: dto.id,
                    title: dto.title,
                    bankName: dto.bankName,
                    amount: dto.amountDouble,
                    currency: dto.depositCurrency,
                    openDate: dto.openDate,
                    closeDate: dto.closeDate,
                    annualInterestRate: dto.annualRateDouble,
                    createdAt: dto.createdAt
                )
            }
            let remoteIds = Set(remoteList.map(\.id))
            let allLocal = try await service.fetchAll()
            for staleId in allLocal.compactMap(\.serverId) where !remoteIds.contains(staleId) {
                try await service.deleteByServerId(staleId)
            }
            let updated = try await service.fetchAll()
            deposits = sorted(updated)
            recomputeIncomes()
        } catch {
            // Keep cached data visible, show non-blocking error
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
            errorMessage = String(localized: "deposits.error.emptyTitle")
            return
        }

        let bankNameOpt = bankName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : bankName.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let body = DepositCreate(
                title: title,
                bankName: bankNameOpt,
                amount: amount,
                currency: currency,
                openDate: openDate,
                closeDate: closeDate,
                annualInterestRate: annualInterestRate
            )
            let response = try await api.createDeposit(body)
            try await service.upsert(
                serverId: response.id,
                title: response.title,
                bankName: response.bankName,
                amount: response.amountDouble,
                currency: response.depositCurrency,
                openDate: response.openDate,
                closeDate: response.closeDate,
                annualInterestRate: response.annualRateDouble,
                createdAt: response.createdAt
            )
            if let close = closeDate {
                scheduleCloseNotification(depositId: response.id, title: title, closeDate: close)
            }
            await load()
        } catch {
            operationError = error.localizedDescription
        }
    }

    // MARK: - Delete

    func deleteDeposit(_ deposit: Deposit) async {
        do {
            cancelCloseNotification(depositId: deposit.serverId ?? deposit.id)
            if let serverId = deposit.serverId {
                try await api.deleteDeposit(id: serverId)
                try await service.deleteByServerId(serverId)
            } else {
                // Fallback: locally-only deposit (no server record)
                try await service.delete(id: deposit.id)
            }
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
            errorMessage = String(localized: "deposits.error.emptyTitle")
            return
        }

        let bankNameOpt = bankName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : bankName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let deposit = deposits.first(where: { $0.id == id }),
              let serverId = deposit.serverId else {
            // Fallback: no server ID, update locally only
            try? await service.update(
                id: id, title: title, bankName: bankNameOpt, amount: amount,
                currency: currency, openDate: openDate, closeDate: closeDate,
                annualInterestRate: annualInterestRate
            )
            await load()
            return
        }

        do {
            let body = DepositUpdate(
                title: title,
                bankName: bankNameOpt,
                amount: amount,
                currency: currency,
                openDate: openDate,
                closeDate: closeDate,
                annualInterestRate: annualInterestRate
            )
            let response = try await api.updateDeposit(id: serverId, body)
            try await service.upsert(
                serverId: response.id,
                title: response.title,
                bankName: response.bankName,
                amount: response.amountDouble,
                currency: response.depositCurrency,
                openDate: response.openDate,
                closeDate: response.closeDate,
                annualInterestRate: response.annualRateDouble,
                createdAt: response.createdAt
            )
            cancelCloseNotification(depositId: serverId)
            if let close = closeDate {
                scheduleCloseNotification(depositId: serverId, title: title, closeDate: close)
            }
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
