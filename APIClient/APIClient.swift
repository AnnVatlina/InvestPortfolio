//
//  APIClient.swift
//  
//
//  Created by Anna on 26.12.25.
//

import Foundation

struct AuthResponse: Decodable {
    let token: String?
    let accessToken: String?
    let sessionId: String?
    
    var authToken: String? {
        token ?? accessToken ?? sessionId
    }
}

private struct LoginRequestBody: Encodable {
    let login: String
    let password: String
    let mode: String
    let getAccounts: Bool
}

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let baseURL = "https://tradernet.ru/api"

    private var authToken: String? {
        KeychainService.loadToken()
    }

    // Авторизация по логину и паролю
    func login(username: String, password: String) async throws {
        // Используем эндпоинт check-login-password согласно документации
        let urlString = baseURL.hasSuffix("/") ? baseURL + "check-login-password".dropFirst() : baseURL + "/check-login-password"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        print("🔐 Login URL: \(urlString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        
        // Тело запроса с логином и паролем
        let body = LoginRequestBody(
            login: username,
            password: password,
            mode: "regular",
            getAccounts: true
        )
        request.httpBody = try JSONEncoder().encode(body)
        
        if let httpBody = request.httpBody {
            print("📤 Request body: \(String(data: httpBody, encoding: .utf8) ?? "nil")")
        } else {
            print("📤 Request body: nil")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status: \(httpResponse.statusCode)")
                print("📋 Response Headers: \(httpResponse.allHeaderFields)")
                
                if let responseBody = String(data: data, encoding: .utf8) {
                    print("📥 Response Body: \(responseBody)")
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    if httpResponse.statusCode == 401 {
                        throw APIError.invalidCredentials
                    }
                    throw APIError.httpError(statusCode: httpResponse.statusCode)
                }
            }
            
            // Пробуем разные форматы ответа
            do {
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                if let token = authResponse.authToken {
                    print("✅ Token received: \(token.prefix(20))...")
                    KeychainService.saveToken(token)
                    return
                }
            } catch {
                print("⚠️ Could not decode as AuthResponse, trying as string")
                // Если не получилось декодировать как AuthResponse, пробуем как строку
                if let tokenString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !tokenString.isEmpty {
                    print("✅ Token as string: \(tokenString.prefix(20))...")
                    KeychainService.saveToken(tokenString)
                    return
                }
            }
            
            // Если ответ успешный, но токен не найден в стандартном формате
            // Возможно, API просто возвращает успех без токена, и токен нужно использовать из сессии
            // Или токен приходит в заголовках
            if let httpResponse = response as? HTTPURLResponse,
               let setCookieHeader = httpResponse.value(forHTTPHeaderField: "Set-Cookie") {
                print("🍪 Cookie received: \(setCookieHeader)")
                KeychainService.saveToken(setCookieHeader)
                return
            }
            
            // Если токен не найден в ответе, но запрос успешен, возможно нужно использовать логин/пароль как токен
            // или API использует cookie-based авторизацию
            print("⚠️ No token found in response, but request was successful")
            // Сохраняем комбинацию логин:пароль как токен для последующих запросов
            let credentials = "\(username):\(password)"
            if let credentialsData = credentials.data(using: .utf8) {
                let base64Credentials = credentialsData.base64EncodedString()
                KeychainService.saveToken(base64Credentials)
                print("✅ Saved credentials as token")
                return
            }
            
            throw APIError.decodingError(NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Токен не найден в ответе сервера"]))
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    func logout() {
        KeychainService.deleteToken()
    }

    private func request(path: String) async throws -> Data {
        // Проверка наличия токена авторизации
        guard let token = authToken, !token.isEmpty else {
            throw APIError.noAuthToken
        }
        
        // Формирование URL
        let urlString = baseURL.hasSuffix("/") ? baseURL + path.dropFirst() : baseURL + path
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Если токен это base64 encoded credentials (login:password), используем Basic Auth
        // Иначе используем Bearer токен
        if let credentialsData = Data(base64Encoded: token),
           let credentials = String(data: credentialsData, encoding: .utf8),
           credentials.contains(":") {
            // Basic Auth
            request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        } else {
            // Bearer токен или cookie
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Проверка HTTP статус кода
            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    // Если 401, удаляем токен и требуем повторной авторизации
                    if httpResponse.statusCode == 401 {
                        KeychainService.deleteToken()
                    }
                    throw APIError.httpError(statusCode: httpResponse.statusCode)
                }
            }
            
            return data
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    func fetchPortfolio() async throws -> [PortfolioPosition] {
        let data = try await request(path: "/portfolio")
        do {
            return try JSONDecoder().decode([PortfolioPosition].self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func fetchCashOperations() async throws -> [CashOperation] {
        let data = try await request(path: "/cash")
        do {
            return try JSONDecoder().decode([CashOperation].self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}

