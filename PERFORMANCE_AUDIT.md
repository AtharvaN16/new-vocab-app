# Performance Audit - VocabApp iOS (April 2026)

This document outlines the performance bottlenecks identified in the current SwiftUI implementation and the proposed remediation steps.

## Executive Summary
The app uses modern SwiftUI (`@Observable`) and SwiftData, which provides a high-performance baseline. However, the custom gesture system and motion-driven UI introduce several "hotspots" that can lead to frame drops and battery drain if not optimized.

---

## 1. High-Priority Bottlenecks

### 1.1. Main-Actor Blockage during Reordering
*   **Location:** `LibraryViewModel.moveUserCollection(from:to:)`
*   **Issue:** The current implementation iterates through the entire collection list and calls `saveCollection` for every item on the `@MainActor`. Each call triggers an individual `modelContext.save()`.
*   **Impact:** Noticeable "hitches" or stuttering during the drag-and-drop animation in the Library.
*   **Remediation:** 
    *   Add `saveCollections([CollectionEntity])` to `CollectionRepository` for batch updates.
    *   Perform the database save once after the array is fully updated, ideally debounced until the user stops dragging.

### 1.2. Redundant Motion Manager Instances
*   **Location:** `WordCardView.swift`
*   **Issue:** Every `WordCardView` initializes its own `MotionManager`, which in turn creates a `CMMotionManager`. Each instance starts a 60Hz update loop.
*   **Impact:** Significant battery drain and CPU overhead when multiple cards are in the view hierarchy (e.g., during transitions or in `WordDetailView`).
*   **Remediation:** 
    *   Implement a **Shared Motion Service** (singleton or environment-injected).
    *   Allow views to subscribe/unsubscribe to motion updates to ensure the hardware sensor is only active when a card is actually visible.

### 1.3. UI Invalidation Storms in Gestures
*   **Location:** `HomeView.dragGesture` and `LibraryView` drag logic.
*   **Issue:** Dragging triggers state changes (`pullDownDistance`, `dragOffset`) that cause the entire View body to re-evaluate at 60-120fps.
*   **Impact:** High "Body Evaluation Count" in Instruments, leading to thermal throttling on older devices.
*   **Remediation:**
    *   Narrow the state scope by moving drag-dependent visuals into leaf views.
    *   Use `.drawingGroup()` for complex stacks involving blurs and shadows (like `PullIndicator`).

---

## 2. Low-Priority / Maintenance Items

### 2.1. Eager Loading in Library
*   **Location:** `LibraryView.swift`
*   **Issue:** Custom collections are rendered inside a standard `VStack` rather than a `LazyVStack`.
*   **Impact:** If a user has 100+ collections, the initial load of the Library tab will be slow as all View identities are created at once.
*   **Remediation:** Switch to `LazyVStack`.

### 2.2. Expensive Visuals in `PullIndicator`
*   **Location:** `Theme.swift`
*   **Issue:** The indicator uses `blur(radius: 14)` and multiple `shadow` layers that are recalculated as the user pulls.
*   **Impact:** GPU overhead.
*   **Remediation:** Use static overlays or pre-rendered assets where possible, or simplify the shadow logic during the active drag phase.

---

## 3. Verification Plan
*   **Baseline:** Profile a **Release build** on a real device using the "SwiftUI" template in Instruments.
*   **Metric:** Target < 16ms per frame (60fps) during the card swipe and collection drag interactions.
*   **Tooling:** Use `Self._printChanges()` during development to ensure only the necessary views are redrawing.
