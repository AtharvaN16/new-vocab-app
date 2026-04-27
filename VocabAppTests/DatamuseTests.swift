import XCTest
@testable import VocabApp

final class DatamuseTests: XCTestCase {

    func test_response_decodesWordList() throws {
        let json = #"[{"word":"transient","score":14521},{"word":"fleeting","score":9823}]"#
        let words = try JSONDecoder().decode(DatamuseResponse.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(words.words(), ["transient", "fleeting"])
    }

    func test_emptyResponse_returnsEmpty() throws {
        let words = try JSONDecoder().decode(DatamuseResponse.self, from: "[]".data(using: .utf8)!)
        XCTAssertEqual(words.words(), [])
    }

    func test_synonymRequest_buildsCorrectURL() {
        let url = DatamuseRequest(word: "ephemeral", relation: .synonyms, maxResults: 10).url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("rel_syn=ephemeral"))
        XCTAssertTrue(url.contains("max=10"))
    }

    func test_antonymRequest_buildsCorrectURL() {
        let url = DatamuseRequest(word: "ephemeral", relation: .antonyms, maxResults: 5).url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("rel_ant=ephemeral"))
    }

    func test_hypernymRequest_buildsCorrectURL() {
        let url = DatamuseRequest(word: "chair", relation: .hypernyms, maxResults: 5).url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("rel_hype=chair"))
    }

    func test_hyponymRequest_buildsCorrectURL() {
        let url = DatamuseRequest(word: "furniture", relation: .hyponyms, maxResults: 5).url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("rel_hypo=furniture"))
    }
}
