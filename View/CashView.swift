//
//  CashView.swift
//  
//
//  Created by Anna on 26.12.25.
//

import SwiftUI

struct CashView: View {
    @StateObject private var vm = CashViewModel()

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView("Загрузка операций...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Ошибка загрузки")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Повторить") {
                        Task {
                            await vm.load()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if vm.operations.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "dollarsign.circle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Нет операций")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(vm.operations) { op in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(op.type)
                            .font(.headline)
                        HStack {
                            Text("\(op.amount, specifier: "%.2f") \(op.currency)")
                            Spacer()
                            if !op.date.isEmpty {
                                Text(op.date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .task { await vm.load() }
        .refreshable {
            await vm.load()
        }
        .navigationTitle("Cash Operations")
    }
}
