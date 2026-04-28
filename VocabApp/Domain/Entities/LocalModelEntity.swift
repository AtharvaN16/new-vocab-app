import Foundation

struct LocalModelEntity: Identifiable, Codable, Equatable {
    let id: String
    let displayName: String
    let description: String
    let parameterCount: String
    let ramRequiredGB: Double
    let downloadSizeGB: Double
    let minDeviceChip: String
    let huggingFaceRepo: String

    var downloadSizeLabel: String {
        downloadSizeGB < 1
            ? "\(Int(downloadSizeGB * 1024))MB"
            : String(format: "%.1fGB", downloadSizeGB)
    }
    var ramLabel: String { "\(Int(ramRequiredGB))GB+" }

    static let catalog: [LocalModelEntity] = [
        LocalModelEntity(
            id: "lfm2-350m",
            displayName: "LiquidAI LFM2 350M",
            description: "Smallest on-device model from Liquid AI. Works on any iPhone.",
            parameterCount: "350M",
            ramRequiredGB: 1.0,
            downloadSizeGB: 0.35,
            minDeviceChip: "A9",
            huggingFaceRepo: "mlx-community/LFM2-350M-4bit"
        ),
        LocalModelEntity(
            id: "qwen2.5-0.5b",
            displayName: "Qwen 2.5 0.5B",
            description: "Compact 500M model from Alibaba. Solid quality for short tasks.",
            parameterCount: "500M",
            ramRequiredGB: 2.0,
            downloadSizeGB: 0.5,
            minDeviceChip: "A11",
            huggingFaceRepo: "mlx-community/Qwen2.5-0.5B-Instruct-4bit"
        ),
        LocalModelEntity(
            id: "lfm2-700m",
            displayName: "LiquidAI LFM2 700M",
            description: "Efficient 700M hybrid model from Liquid AI. Great balance of speed and quality.",
            parameterCount: "700M",
            ramRequiredGB: 2.0,
            downloadSizeGB: 0.7,
            minDeviceChip: "A12",
            huggingFaceRepo: "mlx-community/LFM2-700M-4bit"
        ),
        LocalModelEntity(
            id: "gemma3-1b",
            displayName: "Gemma 3 1B",
            description: "Google's 1B model. Strong reasoning for its size.",
            parameterCount: "1B",
            ramRequiredGB: 4.0,
            downloadSizeGB: 1.0,
            minDeviceChip: "A14",
            huggingFaceRepo: "mlx-community/gemma-3-1b-it-4bit"
        ),
        LocalModelEntity(
            id: "phi35-mini",
            displayName: "Phi-3.5 Mini",
            description: "Microsoft's 3.8B model. Best local quality, requires a newer device.",
            parameterCount: "3.8B",
            ramRequiredGB: 6.0,
            downloadSizeGB: 2.3,
            minDeviceChip: "A17",
            huggingFaceRepo: "mlx-community/Phi-3.5-mini-instruct-4bit"
        )
    ]
}
