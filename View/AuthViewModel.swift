//
//  AuthViewModel.swift
//  
//
//  Created by Anna on 26.12.25.
//

import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var isAuthorized = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    init() {
        isAuthorized = (KeychainService.loadToken() != nil)
        NotificationCenter.default.addObserver(forName: .unauthorized, object: nil, queue: .main) { [weak self] _ in
            self?.handleUnauthorized()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .unauthorized, object: nil)
    }

    func login() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "Введите логин и пароль"
            return
        }
        
        do {
            try await APIClient.shared.login(username: username, password: password)
            isAuthorized = true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleUnauthorized() {
        // Сброс состояния и возврат на экран логина
        APIClient.shared.logout()
        isAuthorized = false
        errorMessage = APIError.unauthorized.errorDescription
    }
}

