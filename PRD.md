# VocabApp — Native iOS Rewrite PRD

## Reference

**Agent coding rules (keep in sync)**: `CLAUDE.md` and `GEMINI.md` — day-to-day Swift/SwiftUI conventions, architecture boundaries, and implementation-level UX (e.g. Home word card gestures). This PRD is product vision, screens, and stack; if a detail lives only in those files, follow it for implementation.

**Old App (React Native)**: `/Users/atharvanayak/Desktop/VocabApp`
- Full codebase of the original app — use as reference for existing features, data models, gestures, and AI integration patterns
- Key files: `src/features/`, `src/services/`, `src/models/`, `App.tsx`

---

## Context

The original VocabApp (see reference above) was a React Native vocabulary learning app that grew organically without upfront architecture planning. Core problems: AI features were shoehorned in late, dictionary APIs were not cohesively designed, and the UI was an afterthought. The user wants to rebuild this as a native SwiftUI app with proper architecture from day one — particularly around AI strategy, search/data pipeline, and a playful design language (inspired by Amie Calendar and Capwords).

---

## 1. Product Vision

**What it is**: A vocabulary builder for curious people who want to grow their word bank — not just test-prep students. You encounter a word, look it up, add it, and the app makes sure you actually remember it.

**Core promise**: *Your words, remembered* — gesture-driven word capture, AI-enhanced enrichment, and science-backed spaced repetition, all in a delightful native UI.

**Target audience**: General vocabulary builders — readers, writers, learners, non-native English speakers, and casual GRE-preppers alike.

**Monetization**: Free core (search, add words, SRS, collections). Premium unlocks: unlimited AI enrichment, advanced analytics, cloud sync, and multi-device support.

---

## 2. Tech Stack

| Layer | Choice | Reason |
|-------|--------|--------|
| UI | **SwiftUI** | Native, best animations, best integration with iOS system features |
| Local storage | **SwiftData** | Swift-first ORM (iOS 17+), clean model definitions, automatic migrations |
| Backend/auth | **Supabase** | Postgres-backed, auth + real-time + storage, open-source, generous free tier |
| Cloud sync | Supabase (REST + Realtime) | Sync SwiftData local state to Supabase on login |
| SRS | **FSRS Swift port** | Same scientifically-grounded algorithm as old app, ported to Swift |
| Local AI | **MLX Swift** | Apple's own ML framework, optimized for Apple Silicon (iPhone 15 Pro+) |
| Cloud AI | **OpenRouter** (BYOK) | One API key, access to GPT-4o, Claude, Gemini, Llama — user chooses |
| Dictionary | Multi-tier API pipeline (see below) | Resilient, offline-capable, normalized data model |

---

## 3. Local LLM Recommendation

**Model**: `Phi-3.5-mini-instruct` via MLX Swift
- Size: ~2.2 GB (4-bit quantized)
- Runs well on: iPhone 15 Pro and later (A17 Pro+)
- Strengths: Excellent instruction following, great for short generative tasks (definitions, examples, mnemonics)

**Fallback for older devices**: `Gemma-2B-instruct` via MLX
- Size: ~1.3 GB
- Runs on: iPhone 12+ (reasonable performance)

**No local LLM on older devices**: Gracefully degrades to OpenRouter BYOK or disables AI features. Never error-gates core features.

**Framework**: `mlx-swift` (github.com/ml-explore/mlx-swift) — Apple's official library.

---

## 4. AI Strategy (Built-In, Not Shoehorned)

### Guiding principle
AI is an *enhancement layer*, not a core dependency. Every screen works without AI. AI makes things better when available.

### AI Tier System
```
Tier 1: Local LLM (MLX Swift — Phi-3.5-mini or Gemma-2B)
  → Private, offline, no cost, limited quality

Tier 2: OpenRouter BYOK (user's own API key)
  → Best quality, cloud-dependent, user-controlled model choice

Tier 3: No AI
  → Core features still work, AI surfaces show "Add API key" prompt
```

### Where AI is integrated (by design, not bolted on)

**A. Word Enrichment** — triggered when a word is added from search
- Generate: mnemonic memory hook, alternative definition, vivid example sentence
- Stored alongside the word, editable by user
- Runs in background after word is saved; result shows as a notification-style card

**B. Mnemonic Generation** — dedicated AI feature per word
- "How to remember this word" — etymology-based trick, visual association, story
- Displayed in word detail screen, collapsible

**C. Practice Hints** — during SRS review, if user taps "Give me a hint"
- AI generates a context clue without giving away the full definition
- Uses the word's stored mnemonic if available first, AI as fallback

**D. Smart Example Generation** — in word detail, user can request "More examples"
- Generates examples in different domains: academic, casual conversation, literature
- Each example saved as a user-owned example (editable, deletable)

**E. AI-powered search query** — in search screen
- If user types a description ("a word for feeling happy but melancholy at same time")
- AI returns candidate words; user taps to look them up via dictionary API
- Clearly labeled as "AI suggestion" with confidence indicator

### What is NOT AI-powered
- SRS scheduling (pure FSRS algorithm)
- Dictionary lookup (real API data)
- Search (dictionary API + local index)
- Core navigation and gestures

---

## 5. Dictionary & Search Pipeline (Well-Thought-Out)

### The problem with the old app
- 3 APIs with unclear priority and no unified model
- API keys hardcoded
- Cache was per-API, not per-word
- No clear offline strategy

### New unified pipeline

**Word Lookup Flow**:
```
User searches word
  → 1. Check SwiftData local cache (instant, offline)
  → 2. Free Dictionary API (primary, no key)
  → 3. Wiktionary API (fallback, richer etymologies)
  → 4. Wordnik API (optional — user adds key in settings)
  → All results normalized into single WordModel
  → Saved to SwiftData cache with timestamp
  → Word shown to user
```

**Normalized WordModel** (single source of truth):
```swift
struct WordModel {
    let word: String
    let definitions: [Definition]     // [{text, partOfSpeech, source}]
    let examples: [Example]           // [{text, source, isAIGenerated}]
    let synonyms: [String]
    let antonyms: [String]
    let phonetic: String?
    let etymology: String?
    let otherForms: [WordForm]
    let sources: [DataSource]         // which APIs contributed data
    let cachedAt: Date
}
```

**Search Modes**:
1. **Direct lookup**: Type a word → dictionary APIs → normalized result
2. **AI assisted**: Describe a concept → AI returns word suggestions → tap to look up via API
3. **Local search**: Search within your saved words (fully offline)

**Caching strategy**:
- All looked-up words cached in SwiftData with 30-day TTL
- User's saved words: never expire
- API responses merged (Free Dictionary + Wiktionary combined, deduped)

---

## 6. Core App Architecture

### Pattern: Clean Architecture + MVVM

```
Presentation Layer (SwiftUI)
  Views — pure UI, no business logic
  ViewModels — @Observable, coordinates use cases

Domain Layer
  Use Cases — single-responsibility (AddWord, ReviewCard, EnrichWord, etc.)
  Domain Models — pure Swift structs, no framework imports
  Repository Protocols — interfaces the data layer implements

Data Layer
  LocalRepository — SwiftData
  RemoteRepository — Supabase client
  DictionaryRepository — API pipeline
  AIRepository — MLX + OpenRouter
```

### Key services

| Service | Responsibility |
|---------|---------------|
| `WordService` | Search, add, update, delete words |
| `CollectionService` | CRUD collections, reordering |
| `SRSService` | FSRS scheduling, due cards, stats |
| `PracticeSessionService` | Manages an active review session |
| `DictionaryService` | Unified API pipeline, caching |
| `AIService` | Routes to local or OpenRouter tier |
| `SyncService` | Bidirectional SwiftData ↔ Supabase sync |
| `SubscriptionService` | StoreKit 2 for premium features |

### Dependency injection
Single `AppEnvironment` object at app root, injected via SwiftUI environment — no singletons.

---

## 7. V1 Screen Inventory

### Old App → New App Mapping

| Old App Screen | Status | New App Equivalent |
|---|---|---|
| LoginScreen | Keep | Login Screen |
| SignupScreen | Keep | Signup Screen |
| AuthGate | Keep | AuthGate (redirect logic) |
| WordDetailScreen (main) | Redesign | Word Detail Sheet (from multiple entry points) |
| CollectionsMenu (side slide) | Replace | Library Tab (persistent tab bar) |
| CollectionDetailScreen | Keep | Collection Detail Screen |
| BookmarkModal | Keep + rename | Add to Collection Sheet |
| MoveToModal | Keep | Move Words Sheet |
| NewCollectionModal | Keep | Create/Edit Collection Modal |
| PracticeScreen | Keep | Practice Session Screen |
| ReviewAllScreen | Merge | Pre-session summary inside Collection Detail |
| SearchScreen | Redesign | Discover Tab |
| SettingsScreen | Split | Settings Tab + Profile section |
| AIChatScreen | **Cut from v1** | v2 — AI chat standalone |
| AIChatModal | **Cut (unused)** | — |
| *(missing)* | **New** | Onboarding Flow |
| *(missing)* | **New** | Home / Today Tab |

---

### V1 Navigation Map

```
App Launch
  └─ First time → Onboarding (3 steps, skippable)
  └─ Not logged in → Auth Flow
       ├─ Login Screen
       └─ Signup Screen
  └─ Logged in / Guest → Main App (Tab Bar)

Tab Bar (4 tabs)
  ├─ Home (Today)
  ├─ Library (Collections)
  ├─ Discover (Search)
  └─ Profile / Settings

Home Tab
  ├─ "Start Review" CTA → Practice Session (all due cards)
  ├─ Word card tap → Word Detail Sheet
  └─ Quick search → Discover Tab

Library Tab (Collection List)
  ├─ Collection card tap → Collection Detail Screen
  │    ├─ Word row tap → Word Detail Sheet
  │    ├─ "Smart Review" → Practice Session (SRS due only)
  │    ├─ "Practice All" → Practice Session (all words)
  │    ├─ Bulk select mode → Move Words Sheet
  │    └─ Edit collection → Create/Edit Collection Modal
  └─ "+" button → Create/Edit Collection Modal

Discover Tab (Search)
  ├─ Type word → dictionary API results
  ├─ Result tap → Word Detail Sheet
  └─ "Describe it" toggle → AI semantic search mode (if AI enabled)

Profile/Settings Tab
  ├─ Account: name, email, logout
  ├─ AI Config: local model download / OpenRouter API key
  ├─ Subscription: free/premium status
  ├─ Theme: system / light / dark
  └─ Data: reset, clear cache

Word Detail Sheet (entry points: Home, Library, Discover, search results)
  ├─ Swipe up → Add to Collection Sheet
  ├─ Swipe down → Bookmark toggle (haptic)
  ├─ Double-tap → Favorite toggle (heart animation + haptic)
  ├─ Swipe left/right → Navigate words in current collection context
  ├─ "AI Enhance" → enriches word with mnemonic + extra examples (background)
  └─ Expanded view: definitions, examples, synonyms, antonyms, etymology, mnemonic

Add to Collection Sheet
  ├─ Checkmark list of all collections
  ├─ Toggle to add/remove word from collection
  └─ "+ New Collection" → Create/Edit Collection Modal

Practice Session Screen (fullscreen)
  ├─ Card front: word + phonetic
  ├─ Tap to reveal definition
  ├─ Rate: Again / Good / Easy
  ├─ Hint button → AI hint (if AI enabled)
  └─ Completion → stats screen with confetti

Onboarding (first launch, 3 steps)
  ├─ Step 1: Welcome + app value prop
  ├─ Step 2: AI setup (local model / OpenRouter key / skip)
  └─ Step 3: Auth (Sign up / Login / Guest)
```

---

### Screen Detail Notes

**A. Home (Today)**
- Streak counter + daily goal progress ring
- Due cards count with "Start Review" CTA
- "Recently Added" words — horizontal scroll of word cards
- Word of the Day (AI-generated if AI enabled, else curated)
- Quick search bar at top (jumps to Discover tab)

**B. Word Detail Sheet**
- Gesture-driven: swipe up (add to collection), swipe down (bookmark), double-tap (favorite), swipe left/right (navigate)
- Collapsed: word + phonetic + short definition + status icons (bookmarked, favorited)
- Expanded: full definitions (multiple if available), examples, synonyms/antonyms, etymology
- Mnemonic card: collapsible, shows AI-generated or user-written mnemonic
- "AI Enhance" button: runs background enrichment, shows result as inline card
- User notes: free text field at bottom

**C. Library Tab (Collection List)**
- Playful card grid (or list toggle)
- Each card: collection name, word count, mastery ring (% at Review state), accent color
- System collections at top: "All Saved", "Favorites", "Bookmarked"
- Long press → reorder, delete, edit
- "+" FAB → create collection

**D. Collection Detail**
- Header: collection name, description, progress bar (X/Y mastered), due card count
- Word list: word + short definition + mastery dot indicator
- Practice buttons: "Review Due (N)" / "Practice All"
- Bulk select: long press any word → select mode → move/delete
- Edit: tap collection name to open Create/Edit modal

**E. Discover (Search)**
- Default state: search bar + recent lookups (local) + curated word spotlight
- Live search: debounced, hits dictionary API pipeline
- Result card: word + definition preview + "+ Save" button
- Tapping result → Word Detail Sheet
- "Describe it" toggle (AI): describe a concept → AI suggests words → tap to look up

**F. Practice Session**
- Fullscreen, gesture-driven
- Pre-session summary: card counts by state (New / Learning / Review / Relearning)
- Card: word front → tap to reveal → definition + examples
- 3-button rating: Again / Good / Easy
- Progress bar in header
- Hint button (shows mnemonic first, AI second)
- End: stats screen with retention rate + confetti

**G. Profile / Settings**
- Top: user avatar placeholder + name + email
- AI Section: model download status + delete, OpenRouter key entry + model picker
- Subscription: current plan + upgrade CTA (premium features list)
- Appearance: theme picker
- Account: change password, logout
- Data: export (v2), reset progress, clear dictionary cache

---

## 8. Onboarding & First-Run Experience

1. **Welcome** — app name + tagline, one illustration
2. **Goal** — "I'm learning for..." (casual reader / professional / test prep)
   - Affects suggested collections and default content
3. **AI Setup** (optional, skippable)
   - Option A: Download local model (~2GB, works offline)
   - Option B: Add OpenRouter API key
   - Option C: Skip — use app without AI
4. **First word** — guided add-a-word moment to show the gesture system
5. **Done** — home screen with first collection pre-created

---

## 9. Design Language

**Inspiration**: Amie Calendar (playful, colorful, tactile), Capwords (bold typography, engaging word interactions)

**Principles**:
- **Tactile**: Every action has a physical analog — cards flip, sheets spring, gestures feel weighted
- **Colorful but not chaotic**: Collections get distinct accent colors, words have consistent chrome
- **Bold typography**: Large, confident word display — the word IS the hero
- **Generous whitespace**: Breathable layouts, not cramped lists
- **Micro-animations**: Haptics + springs on every interaction

**Type**: SF Pro Display for word headlines, SF Pro Text for body
**Color system**: Dynamic backgrounds per collection (pastels), semantic colors for SRS states (new/learning/review)
**Components**: Rounded rectangles everywhere (cornerRadius 20+), card stacks, pill buttons

---

## 10. Supabase Schema

```sql
-- Users handled by Supabase Auth

words (
  id uuid PK,
  user_id uuid FK auth.users,
  word text,
  definitions jsonb,
  examples jsonb,
  synonyms text[],
  antonyms text[],
  phonetic text,
  etymology text,
  other_forms jsonb,
  ai_mnemonic text,
  user_notes text,
  sources text[],
  created_at timestamptz,
  updated_at timestamptz
)

collections (
  id uuid PK,
  user_id uuid FK,
  name text,
  description text,
  color_hex text,
  is_public bool default false,
  created_at timestamptz,
  updated_at timestamptz
)

collection_words (
  collection_id uuid FK,
  word_id uuid FK,
  position int,
  added_at timestamptz,
  PRIMARY KEY (collection_id, word_id)
)

srs_cards (
  id uuid PK,
  user_id uuid FK,
  word_id uuid FK,
  due timestamptz,
  stability float,
  difficulty float,
  elapsed_days int,
  scheduled_days int,
  reps int,
  lapses int,
  state text,  -- New/Learning/Review/Relearning
  last_review timestamptz,
  updated_at timestamptz
)

user_preferences (
  user_id uuid PK FK,
  goal text,
  ai_tier text,  -- local/openrouter/none
  openrouter_model text,
  theme text,
  daily_goal_cards int,
  streak_count int,
  last_active date,
  updated_at timestamptz
)
```

---

## 11. Sync Strategy

**Pattern**: Local-first, async cloud sync

1. All writes go to SwiftData immediately (instant UX)
2. `SyncService` observes SwiftData changes via `ModelContext` notifications
3. On change: enqueue sync operation
4. On network available: batch-flush operations to Supabase
5. Conflict resolution: last-write-wins using `updated_at` timestamps
6. Guest mode: SwiftData only, no Supabase calls
7. On login: pull all cloud data, merge with local (additive — union of words)

---

## 12. Premium Features (StoreKit 2)

**Free**:
- Up to 3 collections
- Up to 100 saved words
- SRS practice (unlimited)
- Dictionary search (unlimited)
- Basic word detail

**Premium**:
- Unlimited collections and words
- AI enrichment (mnemonic, examples, AI search)
- Cloud sync + multi-device
- Advanced analytics (retention graphs, heatmaps)
- Widgets (Today's due cards, word of the day)
- Export (CSV, Anki deck)

---

## 13. What Was Fixed vs. Old App

| Issue | Old App | New App |
|-------|---------|---------|
| AI integration | Bolted on, unclear tier fallback | Designed into every AI touchpoint with clear graceful degradation |
| Dictionary pipeline | 3 APIs, no unified model, hardcoded keys | Unified WordModel, normalized data, user-managed keys |
| Architecture | Feature files scattered, services mixed with UI | Clean Architecture layers, DI from root |
| Local LLM | llama.rn (RN bridge), Llama 3.2-1B | MLX Swift (native), Phi-3.5-mini (better quality) |
| Cloud | Appwrite (locked vendor) | Supabase (open source, Postgres) |
| UI | Afterthought, inconsistent | Designed system first, Amie/Capwords inspired |
| Search | No AI-assisted semantic search | AI "describe it" mode + traditional lookup |
| Offline | Partial | Full offline for saved words + SRS + local AI |

---

## 14. Verification Plan

Once implemented, verify end-to-end:

1. **Onboarding flow**: Fresh install → goal → AI setup → first word gesture
2. **Dictionary pipeline**: Search word → confirm data from correct API tier → word saved to SwiftData
3. **AI enrichment**: Word added → mnemonic generated (local or OpenRouter) → stored and displayed
4. **SRS session**: Add 5 words → practice → rate cards → check `srs_cards` updated in SwiftData
5. **Cloud sync**: Login → make changes → verify Supabase rows updated → sign in on another session → data appears
6. **Offline mode**: Airplane mode → SRS still works → dictionary returns cached results
7. **Premium gate**: Free user hits word limit → paywall shown → StoreKit purchase → limit lifted
8. **Gesture system**: Swipe up (add to collection), swipe down (bookmark), double-tap (favorite), swipe left/right (navigate) all work in Word Detail Sheet
