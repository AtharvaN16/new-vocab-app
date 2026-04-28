import SwiftUI

struct WordExpandedContentView: View {
    let word: WordEntity
    var isFullHeight: Bool = false
    var tiltX: Double = 0
    var tiltY: Double = 0
    var tiltMultiplier: Double = 1.0
    var audioPlayer: WordAudioPlayer
    var onWordEdited: ((WordEntity) -> Void)? = nil
    private let expandedMaxDeg = 14.0

    @Environment(\.appEnvironment) private var appEnvironment
    @State private var showEditor = false
    @State private var showChat = false

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if let phonetic = word.phonetic, !phonetic.isEmpty {
                        Button {
                            audioPlayer.toggle(url: word.audioURL)
                        } label: {
                            HStack(alignment: .center, spacing: 8) {
                                Text(phonetic)
                                    .font(.system(size: 16, weight: .regular))
                                    .tracking(-0.6)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .underline()
                                if word.audioURL != nil {
                                    Image(systemName: audioPlayer.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(word.audioURL == nil)
                        .padding(.top, isFullHeight ? 10 : 40)
                        .padding(.bottom, 8)
                    } else {
                        Spacer(minLength: isFullHeight ? 20 : 60)
                    }

                    StickerText(
                        text: word.word.capitalized,
                        size: 32
                    )
                    .padding(.leading, -8)
                    .rotation3DEffect(
                        .degrees(tiltX * expandedMaxDeg * tiltMultiplier),
                        axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.5
                    )
                    .rotation3DEffect(
                        .degrees(tiltY * expandedMaxDeg * tiltMultiplier),
                        axis: (x: 0, y: 1, z: 0), anchor: .bottom, perspective: 0.5
                    )
                    .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
                    .padding(.bottom, 6)

                    if !word.definitions.isEmpty {
                        expandedSection("DEFINITIONS") {
                            ForEach(Array(word.definitions.prefix(5).enumerated()), id: \.offset) { i, def in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                                        Text("\(i + 1).")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Theme.Colors.textSecondary)
                                        if !def.partOfSpeech.isEmpty {
                                            Text(def.partOfSpeech)
                                                .font(.system(size: 14).italic())
                                                .foregroundColor(Theme.Colors.textSecondary.opacity(0.7))
                                        }
                                    }
                                    Text(def.text)
                                        .font(.system(size: 16))
                                        .tracking(-0.7)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                                .padding(.bottom, 16)
                            }
                        }
                    }

                    if !word.examples.isEmpty {
                        expandedSection("EXAMPLES") {
                            ForEach(Array(word.examples.prefix(3).enumerated()), id: \.offset) { i, ex in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("\(i + 1).").foregroundColor(Theme.Colors.textSecondary)
                                    Text("\"\(ex.text)\"").foregroundColor(Theme.Colors.textSecondary)
                                }
                                .font(.system(size: 16)).tracking(-0.6)
                                .padding(.bottom, 16)
                            }
                        }
                    }

                    if !word.synonyms.isEmpty {
                        expandedSection("SYNONYMS") {
                            WordFlowRow(items: Array(word.synonyms.prefix(8)))
                        }
                    }

                    if !word.antonyms.isEmpty {
                        expandedSection("ANTONYMS") {
                            WordFlowRow(items: Array(word.antonyms.prefix(8)))
                        }
                    }

                    if let etymology = word.etymology, !etymology.isEmpty {
                        expandedSection("ETYMOLOGY") {
                            Text(etymology)
                                .font(.system(size: 16))
                                .tracking(-0.6)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .lineSpacing(4)
                        }
                    }

                    if let contextNote = word.contextualNote, !contextNote.isEmpty {
                        expandedSection("CONTEXT") {
                            Text(contextNote)
                                .font(.system(size: 16))
                                .tracking(-0.6)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .lineSpacing(4)
                        }
                    }

                    if !word.otherForms.isEmpty {
                        expandedSection("OTHER WORD FORMS") {
                            ForEach(word.otherForms, id: \.form) { form in
                                HStack(spacing: 4) {
                                    Text("•")
                                    Text(form.form).fontWeight(.semibold)
                                    + Text(" \(form.relation)")
                                }
                                .font(.system(size: 16)).tracking(-0.6)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .padding(.bottom, 8)
                            }
                        }
                    }
                    
                    if let mnemonic = word.aiMnemonic, !mnemonic.isEmpty {
                        expandedSection("AI MNEMONIC") {
                            Text(mnemonic)
                                .font(.system(size: 16))
                                .tracking(-0.6)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .lineSpacing(4)
                        }
                    }

                    Spacer(minLength: 140)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0), // Start fully visible
                        .init(color: .black, location: 0.82),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Action buttons — top-right corner
            if let env = appEnvironment {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 2) {
                            Button { showChat = true } label: {
                                Image(systemName: "bubble.left.and.text.bubble.right")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.6))
                                    .padding(8)
                            }
                            Button { showEditor = true } label: {
                                Image(systemName: "pencil.circle")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.6))
                                    .padding(8)
                            }
                        }
                        .padding(.top, isFullHeight ? 10 : 40)
                        .padding(.trailing, 20)
                    }
                    Spacer()
                }
                .sheet(isPresented: $showEditor) {
                    WordEditorView(viewModel: WordEditorViewModel(
                        word: word,
                        wordRepository: env.wordRepository,
                        aiRepository: env.aiRepository
                    ))
                }
                .sheet(isPresented: $showChat) {
                    WordChatView(viewModel: WordChatViewModel(
                        word: word,
                        aiRepository: env.aiRepository,
                        wordRepository: env.wordRepository
                    ))
                }
            }
        }
    }

    @ViewBuilder
    private func expandedSection<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(label)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .tracking(1.5)
                .foregroundColor(Theme.Colors.textPrimary)
            content()
        }
        .padding(.bottom, 36)
    }
}
