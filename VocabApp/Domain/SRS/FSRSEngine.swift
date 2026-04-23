import Foundation

/// A simplified Swift implementation of the FSRS v5 algorithm.
/// Based on the official FSRS specification.
struct FSRSEngine {
    // FSRS v5 Default Weights
    private let w: [Double] = [
        0.4, 0.6, 2.4, 5.8, 4.93, 0.94, 0.86, 0.01, 1.49, 0.14, 0.94, 2.18, 0.05, 0.34, 1.26, 0.29, 2.61
    ]
    
    enum Rating: Int {
        case again = 1
        case hard = 2
        case good = 3
        case easy = 4
    }
    
    func createEmptyCard(now: Date = Date()) -> SRSCardEntity {
        return SRSCardEntity(
            id: UUID(),
            wordId: UUID(), // To be set by caller
            due: now,
            stability: 0,
            difficulty: 0,
            elapsedDays: 0,
            scheduledDays: 0,
            reps: 0,
            lapses: 0,
            state: .new,
            lastReview: nil,
            updatedAt: now
        )
    }
    
    func repeatCard(_ card: SRSCardEntity, rating: Rating, now: Date = Date()) -> SRSCardEntity {
        var updatedCard = card
        let elapsedDays = card.lastReview == nil ? 0 : Int(now.timeIntervalSince(card.lastReview!) / 86400)
        
        updatedCard.elapsedDays = elapsedDays
        updatedCard.lastReview = now
        updatedCard.reps += 1
        
        switch card.state {
        case .new:
            updatedCard.state = (rating == .easy) ? .review : .learning
            updatedCard.stability = initStability(rating)
            updatedCard.difficulty = initDifficulty(rating)
            
        case .learning, .relearning:
            if rating == .good || rating == .easy {
                updatedCard.state = .review
                updatedCard.stability = initStability(rating) // Simplified
                updatedCard.difficulty = initDifficulty(rating)
            } else {
                updatedCard.lapses += 1
            }
            
        case .review:
            let interval = Double(elapsedDays)
            let retrievability = exp(log(0.9) * interval / card.stability)
            
            if rating == .again {
                updatedCard.state = .relearning
                updatedCard.lapses += 1
                updatedCard.stability = nextForgetStability(card.stability, retrievability)
                updatedCard.difficulty = nextDifficulty(card.difficulty, rating)
            } else {
                updatedCard.stability = nextRecallStability(card.stability, card.difficulty, retrievability, rating)
                updatedCard.difficulty = nextDifficulty(card.difficulty, rating)
            }
        }
        
        updatedCard.difficulty = max(1.0, min(10.0, updatedCard.difficulty))
        
        // Calculate interval (scheduled days)
        if updatedCard.state == .review {
            let interval = updatedCard.stability * log(0.9) / log(0.9) // Simplified: stability is roughly the 90% retention interval
            updatedCard.scheduledDays = Int(round(max(1.0, interval)))
            
            // Special case from old app: Easy on new card capped at 3 days
            if rating == .easy && card.reps == 0 {
                updatedCard.scheduledDays = min(updatedCard.scheduledDays, 3)
            }
        } else {
            updatedCard.scheduledDays = 0 // Review again in minutes/hours (not handled in days)
        }
        
        // Update due date
        let calendar = Calendar.current
        if updatedCard.scheduledDays > 0 {
            updatedCard.due = calendar.date(byAdding: .day, value: updatedCard.scheduledDays, to: now) ?? now
        } else {
            // Learning/Relearning: due in 10 minutes
            updatedCard.due = now.addingTimeInterval(600)
        }
        
        updatedCard.updatedAt = now
        return updatedCard
    }
    
    // MARK: - Internal Formulas
    
    private func initStability(_ rating: Rating) -> Double {
        return max(0.1, w[rating.rawValue - 1])
    }
    
    private func initDifficulty(_ rating: Rating) -> Double {
        return max(1.0, min(10.0, w[4] - Double(rating.rawValue - 3) * w[5]))
    }
    
    private func nextDifficulty(_ d: Double, _ rating: Rating) -> Double {
        let nextD = d - w[6] * Double(rating.rawValue - 3)
        return w[7] * initDifficulty(.good) + (1 - w[7]) * nextD
    }
    
    private func nextRecallStability(_ s: Double, _ d: Double, _ r: Double, _ rating: Rating) -> Double {
        let hardPenalty = (rating == .hard) ? w[15] : 1.0
        let easyBonus = (rating == .easy) ? w[16] : 1.0
        return s * (1 + exp(w[8]) * (11 - d) * pow(s, -w[9]) * (exp(w[10] * (1 - r)) - 1) * hardPenalty * easyBonus)
    }
    
    private func nextForgetStability(_ s: Double, _ r: Double) -> Double {
        return w[11] * pow(s, -w[12]) * (exp(w[13] * (1 - r)) - 1) + 0.1
    }
}
