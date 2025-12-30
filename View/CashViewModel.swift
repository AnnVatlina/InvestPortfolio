//
//  CashViewModel.swift
//  
//
//  Created by Anna on 26.12.25.
//

import SwiftUI

@MainActor
final class CashViewModel: ObservableObject {
    @Published var operations: [CashOperation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            operations = try await APIClient.shared.fetchCashOperations()
        } catch let error as APIError {
            switch error {
            case .unauthorized:
                // Оповещаем об истечении сессии
                NotificationCenter.default.post(name: .unauthorized, object: nil)
            default:
                break
            }
            errorMessage = error.errorDescription
            print("Ошибка загрузки операций: \(error.localizedDescription)")
        } catch {
            errorMessage = error.localizedDescription
            print("Неизвестная ошибка: \(error)")
        }
    }
}
