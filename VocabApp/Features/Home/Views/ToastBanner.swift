import SwiftUI

struct ToastBanner: View {
    let message: String
    let actionLabel: String
    let action: () -> Void
    var secondaryActionLabel: String? = nil
    var secondaryActionIcon: String? = nil
    var secondaryAction: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 10) {
            Text(message)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            
            Spacer(minLength: 4)
            
            HStack(spacing: 8) {
                if let secondaryAction = secondaryAction, let secondaryLabel = secondaryActionLabel {
                    ToastButton(
                        label: secondaryLabel,
                        icon: secondaryActionIcon,
                        action: secondaryAction
                    )
                }
                
                ToastButton(
                    label: actionLabel,
                    icon: "chevron.right",
                    isTrailingIcon: true,
                    action: action
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.Colors.amieOrange)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Theme.Colors.amieOrange.opacity(0.3), radius: 15, x: 0, y: 8)
        .padding(.horizontal, 20)
    }
}

private struct ToastButton: View {
    let label: String
    var icon: String? = nil
    var isTrailingIcon: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if !isTrailingIcon, let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                }
                
                Text(label)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
                
                if isTrailingIcon, let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .foregroundColor(.white)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .frame(minWidth: 70) // Standardized width for both buttons
            .background(Color.white.opacity(0.2))
            .clipShape(Capsule())
        }
    }
}
