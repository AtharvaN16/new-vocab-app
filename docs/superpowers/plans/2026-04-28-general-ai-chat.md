# General AI Chat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a free-form AI chat screen not tied to any specific word, where users can hunt for words, workshop sentences, explore niche vocabulary by topic/industry, and save discovered words directly to their library.

**Architecture:** `GeneralChatViewModel` owns messages and word-saving state; the AI is system-prompted to wrap vocabulary suggestions in `[[word]]` syntax, which the view parses and renders as saveable chips below each assistant bubble. Word-saving calls `dictionaryRepository.lookup` → `wordRepository.saveWord` → `collectionRepository.addWordToCollection` (to "Favorites"). Entry point is a `sparkles` toolbar button in `HomeView`.

**Tech Stack:** SwiftUI, `@Observable`, `async/await`, `AsyncThrowingStream<String,Error>` (existing `AIRepository`), regex (`Regex` Swift 5.7+), existing `DictionaryRepository` / `WordRepository` / `CollectionRepository` protocols.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `VocabApp/Features/GeneralChat/ViewModels/GeneralChatViewModel.swift` | **Create** | Modes, messages, streaming send, `[[word]]` extraction, per-word save |
| `VocabApp/Features/GeneralChat/Views/GeneralChatView.swift` | **Create** | Chat UI: mode picker, message bubbles, word chips, input bar |
| `VocabApp/Features/Home/Views/HomeView.swift` | **Modify** | Add `sparkles` toolbar button + sheet |
| `VocabApp.xcodeproj/project.pbxproj` | **Modify** | Register two new Swift files |

---

## Key Design Decisions (from research)

- **No inline tappable word spans.** SwiftUI `Text` + `AttributedString` doesn't support per-word tap handlers reliably. Instead: parse `[[word]]` after each AI message and render them as a horizontal chip row below the bubble. This is cleaner UX anyway (confirmed by 2025/26 iOS chat UI patterns).
- **AI instruction contract.** Every mode's system prompt ends with: *"When you mention specific vocabulary words the user should learn or save, always wrap them in double square brackets like [[serendipity]]. Do not bracket common words."* This gives us a reliable extraction target.
- **Streaming.** Same per-chunk `messages[idx].content += chunk` pattern as `WordChatView`. The word chip row is only shown after streaming completes (`isGenerating == false`).
- **Save flow.** Tap chip → spinner → `dictionaryRepository.lookup(word)` → `wordRepository.saveWord(entity)` → `collectionRepository.addWordToCollection(wordId:collectionId:)` using the "Favorites" collection. Mark chip as saved with a checkmark. If lookup fails, show red error state on the chip.

---

## Task 1: `GeneralChatViewModel`

**Files:**
- Create: `VocabApp/Features/GeneralChat/ViewModels/GeneralChatViewModel.swift`

### `GeneralChatMode` enum

```swift
enum GeneralChatMode: String, CaseIterable, Identifiable {
    case wordHunter
    case sentenceWorkshop
    case topicVocab
    case writingCoach
    case wordBrainstorm

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wordHunter:       return "Word Hunter"
        case .sentenceWorkshop: return "Sentence Workshop"
        case .topicVocab:       return "Topic Vocab"
        case .writingCoach:     return "Writing Coach"
        case .wordBrainstorm:   return "Word Brainstorm"
        }
    }

    var icon: String {
        switch self {
        case .wordHunter:       return "scope"
        case .sentenceWorkshop: return "pencil.and.outline"
        case .topicVocab:       return "building.2"
        case .writingCoach:     return "sparkles"
        case .wordBrainstorm:   return "network"
        }
    }

    var modeDescription: String {
        switch self {
        case .wordHunter:       return "Find the perfect word for any situation"
        case .sentenceWorkshop: return "Improve your writing, word by word"
        case .topicVocab:       return "Master vocabulary from any industry or field"
        case .writingCoach:     return "Get evocative word suggestions while writing"
        case .wordBrainstorm:   return "Explore thematic word clusters and semantic fields"
        }
    }

    var quickPrompts: [String] {
        switch self {
        case .wordHunter:
            return [
                "I need a word for the feeling of being happy but slightly sad",
                "What's the word for someone who only talks about themselves?",
                "Find me a formal word for making something worse"
            ]
        case .sentenceWorkshop:
            return [
                "Make this more formal: \"The idea was really cool\"",
                "Give me 3 ways to rewrite: \"He was very angry\"",
                "What's a better word than 'good' in an academic context?"
            ]
        case .topicVocab:
            return [
                "Teach me 8 key terms used in venture capital",
                "What vocabulary do surgeons use that laypeople don't?",
                "Give me niche words from the world of perfumery"
            ]
        case .writingCoach:
            return [
                "Words that evoke loneliness without saying lonely",
                "Strong verbs for describing someone walking confidently",
                "Adjectives for light that feels heavy or oppressive"
            ]
        case .wordBrainstorm:
            return [
                "Words related to the concept of time slipping away",
                "Give me a semantic field around 'betrayal'",
                "Words that sound like what they mean"
            ]
        }
    }

    private static let bracketInstruction = "When you mention specific vocabulary words the user should learn or save, always wrap them in double square brackets like [[serendipity]]. Do not bracket common words — only notable, useful, or learnable vocabulary."

    var systemPrompt: String {
        switch self {
        case .wordHunter:
            return "You are a precision vocabulary specialist. The user describes a concept, feeling, situation, or nuance — you find the exact word for it. Offer 3–5 options with brief explanations of their different connotations and registers (formal, literary, colloquial, archaic). \(Self.bracketInstruction)"
        case .sentenceWorkshop:
            return "You are a sharp-eyed writing editor. When the user shares text, you improve word choice, clarity, and tone. Always explain *why* a word is better. Offer multiple alternatives at different registers. \(Self.bracketInstruction)"
        case .topicVocab:
            return "You are a domain vocabulary expert. When the user names a topic, industry, profession, or field, teach them 6–10 key specialist terms that insiders use but outsiders don't know. For each term, give a one-sentence plain-English explanation and a usage example. \(Self.bracketInstruction)"
        case .writingCoach:
            return "You are a literary writing coach focused on vivid, precise vocabulary. Help the user find evocative words for scenes, emotions, and descriptions. Group suggestions by effect or mood. \(Self.bracketInstruction)"
        case .wordBrainstorm:
            return "You are a lexical cartographer mapping the semantic landscape. When the user gives a concept or theme, explore its word cluster: synonyms, antonyms, hyponyms, related metaphors, and words from adjacent domains. Organize into interesting categories. \(Self.bracketInstruction)"
        }
    }
}
```

### `GeneralChatMessage` struct

```swift
struct GeneralChatMessage: Identifiable, Equatable {
    enum Role { case user, assistant }

    let id: UUID
    let role: Role
    var content: String
    var suggestedWords: [String]   // extracted [[word]] tokens after streaming completes
    var savedWords: Set<String>    // words successfully saved to library
    var savingWords: Set<String>   // words currently mid-save (show spinner)
    var errorWords: Set<String>    // words that failed to save
    let timestamp: Date

    init(role: Role, content: String = "") {
        self.id = UUID()
        self.role = role
        self.content = content
        self.suggestedWords = []
        self.savedWords = []
        self.savingWords = []
        self.errorWords = []
        self.timestamp = Date()
    }
}
```

### `GeneralChatViewModel` class

```swift
@Observable
@MainActor
final class GeneralChatViewModel {
    var messages: [GeneralChatMessage] = []
    var inputText: String = ""
    var isGenerating: Bool = false
    var errorMessage: String? = nil
    var selectedMode: GeneralChatMode = .wordHunter

    private let aiRepository: AIRepository
    private let dictionaryRepository: DictionaryRepository
    private let wordRepository: WordRepository
    private let collectionRepository: CollectionRepository

    init(
        aiRepository: AIRepository,
        dictionaryRepository: DictionaryRepository,
        wordRepository: WordRepository,
        collectionRepository: CollectionRepository
    ) {
        self.aiRepository = aiRepository
        self.dictionaryRepository = dictionaryRepository
        self.wordRepository = wordRepository
        self.collectionRepository = collectionRepository
    }

    var showQuickPrompts: Bool { messages.isEmpty }

    // MARK: - Send

    func send(text: String? = nil) async {
        let userText = (text ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty, !isGenerating else { return }
        inputText = ""
        messages.append(GeneralChatMessage(role: .user, content: userText))

        let assistantMessage = GeneralChatMessage(role: .assistant)
        messages.append(assistantMessage)
        isGenerating = true
        errorMessage = nil

        do {
            let stream = try await aiRepository.generateContent(
                for: "",
                type: .chat(systemPrompt: selectedMode.systemPrompt, userMessage: userText)
            )
            for try await chunk in stream {
                if let idx = messages.firstIndex(where: { $0.id == assistantMessage.id }) {
                    messages[idx].content += chunk
                }
            }
        } catch {
            if let idx = messages.firstIndex(where: { $0.id == assistantMessage.id }) {
                messages[idx].content = "Something went wrong. Please try again."
            }
            errorMessage = error.localizedDescription
        }

        // Extract [[word]] tokens after streaming finishes
        if let idx = messages.firstIndex(where: { $0.id == assistantMessage.id }) {
            messages[idx].suggestedWords = extractWords(from: messages[idx].content)
        }
        isGenerating = false
    }

    // MARK: - Mode Switch

    func switchMode(_ mode: GeneralChatMode) {
        guard mode != selectedMode else { return }
        selectedMode = mode
        messages = []
        errorMessage = nil
    }

    // MARK: - Word Save

    func saveWord(_ word: String, messageId: UUID) async {
        guard let msgIdx = messages.firstIndex(where: { $0.id == messageId }) else { return }
        guard !messages[msgIdx].savedWords.contains(word),
              !messages[msgIdx].savingWords.contains(word) else { return }

        messages[msgIdx].savingWords.insert(word)
        messages[msgIdx].errorWords.remove(word)

        do {
            let entity = try await dictionaryRepository.lookup(word: word)
            try await wordRepository.saveWord(entity)

            // Add to "Favorites" collection if it exists
            let collections = (try? await collectionRepository.fetchCollections()) ?? []
            if let fav = collections.first(where: { $0.name == "Favorites" }) {
                try? await collectionRepository.addWordToCollection(
                    wordId: entity.id,
                    collectionId: fav.id
                )
            }
            if let idx = messages.firstIndex(where: { $0.id == messageId }) {
                messages[idx].savingWords.remove(word)
                messages[idx].savedWords.insert(word)
            }
        } catch {
            if let idx = messages.firstIndex(where: { $0.id == messageId }) {
                messages[idx].savingWords.remove(word)
                messages[idx].errorWords.insert(word)
            }
        }
    }

    // MARK: - Helpers

    private func extractWords(from text: String) -> [String] {
        let pattern = /\[\[([^\]]+)\]\]/
        let matches = text.matches(of: pattern)
        let words = matches.map { String($0.output.1).trimmingCharacters(in: .whitespacesAndNewlines) }
        // Deduplicate while preserving order
        var seen = Set<String>()
        return words.filter { seen.insert($0.lowercased()).inserted }
    }
}
```

- [ ] **Step 1: Create the directory**

```bash
mkdir -p "VocabApp/Features/GeneralChat/ViewModels"
mkdir -p "VocabApp/Features/GeneralChat/Views"
```

- [ ] **Step 2: Create `GeneralChatViewModel.swift`** with the full code above at path `VocabApp/Features/GeneralChat/ViewModels/GeneralChatViewModel.swift`.

- [ ] **Step 3: Build to verify no errors**

```bash
xcodebuild -scheme VocabApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **` (file is not yet in pbxproj — SourceKit errors are expected, build errors are not until Step registered in pbxproj in Task 3).

---

## Task 2: `GeneralChatView`

**Files:**
- Create: `VocabApp/Features/GeneralChat/Views/GeneralChatView.swift`

The view reuses the same structural pattern as `WordChatView` with two additions:
1. **Word chips** rendered below each completed assistant message
2. **`cleanedContent`** computed property strips `[[word]]` brackets from display text

```swift
import SwiftUI

struct GeneralChatView: View {
    @State var viewModel: GeneralChatViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                modePicker
                Divider()
                messagesArea
                inputBar
            }
            .background(Theme.Colors.background)
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: - Mode Picker (identical pattern to WordChatView)

    private var modePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GeneralChatMode.allCases) { mode in
                    Button {
                        withAnimation(.spring(duration: 0.25)) { viewModel.switchMode(mode) }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 12, weight: .semibold))
                            Text(mode.displayName)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(viewModel.selectedMode == mode ? .white : Theme.Colors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(viewModel.selectedMode == mode ? Theme.Colors.amieBlue : Theme.Colors.surface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(
                            viewModel.selectedMode == mode ? Color.clear : Theme.Colors.border,
                            lineWidth: 1
                        ))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Messages Area

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if viewModel.showQuickPrompts {
                        quickPromptsView
                    } else {
                        ForEach(viewModel.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .onChange(of: viewModel.messages.count) {
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom") }
            }
            .onChange(of: viewModel.messages.last?.content) {
                proxy.scrollTo("bottom")
            }
        }
    }

    // MARK: - Quick Prompts

    private var quickPromptsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.selectedMode.displayName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(viewModel.selectedMode.modeDescription)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 8) {
                Text("SUGGESTIONS")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(Theme.Colors.textSecondary)
                ForEach(viewModel.selectedMode.quickPrompts, id: \.self) { prompt in
                    Button {
                        Task { await viewModel.send(text: prompt) }
                    } label: {
                        HStack {
                            Text(prompt)
                                .font(.system(size: 15))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.border))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Message Bubble

    @ViewBuilder
    private func messageBubble(_ message: GeneralChatMessage) -> some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
            HStack {
                if message.role == .user { Spacer(minLength: 60) }

                Text(message.role == .assistant ? cleanedContent(message.content) : message.content)
                    .font(.system(size: 15))
                    .foregroundColor(message.role == .user ? .white : Theme.Colors.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.role == .user ? Theme.Colors.amieBlue : Theme.Colors.surface)
                    .clipShape(GeneralBubbleShape(isUser: message.role == .user))
                    .overlay(
                        message.role == .assistant
                            ? GeneralBubbleShape(isUser: false).stroke(Theme.Colors.border, lineWidth: 1)
                            : nil
                    )

                if message.role == .assistant { Spacer(minLength: 60) }
            }

            // Word chips — only for completed assistant messages
            if message.role == .assistant,
               !message.suggestedWords.isEmpty,
               !viewModel.isGenerating || message.id != viewModel.messages.last?.id {
                wordChipsRow(message: message)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Word Chips

    @ViewBuilder
    private func wordChipsRow(message: GeneralChatMessage) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(message.suggestedWords, id: \.self) { word in
                    wordChip(word: word, message: message)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private func wordChip(word: String, message: GeneralChatMessage) -> some View {
        let isSaved   = message.savedWords.contains(word)
        let isSaving  = message.savingWords.contains(word)
        let isError   = message.errorWords.contains(word)

        Button {
            if !isSaved && !isSaving {
                Task { await viewModel.saveWord(word, messageId: message.id) }
            }
        } label: {
            HStack(spacing: 5) {
                if isSaving {
                    ProgressView().scaleEffect(0.6)
                } else if isSaved {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.Colors.amieGreen)
                } else if isError {
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.Colors.amieBlue)
                }
                Text(word)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(
                        isSaved ? Theme.Colors.amieGreen :
                        isError ? .red :
                        Theme.Colors.textPrimary
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isSaved ? Theme.Colors.amieGreen.opacity(0.1) :
                isError ? Color.red.opacity(0.08) :
                Theme.Colors.surface
            )
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(
                    isSaved ? Theme.Colors.amieGreen.opacity(0.4) :
                    isError ? Color.red.opacity(0.3) :
                    Theme.Colors.border,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(isSaved || isSaving)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask anything about words…", text: $viewModel.inputText, axis: .vertical)
                    .font(.system(size: 15))
                    .lineLimit(1...4)
                    .focused($inputFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.Colors.border))

                Button {
                    inputFocused = false
                    Task { await viewModel.send() }
                } label: {
                    if viewModel.isGenerating {
                        ProgressView().scaleEffect(0.8).frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(
                                viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Theme.Colors.textSecondary.opacity(0.3)
                                    : Theme.Colors.amieBlue
                            )
                    }
                }
                .disabled(
                    viewModel.isGenerating ||
                    viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.Colors.background)
        }
    }

    // MARK: - Helpers

    /// Remove [[word]] brackets from display text — user sees "serendipity" not "[[serendipity]]"
    private func cleanedContent(_ text: String) -> String {
        text.replacing(/\[\[([^\]]+)\]\]/) { match in String(match.output.1) }
    }
}

// MARK: - Bubble Shape (local copy — identical to WordChatView's)

private struct GeneralBubbleShape: Shape {
    let isUser: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = 16
        let tail: CGFloat = 4
        if isUser {
            path.addRoundedRect(in: rect, cornerRadii: .init(
                topLeading: radius, bottomLeading: radius, bottomTrailing: tail, topTrailing: radius))
        } else {
            path.addRoundedRect(in: rect, cornerRadii: .init(
                topLeading: tail, bottomLeading: radius, bottomTrailing: radius, topTrailing: radius))
        }
        return path
    }
}
```

- [ ] **Step 1: Create `GeneralChatView.swift`** with the full code above at path `VocabApp/Features/GeneralChat/Views/GeneralChatView.swift`.

---

## Task 3: Register files in Xcode project

**Files:**
- Modify: `VocabApp.xcodeproj/project.pbxproj`

Generate 7 UUIDs (24-char uppercase hex):

```bash
python3 -c "import secrets; [print(secrets.token_hex(12).upper()) for _ in range(7)]"
```

Assign them:
- `UUID_FILEREF_VM`  → FileRef for `GeneralChatViewModel.swift`
- `UUID_FILEREF_V`   → FileRef for `GeneralChatView.swift`
- `UUID_BUILD_VM`    → BuildFile for `GeneralChatViewModel.swift`
- `UUID_BUILD_V`     → BuildFile for `GeneralChatView.swift`
- `UUID_GROUP_FEAT`  → PBXGroup for `GeneralChat` feature folder
- `UUID_GROUP_VMS`   → PBXGroup for `GeneralChat/ViewModels`
- `UUID_GROUP_VS`    → PBXGroup for `GeneralChat/Views`

- [ ] **Step 1: Add PBXBuildFile entries** — insert before `/* End PBXBuildFile section */`:

```
		<UUID_BUILD_VM> /* GeneralChatViewModel.swift in Sources */ = {isa = PBXBuildFile; fileRef = <UUID_FILEREF_VM> /* GeneralChatViewModel.swift */; };
		<UUID_BUILD_V> /* GeneralChatView.swift in Sources */ = {isa = PBXBuildFile; fileRef = <UUID_FILEREF_V> /* GeneralChatView.swift */; };
```

- [ ] **Step 2: Add PBXFileReference entries** — insert after the first entry in `/* Begin PBXFileReference section */`:

```
		<UUID_FILEREF_VM> /* GeneralChatViewModel.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = GeneralChatViewModel.swift; sourceTree = "<group>"; };
		<UUID_FILEREF_V> /* GeneralChatView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = GeneralChatView.swift; sourceTree = "<group>"; };
```

- [ ] **Step 3: Add PBXGroup entries** — insert after the `WordChat` group block (the one with `171AD52E71295DD2D03043B7`):

```
		<UUID_GROUP_FEAT> /* GeneralChat */ = {
			isa = PBXGroup;
			children = (
				<UUID_GROUP_VMS> /* ViewModels */,
				<UUID_GROUP_VS> /* Views */,
			);
			path = GeneralChat;
			sourceTree = "<group>";
		};
		<UUID_GROUP_VMS> /* ViewModels */ = {
			isa = PBXGroup;
			children = (
				<UUID_FILEREF_VM> /* GeneralChatViewModel.swift */,
			);
			path = ViewModels;
			sourceTree = "<group>";
		};
		<UUID_GROUP_VS> /* Views */ = {
			isa = PBXGroup;
			children = (
				<UUID_FILEREF_V> /* GeneralChatView.swift */,
			);
			path = Views;
			sourceTree = "<group>";
		};
```

- [ ] **Step 4: Add `GeneralChat` to Features group** — find the `39CD31C007C252F4C7B187DF /* Features */` group and add `<UUID_GROUP_FEAT> /* GeneralChat */,` to its `children` array alongside `WordChat`.

- [ ] **Step 5: Add to Sources build phase** — find the `PBXSourcesBuildPhase` section and add both build file entries near the other `WordChat` entries:

```
				<UUID_BUILD_VM> /* GeneralChatViewModel.swift in Sources */,
				<UUID_BUILD_V> /* GeneralChatView.swift in Sources */,
```

- [ ] **Step 6: Build**

```bash
xcodebuild -scheme VocabApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`

---

## Task 4: Wire entry point in `HomeView`

**Files:**
- Modify: `VocabApp/Features/Home/Views/HomeView.swift`

- [ ] **Step 1: Add `@State private var showGeneralChat = false` property**

Add after `@State private var showReview = false` (line ~16):

```swift
@State private var showGeneralChat = false
```

- [ ] **Step 2: Add `sparkles` toolbar button**

In the `toolbar` block, after the existing `ToolbarItem(placement: .topBarTrailing)` for the profile button (around line 184), add a new trailing item:

```swift
ToolbarItem(placement: .topBarTrailing) {
    Button {
        showGeneralChat = true
    } label: {
        Image(systemName: "sparkles")
            .fontWeight(.semibold)
            .foregroundStyle(Theme.Colors.amieBlue)
    }
    .transition(.opacity.combined(with: .move(edge: .top)))
}
```

- [ ] **Step 3: Add sheet**

After the existing `.fullScreenCover(isPresented: $showReview)` modifier (around line 154), add:

```swift
.sheet(isPresented: $showGeneralChat) {
    if let env = appEnvironment {
        GeneralChatView(viewModel: GeneralChatViewModel(
            aiRepository: env.aiRepository,
            dictionaryRepository: env.dictionaryRepository,
            wordRepository: env.wordRepository,
            collectionRepository: env.collectionRepository
        ))
    }
}
```

- [ ] **Step 4: Build and verify**

```bash
xcodebuild -scheme VocabApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add VocabApp/Features/GeneralChat/ViewModels/GeneralChatViewModel.swift \
        VocabApp/Features/GeneralChat/Views/GeneralChatView.swift \
        VocabApp/Features/Home/Views/HomeView.swift \
        VocabApp.xcodeproj/project.pbxproj
git commit -m "feat: add general AI chat with word saving from suggested vocabulary chips"
```

---

## Self-Review

**Spec coverage:**
- ✅ General chat not tied to a word
- ✅ Brainstorming mode (Word Brainstorm)
- ✅ Flesh out sentences (Sentence Workshop)
- ✅ Look for specific words (Word Hunter)
- ✅ Words with niche industry context (Topic Vocab)
- ✅ Saving those words to library (word chips with `+` → dictionary lookup → Favorites)
- ✅ Word-specific chat preserved (unchanged `WordChatView`)
- ✅ Entry point from Home screen (sparkles toolbar button)

**Placeholder scan:** No TBDs, no vague steps. All code is complete.

**Type consistency:**
- `GeneralChatViewModel.send()` uses `aiRepository.generateContent(for: "", type: .chat(...))` — passing empty string for `word` is intentional; `AIRepository` accepts it.
- `GeneralChatView` references `GeneralChatMessage.suggestedWords`, `savedWords`, `savingWords`, `errorWords` — all defined in `GeneralChatMessage` struct in Task 1.
- `cleanedContent` uses `Regex` literal `/\[\[([^\]]+)\]\]/` — requires Swift 5.7+ (iOS 16+, project already targets iOS 17+).
- `extractWords` in ViewModel uses the same regex — consistent.
