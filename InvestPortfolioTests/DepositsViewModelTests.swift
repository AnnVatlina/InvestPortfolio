//
//  DepositsViewModelTests.swift
//  InvestPortfolioTests
//
//  Tests for DepositsViewModel using protocol-based mocks.
//  Verifies API-first cache upsert behaviour.
//

import Testing
import Foundation
@testable import InvestPortfolio

// MARK: - Mock API

final class MockDepositsAPI: DepositsAPIProtocol, @unchecked Sendable {
    var stubbedDeposits: [DepositResponse] = []
    var stubbedError: Error? = nil

    var createCalled = false
    var updateCalled = false
    var deleteCalled = false
    var lastDeletedId: UUID? = nil

    func getDeposits() async throws -> [DepositResponse] {
        if let error = stubbedError { throw error }
        return stubbedDeposits
    }

    func createDeposit(_ body: DepositCreate) async throws -> DepositResponse {
        if let error = stubbedError { throw error }
        createCalled = true
        return stubbedDeposits.first ?? makeResponse()
    }

    func updateDeposit(id: UUID, _ body: DepositUpdate) async throws -> DepositResponse {
        if let error = stubbedError { throw error }
        updateCalled = true
        return stubbedDeposits.first ?? makeResponse()
    }

    func deleteDeposit(id: UUID) async throws {
        if let error = stubbedError { throw error }
        deleteCalled = true
        lastDeletedId = id
    }

    private func makeResponse() -> DepositResponse {
        stubbedDeposits.first ?? DepositResponse(
            id: UUID(), title: "Test", bankName: nil,
            amount: "1000", currency: "RUB",
            openDate: Date(), closeDate: nil,
            annualRate: "5.0", interestType: nil,
            compoundFrequency: nil, incomeToDate: nil,
            daysElapsed: nil, createdAt: Date()
        )
    }
}

// MARK: - Helpers

private func makeResponse(
    id: UUID = UUID(),
    title: String = "Deposit",
    bankName: String? = nil,
    amount: String = "100000",
    currency: String = "RUB",
    annualRate: String = "10.0"
) -> DepositResponse {
    DepositResponse(
        id: id, title: title, bankName: bankName,
        amount: amount, currency: currency,
        openDate: Date(), closeDate: nil,
        annualRate: annualRate, interestType: nil,
        compoundFrequency: nil, incomeToDate: nil,
        daysElapsed: nil, createdAt: Date()
    )
}

@MainActor
private func makeVM(api: MockDepositsAPI) -> DepositsViewModel {
    DepositsViewModel(
        service: DefaultDepositsService(
            repository: InMemoryDepositsRepository()
        ),
        api: api
    )
}

// MARK: - Suite

@Suite("DepositsViewModel — API-first cache")
@MainActor
struct DepositsViewModelTests {

    // MARK: load

    @Test("API returns deposits → cache is populated")
    func loadPopulatesCache() async throws {
        let api = MockDepositsAPI()
        api.stubbedDeposits = [makeResponse(title: "Сбербанк")]
        let vm = makeVM(api: api)

        await vm.load()

        #expect(vm.deposits.count == 1)
        #expect(vm.deposits[0].title == "Сбербанк")
        #expect(vm.errorMessage == nil)
    }

    @Test("API returns multiple deposits → all cached")
    func loadCachesAll() async throws {
        let api = MockDepositsAPI()
        api.stubbedDeposits = [makeResponse(title: "A"), makeResponse(title: "B")]
        let vm = makeVM(api: api)

        await vm.load()

        #expect(vm.deposits.count == 2)
    }

    @Test("API error → existing cache preserved, error shown if cache empty")
    func apiErrorPreservesCache() async throws {
        let api = MockDepositsAPI()
        api.stubbedDeposits = [makeResponse(title: "Cached")]
        let vm = makeVM(api: api)
        // Prime the cache
        await vm.load()
        #expect(vm.deposits.count == 1)

        // Now simulate error
        api.stubbedError = APIError.networkOffline
        await vm.load()

        // Cache still visible, no crash
        #expect(vm.deposits.count == 1)
    }

    @Test("Upsert: same serverId → updates existing record not duplicates")
    func upsertUpdatesSameRecord() async throws {
        let serverId = UUID()
        let api = MockDepositsAPI()
        api.stubbedDeposits = [makeResponse(id: serverId, title: "Original")]
        let vm = makeVM(api: api)
        await vm.load()
        #expect(vm.deposits.count == 1)

        // Update with same serverId
        api.stubbedDeposits = [makeResponse(id: serverId, title: "Updated")]
        await vm.load()

        #expect(vm.deposits.count == 1)
        #expect(vm.deposits[0].title == "Updated")
    }

    // MARK: create

    @Test("Create deposit calls API then upserts into cache")
    func createCallsAPIAndUpdatesCache() async throws {
        let serverId = UUID()
        let api = MockDepositsAPI()
        api.stubbedDeposits = [makeResponse(id: serverId, title: "New")]
        let vm = makeVM(api: api)

        await vm.addDeposit(
            title: "New", bankName: "", amount: 100_000,
            currency: .RUB, openDate: Date(), closeDate: nil,
            annualInterestRate: 10
        )

        #expect(api.createCalled)
        #expect(vm.deposits.isEmpty == false)
    }

    @Test("Create with empty title → shows error, API not called")
    func createEmptyTitleShowsError() async throws {
        let api = MockDepositsAPI()
        let vm = makeVM(api: api)

        await vm.addDeposit(
            title: "  ", bankName: "", amount: 100,
            currency: .RUB, openDate: Date(), closeDate: nil,
            annualInterestRate: 5
        )

        #expect(!api.createCalled)
        #expect(vm.errorMessage != nil)
    }

    // MARK: delete

    @Test("Delete deposit calls API then removes from cache")
    func deleteCallsAPIAndRemovesFromCache() async throws {
        let serverId = UUID()
        let api = MockDepositsAPI()
        api.stubbedDeposits = [makeResponse(id: serverId, title: "ToDelete")]
        let vm = makeVM(api: api)
        await vm.load()
        #expect(vm.deposits.count == 1)

        let deposit = vm.deposits[0]
        // Clear remote list so reload returns empty
        api.stubbedDeposits = []
        await vm.deleteDeposit(deposit)

        #expect(api.deleteCalled)
        #expect(api.lastDeletedId == serverId)
        #expect(vm.deposits.isEmpty)
    }

    @Test("Delete API error → cache preserved, operationError shown")
    func deleteAPIErrorPreservesCache() async throws {
        let serverId = UUID()
        let api = MockDepositsAPI()
        api.stubbedDeposits = [makeResponse(id: serverId, title: "Keep")]
        let vm = makeVM(api: api)
        await vm.load()

        api.stubbedError = APIError.networkOffline
        let deposit = vm.deposits[0]
        await vm.deleteDeposit(deposit)

        #expect(vm.operationError != nil)
    }
}
