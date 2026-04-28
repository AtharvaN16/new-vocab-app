# AI Chat — Consolidated Modes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current 8-mode word chat and implement a new 3-mode general chat, giving each mode a genuine, deep value proposition — including a Challenge Me mode that uses GRE-proven question mechanics (text completion, sentence equivalence, contrast logic, micro-passage) to build true word ownership, not just recall.

**Architecture:**
- `WordChatViewModel` is rewritten in-place: `AssistantMode` collapses from 8 cases to 3. Challenge Me encodes multi-type question generation and adaptive difficulty entirely through its system prompt — no external question generation infrastructure.
- `GeneralChatViewModel` + `GeneralChatView` are new files. The AI wraps vocabulary recommendations in `[[word]]` markers, which the view parses and renders as saveable chips. This is the vocabulary discovery surface of the app.
- Entry point: `sparkles` toolbar button in `HomeView`.

**Tech Stack:** SwiftUI, `@Observable`, `@MainActor`, `AsyncThrowingStream<String,Error>` (existing `AIRepository`), Swift `Regex` literals (iOS 17+).

---

## Design Decisions

### Why 3 modes per context, not 1 or 8

One unconstrained chat produces unfocused responses — the AI needs a persona to give useful, targeted output. Eight modes fragment the user's mental model and dilute quality. Three modes per context is the minimum that covers genuinely distinct jobs-to-be-done:

| Job | Word Chat | General Chat |
|---|---|---|
| Learn deeply / explore | Deep Dive | — |
| Practice / test retention | Challenge Me | — |
| Apply in real writing | Write With It | Write Better |
| Find a word for a concept | — | Word Hunt |
| Learn a domain's vocabulary | — | Vocabulary Safari |

No overlap. Each mode is irreplaceable.

### Why GRE mechanics belong in Challenge Me, not a separate screen

The SRS system already handles *when* to review. Challenge Me handles *how* — turning review sessions into reasoning challenges rather than definition recall. The four question types (text completion, sentence equivalence, micro-passage, contrast logic) are encoding patterns that force the user to understand nuance and connotation, not just meaning. These are implemented entirely through the system prompt, not a separate question engine, keeping the architecture simple.

### The `[[word]]` contract in General Chat

Every General Chat mode's system prompt instructs the AI to wrap notable vocabulary in `[[word]]`. The view strips brackets from display text and renders them as saveable chips with `+` → spinner → checkmark flow. Tapping saves via `dictionaryRepository.lookup` → `wordRepository.saveWord` → adds to "Favorites" collection.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `VocabApp/Features/WordChat/ViewModels/WordChatViewModel.swift` | **Rewrite** | 3-mode AssistantMode, Challenge Me with GRE mechanics |
| `VocabApp/Features/WordChat/Views/WordChatView.swift` | **No change** | Consumes AssistantMode — UI adapts automatically |
| `VocabApp/Features/GeneralChat/ViewModels/GeneralChatViewModel.swift` | **Create** | 3-mode GeneralChatMode, `[[word]]` extraction, per-word save |
| `VocabApp/Features/GeneralChat/Views/GeneralChatView.swift` | **Create** | Mode picker, chat bubbles, word chip row, input bar |
| `VocabApp/Features/Home/Views/HomeView.swift` | **Modify** | Add sparkles toolbar button + sheet |
| `VocabApp.xcodeproj/project.pbxproj` | **Modify** | Register two new Swift files |

---

## Task 1: Rewrite `WordChatViewModel.swift` — 3 consolidated modes

**Files:**
- Modify: `VocabApp/Features/WordChat/ViewModels/WordChatViewModel.swift`

Replace the entire file content. The `AssistantMode` enum drops from 8 cases to 3. `ChatMessage`, `ChatSaveType`, and `WordChatViewModel` class are preserved structurally but the enum is completely replaced.

- [ ] **Step 1: Replace the file** with the following complete content:

```swift
import Foundation
import SwiftUI

// MARK: - Assistant Mode

enum AssistantMode: String, CaseIterable, Identifiable {
    case deepDive
    case challengeMe
    case writeWithIt

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .deepDive:     return "Deep Dive"
        case .challengeMe:  return "Challenge Me"
        case .writeWithIt:  return "Write With It"
        }
    }

    var icon: String {
        switch self {
        case .deepDive:     return "brain"
        case .challengeMe:  return "bolt.circle"
        case .writeWithIt:  return "pencil.and.outline"
        }
    }

    var modeDescription: String {
        switch self {
        case .deepDive:     return "Everything fascinating about this word"
        case .challengeMe:  return "Adaptive questions that build real ownership"
        case .writeWithIt:  return "Use this word in your own writing"
        }
    }

    func systemPrompt(for word: WordEntity) -> String {
        let defs = word.definitions.prefix(2).map(\.text).joined(separator: "; ")
        let base = "The user is studying the word \"\(word.word)\"\(defs.isEmpty ? "." : " — defined as: \(defs).")"

        switch self {
        case .deepDive:
            return """
            \(base)

            You are a brilliant, curious expert on this word. Your job is to make the user genuinely fascinated by it — not just know what it means, but understand why it exists, what nuance it carries, and how it connects to the world.

            Cover what the conversation calls for:
            - Origins and etymology (language family, root meaning, how it evolved)
            - Connotations and register (formal vs casual, positive vs negative charge)
            - Subtle differences from close synonyms
            - Surprising real-world usage (literature, historical speeches, specific industries)
            - Connections to other words the user might know

            Be conversational, not encyclopedic. Respond to what the user specifically asks. 2–4 paragraphs max per turn.
            """

        case .challengeMe:
            return """
            \(base)

            You are an adaptive vocabulary coach. Your job is to test the user's understanding of "\(word.word)" using four question types, cycling through them to build multiple layers of word ownership:

            QUESTION TYPES (use all four across the conversation):

            1. TEXT COMPLETION — Create a sentence with a blank where "\(word.word)" fits naturally. Use logical contrast signals (although, despite, however, while) when possible. Provide 4 options: the correct word, one near-synonym (trap), one antonym, one off-topic distractor. All options must be the same part of speech.

            2. SENTENCE EQUIVALENCE — Find a true synonym of "\(word.word)" and build a sentence where both fit identically. Provide 6 options: the 2 correct synonyms + 4 distractors including at least one near-synonym trap. Label both correct answers only after the user responds.

            3. MICRO-PASSAGE — Write 2–3 sentences using "\(word.word)" in a realistic, nuanced context. Ask: "What does '\(word.word)' most nearly mean in this context?" Provide 4 options where the wrong answers are plausible but fail on tone or specificity.

            4. USE IT — Give the user a specific scenario (formal email, literary passage, casual conversation) and ask them to write one sentence using "\(word.word)". When they respond, rate their sentence on accuracy (did they use it correctly?) and precision (did they capture the nuance?). Suggest improvements.

            DIFFICULTY LEVELS:
            - Start at Level 1 (direct meaning, simple sentence, obvious context)
            - Promote to Level 2 after a correct answer (requires interpreting tone)
            - Promote to Level 3 after two correct (multi-signal sentences)
            - Promote to Level 4 after three correct (trap-heavy distractors, subtle tone mismatches)
            - Drop one level after a wrong answer

            FEEDBACK (after every answer):
            - State whether the user was correct
            - Explain specifically why the correct answer works
            - Explain why each distractor fails (this is the most valuable part)
            - Then generate the next question

            Start immediately with your first question now. Do not introduce yourself — just begin the question.
            """

        case .writeWithIt:
            return """
            \(base)

            You are a writing coach helping the user actually use "\(word.word)" in their own voice. Your job is to bridge the gap between knowing a word and owning it.

            What you do:
            - If the user pastes their own text: identify where "\(word.word)" could fit naturally, show them the revised version, explain why it works there, and suggest how the tone changes with it.
            - If the user hasn't started yet: give them 2–3 specific writing prompts (different registers: formal, literary, casual) and invite them to try one.
            - When the user writes a sentence: rate it on two axes — correctness (did they use it right?) and precision (did they capture its specific nuance vs a blander synonym?). Be specific, not just "good job."
            - Suggest alternatives at different registers if relevant.

            One rule: never write their sentence for them unless they explicitly ask. Challenge them to try first. The act of writing it is the learning.
            """
        }
    }

    var quickPrompts: [String] {
        switch self {
        case .deepDive:
            return [
                "What makes this word different from its closest synonyms?",
                "Where does this word come from originally?",
                "What's a surprising or unusual usage of this word?"
            ]
        case .challengeMe:
            return [
                "Start a Level 1 question",
                "Give me a sentence equivalence challenge",
                "Test me with a micro-passage"
            ]
        case .writeWithIt:
            return [
                "Give me a writing prompt to try this word",
                "I'll paste a sentence — help me work this word in",
                "What register suits this word best?"
            ]
        }
    }
}

// MARK: - Message

struct ChatMessage: Identifiable, Equatable {
    enum Role { case user, assistant }

    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date

    init(role: Role, content: String = "") {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

// MARK: - Save Type

enum ChatSaveType {
    case note
    case example
    case mnemonic
}

// MARK: - ViewModel

@Observable
@MainActor
final class WordChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isGenerating: Bool = false
    var errorMessage: String? = nil
    var selectedMode: AssistantMode = .deepDive

    let word: WordEntity
    private let aiRepository: AIRepository
    private let wordRepository: WordRepository

    init(word: WordEntity, aiRepository: AIRepository, wordRepository: WordRepository) {
        self.word = word
        self.aiRepository = aiRepository
        self.wordRepository = wordRepository
    }

    var showQuickPrompts: Bool { messages.isEmpty }

    func send(text: String? = nil) async {
        let userText = (text ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty, !isGenerating else { return }

        inputText = ""
        messages.append(ChatMessage(role: .user, content: userText))

        let assistantMessage = ChatMessage(role: .assistant)
        messages.append(assistantMessage)

        isGenerating = true
        errorMessage = nil

        do {
            let stream = try await aiRepository.generateContent(
                for: word.word,
                type: .chat(
                    systemPrompt: selectedMode.systemPrompt(for: word),
                    userMessage: userText
                )
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

        isGenerating = false
    }

    func switchMode(_ mode: AssistantMode) {
        guard mode != selectedMode else { return }
        selectedMode = mode
        messages = []
        errorMessage = nil
    }

    func saveMessage(_ message: ChatMessage, as saveType: ChatSaveType) async {
        guard message.role == .assistant, !message.content.isEmpty else { return }
        let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)

        let updated: WordEntity
        switch saveType {
        case .note:
            let existing = word.userNotes.map { "\($0)\n\n" } ?? ""
            updated = WordEntity(
                id: word.id, word: word.word, phonetic: word.phonetic,
                definitions: word.definitions, examples: word.examples,
                synonyms: word.synonyms, antonyms: word.antonyms,
                etymology: word.etymology, otherForms: word.otherForms,
                aiMnemonic: word.aiMnemonic,
                userNotes: "\(existing)\(content)",
                sources: word.sources, createdAt: word.createdAt, updatedAt: Date(),
                audioURL: word.audioURL, syllables: word.syllables,
                register: word.register, contextualNote: word.contextualNote,
                qualityScore: word.qualityScore
            )
        case .example:
            let newExample = WordEntity.Example(text: content, source: "AI Chat", isAIGenerated: true)
            updated = WordEntity(
                id: word.id, word: word.word, phonetic: word.phonetic,
                definitions: word.definitions,
                examples: word.examples + [newExample],
                synonyms: word.synonyms, antonyms: word.antonyms,
                etymology: word.etymology, otherForms: word.otherForms,
                aiMnemonic: word.aiMnemonic, userNotes: word.userNotes,
                sources: word.sources, createdAt: word.createdAt, updatedAt: Date(),
                audioURL: word.audioURL, syllables: word.syllables,
                register: word.register, contextualNote: word.contextualNote,
                qualityScore: word.qualityScore
            )
        case .mnemonic:
            updated = WordEntity(
                id: word.id, word: word.word, phonetic: word.phonetic,
                definitions: word.definitions, examples: word.examples,
                synonyms: word.synonyms, antonyms: word.antonyms,
                etymology: word.etymology, otherForms: word.otherForms,
                aiMnemonic: content,
                userNotes: word.userNotes,
                sources: word.sources, createdAt: word.createdAt, updatedAt: Date(),
                audioURL: word.audioURL, syllables: word.syllables,
                register: word.register, contextualNote: word.contextualNote,
                qualityScore: word.qualityScore
            )
        }
        try? await wordRepository.saveWord(updated)
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -scheme VocabApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add VocabApp/Features/WordChat/ViewModels/WordChatViewModel.swift
git commit -m "refactor: consolidate word chat to 3 focused modes with Challenge Me GRE-style question mechanics"
```

---

## Task 2: Create `GeneralChatViewModel.swift`

**Files:**
- Create: `VocabApp/Features/GeneralChat/ViewModels/GeneralChatViewModel.swift`

- [ ] **Step 1: Create the directories**

```bash
mkdir -p "VocabApp/Features/GeneralChat/ViewModels"
mkdir -p "VocabApp/Features/GeneralChat/Views"
```

- [ ] **Step 2: Create the file** at `VocabApp/Features/GeneralChat/ViewModels/GeneralChatViewModel.swift`:

```swift
import Foundation
import SwiftUI

// MARK: - General Chat Mode

enum GeneralChatMode: String, CaseIterable, Identifiable {
    case wordHunt
    case vocabularySafari
    case writeBetter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wordHunt:          return "Word Hunt"
        case .vocabularySafari:  return "Vocabulary Safari"
        case .writeBetter:       return "Write Better"
        }
    }

    var icon: String {
        switch self {
        case .wordHunt:          return "scope"
        case .vocabularySafari:  return "binoculars"
        case .writeBetter:       return "text.badge.star"
        }
    }

    var modeDescription: String {
        switch self {
        case .wordHunt:          return "Describe what you need — I'll find the exact word"
        case .vocabularySafari:  return "Immerse yourself in any field's vocabulary"
        case .writeBetter:       return "Paste your writing — leave with stronger words"
        }
    }

    var quickPrompts: [String] {
        switch self {
        case .wordHunt:
            return [
                "I need a word for the anxiety of making an irreversible decision",
                "What's the word for a sound that triggers a memory involuntarily?",
                "Find me a formal word that means 'to make something worse'"
            ]
        case .vocabularySafari:
            return [
                "Take me into the world of competitive chess",
                "Teach me vocabulary that sommeliers use but outsiders don't",
                "What terms do venture capitalists use that sound like jargon but mean something specific?"
            ]
        case .writeBetter:
            return [
                "The idea was really interesting and made me think a lot.",
                "He was very angry and said some mean things.",
                "The solution seemed good but had some problems we didn't see."
            ]
        }
    }

    private static let bracketInstruction = "When you mention specific vocabulary words the user should learn or consider saving, wrap each one in double square brackets like [[serendipity]]. Only bracket notable, learnable vocabulary — not common everyday words."

    var systemPrompt: String {
        switch self {
        case .wordHunt:
            return """
            You are a precision vocabulary specialist. The user will describe a concept, feeling, situation, or nuance — your job is to surface the exact word(s) for it.

            How to respond:
            - Offer 3–5 candidate words with brief notes on how they differ in connotation and register
            - Be specific about when each word works and when it doesn't
            - If one is clearly the best fit, say so directly
            - If the user has already saved related words in their vocabulary, you may reference them by name if they seem relevant

            \(Self.bracketInstruction)
            """

        case .vocabularySafari:
            return """
            You are an expert guide leading vocabulary immersions into specific domains. When the user names a field, industry, profession, craft, or world, you don't just list words — you bring them into that world.

            How to respond:
            - Introduce 6–10 specialist terms that insiders use naturally but outsiders wouldn't know
            - For each term: a plain-English explanation, why insiders use it instead of the common equivalent, and a realistic usage example
            - Group terms thematically when possible (e.g., "terms for valuation" vs "terms for fundraising stages")
            - End each message inviting the user to go deeper on any term or explore a related sub-domain

            \(Self.bracketInstruction)
            """

        case .writeBetter:
            return """
            You are a sharp-eyed editor focused entirely on vocabulary. When the user pastes text, your job is to identify the words that are doing the least work and replace them with words that do more.

            How to respond:
            - Quote the specific weak word or phrase from their text
            - Explain what's weak about it (vague, overused, wrong register, missed nuance)
            - Offer 2–3 replacement options at different registers (formal, literary, direct)
            - Show the revised sentence so the improvement is immediately visible
            - Don't rewrite their whole text — focus on vocabulary, not structure

            If the user's text is already strong, say so specifically and explain what's working.

            \(Self.bracketInstruction)
            """
        }
    }
}

// MARK: - General Chat Message

struct GeneralChatMessage: Identifiable, Equatable {
    enum Role { case user, assistant }

    let id: UUID
    let role: Role
    var content: String
    var suggestedWords: [String]  // extracted from [[word]] after streaming completes
    var savedWords: Set<String>
    var savingWords: Set<String>
    var errorWords: Set<String>
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

// MARK: - ViewModel

@Observable
@MainActor
final class GeneralChatViewModel {
    var messages: [GeneralChatMessage] = []
    var inputText: String = ""
    var isGenerating: Bool = false
    var errorMessage: String? = nil
    var selectedMode: GeneralChatMode = .wordHunt

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

        // Parse [[word]] tokens after streaming completes
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
        let words = text.matches(of: pattern)
            .map { String($0.output.1).trimmingCharacters(in: .whitespacesAndNewlines) }
        var seen = Set<String>()
        return words.filter { seen.insert($0.lowercased()).inserted }
    }
}
```

- [ ] **Step 3: Build to verify** (file not yet in pbxproj — SourceKit errors expected, compiler errors are not)

---

## Task 3: Create `GeneralChatView.swift`

**Files:**
- Create: `VocabApp/Features/GeneralChat/Views/GeneralChatView.swift`

- [ ] **Step 1: Create the file** at `VocabApp/Features/GeneralChat/Views/GeneralChatView.swift`:

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

    // MARK: - Mode Picker

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
                            messageBubble(message).id(message.id)
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
                Text("TRY ASKING")
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
        let isStreaming = viewModel.isGenerating && message.id == viewModel.messages.last?.id

        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
            HStack {
                if message.role == .user { Spacer(minLength: 60) }

                Text(message.role == .assistant ? cleanedContent(message.content) : message.content)
                    .font(.system(size: 15))
                    .foregroundColor(message.role == .user ? .white : Theme.Colors.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.role == .user ? Theme.Colors.amieBlue : Theme.Colors.surface)
                    .clipShape(ChatBubbleShape(isUser: message.role == .user))
                    .overlay(
                        message.role == .assistant
                            ? ChatBubbleShape(isUser: false).stroke(Theme.Colors.border, lineWidth: 1)
                            : nil
                    )

                if message.role == .assistant { Spacer(minLength: 60) }
            }

            // Word chips appear after streaming completes
            if message.role == .assistant, !message.suggestedWords.isEmpty, !isStreaming {
                wordChipsRow(message: message)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Word Chips

    @ViewBuilder
    private func wordChipsRow(message: GeneralChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SAVE TO LIBRARY")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1.2)
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.horizontal, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(message.suggestedWords, id: \.self) { word in
                        wordChip(word: word, message: message)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private func wordChip(word: String, message: GeneralChatMessage) -> some View {
        let isSaved  = message.savedWords.contains(word)
        let isSaving = message.savingWords.contains(word)
        let isError  = message.errorWords.contains(word)

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
                        isError ? .red : Theme.Colors.textPrimary
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isSaved ? Theme.Colors.amieGreen.opacity(0.1) :
                isError ? Color.red.opacity(0.08) : Theme.Colors.surface
            )
            .clipShape(Capsule())
            .overlay(Capsule().stroke(
                isSaved ? Theme.Colors.amieGreen.opacity(0.4) :
                isError ? Color.red.opacity(0.3) : Theme.Colors.border,
                lineWidth: 1
            ))
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

    /// Strip [[word]] brackets from display — user sees "serendipity" not "[[serendipity]]"
    private func cleanedContent(_ text: String) -> String {
        text.replacing(/\[\[([^\]]+)\]\]/) { match in String(match.output.1) }
    }
}

// MARK: - Bubble Shape

private struct ChatBubbleShape: Shape {
    let isUser: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r: CGFloat = 16, t: CGFloat = 4
        if isUser {
            path.addRoundedRect(in: rect, cornerRadii: .init(
                topLeading: r, bottomLeading: r, bottomTrailing: t, topTrailing: r))
        } else {
            path.addRoundedRect(in: rect, cornerRadii: .init(
                topLeading: t, bottomLeading: r, bottomTrailing: r, topTrailing: r))
        }
        return path
    }
}
```

---

## Task 4: Register new files in Xcode project + wire `HomeView`

**Files:**
- Modify: `VocabApp.xcodeproj/project.pbxproj`
- Modify: `VocabApp/Features/Home/Views/HomeView.swift`

- [ ] **Step 1: Generate 7 UUIDs**

```bash
python3 -c "import secrets; [print(secrets.token_hex(12).upper()) for _ in range(7)]"
```

Assign:
- `UUID_FILEREF_VM`  → FileRef `GeneralChatViewModel.swift`
- `UUID_FILEREF_V`   → FileRef `GeneralChatView.swift`
- `UUID_BUILD_VM`    → BuildFile `GeneralChatViewModel.swift`
- `UUID_BUILD_V`     → BuildFile `GeneralChatView.swift`
- `UUID_GROUP_FEAT`  → PBXGroup `GeneralChat`
- `UUID_GROUP_VMS`   → PBXGroup `GeneralChat/ViewModels`
- `UUID_GROUP_VS`    → PBXGroup `GeneralChat/Views`

- [ ] **Step 2: Add PBXBuildFile entries** — insert before `/* End PBXBuildFile section */`:

```
		<UUID_BUILD_VM> /* GeneralChatViewModel.swift in Sources */ = {isa = PBXBuildFile; fileRef = <UUID_FILEREF_VM> /* GeneralChatViewModel.swift */; };
		<UUID_BUILD_V> /* GeneralChatView.swift in Sources */ = {isa = PBXBuildFile; fileRef = <UUID_FILEREF_V> /* GeneralChatView.swift */; };
```

- [ ] **Step 3: Add PBXFileReference entries** — insert after the first entry in `/* Begin PBXFileReference section */`:

```
		<UUID_FILEREF_VM> /* GeneralChatViewModel.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = GeneralChatViewModel.swift; sourceTree = "<group>"; };
		<UUID_FILEREF_V> /* GeneralChatView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = GeneralChatView.swift; sourceTree = "<group>"; };
```

- [ ] **Step 4: Add PBXGroup entries** — insert after the `WordChat` group block (UUID `171AD52E71295DD2D03043B7`):

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

- [ ] **Step 5: Add `GeneralChat` to the Features group** — find `39CD31C007C252F4C7B187DF /* Features */` and add `<UUID_GROUP_FEAT> /* GeneralChat */,` to its children alongside `WordChat`.

- [ ] **Step 6: Add to Sources build phase** — insert near the other `WordChat` entries:

```
				<UUID_BUILD_VM> /* GeneralChatViewModel.swift in Sources */,
				<UUID_BUILD_V> /* GeneralChatView.swift in Sources */,
```

- [ ] **Step 7: Wire `HomeView`** — add `@State private var showGeneralChat = false` after line `@State private var showReview = false`, then add a toolbar button:

```swift
ToolbarItem(placement: .topBarTrailing) {
    Button { showGeneralChat = true } label: {
        Image(systemName: "sparkles")
            .fontWeight(.semibold)
            .foregroundStyle(Theme.Colors.amieBlue)
    }
    .transition(.opacity.combined(with: .move(edge: .top)))
}
```

And a sheet after the existing `.fullScreenCover`:

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

- [ ] **Step 8: Build and verify**

```bash
xcodebuild -scheme VocabApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9: Commit**

```bash
git add VocabApp/Features/GeneralChat/ViewModels/GeneralChatViewModel.swift \
        VocabApp/Features/GeneralChat/Views/GeneralChatView.swift \
        VocabApp/Features/Home/Views/HomeView.swift \
        VocabApp.xcodeproj/project.pbxproj
git commit -m "feat: add general AI chat with Word Hunt, Vocabulary Safari, Write Better modes and vocabulary chip saving"
```

---

## Self-Review

**Spec coverage:**
- ✅ Word-specific chat reduced to 3 deep modes: Deep Dive, Challenge Me, Write With It
- ✅ Challenge Me embeds GRE question mechanics (text completion, sentence equivalence, micro-passage, contrast logic) in system prompt — adaptive difficulty, distractor explanations
- ✅ General chat: Word Hunt, Vocabulary Safari, Write Better — each genuinely distinct
- ✅ `[[word]]` syntax contract enables vocabulary chip extraction
- ✅ Word saving: lookup → save entity → add to Favorites collection
- ✅ Entry point: sparkles button in HomeView toolbar
- ✅ Quick prompts on empty state for all 6 modes
- ✅ Mode switching resets conversation

**Placeholder scan:** No TBDs. All code is complete and self-contained.

**Type consistency:**
- `GeneralChatViewModel.send()` passes `for: ""` to `aiRepository.generateContent` — intentional, general chat has no specific word
- `cleanedContent` uses Swift 5.7+ Regex literal — iOS 17+ target confirmed
- `ChatBubbleShape` in `GeneralChatView` is private and local — does not conflict with `BubbleShape` in `WordChatView` (different files, different names)
- `GeneralChatMessage.suggestedWords` is set after `isGenerating = false`, so `isStreaming` check in the view correctly hides chips until complete
