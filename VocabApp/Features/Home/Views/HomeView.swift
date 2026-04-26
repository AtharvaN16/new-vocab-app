import SwiftUI

struct HomeView: View {
    @State var viewModel: HomeViewModel
    @Environment(\.appEnvironment) private var appEnvironment

    @State private var lockedAxis: GestureAxis? = nil
    @State private var pullDownDistance: CGFloat = 0
    @State private var pullUpDistance: CGFloat = 0
    @State private var hasTriggeredDownHaptic = false
    @State private var hasTriggeredUpHaptic = false
    @State private var lastDownStep = 0
    @State private var lastUpStep = 0
    @State private var heartStates: [HeartState] = []
    @State private var messageState: MessageState? = nil

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

                    // Toast Banner
                    if viewModel.showToast {
                        VStack {
                            Spacer()
                            ToastBanner(
                                message: viewModel.toastMessage,
                                actionLabel: "Edit",
                                action: {
                                    viewModel.showToast = false
                                    viewModel.showAddToCollection = true
                                },
                                secondaryActionLabel: "Undo",
                                secondaryActionIcon: "arrow.uturn.backward",
                                secondaryAction: {
                                    Task { await viewModel.undoSaveToDefaultCollection() }
                                }
                            )
                            .padding(.bottom, 120)
                        }
                        .zIndex(20)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity.combined(with: .scale(scale: 0.9))
                        ))
                    }
                }
                .contentShape(Rectangle())
                .simultaneousGesture(viewModel.isExpanded ? nil : dragGesture)
            }
        }
        .overlay {
            ZStack {
                ForEach(heartStates) { state in
                    HeartOverlay(state: state) {
                        heartStates.removeAll(where: { $0.id == state.id })
                    }
                }
                
                MessageOverlay(
                    state: $messageState,
                    onRemove: { Task { await viewModel.removeFromFavorites() } }
                )
            }
            .ignoresSafeArea()
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
        .onChange(of: viewModel.currentIndex) {
            withAnimation { messageState = nil }
        }
        .onChange(of: viewModel.isExpanded) {
            withAnimation { messageState = nil }
        }
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
                    
                    // Ramp-up haptics
                    let downProgress = min(1, pullDownDistance / downThreshold)
                    let downStep = Int(downProgress * 20) // 0 to 20 (5% steps)
                    if downStep > lastDownStep && downStep < 20 {
                        let intensity = CGFloat(downStep) / 20.0
                        let generator = UIImpactFeedbackGenerator(style: .soft)
                        generator.impactOccurred(intensity: intensity)
                        lastDownStep = downStep
                    } else if downStep < lastDownStep {
                        lastDownStep = downStep
                    }

                    let upProgress = min(1, pullUpDistance / upThreshold)
                    let upStep = Int(upProgress * 20) // 0 to 20 (5% steps)
                    if upStep > lastUpStep && upStep < 20 {
                        let intensity = CGFloat(upStep) / 20.0
                        let generator = UIImpactFeedbackGenerator(style: .soft)
                        generator.impactOccurred(intensity: intensity)
                        lastUpStep = upStep
                    } else if upStep < lastUpStep {
                        lastUpStep = upStep
                    }

                    // Trigger final haptic when threshold is reached
                    if pullDownDistance >= downThreshold && !hasTriggeredDownHaptic {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        hasTriggeredDownHaptic = true
                    } else if pullDownDistance < downThreshold {
                        hasTriggeredDownHaptic = false
                    }
                    
                    if pullUpDistance >= upThreshold && !hasTriggeredUpHaptic {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        hasTriggeredUpHaptic = true
                    } else if pullUpDistance < upThreshold {
                        hasTriggeredUpHaptic = false
                    }
                }
            }
            .onEnded { v in
                defer { 
                    lockedAxis = nil
                    hasTriggeredDownHaptic = false
                    hasTriggeredUpHaptic = false
                    lastDownStep = 0
                    lastUpStep = 0
                }

                if lockedAxis == .vertical {
                    if pullDownDistance >= downThreshold {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            pullDownDistance = 0
                        } completion: {
                            appEnvironment?.shouldFocusSearch = true
                            appEnvironment?.selectedTab = 2
                        }
                    } else if pullUpDistance >= upThreshold && !viewModel.words.isEmpty {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            pullUpDistance = 0
                        } completion: {
                            Task { await viewModel.saveToDefaultCollection() }
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
        
        // Always spawn a heart
        heartStates.append(HeartState(tapPoint: point))
        
        // Handle message state transitions
        if alreadyFav {
            // If already showing "already" or "removed", don't restart the message flow
            if messageState?.type != .already && messageState?.type != .removed {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    messageState = MessageState(type: .already)
                }
                
                // Auto-dismiss Already message after delay
                let id = messageState?.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if messageState?.id == id {
                        withAnimation { messageState = nil }
                    }
                }
            }
        } else {
            // If just favorited, show "Added" and auto-dismiss
            if messageState?.type != .added {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    messageState = MessageState(type: .added)
                }
                Task { await viewModel.addToFavorites() }
                
                // Auto-dismiss Added message after delay
                let id = messageState?.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if messageState?.id == id {
                        withAnimation { messageState = nil }
                    }
                }
            }
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
