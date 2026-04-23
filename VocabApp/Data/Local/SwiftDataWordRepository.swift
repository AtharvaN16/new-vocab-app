import Foundation
import SwiftData

final class SwiftDataWordRepository: WordRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @MainActor
    func fetchWords() async throws -> [WordEntity] {
        let descriptor = FetchDescriptor<WordSD>(sortBy: [SortDescriptor(\.word)])
        let words = try modelContext.fetch(descriptor)
        return words.map { $0.toDomain() }
    }

    @MainActor
    func fetchWord(id: UUID) async throws -> WordEntity? {
        let descriptor = FetchDescriptor<WordSD>(predicate: #Predicate { $0.id == id })
        let word = try modelContext.fetch(descriptor).first
        return word?.toDomain()
    }

    @MainActor
    func saveWord(_ word: WordEntity) async throws {
        // Check if exists
        let id = word.id
        let descriptor = FetchDescriptor<WordSD>(predicate: #Predicate { $0.id == id })
        if let existing = try modelContext.fetch(descriptor).first {
            // Update existing (manually or by re-init if allowed)
            // For now, simpler to delete and re-insert if macro supports it, 
            // but usually we update fields.
            existing.word = word.word
            existing.phonetic = word.phonetic
            existing.synonyms = word.synonyms
            existing.antonyms = word.antonyms
            existing.etymology = word.etymology
            existing.aiMnemonic = word.aiMnemonic
            existing.userNotes = word.userNotes
            existing.updatedAt = word.updatedAt
            
            let encoder = JSONEncoder()
            existing.definitionsData = (try? encoder.encode(word.definitions)) ?? Data()
            existing.examplesData = (try? encoder.encode(word.examples)) ?? Data()
            existing.otherFormsData = (try? encoder.encode(word.otherForms)) ?? Data()
        } else {
            let newWord = WordSD(from: word)
            modelContext.insert(newWord)
            
            // Create initial SRS card
            let engine = FSRSEngine()
            let initialCardEntity = engine.createEmptyCard(now: word.createdAt)
            let card = SRSCardSD(from: initialCardEntity)
            card.wordId = word.id
            modelContext.insert(card)
        }
        try modelContext.save()
    }

    @MainActor
    func deleteWord(id: UUID) async throws {
        let descriptor = FetchDescriptor<WordSD>(predicate: #Predicate { $0.id == id })
        if let word = try modelContext.fetch(descriptor).first {
            modelContext.delete(word)
            try modelContext.save()
        }
    }

    @MainActor
    func searchWords(query: String) async throws -> [WordEntity] {
        let descriptor = FetchDescriptor<WordSD>(
            predicate: #Predicate { $0.word.contains(query) },
            sortBy: [SortDescriptor(\.word)]
        )
        let words = try modelContext.fetch(descriptor)
        return words.map { $0.toDomain() }
    }
}
