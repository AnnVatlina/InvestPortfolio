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

    private let repository: DepositsRepository

    init(repository: DepositsRepository = InMemoryDepositsRepository()) {
        self.repository = repository
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            deposits = try await repository.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addDeposit(title: String, amount: Double, currency: String) async {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !currency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            errorMessage = "Введите название и валюту"
            return
        }

        let newDeposit = Deposit(title: title, amount: amount, currency: currency)
        do {
            try await repository.add(newDeposit)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

