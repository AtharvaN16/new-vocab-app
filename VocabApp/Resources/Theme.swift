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

struct HeartState {
    let tapPoint: CGPoint
    let alreadyAdded: Bool
    init(tapPoint: CGPoint, alreadyAdded: Bool) {
        self.tapPoint = tapPoint
        self.alreadyAdded = alreadyAdded
    }
}

struct HeartOverlay: View {
    let state: HeartState
    let onDone: () -> Void

    init(state: HeartState, onDone: @escaping () -> Void) {
        self.state = state
        self.onDone = onDone
    }

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
            let targetY = -(state.tapPoint.y - 120)
            withAnimation(.linear(duration: 1.2)) { heartY = targetY } completion: {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.15)) {
                    heartScale = 1.3; msgScale = 1.2
                }
                withAnimation(.easeOut(duration: 0.3)) {
                    heartOpacity = 0; msgOpacity = 0
                } completion: { onDone() }
            }
            withAnimation(.linear(duration: 0.4)) { heartSwayX = 20  } completion: {
                withAnimation(.linear(duration: 0.4)) { heartSwayX = -20 } completion: {
                    withAnimation(.linear(duration: 0.4)) { heartSwayX = 0 }
                }
            }
        }
    }
}
