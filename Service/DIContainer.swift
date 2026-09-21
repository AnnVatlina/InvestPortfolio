//
//  DIContainer.swift
//  InvestPortfolio
//
//  Central dependency container.
//  The only place that knows about concrete repository implementations.
//  ViewModels only receive service protocols — they don't know about SwiftData.
//

import Foundation
import SwiftData

final class DIContainer: ObservableObject {

    // MARK: - Core

    let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Service Factories

    func makeDepositsService() -> any DepositsService {
        DefaultDepositsService(
            repository: SwiftDataDepositsRepository(modelContainer: modelContainer)
        )
    }

    func makeSubscriptionsService() -> any SubscriptionsService {
        DefaultSubscriptionsService(
            repository: SwiftDataSubscriptionsRepository(modelContainer: modelContainer)
        )
    }

    // MARK: - Reset

    /// Deletes all user-created data from the local store.
    func resetAllData() async throws {
        let context = ModelContext(modelContainer)
        let deposits = try context.fetch(FetchDescriptor<Deposit>())
        let subscriptions = try context.fetch(FetchDescriptor<Subscription>())
        deposits.forEach { context.delete($0) }
        subscriptions.forEach { context.delete($0) }
        try context.save()
    }

    // MARK: - Preview

    /// Isolated container for SwiftUI previews and tests.
    /// Uses an in-memory store — data is not persisted.
    static let preview: DIContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Deposit.self,
                Settings.self,
                Subscription.self,
            configurations: config
        )
        return DIContainer(modelContainer: container)
    }()
}
