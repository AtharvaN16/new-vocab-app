import Foundation

/// Protocol for API DTOs that can be normalized into a domain WordEntity.
protocol Normalizable {
    func normalize() -> WordEntity
}
