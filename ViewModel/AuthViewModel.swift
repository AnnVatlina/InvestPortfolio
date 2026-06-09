//
//  AuthViewModel.swift
//  InvestPortfolio
//
//  Handles Rentivo app-level authentication: login, register, logout.
//  isAuthorized drives top-level routing in InvestPortfolioApp.
//

import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var isAuthorized: Bool
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authAPI: any AuthAPIProtocol
    private let tokenStorage: TokenStorage

    init(
        authAPI: any AuthAPIProtocol = AuthAPI(),
        tokenStorage: TokenStorage = .shared
    ) {
        self.authAPI = authAPI
        self.tokenStorage = tokenStorage
        self.isAuthorized = tokenStorage.hasTokens

        NotificationCenter.default.addObserver(
            forName: .unauthorized,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleUnauthorized()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .unauthorized, object: nil)
    }

    // MARK: - Auth actions

    func login() async {
        guard validate(requireConfirm: false) else { return }
        await perform {
            let token = try await self.authAPI.login(email: self.email, password: self.password)
            self.tokenStorage.save(token)
            self.isAuthorized = true
        }
    }

    func register() async {
        guard validate(requireConfirm: true) else { return }
        await perform {
            let token = try await self.authAPI.register(email: self.email, password: self.password)
            self.tokenStorage.save(token)
            self.isAuthorized = true
        }
    }

    func logout() {
        tokenStorage.clearTokens()
        isAuthorized = false
        email = ""
        password = ""
        confirmPassword = ""
        errorMessage = nil
    }

    func handleUnauthorized() {
        tokenStorage.clearTokens()
        isAuthorized = false
        errorMessage = APIError.unauthorized.errorDescription
    }

    // MARK: - Private

    private func validate(requireConfirm: Bool) -> Bool {
        errorMessage = nil
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = String(localized: "auth.error.emptyEmail")
            return false
        }
        guard !password.isEmpty else {
            errorMessage = String(localized: "auth.error.emptyPassword")
            return false
        }
        if requireConfirm, password != confirmPassword {
            errorMessage = String(localized: "auth.error.passwordMismatch")
            return false
        }
        return true
    }

    private func perform(_ action: @escaping () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await action()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
