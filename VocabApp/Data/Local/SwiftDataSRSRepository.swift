import Foundation
import SwiftData

final class SwiftDataSRSRepository: SRSRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @MainActor
    func fetchDueCards(asOf date: Date) async throws -> [SRSCardEntity] {
        let descriptor = FetchDescriptor<SRSCardSD>(
            predicate: #Predicate { $0.due <= date },
            sortBy: [SortDescriptor(\.due)]
        )
        let cards = try modelContext.fetch(descriptor)
        return cards.map { $0.toDomain() }
    }

    @MainActor
    func fetchDueCards(asOf date: Date, for wordIds: [UUID]) async throws -> [SRSCardEntity] {
        let descriptor = FetchDescriptor<SRSCardSD>(
            predicate: #Predicate { card in
                card.due <= date && wordIds.contains(card.wordId)
            },
            sortBy: [SortDescriptor(\.due)]
        )
        let cards = try modelContext.fetch(descriptor)
        return cards.map { $0.toDomain() }
    }

    @MainActor
    func fetchCard(for wordId: UUID) async throws -> SRSCardEntity? {
        let descriptor = FetchDescriptor<SRSCardSD>(predicate: #Predicate { $0.wordId == wordId })
        let card = try modelContext.fetch(descriptor).first
        return card?.toDomain()
    }

    @MainActor
    func updateCard(_ card: SRSCardEntity) async throws {
        let id = card.id
        let descriptor = FetchDescriptor<SRSCardSD>(predicate: #Predicate { $0.id == id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.due = card.due
            existing.stability = card.stability
            existing.difficulty = card.difficulty
            existing.elapsedDays = card.elapsedDays
            existing.scheduledDays = card.scheduledDays
            existing.reps = card.reps
            existing.lapses = card.lapses
            existing.stateString = card.state.rawValue
            existing.lastReview = card.lastReview
            existing.updatedAt = card.updatedAt
        } else {
            let newCard = SRSCardSD(from: card)
            modelContext.insert(newCard)
        }
        try modelContext.save()
    }

    @MainActor
    func logReview(cardId: UUID, rating: Int, state: String) async throws {
        let log = ReviewLogSD(cardId: cardId, rating: rating, state: state)
        modelContext.insert(log)
        try modelContext.save()
    }

    @MainActor
    func fetchReviewCount(since date: Date) async throws -> Int {
        let descriptor = FetchDescriptor<ReviewLogSD>(
            predicate: #Predicate { $0.createdAt >= date }
        )
        return try modelContext.fetchCount(descriptor)
    }

    @MainActor
    func enrollWords(_ wordIds: [UUID]) async throws {
        for wordId in wordIds {
            let id = wordId
            let descriptor = FetchDescriptor<SRSCardSD>(predicate: #Predicate { $0.wordId == id })
            let existing = try modelContext.fetch(descriptor)
            guard existing.isEmpty else { continue }
            let card = SRSCardEntity(
                id: UUID(),
                wordId: wordId,
                due: Date(),
                stability: 0,
                difficulty: 0,
                elapsedDays: 0,
                scheduledDays: 0,
                reps: 0,
                lapses: 0,
                state: .new,
                lastReview: nil,
                updatedAt: Date()
            )
            modelContext.insert(SRSCardSD(from: card))
        }
        try modelContext.save()
    }

    @MainActor
    func fetchStats() async throws -> SRSStats {
        let descriptor = FetchDescriptor<SRSCardSD>()
        let allCards = try modelContext.fetch(descriptor)
        
        var newCount = 0
        var learningCount = 0
        var reviewCount = 0
        var relearningCount = 0
        
        for card in allCards {
            switch card.stateString {
            case SRSCardEntity.SRSState.new.rawValue: newCount += 1
            case SRSCardEntity.SRSState.learning.rawValue: learningCount += 1
            case SRSCardEntity.SRSState.review.rawValue: reviewCount += 1
            case SRSCardEntity.SRSState.relearning.rawValue: relearningCount += 1
            default: break
            }
        }
        
        return SRSStats(
            newCount: newCount,
            learningCount: learningCount,
            reviewCount: reviewCount,
            relearningCount: relearningCount
        )
    }
}
