import SwiftUI

struct WordDetailView: View {
    @State var viewModel: WordDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var heartState: HeartState? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                WordCardView(
                    word: viewModel.word,
                    isExpanded: $viewModel.isExpanded,
                    onSwipeNext: {
                        Task { await viewModel.navigateNext() }
                    },
                    onSwipePrevious: {
                        Task { await viewModel.navigatePrevious() }
                    },
                    onDoubleTap: { point in
                        handleDoubleTap(at: point)
                    },
                    showToggle: false,
                    isFullHeight: true
                )

                if let state = heartState {
                    HeartOverlay(state: state) { heartState = nil }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }
            }
        }
    }
    
    private func handleDoubleTap(at point: CGPoint) {
        let alreadyFav = viewModel.isFavorited
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        heartState = HeartState(tapPoint: point, alreadyAdded: alreadyFav)
        if !alreadyFav {
            Task { await viewModel.toggleFavorite() }
        }
    }
}
