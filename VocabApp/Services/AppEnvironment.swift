import Foundation
import SwiftData
import SwiftUI

private enum BuildSecrets {
    /// Wordnik key from `Config/Secrets.xcconfig` → Info.plist, or `WORDNIK_API_KEY` in the run environment.
    static var wordnikAPIKey: String {
        if let v = Bundle.main.object(forInfoDictionaryKey: "WORDNIK_API_KEY") as? String,
           !v.isEmpty,
           !v.hasPrefix("$(") {
            return v
        }
        return ProcessInfo.processInfo.environment["WORDNIK_API_KEY"] ?? ""
    }
}

@Observable
final class AppEnvironment {
    var selectedTab: Int = 0 // Default to Home
    var shouldFocusSearch: Bool = false
    let wordRepository: WordRepository
    let collectionRepository: CollectionRepository
    let srsRepository: SRSRepository
    let dictionaryRepository: DictionaryRepository
    var aiRepository: AIRepository
    let syncRepository: SyncRepository
    let authRepository: AuthRepository

    @MainActor
    init(modelContext: ModelContext) {
        let wordRepo = SwiftDataWordRepository(modelContext: modelContext)
        self.wordRepository = wordRepo
        let collectionRepo = SwiftDataCollectionRepository(modelContext: modelContext)
        self.collectionRepository = collectionRepo
        self.srsRepository = SwiftDataSRSRepository(modelContext: modelContext)
        self.authRepository = SupabaseAuthService()

        let wordnikKey = BuildSecrets.wordnikAPIKey

        // BYOK Keys from Keychain
        let orKeyPath = "com.atharvanayak.vocabapp.openrouter_key"
        let mwKeyPath = "com.atharvanayak.vocabapp.merriamwebster_key"
        let savedOrKey = (try? KeychainHelper.read(key: orKeyPath)).flatMap { String(data: $0, encoding: .utf8) }
        let savedMWKey = (try? KeychainHelper.read(key: mwKeyPath)).flatMap { String(data: $0, encoding: .utf8) }

        // Dictionary Service
        let apiClient = APIClient()
        self.dictionaryRepository = DictionaryService(
            apiClient: apiClient,
            wordRepository: wordRepo,
            wordnikApiKey: wordnikKey,
            merriamWebsterApiKey: savedMWKey
        )

        // AI Service
        self.aiRepository = AIServiceCoordinator(openRouterApiKey: savedOrKey)

        // Sync Service
        self.syncRepository = SupabaseSyncService(modelContext: modelContext, wordRepository: wordRepo, srsRepository: self.srsRepository)
        
        // Bootstrap system collections
        Task {
            await bootstrap(collectionRepo: collectionRepo)
        }
    }

    @MainActor
    func updateAIKey(_ key: String) {
        self.aiRepository = AIServiceCoordinator(openRouterApiKey: key.isEmpty ? nil : key)
    }

    @MainActor
    func updateMerriamWebsterKey(_ key: String) {
        let keyPath = "com.atharvanayak.vocabapp.merriamwebster_key"
        let data = key.isEmpty ? nil : key.data(using: .utf8)
        if let data {
            try? KeychainHelper.save(key: keyPath, data: data)
        } else {
            try? KeychainHelper.delete(key: keyPath)
        }
        (dictionaryRepository as? DictionaryService)?.updateMerriamWebsterKey(key.isEmpty ? nil : key)
    }
    @MainActor
    private func bootstrap(collectionRepo: CollectionRepository) async {
        do {
            let collections = try await collectionRepo.fetchCollections()
            let systemNames = ["Favorites", "Bookmarked"]
            
            for (index, name) in systemNames.enumerated() {
                if !collections.contains(where: { $0.name == name }) {
                    let newCollection = CollectionEntity(
                        id: UUID(),
                        name: name,
                        description: "System default collection",
                        colorHex: name == "Favorites" ? "#FF3B30" : "#007AFF",
                        isPublic: false,
                        isSystem: true,
                        sortOrder: index - 100, // System collections at the very top
                        wordIds: [],
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                    try await collectionRepo.saveCollection(newCollection)
                }
            }
        } catch {
            print("Bootstrapping error: \(error)")
        }
    }
}


// EnvironmentKey for AppEnvironment
struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppEnvironment? = nil
}

extension EnvironmentValues {
    var appEnvironment: AppEnvironment? {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
