import Foundation
import SwiftUI

@Observable
final class SupabaseAuthService: AuthRepository {
    var currentUser: UserEntity?
    var isAuthenticated: Bool { currentUser != nil }
    
    private let client = SupabaseClient()
    private let tokenKey = "com.atharvanayak.vocabapp.auth_token"
    private let userKey = "com.atharvanayak.vocabapp.current_user"

    init() {
        loadSession()
    }

    func signUp(email: String, password: String) async throws {
        let response = try await client.signUp(email: email, password: password)
        try saveSession(response: response)
    }

    func signIn(email: String, password: String) async throws {
        let response = try await client.signIn(email: email, password: password)
        try saveSession(response: response)
    }

    func signOut() async throws {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: userKey)
        try? KeychainHelper.delete(key: tokenKey)
    }

    func refreshSession() async throws {
        // Simple implementation: check if token exists
        if currentUser == nil {
            loadSession()
        }
    }

    private func saveSession(response: AuthResponse) throws {
        let user = UserEntity(id: response.user.id, email: response.user.email)
        self.currentUser = user
        
        // Save user to UserDefaults
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userKey)
        }
        
        // Save token to Keychain
        if let tokenData = response.access_token.data(using: .utf8) {
            try KeychainHelper.save(key: tokenKey, data: tokenData)
        }
    }

    private func loadSession() {
        if let data = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(UserEntity.self, from: data) {
            self.currentUser = user
        }
    }
}
