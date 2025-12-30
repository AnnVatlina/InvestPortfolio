//
//  DepositsView.swift
//
//  Created by Anna on 30.12.25.
//

import SwiftUI

struct DepositsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = DepositsViewModel()

    // Поля для добавления нового вклада
    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var currency: String = "RUB"

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                // Форма добавления
                VStack(alignment: .leading, spacing: 8) {
                    Text("Добавить вклад")
                        .font(.headline)

                    TextField("Название", text: $title)
                        .textFieldStyle(.roundedBorder)

                    TextField("Сумма", text: $amountText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)

                    TextField("Валюта (например, RUB)", text: $currency)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        Task {
                            let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
                            await vm.addDeposit(title: title, amount: amount, currency: currency)
                            if vm.errorMessage == nil {
                                title = ""
                                amountText = ""
                                // валюту не очищаем для удобства
                            }
                        }
                    } label: {
                        Text("Добавить")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                // Список вкладов
                Group {
                    if vm.isLoading {
                        ProgressView("Загрузка вкладов...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = vm.errorMessage {
                        VStack(spacing: 8) {
                            Text("Ошибка")
                                .font(.headline)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            Button("Повторить") {
                                Task { await vm.load() }
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if vm.deposits.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "banknote")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("Пока нет вкладов")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(vm.deposits) { deposit in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(deposit.title)
                                    .font(.headline)
                                HStack {
                                    Text("\(deposit.amount, specifier: "%.2f") \(deposit.currency)")
                                    Spacer()
                                    Text(deposit.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listStyle(.plain)
                    }
                }
                .task { await vm.load() }
                .refreshable { await vm.load() }
            }
            .navigationTitle("Вклады")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

