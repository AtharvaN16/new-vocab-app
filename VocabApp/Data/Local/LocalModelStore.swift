import Foundation

final class LocalModelStore: LocalModelRepository {
    private let defaults = UserDefaults.standard
    private let downloadedKey = "com.vocabapp.localModels.downloaded"
    private let activeModelKey = "com.vocabapp.localModels.activeId"

    private var downloadedIds: Set<String> {
        get { Set(defaults.stringArray(forKey: downloadedKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: downloadedKey) }
    }

    func availableModels() -> [LocalModelEntity] {
        LocalModelEntity.catalog
    }

    func downloadedModels() -> [LocalModelEntity] {
        let ids = downloadedIds
        return LocalModelEntity.catalog.filter { ids.contains($0.id) }
    }

    func activeModel() -> LocalModelEntity? {
        guard let id = defaults.string(forKey: activeModelKey) else { return nil }
        return LocalModelEntity.catalog.first { $0.id == id }
    }

    func setActiveModel(_ model: LocalModelEntity?) {
        if let model {
            defaults.set(model.id, forKey: activeModelKey)
        } else {
            defaults.removeObject(forKey: activeModelKey)
        }
    }

    func isDownloaded(_ model: LocalModelEntity) -> Bool {
        guard downloadedIds.contains(model.id) else { return false }
        return localModelPath(for: model).map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    }

    func downloadProgress(for model: LocalModelEntity) -> Double? {
        nil // Managed externally by ModelManagerViewModel
    }

    func localModelPath(for model: LocalModelEntity) -> URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("LocalModels", isDirectory: true)
            .appendingPathComponent(model.id, isDirectory: true)
    }

    func download(_ model: LocalModelEntity, progress: @escaping (Double) -> Void) async throws {
        guard let destDir = localModelPath(for: model) else {
            throw LocalModelError.storageFailed
        }
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        let downloader = MLXModelDownloader()
        try await downloader.downloadModel(
            repo: model.huggingFaceRepo,
            to: destDir,
            progress: progress
        )

        var ids = downloadedIds
        ids.insert(model.id)
        downloadedIds = ids

        // Auto-select if nothing is active
        if activeModel() == nil {
            setActiveModel(model)
        }
    }

    func delete(_ model: LocalModelEntity) throws {
        if let path = localModelPath(for: model) {
            try? FileManager.default.removeItem(at: path)
        }
        var ids = downloadedIds
        ids.remove(model.id)
        downloadedIds = ids

        if activeModel()?.id == model.id {
            setActiveModel(nil)
        }
    }
}

enum LocalModelError: Error, LocalizedError {
    case storageFailed
    case downloadFailed(String)
    case modelNotFound

    var errorDescription: String? {
        switch self {
        case .storageFailed: return "Could not create storage directory for model."
        case .downloadFailed(let msg): return "Download failed: \(msg)"
        case .modelNotFound: return "Model file not found after download."
        }
    }
}
