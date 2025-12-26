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
    case httpError(statusCode: Int)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Неверный URL запроса"
        case .noAuthToken:
            return "Требуется авторизация. Пожалуйста, войдите в систему."
        case .invalidCredentials:
            return "Неверный логин или пароль"
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
        case .decodingError(let error):
            return "Ошибка обработки данных: \(error.localizedDescription)"
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        }
    }
}

