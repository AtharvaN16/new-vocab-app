import XCTest
import SwiftData
@testable import VocabApp

@MainActor
final class SRSEnrollmentTests: XCTestCase {
    var container: ModelContainer!
    var repository: SwiftDataSRSRepository!

    override func setUp() async throws {
        container = try ModelContainer(
            for: SRSCardSD.self, ReviewLogSD.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        repository = SwiftDataSRSRepository(modelContext: container.mainContext)
    }

    override func tearDown() async throws {
        container = nil
        repository = nil
    }

    func test_enrollWords_createsCard() async throws {
        let wordId = UUID()
        try await repository.enrollWords([wordId])
        let card = try await repository.fetchCard(for: wordId)
        XCTAssertNotNil(card)
    }

    func test_enrollWords_newCard_isInNewState() async throws {
        let wordId = UUID()
        try await repository.enrollWords([wordId])
        let card = try await repository.fetchCard(for: wordId)
        XCTAssertEqual(card?.state, .new)
    }

    func test_enrollWords_newCard_isDueNow() async throws {
        let before = Date()
        let wordId = UUID()
        try await repository.enrollWords([wordId])
        let card = try await repository.fetchCard(for: wordId)
        XCTAssertNotNil(card)
        XCTAssertLessThanOrEqual(card!.due, before.addingTimeInterval(5))
    }

    func test_enrollWords_idempotent() async throws {
        let wordId = UUID()
        try await repository.enrollWords([wordId])
        try await repository.enrollWords([wordId])
        let cards = try await repository.fetchDueCards(asOf: Date.distantFuture)
        XCTAssertEqual(cards.filter { $0.wordId == wordId }.count, 1)
    }

    func test_enrollWords_multipleWords_allCreated() async throws {
        let ids = [UUID(), UUID(), UUID()]
        try await repository.enrollWords(ids)
        for id in ids {
            let card = try await repository.fetchCard(for: id)
            XCTAssertNotNil(card)
        }
    }
}
