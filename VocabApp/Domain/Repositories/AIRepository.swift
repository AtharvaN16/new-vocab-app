import Foundation

/// Defines the types of content AI can generate for a word.
enum AIContentType {
    case mnemonic
    case example
    case contextHint
}

protocol AIRepository {
    /// Generates content for a word using a streaming response.
    func generateContent(for word: String, type: AIContentType) async throws -> AsyncThrowingStream<String, Error>
}
