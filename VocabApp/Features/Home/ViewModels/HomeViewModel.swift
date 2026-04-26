import Foundation
import SwiftUI

@Observable
final class HomeViewModel {
    var words: [WordEntity] = []
    var collections: [CollectionEntity] = []
    var currentIndex: Int = 0
    var isExpanded: Bool = false
    var isLoading: Bool = false
    var showAddToCollection: Bool = false
    var showSearch: Bool = false
    
    // Toast state
    var showToast: Bool = false
    var toastMessage: String = ""

    private let wordRepository: WordRepository
    let collectionRepository: CollectionRepository

    init(wordRepository: WordRepository, collectionRepository: CollectionRepository) {
        self.wordRepository = wordRepository
        self.collectionRepository = collectionRepository
        Task { await loadData() }
    }

    var currentWord: WordEntity? {
        guard !words.isEmpty, currentIndex < words.count else { return nil }
        return words[currentIndex]
    }

    private var favoritesCollection: CollectionEntity? {
        collections.first { $0.name == "Favorites" }
    }
    
    private var bookmarkedCollection: CollectionEntity? {
        collections.first { $0.name == "Bookmarked" }
    }

    var isCurrentWordFavorited: Bool {
        guard let word = currentWord, let fav = favoritesCollection else { return false }
        return fav.wordIds.contains(word.id)
    }

    @MainActor
    func loadData() async {
        // Prevent redundant loading if we already have words
        guard words.isEmpty || isLoading else { return }
        
        isLoading = true
        do {
            let allWords = try await wordRepository.fetchWords()
            collections = try await collectionRepository.fetchCollections()
            
            // Get all word IDs that are in at least one collection
            let savedWordIds = Set(collections.flatMap { $0.wordIds })
            
            words = allWords.filter { savedWordIds.contains($0.id) }
                .sorted { $0.createdAt < $1.createdAt }
            
            clampIndex()
        } catch {
            print("HomeViewModel load error: \(error)")
        }
        isLoading = false
    }

    private func clampIndex() {
        if words.isEmpty {
            currentIndex = 0
        } else if currentIndex >= words.count {
            currentIndex = words.count - 1
        }
    }

    func navigateNext() {
        guard !words.isEmpty else { return }
        currentIndex = (currentIndex + 1) % words.count
    }

    func navigatePrevious() {
        guard !words.isEmpty else { return }
        currentIndex = (currentIndex - 1 + words.count) % words.count
    }

    @MainActor
    func addToFavorites() async {
        guard let word = currentWord, let fav = favoritesCollection else { return }
        guard !fav.wordIds.contains(word.id) else { return }
        do {
            try await collectionRepository.addWordToCollection(wordId: word.id, collectionId: fav.id)
            collections = try await collectionRepository.fetchCollections()
        } catch {
            print("Add to favorites error: \(error)")
        }
    }

    @MainActor
    func removeFromFavorites() async {
        guard let word = currentWord, let fav = favoritesCollection else { return }
        do {
            try await collectionRepository.removeWordFromCollection(wordId: word.id, collectionId: fav.id)
            collections = try await collectionRepository.fetchCollections()
        } catch {
            print("Remove from favorites error: \(error)")
        }
    }
    
    @MainActor
    func saveToDefaultCollection() async {
        guard let word = currentWord else { return }
        
        // Find or create "Bookmarked" collection
        var targetCollection = bookmarkedCollection
        
        if targetCollection == nil {
            do {
                targetCollection = try await collectionRepository.createCollection(name: "Bookmarked", colorHex: "#F59E0B")
            } catch {
                print("Error creating Bookmarked collection: \(error)")
            }
        }
        
        guard let collection = targetCollection else { return }
        
        do {
            if !collection.wordIds.contains(word.id) {
                try await collectionRepository.addWordToCollection(wordId: word.id, collectionId: collection.id)
                collections = try await collectionRepository.fetchCollections()
            }
            
            toastMessage = "Saved to Bookmark"
            withAnimation(.spring()) {
                showToast = true
            }
            
            // Auto hide after 3 seconds
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation(.spring()) {
                // Check if it's still the same message to avoid hiding a newer toast
                if toastMessage == "Saved to Bookmark" {
                    showToast = false
                }
            }
        } catch {
            print("Error saving to default collection: \(error)")
        }
    }

    @MainActor
    func undoSaveToDefaultCollection() async {
        guard let word = currentWord, let bookmarked = bookmarkedCollection else { return }
        do {
            try await collectionRepository.removeWordFromCollection(wordId: word.id, collectionId: bookmarked.id)
            collections = try await collectionRepository.fetchCollections()
            withAnimation(.spring()) {
                showToast = false
            }
        } catch {
            print("Error undoing save to default collection: \(error)")
        }
    }
}
