import XCTest
@testable import VocabApp

final class WordEntityTests: XCTestCase {

    // Reproduces every existing call site — only the 14 required params, none of the new ones.
    private func makeMinimal() -> WordEntity {
        WordEntity(
            id: UUID(),
            word: "ephemeral",
            phonetic: "/ɪˈfɛm.ər.əl/",
            definitions: [WordEntity.Definition(text: "Lasting a short time", partOfSpeech: "adjective", source: "t")],
            examples: [],
            synonyms: [],
            antonyms: [],
            etymology: nil,
            otherForms: [],
            aiMnemonic: nil,
            userNotes: nil,
            sources: ["test"],
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func test_newFields_defaultToNilOrEmpty() {
        let e = makeMinimal()
        XCTAssertNil(e.audioURL)
        XCTAssertEqual(e.syllables, [])
        XCTAssertNil(e.register)
        XCTAssertNil(e.contextualNote)
        XCTAssertEqual(e.qualityScore, 0)
    }

    func test_newFields_canBePassedExplicitly() {
        let e = WordEntity(
            id: UUID(), word: "ephemeral",
            phonetic: "/ɪˈfɛm.ər.əl/",
            definitions: [WordEntity.Definition(text: "Lasting a short time", partOfSpeech: "adjective", source: "t")],
            examples: [], synonyms: [], antonyms: [], etymology: nil,
            otherForms: [], aiMnemonic: nil, userNotes: nil,
            sources: ["test"], createdAt: Date(), updatedAt: Date(),
            audioURL: "https://example.com/ephemeral.mp3",
            syllables: ["e", "phem", "er", "al"],
            register: .literary,
            contextualNote: "Often used in poetry",
            qualityScore: 7
        )
        XCTAssertEqual(e.audioURL, "https://example.com/ephemeral.mp3")
        XCTAssertEqual(e.syllables, ["e", "phem", "er", "al"])
        XCTAssertEqual(e.register, .literary)
        XCTAssertEqual(e.contextualNote, "Often used in poetry")
        XCTAssertEqual(e.qualityScore, 7)
    }

    func test_wordRegister_rawValueRoundTrips() throws {
        let r = WordRegister.literary
        let encoded = try JSONEncoder().encode(r)
        let decoded = try JSONDecoder().decode(WordRegister.self, from: encoded)
        XCTAssertEqual(decoded, r)
    }
}
