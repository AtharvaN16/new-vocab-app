# SRS Review — Daily Review Queue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface a daily review queue so users can practise bookmarked words using the FSRS spaced-repetition algorithm already built into the codebase.

**Architecture:** Three missing pieces bridge the existing `FSRSEngine` + `PracticeSessionView` infrastructure to the user: (1) an `enrollWords` repository method that creates SRS cards for bookmarked words that don't have one yet; (2) a call to that method whenever a word is saved to the Bookmarked collection; (3) a `ReviewDashboardView` (presented as a `fullScreenCover` from `HomeView`) that shows today's due-card stats and launches `PracticeSessionView` for a global, wordId-unfiltered session.

**Tech Stack:** SwiftUI, SwiftData, `@Observable`, FSRS (existing `FSRSEngine`)

---

## File Manifest

| File | Action | Responsibility |
|---|---|---|
| `VocabApp/Domain/Repositories/SRSRepository.swift` | Modify | Add `enrollWords(_ wordIds: [UUID]) async throws` to protocol |
| `VocabApp/Data/Local/SwiftDataSRSRepository.swift` | Modify | Implement `enrollWords` — skip words that already have a card |
| `VocabAppTests/SRSEnrollmentTests.swift` | **Create** | Unit tests: creates cards, idempotent, new state, multi-word |
| `VocabApp/Features/Home/ViewModels/HomeViewModel.swift` | Modify | Accept `srsRepository: SRSRepository`; call `enrollWords` in `saveToDefaultCollection` |
| `VocabApp/ContentView.swift` | Modify | Pass `appEnvironment.srsRepository` when constructing `HomeViewModel` |
| `VocabApp/Features/Practice/ViewModels/ReviewDashboardViewModel.swift` | **Create** | Loads due-card count and new/learning/review breakdown |
| `VocabApp/Features/Practice/Views/ReviewDashboardView.swift` | **Create** | Stats display + "START REVIEW" → `PracticeSessionView`; "All caught up" empty state |
| `VocabApp/Features/Home/Views/HomeView.swift` | Modify | Add Review toolbar button (leading, alongside Library); present `ReviewDashboardView` as `fullScreenCover` |

---

## Context for Agentic Workers

**Existing infrastructure (do not re-implement):**

`FSRSEngine` (`VocabApp/Domain/SRS/FSRSEngine.swift`) — FSRS v5 algorithm. `createEmptyCard(now:)` returns an `SRSCardEntity` with `wordId: UUID()` placeholder; caller must supply the real `wordId` when constructing the entity manually.

`SRSCardEntity` (`VocabApp/Domain/Entities/SRSCardEntity.swift`) — all properties except `id` and `wordId` are `var`. `state` is `SRSCardEntity.SRSState` enum with cases `.new`, `.learning`, `.review`, `.relearning`.

`SRSCardSD` (`VocabApp/Data/Local/Models/SRSCardSD.swift`) — `@Model` class with `@Attribute(.unique) var id: UUID` and `var wordId: UUID`. Has `init(from: SRSCardEntity)` and `toDomain() -> SRSCardEntity`.

`SwiftDataSRSRepository` (`VocabApp/Data/Local/SwiftDataSRSRepository.swift`) — all methods are `@MainActor`. The pattern for checking existence before inserting:
```swift
let id = wordId  // capture for #Predicate
let descriptor = FetchDescriptor<SRSCardSD>(predicate: #Predicate { $0.wordId == id })
let existing = try modelContext.fetch(descriptor)
guard existing.isEmpty else { continue }
```

`PracticeSessionView` / `PracticeSessionViewModel` (`VocabApp/Features/Practice/`) — fully working. Initialise `PracticeSessionViewModel(wordRepository:, srsRepository:, wordIds: nil)` for a global unfiltered review session.

`HomeViewModel` (`VocabApp/Features/Home/ViewModels/HomeViewModel.swift`) — `saveToDefaultCollection()` is the bookmark action. Current init:
```swift
init(collectionRepository: CollectionRepository, dictionaryRepository: DictionaryRepository)
```

`ContentView.swift` — constructs `HomeViewModel` inside `homeTab(_:)`:
```swift
navState.homeViewModel = HomeViewModel(
    collectionRepository: appEnvironment.collectionRepository,
    dictionaryRepository: appEnvironment.dictionaryRepository
)
```

`HomeView` toolbar (non-expanded state): `.topBarLeading` → Library icon (grid); `.topBarTrailing` → Profile icon (person). Both set `appEnvironment?.selectedTab`.

`Theme.Colors` in use: `.textPrimary`, `.textSecondary`, `.background`, `.amieBlue`, `.amiePink`, `.amieGreen`.

`AmieButtonStyle` is an existing `ButtonStyle` used on pill buttons in `PracticeSessionView`.

Simulator UDID: `B4403B3A-10A8-43A3-9B61-FD2439ADFEA5`

After creating new Swift files run: `xcodegen generate` from the project root.

---

## Task 1 — enrollWords: SRSRepository + SwiftDataSRSRepository

**Files:**
- Modify: `VocabApp/Domain/Repositories/SRSRepository.swift`
- Modify: `VocabApp/Data/Local/SwiftDataSRSRepository.swift`
- Create: `VocabAppTests/SRSEnrollmentTests.swift`

- [ ] **Step 1.1: Write failing tests**

Create `VocabAppTests/SRSEnrollmentTests.swift`:

```swift
import XCTest
import SwiftData
@testable import VocabApp

@MainActor
final class SRSEnrollmentTests: XCTestCase {
    var container: ModelContainer!
    var repository: SwiftDataSRSRepository!

    override func setUp() async throws {
        container = try ModelContainer(
            for: SRSCardSD.self, ReviewLogSD.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        repository = SwiftDataSRSRepository(modelContext: container.mainContext)
    }

    override func tearDown() async throws {
        container = nil
        repository = nil
    }

    func test_enrollWords_createsCard() async throws {
        let wordId = UUID()
        try await repository.enrollWords([wordId])
        let card = try await repository.fetchCard(for: wordId)
        XCTAssertNotNil(card)
    }

    func test_enrollWords_newCard_isInNewState() async throws {
        let wordId = UUID()
        try await repository.enrollWords([wordId])
        let card = try await repository.fetchCard(for: wordId)
        XCTAssertEqual(card?.state, .new)
    }

    func test_enrollWords_newCard_isDueNow() async throws {
        let before = Date()
        let wordId = UUID()
        try await repository.enrollWords([wordId])
        let card = try await repository.fetchCard(for: wordId)
        XCTAssertNotNil(card)
        XCTAssertLessThanOrEqual(card!.due, before.addingTimeInterval(5))
    }

    func test_enrollWords_idempotent() async throws {
        let wordId = UUID()
        try await repository.enrollWords([wordId])
        try await repository.enrollWords([wordId])
        let cards = try await repository.fetchDueCards(asOf: Date.distantFuture)
        XCTAssertEqual(cards.filter { $0.wordId == wordId }.count, 1)
    }

    func test_enrollWords_multipleWords_allCreated() async throws {
        let ids = [UUID(), UUID(), UUID()]
        try await repository.enrollWords(ids)
        for id in ids {
            let card = try await repository.fetchCard(for: id)
            XCTAssertNotNil(card)
        }
    }
}
```

- [ ] **Step 1.2: Run xcodegen + verify compile error**

```bash
xcodegen generate 2>&1 | tail -2
xcodebuild test -scheme VocabApp -destination 'id=B4403B3A-10A8-43A3-9B61-FD2439ADFEA5' \
  -only-testing:VocabAppTests/SRSEnrollmentTests 2>&1 | grep -E '(error:|PASSED|FAILED)' | head -5
```

Expected: `error: value of type 'SwiftDataSRSRepository' has no member 'enrollWords'`

- [ ] **Step 1.3: Add enrollWords to SRSRepository protocol**

In `VocabApp/Domain/Repositories/SRSRepository.swift`, add after `func fetchReviewCount(since date: Date) async throws -> Int`:

```swift
func enrollWords(_ wordIds: [UUID]) async throws
```

- [ ] **Step 1.4: Implement enrollWords in SwiftDataSRSRepository**

In `VocabApp/Data/Local/SwiftDataSRSRepository.swift`, add after `fetchReviewCount`:

```swift
@MainActor
func enrollWords(_ wordIds: [UUID]) async throws {
    for wordId in wordIds {
        let id = wordId
        let descriptor = FetchDescriptor<SRSCardSD>(predicate: #Predicate { $0.wordId == id })
        let existing = try modelContext.fetch(descriptor)
        guard existing.isEmpty else { continue }
        let card = SRSCardEntity(
            id: UUID(),
            wordId: wordId,
            due: Date(),
            stability: 0,
            difficulty: 0,
            elapsedDays: 0,
            scheduledDays: 0,
            reps: 0,
            lapses: 0,
            state: .new,
            lastReview: nil,
            updatedAt: Date()
        )
        modelContext.insert(SRSCardSD(from: card))
    }
    try modelContext.save()
}
```

- [ ] **Step 1.5: Run tests — expect all 5 PASSED**

```bash
xcodebuild test -scheme VocabApp -destination 'id=B4403B3A-10A8-43A3-9B61-FD2439ADFEA5' \
  -only-testing:VocabAppTests/SRSEnrollmentTests 2>&1 | grep -E '(Test Case|PASSED|FAILED)'
```

Expected: 5 tests PASSED.

- [ ] **Step 1.6: Commit**

```bash
git add VocabApp/Domain/Repositories/SRSRepository.swift \
        VocabApp/Data/Local/SwiftDataSRSRepository.swift \
        VocabAppTests/SRSEnrollmentTests.swift
git commit -m "feat: add enrollWords to SRSRepository — creates new-state cards for unseen words"
```

---

## Task 2 — Auto-enroll on bookmark

**Files:**
- Modify: `VocabApp/Features/Home/ViewModels/HomeViewModel.swift`
- Modify: `VocabApp/ContentView.swift`

- [ ] **Step 2.1: Inject srsRepository into HomeViewModel**

In `VocabApp/Features/Home/ViewModels/HomeViewModel.swift`, change the `let` declarations block (after `private let dailyWordsUseCase`) by adding:

```swift
private let srsRepository: SRSRepository
```

Then update the `init` signature and body:

```swift
init(collectionRepository: CollectionRepository, dictionaryRepository: DictionaryRepository, srsRepository: SRSRepository) {
    self.collectionRepository = collectionRepository
    self.dictionaryRepository = dictionaryRepository
    self.srsRepository = srsRepository
    Task { await loadData() }
}
```

- [ ] **Step 2.2: Call enrollWords in saveToDefaultCollection**

In `HomeViewModel.saveToDefaultCollection()`, after the line:
```swift
try await collectionRepository.addWordToCollection(wordId: word.id, collectionId: collection.id)
```

Add:
```swift
try? await srsRepository.enrollWords([word.id])
```

The full `do` block inside `saveToDefaultCollection` should read:
```swift
do {
    if !collection.wordIds.contains(word.id) {
        try await collectionRepository.addWordToCollection(wordId: word.id, collectionId: collection.id)
        try? await srsRepository.enrollWords([word.id])
        collections = try await collectionRepository.fetchCollections()
    }

    toastMessage = "Saved to Bookmark"
    withAnimation(.spring()) {
        showToast = true
    }

    try? await Task.sleep(nanoseconds: 3_000_000_000)
    withAnimation(.spring()) {
        if toastMessage == "Saved to Bookmark" {
            showToast = false
        }
    }
} catch {
    print("Error saving to default collection: \(error)")
}
```

- [ ] **Step 2.3: Update ContentView to pass srsRepository**

In `VocabApp/ContentView.swift`, inside `homeTab(_:)`, find:
```swift
navState.homeViewModel = HomeViewModel(
    collectionRepository: appEnvironment.collectionRepository,
    dictionaryRepository: appEnvironment.dictionaryRepository
)
```

Replace with:
```swift
navState.homeViewModel = HomeViewModel(
    collectionRepository: appEnvironment.collectionRepository,
    dictionaryRepository: appEnvironment.dictionaryRepository,
    srsRepository: appEnvironment.srsRepository
)
```

- [ ] **Step 2.4: Build — no errors**

```bash
xcodebuild build -scheme VocabApp -destination 'id=B4403B3A-10A8-43A3-9B61-FD2439ADFEA5' 2>&1 | grep -E '(error:|BUILD)'
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 2.5: Commit**

```bash
git add VocabApp/Features/Home/ViewModels/HomeViewModel.swift \
        VocabApp/ContentView.swift
git commit -m "feat: auto-enroll word in SRS when bookmarked"
```

---

## Task 3 — ReviewDashboardViewModel

**Files:**
- Create: `VocabApp/Features/Practice/ViewModels/ReviewDashboardViewModel.swift`

- [ ] **Step 3.1: Create ReviewDashboardViewModel**

Create `VocabApp/Features/Practice/ViewModels/ReviewDashboardViewModel.swift`:

```swift
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
```

- [ ] **Step 3.2: Run xcodegen + build**

```bash
xcodegen generate 2>&1 | tail -2
xcodebuild build -scheme VocabApp -destination 'id=B4403B3A-10A8-43A3-9B61-FD2439ADFEA5' 2>&1 | grep -E '(error:|BUILD)'
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3.3: Commit**

```bash
git add VocabApp/Features/Practice/ViewModels/ReviewDashboardViewModel.swift \
        VocabApp.xcodeproj
git commit -m "feat: add ReviewDashboardViewModel — loads due card counts by state"
```

---

## Task 4 — ReviewDashboardView + HomeView entry point

**Files:**
- Create: `VocabApp/Features/Practice/Views/ReviewDashboardView.swift`
- Modify: `VocabApp/Features/Home/Views/HomeView.swift`

- [ ] **Step 4.1: Create ReviewDashboardView**

Create `VocabApp/Features/Practice/Views/ReviewDashboardView.swift`:

```swift
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
```

- [ ] **Step 4.2: Add Review entry point to HomeView**

In `VocabApp/Features/Home/Views/HomeView.swift`:

**4.2a** — Add `@State` property after the other `@State` declarations at the top of `HomeView`:

```swift
@State private var showReview = false
```

**4.2b** — In the toolbar block (inside `if !viewModel.isExpanded { ... }`), add a second leading `ToolbarItem` after the existing Library one:

```swift
ToolbarItem(placement: .topBarLeading) {
    Button {
        showReview = true
    } label: {
        Image(systemName: "brain")
            .fontWeight(.semibold)
            .foregroundStyle(Theme.Colors.textPrimary)
    }
    .transition(.opacity.combined(with: .move(edge: .top)))
}
```

**4.2c** — Add `.fullScreenCover` modifier after the existing `.sheet(isPresented: $viewModel.showAddToCollection)` block (before `.task`):

```swift
.fullScreenCover(isPresented: $showReview) {
    if let env = appEnvironment {
        ReviewDashboardView(viewModel: ReviewDashboardViewModel(srsRepository: env.srsRepository))
    }
}
```

- [ ] **Step 4.3: Run xcodegen + build**

```bash
xcodegen generate 2>&1 | tail -2
xcodebuild build -scheme VocabApp -destination 'id=B4403B3A-10A8-43A3-9B61-FD2439ADFEA5' 2>&1 | grep -E '(error:|BUILD)'
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4.4: Run full test suite**

```bash
xcodebuild test -scheme VocabApp -destination 'id=B4403B3A-10A8-43A3-9B61-FD2439ADFEA5' 2>&1 | grep -E '(Test Case.*passed|FAILED|BUILD)'
```

Expected: All existing tests pass, `BUILD SUCCEEDED`.

- [ ] **Step 4.5: Commit**

```bash
git add VocabApp/Features/Practice/Views/ReviewDashboardView.swift \
        VocabApp/Features/Home/Views/HomeView.swift \
        VocabApp.xcodeproj
git commit -m "feat: add ReviewDashboardView with due-word stats and review entry point in HomeView toolbar"
```

---

## Self-Review

**Spec coverage:**
| Feature | Task |
|---|---|
| enrollWords creates a card for each new wordId | Task 1 |
| enrollWords is idempotent (no duplicate cards) | Task 1 |
| Word auto-enrolled when bookmarked | Task 2 |
| ReviewDashboard loads due count + state breakdown | Task 3 |
| ReviewDashboard shows "All caught up" when nothing due | Task 4 |
| ReviewDashboard launches global PracticeSessionView | Task 4 |
| Stats refresh after a session completes | Task 4 (Step 4.1, `.onChange(of: showSession)`) |
| Review entry point accessible from HomeView | Task 4 |

**Type consistency check:**
- `SRSRepository.enrollWords(_ wordIds: [UUID])` defined in Task 1 and called in Task 2 ✓
- `ReviewDashboardViewModel(srsRepository:)` defined in Task 3 and initialised in Tasks 4.1 + 4.2c ✓
- `PracticeSessionViewModel(wordRepository:, srsRepository:, wordIds: nil)` matches existing constructor signature ✓
- `appEnvironment.srsRepository` exists — `AppEnvironment` already exposes `let srsRepository: SRSRepository` ✓
- `AppEnvironment.wordRepository` used in Task 4.1 — `AppEnvironment` already exposes `let wordRepository: WordRepository` ✓
