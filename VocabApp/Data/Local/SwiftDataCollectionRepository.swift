import Foundation
import SwiftData

final class SwiftDataCollectionRepository: CollectionRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @MainActor
    func fetchCollections() async throws -> [CollectionEntity] {
        let descriptor = FetchDescriptor<CollectionSD>(sortBy: [SortDescriptor(\.sortOrder)])
        let collections = try modelContext.fetch(descriptor)
        return collections.map { $0.toDomain() }
    }

    @MainActor
    func createCollection(name: String, colorHex: String) async throws -> CollectionEntity {
        // Find highest sortOrder
        let descriptor = FetchDescriptor<CollectionSD>(sortBy: [SortDescriptor(\.sortOrder, order: .reverse)])
        let existing = try modelContext.fetch(descriptor)
        let nextOrder = (existing.first?.sortOrder ?? -1) + 1

        let entity = CollectionEntity(
            id: UUID(),
            name: name,
            description: "",
            colorHex: colorHex,
            isPublic: false,
            isSystem: false,
            sortOrder: nextOrder,
            wordIds: [],
            createdAt: Date(),
            updatedAt: Date()
        )
        let collectionSD = CollectionSD(from: entity)
        modelContext.insert(collectionSD)
        try modelContext.save()
        return entity
    }

    @MainActor
    func saveCollection(_ collection: CollectionEntity) async throws {
        let id = collection.id
        let descriptor = FetchDescriptor<CollectionSD>(predicate: #Predicate { $0.id == id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.name = collection.name
            existing.desc = collection.description
            existing.colorHex = collection.colorHex
            existing.isPublic = collection.isPublic
            existing.updatedAt = collection.updatedAt
        } else {
            let newCollection = CollectionSD(from: collection)
            modelContext.insert(newCollection)
        }
        try modelContext.save()
    }

    @MainActor
    func deleteCollection(id: UUID) async throws {
        let descriptor = FetchDescriptor<CollectionSD>(predicate: #Predicate { $0.id == id })
        if let collection = try modelContext.fetch(descriptor).first {
            modelContext.delete(collection)
            try modelContext.save()
        }
    }

    @MainActor
    func addWordToCollection(wordId: UUID, collectionId: UUID) async throws {
        let wordDescriptor = FetchDescriptor<WordSD>(predicate: #Predicate { $0.id == wordId })
        let collectionDescriptor = FetchDescriptor<CollectionSD>(predicate: #Predicate { $0.id == collectionId })

        guard let word = try modelContext.fetch(wordDescriptor).first,
              let collection = try modelContext.fetch(collectionDescriptor).first else {
            return
        }

        if collection.words == nil { collection.words = [] }
        if !(collection.words?.contains(word) ?? false) {
            collection.words?.append(word)
            try modelContext.save()
        }
    }

    @MainActor
    func removeWordFromCollection(wordId: UUID, collectionId: UUID) async throws {
        let wordDescriptor = FetchDescriptor<WordSD>(predicate: #Predicate { $0.id == wordId })
        let collectionDescriptor = FetchDescriptor<CollectionSD>(predicate: #Predicate { $0.id == collectionId })

        guard let word = try modelContext.fetch(wordDescriptor).first,
              let collection = try modelContext.fetch(collectionDescriptor).first else {
            return
        }

        collection.words?.removeAll(where: { $0.id == word.id })
        try modelContext.save()
    }
}
