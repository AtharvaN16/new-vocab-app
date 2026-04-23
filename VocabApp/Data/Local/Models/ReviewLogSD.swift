import Foundation
import SwiftData

@Model
final class ReviewLogSD {
    @Attribute(.unique) var id: UUID
    var cardId: UUID
    var rating: Int
    var state: String
    var createdAt: Date

    init(cardId: UUID, rating: Int, state: String, createdAt: Date = Date()) {
        self.id = UUID()
        self.cardId = cardId
        self.rating = rating
        self.state = state
        self.createdAt = createdAt
    }
}
