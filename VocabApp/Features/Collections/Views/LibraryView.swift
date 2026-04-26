import SwiftUI

struct LibraryView: View {
    @State var viewModel: LibraryViewModel
    @Environment(\.appEnvironment) private var appEnvironment
    @State private var showingAddAlert = false
    @State private var newCollectionName = ""
    @State private var collectionToRename: CollectionEntity?
    @State private var renameText = ""

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
                                    CollectionCard(
                                        collection: collection,
                                        isEditing: viewModel.isEditing
                                    )
                                }
                                .disabled(viewModel.isEditing)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)

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
                                .opacity(viewModel.isEditing ? 0 : 1)
                                .disabled(viewModel.isEditing)
                            }
                            .frame(height: 32) // Fixed height to prevent vertical jump
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
                                VStack(spacing: 12) {
                                    ForEach(viewModel.userCollections) { collection in
                                        if viewModel.isEditing {
                                            CollectionCard(
                                                collection: collection,
                                                isEditing: true,
                                                onDelete: {
                                                    viewModel.collectionToDelete = collection
                                                },
                                                onRename: {
                                                    renameText = collection.name
                                                    collectionToRename = collection
                                                }
                                            )
                                            .scaleEffect(viewModel.draggedID == collection.id ? 1.02 : 1.0)
                                            .shadow(color: .black.opacity(viewModel.draggedID == collection.id ? 0.1 : 0), radius: 10, y: 5)
                                            .offset(y: viewModel.draggedID == collection.id ? viewModel.dragOffset : 0)
                                            .zIndex(viewModel.draggedID == collection.id ? 10 : 0)
                                            .gesture(
                                                DragGesture(minimumDistance: 0)
                                                    .onChanged { value in
                                                        if viewModel.draggedID == nil {
                                                            viewModel.draggedID = collection.id
                                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                        }
                                                        
                                                        let cardHeight: CGFloat = 72 + 12
                                                        let translation = value.translation.height
                                                        
                                                        // Determine the target slot relative to the START of the drag
                                                        // We don't adjust dragOffset during the drag anymore to keep it absolute
                                                        let moveCount = Int((translation / cardHeight).rounded())
                                                        
                                                        // Magnetic Snap: 
                                                        // The card snaps to the slot center, but has a slight "tug" (20%) from the finger
                                                        let targetSnapOffset = CGFloat(moveCount) * cardHeight
                                                        let residual = translation - targetSnapOffset
                                                        let magneticOffset = targetSnapOffset + (residual * 0.2)
                                                        
                                                        withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.8)) {
                                                            viewModel.dragOffset = magneticOffset
                                                        }
                                                        
                                                        // Perform the actual array move
                                                        if moveCount != 0 {
                                                            if let from = viewModel.userCollections.firstIndex(where: { $0.id == collection.id }) {
                                                                let currentPosInArray = from
                                                                // We need to know where it SHOULD be based on moveCount from its original position
                                                                // This custom logic handles the "snapping" array move
                                                                // For simplicity, we just use the existing move but without adjusting dragOffset
                                                                // because our new magneticOffset calculation handles absolute translation
                                                                let to = from + moveCount
                                                                if to >= 0 && to < viewModel.userCollections.count && to != from {
                                                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                                                        viewModel.moveUserCollection(from: IndexSet(integer: from), to: to > from ? to + 1 : to)
                                                                    }
                                                                    UISelectionFeedbackGenerator().selectionChanged()
                                                                }
                                                            }
                                                        }
                                                    }
                                                    .onEnded { _ in
                                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                            viewModel.dragOffset = 0
                                                            viewModel.draggedID = nil
                                                        }
                                                    }
                                            )
                                        } else {
                                            NavigationLink(value: collection) {
                                                CollectionCard(
                                                    collection: collection,
                                                    isEditing: false
                                                )
                                            }
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(Theme.Animation.spring) {
                            appEnvironment?.selectedTab = 0
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.isEditing ? "Done" : "Edit") {
                        withAnimation(Theme.Animation.spring) {
                            viewModel.isEditing.toggle()
                        }
                    }
                    .fontWeight(.bold)
                    .foregroundColor(Theme.Colors.textPrimary)
                }
            }
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
            .task {
                await viewModel.loadCollections()
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
            .alert("Rename Collection", isPresented: Binding(
                get: { collectionToRename != nil },
                set: { if !$0 { collectionToRename = nil } }
            )) {
                TextField("Collection Name", text: $renameText)
                Button("Cancel", role: .cancel) { renameText = "" }
                Button("Rename") {
                    if let collection = collectionToRename {
                        Task {
                            await viewModel.renameCollection(collection, to: renameText)
                            renameText = ""
                            collectionToRename = nil
                        }
                    }
                }
            } message: {
                Text("Enter a new name for this collection.")
            }
            .alert("Delete Collection", isPresented: Binding(
                get: { viewModel.collectionToDelete != nil },
                set: { if !$0 { viewModel.collectionToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let collection = viewModel.collectionToDelete {
                        Task { await viewModel.deleteCollection(collection) }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete '\(viewModel.collectionToDelete?.name ?? "")'? This cannot be undone.")
            }
        }
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
