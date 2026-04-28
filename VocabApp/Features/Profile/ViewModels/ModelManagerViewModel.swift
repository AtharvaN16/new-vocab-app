import Foundation
import SwiftUI

@Observable
@MainActor
final class ModelManagerViewModel {
    enum Tab { case local, cloud }

    var selectedTab: Tab = .local
    var downloadProgress: [String: Double] = [:]
    var downloadError: [String: String] = [:]
    var deleteError: String? = nil

    private let repository: LocalModelRepository

    init(repository: LocalModelRepository) {
        self.repository = repository
    }

    var availableModels: [LocalModelEntity] { repository.availableModels() }
    var downloadedModels: [LocalModelEntity] { repository.downloadedModels() }
    var activeModel: LocalModelEntity? { repository.activeModel() }

    func isDownloaded(_ model: LocalModelEntity) -> Bool {
        repository.isDownloaded(model)
    }

    func isDownloading(_ model: LocalModelEntity) -> Bool {
        downloadProgress[model.id] != nil
    }

    func progressFor(_ model: LocalModelEntity) -> Double {
        downloadProgress[model.id] ?? 0
    }

    func isCompatible(_ model: LocalModelEntity) -> Bool {
        let deviceRAMGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        return deviceRAMGB >= model.ramRequiredGB
    }

    func download(_ model: LocalModelEntity) {
        guard !isDownloading(model), !isDownloaded(model) else { return }
        downloadProgress[model.id] = 0
        downloadError.removeValue(forKey: model.id)

        Task {
            do {
                try await repository.download(model) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.downloadProgress[model.id] = progress
                    }
                }
                downloadProgress.removeValue(forKey: model.id)
            } catch {
                downloadProgress.removeValue(forKey: model.id)
                downloadError[model.id] = error.localizedDescription
            }
        }
    }

    func delete(_ model: LocalModelEntity) {
        do {
            try repository.delete(model)
        } catch {
            deleteError = error.localizedDescription
        }
    }

    func selectActive(_ model: LocalModelEntity) {
        repository.setActiveModel(model)
    }

    var activeModelLabel: String {
        if let active = activeModel {
            return "\(active.displayName) · Local"
        }
        return "Cloud only"
    }
}
