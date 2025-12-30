//
//  AuthPage.swift
//  InvestPortfolio
//
//  Created by Anna on 30.12.25.
//

import SwiftUI

struct AuthPage: View {
    var onAuthorized: (() -> Void)?

    var body: some View {
        // Оборачиваем существующий AuthView в навигационную страницу
        AuthView(
            onAuthorized: {
                onAuthorized?()
            },
            onOpenDeposits: { /* не используется на странице авторизации */ },
            onOpenSettings: { /* не используется на странице авторизации */ }
        )
        .navigationBarTitleDisplayMode(.inline)
    }
}

