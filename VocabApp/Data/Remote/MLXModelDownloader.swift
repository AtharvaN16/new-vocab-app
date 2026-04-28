import Foundation

/// Downloads MLX model weights from HuggingFace to a local directory.
/// Task C2: Replace stub with real MLXLLM SPM integration.
final class MLXModelDownloader {
    func downloadModel(
        repo: String,
        to destination: URL,
        progress: @escaping (Double) -> Void
    ) async throws {
        // TODO (Task C2): integrate mlx-swift-examples MLXLLM package.
        // Will use MLXLLM.ModelContainer + Hub.snapshot(from:) to download weights.
        throw LocalModelError.downloadFailed("Local LLM download coming soon. Use OpenRouter for now.")
    }
}
