import Foundation
import SwiftUI

struct CollectionEntity: Identifiable, Codable, Equatable, Hashable, Transferable {
    let id: UUID
    var name: String
    var description: String
    var colorHex: String
    var isPublic: Bool
    var isSystem: Bool
    var sortOrder: Int

    // Relationship IDs (Domain entities don't hold object references to avoid cycles/heavy objects)
    var wordIds: [UUID]

    let createdAt: Date
    var updatedAt: Date

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: CollectionEntity.self, contentType: .data)
    }
}
