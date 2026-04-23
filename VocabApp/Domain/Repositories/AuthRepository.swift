import Foundation

struct UserEntity: Identifiable, Codable {
    let id: UUID
    let email: String?
}

protocol AuthRepository {
    var currentUser: UserEntity? { get }
    var isAuthenticated: Bool { get }
    
    func signUp(email: String, password: String) async throws
    func signIn(email: String, password: String) async throws
    func signOut() async throws
    func refreshSession() async throws
}
