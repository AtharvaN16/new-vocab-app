import Foundation
import SwiftUI

@Observable
final class CollectionDetailViewModel {
    var collection: CollectionEntity
    var words: [WordEntity] = []
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
            var fetchedWords: [WordEntity] = []
            for id in collection.wordIds {
                if let word = try await wordRepository.fetchWord(id: id) {
                    fetchedWords.append(word)
                }
            }
            self.words = fetchedWords.sorted(by: { $0.word < $1.word })
            self.isLoading = false
        } catch {
            print("Error loading collection words: \(error)")
            self.isLoading = false
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
}
