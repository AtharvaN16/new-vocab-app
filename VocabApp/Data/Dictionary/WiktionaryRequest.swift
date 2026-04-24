import Foundation

struct WiktionaryRequest: APIRequest {
    typealias Response = WiktionaryResponse
    let word: String
    
    var url: URL? {
        let encodedWord = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word
        return URL(string: "https://en.wiktionary.org/api/rest_v1/page/definition/\(encodedWord)")
    }
    
    var method: HTTPMethod { .get }
}
