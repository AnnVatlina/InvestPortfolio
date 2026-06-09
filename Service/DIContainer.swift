//
//  DIContainer.swift
//  InvestPortfolio
//
//  Центральный контейнер зависимостей.
//  Единственное место, где знают о конкретных реализациях репозиториев.
//  ViewModels получают только протоколы сервисов — не знают о SwiftData/URLSession.
//

import Foundation
import SwiftData

final class DIContainer: ObservableObject {

    // MARK: - Core

    let modelContainer: ModelContainer
    let tokenStorage: TokenStorage
    let rentivoClient: RentivoAPIClient

    init(
        modelContainer: ModelContainer,
        tokenStorage: TokenStorage = .shared,
        rentivoClient: RentivoAPIClient = .shared
    ) {
        self.modelContainer = modelContainer
        self.tokenStorage = tokenStorage
        self.rentivoClient = rentivoClient
    }

    // MARK: - Service Factories

    func makeDepositsService() -> any DepositsService {
        DefaultDepositsService(
            repository: SwiftDataDepositsRepository(modelContainer: modelContainer)
        )
    }

    func makeDepositsAPI() -> any DepositsAPIProtocol {
        DepositsAPI(client: rentivoClient)
    }

    func makeSubscriptionsService() -> any SubscriptionsService {
        DefaultSubscriptionsService(
            repository: SwiftDataSubscriptionsRepository(modelContainer: modelContainer)
        )
    }

    func makeSubscriptionsAPI() -> any SubscriptionsAPIProtocol {
        SubscriptionsAPI(client: rentivoClient)
    }

    // MARK: - Reset

    /// Deletes all user-created data from the server and then clears the local cache.
    /// Server deletions are best-effort — the local reset always proceeds even if the network is unavailable.
    func resetAllData() async throws {
        let depositsAPI = makeDepositsAPI()
        let subscriptionsAPI = makeSubscriptionsAPI()

        let context = ModelContext(modelContainer)
        let deposits = try context.fetch(FetchDescriptor<Deposit>())
        let subscriptions = try context.fetch(FetchDescriptor<Subscription>())

        // Extract server IDs before entering the task group (SwiftData models are not Sendable)
        let depositServerIds = deposits.compactMap(\.serverId)
        let subscriptionServerIds = subscriptions.compactMap(\.serverId)

        await withTaskGroup(of: Void.self) { group in
            for id in depositServerIds {
                group.addTask { try? await depositsAPI.deleteDeposit(id: id) }
            }
            for id in subscriptionServerIds {
                group.addTask { try? await subscriptionsAPI.deleteSubscription(id: id) }
            }
        }

        deposits.forEach { context.delete($0) }
        subscriptions.forEach { context.delete($0) }
        try context.save()
    }

    // MARK: - Preview

    /// Изолированный контейнер для SwiftUI Preview и тестов.
    /// Использует in-memory хранилище — данные не персистируются.
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
