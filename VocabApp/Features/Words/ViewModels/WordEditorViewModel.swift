import Foundation
import SwiftUI

@Observable
@MainActor
final class WordEditorViewModel {
    // Draft state for all editable fields
    var draftPhonetic: String
    var draftDefinitions: [WordEntity.Definition]
    var draftExamples: [WordEntity.Example]
    var draftSynonyms: [String]
    var draftAntonyms: [String]
    var draftEtymology: String
    var draftContextualNote: String

    // AI suggest state
    var suggestingField: WordField? = nil
    var suggestError: String? = nil

    // Save state
    var isSaving: Bool = false
    var saveError: String? = nil

    let original: WordEntity
    private let wordRepository: WordRepository
    let aiRepository: AIRepository

    init(word: WordEntity, wordRepository: WordRepository, aiRepository: AIRepository) {
        self.original = word
        self.wordRepository = wordRepository
        self.aiRepository = aiRepository
        self.draftPhonetic = word.phonetic ?? ""
        self.draftDefinitions = word.definitions
        self.draftExamples = word.examples
        self.draftSynonyms = word.synonyms
        self.draftAntonyms = word.antonyms
        self.draftEtymology = word.etymology ?? ""
        self.draftContextualNote = word.contextualNote ?? ""
    }

    var hasChanges: Bool {
        draftPhonetic != (original.phonetic ?? "")
            || draftDefinitions != original.definitions
            || draftExamples != original.examples
            || draftSynonyms != original.synonyms
            || draftAntonyms != original.antonyms
            || draftEtymology != (original.etymology ?? "")
            || draftContextualNote != (original.contextualNote ?? "")
    }

    func save() async throws {
        isSaving = true
        defer { isSaving = false }
        let checker = WordQualityChecker()
        let draft = WordEntity(
            id: original.id,
            word: original.word,
            phonetic: draftPhonetic.isEmpty ? nil : draftPhonetic,
            definitions: draftDefinitions,
            examples: draftExamples,
            synonyms: draftSynonyms,
            antonyms: draftAntonyms,
            etymology: draftEtymology.isEmpty ? nil : draftEtymology,
            otherForms: original.otherForms,
            aiMnemonic: original.aiMnemonic,
            userNotes: original.userNotes,
            sources: original.sources,
            createdAt: original.createdAt,
            updatedAt: Date(),
            audioURL: original.audioURL,
            syllables: original.syllables,
            register: original.register,
            contextualNote: draftContextualNote.isEmpty ? nil : draftContextualNote,
            qualityScore: 0
        )
        let scored = WordEntity(
            id: draft.id, word: draft.word, phonetic: draft.phonetic,
            definitions: draft.definitions, examples: draft.examples,
            synonyms: draft.synonyms, antonyms: draft.antonyms,
            etymology: draft.etymology, otherForms: draft.otherForms,
            aiMnemonic: draft.aiMnemonic, userNotes: draft.userNotes,
            sources: draft.sources, createdAt: draft.createdAt, updatedAt: draft.updatedAt,
            audioURL: draft.audioURL, syllables: draft.syllables,
            register: draft.register, contextualNote: draft.contextualNote,
            qualityScore: checker.score(draft)
        )
        try await wordRepository.saveWord(scored)
    }

    // MARK: - Field mutations

    func addDefinition(_ text: String, partOfSpeech: String = "") {
        guard !text.isEmpty else { return }
        draftDefinitions.append(WordEntity.Definition(text: text, partOfSpeech: partOfSpeech, source: "User"))
    }

    func removeDefinition(at offsets: IndexSet) {
        draftDefinitions.remove(atOffsets: offsets)
    }

    func addExample(_ text: String) {
        guard !text.isEmpty else { return }
        draftExamples.append(WordEntity.Example(text: text, source: "User", isAIGenerated: false))
    }

    func removeExample(at offsets: IndexSet) {
        draftExamples.remove(atOffsets: offsets)
    }

    func addSynonym(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !draftSynonyms.contains(trimmed) else { return }
        draftSynonyms.append(trimmed)
    }

    func removeSynonym(_ word: String) {
        draftSynonyms.removeAll { $0 == word }
    }

    func addAntonym(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !draftAntonyms.contains(trimmed) else { return }
        draftAntonyms.append(trimmed)
    }

    func removeAntonym(_ word: String) {
        draftAntonyms.removeAll { $0 == word }
    }

    // MARK: - AI suggest

    func suggestForField(_ field: WordField) async {
        guard suggestingField == nil else { return }
        suggestingField = field
        suggestError = nil
        defer { suggestingField = nil }

        let prompt = buildSuggestPrompt(for: field)
        guard !prompt.isEmpty else { return }

        do {
            let stream = try await aiRepository.generateContent(
                for: original.word,
                type: .editorSuggest(prompt: prompt)
            )
            var result = ""
            for try await chunk in stream { result += chunk }
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !result.isEmpty else { return }
            applySuggestion(result, for: field)
        } catch {
            suggestError = "AI suggest failed: \(error.localizedDescription)"
        }
    }

    private func applySuggestion(_ text: String, for field: WordField) {
        switch field {
        case .phonetic:
            draftPhonetic = text
        case .definitions:
            let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            for line in lines {
                draftDefinitions.append(WordEntity.Definition(text: line, partOfSpeech: "", source: "AI"))
            }
        case .examples:
            let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            for line in lines {
                let cleaned = line.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                draftExamples.append(WordEntity.Example(text: cleaned, source: "AI", isAIGenerated: true))
            }
        case .synonyms:
            let words = text.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty }
            for word in words where !draftSynonyms.contains(word) { draftSynonyms.append(word) }
        case .antonyms:
            let words = text.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty }
            for word in words where !draftAntonyms.contains(word) { draftAntonyms.append(word) }
        case .etymology:
            draftEtymology = text
        case .contextualNote:
            draftContextualNote = text
        case .audioURL:
            break
        }
    }

    private func buildSuggestPrompt(for field: WordField) -> String {
        switch field {
        case .phonetic:
            return "Rewrite the pronunciation of '\(original.word)' as simple phonetics readable by a non-linguist (e.g., SEP-uh-rayt style). Reply with just the phonetic string, nothing else."
        case .definitions:
            let existing = draftDefinitions.map(\.text).joined(separator: "; ")
            return "Give 2 additional clear definitions for '\(original.word)' not already in this list: \(existing). One definition per line. Start each line with the part of speech in parentheses."
        case .examples:
            return "Write 3 natural example sentences for '\(original.word)' — one academic, one casual, one literary. One sentence per line. No numbering."
        case .synonyms:
            let existing = draftSynonyms.joined(separator: ", ")
            return "List 5 synonyms for '\(original.word)' not in this list: \(existing). Reply with comma-separated words only."
        case .antonyms:
            return "List 3 antonyms for '\(original.word)'. Reply with comma-separated words only."
        case .etymology:
            return "Give a 2-sentence etymology of '\(original.word)': its language of origin and root meaning."
        case .contextualNote:
            return "In 2 sentences, describe how and when '\(original.word)' is typically used — without using the word itself or its direct definition."
        case .audioURL:
            return ""
        }
    }
}
