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

struct WordnikRelatedWordsRequest: APIRequest {
    typealias Response = [WordnikRelationship]
    let word: String
    let apiKey: String

    var url: URL? {
        let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word
        // %2C = percent-encoded comma for the relationship types list
        return URL(string: "https://api.wordnik.com/v4/word.json/\(encoded)/relatedWords"
            + "?useCanonical=false&relationshipTypes=synonym%2Cantonym"
            + "&limitPerRelationshipType=10&api_key=\(apiKey)")
    }

    var method: HTTPMethod { .get }
}
