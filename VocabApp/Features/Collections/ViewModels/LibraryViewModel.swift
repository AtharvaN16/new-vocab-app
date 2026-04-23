import Foundation
import SwiftUI

@Observable
final class LibraryViewModel {
    var systemCollections: [CollectionEntity] = []
    var userCollections: [CollectionEntity] = []
    var isLoading: Bool = false
    
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
        let newCollection = CollectionEntity(
            id: UUID(),
            name: name,
            description: "",
            colorHex: color,
            isPublic: false,
            isSystem: false,
            wordIds: [],
            createdAt: Date(),
            updatedAt: Date()
        )
        try? await collectionRepository.saveCollection(newCollection)
        await loadCollections()
    }
}
