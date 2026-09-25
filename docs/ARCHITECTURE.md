# Architecture — "Save for Later" Shortlist

Derived from `docs/PRD.md`. Every decision below traces to a PRD goal or an
assumed default recorded there.

## Platform scope note (from PRD)
The PRD scopes this to **iOS only**, **single local user**, **device-local**,
with **no analytics**. Consequences for the standard template:
- **Backend** — *no changes.* Saved state is a local user preference; the only
  network dependency (RandomUser API) is a read-only source of profiles and has
  no concept of "saved." Nothing is sent server-side. (PRD non-goals: no sync,
  no sharing.)
- **Web / Android** — *out of scope* per PRD. No design produced; the data-model
  and API-contract sections below are the local (on-device) equivalents.

So the real architecture is entirely **on-device iOS**.

---

## 1. Component overview

```
                ┌─────────────────────────────────────────────┐
                │                MatchMateApp                   │
                │  RootTabView  (NEW — replaces direct list)    │
                └───────────────┬───────────────┬──────────────┘
                                │               │
                     ┌──────────▼──────┐  ┌─────▼───────────┐
                     │  Matches tab    │  │   Saved tab      │  (NEW)
                     │  MatchListView  │  │   SavedListView  │
                     └────────┬────────┘  └────────┬────────┘
                              │                    │
                   ┌──────────▼────────┐  ┌────────▼───────────┐
                   │ MatchListViewModel│  │ SavedListViewModel │  (NEW)
                   └──────────┬────────┘  └────────┬───────────┘
                              │                    │
                              └─────────┬──────────┘
                                        │
                            ┌───────────▼────────────┐
                            │   ProfileRepository     │  (extended)
                            │  + setSaved / savedProfiles
                            │  + decision clears saved │
                            └───────────┬────────────┘
                                        │
                              ┌─────────▼─────────┐
                              │  SwiftData store  │
                              │  MatchProfile     │  (+ isSaved, savedAt)
                              └───────────────────┘
```
New pieces: `RootTabView`, `SavedListView`, `SavedListViewModel`. Extended:
`MatchProfile`, `ProfileRepository`. `MatchCardView` gains a long-press context
menu. No new networking, no new persistence stack.

## 2. Data flow — primary story ("save a profile, see it in Saved")

1. User long-presses a card in **Matches** → context menu shows **Save for later**.
2. `MatchListViewModel.setSaved(true, for:)` → `ProfileRepository.setSaved(true,…)`.
3. Repository sets `profile.isSaved = true`, `profile.savedAt = .now`, saves context.
4. `@Observable` MatchProfile mutation + SwiftData → **Saved tab** (driven by a
   `@Query`/fetch sorted by `savedAt` desc) reflects it immediately.
5. Later, user Accepts the saved profile → `setDecision(.accepted,…)` also clears
   `isSaved`/`savedAt` in the same write → it leaves the Saved tab automatically.

## 3. API contracts (on-device repository, not network)

No network endpoints. The "contract" is the `ProfileRepository` protocol:

```swift
// existing
func cachedProfiles() throws -> [MatchProfile]
func fetchAndStore(page: Int, pageSize: Int) async throws -> [MatchProfile]
func setDecision(_ decision: MatchDecision, for profile: MatchProfile) throws

// NEW
func savedProfiles() throws -> [MatchProfile]          // sorted by savedAt desc
func setSaved(_ saved: Bool, for profile: MatchProfile) throws
```
Behavioral contract:
- `setSaved(true,…)` sets `isSaved = true`, `savedAt = .now`.
- `setSaved(false,…)` sets `isSaved = false`, `savedAt = nil`.
- `setDecision(.accepted|.declined,…)` **also** clears `isSaved`/`savedAt`
  (auto-remove per PRD AC). `.pending` does not.
- Saving never mutates `decisionRaw`; decision never mutates `isSaved` except the
  auto-remove above (orthogonality per PRD AC).

## 4. Data model

Extend the existing `MatchProfile` (`@Model`). Two additive fields — safe for the
existing SwiftData store (new optional/defaulted properties, lightweight migration):

| Field | Type | Purpose |
|---|---|---|
| `isSaved` | `Bool` (default `false`) | shortlist membership flag |
| `savedAt` | `Date?` (default `nil`) | ordering: most-recently-saved first |

`isSaved` is deliberately **independent of `decisionRaw`** (PRD Q1). `savedAt`
gives the "most-recently-saved first" order (PRD Q12) without a separate entity.

## 5. Tech choices (each tied to a PRD goal)

| Choice | Justification (PRD link) |
|---|---|
| Add `isSaved`/`savedAt` to `MatchProfile`, not a new `SavedItem` entity | Single-user, device-local (Q7); avoids join/relationship complexity; a flag is enough. |
| `RootTabView` (TabView) wrapping existing list + new Saved tab | PRD Q4: shortlist lives in its **own tab**. |
| Long-press context menu on `MatchCardView` for Save/Unsave | PRD Q3/Q5: save and unsave via long-press. |
| Saved tab backed by SwiftData query sorted `savedAt` desc | Persistence + offline (Q8) and most-recent-first order (Q12) for free. |
| Auto-clear saved inside `setDecision` (one write) | Guarantees "Accept/Decline removes from Saved" (AC) atomically — no drift. |
| Reuse `ProfileRepository` as the single write path | Keeps orthogonality + auto-remove rules in one testable place. |

## 6. Cross-cutting

- **Error handling** — reuse `AppError.persistence`; `setSaved` failures surface
  through the same view-model error channel as `setDecision` today.
- **Caching / retention** — profiles are never deleted by current code (`upsert`
  only inserts/updates; image trim touches images only). **Requirement for any
  future profile-eviction:** must exclude `isSaved == true` (PRD Q9). Add this as
  an invariant/comment now so a later cache-trim doesn't silently violate it.
- **Offline** — saved state is local; Save/Unsave and the Saved tab work fully
  offline (consistent with existing offline behavior). PRD Q8.
- **Telemetry** — none. Analytics is a PRD non-goal; saved→Accepted conversion is
  **not instrumented** in v1.
- **Security / privacy** — no new data leaves the device; no new permissions.

## 7. Risks / open questions

1. **Toggle label state** — the menu must show **Save** vs **Unsave** based on
   `isSaved`; iOS Lead should define where that state read happens (card vs VM).
2. **Live update of Saved tab** — must confirm the Saved tab uses a SwiftData
   `@Query`/observed fetch so it reflects saves/unsaves and auto-removes without
   manual refresh. iOS Lead to specify the exact mechanism.
3. **Existing store migration** — adding two defaulted properties should be a
   lightweight SwiftData migration, but the app has a history of a rename-related
   store crash; iOS Lead must verify the additive change migrates cleanly (the
   resilient `PersistenceController` is the safety net).
4. **Empty state** — PRD requires a Saved empty state; not yet designed (iOS Lead).
5. **Tab introduction risk** — root changes from a single view to a `TabView`;
   environment injection (`AppDependencies`, `NetworkMonitor`) must be preserved
   for both tabs.

---

Architecture ready — review it, then run `/lead-ios` (or the equivalent
per-platform lead).
