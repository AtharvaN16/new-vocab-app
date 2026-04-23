import Foundation

protocol DictionaryRepository {
    /// Performs a multi-tier lookup for a word. 
    /// Checks local cache first, then aggregates from multiple APIs.
    func lookup(word: String) async throws -> WordEntity
}
