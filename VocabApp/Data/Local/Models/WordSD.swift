import Foundation
import SwiftData

@Model
final class WordSD {
    @Attribute(.unique) var id: UUID
    var word: String
    var phonetic: String?
    
    // Store complex types as Codable Data (SwiftData supports this for simple arrays/structs, 
    // but for deep nesting or performance, sometimes we use JSON data)
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
    
    // Relationship to collections
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
        
        // Encode complex structs
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
            updatedAt: updatedAt
        )
    }
}
