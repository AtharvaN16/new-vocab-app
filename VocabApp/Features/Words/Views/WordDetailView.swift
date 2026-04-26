import SwiftUI

struct WordDetailView: View {
    @State var viewModel: WordDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var heartStates: [HeartState] = []
    @State private var messageState: MessageState? = nil

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
            }
            .overlay {
                ZStack {
                    ForEach(heartStates) { state in
                        HeartOverlay(state: state) {
                            heartStates.removeAll(where: { $0.id == state.id })
                        }
                    }
                    
                    MessageOverlay(
                        state: $messageState,
                        onRemove: { Task { await viewModel.toggleFavorite() } }
                    )
                }
                .ignoresSafeArea()
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
        
        // Always spawn a heart
        heartStates.append(HeartState(tapPoint: point))
        
        // Handle message state transitions
        if alreadyFav {
            if messageState?.type != .already && messageState?.type != .removed {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    messageState = MessageState(type: .already)
                }
            }
        } else {
            if messageState?.type != .added {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    messageState = MessageState(type: .added)
                }
                Task { await viewModel.toggleFavorite() }
                
                let id = messageState?.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if messageState?.id == id {
                        withAnimation { messageState = nil }
                    }
                }
            }
        }
    }
}
