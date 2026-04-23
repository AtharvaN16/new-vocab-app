import Foundation
import SwiftUI

@Observable
final class ProfileViewModel {
    var openRouterApiKey: String = ""
    var isSaving: Bool = false
    var message: String?
    
    private let orKeyPath = "com.atharvanayak.vocabapp.openrouter_key"

    init() {
        loadKeys()
    }

    func loadKeys() {
        if let orData = try? KeychainHelper.read(key: orKeyPath),
           let key = String(data: orData, encoding: .utf8) {
            self.openRouterApiKey = key
        }
    }

    func saveKeys() {
        isSaving = true
        message = nil
        
        Task {
            do {
                // Save OpenRouter
                if openRouterApiKey.isEmpty {
                    try? KeychainHelper.delete(key: orKeyPath)
                } else if let data = openRouterApiKey.data(using: .utf8) {
                    try KeychainHelper.save(key: orKeyPath, data: data)
                }
                
                await MainActor.run {
                    self.message = "Settings saved successfully!"
                    self.isSaving = false
                }
            } catch {
                await MainActor.run {
                    self.message = "Error saving settings: \(error.localizedDescription)"
                    self.isSaving = false
                }
            }
        }
    }
}
