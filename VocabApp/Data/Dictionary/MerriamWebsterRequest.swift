import Foundation

struct MerriamWebsterRequest: APIRequest {
    typealias Response = [MerriamWebsterEntry]
    let word: String
    let apiKey: String

    var url: URL? {
        let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word
        return URL(string: "https://www.dictionaryapi.com/api/v3/references/collegiate/json/\(encoded)?key=\(apiKey)")
    }

    var method: HTTPMethod { .get }
}
