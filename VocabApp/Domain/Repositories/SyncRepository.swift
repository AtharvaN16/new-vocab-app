import Foundation

enum SyncStatus {
    case idle
    case syncing
    case error(Error)
}

protocol SyncRepository {
    /// Pushes local changes to the remote backend (Supabase).
    func pushLocalChanges() async throws
    
    /// Pulls remote changes from Supabase and merges them locally.
    func pullRemoteChanges() async throws
    
    /// Returns the current sync status.
    var status: SyncStatus { get }
}
