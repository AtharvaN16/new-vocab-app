import SwiftUI

struct WordDetailView: View {
    @State var viewModel: WordDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Gesture State
    @State private var offset: CGSize = .zero
    @State private var isSwipingVertical: Bool = false
    @State private var showHeartAnimation: Bool = false
    @State private var heartPosition: CGPoint = .zero
    
    // Constants
    private let horizontalThreshold: CGFloat = 100
    private let verticalThreshold: CGFloat = 80

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            
            VStack {
                // Header
                HStack(spacing: 16) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(8)
                            .background(Theme.Colors.surface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Theme.Colors.border, lineWidth: 1))
                    }
                    Spacer()
                    
                    HStack(spacing: 8) {
                        if viewModel.isBookmarked {
                            Image(systemName: "bookmark.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.Colors.amieBlue)
                                .padding(10)
                                .background(Theme.Colors.surface)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Theme.Colors.border, lineWidth: 1))
                        }
                        if viewModel.isFavorited {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.Colors.amiePink)
                                .padding(10)
                                .background(Theme.Colors.surface)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Theme.Colors.border, lineWidth: 1))
                        }
                    }
                }
                .padding()
                
                Spacer()
                
                // Main Card
                ZStack {
                    WordCardContent(word: viewModel.word, isExpanded: $viewModel.isExpanded)
                        .offset(offset)
                        .rotationEffect(.degrees(Double(offset.width / 20)))
                        .gesture(
                            ExclusiveGesture(
                                TapGesture(count: 2).onEnded {
                                    handleDoubleTap()
                                },
                                DragGesture()
                                    .onChanged { gesture in
                                        handleDragChanged(gesture)
                                    }
                                    .onEnded { gesture in
                                        handleDragEnded(gesture)
                                    }
                            )
                        )
                        .animation(.interactiveSpring(), value: offset)
                    
                    // Heart Animation Overlay
                    if showHeartAnimation {
                        HeartAnimationView()
                            .position(heartPosition)
                            .transition(.asymmetric(insertion: .scale, removal: .opacity))
                    }
                    
                    // Swipe Indicators
                    swipeIndicators
                }
                .frame(maxWidth: .infinity, maxHeight: 600)
                .padding(24)
                
                Spacer()
                
                // Expand Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(Theme.Animation.spring) {
                        viewModel.isExpanded.toggle()
                    }
                }) {
                    Text(viewModel.isExpanded ? "SHOW LESS" : "SHOW MORE")
                        .font(.system(size: 12, weight: .black))
                        .tracking(1)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(Theme.Colors.surface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.Colors.border, lineWidth: 1))
                }
                .buttonStyle(AmieButtonStyle())
                .padding(.bottom, 30)
            }
        }
    }
    
    private var swipeIndicators: some View {
        Group {
            if offset.height > 20 {
                VStack {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.Colors.amieBlue)
                        .opacity(min(Double(offset.height / verticalThreshold), 1.0))
                    Spacer()
                }
                .padding(.top, 40)
            } else if offset.height < -20 {
                VStack {
                    Spacer()
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.Colors.amieBlue)
                        .opacity(min(Double(-offset.height / verticalThreshold), 1.0))
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Gesture Handlers
    
    private func handleDoubleTap() {
        heartPosition = CGPoint(x: UIScreen.main.bounds.width / 2, y: 300)
        withAnimation(.spring()) {
            showHeartAnimation = true
        }
        
        Task {
            await viewModel.toggleFavorite()
            try? await Task.sleep(nanoseconds: 800_000_000)
            withAnimation {
                showHeartAnimation = false
            }
        }
    }
    
    private func handleDragChanged(_ gesture: DragGesture.Value) {
        let translation = gesture.translation
        
        // Determine primary axis
        if !isSwipingVertical && abs(translation.width) < 10 && abs(translation.height) > 10 {
            isSwipingVertical = true
        }
        
        if isSwipingVertical {
            // Constrain vertical swipe
            offset = CGSize(width: 0, height: translation.height)
        } else {
            // Standard horizontal swipe
            offset = translation
        }
    }
    
    private func handleDragEnded(_ gesture: DragGesture.Value) {
        let translation = gesture.translation
        
        if isSwipingVertical {
            if translation.height > verticalThreshold {
                Task { await viewModel.toggleBookmark() }
            } else if translation.height < -verticalThreshold {
                viewModel.showCollections = true
            }
        } else {
            if translation.width > horizontalThreshold {
                Task {
                    withAnimation(.easeOut(duration: 0.2)) {
                        offset = CGSize(width: 500, height: 0)
                    }
                    await viewModel.navigatePrevious()
                    offset = CGSize(width: -500, height: 0)
                    withAnimation(.spring()) {
                        offset = .zero
                    }
                }
            } else if translation.width < -horizontalThreshold {
                Task {
                    withAnimation(.easeOut(duration: 0.2)) {
                        offset = CGSize(width: -500, height: 0)
                    }
                    await viewModel.navigateNext()
                    offset = CGSize(width: 500, height: 0)
                    withAnimation(.spring()) {
                        offset = .zero
                    }
                }
            }
        }
        
        withAnimation(.spring()) {
            offset = .zero
            isSwipingVertical = false
        }
    }
}

struct WordCardContent: View {
    let word: WordEntity
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(word.word.capitalized)
                    .font(.system(size: 44, weight: .bold, design: .serif))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                if let phonetic = word.phonetic {
                    Text(phonetic)
                        .font(.system(.title2, design: .rounded))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .padding(.top, 10)
            
            if let mnemonic = word.aiMnemonic {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.Colors.amieBlue)
                        Text("MNEMONIC")
                            .font(.system(size: 10, weight: .black))
                            .tracking(1.5)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    Text(mnemonic)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .lineSpacing(4)
                        .foregroundColor(Theme.Colors.textPrimary)
                }
                .padding(20)
                .background(Theme.Colors.amieBlue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            
            if isExpanded {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(word.definitions, id: \.text) { def in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(def.partOfSpeech.uppercased())
                                        .font(.system(size: 10, weight: .black))
                                        .tracking(1.5)
                                        .foregroundColor(Theme.Colors.amiePink)
                                    
                                    Text(def.text)
                                        .font(.system(size: 17, weight: .medium, design: .rounded))
                                        .lineSpacing(4)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                }
                            }
                        }
                        
                        if !word.examples.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("EXAMPLES")
                                    .font(.system(size: 10, weight: .black))
                                    .tracking(1.5)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                
                                ForEach(word.examples, id: \.text) { ex in
                                    Text("\"\(ex.text)\"")
                                        .font(.system(size: 16, design: .serif))
                                        .italic()
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            } else {
                // Collapsed Preview
                if let firstDef = word.definitions.first {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(firstDef.partOfSpeech.uppercased())
                            .font(.system(size: 10, weight: .black))
                            .tracking(1.5)
                            .foregroundColor(Theme.Colors.amiePink)
                        Text(firstDef.text)
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(3)
                    }
                }
                Spacer()
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .amieCard()
    }
}

struct HeartAnimationView: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 1.0

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 100))
            .foregroundColor(.red)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = 1.2
                }
                withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                    scale = 1.5
                    opacity = 0
                }
            }
    }
}
