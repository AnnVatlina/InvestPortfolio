//
//  DepositsViewModel.swift
//
//  Created by Anna on 30.12.25.
//

import Foundation

@MainActor
final class DepositsViewModel: ObservableObject {
    @Published private(set) var deposits: [Deposit] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published private(set) var incomes: [UUID: DepositIncomeSummary] = [:]

    private let service: DepositsService

    init(service: DepositsService = DefaultDepositsService(repository: InMemoryDepositsRepository())) {
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
        amount: Double,
        currency: DepositCurrency,
        openDate: Date,
        closeDate: Date?,
        annualInterestRate: Double
    ) async {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Введите название"
            return
        }

        let newDeposit = Deposit(
            title: title,
            amount: amount,
            currency: currency,
            openDate: openDate,
            closeDate: closeDate,
            annualInterestRate: annualInterestRate
        )

        do {
            try await service.add(newDeposit)
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

    private func recomputeIncomes() {
        var dict: [UUID: DepositIncomeSummary] = [:]
        let now = Date()
        for d in deposits {
            dict[d.id] = service.incomeSummary(for: d, asOf: now)
        }
        incomes = dict
    }
}

