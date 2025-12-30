//
//  DepositsView.swift
//
//  Created by Anna on 30.12.25.
//

import SwiftUI

struct DepositsView: View {
    @StateObject private var vm = DepositsViewModel()

    // Поля для добавления нового вклада
    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var currency: DepositCurrency = .RUB
    @State private var openDate: Date = Date()
    @State private var hasCloseDate: Bool = false
    @State private var closeDate: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var interestText: String = "" // дробная ставка, вводим как текст

    var body: some View {
        VStack(spacing: 12) {
            // Форма добавления
            VStack(alignment: .leading, spacing: 10) {
                Text("Добавить вклад")
                    .font(.headline)

                TextField("Название", text: $title)
                    .textFieldStyle(.roundedBorder)

                TextField("Сумма", text: $amountText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)

                Picker("Валюта", selection: $currency) {
                    ForEach(DepositCurrency.allCases) { curr in
                        Text(curr.rawValue).tag(curr)
                    }
                }
                .pickerStyle(.segmented)

                DatePicker("Дата открытия", selection: $openDate, displayedComponents: .date)

                Toggle("Указать дату закрытия", isOn: $hasCloseDate.animation())

                if hasCloseDate {
                    DatePicker("Дата закрытия", selection: $closeDate, in: openDate..., displayedComponents: .date)
                }

                HStack {
                    TextField("Годовая ставка, %", text: $interestText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                    Text("%")
                        .foregroundColor(.secondary)
                }

                Button {
                    Task {
                        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
                        let interest = Double(interestText.replacingOccurrences(of: ",", with: ".")) ?? 0
                        let close = hasCloseDate ? closeDate : nil
                        await vm.addDeposit(
                            title: title,
                            amount: amount,
                            currency: currency,
                            openDate: openDate,
                            closeDate: close,
                            annualInterestRate: interest
                        )
                        if vm.errorMessage == nil {
                            title = ""
                            amountText = ""
                            interestText = ""
                            // валюту и даты оставляем выбранными
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
                        let summary = vm.incomeSummary(for: deposit)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(deposit.title)
                                .font(.headline)

                            HStack {
                                Text("\(deposit.amount, specifier: "%.2f") \(deposit.currency.rawValue)")
                                Spacer()
                                Text("Ставка: \(deposit.annualInterestRate, specifier: "%.2f")%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 12) {
                                Text("Открыт: \(deposit.openDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let close = deposit.closeDate {
                                    Text("Закрытие: \(close.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Доход на сегодня: \(summary.incomeToDate, specifier: "%.2f") \(deposit.currency.rawValue)")
                                    .font(.subheadline)
                                    .foregroundColor(summary.incomeToDate >= 0 ? .green : .red)

                                if let forecast = summary.forecastIncomeToCloseDate {
                                    Text("Прогноз к закрытию: \(forecast, specifier: "%.2f") \(deposit.currency.rawValue)")
                                        .font(.subheadline)
                                        .foregroundColor(forecast >= 0 ? .green : .red)
                                }
                            }
                            .padding(.top, 2)
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
    }
}

