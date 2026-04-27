import XCTest
@testable import VocabApp

final class WordQualityCheckerTests: XCTestCase {
    private let checker = WordQualityChecker()

    private func entity(
        defs: Int = 0, phonetic: String? = nil, audioURL: String? = nil,
        examples: Int = 0, synonyms: Int = 0, antonyms: Int = 0,
        etymology: String? = nil, contextualNote: String? = nil
    ) -> WordEntity {
        WordEntity(
            word: "test",
            phonetic: phonetic,
            definitions: (0..<defs).map { WordEntity.Definition(text: "d\($0)", partOfSpeech: "noun", source: "t") },
            examples: (0..<examples).map { WordEntity.Example(text: "e\($0)", source: "t", isAIGenerated: false) },
            synonyms: (0..<synonyms).map { "s\($0)" },
            antonyms: (0..<antonyms).map { "a\($0)" },
            etymology: etymology,
            sources: ["test"],
            audioURL: audioURL,
            contextualNote: contextualNote
        )
    }

    func test_score_bareWord_isZero() {
        XCTAssertEqual(checker.score(entity()), 0)
    }

    func test_score_completeWord_isEight() {
        let e = entity(defs: 2, phonetic: "/t/", audioURL: "https://ex.com/t.mp3",
                       examples: 2, synonyms: 3, antonyms: 1,
                       etymology: "From Latin", contextualNote: "formal")
        XCTAssertEqual(checker.score(e), 8)
        XCTAssertTrue(checker.isComplete(e))
    }

    func test_score_countsOnlyPresentFields() {
        let e = entity(phonetic: "/t/", audioURL: "https://ex.com/t.mp3", synonyms: 3)
        XCTAssertEqual(checker.score(e), 3)
        XCTAssertFalse(checker.isComplete(e))
    }

    func test_synonymThreshold_requiresThreeNotTwo() {
        XCTAssertEqual(checker.score(entity(synonyms: 2)), 0)
        XCTAssertEqual(checker.score(entity(synonyms: 3)), 1)
    }

    func test_missingFields_returnsCorrectSet() {
        let e = entity(phonetic: "/t/", audioURL: "https://ex.com/t.mp3")
        let missing = Set(checker.missingFields(e))
        XCTAssertFalse(missing.contains(.phonetic))
        XCTAssertFalse(missing.contains(.audioURL))
        XCTAssertTrue(missing.contains(.definitions))
        XCTAssertTrue(missing.contains(.examples))
        XCTAssertTrue(missing.contains(.synonyms))
        XCTAssertTrue(missing.contains(.antonyms))
        XCTAssertTrue(missing.contains(.etymology))
        XCTAssertTrue(missing.contains(.contextualNote))
    }
}
