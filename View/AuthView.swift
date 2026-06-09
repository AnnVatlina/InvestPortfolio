//
//  AuthView.swift
//  InvestPortfolio
//
//  Portfolio-tab auth card: prompts Rentivo login when the portfolio
//  section requires an authenticated session.
//

import SwiftUI

struct AuthView: View {
    @StateObject private var vm = AuthViewModel()

    var onAuthorized: (() -> Void)?
    var onOpenDeposits: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Text(String(localized: "auth.login.title"))
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(spacing: 16) {
                TextField(String(localized: "auth.field.email"), text: $vm.email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                SecureField(String(localized: "auth.field.password"), text: $vm.password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button(action: {
                    Task {
                        await vm.login()
                        if vm.isAuthorized {
                            onAuthorized?()
                        }
                    }
                }) {
                    if vm.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text(String(localized: "auth.login.action"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isLoading || vm.email.isEmpty || vm.password.isEmpty)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onReceive(NotificationCenter.default.publisher(for: .unauthorized)) { _ in
            vm.handleUnauthorized()
        }
    }
}
