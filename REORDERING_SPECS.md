# Feature Requirement Document: Fluid Grid Reordering (iOS Home Screen Parity)

## 1. Executive Summary
The objective is to implement a reordering system for the Library grid that matches the fluidity, reliability, and visual polish of the iOS Home Screen (Springboard). The current implementation is broken; cards frequently disappear or glitch during transitions.

## 2. Technical Post-Mortem (How I Messed Up)
*   **Unstable View Identity:** I attempted to manage "live" reordering by modifying the source array (`userCollections`) directly within the `isTargeted` closure. This caused the `LazyVGrid`'s `ForEach` to re-evaluate mid-drag, leading to view identity loss and the "disappearing" effect.
*   **Misuse of `onAppear` in Previews:** I relied on `.onAppear` inside a `.draggable` preview to set the `draggingCollection` state. This is non-deterministic and often fails to trigger or triggers too late, causing the source card to flicker or vanish without a valid ghost being rendered.
*   **Race Conditions:** I used `withAnimation` on state changes that were being driven by high-frequency drag events without a throttling or debouncing mechanism, leading to layout engine thrashing.
*   **Poor Feedback Loop:** I failed to verify the state of the view hierarchy during the animation, prioritizing a "quick fix" over a structurally sound gesture system.

## 3. Functional Requirements
### 3.1 Ghosting & Preview
*   **Source Hiding:** The source card must transition to `opacity: 0` or a "placeholder" state immediately upon a successful lift.
*   **Ghost Fidelity:** The drag preview (ghost) must be a high-fidelity snapshot of the card, with correct corner radii and no clipping of shadows or borders.
*   **Delete Icon Suppression:** All "minus" icons must be removed from the entire grid the moment a drag is initiated.

### 3.2 Interaction Logic (The "Flow" Effect)
*   **Collision Detection:** As the ghost moves over a target card, the target must "snap" into the ghost's previous position.
*   **Z-Index Management:** The dragging item must always remain on the top-most layer of the `ZStack` until the drop is completed.
*   **Haptic Integrity:** Tactile feedback must occur precisely when a layout shift is committed, not during every frame of the drag.

## 4. Technical Specifications
*   **Framework:** SwiftUI (iOS 26+).
*   **API Preference:** Modern `Transferable` + `dropDestination` OR a custom `DragGesture` with `GeometryReader` if the native API continues to exhibit layout jitter.
*   **State Control:** Use a stable identifier (UUID) that does not change during the move operation to prevent `ForEach` from losing the view's lifecycle.
*   **Animation:** Must use `interactiveSpring` for the tracking phase and `spring(response:dampingFraction:)` for the insertion phase.

## 5. Acceptance Criteria
1.  **Zero Disappearance:** No card should ever vanish from the screen during a drag.
2.  **No Clipping:** The drag preview must maintain its full visual bounds.
3.  **Visual Continuity:** If the drag is cancelled, the card must animate smoothly back to its original position rather than snapping or teleporting.
4.  **Parity:** The experience must be indistinguishable from moving an app icon on an iPhone.
