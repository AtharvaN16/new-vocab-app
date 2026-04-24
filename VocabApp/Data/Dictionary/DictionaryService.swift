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
        let normalizedWord = word.lowercased().trimmingCharacters(in: .whitespaces)
        print("🔍 Dictionary lookup started for: \(normalizedWord)")

        // 1. Check Cache
        do {
            if let cached = try await wordRepository.searchWords(query: normalizedWord).first(where: { $0.word.lowercased() == normalizedWord }) {
                let age = Date().timeIntervalSince(cached.updatedAt)
                if age < cacheTTL {
                    print("✅ Cache hit for: \(normalizedWord)")
                    return cached
                }
                print("⏳ Cache expired for: \(normalizedWord)")
            }
        } catch {
            print("⚠️ Cache fetch error: \(error)")
        }

        // 2. Concurrent Fetch with TaskGroup for better control
        let result = await withTaskGroup(of: WordEntity?.self) { group in
            // Free Dictionary Task
            group.addTask {
                do {
                    let response = try await self.apiClient.send(FreeDictionaryRequest(word: normalizedWord))
                    return response.normalize()
                } catch {
                    print("❌ FreeDictionary error: \(error)")
                    return nil
                }
            }
            
            // Wiktionary Task
            group.addTask {
                do {
                    let response = try await self.apiClient.send(WiktionaryRequest(word: normalizedWord))
                    let entity = response.normalize()
                    // Wiktionary DTO doesn't have the word in the body, so we set it from the query
                    return WordEntity(
                        id: entity.id, word: normalizedWord, phonetic: entity.phonetic,
                        definitions: entity.definitions, examples: entity.examples,
                        synonyms: entity.synonyms, antonyms: entity.antonyms,
                        etymology: entity.etymology, otherForms: entity.otherForms,
                        aiMnemonic: entity.aiMnemonic, userNotes: entity.userNotes,
                        sources: entity.sources, createdAt: entity.createdAt, updatedAt: entity.updatedAt
                    )
                } catch {
                    print("❌ Wiktionary error: \(error)")
                    return nil
                }
            }
            
            // Wordnik Task
            if let key = wordnikApiKey, !key.isEmpty {
                group.addTask {
                    do {
                        async let defs = self.apiClient.send(WordnikDefinitionRequest(word: normalizedWord, apiKey: key))
                        async let exs = self.apiClient.send(WordnikExampleRequest(word: normalizedWord, apiKey: key))
                        
                        let (d, e) = try await (defs, exs)
                        var entity = d.normalize()
                        // Wordnik DTO normalize returns empty word, set it
                        entity = WordEntity(
                            id: entity.id, word: normalizedWord, phonetic: entity.phonetic,
                            definitions: entity.definitions, examples: entity.examples,
                            synonyms: entity.synonyms, antonyms: entity.antonyms,
                            etymology: entity.etymology, otherForms: entity.otherForms,
                            aiMnemonic: entity.aiMnemonic, userNotes: entity.userNotes,
                            sources: entity.sources, createdAt: entity.createdAt, updatedAt: entity.updatedAt
                        )
                        
                        if let examples = e.examples.prefix(5).map({ WordEntity.Example(text: $0.text, source: "Wordnik", isAIGenerated: false) }) as [WordEntity.Example]?, !examples.isEmpty {
                            entity = WordEntity(
                                id: entity.id, word: entity.word, phonetic: entity.phonetic,
                                definitions: entity.definitions, examples: examples,
                                synonyms: entity.synonyms, antonyms: entity.antonyms,
                                etymology: entity.etymology, otherForms: entity.otherForms,
                                aiMnemonic: entity.aiMnemonic, userNotes: entity.userNotes,
                                sources: entity.sources, createdAt: entity.createdAt, updatedAt: entity.updatedAt
                            )
                        }
                        return entity
                    } catch {
                        print("❌ Wordnik error: \(error)")
                        return nil
                    }
                }
            }
            
            var entities: [WordEntity] = []
            for await entity in group {
                if let entity = entity {
                    entities.append(entity)
                }
            }
            return entities
        }

        guard !result.isEmpty else {
            print("❌ No data found across all APIs for: \(normalizedWord)")
            throw APIError.noData
        }

        // 3. Merge
        let mergedEntity = mergeResults(result, originalWord: normalizedWord)
        print("✅ Lookup successful for: \(normalizedWord)")

        // 4. Cache Result
        do {
            try await wordRepository.saveWord(mergedEntity)
        } catch {
            print("⚠️ Cache save error: \(error)")
        }

        return mergedEntity
    }

    private func mergeResults(_ entities: [WordEntity], originalWord: String) -> WordEntity {
        // Priority by source or just combine
        let main = entities.first { $0.sources.contains("Wordnik") } ?? 
                   entities.first { $0.sources.contains("Free Dictionary API") } ?? 
                   entities.first!
        
        var allDefinitions: [WordEntity.Definition] = []
        var allExamples: [WordEntity.Example] = []
        var seenDefs = Set<String>()
        var seenExs = Set<String>()
        
        for entity in entities {
            for def in entity.definitions {
                let key = def.text.lowercased().trimmingCharacters(in: .whitespaces)
                if !seenDefs.contains(key) {
                    allDefinitions.append(def)
                    seenDefs.insert(key)
                }
            }
            for ex in entity.examples {
                let key = ex.text.lowercased().trimmingCharacters(in: .whitespaces)
                if !seenExs.contains(key) {
                    allExamples.append(ex)
                    seenExs.insert(key)
                }
            }
        }
        
        let synonyms = Array(Set(entities.flatMap { $0.synonyms }))
        let antonyms = Array(Set(entities.flatMap { $0.antonyms }))
        let sources = Array(Set(entities.flatMap { $0.sources }))

        return WordEntity(
            id: main.id,
            word: main.word.isEmpty ? originalWord : main.word,
            phonetic: entities.first(where: { $0.phonetic != nil })?.phonetic,
            definitions: allDefinitions,
            examples: allExamples,
            synonyms: synonyms,
            antonyms: antonyms,
            etymology: entities.first(where: { $0.etymology != nil })?.etymology,
            otherForms: Array(Set(entities.flatMap { $0.otherForms })),
            aiMnemonic: nil,
            userNotes: nil,
            sources: sources,
            createdAt: main.createdAt,
            updatedAt: Date()
        )
    }
}
