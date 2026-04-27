import Foundation

struct DatamuseRequest: APIRequest {
    typealias Response = DatamuseResponse

    enum Relation: String {
        case synonyms  = "rel_syn"
        case antonyms  = "rel_ant"
        case hypernyms = "rel_hype"
        case hyponyms  = "rel_hypo"
    }

    let word: String
    let relation: Relation
    let maxResults: Int

    var url: URL? {
        var components = URLComponents(string: "https://api.datamuse.com/words")
        components?.queryItems = [
            URLQueryItem(name: relation.rawValue, value: word),
            URLQueryItem(name: "max", value: "\(maxResults)")
        ]
        return components?.url
    }

    var method: HTTPMethod { .get }
}
