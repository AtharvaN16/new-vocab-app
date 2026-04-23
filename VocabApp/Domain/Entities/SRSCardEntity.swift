import Foundation

/// Spaced Repetition state for a word, based on FSRS v5 properties.
struct SRSCardEntity: Identifiable, Codable, Equatable {
    let id: UUID
    let wordId: UUID
    
    // FSRS State
    var due: Date
    var stability: Double
    var difficulty: Double
    var elapsedDays: Int
    var scheduledDays: Int
    var reps: Int
    var lapses: Int
    var state: SRSState
    var lastReview: Date?
    
    var updatedAt: Date
    
    enum SRSState: String, Codable {
        case new = "New"
        case learning = "Learning"
        case review = "Review"
        case relearning = "Relearning"
    }
}
