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

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Service Factories

    func makeDepositsService() -> any DepositsService {
        DefaultDepositsService(
            repository: SwiftDataDepositsRepository(modelContainer: modelContainer)
        )
    }

    func makePortfolioService() -> any PortfolioService {
        DefaultPortfolioService(
            repository: SwiftDataPortfolioRepository(modelContainer: modelContainer)
        )
    }

    func makeCashService() -> any CashService {
        DefaultCashService(
            repository: SwiftDataCashOperationsRepository(modelContainer: modelContainer)
        )
    }

    func makeSubscriptionsService() -> any SubscriptionsService {
        DefaultSubscriptionsService(
            repository: SwiftDataSubscriptionsRepository(modelContainer: modelContainer)
        )
    }

    // MARK: - Preview

    /// Изолированный контейнер для SwiftUI Preview и тестов.
    /// Использует in-memory хранилище — данные не персистируются.
    static let preview: DIContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Deposit.self,
                CashOperation.self,
                PortfolioPosition.self,
                Settings.self,
                Subscription.self,
            configurations: config
        )
        return DIContainer(modelContainer: container)
    }()
}
