# GEMINI.md — VocabApp iOS (SwiftUI Rewrite)

This file governs how Gemini CLI behaves when working on this project. It takes precedence over general defaults.

---

## Project Overview

Native iOS vocabulary learning app built with SwiftUI + SwiftData + Supabase.
- **Reference:** See `PRD.md` for full product specification.
- **Legacy Reference:** `/Users/atharvanayak/Desktop/VocabApp` (React Native)

---

## MCP Servers

The following MCP servers are configured for this project:

### 1. Figma Console (Southleft)
- **Purpose:** Real-time design system extraction and selection tracking from the Figma Desktop app.
- **Tools:** `get_selection`, `get_document_colors`, `get_css`, etc.
- **Requirement:** Must have the "Desktop Bridge" plugin running in Figma.
- **Plugin Path:** `/Users/atharvanayak/.figma-console-mcp/plugin/manifest.json`

### 2. Official Figma MCP
- **Purpose:** High-level file management, searching, and writing to the canvas.
- **Tools:** `get_file`, `search_files`, `create_frame`, etc.
- **Auth:** Uses OAuth (user will be prompted on first use).

---

## Engineering Standards & Workflow

### Development Lifecycle
- **Research:** Always investigate existing patterns in `Features/` before implementing new ones. Use `web_search` whenever relevant or planning a big move to stay updated on latest documentation and best practices.
- **Strategy:** For non-trivial tasks (3+ architectural decisions), use `enter_plan_mode` to draft a strategy and get alignment.
- **Execution:** Follow the **Plan -> Act -> Validate** cycle.
- **Verification:** Never claim a task is done without verifying the data flow and UI behavior. Run relevant tests after each key change.

### Swift / SwiftUI Conventions
- **State Management:** Use `@Observable` (iOS 17+) — **NEVER** use `@ObservableObject`, `@StateObject`, or `@ObservedObject`.
- **Persistence:** Use **SwiftData** for all local persistence — no `UserDefaults` for model data, no `CoreData`.
- **Concurrency:** Use `async/await` throughout — no `Combine`, no callbacks.
- **Dependency Injection:** Inject dependencies via SwiftUI `.environment()` from the app root — no singletons.
- **Logic Separation:** Views must remain "dumb" (no business logic). Use `ViewModels` (`@Observable`) and `UseCases`.
- **Naming:** 
    - ViewModels: `<FeatureName>ViewModel`
    - Use Cases: `<Action>UseCase`

### Architecture Rules
Maintain the following directory structure:
- `Features/<FeatureName>/`: `Views/`, `ViewModels/`, `Models/` (pure Swift structs).
- `Domain/`: `UseCases/` (single-responsibility), `Repositories/` (protocols only).
- `Data/`: `Local/` (SwiftData), `Remote/` (Supabase), `Dictionary/` (API pipeline).
- `Services/`: `AIService` (MLX + OpenRouter), `SyncService`, `DictionaryService`.

**Access Control:**
- Never import `SwiftData` into a View directly — go through `ViewModel` -> `UseCase` -> `Repository`.
- Never call `Supabase` from a ViewModel — use the repository protocol.

---

## Feature-Specific Mandates

### Gesture System (Word Detail Sheet)
These core UX behaviors must be preserved exactly:
- **Swipe up:** Add to Collection Sheet.
- **Swipe down:** Bookmark toggle + haptic.
- **Double-tap:** Favorite toggle + heart animation + haptic.
- **Swipe left/right:** Navigate words in current collection context.

### AI Integration Rules
- **Graceful Degradation:** Every screen must work without AI.
- **Tier Priority:** Local LLM (MLX) -> OpenRouter BYOK -> No AI (graceful UI).
- **Asynchronous:** Never block the UI thread for AI calls.
- **Labeling:** All AI-generated content must be labeled and editable.
- **Premium:** Show upgrade prompts for premium AI features instead of failing.

### Dictionary Pipeline Rules
- **Cache-First:** Always check SwiftData cache before any API call.
- **Normalization:** Normalize all API responses into `WordModel` in the Data layer.
- **Isolation:** Never expose raw API response types above the Data layer.
- **TTL:** Cache all successful lookups with a 30-day TTL.

---

## Critical "Don'ts"
- **Don't** use deprecated state wrappers (`@StateObject`, etc.).
- **Don't** use `CoreData`.
- **Don't** hardcode API keys — use Keychain for user-provided keys.
- **Don't** put AI logic in Views or ViewModels — route through `AIService`.
- **Don't** add features outside the `PRD.md` scope without confirmation.
