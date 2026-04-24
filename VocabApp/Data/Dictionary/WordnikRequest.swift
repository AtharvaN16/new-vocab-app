import Foundation

struct WordnikDefinitionRequest: APIRequest {
    typealias Response = [WordnikDefinition]
    let word: String
    let apiKey: String
    
    var url: URL? {
        let encodedWord = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word
        return URL(string: "https://api.wordnik.com/v4/word.json/\(encodedWord)/definitions?limit=5&includeRelated=false&useCanonical=false&includeTags=false&api_key=\(apiKey)")
    }
    
    var method: HTTPMethod { .get }
}

struct WordnikExampleRequest: APIRequest {
    typealias Response = WordnikExampleResponse
    let word: String
    let apiKey: String
    
    var url: URL? {
        let encodedWord = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word
        return URL(string: "https://api.wordnik.com/v4/word.json/\(encodedWord)/examples?includeDuplicates=false&useCanonical=false&limit=5&api_key=\(apiKey)")
    }
    
    var method: HTTPMethod { .get }
}
