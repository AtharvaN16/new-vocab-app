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
    var lastActionWasLoop: Bool = false

    // Toast state
    var showToast: Bool = false
    var toastMessage: String = ""

    let collectionRepository: CollectionRepository
    private let dictionaryRepository: DictionaryRepository
    private let srsRepository: SRSRepository
    private let dailyWordsUseCase = DailyWordsUseCase()

    init(collectionRepository: CollectionRepository, dictionaryRepository: DictionaryRepository, srsRepository: SRSRepository) {
        self.collectionRepository = collectionRepository
        self.dictionaryRepository = dictionaryRepository
        self.srsRepository = srsRepository
        Task { await loadData() }
    }

    var currentWord: WordEntity? {
        guard !words.isEmpty else { return nil }
        let index = currentIndex % words.count
        return words[index >= 0 ? index : index + words.count]
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

    var isCurrentWordBookmarked: Bool {
        guard let word = currentWord, let bm = bookmarkedCollection else { return false }
        return bm.wordIds.contains(word.id)
    }

    @MainActor
    func loadData() async {
        // On re-appear, just refresh collection state so bookmark/fav indicators stay accurate
        guard words.isEmpty else {
            await refreshCollections()
            return
        }
        isLoading = true
        let wordStrings = dailyWordsUseCase.wordsForToday()
        collections = (try? await collectionRepository.fetchCollections()) ?? []

        var loadedResults: [Int: WordEntity] = [:]
        await withTaskGroup(of: (Int, WordEntity?).self) { group in
            for (index, wordString) in wordStrings.enumerated() {
                group.addTask { [dictionaryRepository] in
                    let entity = try? await dictionaryRepository.lookup(word: wordString)
                    return (index, entity)
                }
            }
            for await (index, result) in group {
                if let entity = result { loadedResults[index] = entity }
            }
        }
        
        // Sort by original index to preserve order
        words = wordStrings.indices.compactMap { loadedResults[$0] }
        isLoading = false
    }

    @MainActor
    func refreshCollections() async {
        collections = (try? await collectionRepository.fetchCollections()) ?? []
    }

    func navigateNext() {
        guard !words.isEmpty else { return }
        if currentIndex >= words.count - 1 {
            currentIndex = 0
            lastActionWasLoop = true
        } else {
            currentIndex += 1
            lastActionWasLoop = false
        }
    }

    func navigatePrevious() {
        guard !words.isEmpty else { return }
        if currentIndex <= 0 {
            currentIndex = words.count - 1
        } else {
            currentIndex -= 1
        }
        lastActionWasLoop = false
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
                do { try await srsRepository.enrollWords([word.id]) } catch { print("SRS enrollment error: \(error)") }
                collections = try await collectionRepository.fetchCollections()
            }

            toastMessage = "Saved to Bookmark"
            withAnimation(.spring()) {
                showToast = true
            }

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation(.spring()) {
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
