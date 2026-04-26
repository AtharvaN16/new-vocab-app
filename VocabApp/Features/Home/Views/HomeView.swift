import SwiftUI

struct HomeView: View {
    @State var viewModel: HomeViewModel
    @Environment(\.appEnvironment) private var appEnvironment

    @State private var lockedAxis: GestureAxis? = nil
    @State private var pullDownDistance: CGFloat = 0
    @State private var pullUpDistance: CGFloat = 0
    @State private var heartState: HeartState? = nil

    private let screenW = UIScreen.main.bounds.width

    // Pull-down (search)
    private let downFadeStart:  CGFloat = 20
    private let downFadeEnd:    CGFloat = 50
    private let downThreshold:  CGFloat = 120

    // Pull-up (bookmark)
    private let upFadeStart:    CGFloat = 10
    private let upFadeEnd:      CGFloat = 30
    private let upThreshold:    CGFloat = 60

    enum GestureAxis { case horizontal, vertical }

    private var contentShift: CGFloat { (pullDownDistance - pullUpDistance) * 0.32 }

    var body: some View {
        NavigationStack {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
            } else {
                ZStack {
                    if viewModel.words.isEmpty {
                        EmptyHomeState()
                    } else if let word = viewModel.currentWord {
                        WordCardView(
                            word: word,
                            isExpanded: $viewModel.isExpanded,
                            onSwipeNext: { 
                                viewModel.navigateNext()
                                viewModel.isExpanded = false
                            },
                            onSwipePrevious: { 
                                viewModel.navigatePrevious()
                                viewModel.isExpanded = false
                            },
                            onDoubleTap: { handleDoubleTap(at: $0) },
                            verticalOffset: contentShift
                        )
                    }

                    // Pull-down indicator (search, blue)
                    PullIndicator(
                        dragDistance: pullDownDistance,
                        fadeStart: downFadeStart, fadeEnd: downFadeEnd,
                        threshold: downThreshold,
                        icon: "magnifyingglass",
                        color: Theme.Colors.amieBlue
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 54)
                    .allowsHitTesting(false)

                    // Pull-up indicator (bookmark, orange)
                    if viewModel.currentWord != nil {
                        PullIndicator(
                            dragDistance: pullUpDistance,
                            fadeStart: upFadeStart, fadeEnd: upFadeEnd,
                            threshold: upThreshold,
                            icon: "bookmark.fill",
                            color: Theme.Colors.amieOrange
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 100)
                        .allowsHitTesting(false)
                    }

                    if let state = heartState {
                        HeartOverlay(state: state) { heartState = nil }
                    }
                }
                .contentShape(Rectangle())
                .simultaneousGesture(viewModel.isExpanded ? nil : dragGesture)
            }
        }
        .sheet(isPresented: $viewModel.showAddToCollection) {
            Task { await viewModel.loadData() }
        } content: {
            if let word = viewModel.currentWord {
                AddToCollectionSheet(viewModel: AddToCollectionViewModel(
                    word: word,
                    collectionRepository: viewModel.collectionRepository
                ))
            }
        }
        .task { await viewModel.loadData() }
        .toolbar {
            if !viewModel.isExpanded {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(Theme.Animation.spring) {
                            appEnvironment?.selectedTab = 1
                        }
                    } label: {
                        Image(systemName: "square.grid.2x2")
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(Theme.Animation.spring) {
                            appEnvironment?.selectedTab = 3
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .animation(.snappy, value: viewModel.isExpanded)
        } // NavigationStack
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { v in
                let tx = v.translation.width
                let ty = v.translation.height

                if lockedAxis == nil, abs(tx) > 8 || abs(ty) > 8 {
                    lockedAxis = abs(tx) > abs(ty) ? .horizontal : .vertical
                }

                if lockedAxis == .vertical {
                    pullDownDistance = max(0, ty)
                    if !viewModel.words.isEmpty {
                        pullUpDistance = max(0, -ty)
                    } else {
                        pullUpDistance = 0
                    }
                }
            }
            .onEnded { v in
                defer { lockedAxis = nil }

                if lockedAxis == .vertical {
                    if pullDownDistance >= downThreshold {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            pullDownDistance = 0
                        } completion: {
                            appEnvironment?.shouldFocusSearch = true
                            appEnvironment?.selectedTab = 2
                        }
                    } else if pullUpDistance >= upThreshold && !viewModel.words.isEmpty {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            pullUpDistance = 0
                        } completion: {
                            viewModel.showAddToCollection = true
                        }
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            pullDownDistance = 0
                            pullUpDistance   = 0
                        }
                    }
                }
            }
    }

    private func handleDoubleTap(at point: CGPoint) {
        let alreadyFav = viewModel.isCurrentWordFavorited
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        heartState = HeartState(tapPoint: point, alreadyAdded: alreadyFav)
        if !alreadyFav {
            Task { await viewModel.addToFavorites() }
        }
    }
}

private struct EmptyHomeState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.textSecondary)
            Text("No words yet")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(Theme.Colors.textPrimary)
            Text("Swipe down to search for words\nand start building your vocabulary.")
                .font(.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}
