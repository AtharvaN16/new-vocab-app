import SwiftUI
import UIKit

enum Theme {
    // MARK: - Colors
    enum Colors {
        static let background = Color(red: 0.976, green: 0.976, blue: 0.973)
        static let surface = Color.white
        static let border = Color.black.opacity(0.06)
        static let iconBackground = Color(red: 0.949, green: 0.949, blue: 0.949)

        static let amiePink = Color(red: 1.0, green: 0.44, blue: 0.64)
        static let amieYellow = Color(red: 1.0, green: 0.93, blue: 0.47)
        static let amieBlue = Color(red: 0.36, green: 0.65, blue: 1.0)
        static let amieGreen = Color(red: 0.42, green: 0.83, blue: 0.58)
        static let amieOrange = Color(red: 1.0, green: 0.55, blue: 0.0)
        static let selection = Color(red: 0.31, green: 0.63, blue: 0.86) // #4fa1dc

        static let textPrimary = Color.black.opacity(0.9)
        static let textSecondary = Color.black.opacity(0.5)
    }

    // MARK: - Spacing & Corner Radius
    enum Layout {
        static let cornerRadius: CGFloat = 20
        static let pillRadius: CGFloat = 100
        static let padding: CGFloat = 16
        static let borderWidth: CGFloat = 1.0
    }

    // MARK: - Animations
    enum Animation {
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0)
        static let snappy = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)
    }
}

// MARK: - StickerTextLayer
final class StickerTextLayer: UIView {
    private class RoundedLabel: UILabel {
        override func drawText(in rect: CGRect) {
            let context = UIGraphicsGetCurrentContext()
            context?.setLineJoin(.round)
            context?.setLineCap(.round)
            super.drawText(in: rect)
        }
    }

    private let borderLabel = RoundedLabel()
    private let whiteLabel  = RoundedLabel()
    private let fillLabel   = RoundedLabel()
    private var fontSizeCache: CGFloat = 32

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        tintColor = .black
        for label in [borderLabel, whiteLabel, fillLabel] {
            label.tintColor = .black
            label.numberOfLines = 1
            label.textAlignment = .center
            label.clipsToBounds = false
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.5
            label.baselineAdjustment = .alignCenters
            addSubview(label)
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        tintColor = .black
        for label in [borderLabel, whiteLabel, fillLabel] { label.tintColor = .black }
    }

    func configure(text: String, fontSize: CGFloat, fillColor: UIColor) {
        fontSizeCache = fontSize
        let font = Self.stickerFont(size: fontSize)

        let shadow = NSShadow()
        shadow.shadowColor      = UIColor.black.withAlphaComponent(0.20)
        shadow.shadowOffset     = CGSize(width: 0, height: 4)
        shadow.shadowBlurRadius = 6

        borderLabel.attributedText = NSAttributedString(string: text, attributes: [
            .font: font,
            .strokeColor: UIColor.black.withAlphaComponent(0.12),
            .strokeWidth: -26.0,
            .foregroundColor: UIColor.white,
            .shadow: shadow
        ])

        whiteLabel.attributedText = NSAttributedString(string: text, attributes: [
            .font: font,
            .strokeColor: UIColor.white,
            .strokeWidth: 24.0
        ])

        fillLabel.attributedText = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: fillColor
        ])

        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        borderLabel.frame = bounds
        whiteLabel.frame  = bounds
        fillLabel.frame   = bounds
    }

    override var intrinsicContentSize: CGSize {
        let baseSize = fillLabel.intrinsicContentSize
        let horizontalPadding = fontSizeCache * 0.4
        let verticalPadding   = fontSizeCache * 0.4
        return CGSize(
            width: baseSize.width + horizontalPadding,
            height: baseSize.height + verticalPadding + 10
        )
    }

    private static func stickerFont(size: CGFloat) -> UIFont {
        if let f = UIFont(name: "DynaPuff-Medium", size: size) { return f }
        if let f = UIFont(name: "DynaPuff",        size: size) { return f }
        var desc = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
        if let rounded = desc.withDesign(.rounded) { desc = rounded }
        desc = desc.withSymbolicTraits(.traitBold) ?? desc
        return UIFont(descriptor: desc, size: size)
    }
}

// MARK: - StickerText
struct StickerText: UIViewRepresentable {
    let text: String
    let size: CGFloat
    var fillColor: Color = .black

    init(text: String, size: CGFloat, fillColor: Color = .black) {
        self.text = text
        self.size = size
        self.fillColor = fillColor
    }

    func makeUIView(context: Context) -> StickerTextLayer {
        StickerTextLayer()
    }

    func updateUIView(_ uiView: StickerTextLayer, context: Context) {
        uiView.configure(text: text, fontSize: size, fillColor: UIColor(fillColor))
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: StickerTextLayer, context: Context) -> CGSize? {
        uiView.intrinsicContentSize
    }
}

// MARK: - Amie-style card modifier
struct AmieCard: ViewModifier {
    var backgroundColor: Color = Theme.Colors.surface

    init(backgroundColor: Color = Theme.Colors.surface) {
        self.backgroundColor = backgroundColor
    }

    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .cornerRadius(Theme.Layout.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius)
                    .stroke(Theme.Colors.border, lineWidth: Theme.Layout.borderWidth)
            )
    }
}

extension View {
    func amieCard(backgroundColor: Color = Theme.Colors.surface) -> some View {
        self.modifier(AmieCard(backgroundColor: backgroundColor))
    }
}

struct AmieButtonStyle: ButtonStyle {
    init() {}
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(Theme.Animation.snappy, value: configuration.isPressed)
    }
}

// MARK: - Liquid Glass System (iOS 26+)

enum GlassVariant {
    case regular, clear
}

struct LiquidGlassModifier<S: Shape>: ViewModifier {
    let variant: GlassVariant
    let shape: S
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                shape
                    .fill(.ultraThinMaterial)
                    .overlay {
                        shape.stroke(
                            colorScheme == .light 
                            ? Color.black.opacity(0.05) 
                            : Color.white.opacity(0.3), 
                            lineWidth: 0.5
                        )
                    }
                    .overlay {
                        shape.stroke(Color.white.opacity(0.4), lineWidth: 1.0)
                            .blendMode(.screen)
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
            }
    }
}

extension View {
    @ViewBuilder
    func glassEffect(_ glass: GlassVariant = .regular, in shape: some Shape = Circle()) -> some View {
        if #available(iOS 26, *) {
            self.modifier(LiquidGlassModifier(variant: glass, shape: shape))
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}

// MARK: - Unified UI Components

struct IconButton: View {
    let icon: String
    let action: () -> Void
    var size: CGFloat = 52
    var iconSize: CGFloat = 24

    init(icon: String, size: CGFloat = 52, iconSize: CGFloat = 24, action: @escaping () -> Void) {
        self.icon = icon
        self.size = size
        self.iconSize = iconSize
        self.action = action
    }

    @State private var isVisible = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
                .frame(width: size, height: size)
                .glassEffect()
        }
        .buttonStyle(AmieButtonStyle())
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            let delay = (icon == "xmark" || icon == "xmark.circle.fill") ? 0.35 : 0.0
            withAnimation(Theme.Animation.spring.delay(delay)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Dot Matrix Background
struct DotMatrixBackground: View {
    init() {}
    var body: some View {
        Canvas { context, size in
            let dotSize: CGFloat = 3
            let spacing: CGFloat = 24
            let dotColor: Color = Color.black.opacity(0.07)
            for x in stride(from: 12, through: size.width, by: spacing) {
                for y in stride(from: 12, through: size.height, by: spacing) {
                    let rect = CGRect(x: x - dotSize/2, y: y - dotSize/2, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Shared Layout Components

struct WordFlowRow: View {
    let items: [String]
    init(items: [String]) { self.items = items }
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

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    init(spacing: CGFloat = 8) { self.spacing = spacing }
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

// MARK: - Pull Indicator Component

struct PullIndicator: View {
    let dragDistance: CGFloat
    let fadeStart: CGFloat
    let fadeEnd: CGFloat
    let threshold: CGFloat
    let icon: String
    let color: Color

    init(dragDistance: CGFloat, fadeStart: CGFloat, fadeEnd: CGFloat, threshold: CGFloat, icon: String, color: Color) {
        self.dragDistance = dragDistance
        self.fadeStart = fadeStart
        self.fadeEnd = fadeEnd
        self.threshold = threshold
        self.icon = icon
        self.color = color
    }

    private let radius: CGFloat = 35
    private let strokeWidth: CGFloat = 3.5

    private var indicatorProgress: CGFloat {
        guard dragDistance > fadeStart else { return 0 }
        return min(1, (dragDistance - fadeStart) / (fadeEnd - fadeStart))
    }

    private var ringProgress: CGFloat {
        guard dragDistance > fadeStart else { return 0 }
        return min(1, (dragDistance - fadeStart) / (threshold - fadeStart))
    }

    private var glowOpacity: Double {
        Double(min(1, max(0, (ringProgress - 0.8) / 0.2)))
    }

    var body: some View {
        let diameter = radius * 2
        ZStack {
            Circle()
                .fill(color.opacity(0.4))
                .frame(width: diameter + 28, height: diameter + 28)
                .blur(radius: 14)
                .opacity(glowOpacity)

            Circle()
                .fill(Theme.Colors.surface)
                .frame(width: diameter, height: diameter)
                .shadow(color: color.opacity(0.18 + glowOpacity * 0.28),
                        radius: 8 + CGFloat(glowOpacity) * 10, x: 0, y: 2)

            Circle()
                .stroke(Color.primary.opacity(0.07), lineWidth: strokeWidth)
                .frame(width: diameter, height: diameter)

            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: diameter, height: diameter)
                .rotationEffect(.degrees(-90))

            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(color)
                .scaleEffect(ringProgress >= 1 ? 1.3 : 1.0)
                .animation(.spring(duration: 0.35, bounce: 0.3), value: ringProgress >= 1)
        }
        .scaleEffect(0.5 + 0.5 * indicatorProgress)
        .opacity(Double(indicatorProgress))
    }
}

// MARK: - Heart Overlay Animation

struct PixelHeart: View {
    let color: Color
    var showHighlight: Bool = true
    var shimmerOffset: Int = -20 // In pixel units

    var body: some View {
        Canvas { context, size in
            let px = size.width / 16
            let py = size.height / 16
            
            func drawPixel(x: Int, y: Int, color: Color) {
                let rect = CGRect(x: CGFloat(x) * px, y: CGFloat(y) * py, width: px, height: py)
                context.fill(Path(rect), with: .color(color))
            }
            
            // 1. Heart Grid Definition (16x16)
            let heartPixels: Set<[Int]> = {
                var pixels = Set<[Int]>()
                for x in 3...5 { pixels.insert([x, 2]) }
                for x in 10...12 { pixels.insert([x, 2]) }
                for x in 2...6 { pixels.insert([x, 3]) }
                for x in 9...13 { pixels.insert([x, 3]) }
                for y in 4...8 { for x in 1...14 { pixels.insert([x, y]) } }
                for x in 2...13 { pixels.insert([x, 9]) }
                for x in 3...12 { pixels.insert([x, 10]) }
                for x in 4...11 { pixels.insert([x, 11]) }
                for x in 5...10 { pixels.insert([x, 12]) }
                for x in 6...9 { pixels.insert([x, 13]) }
                for x in 7...8 { pixels.insert([x, 14]) }
                return pixels
            }()
            
            // 2. Draw Pixel Shadow (Offset black pixels)
            for p in heartPixels {
                drawPixel(x: p[0] + 1, y: p[1] + 1, color: Color.black.opacity(0.12))
            }
            
            // 3. Draw Body (Border + Fill + Shimmer)
            for p in heartPixels {
                let x = p[0]
                let y = p[1]
                
                // Border Check: If any neighbor is empty, it's a border
                let isBorder = !heartPixels.contains([x-1, y]) || 
                               !heartPixels.contains([x+1, y]) || 
                               !heartPixels.contains([x, y-1]) || 
                               !heartPixels.contains([x, y+1])
                
                if isBorder {
                    drawPixel(x: x, y: y, color: .black)
                } else {
                    var pixelColor = color
                    
                    // Static Highlight
                    if showHighlight {
                        if (x == 3 && y == 3) || (x == 4 && y == 3) || (x == 3 && y == 4) {
                            pixelColor = .white.opacity(0.8)
                        } else if (x == 5 && y == 3) || (x == 4 && y == 4) || (x == 3 && y == 5) {
                            pixelColor = .white.opacity(0.3)
                        }
                    }
                    
                    // CURVED Shimmer (Circular arc sweep)
                    let dx = CGFloat(x) + 4
                    let dy = CGFloat(y) + 4
                    let dist = sqrt(dx*dx + dy*dy)
                    let targetDist = CGFloat(shimmerOffset)
                    
                    if abs(dist - targetDist) < 1.4 {
                        pixelColor = .white.opacity(0.4)
                    }
                    
                    drawPixel(x: x, y: y, color: pixelColor)
                }
            }
        }
    }
}

struct HeartState: Identifiable {
    let id = UUID()
    let tapPoint: CGPoint
    let swayOffset: CGFloat
    let rotation: Double
    
    init(tapPoint: CGPoint) {
        self.tapPoint = tapPoint
        self.swayOffset = CGFloat.random(in: -50...50)
        self.rotation = Double.random(in: -30...30)
    }
}

enum MessageType: Equatable {
    case added
    case already
    case removed
}

struct MessageState: Identifiable, Equatable {
    let id = UUID()
    var type: MessageType
    
    var text: String {
        switch type {
        case .added: return "Added to favorites"
        case .already: return "Already in favorites"
        case .removed: return "Removed from favorites"
        }
    }
}

struct HeartOverlay: View {
    let state: HeartState
    let onDone: () -> Void

    @State private var heartY: CGFloat = 0
    @State private var heartSwayX: CGFloat = 0
    @State private var heartScale: CGFloat = 0.01
    @State private var heartOpacity: Double = 0
    @State private var shimmerStep: Int = -10

    var body: some View {
        PixelHeart(color: .red, shimmerOffset: shimmerStep)
            .frame(width: 40, height: 40)
            .scaleEffect(heartScale)
            .rotationEffect(.degrees(state.rotation))
            .opacity(heartOpacity)
            .offset(x: heartSwayX, y: heartY)
            .position(x: state.tapPoint.x, y: state.tapPoint.y)
            .allowsHitTesting(false)
            .onAppear {
                let duration: Double = 10.0
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                    heartScale = 1.0
                    heartOpacity = 1.0
                }
                
                withAnimation(.easeOut(duration: duration)) {
                    heartY = -UIScreen.main.bounds.height - 100
                }
                
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    heartSwayX = state.swayOffset
                }
                
                // Pixelated shimmer step animation
                withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                    shimmerStep = 30
                }
                
                withAnimation(.easeIn(duration: 1.5).delay(duration - 1.5)) {
                    heartOpacity = 0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) { onDone() }
            }
    }
}

struct MessageOverlay: View {
    @Binding var state: MessageState?
    let onRemove: () -> Void
    
    @State private var showButton = false
    
    var body: some View {
        ZStack(alignment: .top) {
            if let active = state {
                VStack(spacing: 8) {
                    // Stable Text Area
                    Text(active.text)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .frame(height: 24)
                        .id(active.type)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                    
                    // Interaction Area
                    ZStack {
                        if active.type == .already && showButton {
                            Button {
                                onRemove()
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    state?.type = .removed
                                }
                                // Auto-dismiss removed message after short delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    if state?.type == .removed {
                                        withAnimation { state = nil }
                                    }
                                }
                            } label: {
                                Text("REMOVE")
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 20)
                                    .background(Color(.systemGray5))
                                    .clipShape(Capsule())
                            }
                            .transition(.asymmetric(
                                insertion: .springScale.combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                    }
                    .frame(height: 40)
                }
                .padding(.top, 130)
                .frame(maxWidth: .infinity)
                .onAppear {
                    // Delay the button appearance slightly to decouple it from text
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15)) {
                        showButton = true
                    }
                }
                .onDisappear {
                    showButton = false
                }
                .onChange(of: active.type) { _, newValue in
                    if newValue != .already {
                        showButton = false
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(state?.type == .already) 
    }
}

extension AnyTransition {
    static var springScale: AnyTransition {
        .scale(scale: 0.7).combined(with: .move(edge: .bottom))
    }
}

