import Foundation

final class DictionaryService: DictionaryRepository {
    private let apiClient: APIClient
    private let wordRepository: WordRepository
    private var wordnikApiKey: String?
    private var merriamWebsterApiKey: String?
    private var aiRepository: AIRepository?
    private let cacheTTL: TimeInterval = 30 * 24 * 60 * 60 // 30 days

    init(
        apiClient: APIClient,
        wordRepository: WordRepository,
        wordnikApiKey: String? = nil,
        merriamWebsterApiKey: String? = nil,
        aiRepository: AIRepository? = nil
    ) {
        self.apiClient = apiClient
        self.wordRepository = wordRepository
        self.wordnikApiKey = wordnikApiKey
        self.merriamWebsterApiKey = merriamWebsterApiKey
        self.aiRepository = aiRepository
    }

    func updateWordnikKey(_ key: String?) {
        self.wordnikApiKey = key
    }

    func updateMerriamWebsterKey(_ key: String?) {
        self.merriamWebsterApiKey = key
    }

    func updateAIRepository(_ repo: AIRepository?) {
        self.aiRepository = repo
    }

    func lookup(word: String) async throws -> WordEntity {
        let normalizedWord = word.lowercased().trimmingCharacters(in: .whitespaces)
        print("🔍 Dictionary lookup started for: \(normalizedWord)")

        // 1. Check Cache
        do {
            if let cached = try await wordRepository.searchWords(query: normalizedWord)
                .first(where: { $0.word.lowercased() == normalizedWord }) {
                let age = Date().timeIntervalSince(cached.updatedAt)
                if age < cacheTTL {
                    print("✅ Cache hit for: \(normalizedWord)")
                    if aiRepository != nil, cached.contextualNote == nil {
                        Task { await self.enrichContextualNote(cached) }
                    }
                    return cached
                }
                print("⏳ Cache expired for: \(normalizedWord)")
            }
        } catch {
            print("⚠️ Cache fetch error: \(error)")
        }

        // 2. Concurrent fetch — all sources run in parallel
        let result = await withTaskGroup(of: WordEntity?.self) { group in

            // Free Dictionary — phonetics, audio, definitions, examples, synonyms/antonyms
            group.addTask {
                do {
                    return try await self.apiClient.send(FreeDictionaryRequest(word: normalizedWord)).normalize()
                } catch {
                    print("❌ FreeDictionary error: \(error)")
                    return nil
                }
            }

            // Wiktionary — additional definitions + etymology
            group.addTask {
                do {
                    let entity = try await self.apiClient.send(WiktionaryRequest(word: normalizedWord)).normalize()
                    return WordEntity(
                        id: entity.id, word: normalizedWord, phonetic: entity.phonetic,
                        definitions: entity.definitions, examples: entity.examples,
                        synonyms: entity.synonyms, antonyms: entity.antonyms,
                        etymology: entity.etymology, otherForms: entity.otherForms,
                        sources: entity.sources, createdAt: entity.createdAt, updatedAt: entity.updatedAt
                    )
                } catch {
                    print("❌ Wiktionary error: \(error)")
                    return nil
                }
            }

            // Wordnik definitions + examples
            if let key = wordnikApiKey, !key.isEmpty {
                group.addTask {
                    do {
                        async let defs = self.apiClient.send(WordnikDefinitionRequest(word: normalizedWord, apiKey: key))
                        async let exs  = self.apiClient.send(WordnikExampleRequest(word: normalizedWord, apiKey: key))
                        let (d, e) = try await (defs, exs)
                        var entity = d.normalize()
                        entity = WordEntity(
                            id: entity.id, word: normalizedWord, phonetic: entity.phonetic,
                            definitions: entity.definitions,
                            examples: e.examples.prefix(5).map {
                                WordEntity.Example(text: $0.text, source: "Wordnik", isAIGenerated: false)
                            },
                            synonyms: entity.synonyms, antonyms: entity.antonyms,
                            etymology: entity.etymology, otherForms: entity.otherForms,
                            sources: entity.sources, createdAt: entity.createdAt, updatedAt: entity.updatedAt
                        )
                        return entity
                    } catch {
                        print("❌ Wordnik error: \(error)")
                        return nil
                    }
                }

                // Wordnik RelatedWords — synonyms & antonyms
                group.addTask {
                    do {
                        let rels = try await self.apiClient.send(
                            WordnikRelatedWordsRequest(word: normalizedWord, apiKey: key))
                        return WordEntity(
                            word: normalizedWord,
                            synonyms: rels.synonyms(),
                            antonyms: rels.antonyms(),
                            sources: ["Wordnik"]
                        )
                    } catch {
                        print("❌ Wordnik RelatedWords error: \(error)")
                        return nil
                    }
                }
            }

            // Datamuse — contextual synonyms, antonyms, hypernyms, hyponyms (no key)
            group.addTask {
                do {
                    async let synR  = self.apiClient.send(DatamuseRequest(word: normalizedWord, relation: .synonyms,  maxResults: 15))
                    async let antR  = self.apiClient.send(DatamuseRequest(word: normalizedWord, relation: .antonyms,  maxResults: 10))
                    async let hypeR = self.apiClient.send(DatamuseRequest(word: normalizedWord, relation: .hypernyms, maxResults: 5))
                    async let hypoR = self.apiClient.send(DatamuseRequest(word: normalizedWord, relation: .hyponyms,  maxResults: 5))
                    let (syn, ant, hype, hypo) = try await (synR, antR, hypeR, hypoR)
                    return WordEntity(
                        word: normalizedWord,
                        synonyms: syn.words() + hype.words(),
                        antonyms: ant.words() + hypo.words(),
                        sources: ["Datamuse"]
                    )
                } catch {
                    print("❌ Datamuse error: \(error)")
                    return nil
                }
            }

            // Merriam-Webster — etymology + IPA phonetics (user BYOK key)
            if let key = merriamWebsterApiKey, !key.isEmpty {
                group.addTask {
                    do {
                        let entries = try await self.apiClient.send(
                            MerriamWebsterRequest(word: normalizedWord, apiKey: key))
                        return entries.normalize(word: normalizedWord)
                    } catch {
                        print("❌ Merriam-Webster error: \(error)")
                        return nil
                    }
                }
            }

            var entities: [WordEntity] = []
            for await entity in group {
                if let entity { entities.append(entity) }
            }
            return entities
        }

        guard !result.isEmpty else {
            print("❌ No data found across all APIs for: \(normalizedWord)")
            throw APIError.noData
        }

        // 3. Merge + quality score
        let mergedEntity = mergeResults(result, originalWord: normalizedWord)
        print("✅ Lookup successful for: \(normalizedWord) (quality: \(mergedEntity.qualityScore)/8)")

        // 4. Cache
        do {
            try await wordRepository.saveWord(mergedEntity)
        } catch {
            print("⚠️ Cache save error: \(error)")
        }

        // 5. Background AI enrichment — fires after return, doesn't block caller
        if aiRepository != nil, mergedEntity.contextualNote == nil {
            Task { await self.enrichContextualNote(mergedEntity) }
        }

        return mergedEntity
    }

    private func collectStream(_ stream: AsyncThrowingStream<String, Error>) async throws -> String {
        var result = ""
        for try await chunk in stream { result += chunk }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func enrichContextualNote(_ entity: WordEntity) async {
        guard let ai = aiRepository else { return }
        do {
            let stream = try await ai.generateContent(for: entity.word, type: .contextHint)
            let note = try await collectStream(stream)
            guard !note.isEmpty else { return }

            let checker = WordQualityChecker()
            let enriched = WordEntity(
                id: entity.id, word: entity.word, phonetic: entity.phonetic,
                definitions: entity.definitions, examples: entity.examples,
                synonyms: entity.synonyms, antonyms: entity.antonyms,
                etymology: entity.etymology, otherForms: entity.otherForms,
                aiMnemonic: entity.aiMnemonic, userNotes: entity.userNotes,
                sources: entity.sources, createdAt: entity.createdAt, updatedAt: Date(),
                audioURL: entity.audioURL, syllables: entity.syllables,
                register: entity.register, contextualNote: note,
                qualityScore: 0
            )
            let scored = WordEntity(
                id: enriched.id, word: enriched.word, phonetic: enriched.phonetic,
                definitions: enriched.definitions, examples: enriched.examples,
                synonyms: enriched.synonyms, antonyms: enriched.antonyms,
                etymology: enriched.etymology, otherForms: enriched.otherForms,
                aiMnemonic: enriched.aiMnemonic, userNotes: enriched.userNotes,
                sources: enriched.sources, createdAt: enriched.createdAt, updatedAt: enriched.updatedAt,
                audioURL: enriched.audioURL, syllables: enriched.syllables,
                register: enriched.register, contextualNote: enriched.contextualNote,
                qualityScore: checker.score(enriched)
            )
            try await wordRepository.saveWord(scored)
            print("✅ AI contextual note saved for: \(entity.word) (quality: \(scored.qualityScore)/8)")
        } catch {
            print("⚠️ AI enrichment failed for \(entity.word): \(error)")
        }
    }

    private func mergeResults(_ entities: [WordEntity], originalWord: String) -> WordEntity {
        let checker = WordQualityChecker()

        // Source priority for single-value fields: M-W > Wordnik > Free Dict > others
        let mw       = entities.first { $0.sources.contains("Merriam-Webster") }
        let wordnik  = entities.first { $0.sources.contains("Wordnik") }
        let freeDict = entities.first { $0.sources.contains("Free Dictionary API") }
        let primary  = mw ?? wordnik ?? freeDict ?? entities[0]

        // Deduplicated definitions
        var seenDefs = Set<String>()
        let allDefinitions: [WordEntity.Definition] = entities.flatMap(\.definitions).filter {
            seenDefs.insert($0.text.lowercased()).inserted
        }

        // Deduplicated examples
        var seenExs = Set<String>()
        let allExamples: [WordEntity.Example] = entities.flatMap(\.examples).filter {
            seenExs.insert($0.text.lowercased()).inserted
        }

        let synonyms = Array(Set(entities.flatMap(\.synonyms)))
        let antonyms = Array(Set(entities.flatMap(\.antonyms)))
        let sources  = Array(Set(entities.flatMap(\.sources)))

        // Field priority: prefer M-W for phonetic/audio/etymology; fall back to any non-nil source
        let phonetic = mw?.phonetic
                    ?? freeDict?.phonetic
                    ?? entities.first(where: { $0.phonetic != nil })?.phonetic

        let audioURL = freeDict?.audioURL
                    ?? mw?.audioURL
                    ?? entities.first(where: { $0.audioURL != nil })?.audioURL

        let etymology = mw?.etymology
                     ?? entities.first(where: { $0.etymology != nil })?.etymology

        let merged = WordEntity(
            id: primary.id,
            word: primary.word.isEmpty ? originalWord : primary.word,
            phonetic: phonetic,
            definitions: allDefinitions,
            examples: allExamples,
            synonyms: synonyms,
            antonyms: antonyms,
            etymology: etymology,
            otherForms: Array(Set(entities.flatMap(\.otherForms))),
            sources: sources,
            createdAt: primary.createdAt,
            updatedAt: Date(),
            audioURL: audioURL,
            qualityScore: 0
        )

        return WordEntity(
            id: merged.id, word: merged.word, phonetic: merged.phonetic,
            definitions: merged.definitions, examples: merged.examples,
            synonyms: merged.synonyms, antonyms: merged.antonyms,
            etymology: merged.etymology, otherForms: merged.otherForms,
            sources: merged.sources, createdAt: merged.createdAt, updatedAt: merged.updatedAt,
            audioURL: merged.audioURL, syllables: merged.syllables,
            register: merged.register, contextualNote: merged.contextualNote,
            qualityScore: checker.score(merged)
        )
    }
}
