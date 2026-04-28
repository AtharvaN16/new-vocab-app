import SwiftUI

struct ModelManagerView: View {
    @State var viewModel: ModelManagerViewModel
    @Environment(\.appEnvironment) private var appEnvironment

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $viewModel.selectedTab) {
                Text("Local").tag(ModelManagerViewModel.Tab.local)
                Text("Cloud").tag(ModelManagerViewModel.Tab.cloud)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            ScrollView {
                switch viewModel.selectedTab {
                case .local:
                    localModelsView
                case .cloud:
                    cloudModelsView
                }
            }
        }
        .navigationTitle("Model Manager")
        .navigationBarTitleDisplayMode(.large)
        .background(Theme.Colors.background)
    }

    // MARK: - Local Models

    @ViewBuilder
    private var localModelsView: some View {
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
            let downloaded = viewModel.downloadedModels
            let available = viewModel.availableModels.filter { !viewModel.isDownloaded($0) }

            if !downloaded.isEmpty {
                Section {
                    ForEach(downloaded) { model in
                        modelRow(model, isDownloaded: true)
                        Divider().padding(.leading, 20)
                    }
                } header: {
                    sectionHeader("YOUR MODELS")
                }
            }

            Section {
                ForEach(available) { model in
                    modelRow(model, isDownloaded: false)
                    Divider().padding(.leading, 20)
                }
            } header: {
                sectionHeader(downloaded.isEmpty ? "AVAILABLE MODELS" : "RECOMMENDED")
            }
        }
        .padding(.bottom, 40)
    }

    @ViewBuilder
    private func modelRow(_ model: LocalModelEntity, isDownloaded: Bool) -> some View {
        let compatible = viewModel.isCompatible(model)
        let downloading = viewModel.isDownloading(model)
        let isActive = viewModel.activeModel?.id == model.id

        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(compatible ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.amieGreen)
                    }
                }
                Text(model.description)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    badge(model.ramLabel, icon: "memorychip")
                    badge(model.downloadSizeLabel, icon: "arrow.down.circle")
                    if !compatible {
                        badge("Needs \(model.minDeviceChip)+", icon: "exclamationmark.triangle", color: .orange)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                if downloading {
                    let progress = viewModel.progressFor(model)
                    ZStack {
                        Circle()
                            .stroke(Theme.Colors.border, lineWidth: 2)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Theme.Colors.amieBlue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .frame(width: 36, height: 36)
                } else if isDownloaded {
                    if !isActive {
                        Button {
                            viewModel.selectActive(model)
                        } label: {
                            Text("Use")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.Colors.amieBlue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.Colors.amieBlue.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    Button {
                        viewModel.delete(model)
                    } label: {
                        Text("Delete")
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.7))
                    }
                } else {
                    Button {
                        viewModel.download(model)
                    } label: {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 28))
                            .foregroundColor(compatible ? Theme.Colors.amieBlue : Theme.Colors.textSecondary.opacity(0.4))
                    }
                    .disabled(!compatible)
                }

                if let error = viewModel.downloadError[model.id] {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .opacity(compatible ? 1 : 0.6)
    }

    // MARK: - Cloud Models

    @ViewBuilder
    private var cloudModelsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("OPENROUTER")

            VStack(alignment: .leading, spacing: 12) {
                Text("OpenRouter routes your requests to cloud AI models. Enter your API key below — get one free at openrouter.ai.")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineSpacing(3)

                if let env = appEnvironment {
                    CloudKeyRow(appEnvironment: env)
                }
            }
            .padding(20)

            sectionHeader("RECOMMENDED CLOUD MODELS")

            VStack(spacing: 0) {
                cloudModelRow("Gemini Flash 1.5", provider: "Google", cost: "$0.08/1M tokens", modelId: "google/gemini-flash-1.5", isDefault: true)
                Divider().padding(.leading, 20)
                cloudModelRow("Claude Haiku 4.5", provider: "Anthropic", cost: "$1/1M tokens", modelId: "anthropic/claude-haiku-4-5")
                Divider().padding(.leading, 20)
                cloudModelRow("Llama 3.3 70B", provider: "Meta (free)", cost: "Free · rate limited", modelId: "meta-llama/llama-3.3-70b-instruct:free")
            }
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.border))
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private func cloudModelRow(_ name: String, provider: String, cost: String, modelId: String, isDefault: Bool = false) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(name).font(.system(size: 15, weight: .semibold))
                    if isDefault {
                        Text("DEFAULT")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundColor(Theme.Colors.amieBlue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.amieBlue.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                Text(provider)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            Spacer()
            Text(cost)
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .tracking(1.5)
            .foregroundColor(Theme.Colors.textSecondary)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.background)
    }

    @ViewBuilder
    private func badge(_ text: String, icon: String, color: Color = Theme.Colors.textSecondary) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9))
            Text(text).font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Cloud Key Row (stateful subview to avoid re-reading keychain on every render)

private struct CloudKeyRow: View {
    let appEnvironment: AppEnvironment
    @State private var keyText: String = ""
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SecureField("sk-or-v1-…", text: $keyText)
                    .font(.system(size: 14, design: .monospaced))
                    .padding(10)
                    .background(Theme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.border))

                Button {
                    appEnvironment.updateAIKey(keyText)
                    // Also persist to keychain
                    let keyPath = "com.atharvanayak.vocabapp.openrouter_key"
                    if keyText.isEmpty {
                        try? KeychainHelper.delete(key: keyPath)
                    } else if let data = keyText.data(using: .utf8) {
                        try? KeychainHelper.save(key: keyPath, data: data)
                    }
                    saved = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        saved = false
                    }
                } label: {
                    Text(saved ? "Saved!" : "Save")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(saved ? Theme.Colors.amieGreen : Theme.Colors.amieBlue)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background((saved ? Theme.Colors.amieGreen : Theme.Colors.amieBlue).opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .onAppear {
            let keyPath = "com.atharvanayak.vocabapp.openrouter_key"
            keyText = (try? KeychainHelper.read(key: keyPath))
                .flatMap { String(data: $0, encoding: .utf8) } ?? ""
        }
    }
}
