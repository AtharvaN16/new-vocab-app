import Foundation
import SwiftData

@Model
final class SRSCardSD {
    @Attribute(.unique) var id: UUID
    var wordId: UUID
    
    // FSRS State
    var due: Date
    var stability: Double
    var difficulty: Double
    var elapsedDays: Int
    var scheduledDays: Int
    var reps: Int
    var lapses: Int
    var stateString: String
    var lastReview: Date?
    
    var updatedAt: Date

    init(from entity: SRSCardEntity) {
        self.id = entity.id
        self.wordId = entity.wordId
        self.due = entity.due
        self.stability = entity.stability
        self.difficulty = entity.difficulty
        self.elapsedDays = entity.elapsedDays
        self.scheduledDays = entity.scheduledDays
        self.reps = entity.reps
        self.lapses = entity.lapses
        self.stateString = entity.state.rawValue
        self.lastReview = entity.lastReview
        self.updatedAt = entity.updatedAt
    }

    func toDomain() -> SRSCardEntity {
        return SRSCardEntity(
            id: id,
            wordId: wordId,
            due: due,
            stability: stability,
            difficulty: difficulty,
            elapsedDays: elapsedDays,
            scheduledDays: scheduledDays,
            reps: reps,
            lapses: lapses,
            state: SRSCardEntity.SRSState(rawValue: stateString) ?? .new,
            lastReview: lastReview,
            updatedAt: updatedAt
        )
    }
}
