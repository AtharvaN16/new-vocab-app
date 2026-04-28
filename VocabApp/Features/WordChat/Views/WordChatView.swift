import SwiftUI

struct WordChatView: View {
    @State var viewModel: WordChatViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool
    @State private var saveTarget: ChatMessage? = nil
    @State private var savedFeedback: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                modePicker
                Divider()
                messagesArea
                inputBar
            }
            .background(Theme.Colors.background)
            .navigationTitle(viewModel.word.word.capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .confirmationDialog(
                "Save to word",
                isPresented: Binding(
                    get: { saveTarget != nil },
                    set: { if !$0 { saveTarget = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let msg = saveTarget {
                    Button("Save as Note") {
                        Task { await viewModel.saveMessage(msg, as: .note) }
                        showSavedFeedback("Saved as note")
                        saveTarget = nil
                    }
                    Button("Save as Example") {
                        Task { await viewModel.saveMessage(msg, as: .example) }
                        showSavedFeedback("Saved as example")
                        saveTarget = nil
                    }
                    Button("Save as Memory Aid") {
                        Task { await viewModel.saveMessage(msg, as: .mnemonic) }
                        showSavedFeedback("Saved as memory aid")
                        saveTarget = nil
                    }
                    Button("Cancel", role: .cancel) { saveTarget = nil }
                }
            }
            .overlay(alignment: .top) {
                if let feedback = savedFeedback {
                    Text(feedback)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.Colors.amieGreen)
                        .clipShape(Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.3), value: savedFeedback)
        }
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AssistantMode.allCases) { mode in
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            viewModel.switchMode(mode)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 12, weight: .semibold))
                            Text(mode.displayName)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(viewModel.selectedMode == mode ? .white : Theme.Colors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            viewModel.selectedMode == mode
                                ? Theme.Colors.amieBlue
                                : Theme.Colors.surface
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                viewModel.selectedMode == mode ? Color.clear : Theme.Colors.border,
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Messages Area

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if viewModel.showQuickPrompts {
                        quickPromptsView
                    } else {
                        ForEach(viewModel.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .onChange(of: viewModel.messages.count) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom")
                }
            }
            .onChange(of: viewModel.messages.last?.content) {
                proxy.scrollTo("bottom")
            }
        }
    }

    // MARK: - Quick Prompts

    private var quickPromptsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.selectedMode.displayName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(viewModel.selectedMode.modeDescription)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 8) {
                Text("SUGGESTIONS")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(Theme.Colors.textSecondary)

                ForEach(viewModel.selectedMode.quickPrompts, id: \.self) { prompt in
                    Button {
                        Task { await viewModel.send(text: prompt) }
                    } label: {
                        HStack {
                            Text(prompt)
                                .font(.system(size: 15))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.border))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Message Bubble

    @ViewBuilder
    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content.isEmpty && viewModel.isGenerating ? "●●●" : message.content)
                    .font(.system(size: 15))
                    .foregroundColor(message.role == .user ? .white : Theme.Colors.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.role == .user
                            ? Theme.Colors.amieBlue
                            : Theme.Colors.surface
                    )
                    .clipShape(
                        BubbleShape(isUser: message.role == .user)
                    )
                    .overlay(
                        message.role == .assistant
                            ? BubbleShape(isUser: false).stroke(Theme.Colors.border, lineWidth: 1)
                            : nil
                    )
                    .contextMenu {
                        if message.role == .assistant && !message.content.isEmpty {
                            Button {
                                saveTarget = message
                            } label: {
                                Label("Save to word", systemImage: "square.and.arrow.down")
                            }
                            Button {
                                UIPasteboard.general.string = message.content
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }
                    }
            }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask about \"\(viewModel.word.word)\"…", text: $viewModel.inputText, axis: .vertical)
                    .font(.system(size: 15))
                    .lineLimit(1...4)
                    .focused($inputFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.Colors.border))

                Button {
                    inputFocused = false
                    Task { await viewModel.send() }
                } label: {
                    if viewModel.isGenerating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(
                                viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Theme.Colors.textSecondary.opacity(0.3)
                                    : Theme.Colors.amieBlue
                            )
                    }
                }
                .disabled(
                    viewModel.isGenerating ||
                    viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.Colors.background)
        }
    }

    private func showSavedFeedback(_ text: String) {
        savedFeedback = text
        Task {
            try? await Task.sleep(for: .seconds(2))
            savedFeedback = nil
        }
    }
}

// MARK: - Bubble Shape

private struct BubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let tailRadius: CGFloat = 4
        var path = Path()

        if isUser {
            path.addRoundedRect(in: rect, cornerRadii: .init(
                topLeading: radius, bottomLeading: radius,
                bottomTrailing: tailRadius, topTrailing: radius
            ))
        } else {
            path.addRoundedRect(in: rect, cornerRadii: .init(
                topLeading: tailRadius, bottomLeading: radius,
                bottomTrailing: radius, topTrailing: radius
            ))
        }
        return path
    }
}
