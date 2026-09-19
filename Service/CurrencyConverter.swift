//
//  CurrencyConverter.swift
//  InvestPortfolio
//
//  Converts amounts into a user-chosen base currency using manually entered rates.
//  There is no network layer, so rates cannot be fetched — the user enters them in Settings.
//

import Foundation

// MARK: - Converter

struct CurrencyConverter: Equatable {
    /// Currency every total is expressed in.
    let base: DepositCurrency

    /// How many units of `base` one unit of the key currency is worth.
    /// `base` itself is never stored here — it is always 1.0.
    let rates: [DepositCurrency: Double]

    init(base: DepositCurrency, rates: [DepositCurrency: Double]) {
        self.base = base
        self.rates = rates
    }

    /// Returns `nil` when no usable rate exists, so callers can surface the gap
    /// instead of silently under-reporting a total.
    func convert(_ amount: Double, from currency: DepositCurrency) -> Double? {
        if currency == base { return amount }
        guard let rate = rates[currency], rate > 0 else { return nil }
        return amount * rate
    }

    /// Subset of `currencies` that cannot be converted, sorted for stable display.
    func missingRates(for currencies: [DepositCurrency]) -> [DepositCurrency] {
        let missing = currencies.filter { currency in
            guard currency != base else { return false }
            guard let rate = rates[currency] else { return true }
            return rate <= 0
        }
        return Array(Set(missing)).sorted { $0.rawValue < $1.rawValue }
    }
}

// MARK: - Persistence

/// Namespace for the AppStorage keys backing the converter, plus rate map encoding.
/// Rates live in AppStorage rather than SwiftData — they are a user preference, not domain data.
enum CurrencySettings {
    static let baseCurrencyKey = "Settings_BaseCurrency"
    static let ratesKey = "Settings_ExchangeRates"

    static let defaultBaseCurrency: DepositCurrency = .RUB
    static let defaultRatesJSON = "{}"

    static func decodeRates(_ json: String) -> [DepositCurrency: Double] {
        guard let data = json.data(using: .utf8),
              let raw = try? JSONDecoder().decode([String: Double].self, from: data)
        else { return [:] }

        var result: [DepositCurrency: Double] = [:]
        for (key, value) in raw {
            guard let currency = DepositCurrency(rawValue: key) else { continue }
            result[currency] = value
        }
        return result
    }

    static func encodeRates(_ rates: [DepositCurrency: Double]) -> String {
        var raw: [String: Double] = [:]
        for (currency, value) in rates {
            raw[currency.rawValue] = value
        }
        guard let data = try? JSONEncoder().encode(raw),
              let json = String(data: data, encoding: .utf8)
        else { return defaultRatesJSON }
        return json
    }

    static func converter(baseRaw: String, ratesJSON: String) -> CurrencyConverter {
        CurrencyConverter(
            base: DepositCurrency(rawValue: baseRaw) ?? defaultBaseCurrency,
            rates: decodeRates(ratesJSON)
        )
    }
}
