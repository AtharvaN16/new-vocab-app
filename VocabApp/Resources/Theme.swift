import SwiftUI

enum Theme {
    // MARK: - Colors (Amie-inspired: Tinted Neutrals & Sticker Accents)
    enum Colors {
        static let background = Color(red: 0.976, green: 0.976, blue: 0.973) // #F9F9F8
        static let surface = Color.white
        static let border = Color.black.opacity(0.06)
        
        // Sticker colors
        static let amiePink = Color(red: 1.0, green: 0.44, blue: 0.64)
        static let amieYellow = Color(red: 1.0, green: 0.93, blue: 0.47)
        static let amieBlue = Color(red: 0.36, green: 0.65, blue: 1.0)
        static let amieGreen = Color(red: 0.42, green: 0.83, blue: 0.58)
        
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
    
    // MARK: - Animations (Amie is very "bouncy")
    enum Animation {
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0)
        static let snappy = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)
    }
}

// MARK: - Amie-style View Modifiers
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
