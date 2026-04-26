import SwiftUI

struct AddToCollectionSheet: View {
    @State var viewModel: AddToCollectionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddAlert = false
    @State private var newCollectionName = ""

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var showDoneButton: Bool {
        // Show if any selected collection is NOT "Bookmarked"
        viewModel.collections.filter { viewModel.isSelected($0) }.contains { $0.name != "Bookmarked" }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if viewModel.isLoading && viewModel.collections.isEmpty {
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 200)
                            } else {
                                // System Collections
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(viewModel.systemCollections) { collection in
                                        CollectionCard(
                                            collection: collection,
                                            isSelected: viewModel.isSelected(collection),
                                            action: {
                                                viewModel.toggleSelection(collection)
                                            }
                                        )
                                    }
                                }
                                .padding(.top, 16)

                                // User Collections
                                if !viewModel.userCollections.isEmpty {
                                    VStack(alignment: .leading, spacing: 16) {
                                        Text("MY COLLECTIONS")
                                            .font(.system(size: 12, weight: .black))
                                            .tracking(1.5)
                                            .foregroundColor(Theme.Colors.textSecondary)

                                        LazyVGrid(columns: columns, spacing: 12) {
                                            ForEach(viewModel.userCollections) { collection in
                                                CollectionCard(
                                                    collection: collection,
                                                    isSelected: viewModel.isSelected(collection),
                                                    action: {
                                                        viewModel.toggleSelection(collection)
                                                    }
                                                )
                                            }
                                        }
                                    }
                                    .padding(.top, 8)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                    }

                    // Create New Collection Button
                    Button(action: { showingAddAlert = true }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Create new collection")
                        }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius)
                                .stroke(Theme.Colors.border, style: StrokeStyle(lineWidth: 2, dash: [6]))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                    .padding(.top, 16)
                    .background(Theme.Colors.background)
                }

                // Toast Message
                if viewModel.showMessage {
                    VStack {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text(viewModel.message)
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.Colors.amieOrange)
                        .clipShape(Capsule())
                        .shadow(color: Theme.Colors.amieOrange.opacity(0.3), radius: 10, x: 0, y: 5)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                    .padding(.top, 12)
                    .zIndex(10)
                }
            }
            .navigationTitle("Add to Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if showDoneButton {
                        Button("Done") {
                            Task {
                                try? await viewModel.saveSelections()
                                dismiss()
                            }
                        }
                        .fontWeight(.bold)
                        .foregroundColor(Theme.Colors.textPrimary)
                    }
                }
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
        .presentationDetents([.fraction(0.95)])
    }
}

// SelectableCollectionCard removed as it's now reusable CollectionCard
