import SwiftUI

struct AddToCollectionSheet: View {
    @State var viewModel: AddToCollectionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                
                List {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        ForEach(viewModel.collections) { collection in
                            Button(action: {
                                Task {
                                    await viewModel.toggleCollection(collection)
                                }
                            }) {
                                HStack {
                                    Circle()
                                        .fill(Color(hex: collection.colorHex))
                                        .frame(width: 12, height: 12)
                                    
                                    Text(collection.name)
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                    
                                    Spacer()
                                    
                                    if viewModel.isWordInCollection(collection) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Theme.Colors.amieBlue)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .listRowBackground(Theme.Colors.surface)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add to Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
