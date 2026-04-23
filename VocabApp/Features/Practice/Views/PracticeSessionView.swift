import SwiftUI

struct PracticeSessionView: View {
    @State var viewModel: PracticeSessionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isFlipped = false

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                    .padding(.bottom, 20)
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(Theme.Colors.amieBlue)
                    Spacer()
                } else if viewModel.isFinished {
                    completionView
                } else if let item = viewModel.currentItem {
                    Spacer()
                    
                    // Flashcard (Amie-style: Clean, refined depth)
                    PracticeCardView(word: item.word, isFlipped: $isFlipped)
                        .padding(24)
                        .frame(maxHeight: 450)
                    
                    Spacer()
                    
                    // Controls
                    if isFlipped {
                        ratingButtons
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(Theme.Animation.spring) {
                                isFlipped = true
                            }
                        }) {
                            Text("TAP TO REVEAL")
                                .font(.system(size: 14, weight: .black))
                                .tracking(1)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(Theme.Colors.amieBlue)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(AmieButtonStyle())
                        .padding(24)
                    }
                }
            }
        }
    }
    
    private var header: some View {
        HStack(spacing: 16) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(8)
                    .background(Theme.Colors.surface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.Colors.border, lineWidth: 1))
            }
            
            ProgressView(value: viewModel.progress)
                .tint(Theme.Colors.amieBlue)
            
            Text("\(viewModel.currentIndex + 1)/\(viewModel.items.count)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .padding()
    }
    
    private var ratingButtons: some View {
        HStack(spacing: 10) {
            RatingButton(label: "AGAIN", color: Theme.Colors.amiePink) {
                submitRating(.again)
            }
            RatingButton(label: "GOOD", color: Theme.Colors.amieBlue) {
                submitRating(.good)
            }
            RatingButton(label: "EASY", color: Theme.Colors.amieGreen) {
                submitRating(.easy)
            }
        }
        .padding(20)
    }
    
    private func submitRating(_ rating: FSRSEngine.Rating) {
        Task {
            isFlipped = false
            try? await Task.sleep(nanoseconds: 300_000_000)
            await viewModel.rateCurrentCard(rating)
        }
    }
    
    private var completionView: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.Colors.amieGreen.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .black))
                    .foregroundColor(Theme.Colors.amieGreen)
            }
            
            VStack(spacing: 12) {
                Text("Session Complete")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("You've reviewed \(viewModel.items.count) words today. Keep it up!")
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(.horizontal, 20)
            }
            
            Button(action: { dismiss() }) {
                Text("DONE")
                    .font(.system(size: 14, weight: .black))
                    .tracking(1)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Theme.Colors.textPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(AmieButtonStyle())
            .padding(.top, 20)
            Spacer()
        }
        .padding(40)
    }
}

struct PracticeCardView: View {
    let word: WordEntity
    @Binding var isFlipped: Bool
    
    var body: some View {
        ZStack {
            // Front
            VStack(spacing: 16) {
                Text(word.word.capitalized)
                    .font(.system(size: 44, weight: .bold, design: .serif))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                if let phonetic = word.phonetic {
                    Text(phonetic)
                        .font(.system(.title3, design: .rounded))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .amieCard()
            .opacity(isFlipped ? 0 : 1)
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            
            // Back
            VStack(alignment: .leading, spacing: 20) {
                if let firstDef = word.definitions.first {
                    Text(firstDef.partOfSpeech.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .tracking(1.5)
                        .foregroundColor(Theme.Colors.amieBlue)
                    
                    Text(firstDef.text)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                if let example = word.examples.first {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EXAMPLE")
                            .font(.system(size: 10, weight: .black))
                            .tracking(1.5)
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        Text("\"\(example.text)\"")
                            .font(.system(size: 16, design: .serif))
                            .italic()
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .padding(.top, 10)
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .amieCard()
            .opacity(isFlipped ? 1 : 0)
            .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
    }
}

struct RatingButton: View {
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            VStack {
                Text(label)
                    .font(.system(size: 12, weight: .black))
                    .tracking(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(color)
            .foregroundColor(.white)
            .clipShape(Capsule())
        }
        .buttonStyle(AmieButtonStyle())
    }
}
