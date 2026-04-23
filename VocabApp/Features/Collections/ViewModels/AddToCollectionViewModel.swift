import Foundation
import SwiftUI

@Observable
final class AddToCollectionViewModel {
    let word: WordEntity
    var collections: [CollectionEntity] = []
    var isLoading: Bool = false
    
    private let collectionRepository: CollectionRepository

    init(word: WordEntity, collectionRepository: CollectionRepository) {
        self.word = word
        self.collectionRepository = collectionRepository
        
        Task {
            await loadCollections()
        }
    }

    @MainActor
    func loadCollections() async {
        isLoading = true
        do {
            self.collections = try await collectionRepository.fetchCollections()
            self.isLoading = false
        } catch {
            print("Error loading collections: \(error)")
            self.isLoading = false
        }
    }

    func isWordInCollection(_ collection: CollectionEntity) -> Bool {
        return collection.wordIds.contains(word.id)
    }

    @MainActor
    func toggleCollection(_ collection: CollectionEntity) async {
        do {
            if isWordInCollection(collection) {
                try await collectionRepository.removeWordFromCollection(wordId: word.id, collectionId: collection.id)
            } else {
                try await collectionRepository.addWordToCollection(wordId: word.id, collectionId: collection.id)
            }
            await loadCollections()
            
            // Trigger haptic
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        } catch {
            print("Error toggling collection: \(error)")
        }
    }
}
