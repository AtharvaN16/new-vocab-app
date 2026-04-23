import Foundation

final class DictionaryService: DictionaryRepository {
    private let apiClient: APIClient
    private let wordRepository: WordRepository
    private var wordnikApiKey: String?
    private let cacheTTL: TimeInterval = 30 * 24 * 60 * 60 // 30 days

    init(apiClient: APIClient, wordRepository: WordRepository, wordnikApiKey: String? = nil) {
        self.apiClient = apiClient
        self.wordRepository = wordRepository
        self.wordnikApiKey = wordnikApiKey
    }
    
    func updateWordnikKey(_ key: String?) {
        self.wordnikApiKey = key
    }

    func lookup(word: String) async throws -> WordEntity {
        // 1. Check Cache
        let normalizedWord = word.lowercased().trimmingCharacters(in: .whitespaces)
        if let cached = try await wordRepository.searchWords(query: normalizedWord).first(where: { $0.word.lowercased() == normalizedWord }) {
            let age = Date().timeIntervalSince(cached.updatedAt)
            if age < cacheTTL {
                return cached
            }
        }

        // 2. Concurrent Fetch
        async let fdResponse = try? apiClient.send(FreeDictionaryRequest(word: normalizedWord))
        async let wiktionaryResponse = try? apiClient.send(WiktionaryRequest(word: normalizedWord))
        
        var wordnikTask: Task<WordEntity?, Never>?
        if let key = wordnikApiKey, !key.isEmpty {
            wordnikTask = Task {
                async let defs = try? apiClient.send(WordnikDefinitionRequest(word: normalizedWord, apiKey: key))
                async let exs = try? apiClient.send(WordnikExampleRequest(word: normalizedWord, apiKey: key))
                
                let (d, e) = await (defs, exs)
                var entity = d?.normalize()
                if let examples = e?.examples {
                    let mappedExamples = examples.map { WordEntity.Example(text: $0.text, source: "Wordnik", isAIGenerated: false) }
                    // Update entity with examples
                    if let old = entity {
                        entity = WordEntity(id: old.id, word: old.word, phonetic: old.phonetic, definitions: old.definitions, examples: mappedExamples, synonyms: old.synonyms, antonyms: old.antonyms, etymology: old.etymology, otherForms: old.otherForms, aiMnemonic: old.aiMnemonic, userNotes: old.userNotes, sources: old.sources, createdAt: old.createdAt, updatedAt: old.updatedAt)
                    }
                }
                return entity
            }
        }

        let (fd, wikt, wordnik) = await (fdResponse, wiktionaryResponse, wordnikTask?.value)

        // 3. Normalize & Merge
        let fdEntity = fd?.normalize()
        let wiktEntity = wikt?.normalize()

        guard fdEntity != nil || wiktEntity != nil || wordnik != nil else {
            throw APIError.noData
        }

        let mergedEntity = merge(fd: fdEntity, wikt: wiktEntity, wordnik: wordnik, originalWord: normalizedWord)

        // 4. Cache Result
        try await wordRepository.saveWord(mergedEntity)

        return mergedEntity
    }

    private func merge(fd: WordEntity?, wikt: WordEntity?, wordnik: WordEntity?, originalWord: String) -> WordEntity {
        // Priority: Wordnik > Free Dictionary > Wiktionary
        
        let id = wordnik?.id ?? fd?.id ?? wikt?.id ?? UUID()
        let word = wordnik?.word.isEmpty == false ? wordnik!.word : (fd?.word.isEmpty == false ? fd!.word : originalWord)
        let phonetic = fd?.phonetic ?? wikt?.phonetic
        
        var definitions: [WordEntity.Definition] = []
        var seenDefinitions = Set<String>()
        
        // Helper to add unique definitions
        func addUnique(from source: [WordEntity.Definition]) {
            for def in source {
                let key = def.text.lowercased().trimmingCharacters(in: .whitespaces)
                if !seenDefinitions.contains(key) {
                    definitions.append(def)
                    seenDefinitions.insert(key)
                }
            }
        }
        
        if let wordnik = wordnik { addUnique(from: wordnik.definitions) }
        if let fd = fd { addUnique(from: fd.definitions) }
        if let wikt = wikt { addUnique(from: wikt.definitions) }
        
        var examples: [WordEntity.Example] = []
        var seenExamples = Set<String>()
        
        func addUniqueExamples(from source: [WordEntity.Example]) {
            for ex in source {
                let key = ex.text.lowercased().trimmingCharacters(in: .whitespaces)
                if !seenExamples.contains(key) {
                    examples.append(ex)
                    seenExamples.insert(key)
                }
            }
        }
        
        if let wordnik = wordnik { addUniqueExamples(from: wordnik.examples) }
        if let fd = fd { addUniqueExamples(from: fd.examples) }
        if let wikt = wikt { addUniqueExamples(from: wikt.examples) }
        
        let synonyms = Array(Set((fd?.synonyms ?? []) + (wikt?.synonyms ?? []) + (wordnik?.synonyms ?? [])))
        let antonyms = Array(Set((fd?.antonyms ?? []) + (wikt?.antonyms ?? []) + (wordnik?.antonyms ?? [])))
        let etymology = wordnik?.etymology ?? fd?.etymology ?? wikt?.etymology
        let sources = Array(Set((fd?.sources ?? []) + (wikt?.sources ?? []) + (wordnik?.sources ?? [])))

        return WordEntity(
            id: id,
            word: word,
            phonetic: phonetic,
            definitions: definitions,
            examples: examples,
            synonyms: synonyms,
            antonyms: antonyms,
            etymology: etymology,
            otherForms: wordnik?.otherForms ?? fd?.otherForms ?? wikt?.otherForms ?? [],
            aiMnemonic: nil,
            userNotes: nil,
            sources: sources,
            createdAt: wordnik?.createdAt ?? fd?.createdAt ?? wikt?.createdAt ?? Date(),
            updatedAt: Date()
        )
    }
}
