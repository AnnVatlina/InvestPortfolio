//
//  InvestPortfolioApp.swift
//  
//
//  Created by Anna on 26.12.25.
//

import SwiftUI

@main
struct InvestPortfolioApp: App {
    var body: some Scene {
        WindowGroup {
            if KeychainService.loadToken() == nil {
                AuthView()
            } else {
                MainTabView()
            }
        }
    }
}
