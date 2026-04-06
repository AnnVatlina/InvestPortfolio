//
//  PortfolioService.swift
//  InvestPortfolio
//
//  Created by Anna on 04.04.26.
//

import Foundation

protocol PortfolioService {
    func fetchPositions(sid: String, forceRefresh: Bool) async throws -> [PortfolioPosition]
    func fetchAll() async throws -> [PortfolioPosition]
}

final class DefaultPortfolioService: PortfolioService {
    private let repository: PortfolioRepository
    private let apiClient: APIClient
    private let maxCacheAge: TimeInterval

    init(
        repository: PortfolioRepository,
        apiClient: APIClient = .shared,
        maxCacheAge: TimeInterval = 300 // 5 минут
    ) {
        self.repository = repository
        self.apiClient = apiClient
        self.maxCacheAge = maxCacheAge
    }

    func fetchAll() async throws -> [PortfolioPosition] {
        try await repository.fetchAll()
    }

    func fetchPositions(sid: String, forceRefresh: Bool = false) async throws -> [PortfolioPosition] {
        // Если кеш свежий — возвращаем из SwiftData
        if !forceRefresh, let age = try await repository.cacheAge(), age < maxCacheAge {
            return try await repository.fetchAll()
        }

        // Загружаем с API
        let dtos = try await apiClient.fetchPortfolio(sid: sid)

        // Маппим DTO -> @Model
        let now = Date()
        let models = dtos.map { dto in
            PortfolioPosition(
                ticker: dto.ticker,
                quantity: dto.quantity,
                avgPrice: dto.avgPrice,
                currentPrice: dto.currentPrice,
                profit: dto.profit,
                name: dto.name,
                currency: dto.currency,
                fetchedAt: now
            )
        }

        // Сохраняем в SwiftData
        try await repository.upsertAll(from: models)
        return models
    }
}
