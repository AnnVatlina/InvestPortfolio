//
//  CashService.swift
//  InvestPortfolio
//
//  Created by Anna on 04.04.26.
//

import Foundation

protocol CashService {
    func fetchOperations(forceRefresh: Bool) async throws -> [CashOperation]
    func fetchAll() async throws -> [CashOperation]
}

final class DefaultCashService: CashService {
    private let repository: CashOperationsRepository
    private let apiClient: APIClient
    private let maxCacheAge: TimeInterval

    init(
        repository: CashOperationsRepository,
        apiClient: APIClient = .shared,
        maxCacheAge: TimeInterval = 600 // 10 минут
    ) {
        self.repository = repository
        self.apiClient = apiClient
        self.maxCacheAge = maxCacheAge
    }

    func fetchAll() async throws -> [CashOperation] {
        try await repository.fetchAll()
    }

    func fetchOperations(forceRefresh: Bool = false) async throws -> [CashOperation] {
        // Если кеш свежий — возвращаем из SwiftData
        if !forceRefresh, let age = try await repository.cacheAge(), age < maxCacheAge {
            return try await repository.fetchAll()
        }

        // Загружаем с API
        let dtos = try await apiClient.fetchCashOperations()

        let now = Date()
        let models = dtos.map { dto in
            CashOperation(
                date: dto.date,
                type: dto.type,
                amount: dto.amount,
                currency: dto.currency,
                comment: dto.comment,
                fetchedAt: now
            )
        }

        // Сохраняем в SwiftData
        try await repository.replaceAll(with: models)
        return models
    }
}
