import SwiftUI

struct DiscoverView: View {
    @State private var viewModel: DiscoverViewModel
    @Environment(\.appEnvironment) private var appEnvironment

    init(dictionaryRepository: DictionaryRepository) {
        _viewModel = State(initialValue: DiscoverViewModel(dictionaryRepository: dictionaryRepository))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Bar (Amie-style: Pill with thin border)
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        TextField("Search a word...", text: $viewModel.searchText)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .textFieldStyle(.plain)
                            .onSubmit {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                viewModel.performSearch()
                            }
                        
                        if !viewModel.searchText.isEmpty {
                            Button(action: { viewModel.searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.Colors.surface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Theme.Colors.border, lineWidth: 1))
                    .padding()

                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .tint(Theme.Colors.amieBlue)
                        Spacer()
                    } else if let error = viewModel.errorMessage {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.Colors.amieYellow)
                            Text(error)
                                .font(.system(size: 16, weight: .medium))
                                .multilineTextAlignment(.center)
                                .foregroundColor(Theme.Colors.textSecondary)
                            Spacer()
                        }
                        .padding()
                    } else if let result = viewModel.searchResult {
                        ScrollView {
                            WordResultCard(word: result)
                                .padding()
                                .onTapGesture {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    viewModel.showDetail = true
                                }
                        }
                        .fullScreenCover(isPresented: $viewModel.showDetail) {
                            if let appEnvironment = appEnvironment {
                                WordDetailView(viewModel: WordDetailViewModel(
                                    word: result,
                                    wordRepository: appEnvironment.wordRepository,
                                    collectionRepository: appEnvironment.collectionRepository,
                                    srsRepository: appEnvironment.srsRepository,
                                    aiRepository: appEnvironment.aiRepository
                                ))
                            }
                        }
                    } else {
                        VStack(spacing: 24) {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Theme.Colors.amieBlue.opacity(0.1))
                                    .frame(width: 120, height: 120)
                                Image(systemName: "sparkles")
                                    .font(.system(size: 50))
                                    .foregroundColor(Theme.Colors.amieBlue)
                            }
                            
                            VStack(spacing: 8) {
                                Text("Discover")
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                Text("Search for any word to see definitions,\nexamples, and build your vocabulary.")
                                    .font(.system(size: 15))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .padding(.horizontal, 40)
                            }
                            Spacer()
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Discover")
        }
    }
}

struct WordResultCard: View {
    let word: WordEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(word.word.capitalized)
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    if let phonetic = word.phonetic {
                        Text(phonetic)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Divider()
                .opacity(0.5)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(word.definitions.prefix(2), id: \.text) { def in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(def.partOfSpeech.uppercased())
                            .font(.system(size: 10, weight: .black))
                            .tracking(1.5)
                            .foregroundColor(Theme.Colors.amieBlue)
                        
                        Text(def.text)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(24)
        .amieCard()
    }
}
