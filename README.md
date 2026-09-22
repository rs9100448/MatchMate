# MatchMate

A small matrimonial-style iOS app. It fetches profiles from the [Random User API](https://randomuser.me/documentation), shows them as cards in a paginated list, opens a full profile on tap, and lets you **Accept / Decline** from both the list and the detail screen. Decisions are stored locally, work offline, survive relaunch, and stay perfectly in sync between list and detail.

Built with **SwiftUI + SwiftData + async/await**, targeting **iOS 17+**.

---

## How to run

1. Open `MatchMate.xcodeproj` in **Xcode 16 or newer** (developed on Xcode 26).
2. Select the **MatchMate** scheme and any iOS 17+ simulator (e.g. iPhone 17 Pro).
3. `Cmd+R` to run, `Cmd+U` to run the unit tests.

No third-party dependencies, no package resolution, no setup steps.

From the command line:

```bash
xcodebuild test -project MatchMate.xcodeproj -scheme MatchMate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

---

## Architecture sketch

**MVVM + Repository**, with a single composition root for dependency injection.

```
┌──────────────┐     ┌───────────────────┐     ┌────────────────────┐
│  SwiftUI     │────▶│    ViewModels     │────▶│   ProfileRepository │
│  Views       │     │ (@Observable,     │     │   (protocol)        │
│              │◀────│  @MainActor)      │◀────│                     │
└──────────────┘     └───────────────────┘     └─────────┬──────────┘
                                                          │
                                      ┌───────────────────┴───────────────────┐
                                      │                                       │
                                ┌─────▼──────┐                        ┌───────▼───────┐
                                │ ProfileAPI │                        │  SwiftData     │
                                │ (protocol) │                        │  ModelContext  │
                                │ URLSession │                        │  MatchProfile  │
                                └────────────┘                        └───────────────┘
```

Layers, and why the boundaries sit where they do:

| Layer | Type(s) | Responsibility |
|-------|---------|----------------|
| **App / DI** | `MatchMateApp`, `AppDependencies` | Composition root. Builds the `ModelContainer`, network monitor, repository, and ViewModel factories. Nothing else constructs its own collaborators. |
| **Views** | `MatchListView`, `MatchCardView`, `MatchDetailView`, `DesignSystem/*` | Thin SwiftUI. No networking or persistence logic — they call the ViewModel and render state. |
| **ViewModels** | `MatchListViewModel`, `MatchDetailViewModel` | `@Observable @MainActor`. Own the UI state machine: loading, pagination, decisions, error surfacing. UI-free, so they're unit-tested directly. |
| **Repository** | `ProfileRepository` (protocol) → `SwiftDataProfileRepository` | The domain boundary. Turns "fetch page N" / "set decision" into API calls + SwiftData upserts. The ViewModels never see `URLSession`, `ModelContext`, or the API DTOs. |
| **Networking** | `ProfileAPI` (protocol) → `RandomUserAPI`, `HTTPClient` (protocol) → `URLSessionHTTPClient`, `NetworkMonitor` | `URLSession` + `async/await`. Two levels of protocol so the API and the transport can each be stubbed in tests. |
| **Models** | `MatchProfile` (`@Model`), `MatchDecision`, `RandomUser*` DTOs | Domain vs. wire separation. DTOs mirror the JSON; `MatchProfile` is the persisted source of truth. Mapping lives in one place (`RandomUser.asDomain`). |

Every dependency is injected through a protocol, so each layer is replaceable and testable in isolation.

---

## Architecture decisions & trade-offs

The brief asks for **"MVVM + repository (or similar)"**, and that's exactly what this is. I considered full **Clean Architecture** (pure domain entities, a Use Case/Interactor layer, and separate Domain/Data/Presentation modules) and consciously chose *not* to adopt all of its ceremony for an app this size. This section documents that decision so the choice reads as deliberate, not accidental.

**What this design borrows from Clean Architecture (the principles that matter):**

- **The Dependency Rule via inversion.** Every boundary is a protocol (`ProfileRepository`, `ProfileAPI`, `HTTPClient`, `NetworkMonitoring`); inner layers depend on abstractions, and concrete frameworks (`URLSession`, `ModelContext`) are injected from a single composition root. Nothing UI-facing imports a networking or persistence framework.
- **Separation of concerns** across Presentation → ViewModel → Repository → Data.
- **Wire/domain separation** — API DTOs are decoupled from the app model and mapped in one place.
- **Testability first** — the reason those boundaries exist at all.

**Where it intentionally stops short of *strict* Clean Architecture, and why:**

1. **No separate Use Case layer.** The ViewModels talk to the repository directly. For two screens, use cases like `LoadMatchesUseCase` / `SetDecisionUseCase` would be near-empty pass-throughs — indirection without payoff. I'd add them the moment business rules grew beyond "fetch a page" and "set a flag."
2. **The domain model is a SwiftData `@Model`, not a framework-free `struct`.** This is the one real deviation from Clean Architecture's "entities depend on nothing" rule, and it's a *feature*, not an oversight: because a `@Model` is a reference type that's `Observable`, the list and detail screens share **one instance**, so the "list and detail never disagree, no manual refresh" requirement falls out for free. A purist version would use pure structs + a persistence model + mappers, and then reintroduce cross-screen sync manually through a shared observable store. That's more layers and more moving parts to reproduce behaviour I already get natively — a poor trade at this scale.
3. **One module, folder-separated, not multiple SPM targets.** The layering is enforced by discipline and protocols rather than module boundaries. Splitting into `Domain` / `Data` / `Presentation` packages is a mechanical follow-up if the codebase grows.

**When I *would* go stricter:** multiple feature teams touching the same layers, business logic complex enough to warrant use cases, a second data source or a domain that must outlive the persistence framework, or a hard requirement to compile the domain without UIKit/SwiftData. None of those apply to a two-screen assignment, so the extra structure would read as over-engineering rather than cleanliness.

In short: this is a **pragmatic, principle-driven MVVM + Repository** — Clean Architecture's *dependency discipline* without its *module ceremony* — sized to the problem.

---

## Database choice: **SwiftData** (and why)

I chose **SwiftData** over Core Data:

- **Right fit for iOS 17+.** The assignment sets the floor at iOS 17, which is exactly where SwiftData is available. It's Apple's current, recommended persistence framework.
- **Less boilerplate, fewer footguns.** The model is a plain `@Model` class — no `.xcdatamodeld`, no `NSManagedObject` subclassing, no manual `NSFetchRequest` strings. Type-safe `#Predicate` and `FetchDescriptor` replace stringly-typed queries.
- **Observation for free — and it's the key to the sync requirement.** `@Model` objects are reference types that conform to `Observable`. Because the list and the detail screen hold the *same* `MatchProfile` instance, mutating its `decision` in one place re-renders the other automatically (details below).
- **Trivial in-memory store for tests.** `ModelConfiguration(isStoredInMemoryOnly: true)` gives every test a clean, disk-free store, so the ViewModel tests run against the real persistence + upsert code rather than a fake of it.

Core Data would also have worked; SwiftData simply removes ceremony and pairs naturally with the SwiftUI/Observation stack this app is built on.

---

## How pagination works

- Real pagination against the API's `page` parameter: `?page=N&results=10&seed=matchmate`.
- The seed is fixed to `matchmate` so results stay stable across a review session.
- **Infinite scroll:** each row calls `loadNextPageIfNeeded(currentItem:)` as it appears. When the visible row is within 3 of the end, the ViewModel fetches the next page. A `isLoadingNextPage` guard prevents duplicate/concurrent fetches, and `canLoadMore` stops paging when a page returns nothing new.
- **Pull-to-refresh** re-fetches page 1 and resets the paging cursor.
- Newly fetched pages are **merged** into the store (upsert by id), never blindly replaced — so scrolling never wipes a decision you already made.

## How status sync works (one source of truth)

This is the core of the assignment, so it's worth being explicit.

- **`login.uuid` is the stable profile id** and the SwiftData `@Attribute(.unique)` key. The same person is always the same row, across pages and refreshes.
- **One object, two screens.** The list fetches `[MatchProfile]` (live `@Model` objects). Tapping a card pushes the detail screen with the **same instance** (SwiftUI value-based navigation carries the object, not a copy).
- **Accept/Decline writes through the repository** → mutates `profile.decision` → `context.save()`. Because `MatchProfile` is `Observable` and both screens read that one object:
  - Action on **detail** updates the detail UI immediately, and the list card already shows the new status when you navigate back — **no manual refresh, no notifications, no re-fetch.**
  - Action on the **list** updates that card in place.
- **Upsert preserves decisions.** When a page is re-fetched (refresh, or re-encountering a profile), `SwiftDataProfileRepository.upsert` updates the mutable fields but **never overwrites `decision`**. This is covered by a dedicated test.
- **Survives relaunch.** Decisions are persisted to the on-disk SwiftData store, so they're still there after an app kill.

## Screen state (state machine)

The list screen is driven by a single explicit state value rather than a spread of booleans:

```swift
enum MatchListState {
    case idle
    case loading                       // first load, nothing to show yet
    case loaded([MatchProfile])        // content on screen, settled
    case paginating([MatchProfile])    // content on screen, fetching next page
    case empty                         // finished, nothing to show
    case failed(message:, cached:)     // error; cached content shown behind a banner if present
}
```

- The **ViewModel** is the only thing that transitions the state; the **View** just switches over it and renders the matching branch. Illegal combinations (e.g. "loading *and* error *and* empty") are unrepresentable.
- `failed` carries the `cached` profiles so a failure never blanks the list — with content it shows an inline banner, without content it shows a full-screen error+retry.
- `profiles` and `errorMessage` remain as thin derived accessors off the state, so views and tests read them directly.
- The detail screen has no async load phases (it just renders a profile and writes decisions), so it intentionally has no state enum — adding one would be a single-case type.

## Offline behavior

- **Offline-first load:** the list renders cached profiles immediately from SwiftData, *then* refreshes from the network when connectivity allows.
- `NetworkMonitor` (`NWPathMonitor`) drives an offline banner and prevents pointless network attempts while disconnected.
- **Accept/Decline works fully offline** — it's just a local DB write. Your decisions persist and will be there next launch.
- **Photos are cached too** — a two-tier `ImageCache` (`NSCache` in memory + a small disk cache keyed by a SHA-256 of the URL) means previously seen images render offline and scroll without flicker, not just the text data.
- If there's no cache *and* no connectivity, a clear empty state explains why.

## Error handling

- A single `AppError` type (`offline`, `requestFailed`, `decodingFailed`, `transport`, `persistence`, `unknown`) with friendly, user-facing messages. `AppError.map(_:)` normalizes `URLError` / `DecodingError` / thrown errors into it.
- **API errors** (non-2xx, decode failures, transport) surface as a dismissible banner while cached content stays visible.
- **DB errors** from `context.save()` / `fetch` are wrapped as `.persistence` and surfaced rather than swallowed.
- **Connectivity** is handled distinctly from failure: being offline with a warm cache is a normal state, not an error.

---

## Testing

Unit tests target the ViewModels and the real repository (in-memory SwiftData), using Swift Testing:

- First-page load populates profiles; pagination appends in order.
- Prefetch triggers the next page only near the bottom.
- Accept persists and survives a reload from the store.
- **Re-fetch preserves an existing decision** (upsert never clobbers status).
- **List and detail share one source of truth** (a decision on detail is visible through the list VM's object).
- Offline: empty cache surfaces an offline message and never hits the network; a warm cache shows without error; Accept/Decline still works.
- API failure surfaces an error message; dismiss clears it.
- DTO → domain mapping and `AppError` mapping.

Testability comes from the protocol boundaries: `ProfileAPI`, `HTTPClient`, `NetworkMonitoring`, and `ProfileRepository` are all injectable.

---

## Known gaps / things I'd add with more time

- **Image cache eviction policy** — photos use a two-tier cache (`NSCache` in memory + a small on-disk cache). The memory tier evicts under pressure automatically; the disk tier isn't size-capped or aged out yet, so a production app would add an LRU/trim policy.
- **UI / snapshot tests** — current coverage is at the ViewModel/repository layer.
- **Richer pagination end-state** — with a fixed seed the API is effectively infinite; a real backend would signal the last page.
- **Versioned schema migration** — the store currently recovers from an incompatible/corrupt store by resetting it (safe here since data is API-backed). A production app would add a `SchemaMigrationPlan` to preserve decisions across model changes.
- **Retry/backoff** policy on transient network failures.
- **Localization** — strings are inline English; they'd move to a String Catalog.
- **Accessibility polish** — basics are in place (labels on the status pill), but a full VoiceOver pass would help.

## Tech notes

- **iOS 17.0** minimum deployment target.
- **Swift 5 language mode** with modern concurrency (`async/await`, `@MainActor`, `Sendable`). The code is written to be Swift 6 concurrency-friendly; flipping the language mode is a small follow-up.
- **No third-party libraries** — `URLSession`, SwiftData, and SwiftUI cover everything cleanly, so adding dependencies wasn't justified.
- Project uses Xcode's **file-system-synchronized groups**, so the folder structure on disk *is* the project structure.

## Rough hours spent

~5–6 hours (architecture, implementation, tests, and this README).
