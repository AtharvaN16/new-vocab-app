import Foundation

@Observable
final class ReviewDashboardViewModel {
    var dueCount: Int = 0
    var newCount: Int = 0
    var learningCount: Int = 0
    var reviewCount: Int = 0
    var isLoading: Bool = true

    private let srsRepository: SRSRepository

    init(srsRepository: SRSRepository) {
        self.srsRepository = srsRepository
        Task { await loadStats() }
    }

    @MainActor
    func loadStats() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let due = try await srsRepository.fetchDueCards(asOf: Date())
            dueCount = due.count
            newCount = due.filter { $0.state == .new }.count
            learningCount = due.filter { $0.state == .learning || $0.state == .relearning }.count
            reviewCount = due.filter { $0.state == .review }.count
        } catch {
            print("ReviewDashboard load error: \(error)")
        }
    }
}
