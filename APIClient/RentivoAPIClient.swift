//
//  RentivoAPIClient.swift
//  InvestPortfolio
//
//  Central URLSession client for the Rentivo backend.
//  - Adds Bearer token to every authenticated request
//  - On 401: calls POST /auth/refresh, retries once
//  - On refresh failure: clears tokens
//

import Foundation

final class RentivoAPIClient: @unchecked Sendable {

    static let shared = RentivoAPIClient()

    static let defaultBaseURL = "https://rentivo-api-production.up.railway.app"

    private let baseURL: URL
    let tokenStorage: TokenStorage
    private let session: URLSession
    let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        baseURL: URL = URL(string: defaultBaseURL)!,
        tokenStorage: TokenStorage = .shared,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.tokenStorage = tokenStorage
        self.session = session

        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom(RentivoAPIClient.decodeDate)

        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Authenticated requests

    /// Performs an authenticated request and decodes the response.
    func get<T: Decodable>(path: String) async throws -> T {
        try await authenticatedRequest(method: "GET", path: path, bodyData: nil)
    }

    func post<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T {
        try await authenticatedRequest(method: "POST", path: path, bodyData: try encoder.encode(body))
    }

    func put<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T {
        try await authenticatedRequest(method: "PUT", path: path, bodyData: try encoder.encode(body))
    }

    /// DELETE with no response body — throws on error.
    func delete(path: String) async throws {
        guard let token = tokenStorage.loadAccessToken() else { throw APIError.noAuthToken }
        let request = buildRequest(method: "DELETE", path: path, bodyData: nil, bearer: token)
        let (data, response) = try await executeRequest(request)
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            let newToken = try await refreshTokens()
            let retried = buildRequest(method: "DELETE", path: path, bodyData: nil, bearer: newToken.accessToken)
            let (_, retryResponse) = try await executeRequest(retried)
            try validate(response: retryResponse, data: Data())
        } else {
            try validate(response: response, data: data)
        }
    }

    // MARK: - Public (unauthenticated) requests

    func publicPost<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T {
        let data = try encoder.encode(body)
        let request = buildRequest(method: "POST", path: path, bodyData: data, bearer: nil)
        let (responseData, response) = try await executeRequest(request)
        try validate(response: response, data: responseData)
        return try decoder.decode(T.self, from: responseData)
    }

    // MARK: - Private helpers

    private func authenticatedRequest<T: Decodable>(method: String, path: String, bodyData: Data?) async throws -> T {
        guard let token = tokenStorage.loadAccessToken() else { throw APIError.noAuthToken }
        let request = buildRequest(method: method, path: path, bodyData: bodyData, bearer: token)
        let (data, response) = try await executeRequest(request)

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            let newToken = try await refreshTokens()
            var retried = request
            retried.setValue("Bearer \(newToken.accessToken)", forHTTPHeaderField: "Authorization")
            let (retryData, retryResponse) = try await executeRequest(retried)
            try validate(response: retryResponse, data: retryData)
            return try decoder.decode(T.self, from: retryData)
        }

        try validate(response: response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func refreshTokens() async throws -> AuthToken {
        guard let refreshToken = tokenStorage.loadRefreshToken() else {
            signOut()
            throw APIError.unauthorized
        }
        struct RefreshBody: Encodable { let refreshToken: String }
        struct TokenDTO: Decodable { let accessToken: String; let refreshToken: String }
        do {
            let body = RefreshBody(refreshToken: refreshToken)
            let dto: TokenDTO = try await publicPost(path: "/auth/refresh", body: body)
            let token = AuthToken(accessToken: dto.accessToken, refreshToken: dto.refreshToken)
            tokenStorage.save(token)
            return token
        } catch {
            signOut()
            throw APIError.unauthorized
        }
    }

    private func signOut() {
        tokenStorage.clearTokens()
    }

    private func buildRequest(method: String, path: String, bodyData: Data?, bearer: String?) -> URLRequest {
        // URLComponents is safe; path always starts with "/"
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        if let bearer { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        request.httpBody = bodyData
        return request
    }

    private func executeRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        #if DEBUG
        let bodyStr = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        print("[RentivoAPI] \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "")\(bodyStr.isEmpty ? "" : "\n  body: \(bodyStr)")")
        #endif
        do {
            let (data, response) = try await session.data(for: request)
            #if DEBUG
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[RentivoAPI] → \(code) \(body.prefix(500))")
            #endif
            return (data, response)
        } catch {
            throw APIError.from(error)
        }
    }

    // MARK: - Date decoding (handles fractional seconds and plain ISO 8601)

    private static let iso8601Full: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601Basic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private static func decodeDate(from decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        if let date = iso8601Full.date(from: string) { return date }
        if let date = iso8601Basic.date(from: string) { return date }
        if let date = dateOnly.date(from: string) { return date }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Cannot parse date: \(string)"
        )
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 401 { throw APIError.unauthorized }
            // Try to extract a server-side error message
            if let body = try? JSONDecoder().decode([String: String].self, from: data),
               let message = body["message"] ?? body["error"] {
                throw APIError.apiError(code: http.statusCode, message: message)
            }
            throw APIError.httpError(statusCode: http.statusCode)
        }
    }
}
