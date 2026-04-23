import Foundation

/// Coordinates between different AI tiers (Local MLX vs Remote OpenRouter).
final class AIServiceCoordinator: AIRepository {
    private let openRouterService: AIRepository?
    // private let mlxService: AIRepository?
    
    init(openRouterApiKey: String?) {
        if let apiKey = openRouterApiKey {
            self.openRouterService = OpenRouterService(apiKey: apiKey)
        } else {
            self.openRouterService = nil
        }
    }

    func generateContent(for word: String, type: AIContentType) async throws -> AsyncThrowingStream<String, Error> {
        // Tier 1: Local MLX (Check if model is downloaded and device is capable)
        /*
        if let mlx = mlxService, await mlx.isReady() {
            return try await mlx.generateContent(for: word, type: type)
        }
        */
        
        // Tier 2: OpenRouter
        if let openRouter = openRouterService {
            return try await openRouter.generateContent(for: word, type: type)
        }
        
        // Tier 3: No AI
        return AsyncThrowingStream { continuation in
            continuation.finish(throwing: NSError(domain: "AIService", code: 404, userInfo: [NSLocalizedDescriptionKey: "AI service unavailable. Please add an API key in Settings."]))
        }
    }
}
