import SwiftUI

struct CollectionCard: View {
    let collection: CollectionEntity
    var isSelected: Bool = false
    var isEditing: Bool = false
    var action: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onRename: (() -> Void)? = nil

    var body: some View {
        if action != nil || (isEditing && !collection.isSystem) {
            Button(action: {
                if isEditing {
                    onRename?()
                } else {
                    action?()
                }
            }) {
                cardContent
            }
            .buttonStyle(.plain)
        } else {
            cardContent
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                let isBookmarked = collection.name == "Bookmarked"
                let color = isBookmarked ? Theme.Colors.amieOrange : (collection.isSystem ? Theme.Colors.amieBlue : Color(hex: collection.colorHex))
                let icon = isBookmarked ? "bookmark.fill" : (collection.name == "Favorites" ? "heart.fill" : "folder.fill")

                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                    .padding(.horizontal, isEditing && !collection.isSystem ? 8 : 0)
                    .padding(.vertical, isEditing && !collection.isSystem ? 6 : 0)
                    .background {
                        if isEditing && !collection.isSystem {
                            Theme.Colors.iconBackground
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                Text("\(collection.wordIds.count) words")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            if action != nil && !isEditing {
                Spacer(minLength: 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .frame(minHeight: action != nil ? 130 : 0)
        .amieCard()
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius)
                    .stroke(Theme.Colors.selection, lineWidth: 2)
            }
        }
        .opacity(isEditing && collection.isSystem ? 0.4 : 1.0)
        .overlay(alignment: .topLeading) {
            if isEditing && !collection.isSystem {
                Button(action: { onDelete?() }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.red)
                        .background(Circle().fill(.white))
                }
                .offset(x: -8, y: -8)
            }
        }
        .contentShape(Rectangle())
    }
}
