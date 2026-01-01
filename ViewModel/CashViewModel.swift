//
//  CashViewModel.swift
//
//  Created by Anna on 26.12.25.
//

import Foundation

@MainActor
final class CashViewModel: ObservableObject {
    @Published var operations: [CashOperation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: any CashService

    init(service: any CashService) {
        self.service = service
    }

    /// Загружает операции; использует локальный кеш если он свежий.
    func load() async {
        await fetch(forceRefresh: false)
    }

    /// Принудительно обновляет данные с API (для pull-to-refresh).
    func refresh() async {
        await fetch(forceRefresh: true)
    }

    private func fetch(forceRefresh: Bool) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            operations = try await service.fetchOperations(forceRefresh: forceRefresh)
        } catch let error as APIError {
            if case .unauthorized = error {
                NotificationCenter.default.post(name: .unauthorized, object: nil)
            }
            errorMessage = error.errorDescription
            print(String(format: String(localized: "cash.load.error.format"), error.localizedDescription))
        } catch {
            errorMessage = error.localizedDescription
            print(String(format: String(localized: "common.unknownError.format"), String(describing: error)))
        }
    }
}
