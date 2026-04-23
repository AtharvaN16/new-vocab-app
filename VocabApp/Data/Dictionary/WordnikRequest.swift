import Foundation

struct WordnikDefinitionRequest: APIRequest {
    typealias Response = [WordnikDefinition]
    let word: String
    let apiKey: String
    
    var url: URL? {
        URL(string: "https://api.wordnik.com/v4/word.json/\(word)/definitions?limit=5&includeRelated=false&useCanonical=false&includeTags=false&api_key=\(apiKey)")
    }
    
    var method: HTTPMethod { .get }
}

struct WordnikExampleRequest: APIRequest {
    typealias Response = WordnikExampleResponse
    let word: String
    let apiKey: String
    
    var url: URL? {
        URL(string: "https://api.wordnik.com/v4/word.json/\(word)/examples?includeDuplicates=false&useCanonical=false&limit=5&api_key=\(apiKey)")
    }
    
    var method: HTTPMethod { .get }
}
