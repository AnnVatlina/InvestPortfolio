//
//  QuotesAPIClient.swift
//  InvestPortfolio
//
//  Клиент для получения рыночных котировок без авторизации.
//  Использует Yahoo Finance Chart API (v8) — публичный, без ключа.
//  Для продакшена рекомендуется Finnhub (finnhub.io, бесплатный ключ,
//  60 запросов/мин, официальный контракт).
//

import Foundation

// MARK: - Модель котировки

struct StockQuote {
    let symbol: String
    let currentPrice: Double
    let previousClose: Double
    /// Изменение цены в % относительно предыдущего закрытия
    var changePercent: Double {
        guard previousClose > 0 else { return 0 }
        return ((currentPrice - previousClose) / previousClose) * 100
    }
}

// MARK: - Ошибки котировок

enum QuotesError: Error, LocalizedError {
    case invalidSymbol
    case invalidURL
    case noData
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidSymbol:    return "Неверный символ инструмента"
        case .invalidURL:       return "Неверный URL запроса"
        case .noData:           return "Данные не получены"
        case .decodingError(let e): return "Ошибка разбора ответа: \(e.localizedDescription)"
        case .networkError(let e):  return "Сетевая ошибка: \(e.localizedDescription)"
        }
    }
}

// MARK: - QuotesAPIClient

final class QuotesAPIClient {
    static let shared = QuotesAPIClient()
    private init() {}

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        // Без кук и дополнительных заголовков — публичный API
        config.httpCookieAcceptPolicy = .never
        return URLSession(configuration: config)
    }()

    /// Загружает котировку одного инструмента.
    /// Символ должен быть в формате Yahoo Finance: AAPL, SBER.ME, GAZP.ME и т.д.
    func fetchQuote(symbol: String) async throws -> StockQuote {
        let trimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw QuotesError.invalidSymbol }

        // Безопасное формирование URL через URLComponents
        var components = URLComponents()
        components.scheme = "https"
        components.host = "query1.finance.yahoo.com"
        components.path = "/v8/finance/chart/\(trimmed)"
        components.queryItems = [
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "range", value: "1d")
        ]

        guard let url = components.url else { throw QuotesError.invalidURL }

        do {
            let (data, response) = try await session.data(from: url)

            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                throw QuotesError.noData
            }

            return try parseQuote(symbol: trimmed, data: data)
        } catch let error as QuotesError {
            throw error
        } catch {
            throw QuotesError.networkError(error)
        }
    }

    /// Загружает котировки нескольких инструментов параллельно.
    /// Ошибки по отдельным символам игнорируются — возвращаются только успешные.
    func fetchQuotes(symbols: [String]) async -> [StockQuote] {
        await withTaskGroup(of: StockQuote?.self) { group in
            for symbol in symbols {
                group.addTask {
                    try? await self.fetchQuote(symbol: symbol)
                }
            }
            var results: [StockQuote] = []
            for await quote in group {
                if let q = quote { results.append(q) }
            }
            return results
        }
    }

    // MARK: - Парсинг ответа Yahoo Finance

    private func parseQuote(symbol: String, data: Data) throws -> StockQuote {
        // Структура ответа: {"chart": {"result": [{"meta": {...}, ...}]}}
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let chart = json["chart"] as? [String: Any],
            let resultArray = chart["result"] as? [[String: Any]],
            let result = resultArray.first,
            let meta = result["meta"] as? [String: Any]
        else {
            throw QuotesError.decodingError(
                NSError(domain: "QuotesParser", code: 0, userInfo: [
                    NSLocalizedDescriptionKey: "Неожиданная структура ответа Yahoo Finance"
                ])
            )
        }

        let currentPrice = meta["regularMarketPrice"] as? Double
            ?? meta["chartPreviousClose"] as? Double
            ?? 0.0
        let previousClose = meta["chartPreviousClose"] as? Double
            ?? meta["previousClose"] as? Double
            ?? currentPrice

        return StockQuote(
            symbol: symbol,
            currentPrice: currentPrice,
            previousClose: previousClose
        )
    }
}
