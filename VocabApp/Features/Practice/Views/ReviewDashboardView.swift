import SwiftUI

struct ReviewDashboardView: View {
    @State var viewModel: ReviewDashboardViewModel
    @Environment(\.appEnvironment) private var appEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var showSession = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                        .tint(Theme.Colors.amieBlue)
                } else if viewModel.dueCount == 0 {
                    allCaughtUpView
                } else {
                    reviewContentView
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                }
            }
            .fullScreenCover(isPresented: $showSession) {
                if let env = appEnvironment {
                    PracticeSessionView(viewModel: PracticeSessionViewModel(
                        wordRepository: env.wordRepository,
                        srsRepository: env.srsRepository
                    ))
                }
            }
            .onChange(of: showSession) { _, isShowing in
                if !isShowing {
                    Task { await viewModel.loadStats() }
                }
            }
        }
    }

    private var reviewContentView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                Text("\(viewModel.dueCount)")
                    .font(.system(size: 72, weight: .black, design: .monospaced))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("words to review")
                    .font(.system(size: 16, weight: .regular))
                    .tracking(-0.3)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            HStack(spacing: 32) {
                statPill(label: "NEW", count: viewModel.newCount, color: Theme.Colors.amieBlue)
                statPill(label: "LEARNING", count: viewModel.learningCount, color: Theme.Colors.amiePink)
                statPill(label: "REVIEW", count: viewModel.reviewCount, color: Theme.Colors.amieGreen)
            }
            .padding(.top, 40)

            Spacer()

            Button {
                showSession = true
            } label: {
                Text("START REVIEW")
                    .font(.system(size: 14, weight: .black))
                    .tracking(1)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Theme.Colors.textPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(AmieButtonStyle())
            .padding(24)
        }
    }

    private var allCaughtUpView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(Theme.Colors.amieGreen)
            Text("All caught up!")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(Theme.Colors.textPrimary)
            Text("No words due for review today.")
                .font(.system(size: 16))
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }

    private func statPill(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }
}
