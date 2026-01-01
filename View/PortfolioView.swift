//
//  PortfolioView.swift
//  
//
//  Created by Anna on 26.12.25.
//

import SwiftUI

struct PortfolioView: View {
    @StateObject private var vm: PortfolioViewModel
    @State private var sid: String = ""

    init(container: DIContainer) {
        _vm = StateObject(wrappedValue: PortfolioViewModel(
            service: container.makePortfolioService()
        ))
    }

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView(String(localized: "portfolio.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(String(localized: "common.error"))
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button(String(localized: "common.retry")) {
                        Task { await vm.load(sid: sid) }
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
                    Text(String(localized: "portfolio.empty"))
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
                            Text(String(format: String(localized: "portfolio.quantity.format"), position.quantity))
                            Spacer()
                            Text(String(format: String(localized: "portfolio.profit.format"), position.profit))
                                .foregroundColor(position.profit >= 0 ? .green : .red)
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .task { await vm.load(sid: sid) }
        .refreshable { await vm.refresh(sid: sid) }
        .navigationTitle(String(localized: "home.portfolio.title"))
    }
}
