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
}
