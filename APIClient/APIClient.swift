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
            
            do {
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                if let token = authResponse.authToken {
                    print("✅ Token received: \(token.prefix(20))...")
                    KeychainService.saveToken(token)
                    return
                }
            } catch {
                print("⚠️ Could not decode as AuthResponse, trying as string")
                if let tokenString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !tokenString.isEmpty {
                    print("✅ Token as string: \(tokenString.prefix(20))...")
                    KeychainService.saveToken(tokenString)
                    return
                }
            }
            
            if let httpResponse = response as? HTTPURLResponse,
               let setCookieHeader = httpResponse.value(forHTTPHeaderField: "Set-Cookie") {
                print("🍪 Cookie received: \(setCookieHeader)")
                KeychainService.saveToken(setCookieHeader)
                return
            }
            
            print("⚠️ No token found in response, but request was successful")
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
            throw APIError.from(error)
        }
    }
    
    func logout() {
        KeychainService.deleteToken()
    }

    // Отправляет тело вида { "q": JSON.stringify(inner) }
    private func request(q inner: [String: Any]) async throws -> Data {
        // Проверка наличия токена авторизации
        guard let token = authToken, !token.isEmpty else {
            throw APIError.noAuthToken
        }
        
        guard let url = URL(string: baseURL) else {
            throw APIError.invalidURL
        }
        
        // Сериализуем inner в JSON-строку (эквивалент JSON.stringify)
        let innerData = try JSONSerialization.data(withJSONObject: inner, options: [])
        guard let innerJSONString = String(data: innerData, encoding: .utf8) else {
            throw APIError.decodingError(NSError(domain: "Encoding", code: -1, userInfo: [NSLocalizedDescriptionKey: "Не удалось сформировать JSON-строку для q"]))
        }
        
        print("🌐 Request to: \(baseURL)")
        print("📋 q (stringified): \(innerJSONString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let credentialsData = Data(base64Encoded: token),
           let credentials = String(data: credentialsData, encoding: .utf8),
           credentials.contains(":") {
            request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
            print("🔑 Using Basic Auth")
        } else {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("🔑 Using Bearer token")
        }
        
        let outerBody: [String: Any] = ["q": innerJSONString]
        request.httpBody = try JSONSerialization.data(withJSONObject: outerBody, options: [])
        
        if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
            print("📤 Request body: \(bodyString)")
        }
        
        request.timeoutInterval = 30
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status: \(httpResponse.statusCode)")
                
                if let responseBody = String(data: data, encoding: .utf8) {
                    print("📥 Response: \(responseBody.prefix(500))")
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    if httpResponse.statusCode == 401 {
                        KeychainService.deleteToken()
                        throw APIError.unauthorized
                    }
                    throw APIError.httpError(statusCode: httpResponse.statusCode)
                }
            }
            
            return data
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.from(error)
        }
    }

    func fetchPortfolio(sid: String) async throws -> [PortfolioPosition] {
        let inner: [String: Any] = [
            "cmd": "getPositionJson",
            "SID": sid,
            "params": [:] // пустой объект
        ]
        let data = try await request(q: inner)
        
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(PortfolioResponse.self, from: data)
            
            if let errorCode = response.code, errorCode != 0 {
                let errorMessage = response.errMsg ?? "Неизвестная ошибка"
                print("❌ API Error: code=\(errorCode), message=\(errorMessage)")
                throw APIError.apiError(code: errorCode, message: response.errMsg)
            }
            
            guard let positions = response.pos else {
                return []
            }
            return positions.map { PortfolioPosition(from: $0) }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func fetchCashOperations() async throws -> [CashOperation] {
        let inner: [String: Any] = [
            "cmd": "getUserCashFlows",
            "params": [:]
        ]
        let data = try await request(q: inner)
        do {
            return try JSONDecoder().decode([CashOperation].self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}

