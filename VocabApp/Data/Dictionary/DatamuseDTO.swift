import Foundation

struct DatamuseWord: Decodable {
    let word: String
    let score: Int
}

typealias DatamuseResponse = [DatamuseWord]

extension DatamuseResponse {
    func words() -> [String] { map(\.word) }
}

struct DatamuseEnrichment {
    let synonyms: [String]
    let antonyms: [String]
    let hypernyms: [String]
    let hyponyms: [String]
}
