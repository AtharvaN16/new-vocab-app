import Foundation
import SwiftUI
import Combine

@Observable
final class WordDetailViewModel {
    var word: WordEntity
    var isFavorited: Bool = false
    var isBookmarked: Bool = false
    var isExpanded: Bool = false
    var isGeneratingAI: Bool = false
    var showCollections: Bool = false
    
    // For navigation context
    private var wordIds: [UUID] = []
    private var currentIndex: Int = 0
    
    private let wordRepository: WordRepository
    private let collectionRepository: CollectionRepository
    private let srsRepository: SRSRepository
    private let aiRepository: AIRepository

    init(
        word: WordEntity,
        wordIds: [UUID] = [],
        wordRepository: WordRepository,
        collectionRepository: CollectionRepository,
        srsRepository: SRSRepository,
        aiRepository: AIRepository
    ) {
        self.word = word
        self.wordIds = wordIds
        self.wordRepository = wordRepository
        self.collectionRepository = collectionRepository
        self.srsRepository = srsRepository
        self.aiRepository = aiRepository
        
        if let index = wordIds.firstIndex(of: word.id) {
            self.currentIndex = index
        }
        
        Task {
            await checkStatus()
        }
    }

    @MainActor
    func generateMnemonic() async {
        guard !isGeneratingAI else { return }
        isGeneratingAI = true
        
        // Reset mnemonic to show "generating" state if UI depends on it
        // self.word = word.with(aiMnemonic: "")
        
        do {
            let stream = try await aiRepository.generateContent(for: word.word, type: .mnemonic)
            var fullMnemonic = ""
            
            for try await chunk in stream {
                fullMnemonic += chunk
                // Update word with partial mnemonic for real-time streaming feel
                let updatedWord = WordEntity(
                    id: word.id,
                    word: word.word,
                    phonetic: word.phonetic,
                    definitions: word.definitions,
                    examples: word.examples,
                    synonyms: word.synonyms,
                    antonyms: word.antonyms,
                    etymology: word.etymology,
                    otherForms: word.otherForms,
                    aiMnemonic: fullMnemonic,
                    userNotes: word.userNotes,
                    sources: word.sources,
                    createdAt: word.createdAt,
                    updatedAt: Date()
                )
                self.word = updatedWord
            }
            
            // Save to local repository once finished
            try await wordRepository.saveWord(self.word)
            isGeneratingAI = false
            triggerHaptic(.success)
        } catch {
            print("Error generating AI content: \(error)")
            isGeneratingAI = false
        }
    }

    @MainActor
    func checkStatus() async {
        // In a real app, we'd check if the word is in "Favorites" or "Bookmarked" collections.
        // For now, we'll simulate or use a simple check if we had those flags.
        // Let's assume we fetch collections and check wordIds.
        do {
            let collections = try await collectionRepository.fetchCollections()
            isFavorited = collections.first(where: { $0.name == "Favorites" })?.wordIds.contains(word.id) ?? false
            isBookmarked = collections.first(where: { $0.name == "Bookmarked" })?.wordIds.contains(word.id) ?? false
        } catch {
            print("Error checking status: \(error)")
        }
    }

    @MainActor
    func toggleFavorite() async {
        isFavorited.toggle()
        // TODO: Update collection repository
        triggerHaptic(.success)
    }

    @MainActor
    func toggleBookmark() async {
        isBookmarked.toggle()
        // TODO: Update collection repository
        triggerHaptic(.heavy)
    }

    @MainActor
    func navigateNext() async {
        guard !wordIds.isEmpty else { return }
        currentIndex = (currentIndex + 1) % wordIds.count
        await loadCurrentIndex()
    }

    @MainActor
    func navigatePrevious() async {
        guard !wordIds.isEmpty else { return }
        currentIndex = (currentIndex - 1 + wordIds.count) % wordIds.count
        await loadCurrentIndex()
    }

    @MainActor
    private func loadCurrentIndex() async {
        let id = wordIds[currentIndex]
        do {
            if let newWord = try await wordRepository.fetchWord(id: id) {
                self.word = newWord
                await checkStatus()
            }
        } catch {
            print("Error loading word: \(error)")
        }
    }

    private func triggerHaptic(_ style: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(style)
    }

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}
