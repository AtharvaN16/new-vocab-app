import Foundation

/// Implementation of AIRepository using the OpenRouter API (Tier 2).
final class OpenRouterService: AIRepository {
    private let apiKey: String
    private let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func generateContent(for word: String, type: AIContentType) async throws -> AsyncThrowingStream<String, Error> {
        let prompt = createPrompt(for: word, type: type)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("https://vocabapp.ios", forHTTPHeaderField: "HTTP-Referer")
        request.addValue("VocabApp iOS", forHTTPHeaderField: "X-Title")

        let body: [String: Any] = [
            "model": "google/gemini-pro-1.5", // Default model
            "messages": [["role": "user", "content": prompt]],
            "stream": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0))
                        return
                    }

                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = line.dropFirst(6)
                            
                            if jsonString == "[DONE]" {
                                continuation.finish()
                                break
                            }
                            
                            if let data = jsonString.data(using: .utf8),
                               let decoded = try? JSONDecoder().decode(OpenRouterChatResponse.self, from: data),
                               let content = decoded.choices.first?.delta.content {
                                continuation.yield(content)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func createPrompt(for word: String, type: AIContentType) -> String {
        switch type {
        case .mnemonic:
            return "Create a short, vivid mnemonic to help me remember the word '\(word)'. Use etymology or visual association. Keep it under 2 sentences."
        case .example:
            return "Create 3 distinct example sentences for the word '\(word)': one academic, one casual, and one literary."
        case .contextHint:
            return "Give me a subtle context clue for the word '\(word)' without using the word itself or its direct definition."
        }
    }
}

// MARK: - DTOs

struct OpenRouterChatResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let delta: Delta
    }
    
    struct Delta: Codable {
        let content: String?
    }
}
