import Foundation

struct FreeDictionaryEntry: Decodable {
    let word: String
    let phonetic: String?
    let phonetics: [Phonetic]
    let meanings: [Meaning]
    let sourceUrls: [String]?

    struct Phonetic: Decodable {
        let text: String?
        let audio: String?
    }

    struct Meaning: Decodable {
        let partOfSpeech: String
        let definitions: [Definition]
        let synonyms: [String]?
        let antonyms: [String]?
    }

    struct Definition: Decodable {
        let definition: String
        let example: String?
        let synonyms: [String]?
        let antonyms: [String]?
    }
}

typealias FreeDictionaryResponse = [FreeDictionaryEntry]

extension FreeDictionaryResponse {
    func normalize() -> WordEntity {
        guard let entry = self.first else {
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
                sources: ["Free Dictionary API"],
                createdAt: Date(),
                updatedAt: Date()
            )
        }

        var allDefinitions: [WordEntity.Definition] = []
        var allExamples: [WordEntity.Example] = []
        var allSynonyms: Set<String> = []
        var allAntonyms: Set<String> = []

        for meaning in entry.meanings {
            for def in meaning.definitions {
                allDefinitions.append(WordEntity.Definition(
                    text: def.definition,
                    partOfSpeech: meaning.partOfSpeech,
                    source: "Free Dictionary API"
                ))
                
                if let example = def.example {
                    allExamples.append(WordEntity.Example(
                        text: example,
                        source: "Free Dictionary API",
                        isAIGenerated: false
                    ))
                }
                
                def.synonyms?.forEach { allSynonyms.insert($0) }
                def.antonyms?.forEach { allAntonyms.insert($0) }
            }
            meaning.synonyms?.forEach { allSynonyms.insert($0) }
            meaning.antonyms?.forEach { allAntonyms.insert($0) }
        }

        return WordEntity(
            id: UUID(),
            word: entry.word,
            phonetic: entry.phonetic ?? entry.phonetics.first(where: { $0.text != nil })?.text,
            definitions: allDefinitions,
            examples: allExamples,
            synonyms: [String](allSynonyms),
            antonyms: [String](allAntonyms),
            etymology: nil, // Free Dictionary doesn't provide etymology in a reliable field
            otherForms: [],
            aiMnemonic: nil,
            userNotes: nil,
            sources: ["Free Dictionary API"],
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
