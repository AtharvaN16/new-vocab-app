# GEMINI.md — VocabApp iOS (SwiftUI Rewrite)

This file governs how Gemini CLI behaves when working on this project.

**Edits to this file:** **Only** **## Project Overview** may be updated — to keep the one-line description, `PRD.md` pointer, and reference paths accurate. **Do not** add to, remove, reword, or “save learnings” in any other section; everything from **## Agent Skills to Install** to the end is **fixed AI and coding instruction** and must be left unchanged unless the user explicitly requests a change to it.

---

## Project Overview

Native iOS vocabulary learning app built with SwiftUI + SwiftData + Supabase.  
See `PRD.md` for full product specification, reference app path, and stack rationale.  
Old app reference: `/Users/atharvanayak/Desktop/VocabApp` (React Native)

---

## Agent Skills to Install

These skills help write better Swift/SwiftUI code. Install before starting:

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

Use `/swiftui-pro` when writing or reviewing SwiftUI views when available in your environment.

---

## AI Workflow Orchestration

- Always use web search whenever relevant or planning a big move to ensure latest documentation, library versions, and best practices are followed.
- For non-trivial tasks (3+ architectural decisions), use plan mode (`enter_plan_mode` or equivalent) — write the plan, get alignment, then implement.
- Use plan mode for verification steps — do not jump straight to code on ambiguous requirements.
- Break large features into tasks using todo lists before starting. Complete each task fully before moving to the next.
- After each significant change, pause and ask: *"Is there a more elegant way? Would a senior Swift engineer say this is overcomplicated?"*

---

## AI Self-Improvement Loop

- After each task: update the **session task list** in the tool to reflect what is done and what is next — not this file.
- **Do not** edit `GEMINI.md` to log patterns or new rules. Fix the code; learn in-session. If something must be written down, use `PRD.md`, a comment, or ask the user before changing this file.
- Do not just fix bugs — identify the class of mistake so you do not repeat it; that reflection stays in the session unless the user asks to document it elsewhere.

---

## AI Verification Before Done

- For non-trivial changes: do not claim done, demonstrate it. Run the code, check the UI, verify the data flow.
- Run through relevant tests after each key change.
- Before marking a task complete, confirm: does it match the PRD spec? Does it handle the edge cases?
- Check for regressions in adjacent screens or features before reporting done.

---

## AI Task Management

- Always use a checkable task list to create and update work items.
- Keep tasks clear and atomic — one concrete action per item.
- Structure: `[ ] Feature name — specific deliverable`
- Mark tasks in progress when starting, completed immediately when done (do not batch completions).

---

## AI Autonomy

- Give high-level summaries at decision points, not step-by-step narration of every action.
- Make reasonable judgment calls without asking — only pause for genuine ambiguity or irreversible actions.
- When delegating to other agents: give them full context, do not expect them to infer from conversation history.
- Do not hand-hold — trust the architecture in the PRD and the patterns established in the codebase.

---

## AI Core Principles (from Andrej Karpathy / forrestchang)

**Think before coding**
State assumptions explicitly. If uncertain, ask. Present options and flag confusion before writing code — do not silently choose between interpretations.

**Simplicity first**
Minimal, direct solutions. No speculative features. If code exceeds reasonable length, rewrite it. Ask: *"Would a senior engineer say this is overcomplicated?"*

**Surgical changes**
When modifying existing code, preserve surrounding style. Every changed line should trace directly to the user request. Only remove code your changes rendered obsolete.

**Goal-driven execution**
Transform vague requests into measurable outcomes with verification steps. Instead of "make it work," establish concrete success criteria.

---

## CLI Tips (parallel work and hygiene)

- Run multiple sessions in parallel using `git worktree` for independent features.
- Start complex features with a planning phase before any implementation.
- If **## Project Overview** is out of date (paths, one-line blurb), update **that section only** — never add ad hoc conventions to the rest of this file without a user request.
- Create reusable commands or prompts for frequent workflows (e.g. add-screen, run-tests).
- Use separate research passes — do not cram everything into one context.

---

## Swift / SwiftUI Conventions

- Use `@Observable` (iOS 17+) — not `@ObservableObject` / `@StateObject`
- Use SwiftData for all local persistence — no UserDefaults for model data
- Use `async/await` throughout — no Combine, no callbacks
- Inject dependencies via SwiftUI `.environment()` from app root — no singletons
- Views are dumb: no business logic in View `body`. All logic goes in ViewModels or Use Cases.
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

Preserve these exactly — they are core UX. Mirrors the old React Native app gesture system:
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

- Do not use `@StateObject` / `@ObservedObject` — use `@Observable`
- Do not use CoreData — use SwiftData
- Do not hardcode API keys — use user-provided keys stored in Keychain
- Do not put AI calls in Views or ViewModels — route through `AIService`
- Do not show error screens for missing AI — degrade gracefully
- Do not add features not in the PRD without discussing first
