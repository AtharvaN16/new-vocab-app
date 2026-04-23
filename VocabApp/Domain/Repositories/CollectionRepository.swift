import Foundation

protocol CollectionRepository {
    func fetchCollections() async throws -> [CollectionEntity]
    func saveCollection(_ collection: CollectionEntity) async throws
    func deleteCollection(id: UUID) async throws
    func addWordToCollection(wordId: UUID, collectionId: UUID) async throws
    func removeWordFromCollection(wordId: UUID, collectionId: UUID) async throws
}
