//
//  PortfolioView.swift
//  
//
//  Created by Anna on 26.12.25.
//

import SwiftUI

struct PortfolioView: View {
    @StateObject private var vm = PortfolioViewModel()
    @State private var sid: String = ""
    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView("Загрузка портфеля...")
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
                            await vm.load(sid: sid)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if vm.positions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.pie")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Портфель пуст")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(vm.positions) { position in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(position.ticker)
                            .font(.headline)
                        HStack {
                            Text("Кол-во: \(position.quantity, specifier: "%.2f")")
                            Spacer()
                            Text("P/L: \(position.profit, specifier: "%.2f")")
                                .foregroundColor(position.profit >= 0 ? .green : .red)
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .task { await vm.load(sid: sid) }
        .refreshable {
            await vm.load(sid: sid  )
        }
        .navigationTitle("Portfolio")
    }
}
