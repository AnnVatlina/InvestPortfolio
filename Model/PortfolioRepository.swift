//
//  PortfolioRepository.swift
//  InvestPortfolio
//
//  Created by Anna on 04.04.26.
//

import Foundation
import SwiftData

protocol PortfolioRepository {
    func fetchAll() async throws -> [PortfolioPosition]
    func upsertAll(from positions: [PortfolioPosition]) async throws
    func cacheAge() async throws -> TimeInterval?
}

@ModelActor
actor SwiftDataPortfolioRepository: PortfolioRepository {
    func fetchAll() async throws -> [PortfolioPosition] {
        let descriptor = FetchDescriptor<PortfolioPosition>(
            sortBy: [SortDescriptor(\.ticker)]
        )
        return try modelContext.fetch(descriptor)
    }

    func upsertAll(from positions: [PortfolioPosition]) async throws {
        try modelContext.delete(model: PortfolioPosition.self)
        for pos in positions {
            modelContext.insert(pos)
        }
        try modelContext.save()
    }

    func cacheAge() async throws -> TimeInterval? {
        var descriptor = FetchDescriptor<PortfolioPosition>(
            sortBy: [SortDescriptor(\.fetchedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let latest = try modelContext.fetch(descriptor).first else { return nil }
        return Date().timeIntervalSince(latest.fetchedAt)
    }
}
