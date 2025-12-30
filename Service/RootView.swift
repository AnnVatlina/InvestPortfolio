//
//  RootView.swift
//  InvestPortfolio
//
//  Created by Anna on 30.12.25.
//

import SwiftUI

enum Route: Hashable {
    case deposits
}

struct RootView: View {
    @State private var path: [Route] = []
    @State private var isAuthorized: Bool = (KeychainService.loadToken() != nil)

    var body: some View {
        Group {
            if isAuthorized {
                // Авторизован: показываем основную часть приложения
                MainTabView()
                    .onReceive(NotificationCenter.default.publisher(for: .unauthorized)) { _ in
                        // Сброс авторизации при истечении сессии
                        APIClient.shared.logout()
                        isAuthorized = false
                        path = []
                    }
            } else {
                // Не авторизован: экран входа, обернутый в NavigationStack
                NavigationStack(path: $path) {
                    AuthView(onAuthorized: {
                        // колбэк при успешном входе
                        isAuthorized = true
                        path = []
                    }, onOpenDeposits: {
                        path.append(.deposits)
                    })
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .deposits:
                            DepositsView()
                        }
                    }
                }
            }
        }
        .onAppear {
            isAuthorized = (KeychainService.loadToken() != nil)
        }
    }
}

