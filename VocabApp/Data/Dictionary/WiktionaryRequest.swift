import Foundation

struct WiktionaryRequest: APIRequest {
    typealias Response = WiktionaryResponse
    let word: String
    
    var url: URL? {
        URL(string: "https://en.wiktionary.org/api/rest_v1/page/definition/\(word)")
    }
    
    var method: HTTPMethod { .get }
}
