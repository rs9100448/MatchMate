# Gaps (iOS) — "Save for Later"

Decisions the architecture left to the iOS Lead, each with a recommendation.
**None are blocking** — recommendations are applied in `docs/LLD-ios.md`. Flag any
you want changed before `/develop`.

1. **Save/Unsave label state (Risk #1)** — where is `isSaved` read for the menu?
   *Recommendation:* read `profile.isSaved` directly in `MatchCardView` and show
   Save vs Unsave in the same `.contextMenu`. The card already takes the profile;
   no extra plumbing. Applied.

2. **Saved-tab live update (Risk #2)** — `@Query` vs view-model reload?
   *Recommendation:* use a **view-model `reload()`** (not `@Query`), consistent
   with the existing MVVM style where views never touch SwiftData directly. Trigger
   reload on `.task` and after each mutation. (`@Query` would work but would break
   the pattern and bypass the repository.) Applied.

3. **Additive migration safety (Risk #3)** — will adding two properties migrate?
   *Recommendation:* two **defaulted** properties (`isSaved = false`,
   `savedAt = nil`) are a lightweight SwiftData migration and should open the
   existing store cleanly; the resilient `PersistenceController` is the fallback.
   Add a `MigrationTests` case to prove it. Applied as TICKET.

4. **Empty state (Risk #4)** — copy/appearance for an empty Saved tab.
   *Recommendation:* `ContentUnavailableView` with `bookmark` icon, title
   "No saved profiles," description "Long-press a match and choose Save for later."
   Applied.

5. **Tab root env injection (Risk #5)** — keep `AppDependencies`/`NetworkMonitor`
   in both tabs. *Recommendation:* inject on the `RootTabView`, not per child, so
   both tabs inherit. Applied.

6. **Decision controls on the Saved row** — should Saved rows show Accept/Decline?
   *Recommendation:* **yes** — reuse `MatchCardView` unchanged so a user can decide
   straight from the shortlist (this is exactly the saved→Accepted conversion the
   PRD wants). No separate row type. Applied.

7. **Tab icons/titles** — not specified. *Recommendation:* Matches
   (`heart.text.square`) / Saved (`bookmark`). Cosmetic; change freely.
