import Foundation
import SwiftData

@Model
final class CollectionSD {
    @Attribute(.unique) var id: UUID
    var name: String
    var desc: String // 'description' is a reserved property name in Swift
    var colorHex: String
    var isPublic: Bool
    var isSystem: Bool = false
    var createdAt: Date
    var updatedAt: Date
    
    // Relationship to words
    var words: [WordSD]?

    init(from entity: CollectionEntity) {
        self.id = entity.id
        self.name = entity.name
        self.desc = entity.description
        self.colorHex = entity.colorHex
        self.isPublic = entity.isPublic
        self.isSystem = entity.isSystem
        self.createdAt = entity.createdAt
        self.updatedAt = entity.updatedAt
        self.words = []
    }

    func toDomain() -> CollectionEntity {
        return CollectionEntity(
            id: id,
            name: name,
            description: desc,
            colorHex: colorHex,
            isPublic: isPublic,
            isSystem: isSystem,
            wordIds: words?.map { $0.id } ?? [],
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
