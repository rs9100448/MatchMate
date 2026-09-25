# Tickets — "Save for Later" Shortlist (iOS)

Source of truth for `/develop`. Dependency-ordered. Jira: not connected — this
file is the ticket store.

---

### TICKET-1: Add `isSaved` / `savedAt` to MatchProfile
- Type: feature
- Description: Add two additive, defaulted properties to the `@Model MatchProfile`
  (`isSaved: Bool = false`, `savedAt: Date? = nil`) and their `init` defaults, so
  the shortlist has a persistence backing without a new entity.
- Acceptance criteria:
  - `MatchProfile` has `isSaved` (default false) and `savedAt` (default nil).
  - Existing `init` call sites compile unchanged (defaults supplied).
  - Project builds.
- Depends on: none
- Estimate: S

### TICKET-2: Extend ProfileRepository with save + auto-remove
- Type: feature
- Description: Add `savedProfiles()` and `setSaved(_:for:)` to the
  `ProfileRepository` protocol and `SwiftDataProfileRepository`. Modify
  `setDecision` so `.accepted`/`.declined` also clears `isSaved`/`savedAt` in the
  same save; `.pending` does not.
- Acceptance criteria:
  - `savedProfiles()` returns only `isSaved == true`, sorted `savedAt` descending.
  - `setSaved(true,…)` sets `isSaved=true`, `savedAt=now`; `setSaved(false,…)`
    sets `isSaved=false`, `savedAt=nil`.
  - `setDecision(.accepted/.declined,…)` clears saved state; `.pending` leaves it.
  - Saving never mutates `decisionRaw`; toggling save never changes the decision.
- Depends on: TICKET-1
- Estimate: M

### TICKET-3: Repository unit tests (save + auto-remove + ordering)
- Type: test
- Description: Extend `MockProfileRepository` with `savedProfiles`/`setSaved` (+
  `setSavedError`). Add real `SwiftDataProfileRepository` tests (in-memory store).
- Acceptance criteria:
  - setSaved true/false toggles `isSaved` and `savedAt` correctly.
  - setDecision(.accepted) clears saved; setDecision(.pending) does not.
  - savedProfiles returns only saved profiles, ordered most-recent-first.
  - All tests pass.
- Depends on: TICKET-2
- Estimate: M

### TICKET-4: SavedListViewModel + protocol
- Type: feature
- Description: Add `SavedListViewModeling` protocol and `@Observable`
  `SavedListViewModel` (reload, toggleSave, setDecision, dismissError) and the
  `AppDependencies.makeSavedListViewModel()` factory.
- Acceptance criteria:
  - `reload()` populates `saved` from `repository.savedProfiles()`.
  - `toggleSave` / `setDecision` mutate via repository then reload.
  - Errors surface via `errorMessage`; `dismissError` clears it.
  - Factory returns `some SavedListViewModeling`.
- Depends on: TICKET-2
- Estimate: M

### TICKET-5: SavedListViewModel unit tests
- Type: test
- Description: Add `SavedListViewModelTests` using the mock repository.
- Acceptance criteria:
  - reload surfaces saved profiles most-recent-first.
  - toggleSave adds then removes a profile.
  - accepting a saved profile removes it from `saved`.
  - error path surfaces and dismisses.
  - All tests pass.
- Depends on: TICKET-4
- Estimate: S

### TICKET-6: Long-press Save/Unsave on MatchCardView
- Type: feature
- Description: Add an `onToggleSave: () -> Void` closure to `MatchCardView` and a
  `.contextMenu` showing **Save for later** (`bookmark`) when not saved and
  **Unsave** (`bookmark.slash`) when saved. Wire `MatchListView` to call
  `MatchListViewModel.toggleSave(for:)`; add that method to the VM.
- Acceptance criteria:
  - Long-pressing a card shows Save when `isSaved == false`, Unsave when true.
  - Selecting it toggles the profile's saved state (persisted).
  - Existing tap-to-detail and Accept/Decline are unaffected.
- Depends on: TICKET-2
- Estimate: M

### TICKET-7: RootTabView with Matches + Saved tabs
- Type: feature
- Description: Introduce `RootTabView` (`TabView`) as the app root in
  `MatchMateApp`, hosting the existing `MatchListView` (Matches) and new
  `SavedListView` (Saved), with environment injected on the tab view. Build
  `SavedListView` (reuses `MatchCardView` rows, empty state via
  `ContentUnavailableView`).
- Acceptance criteria:
  - App launches into a two-tab UI; Matches tab behaves exactly as before.
  - Saved tab lists saved profiles most-recent-first and shows an empty state
    when none are saved.
  - Both tabs receive `AppDependencies` and `NetworkMonitor`.
  - Saving in Matches makes the profile appear in Saved; Accept/Decline or Unsave
    removes it.
- Depends on: TICKET-4, TICKET-6
- Estimate: M

### TICKET-8: Additive migration test — CLOSED (not applicable)
- Type: test
- Status: **Closed, won't do.**
- Description: Add a `MigrationTests` case proving a store created before the new
  fields opens cleanly with `isSaved=false`, `savedAt=nil`.
- Resolution: The app uses SwiftData with a plain `Schema([MatchProfile.self])`
  and **implicit lightweight migration** — there is no `VersionedSchema` /
  `SchemaMigrationPlan` to exercise. Adding two optional/defaulted properties
  (`isSaved = false`, `savedAt = nil`) is handled automatically by SwiftData, and
  any true store incompatibility is caught by the resilient `PersistenceController`
  (delete + rebuild), which is already observed firing in the test logs. A literal
  "old column-less store → new schema" test would require introducing versioned
  schemas and a migration plan the app deliberately does not have. Closed rather
  than write a test that only appears to verify migration.
- Depends on: TICKET-1
- Estimate: S

---

Suggested order: 1 → 2 → (3, 4 in parallel) → 5 → 6 → 7; 8 any time after 1.
