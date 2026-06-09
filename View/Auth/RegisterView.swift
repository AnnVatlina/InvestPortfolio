//
//  RegisterView.swift
//  InvestPortfolio
//
//  New account registration screen (Rentivo).
//

import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var vm: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // MARK: Header
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.brand)

                    Text(String(localized: "auth.register.title"))
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding(.top, 32)

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
                        .textContentType(.newPassword)

                    SecureField(String(localized: "auth.field.confirmPassword"), text: $vm.confirmPassword)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)

                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await vm.register() }
                    } label: {
                        Group {
                            if vm.isLoading {
                                ProgressView()
                            } else {
                                Text(String(localized: "auth.register.action"))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(vm.isLoading || vm.email.isEmpty || vm.password.isEmpty || vm.confirmPassword.isEmpty)
                }
                .padding(.horizontal, 24)

                // MARK: Switch to Login
                Button {
                    vm.errorMessage = nil
                    dismiss()
                } label: {
                    Text(String(localized: "auth.switch.toLogin"))
                        .font(.subheadline)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(String(localized: "auth.register.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
