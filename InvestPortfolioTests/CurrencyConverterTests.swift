//
//  CurrencyConverterTests.swift
//  InvestPortfolioTests
//
//  Tests for CurrencyConverter and the AppStorage-backed rate map encoding.
//

import Testing
import Foundation
@testable import InvestPortfolio

// MARK: - Helpers

private func converter(
    base: DepositCurrency = .RUB,
    rates: [DepositCurrency: Double] = [:]
) -> CurrencyConverter {
    CurrencyConverter(base: base, rates: rates)
}

// MARK: - Conversion

@Suite("CurrencyConverter — convert")
struct CurrencyConverterConvertTests {

    @Test("Base currency converts to itself unchanged")
    func baseIsIdentity() {
        let c = converter(base: .RUB, rates: [.USD: 90])
        #expect(c.convert(1234.56, from: .RUB) == 1234.56)
    }

    @Test("Base currency needs no rate even when the map is empty")
    func baseNeedsNoRate() {
        let c = converter(base: .USD, rates: [:])
        #expect(c.convert(100, from: .USD) == 100)
    }

    @Test("Known rate multiplies the amount")
    func knownRateMultiplies() throws {
        let c = converter(base: .RUB, rates: [.USD: 90])
        let result = try #require(c.convert(10, from: .USD))
        #expect(abs(result - 900) < 0.001)
    }

    @Test("Missing rate returns nil rather than zero")
    func missingRateReturnsNil() {
        let c = converter(base: .RUB, rates: [.USD: 90])
        #expect(c.convert(10, from: .EUR) == nil)
    }

    @Test("Zero rate returns nil")
    func zeroRateReturnsNil() {
        let c = converter(base: .RUB, rates: [.USD: 0])
        #expect(c.convert(10, from: .USD) == nil)
    }

    @Test("Negative rate returns nil")
    func negativeRateReturnsNil() {
        let c = converter(base: .RUB, rates: [.USD: -5])
        #expect(c.convert(10, from: .USD) == nil)
    }
}

// MARK: - Missing rates

@Suite("CurrencyConverter — missingRates")
struct CurrencyConverterMissingRatesTests {

    @Test("Base currency is never reported as missing")
    func baseNotMissing() {
        let c = converter(base: .RUB, rates: [:])
        #expect(c.missingRates(for: [.RUB]).isEmpty)
    }

    @Test("Currencies without a rate are reported, sorted by rawValue")
    func reportsUnratedSorted() {
        let c = converter(base: .RUB, rates: [.USD: 90])
        #expect(c.missingRates(for: [.USD, .GEL, .EUR]) == [.EUR, .GEL])
    }

    @Test("Non-positive rates count as missing")
    func nonPositiveCountsAsMissing() {
        let c = converter(base: .RUB, rates: [.USD: 0, .EUR: -1])
        #expect(c.missingRates(for: [.USD, .EUR]) == [.EUR, .USD])
    }

    @Test("Duplicates collapse to a single entry")
    func duplicatesCollapse() {
        let c = converter(base: .RUB, rates: [:])
        #expect(c.missingRates(for: [.USD, .USD, .USD]) == [.USD])
    }
}

// MARK: - Persistence encoding

@Suite("CurrencySettings — rate map encoding")
struct CurrencySettingsEncodingTests {

    @Test("Encode then decode round-trips the rate map")
    func roundTrips() {
        let original: [DepositCurrency: Double] = [.USD: 90.5, .EUR: 98.25]
        let decoded = CurrencySettings.decodeRates(CurrencySettings.encodeRates(original))
        #expect(decoded == original)
    }

    @Test("Empty map round-trips")
    func emptyRoundTrips() {
        let decoded = CurrencySettings.decodeRates(CurrencySettings.encodeRates([:]))
        #expect(decoded.isEmpty)
    }

    @Test("Malformed JSON decodes to an empty map instead of crashing")
    func malformedDecodesEmpty() {
        #expect(CurrencySettings.decodeRates("not json at all").isEmpty)
    }

    @Test("Unknown currency codes are dropped on decode")
    func unknownCodesDropped() {
        let decoded = CurrencySettings.decodeRates(#"{"USD": 90, "XYZ": 1.5}"#)
        #expect(decoded == [.USD: 90])
    }

    @Test("converter(baseRaw:ratesJSON:) falls back to the default base for an unknown code")
    func unknownBaseFallsBack() {
        let c = CurrencySettings.converter(baseRaw: "XYZ", ratesJSON: "{}")
        #expect(c.base == CurrencySettings.defaultBaseCurrency)
    }

    @Test("converter(baseRaw:ratesJSON:) wires up base and rates")
    func buildsConverter() {
        let c = CurrencySettings.converter(baseRaw: "USD", ratesJSON: #"{"RUB": 0.011}"#)
        #expect(c.base == .USD)
        #expect(c.rates[.RUB] == 0.011)
    }
}
