//
//  PortfolioViewModel.swift
//
//  Created by Anna on 26.12.25.
//

import Foundation

@MainActor
final class PortfolioViewModel: ObservableObject {
    @Published var positions: [PortfolioPosition] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: any PortfolioService

    init(service: any PortfolioService) {
        self.service = service
    }

    /// Загружает позиции; использует локальный кеш если он свежий.
    func load(sid: String) async {
        await fetch(sid: sid, forceRefresh: false)
    }

    /// Принудительно обновляет данные с API (для pull-to-refresh).
    func refresh(sid: String) async {
        await fetch(sid: sid, forceRefresh: true)
    }

    private func fetch(sid: String, forceRefresh: Bool) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            positions = try await service.fetchPositions(sid: sid, forceRefresh: forceRefresh)
        } catch let error as APIError {
            if case .unauthorized = error {
                NotificationCenter.default.post(name: .unauthorized, object: nil)
            }
            errorMessage = error.errorDescription
            print("Ошибка загрузки портфеля: \(error.localizedDescription)")
        } catch {
            errorMessage = error.localizedDescription
            print("Неизвестная ошибка: \(error)")
        }
    }
}
