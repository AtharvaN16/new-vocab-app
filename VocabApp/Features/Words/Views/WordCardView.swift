import SwiftUI

struct WordCardView: View {
    let word: WordEntity
    @Binding var isExpanded: Bool
    let onSwipeNext: () -> Void
    let onSwipePrevious: () -> Void
    let onDoubleTap: (CGPoint) -> Void
    var showToggle: Bool = true
    var isFullHeight: Bool = false
    var verticalOffset: CGFloat = 0
    @State private var motion = MotionManager()
    @State private var cardX: CGFloat = 0
    @State private var isTransitioning = false
    @State private var lockedAxis: GestureAxis? = nil
    
    private let collapsedMaxDeg = 14.0
    private let expandedMaxDeg = 14.0
    private let screenW = UIScreen.main.bounds.width
    
    // Fades tilt to zero as card is dragged
    private var tiltMultiplier: Double { max(0, 1.0 - abs(Double(cardX)) / 50.0) }
    private var cardScale: CGFloat { max(0.8, 1.0 - abs(cardX) / screenW * 0.2) }
    private var cardOpacity: Double { Double(max(0, 1.0 - abs(cardX) / screenW)) }

    enum GestureAxis { case horizontal, vertical }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if isExpanded {
                    WordExpandedContentView(
                        word: word,
                        isFullHeight: isFullHeight,
                        tiltX: motion.tiltX,
                        tiltY: motion.tiltY,
                        tiltMultiplier: tiltMultiplier
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .move(edge: .bottom))
                    ))
                } else {
                    collapsedContent(word: word)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .offset(x: cardX, y: verticalOffset)
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
            .simultaneousGesture(
                isExpanded ? nil :
                SpatialTapGesture(count: 2, coordinateSpace: .global)
                    .onEnded { handleDoubleTap(at: $0.location) }
            )
            .simultaneousGesture(isExpanded ? nil : dragGesture)
            
            // SHOW MORE / CLOSE Button at the bottom
            if showToggle {
                VStack {
                    Spacer()
                    Button {
                        withAnimation(.snappy(duration: 0.4, extraBounce: 0.1)) { 
                            isExpanded.toggle() 
                        }
                    } label: {
                        Text(isExpanded ? "CLOSE" : "SHOW MORE")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.vertical, 20)
                            .padding(.horizontal, 40)
                            .background(Color.clear)
                    }
                    .padding(.bottom, 20)
                }
                .allowsHitTesting(!isTransitioning)
            }
        }
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
    }

    @ViewBuilder
    private func collapsedContent(word: WordEntity) -> some View {
        VStack(spacing: 0) {
            Spacer()
            Spacer()

            // 1. Phonetic Slot (Fixed height to prevent jumping)
            Group {
                if let phonetic = word.phonetic, !phonetic.isEmpty {
                    Text(phonetic)
                        .font(.system(size: 16, weight: .regular))
                        .tracking(-0.6)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .underline()
                } else {
                    Text(" ") // Invisible placeholder to hold space
                }
            }
            .frame(height: 20)
            .padding(.bottom, 14)

            // 2. Word Anchor
            StickerText(
                text: word.word.capitalized,
                size: 48
            )
            .rotation3DEffect(
                .degrees(motion.tiltX * collapsedMaxDeg * tiltMultiplier),
                axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.5
            )
            .rotation3DEffect(
                .degrees(motion.tiltY * collapsedMaxDeg * tiltMultiplier),
                axis: (x: 0, y: 1, z: 0), anchor: .bottom, perspective: 0.5
            )
            .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
            .padding(.horizontal, 20)
            .frame(height: 60) // Fixed height for the word sticker area
            .padding(.bottom, 32)

            // 3. Definition Slot (Fixed height for 3 lines max)
            VStack(spacing: 0) {
                if let def = word.definitions.first {
                    Group {
                        if !def.partOfSpeech.isEmpty {
                            Text("(\(def.partOfSpeech)) ").fontWeight(.bold)
                            + Text(def.text)
                        } else {
                            Text(def.text)
                        }
                    }
                    .font(.system(size: 18, weight: .regular))
                    .tracking(-0.7)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(minHeight: 70, alignment: .top) // Fixed slot for definition
                }
            }
            .padding(.horizontal, 32)

            Spacer().frame(height: 40)

            // 4. Example Slot (Fixed height for 2 lines max)
            VStack(spacing: 0) {
                if let example = word.examples.first {
                    Text("\"\(example.text)\"")
                        .font(.system(size: 14, weight: .regular))
                        .tracking(-0.6)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .italic()
                }
            }
            .frame(height: 40, alignment: .top)
            .padding(.horizontal, 40)

            Spacer()
            Spacer()
            Spacer()
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { v in
                guard !isTransitioning else { return }
                let tx = v.translation.width
                let ty = v.translation.height

                if lockedAxis == nil, abs(tx) > 8 || abs(ty) > 8 {
                    lockedAxis = abs(tx) > abs(ty) ? .horizontal : .vertical
                }

                if lockedAxis == .horizontal {
                    cardX = tx
                }
            }
            .onEnded { v in
                guard !isTransitioning else { return }
                defer { lockedAxis = nil }

                let tx = v.translation.width
                let vx = v.velocity.width

                if lockedAxis == .horizontal {
                    if tx < -(screenW * 0.3) || vx < -500    { swipeCard(direction: -1) }
                    else if tx > (screenW * 0.3) || vx > 500 { swipeCard(direction: 1) }
                    else {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                            cardX = 0
                        }
                    }
                }
            }
    }

    private func swipeCard(direction: CGFloat) {
        isTransitioning = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.easeInOut(duration: 0.3)) {
            cardX = direction * screenW
        } completion: {
            if direction < 0 { onSwipeNext() }
            else             { onSwipePrevious() }

            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                cardX = -direction * screenW
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.62)) {
                    cardX = 0
                }
                isTransitioning = false
            }
        }
    }

    private func handleDoubleTap(at point: CGPoint) {
        onDoubleTap(point)
    }
}
