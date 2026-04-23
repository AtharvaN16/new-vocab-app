import Foundation

// MARK: - DTOs

struct AuthResponse: Codable {
    let access_token: String
    let refresh_token: String?
    let user: SupabaseUser
}

struct SupabaseUser: Codable {
    let id: UUID
    let email: String?
}

struct SupabaseError: Codable {
    let msg: String?
    let message: String?
}

/// Internal Supabase configuration.
enum SupabaseConfig {
    static let url = URL(string: "https://nlctbwqfrrqfruyflglm.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5sY3Rid3FmcnJxZnJ1eWZsZ2xtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5MDUzMzIsImV4cCI6MjA5MjQ4MTMzMn0.kBVBrq9d5JGF7yATC2Bp9L39_g6xkVPlQzsGGK5_KIU"
}

/// A lightweight wrapper for Supabase REST operations.
actor SupabaseClient {
    private let session: URLSession = .shared
    private let tokenKey = "com.atharvanayak.vocabapp.auth_token"

    private func getAuthHeader() -> String {
        if let data = try? KeychainHelper.read(key: tokenKey),
           let token = String(data: data, encoding: .utf8) {
            return "Bearer \(token)"
        }
        return "Bearer \(SupabaseConfig.anonKey)"
    }
    
    // MARK: - Auth
    
    func signUp(email: String, password: String) async throws -> AuthResponse {
        var request = URLRequest(url: SupabaseConfig.url.appendingPathComponent("auth/v1/signup"))
        request.httpMethod = "POST"
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        return try handleAuthResponse(data: data, response: response)
    }
    
    func signIn(email: String, password: String) async throws -> AuthResponse {
        var request = URLRequest(url: SupabaseConfig.url.appendingPathComponent("auth/v1/token"))
        request.url?.append(queryItems: [URLQueryItem(name: "grant_type", value: "password")])
        request.httpMethod = "POST"
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        return try handleAuthResponse(data: data, response: response)
    }
    
    private func handleAuthResponse(data: Data, response: URLResponse) throws -> AuthResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "SupabaseAuth", code: 0)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let error = try? JSONDecoder().decode(SupabaseError.self, from: data)
            throw NSError(domain: "SupabaseAuth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: error?.msg ?? "Auth failed"])
        }
        
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    // MARK: - Data
    
    func upsert<T: Encodable>(table: String, item: T) async throws {
        var request = URLRequest(url: SupabaseConfig.url.appendingPathComponent("rest/v1/\(table)"))
        request.httpMethod = "POST"
        request.addValue(getAuthHeader(), forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(item)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "Supabase", code: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }
    
    func fetch<T: Decodable>(table: String, since: Date) async throws -> [T] {
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: since)
        
        var components = URLComponents(url: SupabaseConfig.url.appendingPathComponent("rest/v1/\(table)"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "updated_at", value: "gt.\(dateString)"),
            URLQueryItem(name: "select", value: "*")
        ]
        
        guard let url = components?.url else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(getAuthHeader(), forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([T].self, from: data)
    }
}
