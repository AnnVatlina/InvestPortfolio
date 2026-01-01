//
//  InvestPortfolioApp.swift
//  
//
//  Created by Anna on 26.12.25.
//

import SwiftUI

@main
struct InvestPortfolioApp: App {
    @AppStorage("App_LocaleIdentifier") private var localeIdentifier: String = Locale.current.identifier
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, Locale(identifier: localeIdentifier))
        }
    }
}
