# Word Data Enrichment — Design & Implementation Plan

**Status:** Approved for implementation  
**Last updated:** 2026-04-27  
**Covers:** Standardised word quality, multi-source enrichment pipeline, AI gap-filling, daily words bundle

---

## 1. Problem Statement

`WordEntity` has the right schema (phonetic, etymology, synonyms, antonyms, otherForms, examples) but the data is inconsistently populated. The three existing API normalizers leave most optional fields empty:

| Field | Current reality |
|---|---|
| `phonetic` | Only Free Dictionary provides it; missing for many words |
| `synonyms / antonyms` | Free Dictionary only (definition-level, sparse). Wordnik's Relatedwords endpoint is **not called** |
| `etymology` | Struct has the field, **never populated**. All three normalizers explicitly skip it |
| `otherForms` | Struct has the field, **always empty**. No source feeds it |
| `examples` | 0–1 inline examples from Free Dictionary; Wordnik gives 5 real-world examples |
| `audioURL` | Free Dictionary returns audio URLs in `Phonetic.audio` — **dropped on normalize** |
| `syllables` | Not in WordEntity, not fetched |

Additionally:

- `HomeViewModel.loadData()` fetches 10 words **sequentially** — cold load is slow.
- `curated_words.json` is 5000+ plain strings with zero pre-enrichment. Every first-time daily word triggers 3 concurrent API calls.
- Search quality depends entirely on which APIs succeed; a word with only one API response silently gets thin data.

---

## 2. Target State — WordQualityScore Contract

A word is considered **complete** when all of these pass:

```
✓ definitions       ≥ 2, each with a partOfSpeech
✓ phonetic          present (IPA string)
✓ audioURL          present (pronunciation audio link)
✓ examples          ≥ 2 real-world usage examples
✓ synonyms          ≥ 3
✓ antonyms          ≥ 1
✓ etymology         present (origin/history string)
✓ contextualNote    present (usage register, writer context, or mnemonic)
```

Words below this threshold are flagged with a `qualityScore: Int` (0–8, one point per field above). Score is stored in `WordSD` and used to prioritise LLM gap-filling.

---

## 3. WordEntity Changes

Add the following fields:

```swift
struct WordEntity {
    // ... existing fields ...

    // New in this plan
    let audioURL: String?           // pronunciation audio (MP3/OGG from Free Dict or M-W)
    let syllables: [String]         // ["mel", "an", "chol", "y"] — from WordsAPI or LLM
    let frequency: Double?          // word frequency score (0–7 Zipf scale) — WordsAPI
    let register: WordRegister?     // formal / informal / literary / archaic / rare
    let contextualNote: String?     // AI-generated usage note for writers
    let qualityScore: Int           // 0–8, populated by WordQualityChecker
}

enum WordRegister: String, Codable {
    case formal, informal, literary, archaic, rare, neutral
}
```

`WordSD` (SwiftData model) gains matching columns. Migration is additive — all new fields are optional.

---

## 4. Data Source Landscape

### 4a. APIs (Online)

| Source | Endpoint(s) used | Fields contributed | Auth | Rate limit |
|---|---|---|---|---|
| **Free Dictionary API** | `/api/v2/entries/en/{word}` | definitions, phonetic, **audioURL** (fix), examples, some synonyms | None | None |
| **Wiktionary REST** | `/page/definition/{word}` | definitions, examples | None | None |
| **Wordnik** | `/definitions`, `/examples`, **`/relatedWords`** (new) | definitions, examples, **synonyms, antonyms** (fix) | User key | ~5k/day free |
| **Datamuse API** (new) | `/?rel_syn=`, `/?rel_ant=`, `/?topics=`, `/?rel_hype=`, `/?rel_hypo=` | contextual synonyms, antonyms, semantic relatives, topic associations | None | 100k/day |
| **Merriam-Webster** (new) | `/v3/references/collegiate/json/{word}` | **etymology**, authoritative IPA phonetic, audio | User key | 1000/day free |

**Datamuse is the highest-leverage new addition:**
- `?rel_syn=word` → contextual synonyms (ranked by co-occurrence, not just thesaurus)
- `?rel_ant=word` → antonyms
- `?rel_hype=word` → hypernyms ("chair" → "furniture")
- `?rel_hypo=word` → hyponyms ("furniture" → "chair", "table")
- `?topics=word` → words strongly associated with a topic — powers the writer brainstorm feature
- All responses are JSON arrays, simple to parse, no auth

### 4b. Offline / Bundled (Phase 2)

| Source | What it provides | Bundle size | iOS integration |
|---|---|---|---|
| **WordNet (Princeton)** | 150k+ word senses, synsets, semantic relationships, hypernyms/hyponyms | ~50MB SQLite | `Lexicontext` Swift library |
| **Pre-enriched daily words JSON** | All 5000 curated words fully enriched via pipeline script | ~15–20MB JSON | Bundled in `Resources/` |

### 4c. Local LLM (Phase 2)

| Option | Model | Size | Integration |
|---|---|---|---|
| **Gemma 3 1B** (recommended) | Gemma 3 1B via MLX | ~300MB download | `LocalLLMClient` Swift pkg (MLX backend) |
| **Fallback** | OpenRouter (existing) | — | Already wired in `AIServiceCoordinator` |

`LocalLLMClient` supports structured JSON output — essential so LLM responses map directly to `WordEntity` fields without fragile string parsing.

---

## 5. Phase 1 — Immediate API Quality Improvements

### 5a. Fix: Free Dictionary normalizer

**File:** `VocabApp/Data/Dictionary/FreeDictionaryDTO.swift`

Currently drops `Phonetic.audio`. Fix: capture the first non-empty audio URL and map it to `WordEntity.audioURL`.

```
FreeDictionaryEntry.phonetics[].audio  →  WordEntity.audioURL
```

### 5b. Fix: Wordnik — wire Relatedwords endpoint

**File:** `VocabApp/Data/Dictionary/WordnikRequest.swift` + `WordnikDTO.swift`

Add `WordnikRelatedWordsRequest` hitting:
```
GET /v4/word.json/{word}/relatedWords?relationshipTypes=synonym,antonym&limit=10&api_key=...
```

Response shape:
```swift
struct WordnikRelationship: Decodable {
    let relationshipType: String  // "synonym" | "antonym"
    let words: [String]
}
```

Map to `WordEntity.synonyms` and `WordEntity.antonyms` in `DictionaryService.mergeResults()`.

### 5c. Fix: Wiktionary — parse etymology via Action API

Wiktionary's REST definition endpoint (`rest_v1`) doesn't include etymology. The MediaWiki **Action API** does:
```
GET https://en.wiktionary.org/w/api.php?action=parse&page={word}&prop=sections&format=json
```
Then fetch the Etymology section. This is an additional call, fire it in the same `TaskGroup` as the existing Wiktionary request.

**File:** New `WiktionaryEtymologyRequest.swift`

### 5d. New: Datamuse integration

**New files:**
- `VocabApp/Data/Dictionary/DatamuseRequest.swift`
- `VocabApp/Data/Dictionary/DatamuseDTO.swift`

Single request fires multiple Datamuse queries in parallel (they're cheap, no auth):

```swift
struct DatamuseEnrichment {
    let synonyms: [String]      // rel_syn
    let antonyms: [String]      // rel_ant
    let hypernyms: [String]     // rel_hype
    let hyponyms: [String]      // rel_hypo
    let topicWords: [String]    // topics= (writer brainstorm)
}
```

These map to:
- `WordEntity.synonyms` (merged with other sources)
- `WordEntity.antonyms` (merged)
- New `WordEntity.semanticRelatives: [String]` (hypernyms + hyponyms combined — useful for writer context panel)

### 5e. New: Merriam-Webster integration

**New files:**
- `VocabApp/Data/Dictionary/MerriamWebsterRequest.swift`
- `VocabApp/Data/Dictionary/MerriamWebsterDTO.swift`

Only fires when user has provided an M-W API key (same UX as Wordnik key in Settings). Contributes:
- `WordEntity.etymology` (parsed from `et` field in response)
- `WordEntity.phonetic` (IPA from `hwi.prs[].ipa`, higher quality than Free Dict)
- `WordEntity.audioURL` (M-W audio base URL + filename if Free Dict didn't provide one)

### 5f. Fix: HomeViewModel — concurrent word loading

**File:** `VocabApp/Features/Home/ViewModels/HomeViewModel.swift`

Replace the sequential `for wordString in wordStrings` loop with a `TaskGroup`:

```swift
// Before (sequential — 10 words × ~500ms = ~5s load)
for wordString in wordStrings {
    if let entity = try? await dictionaryRepository.lookup(word: wordString) {
        loaded.append(entity)
    }
}

// After (concurrent — all 10 fire at once, load time ≈ slowest single lookup)
await withTaskGroup(of: WordEntity?.self) { group in
    for wordString in wordStrings {
        group.addTask {
            try? await self.dictionaryRepository.lookup(word: wordString)
        }
    }
    for await result in group {
        if let entity = result { loaded.append(entity) }
    }
}
```

### 5g. New: WordQualityChecker

**New file:** `VocabApp/Domain/UseCases/WordQualityChecker.swift`

```swift
struct WordQualityChecker {
    func score(_ word: WordEntity) -> Int  // 0–8
    func missingFields(_ word: WordEntity) -> [WordField]
    func isComplete(_ word: WordEntity) -> Bool
}

enum WordField {
    case definitions, phonetic, audioURL, examples
    case synonyms, antonyms, etymology, contextualNote
}
```

Called after `DictionaryService.mergeResults()`. Score stored in `WordSD`. Words with score < 6 are queued for Phase 2 LLM gap-filling.

### 5h. Updated DictionaryService pipeline (Phase 1)

```
lookup(word)
  │
  ├─ 1. Cache check (SwiftData, 30-day TTL)
  │       └─ hit → return cached entity
  │
  ├─ 2. Concurrent API fetch (TaskGroup)
  │       ├─ Free Dictionary  → definitions, phonetic, audioURL, examples
  │       ├─ Wiktionary        → definitions, examples
  │       ├─ Wiktionary Etym.  → etymology  [new]
  │       ├─ Wordnik defs      → definitions
  │       ├─ Wordnik examples  → examples
  │       ├─ Wordnik related   → synonyms, antonyms  [fixed]
  │       ├─ Datamuse          → synonyms, antonyms, semanticRelatives  [new]
  │       └─ Merriam-Webster   → etymology, phonetic, audioURL  [new, if key present]
  │
  ├─ 3. mergeResults() → WordEntity
  │
  ├─ 4. WordQualityChecker.score()  [new]
  │       └─ store qualityScore in entity
  │
  └─ 5. Cache (SwiftData)
```

---

## 6. Phase 2 — Offline Bundle + LLM Gap-Filling

### 6a. WordNet SQLite bundle

Add `Lexicontext` Swift library via SPM:
```
https://github.com/... (Lexicontext repo)
```

`WordNetRepository` protocol + `LexicontextWordRepository` implementation hit WordNet **before** any API call. WordNet contributes:
- Multiple definitions per sense (very rich for common words)
- Synsets → high-quality synonyms
- Hypernym/hyponym chains

Call order in Phase 2:
```
1. Cache check
2. WordNet lookup (offline, instant)
3. API enrichment (fills phonetic, etymology, examples — gaps WordNet has)
4. Merge + quality check
5. LLM gap-fill if score < 6
6. Cache
```

### 6b. Pre-enriched daily words bundle

**Script:** `scripts/enrich_daily_words.swift` (run once, not at app runtime)

Process:
1. Load `curated_words.json` (5000 words)
2. For each word, run the full Phase 1 pipeline (Free Dict + Wiktionary + Wordnik + Datamuse + M-W)
3. Serialise to `curated_words_enriched.json` — array of full `WordEntity` JSON objects
4. Commit the generated file to the repo

`DailyWordsUseCase` in Phase 2:
- Loads `curated_words_enriched.json` at startup
- Returns pre-populated `[WordEntity]` directly — no API calls for daily words
- Falls back to live lookup if a word isn't found in the bundle (new additions to the list)

Estimated size: ~15–20MB for 5000 fully enriched words.

### 6c. Local LLM integration

**Package:** `LocalLLMClient` via SPM — supports both MLX (Apple Silicon, fast) and llama.cpp (fallback)  
**Model:** Gemma 3 1B (~300MB), downloaded on-demand when user enables AI in Settings

**New file:** `VocabApp/Services/LocalLLMService.swift`

Implements `AIRepository`. Wires into existing `AIServiceCoordinator` as Tier 1 (currently commented out):

```swift
// AIServiceCoordinator.swift — Phase 2
// Tier 1: Local LLM
if let localLLM = localLLMService, await localLLM.isModelReady() {
    return try await localLLM.generateContent(for: word, type: type)
}
// Tier 2: OpenRouter (existing)
// Tier 3: Graceful degradation (existing)
```

### 6d. LLM gap-filling

**New file:** `VocabApp/Domain/UseCases/WordEnrichmentUseCase.swift`

Triggered for words with `qualityScore < 6`. Runs async in background after word is displayed. Uses structured JSON output prompt:

```
Given the English word "{word}", provide the following as JSON:
{
  "etymology": "...",
  "contextualNote": "Usage register and context for writers: ...",
  "syllables": ["syl", "la", "ble"],
  "additionalSynonyms": ["...", "..."],
  "mnemonicHint": "..."
}
Only fill fields that are genuinely missing or thin.
```

Response mapped back to `WordEntity` and saved to cache. UI updates the card silently if the user is still viewing it.

**AI-generated fields are always labelled** — `Example.isAIGenerated = true`, and a subtle "AI" badge appears in the UI on those fields.

### 6e. Standalone AI screen

**New screen:** `VocabApp/Features/AIChat/`

Free-form text input. Supports:
- Single word lookup with full enrichment context ("tell me everything about 'melancholy'")
- Writer brainstorm ("10 ways to express grief without using the word sad")
- Phrase/idiom lookup ("idioms about time")
- Thematic word discovery ("words associated with maritime navigation")
- Contextual meaning ("what does 'wicked' mean in Boston slang?")

Backed by `AIServiceCoordinator` (local LLM → OpenRouter → unavailable). Does not return `WordEntity` — returns free-form streamed text. Results can be pinned/saved as user notes.

### 6f. Word metadata editing via LLM

On any bookmarked word's detail view, an "Enrich with AI" button:
1. Sends current `WordEntity` + "fill gaps / improve" prompt to LLM
2. Shows a diff-style preview of proposed changes
3. User approves individual field updates
4. Saved back to SwiftData

This is the manual override flow for power users.

---

## 7. New File Manifest

### Phase 1 (new files)
```
VocabApp/Data/Dictionary/
  DatamuseRequest.swift          — Datamuse API request
  DatamuseDTO.swift              — response DTOs + normalize()
  MerriamWebsterRequest.swift    — M-W API request
  MerriamWebsterDTO.swift        — response DTOs + normalize()
  WiktionaryEtymologyRequest.swift — etymology via Action API
  WordnikRelatedWordsRequest.swift — relatedWords endpoint

VocabApp/Domain/UseCases/
  WordQualityChecker.swift       — quality scoring + missing field detection
```

### Phase 1 (modified files)
```
VocabApp/Domain/Entities/WordEntity.swift       — add audioURL, syllables, frequency, register, contextualNote, qualityScore
VocabApp/Data/Dictionary/FreeDictionaryDTO.swift — capture audioURL
VocabApp/Data/Dictionary/WordnikDTO.swift        — add WordnikRelationship DTO
VocabApp/Data/Dictionary/WiktionaryDTO.swift     — no change (etymology via separate request)
VocabApp/Data/Dictionary/DictionaryService.swift — add new sources to TaskGroup, wire mergeResults
VocabApp/Data/Local/Models/WordSD.swift          — add new persisted columns
VocabApp/Features/Home/ViewModels/HomeViewModel.swift — concurrent TaskGroup loading
```

### Phase 2 (new files)
```
VocabApp/Data/Dictionary/WordNetRepository.swift    — offline WordNet lookup via Lexicontext
VocabApp/Services/LocalLLMService.swift             — LocalLLMClient wrapper
VocabApp/Domain/UseCases/WordEnrichmentUseCase.swift — async LLM gap-filling
VocabApp/Features/AIChat/Views/AIChatView.swift
VocabApp/Features/AIChat/ViewModels/AIChatViewModel.swift
scripts/enrich_daily_words.swift                    — one-time pre-enrichment script
VocabApp/Resources/curated_words_enriched.json      — generated by above script
```

### Phase 2 (modified files)
```
VocabApp/Services/AIServiceCoordinator.swift    — uncomment Tier 1 local LLM
VocabApp/Domain/UseCases/DailyWordsUseCase.swift — load from enriched bundle
VocabApp/Data/Dictionary/DictionaryService.swift  — add WordNet as first lookup tier
```

---

## 8. Settings / API Keys

The following keys are user-provided, stored in Keychain (same pattern as existing Wordnik key):

| Key | Where obtained | Phase |
|---|---|---|
| Wordnik | wordnik.com (existing) | Phase 1 |
| Merriam-Webster | dictionaryapi.com (free, non-commercial) | Phase 1 |
| OpenRouter | openrouter.ai (existing) | Phase 2 |

Datamuse and Free Dictionary require no keys. WordNet bundle requires no keys.

---

## 9. Implementation Order (within Phase 1)

1. `WordEntity` field additions + `WordSD` migration
2. `WordQualityChecker`
3. Fix Free Dictionary normalizer (audioURL)
4. Fix Wordnik Relatedwords endpoint (synonyms/antonyms)
5. Wiktionary etymology request
6. Datamuse integration
7. Merriam-Webster integration
8. `DictionaryService` — wire all sources into TaskGroup
9. `HomeViewModel` — concurrent loading

Each step is independently testable. Steps 3–7 can be parallelised across sessions.

---

## 10. Open Questions / Deferred

- **WordsAPI** (syllables, frequency, rhymes): Freemium — evaluate if syllable data is worth adding a paid dependency or if LLM-generated syllables are good enough.
- **Pronunciation audio playback**: `AVFoundation` needed in the word card UI — not in scope for this plan, tracked separately.
- **Pre-enrichment script timing**: Run manually by developer when curated list changes, or automate via CI? Start manual.
- **WordNet bundle size**: `Lexicontext` ships the full WordNet DB (~50MB). Evaluate if this is acceptable for App Store size on cellular. Possible mitigation: only bundle the subset of words in `curated_words.json`.
- **LLM model download UX**: Where in onboarding/settings does the ~300MB Gemma 3 1B download prompt appear? Needs a separate UX design pass.
- **AI chat screen design**: Visual design and navigation entry point not defined here — needs a separate UI design pass before implementation.
