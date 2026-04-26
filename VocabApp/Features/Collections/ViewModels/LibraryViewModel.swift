import Foundation
import SwiftUI

@Observable
final class LibraryViewModel {
    var systemCollections: [CollectionEntity] = []
    var userCollections: [CollectionEntity] = []
    var isLoading: Bool = false
    var isEditing: Bool = false
    var collectionToDelete: CollectionEntity?

    private let collectionRepository: CollectionRepository

    init(collectionRepository: CollectionRepository) {
        self.collectionRepository = collectionRepository

        Task {
            await loadCollections()
        }
    }

    @MainActor
    func loadCollections() async {
        isLoading = true
        do {
            let all = try await collectionRepository.fetchCollections()
            let systemNames = ["Favorites", "Bookmarked"]

            self.systemCollections = all.filter { systemNames.contains($0.name) }
            self.userCollections = all.filter { !systemNames.contains($0.name) }
            self.isLoading = false
        } catch {
            print("Error loading collections: \(error)")
            self.isLoading = false
        }
    }

    @MainActor
    func createCollection(name: String, color: String = "#007AFF") async {
        do {
            _ = try await collectionRepository.createCollection(name: name, colorHex: color)
            await loadCollections()
        } catch {
            print("Error creating collection: \(error)")
        }
    }

    @MainActor
    func deleteCollection(_ collection: CollectionEntity) async {
        guard !collection.isSystem else { return }
        try? await collectionRepository.deleteCollection(id: collection.id)
        await loadCollections()
    }

    @MainActor
    func renameCollection(_ collection: CollectionEntity, to newName: String) async {
        guard !collection.isSystem, !newName.isEmpty else { return }
        var updated = collection
        updated.name = newName
        updated.updatedAt = Date()
        try? await collectionRepository.saveCollection(updated)
        await loadCollections()
    }
}
