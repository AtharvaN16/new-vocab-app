import Foundation

struct CollectionEntity: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var colorHex: String
    var isPublic: Bool
    var isSystem: Bool
    
    // Relationship IDs (Domain entities don't hold object references to avoid cycles/heavy objects)
    var wordIds: [UUID]
    
    let createdAt: Date
    var updatedAt: Date
}
