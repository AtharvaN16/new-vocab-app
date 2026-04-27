import XCTest
@testable import VocabApp

final class FreeDictionaryNormalizerTests: XCTestCase {

    private let json = """
    [{
        "word": "ephemeral",
        "phonetic": "/ɪˈfɛm.ər.əl/",
        "phonetics": [
            {"text": "/ɪˈfɛm.ər.əl/", "audio": ""},
            {"text": "/ɪˈfɛm.ər.əl/", "audio": "https://api.dictionaryapi.dev/media/pronunciations/en/ephemeral-us.mp3"}
        ],
        "meanings": [{
            "partOfSpeech": "adjective",
            "definitions": [{"definition": "Lasting for a very short time.", "example": "fashions are ephemeral"}],
            "synonyms": ["transient"], "antonyms": ["permanent"]
        }],
        "sourceUrls": ["https://en.wiktionary.org/wiki/ephemeral"]
    }]
    """

    func test_normalize_capturesFirstNonEmptyAudioURL() throws {
        let response = try JSONDecoder().decode(FreeDictionaryResponse.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(response.normalize().audioURL,
                       "https://api.dictionaryapi.dev/media/pronunciations/en/ephemeral-us.mp3")
    }

    func test_normalize_nilAudioURL_whenAllEmpty() throws {
        let j = """
        [{"word":"t","phonetics":[{"audio":""},{"audio":null}],"meanings":[]}]
        """
        let response = try JSONDecoder().decode(FreeDictionaryResponse.self, from: j.data(using: .utf8)!)
        XCTAssertNil(response.normalize().audioURL)
    }

    func test_normalize_retainsPhonetic() throws {
        let response = try JSONDecoder().decode(FreeDictionaryResponse.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(response.normalize().phonetic, "/ɪˈfɛm.ər.əl/")
    }
}
