import Foundation
import SwiftUI

@Observable
final class LibraryViewModel {
    var systemCollections: [CollectionEntity] = []
    var userCollections: [CollectionEntity] = []
    var isLoading: Bool = false
    var isEditing: Bool = false
    var collectionToDelete: CollectionEntity?
    var draggingCollection: CollectionEntity?
    
    // Custom drag reordering state
    var draggedID: UUID?
    var dragOffset: CGFloat = 0

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
                .sorted { a, b in
                    if a.name == "Bookmarked" { return true }
                    if b.name == "Bookmarked" { return false }
                    return a.name < b.name
                }
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

    @MainActor
    func moveUserCollection(from source: IndexSet, to destination: Int) {
        userCollections.move(fromOffsets: source, toOffset: destination)
        
        // Sync to DB in background
        let updatedCollections = userCollections
        Task {
            for (index, collection) in updatedCollections.enumerated() {
                var updated = collection
                updated.sortOrder = index
                try? await collectionRepository.saveCollection(updated)
            }
        }
    }
}
