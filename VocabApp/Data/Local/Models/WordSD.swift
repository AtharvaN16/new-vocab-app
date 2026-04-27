import Foundation
import SwiftData

@Model
final class WordSD {
    @Attribute(.unique) var id: UUID
    var word: String
    var phonetic: String?
    var definitionsData: Data
    var examplesData: Data
    var synonyms: [String]
    var antonyms: [String]
    var etymology: String?
    var otherFormsData: Data
    var aiMnemonic: String?
    var userNotes: String?
    var sources: [String]
    var createdAt: Date
    var updatedAt: Date
    // Phase 1 enrichment — all optional/defaulted → lightweight migration
    var audioURL: String?
    var syllables: [String] = []
    var register: String?        // WordRegister.rawValue
    var contextualNote: String?
    var qualityScore: Int = 0

    @Relationship(inverse: \CollectionSD.words)
    var collections: [CollectionSD]?

    init(from entity: WordEntity) {
        self.id = entity.id
        self.word = entity.word
        self.phonetic = entity.phonetic
        self.synonyms = entity.synonyms
        self.antonyms = entity.antonyms
        self.etymology = entity.etymology
        self.aiMnemonic = entity.aiMnemonic
        self.userNotes = entity.userNotes
        self.sources = entity.sources
        self.createdAt = entity.createdAt
        self.updatedAt = entity.updatedAt
        self.audioURL = entity.audioURL
        self.syllables = entity.syllables
        self.register = entity.register?.rawValue
        self.contextualNote = entity.contextualNote
        self.qualityScore = entity.qualityScore
        let encoder = JSONEncoder()
        self.definitionsData = (try? encoder.encode(entity.definitions)) ?? Data()
        self.examplesData = (try? encoder.encode(entity.examples)) ?? Data()
        self.otherFormsData = (try? encoder.encode(entity.otherForms)) ?? Data()
    }

    func toDomain() -> WordEntity {
        let decoder = JSONDecoder()
        let definitions = (try? decoder.decode([WordEntity.Definition].self, from: definitionsData)) ?? []
        let examples = (try? decoder.decode([WordEntity.Example].self, from: examplesData)) ?? []
        let otherForms = (try? decoder.decode([WordEntity.WordForm].self, from: otherFormsData)) ?? []
        return WordEntity(
            id: id,
            word: word,
            phonetic: phonetic,
            definitions: definitions,
            examples: examples,
            synonyms: synonyms,
            antonyms: antonyms,
            etymology: etymology,
            otherForms: otherForms,
            aiMnemonic: aiMnemonic,
            userNotes: userNotes,
            sources: sources,
            createdAt: createdAt,
            updatedAt: updatedAt,
            audioURL: audioURL,
            syllables: syllables,
            register: register.flatMap { WordRegister(rawValue: $0) },
            contextualNote: contextualNote,
            qualityScore: qualityScore
        )
    }
}
