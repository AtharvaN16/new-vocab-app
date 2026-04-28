import Foundation

protocol SRSRepository {
    func fetchDueCards(asOf date: Date) async throws -> [SRSCardEntity]
    func fetchDueCards(asOf date: Date, for wordIds: [UUID]) async throws -> [SRSCardEntity]
    func fetchCard(for wordId: UUID) async throws -> SRSCardEntity?
    func updateCard(_ card: SRSCardEntity) async throws
    func logReview(cardId: UUID, rating: Int, state: String) async throws
    func fetchStats() async throws -> SRSStats
    func fetchReviewCount(since date: Date) async throws -> Int
    func enrollWords(_ wordIds: [UUID]) async throws
}

struct SRSStats {
    let newCount: Int
    let learningCount: Int
    let reviewCount: Int
    let relearningCount: Int
}
