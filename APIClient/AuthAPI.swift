//
//  AuthAPI.swift
//  InvestPortfolio
//
//  Rentivo auth endpoints: register / login / refresh.
//  Uses RentivoAPIClient.publicPost (no Bearer header needed).
//

import Foundation

// MARK: - Protocol (for testing)

protocol AuthAPIProtocol: Sendable {
    func register(email: String, password: String) async throws -> AuthToken
    func login(email: String, password: String) async throws -> AuthToken
    func refresh(token: String) async throws -> AuthToken
}

// MARK: - Request / Response DTOs

private struct RegisterBody: Encodable {
    let email: String
    let password: String
}

private struct LoginBody: Encodable {
    let email: String
    let password: String
}

private struct RefreshBody: Encodable {
    let refreshToken: String
}

private struct AuthResponseDTO: Decodable {
    let accessToken: String
    let refreshToken: String
}

// MARK: - Implementation

final class AuthAPI: AuthAPIProtocol {

    private let client: RentivoAPIClient

    init(client: RentivoAPIClient = .shared) {
        self.client = client
    }

    func register(email: String, password: String) async throws -> AuthToken {
        let dto: AuthResponseDTO = try await client.publicPost(
            path: "/auth/register",
            body: RegisterBody(email: email, password: password)
        )
        return AuthToken(accessToken: dto.accessToken, refreshToken: dto.refreshToken)
    }

    func login(email: String, password: String) async throws -> AuthToken {
        let dto: AuthResponseDTO = try await client.publicPost(
            path: "/auth/login",
            body: LoginBody(email: email, password: password)
        )
        return AuthToken(accessToken: dto.accessToken, refreshToken: dto.refreshToken)
    }

    func refresh(token: String) async throws -> AuthToken {
        let dto: AuthResponseDTO = try await client.publicPost(
            path: "/auth/refresh",
            body: RefreshBody(refreshToken: token)
        )
        return AuthToken(accessToken: dto.accessToken, refreshToken: dto.refreshToken)
    }
}
