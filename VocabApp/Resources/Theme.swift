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
        static let amieOrange = Color(red: 1.0, green: 0.55, blue: 0.0) // Added amieOrange

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
// Three-pass rendering for the sticker effect:
//   Pass 0 — borderLabel: thin outer outline + shadow.
//   Pass 1 — whiteLabel: thick white stroke (the "sticker" boundary).
//   Pass 2 — fillLabel: the actual colored text.
// We use a custom subclass to force .round line joins, preventing sharp "spikes".
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
        // TabView / parent SwiftUI .tint() propagates to UIKit; override so sticker text stays black, not the accent.
        tintColor = .black
        for label in [borderLabel, whiteLabel, fillLabel] {
            label.tintColor = .black
            label.numberOfLines = 1
            label.textAlignment = .center
            label.clipsToBounds = false
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

        // Pass 0: Very thin light outer border + solid white fill + shadow
        borderLabel.attributedText = NSAttributedString(string: text, attributes: [
            .font: font,
            .strokeColor: UIColor.black.withAlphaComponent(0.12),
            .strokeWidth: -26.0,
            .foregroundColor: UIColor.white,
            .shadow: shadow
        ])

        // Pass 1: Thick white stroke
        whiteLabel.attributedText = NSAttributedString(string: text, attributes: [
            .font: font,
            .strokeColor: UIColor.white,
            .strokeWidth: 24.0
        ])

        // Pass 2: Colored fill
        fillLabel.attributedText = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: fillColor
        ])

        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Center the labels within our bounds, allowing them to bleed out if needed
        let insetBounds = bounds.insetBy(dx: -fontSizeCache * 0.2, dy: -fontSizeCache * 0.2)
        borderLabel.frame = bounds
        whiteLabel.frame  = bounds
        fillLabel.frame   = bounds
    }

    override var intrinsicContentSize: CGSize {
        let baseSize = fillLabel.intrinsicContentSize
        // Substantially more padding to account for thick strokes (13% bleed each side) + shadow
        let horizontalPadding = fontSizeCache * 0.4 // 20% bleed each side
        let verticalPadding   = fontSizeCache * 0.4
        return CGSize(
            width: baseSize.width + horizontalPadding,
            height: baseSize.height + verticalPadding + 10 // Extra for shadow
        )
    }

    // SF Rounded Black is guaranteed on every iOS device and gives the sticker look.
    // DynaPuff is tried first as an optional upgrade if it loaded correctly.
    private static func stickerFont(size: CGFloat) -> UIFont {
        if let f = UIFont(name: "DynaPuff-Medium", size: size) { return f }
        if let f = UIFont(name: "DynaPuff",        size: size) { return f }
        // SF Rounded Black — same playful rounded style, always available.
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

    func makeUIView(context: Context) -> StickerTextLayer {
        StickerTextLayer()
    }

    func updateUIView(_ uiView: StickerTextLayer, context: Context) {
        // Use UIKit black directly — `UIColor(SwiftUI.Color)` + parent `.tint()` can still yield accent-colored text.
        uiView.configure(text: text, fontSize: size, fillColor: .black)
    }

    // SwiftUI layout: report intrinsic size so VStack/HStack sizes itself correctly.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: StickerTextLayer, context: Context) -> CGSize? {
        uiView.intrinsicContentSize
    }
}

// MARK: - Amie-style card modifier
struct AmieCard: ViewModifier {
    var backgroundColor: Color = Theme.Colors.surface

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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(Theme.Animation.snappy, value: configuration.isPressed)
    }
}

// MARK: - Unified UI Components

struct IconButton: View {
    let icon: String
    let action: () -> Void
    var size: CGFloat = 52
    var iconSize: CGFloat = 24
    
    @State private var isVisible = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.iconBackground)
                    .frame(width: size, height: size)
                
                Circle()
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
                    .frame(width: size, height: size)
                
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
            }
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
