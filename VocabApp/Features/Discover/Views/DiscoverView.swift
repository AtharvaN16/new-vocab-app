import SwiftUI

struct DiscoverView: View {
    @State var viewModel: DiscoverViewModel?
    @Environment(\.appEnvironment) private var appEnvironment
    @FocusState private var isSearchFocused: Bool

    init(viewModel: DiscoverViewModel? = nil) {
        self._viewModel = State(initialValue: viewModel)
    }

    init(dictionaryRepository: DictionaryRepository, wordRepository: WordRepository, collectionRepository: CollectionRepository) {
        self._viewModel = State(initialValue: DiscoverViewModel(
            dictionaryRepository: dictionaryRepository,
            wordRepository: wordRepository,
            collectionRepository: collectionRepository
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    if let viewModel = viewModel {
                        // Large Title Search Section
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Search", text: Bindable(viewModel).searchText)
                                .font(.system(size: 44, weight: .black, design: .rounded))
                                .foregroundStyle(Theme.Colors.textPrimary.opacity(viewModel.searchResult == nil ? 0.6 : 1.0))
                                .focused($isSearchFocused)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .submitLabel(.search)
                                .onSubmit {
                                    viewModel.performSearch()
                                }
                                .animation(Theme.Animation.spring, value: viewModel.searchResult == nil)
                            
                            if viewModel.isLoading {
                                AnimatingSearchingView()
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 60) // Extra padding for the title feel
                        .padding(.bottom, 20)

                        if let error = viewModel.errorMessage {
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
                                WordResultCard(word: result, viewModel: viewModel)
                                    .padding()
                            }
                        } else if !viewModel.recommendations.isEmpty {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("RECOMMENDATIONS")
                                        .font(.system(size: 10, weight: .black))
                                        .tracking(1.5)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                        .padding(.horizontal, 24)
                                        .padding(.bottom, 12)

                                    ForEach(viewModel.recommendations) { word in
                                        Button {
                                            withAnimation {
                                                viewModel.selectRecommendation(word)
                                            }
                                        } label: {
                                            HStack {
                                                Image(systemName: "magnifyingglass")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(Theme.Colors.textSecondary)
                                                Text(word.word)
                                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                                    .foregroundColor(Theme.Colors.textPrimary)
                                                Spacer()
                                                Image(systemName: "arrow.up.left")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(Theme.Colors.textSecondary)
                                            }
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 16)
                                            .background(Theme.Colors.surface.opacity(0.001)) // Tappable area
                                        }
                                        Divider()
                                            .padding(.horizontal, 24)
                                    }
                                }
                                .padding(.top, 8)
                            }
                        } else {
                            Spacer()
                        }
                    } else {
                        ProgressView()
                            .onAppear {
                                if let appEnv = appEnvironment {
                                    viewModel = DiscoverViewModel(
                                        dictionaryRepository: appEnv.dictionaryRepository,
                                        wordRepository: appEnv.wordRepository,
                                        collectionRepository: appEnv.collectionRepository
                                    )
                                }
                            }
                    }
                }
            }
            .onAppear {
                handleFocusTrigger()
            }
            .onChange(of: appEnvironment?.shouldFocusSearch) { _, _ in
                handleFocusTrigger()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(Theme.Animation.spring) {
                            appEnvironment?.selectedTab = 0
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private func handleFocusTrigger() {
        if appEnvironment?.shouldFocusSearch == true {
            isSearchFocused = true
            appEnvironment?.shouldFocusSearch = false
        }
    }
}

struct AnimatingSearchingView: View {
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            Text("Searching")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.Colors.textSecondary)
            
            HStack(spacing: 2) {
                Text(".")
                    .opacity(dotCount >= 1 ? 1 : 0)
                Text(".")
                    .opacity(dotCount >= 2 ? 1 : 0)
                Text(".")
                    .opacity(dotCount >= 3 ? 1 : 0)
            }
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundColor(Theme.Colors.textSecondary)
        }
        .onReceive(timer) { _ in
            withAnimation {
                dotCount = (dotCount + 1) % 4
            }
        }
    }
}

struct WordResultCard: View {
    let word: WordEntity
    @Bindable var viewModel: DiscoverViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Huge Icon Actions Row - Aligned Right
            HStack(spacing: 12) {
                Spacer()
                
                Button {
                    Task { await viewModel.toggleBookmark() }
                } label: {
                    CircleIconView(
                        icon: viewModel.isBookmarked ? "bookmark.fill" : "bookmark",
                        activeColor: Theme.Colors.amieOrange,
                        isActive: viewModel.isBookmarked
                    )
                }
                
                Button {
                    Task { await viewModel.toggleFavorite() }
                } label: {
                    CircleIconView(
                        icon: viewModel.isFavorited ? "heart.fill" : "heart",
                        activeColor: Color(red: 0.9, green: 0.2, blue: 0.2), // Darker red for heart
                        isActive: viewModel.isFavorited,
                        activeBgColor: Theme.Colors.amiePink.opacity(0.15)
                    )
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                StickerText(
                    text: word.word.capitalized,
                    size: 32
                )
                .padding(.leading, -8)
                .padding(.bottom, 4)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(word.definitions.prefix(3).enumerated()), id: \.offset) { index, def in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.Colors.textSecondary)
                            
                            Text(def.text)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            
            // Quick Add Tags
            let quickCollections = viewModel.quickAddCollections
            if !quickCollections.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("QUICK ADD")
                        .font(.system(size: 10, weight: .black))
                        .tracking(1.5)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(.top, 8)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickCollections) { collection in
                                let isIn = viewModel.isInCollection(collection)
                                Button {
                                    Task { await viewModel.addToCollection(collection) }
                                } label: {
                                    HStack(spacing: 6) {
                                        if isIn {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .bold))
                                        }
                                        Text(collection.name)
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(isIn ? Color(hex: collection.colorHex).opacity(0.1) : Theme.Colors.surface)
                                    .foregroundColor(isIn ? Color(hex: collection.colorHex) : Theme.Colors.textSecondary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(isIn ? Color(hex: collection.colorHex).opacity(0.3) : Theme.Colors.border, lineWidth: 1)
                                    )
                                }
                                .disabled(isIn)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .amieCard()
    }
}

private struct CircleIconView: View {
    let icon: String
    let activeColor: Color
    let isActive: Bool
    var activeBgColor: Color? = nil
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isActive ? (activeBgColor ?? activeColor.opacity(0.15)) : Theme.Colors.iconBackground)
                .frame(width: 44, height: 44)
            
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(isActive ? activeColor : .black)
        }
    }
}
