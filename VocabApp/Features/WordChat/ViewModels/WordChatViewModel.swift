import Foundation
import SwiftUI

// MARK: - Assistant Mode

enum AssistantMode: String, CaseIterable, Identifiable {
    case deepDive
    case challengeMe
    case writeWithIt

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .deepDive:     return "Deep Dive"
        case .challengeMe:  return "Challenge Me"
        case .writeWithIt:  return "Write With It"
        }
    }

    var icon: String {
        switch self {
        case .deepDive:     return "brain"
        case .challengeMe:  return "bolt.circle"
        case .writeWithIt:  return "pencil.and.outline"
        }
    }

    var modeDescription: String {
        switch self {
        case .deepDive:     return "Everything fascinating about this word"
        case .challengeMe:  return "Adaptive questions that build real ownership"
        case .writeWithIt:  return "Use this word in your own writing"
        }
    }

    func systemPrompt(for word: WordEntity) -> String {
        let defs = word.definitions.prefix(2).map(\.text).joined(separator: "; ")
        let base = "The user is studying the word \"\(word.word)\"\(defs.isEmpty ? "." : " — defined as: \(defs).")"

        switch self {
        case .deepDive:
            return """
            \(base)

            You are a brilliant, curious expert on this word. Your job is to make the user genuinely fascinated by it — not just know what it means, but understand why it exists, what nuance it carries, and how it connects to the world.

            Cover what the conversation calls for:
            - Origins and etymology (language family, root meaning, how it evolved)
            - Connotations and register (formal vs casual, positive vs negative charge)
            - Subtle differences from close synonyms
            - Surprising real-world usage (literature, historical speeches, specific industries)
            - Connections to other words the user might know

            Be conversational, not encyclopedic. Respond to what the user specifically asks. 2–4 paragraphs max per turn.
            """

        case .challengeMe:
            return """
            \(base)

            You are an adaptive vocabulary coach. Your job is to test the user's understanding of "\(word.word)" using four question types, cycling through them to build multiple layers of word ownership:

            QUESTION TYPES (use all four across the conversation):

            1. TEXT COMPLETION — Create a sentence with a blank where "\(word.word)" fits naturally. Use logical contrast signals (although, despite, however, while) when possible. Provide 4 options: the correct word, one near-synonym (trap), one antonym, one off-topic distractor. All options must be the same part of speech.

            2. SENTENCE EQUIVALENCE — Find a true synonym of "\(word.word)" and build a sentence where both fit identically. Provide 6 options: the 2 correct synonyms + 4 distractors including at least one near-synonym trap. Label both correct answers only after the user responds.

            3. MICRO-PASSAGE — Write 2–3 sentences using "\(word.word)" in a realistic, nuanced context. Ask: "What does '\(word.word)' most nearly mean in this context?" Provide 4 options where the wrong answers are plausible but fail on tone or specificity.

            4. USE IT — Give the user a specific scenario (formal email, literary passage, casual conversation) and ask them to write one sentence using "\(word.word)". When they respond, rate their sentence on accuracy (did they use it correctly?) and precision (did they capture the nuance?). Suggest improvements.

            DIFFICULTY LEVELS:
            - Start at Level 1 (direct meaning, simple sentence, obvious context)
            - Promote to Level 2 after a correct answer (requires interpreting tone)
            - Promote to Level 3 after two correct (multi-signal sentences)
            - Promote to Level 4 after three correct (trap-heavy distractors, subtle tone mismatches)
            - Drop one level after a wrong answer

            FEEDBACK (after every answer):
            - State whether the user was correct
            - Explain specifically why the correct answer works
            - Explain why each distractor fails (this is the most valuable part)
            - Then generate the next question
            """

        case .writeWithIt:
            return """
            \(base)

            You are a writing coach helping the user actually use "\(word.word)" in their own voice. Your job is to bridge the gap between knowing a word and owning it.

            What you do:
            - If the user pastes their own text: identify where "\(word.word)" could fit naturally, show them the revised version, explain why it works there, and suggest how the tone changes with it.
            - If the user hasn't started yet: give them 2–3 specific writing prompts (different registers: formal, literary, casual) and invite them to try one.
            - When the user writes a sentence: rate it on two axes — correctness (did they use it right?) and precision (did they capture its specific nuance vs a blander synonym?). Be specific, not just "good job."
            - Suggest alternatives at different registers if relevant.

            One rule: always ask the user to try writing first, before you provide any examples. Even if they ask you to write one for them, offer a simpler prompt or scaffold instead — never produce the sentence for them. The act of struggling to write it is the learning.
            """
        }
    }

    var quickPrompts: [String] {
        switch self {
        case .deepDive:
            return [
                "What makes this word different from its closest synonyms?",
                "Where does this word come from originally?",
                "What's a surprising or unusual usage of this word?"
            ]
        case .challengeMe:
            return [
                "Start a Level 1 question",
                "Give me a sentence equivalence challenge",
                "Test me with a micro-passage"
            ]
        case .writeWithIt:
            return [
                "Give me a writing prompt to try this word",
                "I'll paste a sentence — help me work this word in",
                "What register suits this word best?"
            ]
        }
    }
}

// MARK: - Message

struct ChatMessage: Identifiable, Equatable {
    enum Role { case user, assistant }

    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date

    init(role: Role, content: String = "") {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

// MARK: - Save Type

enum ChatSaveType {
    case note
    case example
    case mnemonic
}

// MARK: - ViewModel

@Observable
@MainActor
final class WordChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isGenerating: Bool = false
    var errorMessage: String? = nil
    var selectedMode: AssistantMode = .deepDive

    var word: WordEntity
    private let aiRepository: AIRepository
    private let wordRepository: WordRepository

    init(word: WordEntity, aiRepository: AIRepository, wordRepository: WordRepository) {
        self.word = word
        self.aiRepository = aiRepository
        self.wordRepository = wordRepository
    }

    var showQuickPrompts: Bool { messages.isEmpty }

    func send(text: String? = nil) async {
        let userText = (text ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty, !isGenerating else { return }

        inputText = ""
        // Snapshot history BEFORE appending the new turn
        let history = messages.map {
            ChatHistoryEntry(role: $0.role == .user ? "user" : "assistant", content: $0.content)
        }
        messages.append(ChatMessage(role: .user, content: userText))
        let assistantMessage = ChatMessage(role: .assistant)
        messages.append(assistantMessage)
        isGenerating = true
        errorMessage = nil

        do {
            let stream = try await aiRepository.generateContent(
                for: word.word,
                type: .chat(
                    systemPrompt: selectedMode.systemPrompt(for: word),
                    history: history,
                    userMessage: userText
                )
            )
            for try await chunk in stream {
                if let idx = messages.firstIndex(where: { $0.id == assistantMessage.id }) {
                    messages[idx].content += chunk
                }
            }
        } catch {
            if let idx = messages.firstIndex(where: { $0.id == assistantMessage.id }) {
                messages[idx].content = "Something went wrong. Please try again."
            }
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }

    func switchMode(_ mode: AssistantMode) {
        guard mode != selectedMode else { return }
        selectedMode = mode
        messages = []
        errorMessage = nil
    }

    func saveMessage(_ message: ChatMessage, as saveType: ChatSaveType) async {
        guard message.role == .assistant, !message.content.isEmpty else { return }
        let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)

        let updated: WordEntity
        switch saveType {
        case .note:
            let existing = word.userNotes.map { "\($0)\n\n" } ?? ""
            updated = WordEntity(
                id: word.id, word: word.word, phonetic: word.phonetic,
                definitions: word.definitions, examples: word.examples,
                synonyms: word.synonyms, antonyms: word.antonyms,
                etymology: word.etymology, otherForms: word.otherForms,
                aiMnemonic: word.aiMnemonic,
                userNotes: "\(existing)\(content)",
                sources: word.sources, createdAt: word.createdAt, updatedAt: Date(),
                audioURL: word.audioURL, syllables: word.syllables,
                register: word.register, contextualNote: word.contextualNote,
                qualityScore: word.qualityScore
            )
        case .example:
            let newExample = WordEntity.Example(text: content, source: "AI Chat", isAIGenerated: true)
            updated = WordEntity(
                id: word.id, word: word.word, phonetic: word.phonetic,
                definitions: word.definitions,
                examples: word.examples + [newExample],
                synonyms: word.synonyms, antonyms: word.antonyms,
                etymology: word.etymology, otherForms: word.otherForms,
                aiMnemonic: word.aiMnemonic, userNotes: word.userNotes,
                sources: word.sources, createdAt: word.createdAt, updatedAt: Date(),
                audioURL: word.audioURL, syllables: word.syllables,
                register: word.register, contextualNote: word.contextualNote,
                qualityScore: word.qualityScore
            )
        case .mnemonic:
            updated = WordEntity(
                id: word.id, word: word.word, phonetic: word.phonetic,
                definitions: word.definitions, examples: word.examples,
                synonyms: word.synonyms, antonyms: word.antonyms,
                etymology: word.etymology, otherForms: word.otherForms,
                aiMnemonic: content,
                userNotes: word.userNotes,
                sources: word.sources, createdAt: word.createdAt, updatedAt: Date(),
                audioURL: word.audioURL, syllables: word.syllables,
                register: word.register, contextualNote: word.contextualNote,
                qualityScore: word.qualityScore
            )
        }
        self.word = updated
        try? await wordRepository.saveWord(updated)
    }
}
