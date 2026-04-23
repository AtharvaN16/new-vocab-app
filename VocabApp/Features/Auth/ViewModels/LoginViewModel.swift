import Foundation
import SwiftUI

@Observable
final class LoginViewModel {
    var email = ""
    var password = ""
    var isSignUp = false
    var isLoading = false
    var errorMessage: String?
    
    private let authRepository: AuthRepository

    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
    }

    @MainActor
    func handleSubmit() async {
        guard !email.isEmpty && !password.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            if isSignUp {
                try await authRepository.signUp(email: email, password: password)
            } else {
                try await authRepository.signIn(email: email, password: password)
            }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
