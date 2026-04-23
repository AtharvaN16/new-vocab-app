# CLAUDE.md — VocabApp iOS (SwiftUI Rewrite)

This file governs how Claude Code behaves when working on this project.

**This is a living document.** Update it whenever a new convention is established, a mistake pattern is identified, or a rule becomes outdated. Keep it lean — if a rule no longer applies, remove it. If two rules say the same thing, merge them. Never let this file bloat: every line should earn its place. Prefer one sharp rule over three vague ones.

---

## Project Overview

Native iOS vocabulary learning app built with SwiftUI + SwiftData + Supabase.
See `PRD.md` for full product specification.
Old app reference: `/Users/atharvanayak/Desktop/VocabApp` (React Native)

---

## MCP Servers

The following MCP servers are configured for this project and should be used for design-to-code tasks:

### 1. Figma Console (Southleft)
- **Purpose:** Direct interaction with the active Figma selection. Use this to get exact CSS, colors, and layout from the desktop app.
- **Tools:** `get_selection`, `get_css`, `get_document_colors`.
- **Setup:** Ensure the **Desktop Bridge** plugin is running in Figma (imported from `~/.figma-console-mcp/plugin/manifest.json`).

### 2. Official Figma MCP
- **Purpose:** File-level operations and generating canvas elements. Use this to search for frames or list project files.
- **Tools:** `get_file`, `search_files`, `create_component`.

---

## Agent Skills to Install

These skills teach Claude how to write better Swift/SwiftUI code. Install before starting:

```bash
# Paul Hudson's SwiftUI skill — prevents common SwiftUI mistakes
npx skills add https://github.com/twostraws/swiftui-agent-skill

# 79 Swift/iOS skills covering SwiftUI, SwiftData, StoreKit, on-device LLM, networking
npx skills add https://github.com/dpearson2699/swift-ios-skills
```

Most relevant skill categories for this project:
- **SwiftUI** — animations, gestures, navigation, layouts
- **Core Swift** — concurrency (async/await), SwiftData, Codable
- **App Experience** — StoreKit 2 (in-app purchases), widgets
- **AI & ML** — on-device LLM inference via MLX
- **Engineering** — networking, security, accessibility

Use `/swiftui-pro` when writing or reviewing SwiftUI views.

---

## AI Workflow Orchestration

- Always use web search whenever relevant or planning a big move to ensure latest documentation, library versions, and best practices are followed.
- Enter plan mode for non-trivial tasks (3+ architectural decisions). Write the plan, get alignment, then implement.
- Use plan mode for verification steps — don't jump straight to code on ambiguous requirements.
- Break large features into tasks using TodoWrite before starting. Complete each task fully before moving to the next.
- After each significant change, pause and ask: *"Is there a more elegant way? Would a senior Swift engineer say this is overcomplicated?"*

---

## AI Self-Improvement Loop

- After each task: update task list to reflect what's done and what's next.
- When you make a mistake or catch a pattern, write it as a rule — add it to the relevant section of this file so it doesn't happen again.
- Don't just fix bugs — identify the class of mistake and note it here.

---

## AI Verification Before Done

- For non-trivial changes: don't claim done, demonstrate it. Run the code, check the UI, verify the data flow.
- Run through relevant tests after each key change.
- Before marking a task complete, confirm: does it match the PRD spec? Does it handle the edge cases?
- Check for regressions in adjacent screens/features before reporting done.

---

## AI Task Management

- Always use TodoWrite to create and update checkable task lists.
- Keep tasks clear and atomic — one concrete action per item.
- Structure: `[ ] Feature name — specific deliverable`
- Mark tasks `in_progress` when starting, `completed` immediately when done (don't batch completions).

---

## AI Autonomy

- Give high-level summaries at decision points, not step-by-step narration of what you're doing.
- Make reasonable judgment calls without asking — only pause for genuine ambiguity or irreversible actions.
- When delegating to subagents: give them full context, don't expect them to infer from conversation history.
- Don't hand-hold — trust the architecture in the PRD and the patterns established in the codebase.

---

## AI Core Principles (from Andrej Karpathy / forrestchang)

**Think before coding**
State assumptions explicitly. If uncertain, ask. Present options and flag confusion before writing code — don't silently choose between interpretations.

**Simplicity first**
Minimal, direct solutions. No speculative features. If code exceeds reasonable length, rewrite it. Ask: *"Would a senior engineer say this is overcomplicated?"*

**Surgical changes**
When modifying existing code, preserve surrounding style. Every changed line should trace directly to the user's request. Only remove code your changes rendered obsolete.

**Goal-driven execution**
Transform vague requests into measurable outcomes with verification steps. Instead of "make it work," establish concrete success criteria.

---

## Claude Code Tips (from Boris Cherny / Claude team)

- Run multiple Claude sessions in parallel using `git worktree` for independent features.
- Start complex features with a planning phase (`/plan`) before any implementation.
- Keep this `CLAUDE.md` updated — encode conventions as you discover them.
- Create reusable slash commands for frequent workflows (e.g., `/add-screen`, `/run-tests`).
- Use subagents to distribute research — don't cram everything into one context.
- Pre-configure safe permissions in `.claude/settings.json` to reduce interruptions.

---

## Swift / SwiftUI Conventions

- Use `@Observable` (iOS 17+) — not `@ObservableObject` / `@StateObject`
- Use SwiftData for all local persistence — no UserDefaults for model data
- Use `async/await` throughout — no Combine, no callbacks
- Inject dependencies via SwiftUI `.environment()` from app root — no singletons
- Views are dumb: no business logic in View body. All logic goes in ViewModels or Use Cases.
- Name ViewModels `<FeatureName>ViewModel`, Use Cases `<Action>UseCase`

## Architecture Rules

```
Features/
  <FeatureName>/
    Views/          — SwiftUI views only
    ViewModels/     — @Observable view models
    Models/         — domain models (pure Swift structs)

Domain/
  UseCases/         — single-responsibility use cases
  Repositories/     — protocols only

Data/
  Local/            — SwiftData implementations
  Remote/           — Supabase client implementations
  Dictionary/       — API pipeline

Services/
  AIService         — MLX + OpenRouter routing
  SyncService       — SwiftData ↔ Supabase
  DictionaryService — word lookup pipeline
```

- Never import SwiftData into a View directly — go through ViewModel → UseCase → Repository
- Never call Supabase from a ViewModel — use the repository protocol

## Gesture System (Home Word Card)

Preserve these exactly — they are core UX. Mirrors the old React Native app's gesture system:
- **Swipe left/right** → Navigate words (card slides fully off-screen, new card springs in from opposite side; scale + opacity linked to drag distance)
- **Pull down** (overscroll at top) → Opens "Save to Collection" bottom sheet + circular progress indicator at top while pulling
- **Pull up** (overscroll at bottom) → Opens Search + circular progress indicator at bottom while pulling
- **Double-tap** → Favorite toggle + heart floats up from tap location with sway + "Added to favorites" message

### Pull Indicator Behaviour
Both pull indicators (bookmark ↓, search ↑) use the same visual: a frosted-glass circle with a progress ring that fills as the user pulls. Trigger threshold: 60 pt. On release before threshold: spring back, no action. On release past threshold: action fires, indicator snaps back.

## AI Integration Rules

- Every screen must work without AI — AI is enhancement only
- AI tier priority: Local LLM (MLX) → OpenRouter BYOK → No AI (graceful UI)
- Never block UI thread for AI calls — always async, show loading state
- All AI-generated content must be labeled as such and editable by the user
- AI features that require premium: show upgrade prompt, never error

## Dictionary Pipeline Rules

- Always check SwiftData cache first before any API call
- Normalize all API responses into `WordModel` before returning to domain layer
- Never expose raw API response types above the Data layer
- Cache all successful lookups with 30-day TTL

## What NOT to Do

- Don't use `@StateObject` / `@ObservedObject` — use `@Observable`
- Don't use CoreData — use SwiftData
- Don't hardcode API keys — use user-provided keys stored in Keychain
- Don't put AI calls in Views or ViewModels — route through `AIService`
- Don't show error screens for missing AI — degrade gracefully
- Don't add features not in the PRD without discussing first
