import Foundation
import SwiftUI

@Observable
final class PracticeSessionViewModel {
    struct ReviewItem: Identifiable {
        let id = UUID()
        let word: WordEntity
        var card: SRSCardEntity
        var isFlipped: Bool = false
    }
    
    var items: [ReviewItem] = []
    var currentIndex: Int = 0
    var isFinished: Bool = false
    var isLoading: Bool = true
    
    private let wordRepository: WordRepository
    private let srsRepository: SRSRepository
    private let wordIds: [UUID]?
    private let engine = FSRSEngine()

    init(wordRepository: WordRepository, srsRepository: SRSRepository, wordIds: [UUID]? = nil) {
        self.wordRepository = wordRepository
        self.srsRepository = srsRepository
        self.wordIds = wordIds
        
        Task {
            await loadSession()
        }
    }

    @MainActor
    func loadSession() async {
        isLoading = true
        do {
            let dueCards: [SRSCardEntity]
            if let filterIds = wordIds {
                dueCards = try await srsRepository.fetchDueCards(asOf: Date(), for: filterIds)
            } else {
                dueCards = try await srsRepository.fetchDueCards(asOf: Date())
            }
            
            var sessionItems: [ReviewItem] = []
            
            for card in dueCards {
                if let word = try await wordRepository.fetchWord(id: card.wordId) {
                    sessionItems.append(ReviewItem(word: word, card: card))
                }
            }
            
            self.items = sessionItems.shuffled()
            self.isLoading = false
            if items.isEmpty {
                isFinished = true
            }
        } catch {
            print("Error loading practice session: \(error)")
            isLoading = false
        }
    }

    @MainActor
    func rateCurrentCard(_ rating: FSRSEngine.Rating) async {
        guard currentIndex < items.count else { return }
        
        let item = items[currentIndex]
        let updatedCard = engine.repeatCard(item.card, rating: rating)
        
        do {
            try await srsRepository.updateCard(updatedCard)
            try await srsRepository.logReview(cardId: updatedCard.id, rating: rating.rawValue, state: updatedCard.state.rawValue)
            
            if currentIndex + 1 < items.count {
                withAnimation {
                    currentIndex += 1
                }
            } else {
                withAnimation {
                    isFinished = true
                }
            }
        } catch {
            print("Error updating card: \(error)")
        }
    }
    
    var currentItem: ReviewItem? {
        guard currentIndex < items.count else { return nil }
        return items[currentIndex]
    }
    
    var progress: Double {
        guard !items.isEmpty else { return 0 }
        return Double(currentIndex) / Double(items.count)
    }
}
