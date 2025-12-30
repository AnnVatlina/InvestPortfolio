//
//  RootView.swift
//  InvestPortfolio
//
//  Created by Anna on 30.12.25.
//

import SwiftUI

struct RootView: View {
    @State private var isAuthorized: Bool = (KeychainService.loadToken() != nil)

    var body: some View {
        MainTabView(
            isAuthorized: isAuthorized,
            onAuthorized: {
                isAuthorized = true
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: .unauthorized)) { _ in
            APIClient.shared.logout()
            isAuthorized = false
        }
        .onAppear {
            isAuthorized = (KeychainService.loadToken() != nil)
        }
    }
}
