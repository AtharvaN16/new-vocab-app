import SwiftUI

struct CollectionDetailView: View {
    @State var viewModel: CollectionDetailViewModel
    @Environment(\.appEnvironment) private var appEnvironment
    @State private var selectedWord: WordEntity?
    @State private var showingPractice = false

    var body: some View {
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
                                if let phonetic = word.phonetic {
                                    Text(phonetic)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }
                .onDelete(perform: viewModel.deleteWord)
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
        .fullScreenCover(item: $selectedWord) { word in
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
