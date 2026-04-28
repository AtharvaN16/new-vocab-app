import Foundation

protocol LocalModelRepository {
    func availableModels() -> [LocalModelEntity]
    func downloadedModels() -> [LocalModelEntity]
    func activeModel() -> LocalModelEntity?
    func setActiveModel(_ model: LocalModelEntity?)
    func isDownloaded(_ model: LocalModelEntity) -> Bool
    func downloadProgress(for model: LocalModelEntity) -> Double?
    func localModelPath(for model: LocalModelEntity) -> URL?
    func download(_ model: LocalModelEntity, progress: @escaping (Double) -> Void) async throws
    func delete(_ model: LocalModelEntity) throws
}
