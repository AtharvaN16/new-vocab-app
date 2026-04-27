import XCTest
@testable import VocabApp

final class WordnikRelatedWordsTests: XCTestCase {

    func test_parse_synonymsAndAntonyms() throws {
        let json = """
        [
            {"relationshipType":"synonym","words":["transient","fleeting","momentary"]},
            {"relationshipType":"antonym","words":["permanent","lasting"]}
        ]
        """
        let rels = try JSONDecoder().decode([WordnikRelationship].self, from: json.data(using: .utf8)!)
        XCTAssertEqual(rels.synonyms(), ["transient", "fleeting", "momentary"])
        XCTAssertEqual(rels.antonyms(), ["permanent", "lasting"])
    }

    func test_parse_missingRelationshipReturnsEmpty() throws {
        let json = #"[{"relationshipType":"antonym","words":["permanent"]}]"#
        let rels = try JSONDecoder().decode([WordnikRelationship].self, from: json.data(using: .utf8)!)
        XCTAssertEqual(rels.synonyms(), [])
        XCTAssertEqual(rels.antonyms(), ["permanent"])
    }

    func test_relatedWordsRequest_urlContainsRequiredParams() {
        let req = WordnikRelatedWordsRequest(word: "ephemeral", apiKey: "testkey")
        let url = req.url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("/relatedWords"))
        XCTAssertTrue(url.contains("synonym"))
        XCTAssertTrue(url.contains("antonym"))
        XCTAssertTrue(url.contains("testkey"))
    }
}
