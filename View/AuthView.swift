//
//  AuthView.swift
//  
//
//  Created by Anna on 26.12.25.
//

import SwiftUI

struct AuthView: View {
    @StateObject private var vm = AuthViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("Вход в Tradernet")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                TextField("Логин", text: $vm.username)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                SecureField("Пароль", text: $vm.password)
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
                    }
                }) {
                    if vm.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Войти")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isLoading || vm.username.isEmpty || vm.password.isEmpty)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .fullScreenCover(isPresented: $vm.isAuthorized) {
            MainTabView()
        }
    }
}
