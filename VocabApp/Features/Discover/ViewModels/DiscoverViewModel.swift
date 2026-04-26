import Foundation
import SwiftUI
import Combine

@Observable
@MainActor
final class DiscoverViewModel {
    var searchText: String = "" {
        didSet {
            if searchText.isEmpty {
                recommendations = []
                searchResult = nil
            } else {
                performLocalSearch()
            }
        }
    }
    var searchResult: WordEntity?
    var recommendations: [WordEntity] = []
    var isLoading: Bool = false
    var errorMessage: String?
    
    var collections: [CollectionEntity] = []
    
    private let dictionaryRepository: DictionaryRepository
    private let wordRepository: WordRepository
    private let collectionRepository: CollectionRepository
    private var searchTask: Task<Void, Never>?
    private var localSearchTask: Task<Void, Never>?

    init(
        dictionaryRepository: DictionaryRepository,
        wordRepository: WordRepository,
        collectionRepository: CollectionRepository
    ) {
        self.dictionaryRepository = dictionaryRepository
        self.wordRepository = wordRepository
        self.collectionRepository = collectionRepository
        
        Task { 
            await ensureSystemCollections()
            await loadCollections() 
        }
    }

    @MainActor
    private func ensureSystemCollections() async {
        do {
            let existing = try await collectionRepository.fetchCollections()
            if !existing.contains(where: { $0.name == "Favorites" }) {
                _ = try await collectionRepository.createCollection(name: "Favorites", colorHex: "#FF2D55")
            }
            if !existing.contains(where: { $0.name == "Bookmarked" }) {
                _ = try await collectionRepository.createCollection(name: "Bookmarked", colorHex: "#F59E0B")
            }
        } catch {
            print("Error ensuring system collections: \(error)")
        }
    }

    @MainActor
    func loadCollections() async {
        do {
            self.collections = try await collectionRepository.fetchCollections()
        } catch {
            print("Error loading collections: \(error)")
        }
    }

    var quickAddCollections: [CollectionEntity] {
        let systemNames = ["Favorites", "Bookmarked"]
        return collections
            .filter { !systemNames.contains($0.name) }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(3)
            .map { $0 }
    }

    var isFavorited: Bool {
        guard let word = searchResult, 
              let fav = collections.first(where: { $0.name == "Favorites" }) else { return false }
        return fav.wordIds.contains(word.id)
    }

    var isBookmarked: Bool {
        guard let word = searchResult, 
              let bookmark = collections.first(where: { $0.name == "Bookmarked" }) else { return false }
        return bookmark.wordIds.contains(word.id)
    }

    func toggleFavorite() async {
        guard let word = searchResult,
              let fav = collections.first(where: { $0.name == "Favorites" }) else { return }
        
        do {
            try await wordRepository.saveWord(word)
            if fav.wordIds.contains(word.id) {
                try await collectionRepository.removeWordFromCollection(wordId: word.id, collectionId: fav.id)
            } else {
                try await collectionRepository.addWordToCollection(wordId: word.id, collectionId: fav.id)
            }
            await loadCollections()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch {
            print("Toggle favorite error: \(error)")
        }
    }

    func toggleBookmark() async {
        guard let word = searchResult,
              let bookmark = collections.first(where: { $0.name == "Bookmarked" }) else { return }
        
        do {
            try await wordRepository.saveWord(word)
            if bookmark.wordIds.contains(word.id) {
                try await collectionRepository.removeWordFromCollection(wordId: word.id, collectionId: bookmark.id)
            } else {
                try await collectionRepository.addWordToCollection(wordId: word.id, collectionId: bookmark.id)
            }
            await loadCollections()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch {
            print("Toggle bookmark error: \(error)")
        }
    }

    func addToCollection(_ collection: CollectionEntity) async {
        guard let word = searchResult else { return }
        do {
            try await wordRepository.saveWord(word)
            try await collectionRepository.addWordToCollection(wordId: word.id, collectionId: collection.id)
            await loadCollections()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch {
            print("Add to collection error: \(error)")
        }
    }

    func isInCollection(_ collection: CollectionEntity) -> Bool {
        guard let word = searchResult else { return false }
        return collection.wordIds.contains(word.id)
    }

    func performLocalSearch() {
        localSearchTask?.cancel()
        
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            recommendations = []
            return
        }

        localSearchTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms debounce
            if Task.isCancelled { return }
            
            do {
                let localResults = try await wordRepository.searchWords(query: query)
                if !Task.isCancelled {
                    // Unique words, limit to 5
                    var uniqueWords: [WordEntity] = []
                    var seen = Set<String>()
                    for w in localResults {
                        let lower = w.word.lowercased()
                        if !seen.contains(lower) {
                            seen.insert(lower)
                            uniqueWords.append(w)
                        }
                    }
                    self.recommendations = Array(uniqueWords.prefix(5))
                }
            } catch {
                print("Local search error: \(error)")
            }
        }
    }

    func selectRecommendation(_ word: WordEntity) {
        searchText = word.word
        searchResult = word
        recommendations = []
        errorMessage = nil
        // Optional: Perform full API lookup if needed to refresh data,
        // but for now we just show the local one.
    }

    func performSearch() {
        searchTask?.cancel()
        recommendations = []
        
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResult = nil
            errorMessage = nil
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        searchTask = Task {
            defer {
                if !Task.isCancelled {
                    isLoading = false
                }
            }
            
            do {
                let result = try await dictionaryRepository.lookup(word: query)
                if !Task.isCancelled {
                    self.searchResult = result
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = "Could not find definition for '\(query)'"
                    self.searchResult = nil
                }
            }
        }
    }
}
