# Low-Level Design (iOS) — "Save for Later"

Source: `docs/PRD.md`, `docs/ARCHITECTURE.md`. Target: **iOS 17.0+**,
SwiftUI + SwiftData + Observation, MVVM + Repository (matching existing code).

## 1. Screens / flows

### RootTabView (NEW)
Replaces the direct `MatchListView` root in `MatchMateApp`. A `TabView` with two
tabs, both receiving the existing environment (`AppDependencies`, `NetworkMonitor`):
- **Matches** tab — existing `MatchListView`. Icon: `heart.text.square`.
- **Saved** tab — new `SavedListView`. Icon: `bookmark`.

### MatchCardView (EXTENDED)
Gains a long-press context menu via `.contextMenu`:
- If `profile.isSaved == false` → **Save for later** (`bookmark`), calls `onToggleSave()`.
- If `profile.isSaved == true` → **Unsave** (`bookmark.slash`), calls `onToggleSave()`.
Card signature grows one closure: `onToggleSave: () -> Void`. Existing tap-to-detail
and `onDecision` are unchanged.

### SavedListView (NEW)
Lists saved profiles (most-recently-saved first). Reuses `MatchCardView` rows so
Save/Unsave/decision all work identically. Shows a `ContentUnavailableView` empty
state when the shortlist is empty. Pull-to-refresh is **not** needed (local data).

## 2. View models

### SavedListViewModeling (NEW protocol — mirrors MatchListViewModeling)
```swift
@MainActor
protocol SavedListViewModeling: Observable, AnyObject {
    var saved: [MatchProfile] { get }
    var errorMessage: String? { get }
    func reload()
    func toggleSave(for profile: MatchProfile)
    func setDecision(_ decision: MatchDecision, for profile: MatchProfile)
    func dismissError()
}
```

### SavedListViewModel (NEW, `@Observable final class`)
- Holds `private(set) var saved: [MatchProfile] = []` and `errorMessage`.
- `reload()` → `saved = try repository.savedProfiles()` (sorted savedAt desc);
  on error sets `errorMessage`.
- `toggleSave(for:)` → `repository.setSaved(!profile.isSaved, for:)` then `reload()`.
- `setDecision(_:for:)` → `repository.setDecision(...)` then `reload()`
  (accept/decline auto-removes the row, so it drops out on reload).
- Called from the view's `.task`/`.onAppear` and after each mutation.

### MatchListViewModel (EXTENDED)
Add `func toggleSave(for profile: MatchProfile)` → `repository.setSaved(!isSaved,…)`
inside the existing error-handled path (same shape as `setDecision`). No state-machine
change; `isSaved` is a property on the model, not part of `MatchListState`.

## 3. Model + repository

### MatchProfile (EXTENDED)
Add two additive, defaulted properties (lightweight SwiftData migration):
```swift
var isSaved: Bool = false
var savedAt: Date? = nil
```
Add to `init` with defaults so existing call sites compile unchanged.

### ProfileRepository (EXTENDED protocol)
```swift
func savedProfiles() throws -> [MatchProfile]           // isSaved == true, savedAt desc
func setSaved(_ saved: Bool, for profile: MatchProfile) throws
```
`SwiftDataProfileRepository`:
- `savedProfiles()` → `FetchDescriptor<MatchProfile>(predicate: #Predicate { $0.isSaved },
  sortBy: [SortDescriptor(\.savedAt, order: .reverse)])`.
- `setSaved(_:for:)` → set `isSaved`; set `savedAt = saved ? .now : nil`; `save()`.
- `setDecision(_:for:)` **modified**: after setting decision, if decision is
  `.accepted` or `.declined`, also clear `isSaved = false`, `savedAt = nil`
  (single atomic `save()`). `.pending` leaves saved untouched.

## 4. State machine — primary flow (save → appears in Saved)

```
[Matches list]
   └─ long-press card ──► .contextMenu
        └─ tap "Save for later"
             └─ MatchListViewModel.toggleSave(for:)
                  └─ repository.setSaved(true)  → isSaved=true, savedAt=now
                       └─ SwiftData save
                            └─ Saved tab reload() shows row (savedAt desc)

[Saved list]
   └─ Accept/Decline on row ──► setDecision(.accepted/.declined)
        └─ repository clears isSaved in same write
             └─ reload() → row removed from Saved
   └─ long-press "Unsave" ──► toggleSave → setSaved(false) → row removed
```

## 5. Dependency wiring (composition root)

`AppDependencies` gains one factory (mirrors `makeMatchListViewModel`):
```swift
func makeSavedListViewModel() -> some SavedListViewModeling {
    SavedListViewModel(repository: repository)
}
```
`MatchMateApp` root becomes:
```swift
RootTabView()
    .environment(dependencies)
    .environment(dependencies.networkMonitor)
```
`RootTabView` builds both child VMs from `dependencies` (same pattern as today).

## 6. Test plan

**Unit (Swift Testing, in-memory SwiftData) — extend `MockProfileRepository`
with `savedProfiles`/`setSaved` and a `setSavedError` hook:**
- `SavedListViewModelTests`:
  - reload surfaces saved profiles sorted most-recent-first.
  - toggleSave adds then removes a profile.
  - accepting a saved profile removes it from `saved`.
  - decision error surfaces via `errorMessage`; dismissError clears it.
- `MatchListViewModelTests` (add):
  - toggleSave calls repository with the negated flag.
- `ProfileRepositoryTests` (real SwiftDataProfileRepository, in-memory):
  - setSaved(true) sets isSaved + savedAt; setSaved(false) clears both.
  - setDecision(.accepted) clears isSaved; setDecision(.pending) does not.
  - savedProfiles returns only saved, ordered savedAt desc.
- `MigrationTests` (add): a store with old `MatchProfile` opens with the two new
  defaulted fields (isSaved=false, savedAt=nil) — verifies additive migration.

**UI (optional, lower priority):** long-press → Save → switch to Saved tab →
row present; Accept on Saved row → row disappears; empty state shows when none saved.
