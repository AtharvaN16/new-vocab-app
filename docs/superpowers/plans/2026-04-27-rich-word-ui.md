# Rich Word UI — Surfacing Enriched Data Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Display all enriched word data in the expanded word card — multiple definitions, etymology, and audio pronunciation playback.

**Architecture:** All view changes are in the existing `WordExpandedContentView` and `WordCardView`. Audio state is encapsulated in a new `WordAudioPlayer` `@Observable` class owned as `@State` in `WordCardView` (so the same player instance persists across expand/collapse without prop-drilling through a ViewModel). No new ViewModels needed.

**Tech Stack:** SwiftUI, AVFoundation, `@Observable`

---

## File Manifest

| File | Action | Responsibility |
|---|---|---|
| `VocabApp/Services/WordAudioPlayer.swift` | **Create** | `@Observable` class wrapping AVPlayer; `toggle(url:)`, `stop()`, `isPlaying` state |
| `VocabApp/Features/Words/Views/WordExpandedContentView.swift` | Modify | Replace single-definition hero with DEFINITIONS section; add ETYMOLOGY section; add audio button next to phonetic |
| `VocabApp/Features/Words/Views/WordCardView.swift` | Modify | Own `@State audioPlayer`; pass to expanded view; add audio button to collapsed phonetic slot; stop player on word change |
| `VocabAppTests/WordAudioPlayerTests.swift` | **Create** | Unit tests for state machine: initial state, toggle, stop, nil URL guard |

---

## Context for Agentic Workers

**Codebase snapshot:**

`WordExpandedContentView` (`VocabApp/Features/Words/Views/WordExpandedContentView.swift`) takes `word: WordEntity` plus tilt geometry params. It uses a private `expandedSection(_:content:)` helper that renders a monospaced label + content block. The current layout order is: phonetic → word (StickerText) → POS → first definition → EXAMPLES → SYNONYMS → ANTONYMS → OTHER WORD FORMS → AI MNEMONIC.

`WordCardView` (`VocabApp/Features/Words/Views/WordCardView.swift`) owns the gesture system and switches between `collapsedContent(word:)` and `WordExpandedContentView`. It already has `@State private var motion = MotionManager()`.

`WordEntity` (`VocabApp/Domain/Entities/WordEntity.swift`) has:
- `definitions: [Definition]` where `Definition` has `.text: String`, `.partOfSpeech: String`
- `etymology: String?`
- `audioURL: String?`

`Theme.Colors.textSecondary` = `Color.black.opacity(0.5)`.

Tests use simulator UDID `B4403B3A-10A8-43A3-9B61-FD2439ADFEA5`.

After adding new Swift files, run `xcodegen generate` (from the project root) before building.

---

## Task 1 — Multiple Definitions + Etymology in Expanded View

**Files:**
- Modify: `VocabApp/Features/Words/Views/WordExpandedContentView.swift`

Pure view change — no new types. Test is `xcodebuild build` succeeding.

- [x] **Step 1.1: Replace single-definition hero with DEFINITIONS section**

In `WordExpandedContentView.swift`, find and **replace** this block (currently after the POS text):

```swift
if let def = word.definitions.first {
    Text(def.text)
        .font(.system(size: 16))
        .tracking(-0.7)
        .foregroundColor(Theme.Colors.textSecondary)
        .padding(.bottom, 36)
}
```

Replace with:

```swift
if !word.definitions.isEmpty {
    expandedSection("DEFINITIONS") {
        ForEach(Array(word.definitions.prefix(5).enumerated()), id: \.offset) { i, def in
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(i + 1).")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Colors.textSecondary)
                    if !def.partOfSpeech.isEmpty {
                        Text(def.partOfSpeech)
                            .font(.system(size: 14).italic())
                            .foregroundColor(Theme.Colors.textSecondary.opacity(0.7))
                    }
                }
                Text(def.text)
                    .font(.system(size: 16))
                    .tracking(-0.7)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.bottom, 16)
        }
    }
}
```

- [x] **Step 1.2: Add ETYMOLOGY section after ANTONYMS**

In `WordExpandedContentView.swift`, after the `if !word.antonyms.isEmpty { expandedSection("ANTONYMS") ... }` block, add:

```swift
if let etymology = word.etymology, !etymology.isEmpty {
    expandedSection("ETYMOLOGY") {
        Text(etymology)
            .font(.system(size: 16))
            .tracking(-0.6)
            .foregroundColor(Theme.Colors.textSecondary)
            .lineSpacing(4)
    }
}
```

- [x] **Step 1.3: Build — no errors**

```bash
xcodebuild build -scheme VocabApp -destination 'id=B4403B3A-10A8-43A3-9B61-FD2439ADFEA5' 2>&1 | grep -E '(error:|BUILD)'
```

Expected: `BUILD SUCCEEDED`

- [x] **Step 1.4: Commit**

```bash
git add VocabApp/Features/Words/Views/WordExpandedContentView.swift
git commit -m "feat: show all definitions and etymology in expanded word card"
```

---

## Task 2 — Audio Playback: play button next to phonetic

**Files:**
- Create: `VocabApp/Services/WordAudioPlayer.swift`
- Create: `VocabAppTests/WordAudioPlayerTests.swift`
- Modify: `VocabApp/Features/Words/Views/WordExpandedContentView.swift`
- Modify: `VocabApp/Features/Words/Views/WordCardView.swift`

- [x] **Step 2.1: Write failing tests**

Create `VocabAppTests/WordAudioPlayerTests.swift`:

```swift
import XCTest
@testable import VocabApp

final class WordAudioPlayerTests: XCTestCase {

    func test_initialState_notPlaying() {
        let player = WordAudioPlayer()
        XCTAssertFalse(player.isPlaying)
    }

    func test_toggle_nilURL_doesNotPlay() {
        let player = WordAudioPlayer()
        player.toggle(url: nil)
        XCTAssertFalse(player.isPlaying)
    }

    func test_stop_whenNotPlaying_staysNotPlaying() {
        let player = WordAudioPlayer()
        player.stop()
        XCTAssertFalse(player.isPlaying)
    }

    func test_toggle_validURL_startsPlaying() {
        let player = WordAudioPlayer()
        player.toggle(url: "https://api.dictionaryapi.dev/media/pronunciations/en/ephemeral-us.mp3")
        XCTAssertTrue(player.isPlaying)
    }

    func test_toggle_whenPlaying_stops() {
        let player = WordAudioPlayer()
        player.toggle(url: "https://api.dictionaryapi.dev/media/pronunciations/en/ephemeral-us.mp3")
        player.toggle(url: "https://api.dictionaryapi.dev/media/pronunciations/en/ephemeral-us.mp3")
        XCTAssertFalse(player.isPlaying)
    }

    func test_stop_whenPlaying_stops() {
        let player = WordAudioPlayer()
        player.toggle(url: "https://api.dictionaryapi.dev/media/pronunciations/en/ephemeral-us.mp3")
        player.stop()
        XCTAssertFalse(player.isPlaying)
    }
}
```

- [x] **Step 2.2: Run — expect compile error** (`WordAudioPlayer` not found)

```bash
xcodebuild test -scheme VocabApp -destination 'id=B4403B3A-10A8-43A3-9B61-FD2439ADFEA5' \
  -only-testing:VocabAppTests/WordAudioPlayerTests 2>&1 | grep -E '(error:|PASSED|FAILED)' | head -5
```

Expected: `error: cannot find type 'WordAudioPlayer' in scope`

- [x] **Step 2.3: Create WordAudioPlayer.swift**

Create `VocabApp/Services/WordAudioPlayer.swift`:

```swift
import AVFoundation
import Observation

@Observable
final class WordAudioPlayer {
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    var isPlaying: Bool = false

    func toggle(url urlString: String?) {
        guard let urlString, let url = URL(string: urlString) else { return }
        if isPlaying {
            stop()
        } else {
            let item = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: item)
            player?.play()
            isPlaying = true
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                self?.isPlaying = false
            }
        }
    }

    func stop() {
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }
        player?.pause()
        player = nil
        isPlaying = false
    }

    deinit { stop() }
}
```

- [x] **Step 2.4: Run xcodegen then run tests — expect all 6 PASSED**

```bash
xcodegen generate 2>&1 | tail -2
xcodebuild test -scheme VocabApp -destination 'id=B4403B3A-10A8-43A3-9B61-FD2439ADFEA5' \
  -only-testing:VocabAppTests/WordAudioPlayerTests 2>&1 | grep -E '(Test Case|PASSED|FAILED)'
```

Expected: 6 tests PASSED.

- [x] **Step 2.5: Add `audioPlayer` parameter to WordExpandedContentView**

In `WordExpandedContentView.swift`, add the property after `var tiltMultiplier: Double = 1.0`:

```swift
var audioPlayer: WordAudioPlayer = WordAudioPlayer()
```

Then replace the phonetic block (the `if let phonetic = word.phonetic` section at the top of the ScrollView VStack) with:

```swift
if let phonetic = word.phonetic, !phonetic.isEmpty {
    HStack(alignment: .center, spacing: 8) {
        Text(phonetic)
            .font(.system(size: 16, weight: .regular))
            .tracking(-0.6)
            .foregroundColor(Theme.Colors.textSecondary)
            .underline()
        if word.audioURL != nil {
            Button {
                audioPlayer.toggle(url: word.audioURL)
            } label: {
                Image(systemName: audioPlayer.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
    }
    .padding(.top, isFullHeight ? 10 : 40)
    .padding(.bottom, 16)
} else {
    Spacer(minLength: isFullHeight ? 20 : 60)
}
```

- [x] **Step 2.6: Update WordCardView to own and pass audioPlayer**

In `WordCardView.swift`:

**2.6a** — Add `@State` property after `@State private var motion = MotionManager()`:

```swift
@State private var audioPlayer = WordAudioPlayer()
```

**2.6b** — Update the `WordExpandedContentView` initializer call to pass the player:

```swift
WordExpandedContentView(
    word: word,
    isFullHeight: isFullHeight,
    tiltX: motion.tiltX,
    tiltY: motion.tiltY,
    tiltMultiplier: tiltMultiplier,
    audioPlayer: audioPlayer
)
```

**2.6c** — In `collapsedContent(word:)`, replace the phonetic `Group { ... }` block with:

```swift
Group {
    if let phonetic = word.phonetic, !phonetic.isEmpty {
        HStack(alignment: .center, spacing: 6) {
            Text(phonetic)
                .font(.system(size: 16, weight: .regular))
                .tracking(-0.6)
                .foregroundColor(Theme.Colors.textSecondary)
                .underline()
            if word.audioURL != nil {
                Button {
                    audioPlayer.toggle(url: word.audioURL)
                } label: {
                    Image(systemName: audioPlayer.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
    } else {
        Text(" ")
    }
}
.frame(height: 20)
.padding(.bottom, 14)
```

**2.6d** — Add stop-on-word-change modifier. In the `.onDisappear { motion.stop() }` chain at the bottom of `body`, add:

```swift
.onChange(of: word.id) {
    audioPlayer.stop()
}
```

- [x] **Step 2.7: Build — no errors**

```bash
xcodebuild build -scheme VocabApp -destination 'id=B4403B3A-10A8-43A3-9B61-FD2439ADFEA5' 2>&1 | grep -E '(error:|BUILD)'
```

Expected: `BUILD SUCCEEDED`

- [x] **Step 2.8: Commit**

```bash
git add VocabApp/Services/WordAudioPlayer.swift \
        VocabAppTests/WordAudioPlayerTests.swift \
        VocabApp/Features/Words/Views/WordExpandedContentView.swift \
        VocabApp/Features/Words/Views/WordCardView.swift \
        VocabApp.xcodeproj
git commit -m "feat: add audio pronunciation playback button next to phonetic in word card"
```

---

## Self-Review

**Spec coverage:**
| Feature | Task |
|---|---|
| Multiple definitions in expanded view | Task 1 |
| Etymology section in expanded view | Task 1 |
| Audio playback button (collapsed + expanded) | Task 2 |
| Player stops when swiping to next word | Task 2 (Step 2.6d) |
| Quality score badge | Out of scope — internal metric, not surfaced in UI |

**Type consistency check:**
- `WordAudioPlayer.toggle(url:)` accepts `String?` — matches `word.audioURL: String?` ✓
- `WordExpandedContentView.audioPlayer` has default value so all existing call sites (none pass it explicitly) still compile ✓
- `audioPlayer` is `@State` in `WordCardView` — accessible from both the body (passing to `WordExpandedContentView`) and `collapsedContent(word:)` (which is a `@ViewBuilder` func on the same struct) ✓
- `.onChange(of: word.id)` — `word.id` is `UUID` which is `Equatable` ✓
