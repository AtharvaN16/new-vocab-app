import Foundation

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
    
    // AI Enrichment fields
    let aiMnemonic: String?
    let userNotes: String?
    
    // Metadata
    let sources: [String]
    let createdAt: Date
    let updatedAt: Date

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
        let relation: String // e.g., "past tense", "plural"
    }
}
