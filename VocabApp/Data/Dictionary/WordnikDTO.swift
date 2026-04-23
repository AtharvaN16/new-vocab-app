import Foundation

struct WordnikDefinition: Decodable {
    let text: String
    let partOfSpeech: String
    let sourceDictionary: String
}

struct WordnikExample: Decodable {
    let text: String
}

struct WordnikExampleResponse: Decodable {
    let examples: [WordnikExample]
}

extension Array where Element == WordnikDefinition {
    func normalize() -> WordEntity {
        let definitions = self.map { 
            WordEntity.Definition(text: $0.text, partOfSpeech: $0.partOfSpeech, source: "Wordnik (\($0.sourceDictionary))")
        }
        
        return WordEntity(
            id: UUID(),
            word: "",
            phonetic: nil,
            definitions: definitions,
            examples: [],
            synonyms: [],
            antonyms: [],
            etymology: nil,
            otherForms: [],
            aiMnemonic: nil,
            userNotes: nil,
            sources: ["Wordnik"],
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
