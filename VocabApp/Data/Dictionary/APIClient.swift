import Foundation

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case decodingError(Error)
    case serverError(Int)
    case noData
}

enum HTTPMethod: String {
    case get = "GET"
}

protocol APIRequest {
    associatedtype Response: Decodable
    var url: URL? { get }
    var method: HTTPMethod { get }
}

/// Generic actor to handle networking safely on a background thread.
actor APIClient {
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 30
            self.session = URLSession(configuration: config)
        }
    }

    func send<T: APIRequest>(_ request: T) async throws -> T.Response {
        guard let url = request.url else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.Response.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
