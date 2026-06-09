//
//  TokenStorageTests.swift
//  InvestPortfolioTests
//
//  Unit tests for TokenStorage (Keychain-backed).
//  Uses unique key prefixes per test suite to avoid cross-test collisions.
//

import Testing
import Foundation
@testable import InvestPortfolio

// MARK: - Helpers

private func makeStorage() -> TokenStorage {
    // Unique keys per test run so parallel tests don't collide
    let suffix = UUID().uuidString
    return TokenStorage(
        accessKey: "test.access.\(suffix)",
        refreshKey: "test.refresh.\(suffix)"
    )
}

private let sampleToken = AuthToken(
    accessToken: "eyJ.access.token",
    refreshToken: "eyJ.refresh.token"
)

// MARK: - Suite

@Suite("TokenStorage")
struct TokenStorageTests {

    // MARK: save & retrieve

    @Test("Store and retrieve access token")
    func storeAndRetrieveAccessToken() {
        let storage = makeStorage()
        storage.save(sampleToken)
        #expect(storage.loadAccessToken() == sampleToken.accessToken)
    }

    @Test("Store and retrieve refresh token")
    func storeAndRetrieveRefreshToken() {
        let storage = makeStorage()
        storage.save(sampleToken)
        #expect(storage.loadRefreshToken() == sampleToken.refreshToken)
    }

    // MARK: hasTokens

    @Test("hasTokens is false when nothing stored")
    func hasTokensFalseWhenEmpty() {
        let storage = makeStorage()
        #expect(storage.hasTokens == false)
    }

    @Test("hasTokens is true after save")
    func hasTokensTrueAfterSave() {
        let storage = makeStorage()
        storage.save(sampleToken)
        #expect(storage.hasTokens == true)
    }

    // MARK: clearTokens

    @Test("Delete tokens on logout")
    func deleteTokensOnLogout() {
        let storage = makeStorage()
        storage.save(sampleToken)
        storage.clearTokens()
        #expect(storage.loadAccessToken() == nil)
        #expect(storage.loadRefreshToken() == nil)
        #expect(storage.hasTokens == false)
    }

    // MARK: overwrite

    @Test("Overwrite existing tokens")
    func overwriteExistingToken() {
        let storage = makeStorage()
        storage.save(sampleToken)

        let newToken = AuthToken(accessToken: "new.access", refreshToken: "new.refresh")
        storage.save(newToken)

        #expect(storage.loadAccessToken() == "new.access")
        #expect(storage.loadRefreshToken() == "new.refresh")
    }

    // MARK: isolation

    @Test("Two separate storages are independent")
    func twoStoragesAreIndependent() {
        let a = makeStorage()
        let b = makeStorage()

        a.save(sampleToken)
        // b should not see a's tokens
        #expect(b.loadAccessToken() == nil)
    }
}
