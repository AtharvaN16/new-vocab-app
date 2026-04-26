import SwiftUI

struct CollectionDetailView: View {
    @State var viewModel: CollectionDetailViewModel
    @Environment(\.appEnvironment) private var appEnvironment
    @State private var selectedWord: WordEntity?
    @State private var showingPractice = false

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            DotMatrixBackground()

            if viewModel.words.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No words yet",
                    systemImage: "book",
                    description: Text("Add words from the Discover tab to build your collection.")
                )
            } else {
                ScrollView {
                    VStack(spacing: 32) {
                        ForEach(chunkItemsIntoRows()) { row in
                            HStack(spacing: 0) {
                                ForEach(row.items) { item in
                                    stickerView(for: item)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 40)
                    .padding(.horizontal, 24)
                }
            }
        }
        .navigationTitle(viewModel.collection.name)
        .toolbar {
            if !viewModel.words.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Review") {
                        showingPractice = true
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingPractice) {
            if let appEnv = appEnvironment {
                PracticeSessionView(viewModel: PracticeSessionViewModel(
                    wordRepository: appEnv.wordRepository,
                    srsRepository: appEnv.srsRepository,
                    wordIds: viewModel.collection.wordIds
                ))
            }
        }
        .fullScreenCover(item: $selectedWord, onDismiss: {
            Task { await viewModel.loadWords() }
        }) { word in
            if let appEnv = appEnvironment {
                WordDetailView(viewModel: WordDetailViewModel(
                    word: word,
                    wordIds: viewModel.words.map { $0.id },
                    wordRepository: appEnv.wordRepository,
                    collectionRepository: appEnv.collectionRepository,
                    srsRepository: appEnv.srsRepository,
                    aiRepository: appEnv.aiRepository
                ))
            }
        }
        .refreshable {
            await viewModel.loadWords()
        }
    }

    @ViewBuilder
    private func stickerView(for item: CollectionDetailViewModel.StickerLayoutItem) -> some View {
        Button(action: { selectedWord = item.word }) {
            StickerText(text: item.word.word, size: item.fontSize, fillColor: .black)
                .padding(.horizontal, 16)
                .rotationEffect(.degrees(item.rotation))
                .offset(x: item.xOffset, y: item.yOffset)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(AmieButtonStyle())
        .contextMenu {
            Button(role: .destructive) {
                viewModel.removeWord(item.word)
            } label: {
                Label("Remove from Collection", systemImage: "trash")
            }
        }
    }

    private struct StickerRow: Identifiable {
        let id: String
        let items: [CollectionDetailViewModel.StickerLayoutItem]
    }

    private func chunkItemsIntoRows() -> [StickerRow] {
        var rows: [StickerRow] = []
        var currentIndex = 0
        let items = viewModel.stickerLayouts

        while currentIndex < items.count {
            let item = items[currentIndex]

            if item.spansFullWidth {
                rows.append(StickerRow(id: item.id.uuidString, items: [item]))
                currentIndex += 1
            } else {
                if currentIndex + 1 < items.count && !items[currentIndex + 1].spansFullWidth {
                    let nextItem = items[currentIndex + 1]
                    rows.append(StickerRow(id: "\(item.id.uuidString)-\(nextItem.id.uuidString)", items: [item, nextItem]))
                    currentIndex += 2
                } else {
                    rows.append(StickerRow(id: item.id.uuidString, items: [item]))
                    currentIndex += 1
                }
            }
        }
        return rows
    }
}
