# Word Data Enrichment — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Standardise word quality by fixing existing API normalisers, adding Datamuse and Merriam-Webster as new sources, scoring every word against an 8-field quality contract, and loading home words concurrently.

**Architecture:** `DictionaryService` runs all sources in a single `TaskGroup` (Free Dict + Wiktionary + Wordnik + Datamuse + M-W), merges results into a `WordEntity`, scores it with `WordQualityChecker`, and caches. `HomeViewModel` loads 10 daily words in parallel instead of sequentially. All new API keys follow the existing BYOK-from-Keychain pattern (OpenRouter precedent).

**Tech Stack:** Swift 6.3, URLSession async/await, TaskGroup, SwiftData (lightweight migration), XCTest

**Reference:** `docs/data-enrichment.md` — full design rationale and data source landscape.

---

## Before You Start

If there is no `VocabAppTests` test target: open `VocabApp.xcodeproj → File → New → Target → Unit Testing Bundle`, name it `VocabAppTests`, set host application to `VocabApp`. All test files below go in that target.

**Build:**
```bash
xcodebuild build -scheme VocabApp -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E '(error:|BUILD)'
```

**Test (single file):**
```bash
xcodebuild test -scheme VocabApp -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:VocabAppTests/<TestFileName> 2>&1 | grep -E '(Test Case|PASSED|FAILED|error:)'
```

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `VocabApp/Domain/Entities/WordEntity.swift` | Modify | Add 5 new fields + explicit init with defaults |
| `VocabApp/Data/Local/Models/WordSD.swift` | Modify | Persist new columns (lightweight migration) |
| `VocabApp/Domain/UseCases/WordQualityChecker.swift` | **Create** | 8-field quality score + missing field detection |
| `VocabApp/Data/Dictionary/FreeDictionaryDTO.swift` | Modify | Capture `audioURL` from phonetics array |
| `VocabApp/Data/Dictionary/WordnikRequest.swift` | Modify | Add `WordnikRelatedWordsRequest` |
| `VocabApp/Data/Dictionary/WordnikDTO.swift` | Modify | Add `WordnikRelationship` DTO + helper extensions |
| `VocabApp/Data/Dictionary/DatamuseRequest.swift` | **Create** | Datamuse requests (synonyms / antonyms / hypernyms / hyponyms) |
| `VocabApp/Data/Dictionary/DatamuseDTO.swift` | **Create** | Datamuse response DTO + `DatamuseEnrichment` |
| `VocabApp/Data/Dictionary/MerriamWebsterRequest.swift` | **Create** | M-W Collegiate API request |
| `VocabApp/Data/Dictionary/MerriamWebsterDTO.swift` | **Create** | M-W response DTO + `normalize(word:)` |
| `VocabApp/Data/Dictionary/DictionaryService.swift` | Modify | Wire all sources into TaskGroup; update `mergeResults`; apply quality score |
| `VocabApp/Services/AppEnvironment.swift` | Modify | Add M-W BYOK key (Keychain read + `updateMerriamWebsterKey`) |
| `VocabApp/Features/Home/ViewModels/HomeViewModel.swift` | Modify | Replace sequential loop with concurrent TaskGroup |

---

## Task 1 — WordEntity: new fields + explicit init

**Files:**
- Modify: `VocabApp/Domain/Entities/WordEntity.swift`
- Create: `VocabAppTests/WordEntityTests.swift`

- [ ] **Step 1.1: Write failing tests**

Create `VocabAppTests/WordEntityTests.swift`:

```swift
import XCTest
@testable import VocabApp

final class WordEntityTests: XCTestCase {

    // Reproduces every existing call site — only the 14 required params, none of the new ones.
    private func makeMinimal() -> WordEntity {
        WordEntity(
            id: UUID(),
            word: "ephemeral",
            phonetic: "/ɪˈfɛm.ər.əl/",
            definitions: [WordEntity.Definition(text: "Lasting a short time", partOfSpeech: "adjective", source: "t")],
            examples: [],
            synonyms: [],
            antonyms: [],
            etymology: nil,
            otherForms: [],
            aiMnemonic: nil,
            userNotes: nil,
            sources: ["test"],
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func test_newFields_defaultToNilOrEmpty() {
        let e = makeMinimal()
        XCTAssertNil(e.audioURL)
        XCTAssertEqual(e.syllables, [])
        XCTAssertNil(e.register)
        XCTAssertNil(e.contextualNote)
        XCTAssertEqual(e.qualityScore, 0)
    }

    func test_newFields_canBePassedExplicitly() {
        let e = WordEntity(
            id: UUID(), word: "ephemeral",
            phonetic: "/ɪˈfɛm.ər.əl/",
            definitions: [WordEntity.Definition(text: "Lasting a short time", partOfSpeech: "adjective", source: "t")],
            examples: [], synonyms: [], antonyms: [], etymology: nil,
            otherForms: [], aiMnemonic: nil, userNotes: nil,
            sources: ["test"], createdAt: Date(), updatedAt: Date(),
            audioURL: "https://example.com/ephemeral.mp3",
            syllables: ["e", "phem", "er", "al"],
            register: .literary,
            contextualNote: "Often used in poetry",
            qualityScore: 7
        )
        XCTAssertEqual(e.audioURL, "https://example.com/ephemeral.mp3")
        XCTAssertEqual(e.syllables, ["e", "phem", "er", "al"])
        XCTAssertEqual(e.register, .literary)
        XCTAssertEqual(e.contextualNote, "Often used in poetry")
        XCTAssertEqual(e.qualityScore, 7)
    }

    func test_wordRegister_rawValueRoundTrips() throws {
        let r = WordRegister.literary
        let encoded = try JSONEncoder().encode(r)
        let decoded = try JSONDecoder().decode(WordRegister.self, from: encoded)
        XCTAssertEqual(decoded, r)
    }
}
```

- [ ] **Step 1.2: Run — expect compile error** (`audioURL` not found)

```bash
xcodebuild test -scheme VocabApp -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:VocabAppTests/WordEntityTests 2>&1 | grep 'error:'
```

- [ ] **Step 1.3: Replace WordEntity.swift**

```swift
import Foundation

enum WordRegister: String, Codable, Equatable {
    case formal, informal, literary, archaic, rare, neutral
}

struct WordEntity: Identifiable, Codable, Equatable {
    let id: UUID
    let word: String
    let phonetic: String?
    let definitions: [Definition]
    let examples: [Example]
    let synonyms: [String]
    let antonyms: [String]
    let etymology: String?
    let otherForms: [WordForm]
    let aiMnemonic: String?
    let userNotes: String?
    let sources: [String]
    let createdAt: Date
    let updatedAt: Date
    // Phase 1 enrichment
    let audioURL: String?
    let syllables: [String]
    let register: WordRegister?
    let contextualNote: String?
    let qualityScore: Int

    init(
        id: UUID = UUID(),
        word: String,
        phonetic: String? = nil,
        definitions: [Definition] = [],
        examples: [Example] = [],
        synonyms: [String] = [],
        antonyms: [String] = [],
        etymology: String? = nil,
        otherForms: [WordForm] = [],
        aiMnemonic: String? = nil,
        userNotes: String? = nil,
        sources: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        audioURL: String? = nil,
        syllables: [String] = [],
        register: WordRegister? = nil,
        contextualNote: String? = nil,
        qualityScore: Int = 0
    ) {
        self.id = id; self.word = word; self.phonetic = phonetic
        self.definitions = definitions; self.examples = examples
        self.synonyms = synonyms; self.antonyms = antonyms
        self.etymology = etymology; self.otherForms = otherForms
        self.aiMnemonic = aiMnemonic; self.userNotes = userNotes
        self.sources = sources; self.createdAt = createdAt; self.updatedAt = updatedAt
        self.audioURL = audioURL; self.syllables = syllables
        self.register = register; self.contextualNote = contextualNote
        self.qualityScore = qualityScore
    }

    struct Definition: Codable, Equatable {
        let text: String
        let partOfSpeech: String
        let source: String
    }

    struct Example: Codable, Equatable {
        let text: String
        let source: String
        let isAIGenerated: Bool
    }

    struct WordForm: Codable, Equatable, Hashable {
        let form: String
        let relation: String
    }
}
```

- [ ] **Step 1.4: Build — confirm all existing call sites compile**

```bash
xcodebuild build -scheme VocabApp -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E '(error:|BUILD)'
```

Expected: `BUILD SUCCEEDED`. Existing call sites don't name the new params; they resolve via defaults.

- [ ] **Step 1.5: Run tests — expect all 3 PASSED**

```bash
xcodebuild test -scheme VocabApp -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:VocabAppTests/WordEntityTests 2>&1 | grep -E '(Test Case|PASSED|FAILED)'
```

- [ ] **Step 1.6: Commit**

```bash
git add VocabApp/Domain/Entities/WordEntity.swift VocabAppTests/WordEntityTests.swift
git commit -m "feat: add audioURL, syllables, register, contextualNote, qualityScore to WordEntity"
```

---

## Task 2 — WordSD: persist new columns

**Files:**
- Modify: `VocabApp/Data/Local/Models/WordSD.swift`

SwiftData automatically performs a lightweight migration when you add optional or defaulted properties — no `VersionedSchema` required here.

- [ ] **Step 2.1: Update WordSD**

Replace `VocabApp/Data/Local/Models/WordSD.swift`:

```swift
import Foundation
import SwiftData

@Model
final class WordSD {
    @Attribute(.unique) var id: UUID
    var word: String
    var phonetic: String?
    var definitionsData: Data
    var examplesData: Data
    var synonyms: [String]
    var antonyms: [String]
    var etymology: String?
    var otherFormsData: Data
    var aiMnemonic: String?
    var userNotes: String?
    var sources: [String]
    var createdAt: Date
    var updatedAt: Date
    // Phase 1 enrichment — all optional/defaulted → lightweight migration
    var audioURL: String?
    var syllables: [String] = []
    var register: String?        // WordRegister.rawValue
    var contextualNote: String?
    var qualityScore: Int = 0

    @Relationship(inverse: \CollectionSD.words)
    var collections: [CollectionSD]?

    init(from entity: WordEntity) {
        self.id = entity.id
        self.word = entity.word
        self.phonetic = entity.phonetic
        self.synonyms = entity.synonyms
        self.antonyms = entity.antonyms
        self.etymology = entity.etymology
        self.aiMnemonic = entity.aiMnemonic
        self.userNotes = entity.userNotes
        self.sources = entity.sources
        self.createdAt = entity.createdAt
        self.updatedAt = entity.updatedAt
        self.audioURL = entity.audioURL
        self.syllables = entity.syllables
        self.register = entity.register?.rawValue
        self.contextualNote = entity.contextualNote
        self.qualityScore = entity.qualityScore
        let encoder = JSONEncoder()
        self.definitionsData = (try? encoder.encode(entity.definitions)) ?? Data()
        self.examplesData = (try? encoder.encode(entity.examples)) ?? Data()
        self.otherFormsData = (try? encoder.encode(entity.otherForms)) ?? Data()
    }

    func toDomain() -> WordEntity {
        let decoder = JSONDecoder()
        let definitions = (try? decoder.decode([WordEntity.Definition].self, from: definitionsData)) ?? []
        let examples = (try? decoder.decode([WordEntity.Example].self, from: examplesData)) ?? []
        let otherForms = (try? decoder.decode([WordEntity.WordForm].self, from: otherFormsData)) ?? []
        return WordEntity(
            id: id, word: word, phonetic: phonetic,
            definitions: definitions, examples: examples,
            synonyms: synonyms, antonyms: antonyms,
            etymology: etymology, otherForms: otherForms,
            aiMnemonic: aiMnemonic, userNotes: userNotes,
            sources: sources, createdAt: createdAt, updatedAt: updatedAt,
            audioURL: audioURL, syllables: syllables,
            register: register.flatMap { WordRegister(rawValue: $0) },
            contextualNote: contextualNote, qualityScore: qualityScore
        )
    }
}
```

- [ ] **Step 2.2: Build**

```bash
xcodebuild build -scheme VocabApp -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E '(error:|BUILD)'
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 2.3: Commit**

```bash
git add VocabApp/Data/Local/Models/WordSD.swift
git commit -m "feat: add Phase 1 enrichment columns to WordSD (automatic lightweight migration)"
```

---

## Task 3 — WordQualityChecker

**Files:**
- Create: `VocabApp/Domain/UseCases/WordQualityChecker.swift`
- Create: `VocabAppTests/WordQualityCheckerTests.swift`

- [ ] **Step 3.1: Write failing tests**

Create `VocabAppTests/WordQualityCheckerTests.swift`:

```swift
import XCTest
@testable import VocabApp

final class WordQualityCheckerTests: XCTestCase {
    private let checker = WordQualityChecker()

    private func entity(
        defs: Int = 0, phonetic: String? = nil, audioURL: String? = nil,
        examples: Int = 0, synonyms: Int = 0, antonyms: Int = 0,
        etymology: String? = nil, contextualNote: String? = nil
    ) -> WordEntity {
        WordEntity(
            word: "test",
            phonetic: phonetic,
            definitions: (0..<defs).map { WordEntity.Definition(text: "d\($0)", partOfSpeech: "noun", source: "t") },
            examples: (0..<examples).map { WordEntity.Example(text: "e\($0)", source: "t", isAIGenerated: false) },
            synonyms: (0..<synonyms).map { "s\($0)" },
            antonyms: (0..<antonyms).map { "a\($0)" },
            etymology: etymology,
            sources: ["test"],
            audioURL: audioURL,
            contextualNote: contextualNote
        )
    }

    func test_score_bareWord_isZero() {
        XCTAssertEqual(checker.score(entity()), 0)
    }

    func test_score_completeWord_isEight() {
        let e = entity(defs: 2, phonetic: "/t/", audioURL: "https://ex.com/t.mp3",
                       examples: 2, synonyms: 3, antonyms: 1,
                       etymology: "From Latin", contextualNote: "formal")
        XCTAssertEqual(checker.score(e), 8)
        XCTAssertTrue(checker.isComplete(e))
    }

    func test_score_countsOnlyPresentFields() {
        let e = entity(phonetic: "/t/", audioURL: "https://ex.com/t.mp3", synonyms: 3)
        XCTAssertEqual(checker.score(e), 3)
        XCTAssertFalse(checker.isComplete(e))
    }

    func test_synonymThreshold_requiresThreeNotTwo() {
        XCTAssertEqual(checker.score(entity(synonyms: 2)), 0)
        XCTAssertEqual(checker.score(entity(synonyms: 3)), 1)
    }

    func test_missingFields_returnsCorrectSet() {
        let e = entity(phonetic: "/t/", audioURL: "https://ex.com/t.mp3")
        let missing = Set(checker.missingFields(e))
        XCTAssertFalse(missing.contains(.phonetic))
        XCTAssertFalse(missing.contains(.audioURL))
        XCTAssertTrue(missing.contains(.definitions))
        XCTAssertTrue(missing.contains(.examples))
        XCTAssertTrue(missing.contains(.synonyms))
        XCTAssertTrue(missing.contains(.antonyms))
        XCTAssertTrue(missing.contains(.etymology))
        XCTAssertTrue(missing.contains(.contextualNote))
    }
}
```

- [ ] **Step 3.2: Run — expect compile error** (`WordQualityChecker` not found)

```bash
xcodebuild test -scheme VocabApp -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:VocabAppTests/WordQualityCheckerTests 2>&1 | grep 'error:'
```

- [ ] **Step 3.3: Implement**

Create `VocabApp/Domain/UseCases/WordQualityChecker.swift`:

```swift
import Foundation

enum WordField: CaseIterable, Equatable {
    case definitions, phonetic, audioURL, examples
    case synonyms, antonyms, etymology, contextualNote
}

struct WordQualityChecker {

    func score(_ word: WordEntity) -> Int {
        WordField.allCases.count - missingFields(word).count
    }

    func isComplete(_ word: WordEntity) -> Bool {
        missingFields(word).isEmpty
    }

    func missingFields(_ word: WordEntity) -> [WordField] {
        var missing: [WordField] = []
        if word.definitions.count < 2  { missing.append(.definitions) }
        if word.phonetic == nil        { missing.append(.phonetic) }
        if word.audioURL == nil        { missing.append(.audioURL) }
        if word.examples.count < 2    { missing.append(.examples) }
        if word.synonyms.count < 3    { missing.append(.synonyms) }
        if word.antonyms.isEmpty      { missing.append(.antonyms) }
        if word.etymology == nil      { missing.append(.etymology) }
        if word.contextualNote == nil { missing.append(.contextualNote) }
        return missing
    }
}
```

- [ ] **Step 3.4: Run tests — expect all 5 PASSED**

```bash
xcodebuild test -scheme VocabApp -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:VocabAppTests/WordQualityCheckerTests 2>&1 | grep -E '(Test Case|PASSED|FAILED)'
```

- [ ] **Step 3.5: Commit**

```bash
git add VocabApp/Domain/UseCases/WordQualityChecker.swift VocabAppTests/WordQualityCheckerTests.swift
git commit -m "feat: add WordQualityChecker with 8-field quality contract"
```

---

## Task 4 — Free Dictionary: capture audioURL

**Files:**
- Modify: `VocabApp/Data/Dictionary/FreeDictionaryDTO.swift`
- Create: `VocabAppTests/FreeDictionaryNormalizerTests.swift`

- [ ] **Step 4.1: Write failing tests**

Create `VocabAppTests/FreeDictionaryNormalizerTests.swift`:

```swift
import XCTest
@testable import VocabApp

final class FreeDictionaryNormalizerTests: XCTestCase {

    private let json = """
    [{
        "word": "ephemeral",
        "phonetic": "/ɪˈfɛm.ər.əl/",
        "phonetics": [
            {"text": "/ɪˈfɛm.ər.əl/", "audio": ""},
            {"text": "/ɪˈfɛm.ər.əl/", "audio": "https://api.dictionaryapi.dev/media/pronunciations/en/ephemeral-us.mp3"}
        ],
        "meanings": [{
            "partOfSpeech": "adjective",
            "definitions": [{"definition": "Lasting for a very short time.", "example": "fashions are ephemeral"}],
            "synonyms": ["transient"], "antonyms": ["permanent"]
        }],
        "sourceUrls": ["https://en.wiktionary.org/wiki/ephemeral"]
    }]
    """

    func test_normalize_capturesFirstNonEmptyAudioURL() throws {
        let response = try JSONDecoder().decode(FreeDictionaryResponse.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(response.normalize().audioURL,
                       "https://api.dictionaryapi.dev/media/pronunciations/en/ephemeral-us.mp3")
    }

    func test_normalize_nilAudioURL_whenAllEmpty() throws {
        let j = """[{"word":"t","phonetics":[{"audio":""},{"audio":null}],"meanings":[]}]"""
        let response = try JSONDecoder().decode(FreeDictionaryResponse.self, from: j.data(using: .utf8)!)
        XCTAssertNil(response.normalize().audioURL)
    }

    func test_normalize_retainsPhonetic() throws {
        let response = try JSONDecoder().decode(FreeDictionaryResponse.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(response.normalize().phonetic, "/ɪˈfɛm.ər.əl/")
    }
}
```

- [ ] **Step 4.2: Run — expect `test_normalize_capturesFirstNonEmptyAudioURL` FAILED** (returns nil)

```bash
xcodebuild test -scheme VocabApp -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:VocabAppTests/FreeDictionaryNormalizerTests 2>&1 | grep -E '(PASSED|FAILED)'
```

- [ ] **Step 4.3: Fix FreeDictionaryDTO.swift — add audioURL to the return WordEntity**

In `FreeDictionaryDTO.swift`, inside the `normalize()` extension, add `audioURL:` to the return statement:

```swift
// replace the final return WordEntity(...) with:
return WordEntity(
    id: UUID(),
    word: entry.word,
    phonetic: entry.phonetic ?? entry.phonetics.first(where: { $0.text != nil })?.text,
    definitions: allDefinitions,
    examples: allExamples,
    synonyms: [String](allSynonyms),
    antonyms: [String](allAntonyms),
    etymology: nil,
    otherForms: [],
    aiMnemonic: nil,
    userNotes: nil,
    sources: ["Free Dictionary API"],
    createdAt: Date(),
    updatedAt: Date(),
    audioURL: entry.phonetics.first(where: { audio in
        guard let a = audio.audio else { return false }
        return !a.isEmpty
    })?.audio
)
```

- [ ] **Step 4.4: Run tests — expect all 3 PASSED**

```bash
xcodebuild test -scheme VocabApp -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:VocabAppTests/FreeDictionaryNormalizerTests 2>&1 | grep -E '(Test Case|PASSED|FAILED)'
```

- [ ] **Step 4.5: Commit**

```bash
git add VocabApp/Data/Dictionary/FreeDictionaryDTO.swift VocabAppTests/FreeDictionaryNormalizerTests.swift
git commit -m "fix: capture pronunciation audioURL from Free Dictionary phonetics array"
```

---

## Task 5 — Wordnik: RelatedWords for synonyms & antonyms

**Files:**
- Modify: `VocabApp/Data/Dictionary/WordnikRequest.swift`
- Modify: `VocabApp/Data/Dictionary/WordnikDTO.swift`
- Create: `VocabAppTests/WordnikRelatedWordsTests.swift`

- [ ] **Step 5.1: Write failing tests**

Create `VocabAppTests/WordnikRelatedWordsTests.swift`:

```swift
import XCTest
@testable import VocabApp

final class WordnikRelatedWordsTests: XCTestCase {

    func test_parse_synonymsAndAntonyms() throws {
        let json = """
        [
            {"relationshipType":"synonym","words":["transient","fleeting","momentary"]},
            {"relationshipType":"antonym","words":["permanent","lasting"]}
        ]
        """
        let rels = try JSONDecoder().decode([WordnikRelationship].self, from: json.data(using: .utf8)!)
        XCTAssertEqual(rels.synonyms(), ["transient", "fleeting", "momentary"])
        XCTAssertEqual(rels.antonyms(), ["permanent", "lasting"])
    }

    func test_parse_missingRelationshipReturnsEmpty() throws {
        let json = """[{"relationshipType":"antonym","words":["permanent"]}]"""
        let rels = try JSONDecoder().decode([WordnikRelationship].self, from: json.data(using: .utf8)!)
        XCTAssertEqual(rels.synonyms(), [])
        XCTAssertEqual(rels.antonyms(), ["permanent"])
    }

    func test_relatedWordsRequest_urlContainsRequiredParams() {
        let req = WordnikRelatedWordsRequest(word: "ephemeral", apiKey: "testkey")
        let url = req.url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("/relatedWords"))
        XCTAssertTrue(url.contains("synonym"))
        XCTAssertTrue(url.contains("antonym"))
        XCTAssertTrue(url.contains("testkey"))
    }
}
```

- [ ] **Step 5.2: Run — expect compile error** (`WordnikRelationship` not found)

- [ ] **Step 5.3: Add WordnikRelationship to WordnikDTO.swift**

Append to `VocabApp/Data/Dictionary/WordnikDTO.swift`:

```swift
struct WordnikRelationship: Decodable {
    let relationshipType: String
    let words: [String]
}

extension Array where Element == WordnikRelationship {
    func synonyms() -> [String] {
        first { $0.relationshipType == "synonym" }?.words ?? []
    }
    func antonyms() -> [String] {
        first { $0.relationshipType == "antonym" }?.words ?? []
    }
}
```

- [ ] **Step 5.4: Add WordnikRelatedWordsRequest to WordnikRequest.swift**

Append to `VocabApp/Data/Dictionary/WordnikRequest.swift`:

```swift
struct WordnikRelatedWordsRequest: APIRequest {
    typealias Response = [WordnikRelationship]
    let word: String
    let apiKey: String

    var url: URL? {
        let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word
        // %2C = percent-encoded comma for the relationship types list
        return URL(string: "https://api.wordnik.com/v4/word.json/\(encoded)/relatedWords"
            + "?useCanonical=false&relationshipTypes=synonym%2Cantonym"
            + "&limitPerRelationshipType=10&api_key=\(apiKey)")
    }

    var method: HTTPMethod { .get }
}
```

- [ ] **Step 5.5: Run tests — expect all 3 PASSED**

```bash
xcodebuild test -scheme VocabApp -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:VocabAppTests/WordnikRelatedWordsTests 2>&1 | grep -E '(Test Case|PASSED|FAILED)'
```

- [ ] **Step 5.6: Commit**

```bash
git add VocabApp/Data/Dictionary/WordnikRequest.swift VocabApp/Data/Dictionary/WordnikDTO.swift \
        VocabAppTests/WordnikRelatedWordsTests.swift
git commit -m "feat: add Wordnik RelatedWords endpoint for synonyms and antonyms"
```

---

## Task 6 — Datamuse: contextual synonyms, antonyms, hypernyms, hyponyms

No API key required. 100k requests/day free.

**Files:**
- Create: `VocabApp/Data/Dictionary/DatamuseRequest.swift`
- Create: `VocabApp/Data/Dictionary/DatamuseDTO.swift`
- Create: `VocabAppTests/DatamuseTests.swift`

- [ ] **Step 6.1: Write failing tests**

Create `VocabAppTests/DatamuseTests.swift`:

```swift
import XCTest
@testable import VocabApp

final class DatamuseTests: XCTestCase {

    func test_response_decodesWordList() throws {
        let json = """[{"word":"transient","score":14521},{"word":"fleeting","score":9823}]"""
        let words = try JSONDecoder().decode(DatamuseResponse.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(words.words(), ["transient", "fleeting"])
    }

    func test_emptyResponse_returnsEmpty() throws {
        let words = try JSONDecoder().decode(DatamuseResponse.self, from: "[]".data(using: .utf8)!)
        XCTAssertEqual(words.words(), [])
    }

    func test_synonymRequest_buildsCorrectURL() {
        let url = DatamuseRequest(word: "ephemeral", relation: .synonyms, maxResults: 10).url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("rel_syn=ephemeral"))
        XCTAssertTrue(url.contains("max=10"))
    }

    func test_antonymRequest_buildsCorrectURL() {
        let url = DatamuseRequest(word: "ephemeral", relation: .antonyms, maxResults: 5).url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("rel_ant=ephemeral"))
    }

    func test_hypernymRequest_buildsCorrectURL() {
        let url = DatamuseRequest(word: "chair", relation: .hypernyms, maxResults: 5).url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("rel_hype=chair"))
    }

    func test_hyponymRequest_buildsCorrectURL() {
        let url = DatamuseRequest(word: "furniture", relation: .hyponyms, maxResults: 5).url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("rel_hypo=furniture"))
    }
}
```

- [ ] **Step 6.2: Run — expect compile error** (`DatamuseRequest` not found)

- [ ] **Step 6.3: Create DatamuseRequest.swift**

Create `VocabApp/Data/Dictionary/DatamuseRequest.swift`:

```swift
import Foundation

struct DatamuseRequest: APIRequest {
    typealias Response = DatamuseResponse

    enum Relation: String {
        case synonyms  = "rel_syn"
        case antonyms  = "rel_ant"
        case hypernyms = "rel_hype"
        case hyponyms  = "rel_hypo"
    }

    let word: String
    let relation: Relation
    let maxResults: Int

    var url: URL? {
        var components = URLComponents(string: "https://api.datamuse.com/words")
        components?.queryItems = [
            URLQueryItem(name: relation.rawValue, value: word),
            URLQueryItem(name: "max", value: "\(maxResults)")
        ]
        return components?.url
    }

    var method: HTTPMethod { .get }
}
```

- [ ] **Step 6.4: Create DatamuseDTO.swift**

Create `VocabApp/Data/Dictionary/DatamuseDTO.swift`:

```swift
import Foundation

struct DatamuseWord: Decodable {
    let word: String
    let score: Int
}

typealias DatamuseResponse = [DatamuseWord]

extension DatamuseResponse {
    func words() -> [String] { map(\.word) }
}

struct DatamuseEnrichment {
    let synonyms: [String]
    let antonyms: [String]
    let hypernyms: [String]
    let hyponyms: [String]
}
```

- [ ] **Step 6.5: Run tests — expect all 6 PASSED**

```bash
xcodebuild test -scheme VocabApp -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:VocabAppTests/DatamuseTests 2>&1 | grep -E '(Test Case|PASSED|FAILED)'
```

- [ ] **Step 6.6: Commit**

```bash
git add VocabApp/Data/Dictionary/DatamuseRequest.swift VocabApp/Data/Dictionary/DatamuseDTO.swift \
        VocabAppTests/DatamuseTests.swift
git commit -m "feat: add Datamuse API client for contextual synonyms, antonyms, hypernyms, hyponyms"
```

---

## Task 7 — Merriam-Webster: etymology + authoritative phonetics

User provides their own free key at [dictionaryapi.com](https://dictionaryapi.com) (non-commercial, 1000 req/day). Follows the existing OpenRouter BYOK-from-Keychain pattern.

**Files:**
- Create: `VocabApp/Data/Dictionary/MerriamWebsterRequest.swift`
- Create: `VocabApp/Data/Dictionary/MerriamWebsterDTO.swift`
- Modify: `VocabApp/Services/AppEnvironment.swift`
- Create: `VocabAppTests/MerriamWebsterTests.swift`

- [ ] **Step 7.1: Write failing tests**

Create `VocabAppTests/MerriamWebsterTests.swift`:

```swift
import XCTest
@testable import VocabApp

final class MerriamWebsterTests: XCTestCase {

    // Realistic shape of an M-W Collegiate API response (trimmed to relevant fields)
    private let sampleJSON = """
    [{
        "hwi": {
            "hw": "ephem*er*al",
            "prs": [{"ipa": "i-ˈfe-mə-rəl", "sound": {"audio": "epheme01"}}]
        },
        "et": [["text", "from {it}Greek{/it} ephemeros, from {it}epi-{/it} + {it}hemera{/it} day"]]
    }]
    """

    func test_normalize_extractsIPA() throws {
        let entries = try JSONDecoder().decode([MerriamWebsterEntry].self, from: sampleJSON.data(using: .utf8)!)
        XCTAssertEqual(entries.normalize(word: "ephemeral").phonetic, "i-ˈfe-mə-rəl")
    }

    func test_normalize_stripsMarkupFromEtymology() throws {
        let entries = try JSONDecoder().decode([MerriamWebsterEntry].self, from: sampleJSON.data(using: .utf8)!)
        let entity = entries.normalize(word: "ephemeral")
        XCTAssertNotNil(entity.etymology)
        XCTAssertFalse(entity.etymology!.contains("{it}"))
        XCTAssertTrue(entity.etymology!.contains("Greek"))
    }

    func test_normalize_buildsAudioURL() throws {
        let entries = try JSONDecoder().decode([MerriamWebsterEntry].self, from: sampleJSON.data(using: .utf8)!)
        XCTAssertEqual(
            entries.normalize(word: "ephemeral").audioURL,
            "https://media.merriam-webster.com/audio/prons/en/us/mp3/e/epheme01.mp3"
        )
    }

    func test_normalize_emptyArray_returnsEmptyEntity() throws {
        let entries = try JSONDecoder().decode([MerriamWebsterEntry].self, from: "[]".data(using: .utf8)!)
        let entity = entries.normalize(word: "xyz")
        XCTAssertNil(entity.phonetic)
        XCTAssertNil(entity.etymology)
        XCTAssertNil(entity.audioURL)
    }

    func test_audioSubdirectory_bixPrefix() {
        XCTAssertEqual(MerriamWebsterAudioURL.subdirectory(for: "bixword"), "bix")
    }
    func test_audioSubdirectory_ggPrefix() {
        XCTAssertEqual(MerriamWebsterAudioURL.subdirectory(for: "ggword"), "gg")
    }
    func test_audioSubdirectory_digitPrefix() {
        XCTAssertEqual(MerriamWebsterAudioURL.subdirectory(for: "1word"), "number")
    }
    func test_audioSubdirectory_normalWord() {
        XCTAssertEqual(MerriamWebsterAudioURL.subdirectory(for: "epheme01"), "e")
    }

    func test_request_urlContainsWordAndKey() {
        let req = MerriamWebsterRequest(word: "ephemeral", apiKey: "testkey")
        let url = req.url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("ephemeral"))
        XCTAssertTrue(url.contains("key=testkey"))
        XCTAssertTrue(url.contains("collegiate"))
    }
}
```

- [ ] **Step 7.2: Run — expect compile error** (`MerriamWebsterEntry` not found)

- [ ] **Step 7.3: Create MerriamWebsterRequest.swift**

Create `VocabApp/Data/Dictionary/MerriamWebsterRequest.swift`:

```swift
import Foundation

struct MerriamWebsterRequest: APIRequest {
    typealias Response = [MerriamWebsterEntry]
    let word: String
    let apiKey: String

    var url: URL? {
        let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word
        return URL(string: "https://www.dictionaryapi.com/api/v3/references/collegiate/json/\(encoded)?key=\(apiKey)")
    }

    var method: HTTPMethod { .get }
}
```

- [ ] **Step 7.4: Create MerriamWebsterDTO.swift**

Create `VocabApp/Data/Dictionary/MerriamWebsterDTO.swift`:

```swift
import Foundation

// MARK: - Entry

struct MerriamWebsterEntry: Decodable {
    let hwi: HeadwordInfo?
    let et: [[MWValue]]?       // etymology: array of [type-tag, text] pairs

    struct HeadwordInfo: Decodable {
        let hw: String
        let prs: [Pronunciation]?

        struct Pronunciation: Decodable {
            let ipa: String?
            let sound: Sound?
            struct Sound: Decodable { let audio: String }
        }
    }
}

// M-W arrays contain mixed String / [String] values — MWValue decodes both.
enum MWValue: Decodable {
    case string(String)
    case nested([MWValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self)     { self = .string(s);  return }
        if let a = try? c.decode([MWValue].self)  { self = .nested(a);  return }
        self = .string("")
    }

    var stringValue: String? {
        guard case .string(let s) = self else { return nil }
        return s
    }
}

// MARK: - Audio URL helper

enum MerriamWebsterAudioURL {
    /// M-W audio files live in a subdirectory determined by the filename prefix.
    static func subdirectory(for filename: String) -> String {
        if filename.hasPrefix("bix") { return "bix" }
        if filename.hasPrefix("gg")  { return "gg" }
        if let first = filename.first, first.isNumber { return "number" }
        return String(filename.prefix(1))
    }

    static func build(filename: String) -> String {
        "https://media.merriam-webster.com/audio/prons/en/us/mp3/\(subdirectory(for: filename))/\(filename).mp3"
    }
}

// MARK: - Normalise

extension Array where Element == MerriamWebsterEntry {
    func normalize(word: String) -> WordEntity {
        guard let entry = first else {
            return WordEntity(word: word, sources: ["Merriam-Webster"])
        }
        let phonetic = entry.hwi?.prs?.first?.ipa
        let audioURL = entry.hwi?.prs?.first?.sound.map { MerriamWebsterAudioURL.build(filename: $0.audio) }
        let etymology: String? = entry.et?
            .compactMap { pair -> String? in
                guard pair.first?.stringValue == "text",
                      let text = pair.dropFirst().first?.stringValue else { return nil }
                return text.strippingMWMarkup()
            }
            .first

        return WordEntity(
            word: word,
            phonetic: phonetic,
            etymology: etymology,
            sources: ["Merriam-Webster"],
            audioURL: audioURL
        )
    }
}

private extension String {
    /// Strip M-W wikitext tags like {it}, {bc}, {dx}, etc.
    func strippingMWMarkup() -> String {
        replacingOccurrences(of: "\\{[^}]+\\}", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

- [ ] **Step 7.5: Run tests — expect all 9 PASSED**

```bash
xcodebuild test -scheme VocabApp -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:VocabAppTests/MerriamWebsterTests 2>&1 | grep -E '(Test Case|PASSED|FAILED)'
```

- [ ] **Step 7.6: Add M-W BYOK key to AppEnvironment**

In `VocabApp/Services/AppEnvironment.swift`, add the M-W key alongside the existing OpenRouter key. Find the `// BYOK Keys from Keychain` block and add the M-W read:

```swift
// BYOK Keys from Keychain
let orKeyPath  = "com.atharvanayak.vocabapp.openrouter_key"
let mwKeyPath  = "com.atharvanayak.vocabapp.merriamwebster_key"   // add this line
let savedOrKey = (try? KeychainHelper.read(key: orKeyPath)).flatMap { String(data: $0, encoding: .utf8) }
let savedMWKey = (try? KeychainHelper.read(key: mwKeyPath)).flatMap { String(data: $0, encoding: .utf8) }   // add this
```

Update the `DictionaryService` init line to pass the M-W key:

```swift
// before:
self.dictionaryRepository = DictionaryService(apiClient: apiClient, wordRepository: wordRepo, wordnikApiKey: wordnikKey)

// after:
self.dictionaryRepository = DictionaryService(
    apiClient: apiClient,
    wordRepository: wordRepo,
    wordnikApiKey: wordnikKey,
    merriamWebsterApiKey: savedMWKey   // new
)
```

Also add the update function alongside `updateAIKey`:

```swift
@MainActor
func updateMerriamWebsterKey(_ key: String) {
    let keyPath = "com.atharvanayak.vocabapp.merriamwebster_key"
    let data = key.isEmpty ? nil : key.data(using: .utf8)
    if let data {
        try? KeychainHelper.save(key: keyPath, data: data)
    } else {
        try? KeychainHelper.delete(key: keyPath)
    }
    (dictionaryRepository as? DictionaryService)?.updateMerriamWebsterKey(key.isEmpty ? nil : key)
}
```

- [ ] **Step 7.7: Build**

```bash
xcodebuild build -scheme VocabApp -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E '(error:|BUILD)'
```

Expected: compile errors on `DictionaryService` (missing param + missing method) — fixed in Task 8.

- [ ] **Step 7.8: Commit (partial — AppEnvironment only)**

```bash
git add VocabApp/Data/Dictionary/MerriamWebsterRequest.swift VocabApp/Data/Dictionary/MerriamWebsterDTO.swift \
        VocabApp/Services/AppEnvironment.swift VocabAppTests/MerriamWebsterTests.swift
git commit -m "feat: add Merriam-Webster Collegiate API client for etymology and IPA phonetics"
```

---

## Task 8 — DictionaryService: wire all sources + quality scoring

**Files:**
- Modify: `VocabApp/Data/Dictionary/DictionaryService.swift`

This task adds `merriamWebsterApiKey` to the service, adds Datamuse and M-W into the TaskGroup, updates `mergeResults` to handle new fields, and applies `WordQualityChecker` after merge.

- [ ] **Step 8.1: Add merriamWebsterApiKey property and updateMerriamWebsterKey method**

In `DictionaryService.swift`, after the existing `wordnikApiKey` declarations:

```swift
// add alongside wordnikApiKey
private var merriamWebsterApiKey: String?
```

Update `init`:

```swift
init(apiClient: APIClient, wordRepository: WordRepository,
     wordnikApiKey: String? = nil, merriamWebsterApiKey: String? = nil) {
    self.apiClient = apiClient
    self.wordRepository = wordRepository
    self.wordnikApiKey = wordnikApiKey
    self.merriamWebsterApiKey = merriamWebsterApiKey
}
```

Add the update method alongside `updateWordnikKey`:

```swift
func updateMerriamWebsterKey(_ key: String?) {
    self.merriamWebsterApiKey = key
}
```

- [ ] **Step 8.2: Add Wordnik RelatedWords, Datamuse, and M-W tasks to the TaskGroup**

In the `lookup(word:)` function, inside the `withTaskGroup(of: WordEntity?.self)` block, append after the existing Wordnik task:

```swift
// Wordnik RelatedWords — synonyms & antonyms
if let key = wordnikApiKey, !key.isEmpty {
    group.addTask {
        do {
            let relationships = try await self.apiClient.send(
                WordnikRelatedWordsRequest(word: normalizedWord, apiKey: key))
            return WordEntity(
                word: normalizedWord,
                synonyms: relationships.synonyms(),
                antonyms: relationships.antonyms(),
                sources: ["Wordnik"]
            )
        } catch {
            print("❌ Wordnik RelatedWords error: \(error)")
            return nil
        }
    }
}

// Datamuse — contextual synonyms, antonyms, hypernyms, hyponyms (no key required)
group.addTask {
    do {
        async let synR  = self.apiClient.send(DatamuseRequest(word: normalizedWord, relation: .synonyms,  maxResults: 15))
        async let antR  = self.apiClient.send(DatamuseRequest(word: normalizedWord, relation: .antonyms,  maxResults: 10))
        async let hypeR = self.apiClient.send(DatamuseRequest(word: normalizedWord, relation: .hypernyms, maxResults: 5))
        async let hypoR = self.apiClient.send(DatamuseRequest(word: normalizedWord, relation: .hyponyms,  maxResults: 5))
        let (syn, ant, hype, hypo) = try await (synR, antR, hypeR, hypoR)
        return WordEntity(
            word: normalizedWord,
            synonyms: syn.words() + hype.words(),
            antonyms: ant.words() + hypo.words(),
            sources: ["Datamuse"]
        )
    } catch {
        print("❌ Datamuse error: \(error)")
        return nil
    }
}

// Merriam-Webster — etymology + IPA phonetics (user BYOK key)
if let key = merriamWebsterApiKey, !key.isEmpty {
    group.addTask {
        do {
            let entries = try await self.apiClient.send(
                MerriamWebsterRequest(word: normalizedWord, apiKey: key))
            return entries.normalize(word: normalizedWord)
        } catch {
            print("❌ Merriam-Webster error: \(error)")
            return nil
        }
    }
}
```

- [ ] **Step 8.3: Update mergeResults to handle new fields and apply quality score**

Replace the entire `mergeResults` private function:

```swift
private func mergeResults(_ entities: [WordEntity], originalWord: String) -> WordEntity {
    let checker = WordQualityChecker()

    // Source priority for single-value fields: M-W > Wordnik > Free Dict > others
    let mw       = entities.first { $0.sources.contains("Merriam-Webster") }
    let wordnik  = entities.first { $0.sources.contains("Wordnik") }
    let freeDict = entities.first { $0.sources.contains("Free Dictionary API") }
    let primary  = mw ?? wordnik ?? freeDict ?? entities[0]

    // Deduplicated definitions (exact text match)
    var seenDefs = Set<String>()
    let allDefinitions: [WordEntity.Definition] = entities.flatMap(\.definitions).filter {
        seenDefs.insert($0.text.lowercased()).inserted
    }

    // Deduplicated examples
    var seenExs = Set<String>()
    let allExamples: [WordEntity.Example] = entities.flatMap(\.examples).filter {
        seenExs.insert($0.text.lowercased()).inserted
    }

    let synonyms = Array(Set(entities.flatMap(\.synonyms)))
    let antonyms = Array(Set(entities.flatMap(\.antonyms)))
    let sources  = Array(Set(entities.flatMap(\.sources)))

    // Field priority: prefer M-W for phonetic/audio/etymology; fall back to any non-nil source
    let phonetic = mw?.phonetic
                ?? freeDict?.phonetic
                ?? entities.first(where: { $0.phonetic != nil })?.phonetic

    let audioURL = freeDict?.audioURL
                ?? mw?.audioURL
                ?? entities.first(where: { $0.audioURL != nil })?.audioURL

    let etymology = mw?.etymology
                 ?? entities.first(where: { $0.etymology != nil })?.etymology

    let merged = WordEntity(
        id: primary.id,
        word: primary.word.isEmpty ? originalWord : primary.word,
        phonetic: phonetic,
        definitions: allDefinitions,
        examples: allExamples,
        synonyms: synonyms,
        antonyms: antonyms,
        etymology: etymology,
        otherForms: Array(Set(entities.flatMap(\.otherForms))),
        aiMnemonic: nil,
        userNotes: nil,
        sources: sources,
        createdAt: primary.createdAt,
        updatedAt: Date(),
        audioURL: audioURL,
        qualityScore: 0   // placeholder; recalculated below
    )

    let score = checker.score(merged)
    // Return with computed quality score
    return WordEntity(
        id: merged.id, word: merged.word, phonetic: merged.phonetic,
        definitions: merged.definitions, examples: merged.examples,
        synonyms: merged.synonyms, antonyms: merged.antonyms,
        etymology: merged.etymology, otherForms: merged.otherForms,
        aiMnemonic: merged.aiMnemonic, userNotes: merged.userNotes,
        sources: merged.sources, createdAt: merged.createdAt, updatedAt: merged.updatedAt,
        audioURL: merged.audioURL, syllables: merged.syllables,
        register: merged.register, contextualNote: merged.contextualNote,
        qualityScore: score
    )
}
```

- [ ] **Step 8.4: Build — no errors**

```bash
xcodebuild build -scheme VocabApp -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E '(error:|BUILD)'
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 8.5: Commit**

```bash
git add VocabApp/Data/Dictionary/DictionaryService.swift
git commit -m "feat: wire Datamuse, Merriam-Webster, and Wordnik RelatedWords into DictionaryService TaskGroup; apply WordQualityChecker after merge"
```

---

## Task 9 — HomeViewModel: concurrent word loading

**Files:**
- Modify: `VocabApp/Features/Home/ViewModels/HomeViewModel.swift`

- [ ] **Step 9.1: Replace sequential loop with TaskGroup**

In `HomeViewModel.swift`, replace the `for wordString in wordStrings` loop inside `loadData()`:

```swift
// BEFORE (sequential — ~5s for 10 words on cold start)
var loaded: [WordEntity] = []
for wordString in wordStrings {
    if let entity = try? await dictionaryRepository.lookup(word: wordString) {
        loaded.append(entity)
    }
}
words = loaded

// AFTER (concurrent — load time ≈ slowest single lookup, typically ~800ms)
var loaded: [WordEntity] = []
await withTaskGroup(of: WordEntity?.self) { group in
    for wordString in wordStrings {
        group.addTask { [dictionaryRepository] in
            try? await dictionaryRepository.lookup(word: wordString)
        }
    }
    for await result in group {
        if let entity = result { loaded.append(entity) }
    }
}
words = loaded
```

The `[dictionaryRepository]` capture avoids capturing `self` (a `@MainActor` class) inside a non-isolated child task, which would cause a Swift 6 concurrency warning.

- [ ] **Step 9.2: Build**

```bash
xcodebuild build -scheme VocabApp -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E '(error:|BUILD)'
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 9.3: Run app on simulator and verify**

Launch the app in the simulator. Open the Home tab. Confirm:
- The loading spinner appears once
- All 10 word cards load (previously some might have been dropped silently)
- No crashes in the console

- [ ] **Step 9.4: Commit**

```bash
git add VocabApp/Features/Home/ViewModels/HomeViewModel.swift
git commit -m "perf: load daily words concurrently with TaskGroup (was sequential)"
```

---

## Self-Review: Spec Coverage Check

| Spec requirement | Task |
|---|---|
| `audioURL` field on WordEntity | Task 1 |
| `qualityScore` field on WordEntity | Task 1 |
| `syllables`, `register`, `contextualNote` fields | Task 1 |
| WordSD lightweight migration | Task 2 |
| WordQualityChecker with 8-field contract | Task 3 |
| Free Dictionary audioURL capture | Task 4 |
| Wordnik RelatedWords endpoint | Task 5 |
| Datamuse synonyms/antonyms/hypernyms/hyponyms | Task 6 |
| Merriam-Webster etymology + phonetics | Task 7 |
| M-W BYOK key (Keychain, AppEnvironment) | Task 7 |
| All sources wired into single TaskGroup | Task 8 |
| Quality score applied after merge | Task 8 |
| Merge priority (M-W > Wordnik > Free Dict) | Task 8 |
| HomeViewModel concurrent loading | Task 9 |

All Phase 1 requirements from `docs/data-enrichment.md` are covered. Phase 2 items (WordNet bundle, pre-enriched JSON, LocalLLMClient, AI chat screen) are out of scope for this plan.

---

## Notes for Phase 2

When Phase 2 begins, refer to `docs/data-enrichment.md` §6 for:
- `WordNetRepository` (Lexicontext SPM package, offline SQLite)
- `scripts/enrich_daily_words.swift` (one-time pre-enrichment script)
- `LocalLLMService` (LocalLLMClient SPM, Gemma 3 1B)
- `WordEnrichmentUseCase` (async LLM gap-fill for words with `qualityScore < 6`)
