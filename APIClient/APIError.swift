//
//  APIError.swift
//  
//
//  Created by Anna on 26.12.25.
//

import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case noAuthToken
    case invalidCredentials
    case unauthorized // 401, для реакции UI (relogin)
    case httpError(statusCode: Int)
    case apiError(code: Int, message: String?) // бизнес-ошибка из тела ответа
    case decodingError(Error)
    case networkError(Error)
    // Детализированные сетевые ошибки
    case networkTimeout
    case networkCancelled
    case networkOffline
    case networkDNSFailure
    case networkCannotFindHost
    case networkCannotConnectToHost

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Неверный URL запроса"
        case .noAuthToken:
            return "Требуется авторизация. Пожалуйста, войдите в систему."
        case .invalidCredentials:
            return "Неверный логин или пароль"
        case .unauthorized:
            return "Сессия истекла или недействительна. Пожалуйста, войдите снова."
        case .httpError(let code):
            switch code {
            case 401:
                return "Ошибка авторизации (401). Проверьте логин и пароль."
            case 403:
                return "Доступ запрещен (403)"
            case 404:
                return "Эндпоинт не найден (404)"
            default:
                return "Ошибка сервера: \(code)"
            }
        case .apiError(let code, let message):
            if let message, !message.isEmpty {
                return "Ошибка API (\(code)): \(message)"
            } else {
                return "Ошибка API (\(code))"
            }
        case .decodingError(let error):
            return "Ошибка обработки данных: \(error.localizedDescription)"
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .networkTimeout:
            return "Превышено время ожидания соединения"
        case .networkCancelled:
            return "Запрос отменён"
        case .networkOffline:
            return "Нет подключения к интернету"
        case .networkDNSFailure:
            return "Не удалось разрешить адрес сервера (DNS)"
        case .networkCannotFindHost:
            return "Сервер не найден"
        case .networkCannotConnectToHost:
            return "Не удалось подключиться к серверу"
        }
    }

    // Удобный и единый маппер URLError → APIError
    static func from(_ error: Error) -> APIError {
        if let apiError = error as? APIError {
            return apiError
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return .networkTimeout
            case .cancelled:
                return .networkCancelled
            case .notConnectedToInternet:
                return .networkOffline
            case .dnsLookupFailed:
                return .networkDNSFailure
            case .cannotFindHost:
                return .networkCannotFindHost
            case .cannotConnectToHost:
                return .networkCannotConnectToHost
            default:
                return .networkError(urlError)
            }
        }
        return .networkError(error)
    }
}

