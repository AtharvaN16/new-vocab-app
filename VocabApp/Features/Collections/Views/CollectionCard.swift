import SwiftUI

struct CollectionCard: View {
    let collection: CollectionEntity
    var isSelected: Bool = false
    var isEditing: Bool = false
    var action: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onRename: (() -> Void)? = nil

    var body: some View {
        if action != nil && !isEditing {
            Button(action: {
                action?()
            }) {
                cardContent
            }
            .buttonStyle(.plain)
        } else {
            cardContent
        }
    }

    private var cardContent: some View {
        Group {
            if collection.isSystem {
                VStack(alignment: .leading, spacing: 12) {
                    ZStack {
                        let isBookmarked = collection.name == "Bookmarked"
                        let isFavorites = collection.name == "Favorites"
                        let color = isFavorites ? Color.red : (isBookmarked ? Theme.Colors.amieOrange : Theme.Colors.amieBlue)
                        let icon = isBookmarked ? "bookmark.fill" : (isFavorites ? "heart.fill" : "folder.fill")

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

                        Text("\(collection.wordIds.count) words")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 140) // Fixed height for system cards
            } else {
                HStack(spacing: 0) {
                    if isEditing {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.trailing, 16)
                    }

                    // Rename Touch Target
                    let renameContent = VStack(alignment: .leading, spacing: 0) {
                        Text(collection.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                            .padding(.horizontal, isEditing ? 10 : 0)
                            .padding(.vertical, isEditing ? 6 : 0)
                            .background {
                                if isEditing {
                                    Theme.Colors.iconBackground
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .contentShape(Rectangle())

                    if isEditing {
                        Button(action: { onRename?() }) {
                            renameContent
                        }
                        .buttonStyle(.plain)
                    } else {
                        renameContent
                    }

                    if isEditing {
                        Button(action: { onDelete?() }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.red)
                                .background(Circle().fill(.white))
                                .padding(.leading, 16)
                                .padding(.vertical, 16)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        // Word count circle on the right
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.iconBackground)
                                .frame(width: 32, height: 32)
                            
                            Text("\(collection.wordIds.count)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 72)
            }
        }
        .amieCard()
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius)
                    .stroke(Theme.Colors.selection, lineWidth: 2)
            }
        }
        .opacity(isEditing && collection.isSystem ? 0.4 : 1.0)
        .contentShape(Rectangle())
    }
}
