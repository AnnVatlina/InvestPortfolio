//
//  PortfolioViewModel.swift
//  
//
//  Created by Anna on 26.12.25.
//

import Foundation

@MainActor
final class PortfolioViewModel: ObservableObject {
    @Published var positions: [PortfolioPosition] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(sid: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            positions = try await APIClient.shared.fetchPortfolio(sid: sid)
        } catch let error as APIError {
            errorMessage = error.errorDescription
            print("Ошибка загрузки портфеля: \(error.localizedDescription)")
        } catch {
            errorMessage = error.localizedDescription
            print("Неизвестная ошибка: \(error)")
        }
    }
}
