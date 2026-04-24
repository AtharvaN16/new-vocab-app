import Foundation

struct FreeDictionaryRequest: APIRequest {
    typealias Response = FreeDictionaryResponse
    let word: String
    
    var url: URL? {
        let encodedWord = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word
        return URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(encodedWord)")
    }
    
    var method: HTTPMethod { .get }
}
