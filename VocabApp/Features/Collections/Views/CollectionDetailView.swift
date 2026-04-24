import SwiftUI

struct CollectionDetailView: View {
    @State var viewModel: CollectionDetailViewModel
    @Environment(\.appEnvironment) private var appEnvironment
    @State private var selectedWord: WordEntity?
    @State private var showingPractice = false

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            
            List {
                if viewModel.words.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No words yet",
                        systemImage: "book",
                        description: Text("Add words from the Discover tab to build your collection.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.words) { word in
                        Button(action: { selectedWord = word }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(word.word.capitalized)
                                        .font(.headline)
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                    if let phonetic = word.phonetic {
                                        Text(phonetic)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(Theme.Colors.surface)
                    }
                    .onDelete(perform: viewModel.deleteWord)
                }
            }
            .scrollContentBackground(.hidden)
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
}
