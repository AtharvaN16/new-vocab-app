import Foundation
import SwiftData
import Combine

/// Implementation of local-first sync using Supabase.
@Observable
final class SupabaseSyncService: SyncRepository {
    var status: SyncStatus = .idle
    private let modelContext: ModelContext
    private let wordRepository: WordRepository
    private let srsRepository: SRSRepository
    private let client = SupabaseClient()
    private var lastSyncDate: Date {
        get { UserDefaults.standard.object(forKey: "lastSyncDate") as? Date ?? .distantPast }
        set { UserDefaults.standard.set(newValue, forKey: "lastSyncDate") }
    }
    private var cancellables = Set<AnyCancellable>()

    init(modelContext: ModelContext, wordRepository: WordRepository, srsRepository: SRSRepository) {
        self.modelContext = modelContext
        self.wordRepository = wordRepository
        self.srsRepository = srsRepository
        setupObservers()
    }

    private func setupObservers() {
        // Observe SwiftData context saves
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] notification in
                self?.handleContextSave(notification)
            }
            .store(in: &cancellables)
    }

    private func handleContextSave(_ notification: Notification) {
        // Queue these changes for Supabase
        print("SupabaseSyncService: Local changes detected, queueing for sync...")
        Task {
            try? await pushLocalChanges()
        }
    }

    func pushLocalChanges() async throws {
        status = .syncing
        do {
            // Push Words
            let wordDescriptor = FetchDescriptor<WordSD>(predicate: #Predicate { $0.updatedAt > lastSyncDate })
            let dirtyWords = try modelContext.fetch(wordDescriptor)
            for wordSD in dirtyWords {
                let entity = wordSD.toDomain()
                try await client.upsert(table: "words", item: entity)
            }
            
            // Push SRS Cards
            let srsDescriptor = FetchDescriptor<SRSCardSD>(predicate: #Predicate { $0.updatedAt > lastSyncDate })
            let dirtyCards = try modelContext.fetch(srsDescriptor)
            for cardSD in dirtyCards {
                let entity = cardSD.toDomain()
                try await client.upsert(table: "srs_cards", item: entity)
            }
            
            lastSyncDate = Date()
            status = .idle
        } catch {
            status = .error(error)
            print("Sync Error: \(error)")
        }
    }

    func pullRemoteChanges() async throws {
        status = .syncing
        do {
            // 1. Pull Words
            let remoteWords: [WordEntity] = try await client.fetch(table: "words", since: lastSyncDate)
            for entity in remoteWords {
                try await wordRepository.saveWord(entity)
            }
            
            // 2. Pull SRS Cards
            let remoteCards: [SRSCardEntity] = try await client.fetch(table: "srs_cards", since: lastSyncDate)
            for entity in remoteCards {
                try await srsRepository.updateCard(entity)
            }
            
            lastSyncDate = Date()
            status = .idle
        } catch {
            status = .error(error)
            print("Sync Pull Error: \(error)")
        }
    }
}
