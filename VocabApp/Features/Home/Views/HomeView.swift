import SwiftUI

struct HomeView: View {
    @State var viewModel: HomeViewModel

    @State private var lockedAxis: GestureAxis? = nil
    @State private var isTransitioning = false
    @State private var cardX: CGFloat = 0

    @State private var pullDownDistance: CGFloat = 0
    @State private var pullUpDistance: CGFloat = 0

    @State private var heartState: HeartState? = nil
    @State private var isExpanded = false

    private let screenW = UIScreen.main.bounds.width

    // Pull-down (bookmark) — matches useSwipeGesture.ts: BOOKMARK_FADE_START=20, SWIPE_DOWN_THRESHOLD=120
    private let downFadeStart:  CGFloat = 20
    private let downFadeEnd:    CGFloat = 50
    private let downThreshold:  CGFloat = 120

    // Pull-up (search) — matches usePullToSearch.ts: FADE_START=10, PULL_THRESHOLD=60
    private let upFadeStart:    CGFloat = 10
    private let upFadeEnd:      CGFloat = 30
    private let upThreshold:    CGFloat = 60

    enum GestureAxis { case horizontal, vertical }

    // Scale and opacity computed directly from card position — mirrors translateX interpolation
    private var cardScale:   CGFloat { max(0.8,  1.0 - abs(cardX) / screenW * 0.2) }
    private var cardOpacity: Double  { Double(max(0, 1.0 - abs(cardX) / screenW)) }

    // Word content shifts with vertical pull (SHOW MORE is kept outside this offset)
    private var contentShift: CGFloat { (pullDownDistance - pullUpDistance) * 0.32 }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.words.isEmpty {
                EmptyHomeState()
            } else if let word = viewModel.currentWord {

                // Card — horizontal swipe drives offset/scale/opacity
                wordContent(word: word)
                    .offset(x: cardX)
                    .scaleEffect(cardScale)
                    .opacity(cardOpacity)
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        SpatialTapGesture(count: 2, coordinateSpace: .global)
                            .onEnded { handleDoubleTap(at: $0.location) }
                    )
                    .simultaneousGesture(dragGesture)

                // SHOW MORE — outside card transform, stays fixed on vertical pull
                VStack {
                    Spacer()
                    Button {
                        withAnimation(Theme.Animation.spring) { isExpanded.toggle() }
                    } label: {
                        Text(isExpanded ? "SHOW LESS" : "SHOW MORE")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .padding(.bottom, 40)
                }
                .allowsHitTesting(!isTransitioning)

                // Pull-down indicator (bookmark, pink)
                PullIndicator(
                    dragDistance: pullDownDistance,
                    fadeStart: downFadeStart, fadeEnd: downFadeEnd,
                    threshold: downThreshold,
                    icon: "bookmark.fill",
                    color: Theme.Colors.amiePink
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 120)
                .allowsHitTesting(false)

                // Pull-up indicator (search, blue)
                PullIndicator(
                    dragDistance: pullUpDistance,
                    fadeStart: upFadeStart, fadeEnd: upFadeEnd,
                    threshold: upThreshold,
                    icon: "magnifyingglass",
                    color: Theme.Colors.amieBlue
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 120)
                .allowsHitTesting(false)

                if let state = heartState {
                    HeartOverlay(state: state) { heartState = nil }
                }
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
        .sheet(isPresented: $viewModel.showSearch) {
            HomeSearchSheet(words: viewModel.words)
        }
        .task { await viewModel.loadData() }
    }

    // MARK: - Word Content (only this shifts on vertical pull; SHOW MORE is a sibling)

    @ViewBuilder
    private func wordContent(word: WordEntity) -> some View {
        Group {
            if isExpanded {
                expandedContent(word: word)
            } else {
                collapsedContent(word: word)
            }
        }
        .offset(y: contentShift)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Collapsed

    @ViewBuilder
    private func collapsedContent(word: WordEntity) -> some View {
        VStack(spacing: 0) {
            Spacer()

            if let phonetic = word.phonetic, !phonetic.isEmpty {
                Text(phonetic)
                    .font(.system(size: 16, weight: .regular))
                    .tracking(-0.6)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .underline()
                    .padding(.bottom, 14)
            }

            Text(word.word.capitalized)
                .font(.system(size: 48, weight: .bold))
                .tracking(-1.9)
                .foregroundColor(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)

            if let def = word.definitions.first {
                Group {
                    if !def.partOfSpeech.isEmpty {
                        Text("(\(def.partOfSpeech)) ").fontWeight(.regular)
                        + Text(def.text)
                    } else {
                        Text(def.text)
                    }
                }
                .font(.system(size: 18, weight: .regular))
                .tracking(-0.7)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            }

            Spacer().frame(height: 100)

            if let example = word.examples.first {
                Text("\"\(example.text)\"")
                    .font(.system(size: 14, weight: .regular))
                    .tracking(-0.6)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }

    // MARK: - Expanded

    @ViewBuilder
    private func expandedContent(word: WordEntity) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                if let phonetic = word.phonetic, !phonetic.isEmpty {
                    Text(phonetic)
                        .font(.system(size: 16, weight: .regular))
                        .tracking(-0.6)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .underline()
                        .padding(.top, 28)
                        .padding(.bottom, 16)
                }

                Text(word.word.capitalized)
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-1.9)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.bottom, 6)

                if let pos = word.definitions.first?.partOfSpeech, !pos.isEmpty {
                    Text(pos)
                        .font(.system(size: 16))
                        .tracking(-0.6)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(.bottom, 24)
                }

                if let def = word.definitions.first {
                    Text(def.text)
                        .font(.system(size: 16))
                        .tracking(-0.7)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(.bottom, 36)
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

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func expandedSection<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(label)
                .font(.system(size: 16, design: .monospaced))
                .foregroundColor(Theme.Colors.textPrimary)
            content()
        }
        .padding(.bottom, 36)
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { v in
                guard !isTransitioning else { return }
                let tx = v.translation.width
                let ty = v.translation.height

                if lockedAxis == nil, abs(tx) > 8 || abs(ty) > 8 {
                    lockedAxis = abs(tx) > abs(ty) ? .horizontal : .vertical
                }

                switch lockedAxis {
                case .horizontal:
                    cardX = tx                        // 1:1 finger tracking
                case .vertical:
                    pullDownDistance = max(0, ty)
                    pullUpDistance   = max(0, -ty)
                case nil: break
                }
            }
            .onEnded { v in
                guard !isTransitioning else { return }
                defer { lockedAxis = nil }

                let tx = v.translation.width
                let vx = v.velocity.width

                switch lockedAxis {
                case .horizontal:
                    if tx < -(screenW * 0.3) || vx < -500    { swipeCard(direction: -1) }
                    else if tx > (screenW * 0.3) || vx > 500 { swipeCard(direction: 1) }
                    else {
                        // Snap-back: tension:100 friction:10 ≈ response:0.6 damping:0.5
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                            cardX = 0
                        }
                    }

                case .vertical:
                    if pullDownDistance >= downThreshold {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            pullDownDistance = 0
                        } completion: {
                            viewModel.showAddToCollection = true
                        }
                    } else if pullUpDistance >= upThreshold {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            pullUpDistance = 0
                        } completion: {
                            viewModel.showSearch = true
                        }
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            pullDownDistance = 0
                            pullUpDistance   = 0
                        }
                    }

                case nil: break
                }
            }
    }

    // MARK: - Swipe Card

    private func swipeCard(direction: CGFloat) {
        isTransitioning = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Exit: easeInOut 300ms — matches Animated.timing default easing
        withAnimation(.easeInOut(duration: 0.3)) {
            cardX = direction * screenW
        } completion: {
            if direction < 0 { viewModel.navigateNext() }
            else             { viewModel.navigatePrevious() }
            isExpanded = false

            cardX = -direction * screenW   // instant — new card starts off-screen

            // Entry: tension:65 friction:10 ≈ response:0.8 damping:0.62 (bouncy)
            withAnimation(.spring(response: 0.8, dampingFraction: 0.62)) {
                cardX = 0
            }
            isTransitioning = false         // allow new swipe during entry spring
        }
    }

    // MARK: - Double Tap → Favorite

    private func handleDoubleTap(at point: CGPoint) {
        let alreadyFav = viewModel.isCurrentWordFavorited
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // Show heart immediately — don't wait for async favorites update
        heartState = HeartState(tapPoint: point, alreadyAdded: alreadyFav)
        if !alreadyFav {
            Task { await viewModel.addToFavorites() }
        }
    }
}

// MARK: - Pull Indicator

private struct PullIndicator: View {
    let dragDistance: CGFloat
    let fadeStart: CGFloat
    let fadeEnd: CGFloat
    let threshold: CGFloat
    let icon: String
    let color: Color

    @State private var iconBounced = false

    private let radius: CGFloat = 35
    private let strokeWidth: CGFloat = 3.5

    // Container opacity/scale: 0 before fadeStart, ramps to 1 at fadeEnd
    private var indicatorProgress: CGFloat {
        guard dragDistance > fadeStart else { return 0 }
        return min(1, (dragDistance - fadeStart) / (fadeEnd - fadeStart))
    }

    // Ring fill progress: 0 at fadeStart, 1 at threshold
    private var ringProgress: CGFloat {
        guard dragDistance > fadeStart else { return 0 }
        return min(1, (dragDistance - fadeStart) / (threshold - fadeStart))
    }

    // Colored glow appears as ring nears 100%
    private var glowOpacity: Double {
        Double(min(1, max(0, (ringProgress - 0.8) / 0.2)))
    }

    var body: some View {
        let diameter = radius * 2
        ZStack {
            // Colored glow halo (spreads beyond the circle)
            Circle()
                .fill(color.opacity(0.4))
                .frame(width: diameter + 28, height: diameter + 28)
                .blur(radius: 14)
                .opacity(glowOpacity)

            // Frosted white background with color-tinted shadow
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: diameter, height: diameter)
                .shadow(color: color.opacity(0.18 + glowOpacity * 0.28),
                        radius: 8 + CGFloat(glowOpacity) * 10, x: 0, y: 2)

            // Track ring (very subtle)
            Circle()
                .stroke(Color.primary.opacity(0.07), lineWidth: strokeWidth)
                .frame(width: diameter, height: diameter)

            // Colored progress ring
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: diameter, height: diameter)
                .rotationEffect(.degrees(-90))

            // Icon — colored, bounces when ring completes
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .scaleEffect(iconBounced ? 1.4 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.35), value: iconBounced)
        }
        // Container fades and scales in as user starts pulling (0.5→1.0 scale)
        .scaleEffect(0.5 + 0.5 * indicatorProgress)
        .opacity(Double(indicatorProgress))
        .onChange(of: ringProgress) { _, new in
            guard new >= 1, !iconBounced else { return }
            iconBounced = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { iconBounced = false }
        }
    }
}

// MARK: - Heart Animation

struct HeartState {
    let tapPoint: CGPoint
    let alreadyAdded: Bool
}

private struct HeartOverlay: View {
    let state: HeartState
    let onDone: () -> Void

    @State private var heartY: CGFloat = 0
    @State private var heartSwayX: CGFloat = 0
    @State private var heartScale: CGFloat = 0
    @State private var heartOpacity: Double = 0
    @State private var msgScale: CGFloat = 0
    @State private var msgOpacity: Double = 0

    var body: some View {
        ZStack {
            Text(state.alreadyAdded ? "Already in favorites" : "Added to favorites")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.Colors.textPrimary)
                .scaleEffect(msgScale)
                .opacity(msgOpacity)
                .position(x: UIScreen.main.bounds.width / 2, y: 120)

            if !state.alreadyAdded {
                Text("❤️")
                    .font(.system(size: 80))
                    .scaleEffect(heartScale)
                    .opacity(heartOpacity)
                    .offset(x: heartSwayX, y: heartY)
                    .position(x: state.tapPoint.x, y: state.tapPoint.y)
            }
        }
        .allowsHitTesting(false)
        .onAppear(perform: animate)
    }

    private func animate() {
        // Phase 1 — pop in (tension:100 friction:5 ≈ response:0.6 damping:0.25, very bouncy)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.25)) {
            heartScale = 1; heartOpacity = 1
            msgScale   = 1; msgOpacity   = 1
        } completion: {
            if state.alreadyAdded {
                withAnimation(.easeOut(duration: 0.4).delay(2.5)) {
                    msgOpacity = 0; msgScale = 0.85
                } completion: { onDone() }
                return
            }

            // Phase 2 — float up (linear, matches Animated.timing default)
            // Sway runs in parallel: 3 segments × 400ms = 1200ms = float duration
            let targetY = -(state.tapPoint.y - 120)
            withAnimation(.linear(duration: 1.2)) {
                heartY = targetY
            } completion: {
                // Phase 3 — collision pop + fade (tension:100 friction:3 ≈ very bouncy)
                withAnimation(.spring(response: 0.2, dampingFraction: 0.15)) {
                    heartScale = 1.3; msgScale = 1.2
                }
                withAnimation(.easeOut(duration: 0.3)) {
                    heartOpacity = 0; msgOpacity = 0
                } completion: { onDone() }
            }

            // Sway: three 400ms linear segments (parallel to float)
            withAnimation(.linear(duration: 0.4)) { heartSwayX = 20  } completion: {
                withAnimation(.linear(duration: 0.4)) { heartSwayX = -20 } completion: {
                    withAnimation(.linear(duration: 0.4)) { heartSwayX = 0 }
                }
            }
        }
    }
}

// MARK: - Word Flow Row

private struct WordFlowRow: View {
    let items: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { word in
                Text(word)
                    .font(.system(size: 16))
                    .tracking(-0.6)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .underline()
                    .padding(.bottom, 4)
            }
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0; var x: CGFloat = 0; var lineH: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > width, x > 0 { height += lineH + spacing; x = 0; lineH = 0 }
            x += s.width + spacing; lineH = max(lineH, s.height)
        }
        return CGSize(width: width, height: height + lineH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var lineH: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { y += lineH + spacing; x = bounds.minX; lineH = 0 }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; lineH = max(lineH, s.height)
        }
    }
}

// MARK: - Home Search Sheet

struct HomeSearchSheet: View {
    let words: [WordEntity]
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private var results: [WordEntity] {
        guard !query.isEmpty else { return words }
        return words.filter { $0.word.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List(results) { word in
                VStack(alignment: .leading, spacing: 4) {
                    Text(word.word.capitalized)
                        .font(.system(.body).weight(.semibold))
                    if let def = word.definitions.first {
                        Text(def.text)
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineLimit(2)
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(.plain)
            .searchable(text: $query,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search your words")
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Empty State

private struct EmptyHomeState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.textSecondary)
            Text("No words yet")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(Theme.Colors.textPrimary)
            Text("Search for words in the Discover tab\nto start building your vocabulary.")
                .font(.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}
