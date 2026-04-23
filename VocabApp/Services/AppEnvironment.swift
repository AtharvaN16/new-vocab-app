import Foundation
import SwiftData
import SwiftUI

@Observable
final class AppEnvironment {
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

        let wordnikKey = "n45snhph1wsci8f2v1j83182d5fk2kqwpos7kax1uv9pcptc2"
        
        // BYOK Keys from Keychain
        let orKeyPath = "com.atharvanayak.vocabapp.openrouter_key"
        let savedOrKey = (try? KeychainHelper.read(key: orKeyPath)).flatMap { String(data: $0, encoding: .utf8) }

        // Dictionary Service
        let apiClient = APIClient()
        self.dictionaryRepository = DictionaryService(apiClient: apiClient, wordRepository: wordRepo, wordnikApiKey: wordnikKey)

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
    private func bootstrap(collectionRepo: CollectionRepository) async {
        do {
            let collections = try await collectionRepo.fetchCollections()
            let systemNames = ["Favorites", "Bookmarked"]
            
            for name in systemNames {
                if !collections.contains(where: { $0.name == name }) {
                    let newCollection = CollectionEntity(
                        id: UUID(),
                        name: name,
                        description: "System default collection",
                        colorHex: name == "Favorites" ? "#FF3B30" : "#007AFF",
                        isPublic: false,
                        isSystem: true,
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
