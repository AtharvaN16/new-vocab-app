import Foundation

struct FreeDictionaryRequest: APIRequest {
    typealias Response = FreeDictionaryResponse
    let word: String
    
    var url: URL? {
        URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(word)")
    }
    
    var method: HTTPMethod { .get }
}
