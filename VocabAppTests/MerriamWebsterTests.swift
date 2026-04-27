import XCTest
@testable import VocabApp

final class MerriamWebsterTests: XCTestCase {

    private let sampleJSON = """
    [{
        "hwi": {
            "hw": "ephem*er*al",
            "prs": [{"ipa": "i-ˈfe-mə-rəl", "sound": {"audio": "epheme01"}}]
        },
        "et": [["text", "from {it}Greek{/it} ephemeros, from {it}epi-{/it} + {it}hemera{/it} day"]]
    }]
    """

    func test_normalize_extractsIPA() throws {
        let entries = try JSONDecoder().decode([MerriamWebsterEntry].self, from: sampleJSON.data(using: .utf8)!)
        XCTAssertEqual(entries.normalize(word: "ephemeral").phonetic, "i-ˈfe-mə-rəl")
    }

    func test_normalize_stripsMarkupFromEtymology() throws {
        let entries = try JSONDecoder().decode([MerriamWebsterEntry].self, from: sampleJSON.data(using: .utf8)!)
        let entity = entries.normalize(word: "ephemeral")
        XCTAssertNotNil(entity.etymology)
        XCTAssertFalse(entity.etymology!.contains("{it}"))
        XCTAssertTrue(entity.etymology!.contains("Greek"))
    }

    func test_normalize_buildsAudioURL() throws {
        let entries = try JSONDecoder().decode([MerriamWebsterEntry].self, from: sampleJSON.data(using: .utf8)!)
        XCTAssertEqual(
            entries.normalize(word: "ephemeral").audioURL,
            "https://media.merriam-webster.com/audio/prons/en/us/mp3/e/epheme01.mp3"
        )
    }

    func test_normalize_emptyArray_returnsEmptyEntity() throws {
        let entries = try JSONDecoder().decode([MerriamWebsterEntry].self, from: "[]".data(using: .utf8)!)
        let entity = entries.normalize(word: "xyz")
        XCTAssertNil(entity.phonetic)
        XCTAssertNil(entity.etymology)
        XCTAssertNil(entity.audioURL)
    }

    func test_audioSubdirectory_bixPrefix() {
        XCTAssertEqual(MerriamWebsterAudioURL.subdirectory(for: "bixword"), "bix")
    }

    func test_audioSubdirectory_ggPrefix() {
        XCTAssertEqual(MerriamWebsterAudioURL.subdirectory(for: "ggword"), "gg")
    }

    func test_audioSubdirectory_digitPrefix() {
        XCTAssertEqual(MerriamWebsterAudioURL.subdirectory(for: "1word"), "number")
    }

    func test_audioSubdirectory_normalWord() {
        XCTAssertEqual(MerriamWebsterAudioURL.subdirectory(for: "epheme01"), "e")
    }

    func test_request_urlContainsWordAndKey() {
        let req = MerriamWebsterRequest(word: "ephemeral", apiKey: "testkey")
        let url = req.url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("ephemeral"))
        XCTAssertTrue(url.contains("key=testkey"))
        XCTAssertTrue(url.contains("collegiate"))
    }
}
