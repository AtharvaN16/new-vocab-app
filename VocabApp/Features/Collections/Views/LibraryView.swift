import SwiftUI

struct LibraryView: View {
    @State var viewModel: LibraryViewModel
    @Environment(\.appEnvironment) private var appEnvironment
    @State private var showingAddAlert = false
    @State private var newCollectionName = ""

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // System Collections
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(viewModel.systemCollections) { collection in
                                NavigationLink(value: collection) {
                                    CollectionCard(collection: collection)
                                }
                            }
                        }
                        .padding(.horizontal)

                        // User Collections
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("MY COLLECTIONS")
                                    .font(.system(size: 12, weight: .black))
                                    .tracking(1.5)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                Spacer()
                                Button(action: { showingAddAlert = true }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Theme.Colors.amieBlue)
                                        .padding(8)
                                        .background(Theme.Colors.surface)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Theme.Colors.border, lineWidth: 1))
                                }
                            }
                            .padding(.horizontal)

                            if viewModel.userCollections.isEmpty {
                                Text("No custom collections yet.")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .padding(.vertical, 40)
                                    .frame(maxWidth: .infinity)
                                    .amieCard()
                                    .padding(.horizontal)
                            } else {
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(viewModel.userCollections) { collection in
                                        NavigationLink(value: collection) {
                                            CollectionCard(collection: collection)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Library")
            .navigationDestination(for: CollectionEntity.self) { collection in
                if let appEnv = appEnvironment {
                    CollectionDetailView(viewModel: CollectionDetailViewModel(
                        collection: collection,
                        wordRepository: appEnv.wordRepository,
                        collectionRepository: appEnv.collectionRepository,
                        srsRepository: appEnv.srsRepository
                    ))
                }
            }
            .refreshable {
                await viewModel.loadCollections()
            }
            .alert("New Collection", isPresented: $showingAddAlert) {
                TextField("Collection Name", text: $newCollectionName)
                Button("Cancel", role: .cancel) { newCollectionName = "" }
                Button("Create") {
                    Task {
                        await viewModel.createCollection(name: newCollectionName)
                        newCollectionName = ""
                    }
                }
            } message: {
                Text("Enter a name for your new word collection.")
            }
        }
    }
}

struct CollectionCard: View {
    let collection: CollectionEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(collection.isSystem ? Theme.Colors.amieBlue.opacity(0.1) : Color(hex: collection.colorHex).opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: collection.isSystem ? "star.fill" : "folder.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(collection.isSystem ? Theme.Colors.amieBlue : Color(hex: collection.colorHex))
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .amieCard()
    }
}

// Helper for Hex Colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
