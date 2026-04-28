import Foundation

struct ChatHistoryEntry {
    let role: String   // "user" or "assistant"
    let content: String
}

/// Defines the types of content AI can generate for a word.
enum AIContentType {
    case mnemonic
    case example
    case contextHint
    /// AI-assisted suggestion for a specific field in the word editor.
    case editorSuggest(prompt: String)
    /// Conversational chat about a word with a specific system persona.
    case chat(systemPrompt: String, history: [ChatHistoryEntry], userMessage: String)
}

protocol AIRepository {
    /// Generates content for a word using a streaming response.
    func generateContent(for word: String, type: AIContentType) async throws -> AsyncThrowingStream<String, Error>
}
