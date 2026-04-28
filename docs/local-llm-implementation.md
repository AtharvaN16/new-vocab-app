# AI Features Implementation Plan
# Local LLM + Word Editor + Word Chat + Assistant Modes

> **Resume point:** This plan was written 2026-04-28 on branch `dev`.
> All existing AI infrastructure lives in `VocabApp/Services/AIServiceCoordinator.swift`,
> `VocabApp/Data/Remote/OpenRouterService.swift`, `VocabApp/Data/Remote/MLXService.swift`,
> and `VocabApp/Domain/Repositories/AIRepository.swift`.
> The background enrichment pipeline (contextualNote auto-fill) is already wired in
> `DictionaryService.swift`. Build and run before starting — everything should be green.
>
> **Research findings (2026-04-28):**
> - Local inference backend: use **`mlx-swift-examples`** SPM package (provides `MLXLLM` library).
>   It handles model download from HuggingFace and inference. Official Apple repo. iOS + macOS.
>   SPM URL: `https://github.com/ml-explore/mlx-swift-examples` (use `MLXLLM` product).
>   Also watch: `https://github.com/ml-explore/mlx-swift-lm` (newer dedicated LLM package).
> - **LFM2-350M exists** — add as smallest tier in model catalog.
> - **LiquidAI LEAP SDK** (`docs.liquid.ai/leap/edge-sdk/ios`) is an alternative for LFM2 only.
>   It has its own download + inference. Skip for now; use MLX for all models since LFM2 has
>   MLX-format weights on HuggingFace (mlx-community).
> - **AnyLanguageModel** (github.com/mattt/AnyLanguageModel, announced Nov 2025) is a unified
>   API wrapping MLX, Core ML, llama.cpp, and cloud. Pre-1.0 — monitor but don't adopt yet.
> - **OpenRouter free models** (April 2026): Gemma 3, Llama 3.3 70B, DeepSeek R1 are free
>   (rate limited: 20 req/min, 200/day). Paid: Gemini 3.1 Flash Lite ~$0.25/$1.50 per 1M tokens.
>   Change default model from `google/gemini-pro-1.5` → `google/gemini-flash-1.5`.
> - mlx-community HuggingFace org has Qwen2.5, Gemma3, LFM2 in MLX format.

---

## Scope

Four interconnected features, buildable independently:

1. **AI Model Manager** — Local model download/select + cloud model config, unified in Settings
2. **Word Editor** — Inline editing of all word fields with per-field AI assist
3. **Word Chat** — Ephemeral chat about a specific word, with assistant modes
4. **AI Assistant Modes** — Vocabulary-specific chat personas (Explorer, Quiz, Story, Game, etc.)

Build order: **Model Manager → Word Editor → Word Chat → Assistant Modes**
Each feature is a separate PR.

---

## Part 1: AI Model Manager

### Goal
Users can download local LLM models that run fully on-device (no API key, no internet, private).
Cloud models (OpenRouter) remain available as a fallback or alternative.
`AIServiceCoordinator` automatically routes to the best available tier.

### Model Catalog

| ID | Display Name | Params | RAM | Download | Min device | mlx-community repo | Quality |
|---|---|---|---|---|---|---|---|
| `lfm2-350m` | LiquidAI LFM2 350M | 350M | 1GB+ | ~350MB | iPhone 6s / A9 | check mlx-community | Minimal |
| `qwen2.5-0.5b` | Qwen 2.5 0.5B | 500M | 2GB+ | ~500MB | iPhone 8 / A11 | `mlx-community/Qwen2.5-0.5B-Instruct-4bit` | Basic |
| `lfm2-700m` | LiquidAI LFM2 700M | 700M | 2GB+ | ~700MB | iPhone X / A12 | check mlx-community | Good |
| `gemma3-1b` | Gemma 3 1B | 1B | 4GB+ | ~1GB | iPhone 12 / A14 | `mlx-community/gemma-3-1b-it-4bit` | Better |
| `phi35-mini` | Phi-3.5 Mini | 3.8B | 6GB+ | ~2.3GB | iPhone 15 Pro / A17 | `mlx-community/Phi-3.5-mini-instruct-4bit` | Best |

> **Confirm before Task C2:** Verify exact mlx-community repo slugs at `https://huggingface.co/mlx-community`.
> LFM2 MLX weights confirmed available (LiquidAI announced day-zero MLX support).
> All inference via `MLXLLM` from `mlx-swift-examples` SPM package.
> Device RAM check: use `ProcessInfo.processInfo.physicalMemory` at runtime to grey out incompatible models.

### New Files to Create

```
VocabApp/
  Domain/
    Entities/
      LocalModelEntity.swift          — pure Swift struct for a model's metadata
    Repositories/
      LocalModelRepository.swift      — protocol: list, download, delete, activeModel
  Data/
    Local/
      LocalModelStore.swift           — UserDefaults-backed: stores downloaded state, active selection
    Remote/
      MLXModelDownloader.swift        — URLSession download task with progress; moves file to App Support
  Features/
    Settings/
      Views/
        ModelManagerView.swift        — Local / Cloud tab picker
        LocalModelListView.swift      — list of downloadable models with RAM/size badges
        CloudModelSettingsView.swift  — OpenRouter key + model picker (existing UI, moved here)
      ViewModels/
        ModelManagerViewModel.swift   — handles download state, progress, selection
```

### `LocalModelEntity.swift`

```swift
struct LocalModelEntity: Identifiable, Codable {
    let id: String              // e.g. "gemma3-1b"
    let displayName: String
    let description: String
    let parameterCount: String  // e.g. "1B"
    let ramRequiredGB: Double   // e.g. 4.0
    let downloadSizeGB: Double  // e.g. 1.0
    let minDeviceChip: String   // e.g. "A14"
    let huggingFaceRepo: String // MLX community repo slug

    var downloadSizeLabel: String { String(format: "%.0fMB", downloadSizeGB * 1024) }
    var ramLabel: String { "\(Int(ramRequiredGB))GB+" }
}
```

### `LocalModelRepository.swift`

```swift
protocol LocalModelRepository {
    func availableModels() -> [LocalModelEntity]
    func downloadedModels() -> [LocalModelEntity]
    func activeModel() -> LocalModelEntity?
    func setActiveModel(_ model: LocalModelEntity?)
    func isDownloaded(_ model: LocalModelEntity) -> Bool
    func downloadProgress(for model: LocalModelEntity) -> Double? // nil = not downloading
    func download(_ model: LocalModelEntity) async throws
    func delete(_ model: LocalModelEntity) throws
}
```

### `ModelManagerViewModel.swift`

```swift
@Observable
@MainActor
final class ModelManagerViewModel {
    enum Tab { case local, cloud }
    var selectedTab: Tab = .local
    var downloadProgress: [String: Double] = [:]  // modelId → 0.0–1.0
    var downloadError: [String: String] = [:]

    private let repository: LocalModelRepository

    var availableModels: [LocalModelEntity] { repository.availableModels() }
    var activeModel: LocalModelEntity? { repository.activeModel() }

    func isDownloaded(_ model: LocalModelEntity) -> Bool { repository.isDownloaded(model) }
    func isDownloading(_ model: LocalModelEntity) -> Bool { downloadProgress[model.id] != nil }

    func download(_ model: LocalModelEntity) {
        Task {
            downloadProgress[model.id] = 0
            do {
                try await repository.download(model)
                downloadProgress.removeValue(forKey: model.id)
            } catch {
                downloadProgress.removeValue(forKey: model.id)
                downloadError[model.id] = error.localizedDescription
            }
        }
    }

    func delete(_ model: LocalModelEntity) {
        try? repository.delete(model)
    }

    func selectActive(_ model: LocalModelEntity) {
        repository.setActiveModel(model)
    }
}
```

### `ModelManagerView.swift` — Key UI

```
┌─────────────────────────────┐
│  ← Model Manager          + │
│                             │
│  ┌──────────┬─────────────┐ │
│  │Local     │Cloud        │ │
│  └──────────┴─────────────┘ │
│                             │
│  YOUR MODELS                │
│  ┌───────────────────────┐  │
│  │ Gemma 3 1B          ✓ │  │
│  │ Google · 1B params    │  │
│  │ [4GB+] [1GB]  [Delete]│  │
│  └───────────────────────┘  │
│                             │
│  RECOMMENDED                │
│  ┌───────────────────────┐  │
│  │ LiquidAI LFM2 700M    │  │
│  │ LiquidAI · 700M       │  │
│  │ [2GB+] [700MB]   [↓]  │  │
│  └───────────────────────┘  │
│  ┌───────────────────────┐  │
│  │ Qwen 2.5 0.5B         │  │  ← "Older devices" label
│  │ Alibaba · 500M        │  │
│  │ [2GB+] [500MB]   [↓]  │  │
│  └───────────────────────┘  │
└─────────────────────────────┘
```

- Greyed-out + tooltip if device RAM too low (detect via `ProcessInfo.processInfo.physicalMemory`)
- Download shows circular progress ring in place of the `↓` button
- Tapping a downloaded model that is not active → sets as active (checkmark moves)

### `AIServiceCoordinator.swift` — Updated Routing

```swift
// New init
init(localModelRepository: LocalModelRepository, openRouterApiKey: String?) {
    // Tier 1: active local model (if downloaded)
    if let active = localModelRepository.activeModel(),
       localModelRepository.isDownloaded(active) {
        self.mlxService = MLXService(modelId: active.id)
    }
    // Tier 2: OpenRouter
    if let key = openRouterApiKey, !key.isEmpty {
        self.openRouterService = OpenRouterService(apiKey: key)
    }
}
```

### Settings Entry Point

In `ProfileView` (or wherever Settings lives), the existing "AI" section becomes:
- **Intelligence** row → navigates to `ModelManagerView`
- Active model shown as subtitle: "Gemma 3 1B · Local" or "OpenRouter · Cloud"

---

## Part 2: Word Editor (Edit with AI)

### Goal
From the expanded word card, users can edit any field manually OR ask AI to suggest improvements.
Edits persist locally via `wordRepository.saveWord()`.

### Entry Point

In `WordExpandedContentView.swift`, add an **Edit button** that appears at the top-right of the
expanded card (small pencil SF Symbol, `pencil` or `pencil.circle`). Only visible when expanded
(`isFullHeight == true` or always in the expanded state).

Tapping → presents `WordEditorView` as `.sheet` (not fullscreen — partial sheet with large detent
so the word card is visible behind it gives context).

### New Files

```
VocabApp/
  Features/
    Words/
      Views/
        WordEditorView.swift              — the edit sheet
        WordEditorFieldView.swift         — reusable editable field row
        WordEditorTagFieldView.swift      — chip-style tag editor (synonyms/antonyms)
      ViewModels/
        WordEditorViewModel.swift         — holds draft state, AI suggest calls, save
```

### `WordEditorViewModel.swift`

```swift
@Observable
@MainActor
final class WordEditorViewModel {
    // Draft state — all editable fields
    var draftPhonetic: String
    var draftDefinitions: [WordEntity.Definition]
    var draftExamples: [WordEntity.Example]
    var draftSynonyms: [String]
    var draftAntonyms: [String]
    var draftEtymology: String
    var draftContextualNote: String

    // AI suggest state
    var isSuggestingForField: WordField? = nil
    var suggestError: String? = nil

    private let original: WordEntity
    private let wordRepository: WordRepository
    private let aiRepository: AIRepository

    init(word: WordEntity, wordRepository: WordRepository, aiRepository: AIRepository) {
        self.original = word
        self.wordRepository = wordRepository
        self.aiRepository = aiRepository
        // Pre-fill draft from existing entity
        self.draftPhonetic = word.phonetic ?? ""
        self.draftDefinitions = word.definitions
        self.draftExamples = word.examples
        self.draftSynonyms = word.synonyms
        self.draftAntonyms = word.antonyms
        self.draftEtymology = word.etymology ?? ""
        self.draftContextualNote = word.contextualNote ?? ""
    }

    var hasChanges: Bool {
        draftPhonetic != (original.phonetic ?? "")
        || draftDefinitions != original.definitions
        || draftExamples != original.examples
        || draftSynonyms != original.synonyms
        || draftAntonyms != original.antonyms
        || draftEtymology != (original.etymology ?? "")
        || draftContextualNote != (original.contextualNote ?? "")
    }

    func save() async throws {
        let checker = WordQualityChecker()
        let updated = WordEntity(
            id: original.id, word: original.word,
            phonetic: draftPhonetic.isEmpty ? nil : draftPhonetic,
            definitions: draftDefinitions,
            examples: draftExamples,
            synonyms: draftSynonyms,
            antonyms: draftAntonyms,
            etymology: draftEtymology.isEmpty ? nil : draftEtymology,
            otherForms: original.otherForms,
            aiMnemonic: original.aiMnemonic,
            userNotes: original.userNotes,
            sources: original.sources,
            createdAt: original.createdAt,
            updatedAt: Date(),
            audioURL: original.audioURL,
            syllables: original.syllables,
            register: original.register,
            contextualNote: draftContextualNote.isEmpty ? nil : draftContextualNote,
            qualityScore: 0
        )
        let scored = WordEntity(/* same fields, qualityScore: checker.score(updated) */)
        try await wordRepository.saveWord(scored)
    }

    // AI suggest for a specific field — streams suggestions into the draft
    func suggestForField(_ field: WordField) async {
        isSuggestingForField = field
        defer { isSuggestingForField = nil }
        do {
            let prompt = buildSuggestPrompt(for: field)
            let stream = try await aiRepository.generateContent(for: original.word, type: .editorSuggest(field: field, prompt: prompt))
            // collect stream and apply to draft field
        } catch {
            suggestError = error.localizedDescription
        }
    }

    private func buildSuggestPrompt(for field: WordField) -> String {
        switch field {
        case .phonetic:
            return "Rewrite the pronunciation of '\(original.word)' as simple phonetics readable by a non-linguist (e.g., SEP-uh-rayt). Reply with just the phonetic string."
        case .definitions:
            return "Give 2 additional clear definitions for '\(original.word)' not already listed: \(draftDefinitions.map(\.text).joined(separator: "; ")). Format: one definition per line, starting with part of speech in parentheses."
        case .examples:
            return "Give 3 natural example sentences for '\(original.word)' — one academic, one casual, one literary. Each on its own line."
        case .synonyms:
            return "List 5 synonyms for '\(original.word)' not in this list: \(draftSynonyms.joined(separator: ", ")). Reply with comma-separated words only."
        case .antonyms:
            return "List 3 antonyms for '\(original.word)'. Reply with comma-separated words only."
        case .etymology:
            return "Give a 2-3 sentence etymology of '\(original.word)' covering its language origin and root meaning."
        case .contextualNote:
            return "Give a subtle context clue for '\(original.word)' — describe how/when it's typically used without using the word itself. 2 sentences max."
        case .audioURL:
            return "" // not AI-suggestable
        }
    }
}
```

### New `AIContentType` case needed

Add to `AIRepository.swift`:
```swift
enum AIContentType {
    case mnemonic
    case example
    case contextHint
    case editorSuggest(field: WordField, prompt: String)  // NEW
}
```

Add to `OpenRouterService.createPrompt`:
```swift
case .editorSuggest(_, let prompt):
    return prompt
```

### `WordEditorView.swift` — UI Structure

```
┌────────────────────────────────┐
│  Cancel    Edit Word    Save   │
│                                │
│  PRONUNCIATION                 │
│  [/ˈsɛp.ər.eɪt/          ] ✨ │ ← text field + AI suggest button
│                                │
│  DEFINITIONS                   │
│  1. (adj) existing apart  [x]  │
│  2. (v) to divide apart   [x]  │
│  + Add definition          ✨  │
│                                │
│  EXAMPLES                      │
│  "The two..." [x]              │
│  + Add example             ✨  │
│                                │
│  SYNONYMS                      │
│  [distinct] [apart] [+]    ✨  │
│                                │
│  ANTONYMS                      │
│  [joined] [+]              ✨  │
│                                │
│  ETYMOLOGY                     │
│  [Latin separatus...      ] ✨  │
│                                │
│  CONTEXT NOTE                  │
│  [Used to describe...     ] ✨  │
└────────────────────────────────┘
```

- `✨` button triggers `viewModel.suggestForField(_:)`
- While AI is generating for a field, the `✨` button shows a spinner, result appends to draft
- Definitions and examples: list with swipe-to-delete; `+` button adds a blank row for typing
- Synonyms/Antonyms: horizontal chip layout; tap chip to delete; `+` opens a small text input
- Save button is disabled if `!hasChanges` and enabled (highlighted) when changes exist
- "Improve All" button at the very bottom: calls suggest for all nil/thin fields in sequence

### How `WordExpandedContentView` launches the editor

```swift
// Add to WordExpandedContentView
@Environment(\.appEnvironment) private var appEnvironment
@State private var showEditor = false

// In body, overlay or toolbar:
Button { showEditor = true } label: {
    Image(systemName: "pencil.circle")
        .font(.system(size: 20, weight: .medium))
        .foregroundColor(Theme.Colors.textSecondary)
}
.sheet(isPresented: $showEditor) {
    if let env = appEnvironment {
        WordEditorView(
            viewModel: WordEditorViewModel(
                word: word,
                wordRepository: env.wordRepository,
                aiRepository: env.aiRepository
            )
        )
    }
}
```

### Caveat: `WordExpandedContentView` currently has no `@Environment`

The view is used both from `HomeView` (as a card) and potentially from collection detail.
It currently takes `word: WordEntity` as a `let`. To add the editor, it either needs
`@Environment(\.appEnvironment)` injected (requires the view hierarchy to have it, which it does
via `ContentView`) or a callback closure `onEdit: ((WordEntity) -> Void)?` passed from the parent.
**Recommended: add `@Environment(\.appEnvironment)` directly** — it's already set at the root.

---

## Part 3: Word Chat

### Goal
User can open a chat conversation about the current word. AI is pre-seeded with the word's context.
Multiple assistant modes (personas) change how the AI responds.
Chat is ephemeral (no persistence between sessions). User can save useful AI messages back to the word.

### New Files

```
VocabApp/
  Features/
    WordChat/
      Views/
        WordChatView.swift              — full-screen chat sheet
        WordChatBubble.swift            — individual message bubble
        AssistantModePickerView.swift   — horizontal scrolling mode selector
      ViewModels/
        WordChatViewModel.swift         — message list, streaming, mode selection, save-back
  Domain/
    Entities/
      ChatMessage.swift                 — id, role (user/assistant), content, timestamp
      AssistantMode.swift               — enum of all modes with name, icon, systemPrompt
```

### `AssistantMode.swift`

```swift
enum AssistantMode: String, CaseIterable, Identifiable {
    case wordExplorer
    case etymologyNerd
    case usageCoach
    case storyteller
    case wordGame
    case quizmaster
    case poetryMode
    case grammarGuru

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wordExplorer:  return "Word Explorer"
        case .etymologyNerd: return "Etymology"
        case .usageCoach:    return "Usage Coach"
        case .storyteller:   return "Storyteller"
        case .wordGame:      return "Word Game"
        case .quizmaster:    return "Quiz Me"
        case .poetryMode:    return "Poetry"
        case .grammarGuru:   return "Grammar"
        }
    }

    var icon: String {
        switch self {
        case .wordExplorer:  return "magnifyingglass"
        case .etymologyNerd: return "scroll"
        case .usageCoach:    return "person.wave.2"
        case .storyteller:   return "book"
        case .wordGame:      return "gamecontroller"
        case .quizmaster:    return "questionmark.circle"
        case .poetryMode:    return "pencil.and.outline"
        case .grammarGuru:   return "checkmark.seal"
        }
    }

    func systemPrompt(for word: WordEntity) -> String {
        let definitions = word.definitions.prefix(3).map(\.text).joined(separator: "; ")
        let etymology = word.etymology ?? "unknown"
        let base = "The user is studying the word '\(word.word)'. Definitions: \(definitions). Etymology: \(etymology)."
        switch self {
        case .wordExplorer:
            return "\(base) You are a helpful vocabulary tutor. Answer any questions about this word clearly and concisely."
        case .etymologyNerd:
            return "\(base) You are obsessed with word history. Dive deep into roots, cognates in other languages, and historical usage. Keep answers under 3 sentences."
        case .usageCoach:
            return "\(base) You are a usage coach. Explain when and how to use this word correctly — formal vs casual, British vs American, register, common mistakes. Give concrete examples."
        case .storyteller:
            return "\(base) You create short 3-5 sentence stories that use the word '\(word.word)' naturally in context. Each story should be in a different setting. Do not explain — just tell the story."
        case .wordGame:
            return "\(base) You run vocabulary games. First ask the user which game they want: (1) Definition Guess — you describe a concept and they guess the word, (2) Fill-in-blank — you give a sentence with a blank, (3) Word Association — you say a word and they say what it reminds them of. Keep it fun and brief."
        case .quizmaster:
            return "\(base) You quiz the user on this word. Ask one question at a time: definition, usage, synonym, antonym, or fill-in-the-blank. Give encouraging feedback. Vary question types."
        case .poetryMode:
            return "\(base) You write short poems (haiku, limerick, or 4-line verse) that use '\(word.word)' to help the user remember it. After each poem, ask if they'd like a different style."
        case .grammarGuru:
            return "\(base) You explain the grammatical properties of this word: parts of speech, conjugation/inflection if applicable, which prepositions it takes, common grammatical mistakes people make with it."
        }
    }
}
```

### `WordChatViewModel.swift`

```swift
@Observable
@MainActor
final class WordChatViewModel {
    struct Message: Identifiable {
        enum Role { case user, assistant }
        let id = UUID()
        let role: Role
        var content: String      // var because streaming updates it in place
        let timestamp: Date
    }

    var messages: [Message] = []
    var inputText: String = ""
    var isGenerating: Bool = false
    var selectedMode: AssistantMode = .wordExplorer
    var saveConfirmation: String? = nil  // brief toast after save-back

    private let word: WordEntity
    private let aiRepository: AIRepository
    private let wordRepository: WordRepository

    // Quick prompts shown before first user message
    var quickPrompts: [String] {
        switch selectedMode {
        case .wordExplorer: return ["How do I use this?", "Formal vs casual?", "Common mistakes?"]
        case .etymologyNerd: return ["What's the origin?", "Any cognates?", "When did this appear?"]
        case .usageCoach: return ["Give me a formal example", "Casual usage?", "What to avoid?"]
        case .storyteller: return ["Tell me a story", "Business context", "Casual conversation"]
        case .wordGame: return ["Let's play!", "Definition game", "Fill-in-blank"]
        case .quizmaster: return ["Quiz me!", "Give a hint", "New question"]
        case .poetryMode: return ["Write a haiku", "Write a limerick", "4-line verse"]
        case .grammarGuru: return ["What part of speech?", "How to conjugate?", "Common errors?"]
        }
    }

    var showQuickPrompts: Bool { messages.isEmpty }

    func send(text: String? = nil) async {
        let content = (text ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !isGenerating else { return }
        inputText = ""
        messages.append(Message(role: .user, content: content, timestamp: Date()))
        isGenerating = true
        defer { isGenerating = false }

        // Append empty assistant message for streaming into
        let assistantIndex = messages.count
        messages.append(Message(role: .assistant, content: "", timestamp: Date()))

        do {
            let fullPrompt = buildFullPrompt(userMessage: content)
            let stream = try await aiRepository.generateContent(for: word.word, type: .chat(systemPrompt: selectedMode.systemPrompt(for: word), userMessage: fullPrompt))
            for try await chunk in stream {
                messages[assistantIndex].content += chunk
            }
        } catch {
            messages[assistantIndex].content = "Sorry, I couldn't generate a response. Check your AI configuration in Settings."
        }
    }

    func saveMessage(_ message: Message, as field: SaveTarget) async {
        // SaveTarget: enum { case note, example, mnemonic }
        // Build updated WordEntity with the message content appended to the target field
        // Call wordRepository.saveWord(updated)
        saveConfirmation = "Saved as \(field.displayName)"
        try? await Task.sleep(for: .seconds(2))
        saveConfirmation = nil
    }

    func switchMode(_ mode: AssistantMode) {
        selectedMode = mode
        messages = []  // reset conversation when mode changes
    }

    private func buildFullPrompt(userMessage: String) -> String {
        // Include last 6 messages as context (no full history to keep local models fast)
        let history = messages.dropLast(2).suffix(6)  // exclude the new user + empty assistant
            .map { "\($0.role == .user ? "User" : "Assistant"): \($0.content)" }
            .joined(separator: "\n")
        return history.isEmpty ? userMessage : "\(history)\nUser: \(userMessage)"
    }
}
```

### New `AIContentType` case needed

```swift
enum AIContentType {
    case mnemonic
    case example
    case contextHint
    case editorSuggest(field: WordField, prompt: String)
    case chat(systemPrompt: String, userMessage: String)   // NEW
}
```

In `OpenRouterService`, the `chat` case sends a multi-message body:
```swift
case .chat(let systemPrompt, let userMessage):
    // body["messages"] = [["role": "system", "content": systemPrompt], ["role": "user", "content": userMessage]]
```

### `WordChatView.swift` — UI Structure

```
┌──────────────────────────────────┐
│  ✕               [Word Explorer] │ ← mode picker (tappable label)
│                                  │
│  ← Assistant mode pills:         │
│  [Explorer] [Etymology] [Quiz].. │ ← horizontal scroll, shown always at top
│                                  │
│  ┌──────────────────────────┐    │
│  │ "separate" · Word Explorer│   │ ← context header (word name + mode)
│  └──────────────────────────┘    │
│                                  │
│  Quick prompts (if no messages): │
│  [How do I use this?]            │
│  [Formal vs casual?]             │
│  [Common mistakes?]              │
│                                  │
│  [user bubble: "how to use?"]    │
│  [AI bubble: streaming text...]  │
│                                  │
│  ────────────────────────────    │
│  [     Type a message...    ] → │ ← input bar, send on tap
└──────────────────────────────────┘
```

**Long-press AI message** → action sheet:
- "Save as Note" → appends to `userNotes`
- "Save as Example" → appends to `examples` with `isAIGenerated: true`
- "Save as Mnemonic" → sets `aiMnemonic`
- "Copy"

**Mode switching:** Tapping a mode pill resets the conversation and inserts a mode-change message
in the chat: "Switched to Etymology mode. Ask me about the origins of this word."

### Entry Point

In `WordExpandedContentView`, add a second button alongside the pencil:

```swift
Button { showChat = true } label: {
    Image(systemName: "bubble.left.and.bubble.right")
        .font(.system(size: 18, weight: .medium))
        .foregroundColor(Theme.Colors.textSecondary)
}
.sheet(isPresented: $showChat) {
    WordChatView(viewModel: WordChatViewModel(
        word: word,
        aiRepository: env.aiRepository,
        wordRepository: env.wordRepository
    ))
}
```

---

## Part 4: OpenRouter Model Default (Quick Fix)

**Current:** `OpenRouterService` hardcodes `"google/gemini-pro-1.5"` which is slow and expensive for short prompts.

**Fix:** Change default to `"google/gemini-flash-1.5"` for all task types except `.chat` where the user might want a smarter model.

In `OpenRouterService.swift`:
```swift
private func modelId(for type: AIContentType) -> String {
    switch type {
    case .chat: return "google/gemini-flash-1.5"      // good enough, fast
    default:    return "google/gemini-flash-1.5"       // background enrichment, keep cheap
    }
}
```

Eventually: expose model selection in the Cloud tab of Model Manager.

---

## Implementation Sequence (Task by Task)

### Phase A — Foundation (do first, unblocks everything)

**Task A1:** Update `AIContentType` in `AIRepository.swift` to add `.editorSuggest` and `.chat`.
Update `OpenRouterService.createPrompt` to handle them.
Update `OpenRouterService` default model to `gemini-flash-1.5`.
Commit: `feat: expand AIContentType for editor and chat, update default model`

**Task A2:** Create `LocalModelEntity.swift` and `LocalModelRepository.swift` (protocol + simple
UserDefaults-backed `LocalModelStore.swift`). No download yet — just the catalog and selection state.
Commit: `feat: add LocalModelEntity and LocalModelRepository protocol`

### Phase B — Word Editor

**Task B1:** Create `WordEditorViewModel.swift` with draft state and save logic (no AI yet).
Write unit tests: draft matches original on init, `hasChanges` works, save builds correct entity.
Commit: `feat: WordEditorViewModel with draft state and save`

**Task B2:** Create `WordEditorView.swift` with all editable fields, manual add/delete.
No AI suggest yet. Wire pencil button in `WordExpandedContentView`.
Test: open sheet, edit a definition, save, verify the word card updates.
Commit: `feat: WordEditorView with manual field editing`

**Task B3:** Add `suggestForField(_:)` to `WordEditorViewModel`. Wire `✨` buttons in the view.
Test with OpenRouter key configured.
Commit: `feat: AI suggest per field in WordEditorView`

### Phase C — Model Manager UI

**Task C1:** Create `ModelManagerViewModel.swift` backed by `LocalModelStore`.
Create `ModelManagerView.swift` with Local/Cloud tabs. Local tab shows catalog with badges.
Cloud tab: move existing OpenRouter key input here from wherever it currently lives.
No real download yet — download button shows "Coming soon" or is disabled.
Commit: `feat: ModelManagerView with local/cloud tabs`

**Task C2:** Implement `MLXModelDownloader.swift` — download GGUF/MLX weights from HuggingFace
to `Application Support`, report progress via `AsyncStream<Double, Error>`.
Wire download buttons in `ModelManagerView`.
Commit: `feat: MLX model download with progress`

**Task C3:** Wire `MLXService` to use the downloaded model path. Update `AIServiceCoordinator`
to use local tier first. Test with a downloaded model.
Commit: `feat: wire local MLX inference tier in AIServiceCoordinator`

### Phase D — Word Chat

**Task D1:** Create `ChatMessage` and `AssistantMode`. Create `WordChatViewModel` with
`send()` and mode switching. Unit test: messages append, mode switch resets history.
Commit: `feat: WordChatViewModel with assistant modes`

**Task D2:** Create `WordChatView` — message bubbles, input bar, quick prompts, mode picker pills.
Wire chat button in `WordExpandedContentView`. Test streaming.
Commit: `feat: WordChatView with streaming and assistant modes`

**Task D3:** Add long-press save-back action (Save as Note / Example / Mnemonic).
Commit: `feat: save AI chat messages back to word entity`

---

## Files Modified (existing)

| File | Change |
|---|---|
| `VocabApp/Domain/Repositories/AIRepository.swift` | Add `.editorSuggest` and `.chat` to `AIContentType` |
| `VocabApp/Data/Remote/OpenRouterService.swift` | Handle new cases, change default model |
| `VocabApp/Services/AIServiceCoordinator.swift` | Accept `LocalModelRepository`, route local first |
| `VocabApp/Services/AppEnvironment.swift` | Init `LocalModelStore`, pass to `AIServiceCoordinator` |
| `VocabApp/Features/Words/Views/WordExpandedContentView.swift` | Add pencil + chat buttons, sheets |

---

## Open Questions (resolve before Task C2)

1. **MLX Swift package version** — confirm `swift-mlx` / `mlx-swift-examples` are available
   via SPM and can be added without breaking existing build. Check `Package.swift` or `project.pbxproj`.
2. **Model weights format** — confirm HuggingFace MLX Community has `.mlx` packages for
   Qwen 2.5 0.5B, LFM2 700M, Gemma 3 1B. URL pattern: `https://huggingface.co/mlx-community/<model>`.
3. **App size budget** — App Store has a 4GB app size limit and a 200MB cellular download limit.
   Model weights are stored in Application Support (not the .ipa), downloaded post-install.
   Confirm the download/storage approach doesn't break App Store guidelines.
4. **`WordExpandedContentView` dependency** — currently receives `word: WordEntity` as a let.
   To support live updates after editing, the parent (`HomeViewModel`) needs to reload the
   current word after the editor sheet dismisses. Add `onSave: ((WordEntity) -> Void)?` callback
   or have `HomeViewModel` call `refreshCollections()` on sheet dismiss.

---

## Estimated Effort

| Feature | Complexity | Days |
|---|---|---|
| A: Foundation (AIContentType + LocalModelRepository) | Small | 0.5 |
| B: Word Editor | Medium | 2 |
| C: Model Manager + MLX download + inference | Large | 4-5 |
| D: Word Chat | Medium | 2-3 |
| **Total** | | **~10 days** |
