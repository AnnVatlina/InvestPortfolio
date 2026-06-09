//
//  RootView.swift
//  InvestPortfolio
//
//  Created by Anna on 30.12.25.
//

import SwiftUI

struct RootView: View {
    @AppStorage("App_HasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        MainTabView()
            .fullScreenCover(isPresented: .constant(!hasCompletedOnboarding)) {
                OnboardingView()
            }
    }
}
