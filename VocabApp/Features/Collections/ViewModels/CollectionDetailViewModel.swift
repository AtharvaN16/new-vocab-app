import Foundation
import SwiftUI

@Observable
final class CollectionDetailViewModel {
    struct StickerLayoutItem: Identifiable {
        let id: UUID
        let word: WordEntity
        let fontSize: CGFloat
        let rotation: Double
        let xOffset: CGFloat
        let yOffset: CGFloat
        let spansFullWidth: Bool
    }

    var collection: CollectionEntity
    var words: [WordEntity] = []
    var stickerLayouts: [StickerLayoutItem] = []
    var isLoading: Bool = false
    
    private let wordRepository: WordRepository
    private let collectionRepository: CollectionRepository
    private let srsRepository: SRSRepository

    init(
        collection: CollectionEntity,
        wordRepository: WordRepository,
        collectionRepository: CollectionRepository,
        srsRepository: SRSRepository
    ) {
        self.collection = collection
        self.wordRepository = wordRepository
        self.collectionRepository = collectionRepository
        self.srsRepository = srsRepository
        
        Task {
            await loadWords()
        }
    }

    @MainActor
    func loadWords() async {
        isLoading = true
        do {
            // Re-fetch collection to get updated wordIds
            let collections = try await collectionRepository.fetchCollections()
            if let updated = collections.first(where: { $0.id == collection.id }) {
                self.collection = updated
            }

            var fetchedWords: [WordEntity] = []
            for id in collection.wordIds {
                if let word = try await wordRepository.fetchWord(id: id) {
                    fetchedWords.append(word)
                }
            }
            self.words = fetchedWords.sorted(by: { $0.word < $1.word })
            generateStickerLayouts()
            self.isLoading = false
        } catch {
            print("Error loading collection words: \(error)")
            self.isLoading = false
        }
    }

    private func generateStickerLayouts() {
        var layouts: [StickerLayoutItem] = []
        for word in words {
            // Use the word's stable UUID as a seed for consistent randomization across sessions
            var generator = StableRandomGenerator(seed: word.id.uuidString.hashValue)

            let fontSize = CGFloat.random(in: 26...44, using: &generator)
            let rotation = Double.random(in: -6...6, using: &generator) // Subtler tilt
            let xOffset = CGFloat.random(in: -10...10, using: &generator)
            let yOffset = CGFloat.random(in: -5...5, using: &generator)

            // Span full width if font is large or word is long
            let spansFullWidth = fontSize > 38 || word.word.count > 9

            layouts.append(StickerLayoutItem(
                id: word.id,
                word: word,
                fontSize: fontSize,
                rotation: rotation,
                xOffset: xOffset,
                yOffset: yOffset,
                spansFullWidth: spansFullWidth
            ))
        }
        self.stickerLayouts = layouts
    }

    // Simple deterministic random number generator for stable layouts
    struct StableRandomGenerator: RandomNumberGenerator {
        private var state: UInt64
        init(seed: Int) { state = UInt64(bitPattern: Int64(seed)) }
        mutating func next() -> UInt64 {
            state = state &+ 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    @MainActor
    func deleteWord(at offsets: IndexSet) {
        let wordsToRemove = offsets.map { words[$0] }
        Task {
            for word in wordsToRemove {
                try? await collectionRepository.removeWordFromCollection(wordId: word.id, collectionId: collection.id)
            }
            await loadWords()
        }
    }

    @MainActor
    func removeWord(_ word: WordEntity) {
        Task {
            try? await collectionRepository.removeWordFromCollection(wordId: word.id, collectionId: collection.id)
            await loadWords()
        }
    }
}
