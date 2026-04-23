import Foundation

protocol WordRepository {
    func fetchWords() async throws -> [WordEntity]
    func fetchWord(id: UUID) async throws -> WordEntity?
    func saveWord(_ word: WordEntity) async throws
    func deleteWord(id: UUID) async throws
    func searchWords(query: String) async throws -> [WordEntity]
}
