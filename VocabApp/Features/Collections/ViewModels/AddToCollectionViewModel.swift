import Foundation
import SwiftUI

@Observable
final class AddToCollectionViewModel {
    let word: WordEntity
    var collections: [CollectionEntity] = []
    var selectedCollectionIds: Set<UUID> = []
    var isLoading: Bool = false
    var showMessage: Bool = false
    var message: String = ""
    
    var systemCollections: [CollectionEntity] {
        collections.filter { $0.isSystem }.sorted { $0.name < $1.name }
    }
    
    var userCollections: [CollectionEntity] {
        collections.filter { !$0.isSystem }.sorted { $0.createdAt > $1.createdAt }
    }
    
    private let collectionRepository: CollectionRepository

    init(word: WordEntity, collectionRepository: CollectionRepository) {
        self.word = word
        self.collectionRepository = collectionRepository
        
        Task {
            await loadCollections()
            await autoBookmarkAndShowMessage()
        }
    }

    @MainActor
    private func autoBookmarkAndShowMessage() async {
        // Find "Bookmarked" collection
        if let bookmarkedCollection = collections.first(where: { $0.name == "Bookmarked" }) {
            if !isWordInCollection(bookmarkedCollection) {
                try? await collectionRepository.addWordToCollection(wordId: word.id, collectionId: bookmarkedCollection.id)
                await loadCollections()
            }
        }
    }

    @MainActor
    func loadCollections() async {
        isLoading = true
        do {
            let fetched = try await collectionRepository.fetchCollections()
            self.collections = fetched
            // Initialize selected IDs based on current status
            self.selectedCollectionIds = Set(fetched.filter { $0.wordIds.contains(word.id) }.map { $0.id })
            self.isLoading = false
        } catch {
            print("Error loading collections: \(error)")
            self.isLoading = false
        }
    }

    func isSelected(_ collection: CollectionEntity) -> Bool {
        selectedCollectionIds.contains(collection.id)
    }

    func isWordInCollection(_ collection: CollectionEntity) -> Bool {
        return collection.wordIds.contains(word.id)
    }

    func toggleSelection(_ collection: CollectionEntity) {
        withAnimation(Theme.Animation.snappy) {
            if selectedCollectionIds.contains(collection.id) {
                selectedCollectionIds.remove(collection.id)
            } else {
                selectedCollectionIds.insert(collection.id)
            }
        }
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    @MainActor
    func saveSelections() async throws {
        isLoading = true
        defer { isLoading = false }
        
        for collection in collections {
            let shouldBeIn = selectedCollectionIds.contains(collection.id)
            let isIn = isWordInCollection(collection)
            
            if shouldBeIn && !isIn {
                try await collectionRepository.addWordToCollection(wordId: word.id, collectionId: collection.id)
            } else if !shouldBeIn && isIn {
                try await collectionRepository.removeWordFromCollection(wordId: word.id, collectionId: collection.id)
            }
        }
        
        await loadCollections()
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    @MainActor
    func createCollection(name: String) async {
        do {
            let newCollection = try await collectionRepository.createCollection(name: name, colorHex: "#60A5FA")
            // Automatically select the new collection
            selectedCollectionIds.insert(newCollection.id)
            await loadCollections()
        } catch {
            print("Error creating collection: \(error)")
        }
    }
}
