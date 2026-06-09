//
//  LoginView.swift
//  InvestPortfolio
//
//  App-level Rentivo login screen.
//  Shown when no valid token is found in Keychain.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var vm: AuthViewModel
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // MARK: Header
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.brand)

                        Text(String(localized: "app.name"))
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text(String(localized: "auth.login.title"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 48)

                    // MARK: Form
                    VStack(spacing: 14) {
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
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            Task { await vm.login() }
                        } label: {
                            Group {
                                if vm.isLoading {
                                    ProgressView()
                                } else {
                                    Text(String(localized: "auth.login.action"))
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(vm.isLoading || vm.email.isEmpty || vm.password.isEmpty)
                    }
                    .padding(.horizontal, 24)

                    // MARK: Switch to Register
                    Button {
                        vm.errorMessage = nil
                        showRegister = true
                    } label: {
                        Text(String(localized: "auth.switch.toRegister"))
                            .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .navigationDestination(isPresented: $showRegister) {
                RegisterView()
            }
        }
    }
}
