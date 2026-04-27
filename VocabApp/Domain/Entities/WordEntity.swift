import Foundation

enum WordRegister: String, Codable, Equatable {
    case formal, informal, literary, archaic, rare, neutral
}

/// A pure domain representation of a vocabulary word.
/// Agnostic of persistence (SwiftData) or network (Supabase/APIs) frameworks.
struct WordEntity: Identifiable, Codable, Equatable {
    let id: UUID
    let word: String
    let phonetic: String?
    let definitions: [Definition]
    let examples: [Example]
    let synonyms: [String]
    let antonyms: [String]
    let etymology: String?
    let otherForms: [WordForm]
    let aiMnemonic: String?
    let userNotes: String?
    let sources: [String]
    let createdAt: Date
    let updatedAt: Date
    // Phase 1 enrichment
    let audioURL: String?
    let syllables: [String]
    let register: WordRegister?
    let contextualNote: String?
    let qualityScore: Int

    init(
        id: UUID = UUID(),
        word: String,
        phonetic: String? = nil,
        definitions: [Definition] = [],
        examples: [Example] = [],
        synonyms: [String] = [],
        antonyms: [String] = [],
        etymology: String? = nil,
        otherForms: [WordForm] = [],
        aiMnemonic: String? = nil,
        userNotes: String? = nil,
        sources: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        audioURL: String? = nil,
        syllables: [String] = [],
        register: WordRegister? = nil,
        contextualNote: String? = nil,
        qualityScore: Int = 0
    ) {
        self.id = id; self.word = word; self.phonetic = phonetic
        self.definitions = definitions; self.examples = examples
        self.synonyms = synonyms; self.antonyms = antonyms
        self.etymology = etymology; self.otherForms = otherForms
        self.aiMnemonic = aiMnemonic; self.userNotes = userNotes
        self.sources = sources; self.createdAt = createdAt; self.updatedAt = updatedAt
        self.audioURL = audioURL; self.syllables = syllables
        self.register = register; self.contextualNote = contextualNote
        self.qualityScore = qualityScore
    }

    struct Definition: Codable, Equatable {
        let text: String
        let partOfSpeech: String
        let source: String
    }

    struct Example: Codable, Equatable {
        let text: String
        let source: String
        let isAIGenerated: Bool
    }

    struct WordForm: Codable, Equatable, Hashable {
        let form: String
        let relation: String
    }
}
