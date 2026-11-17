//
//  RootView.swift
//  InvestPortfolio
//
//  Created by Anna on 30.12.25.
//

import SwiftUI

struct RootView: View {
    @AppStorage("App_HasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(StoreRecovery.noticeKey) private var recoveryNoticeRaw: String = ""

    private var recoveryNotice: StoreRecovery.Notice? {
        StoreRecovery.Notice(rawValue: recoveryNoticeRaw)
    }

    private var recoveryMessage: String {
        switch recoveryNotice {
        case .backedUp(let fileName):
            return String(format: LanguageBundle.string("store.recovery.backedUp.format"), fileName)
        case .unavailable:
            return LanguageBundle.string("store.recovery.unavailable")
        case nil:
            return ""
        }
    }

    var body: some View {
        MainTabView()
            .fullScreenCover(isPresented: .constant(!hasCompletedOnboarding)) {
                OnboardingView()
            }
            .alert("store.recovery.title", isPresented: Binding(
                get: { recoveryNotice != nil },
                set: { if !$0 { recoveryNoticeRaw = "" } }
            )) {
                Button("common.ok") { recoveryNoticeRaw = "" }
            } message: {
                Text(recoveryMessage)
            }
    }
}
