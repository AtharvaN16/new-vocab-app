import Foundation

struct WiktionaryResponse: Decodable {
    let en: [WiktionaryEntry]?
}

struct WiktionaryEntry: Decodable {
    let partOfSpeech: String
    let definitions: [WiktionaryDefinition]
}

struct WiktionaryDefinition: Decodable {
    let definition: String
    let parsedExamples: [WiktionaryExample]?
}

struct WiktionaryExample: Decodable {
    let example: String
}

extension WiktionaryResponse: Normalizable {
    func normalize() -> WordEntity {
        guard let entries = self.en else {
            return WordEntity(
                id: UUID(),
                word: "",
                phonetic: nil,
                definitions: [],
                examples: [],
                synonyms: [],
                antonyms: [],
                etymology: nil,
                otherForms: [],
                aiMnemonic: nil,
                userNotes: nil,
                sources: ["Wiktionary"],
                createdAt: Date(),
                updatedAt: Date()
            )
        }

        var allDefinitions: [WordEntity.Definition] = []
        var allExamples: [WordEntity.Example] = []

        for entry in entries {
            for def in entry.definitions {
                let cleanDefinition = def.definition.strippingHTML()
                allDefinitions.append(WordEntity.Definition(
                    text: cleanDefinition,
                    partOfSpeech: entry.partOfSpeech,
                    source: "Wiktionary"
                ))
                
                def.parsedExamples?.forEach { ex in
                    allExamples.append(WordEntity.Example(
                        text: ex.example.strippingHTML(),
                        source: "Wiktionary",
                        isAIGenerated: false
                    ))
                }
            }
        }

        return WordEntity(
            id: UUID(),
            word: "", // Word is not explicitly in the definition REST API response body, usually inferred from URL
            phonetic: nil,
            definitions: allDefinitions,
            examples: allExamples,
            synonyms: [],
            antonyms: [],
            etymology: nil, // Etymology is not in the rest_v1 definition endpoint, requires Action API usually
            otherForms: [],
            aiMnemonic: nil,
            userNotes: nil,
            sources: ["Wiktionary"],
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

extension String {
    func strippingHTML() -> String {
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
            .replacingOccurrences(of: "&[^;]+;", with: "", options: .regularExpression, range: nil) // Basic entity stripping
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
