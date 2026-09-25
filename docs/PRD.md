# PRD — "Save for Later" Shortlist

**Feature:** Add a "Save for later" shortlist to MatchMate
**Platform:** iOS only
**Status:** Draft for architecture review

---

## 1. Problem
Users browsing the match list often see a profile they're interested in but
aren't ready to Accept or Decline yet. Today the only states are pending,
Accepted, and Declined, so an "interesting, decide later" profile gets lost in
the scrolling list. Users need a lightweight way to set profiles aside and
return to them.

## 2. Goals
- Let a user save any profile to a personal shortlist and revisit it later.
- Make saving effortless (no new full screen to save) and the shortlist easy to
  find (its own place in the app).
- **Primary product intent:** increase conversion from *saved → Accepted* —
  the shortlist should help users commit to matches they were unsure about.
  *(Not measurable in v1 — see Non-goals; treated as functional criteria below.)*

## 3. Non-goals (explicitly out of scope for v1)
- **Analytics / instrumentation.** MatchMate has no analytics layer, so the
  saved→Accepted conversion metric cannot be measured yet. Success is verified
  functionally, not numerically.
- **Cross-device sync** of the shortlist (app is single local user, on-device).
- **Sharing or exporting** the shortlist.
- **Notifications or reminders** about saved profiles.
- **Manual sorting / reordering** of the shortlist.
- **A cap** on the number of saved profiles.

## 4. User stories
- As a user, I want to **save** a profile from the match list via a long-press
  menu, so that I can set it aside without deciding now.
- As a user, I want a **dedicated Saved tab**, so that I can find everything I
  set aside in one place.
- As a user, I want to **unsave** a profile from the long-press menu, so that I
  can remove ones I'm no longer interested in.
- As a user, I want Accepting or Declining a saved profile to **remove it from
  Saved automatically**, so that the shortlist only holds undecided profiles.
- As a user, I want my shortlist to **survive app relaunch and work offline**,
  so that my saved profiles are always there.

## 5. Acceptance criteria (functional, testable)
- **Save:** Long-pressing a profile card on the match list shows a menu with a
  **Save for later** action; tapping it adds the profile to the shortlist.
- **Saved tab:** A new **Saved** tab lists exactly the saved profiles, most
  recently saved first, and updates immediately when a profile is saved/unsaved.
- **Unsave:** Long-pressing a saved (or listed) profile shows an **Unsave**
  action (replacing Save when already saved); tapping it removes it from the
  shortlist.
- **Auto-remove on decision:** Accepting or Declining a saved profile removes it
  from the Saved tab; the decision itself is unchanged in the main list.
- **Save is orthogonal:** Saving does not change a profile's decision state
  (pending/accepted/declined) and vice versa — they are independent.
- **Persistence:** Saved state persists across app relaunch (stored in
  SwiftData) and is visible offline.
- **Cache retention:** A saved profile is retained locally and is **not removed
  by cache trimming** while it remains saved.
- **Empty state:** With nothing saved, the Saved tab shows a clear empty state.

## 6. Open questions / assumed defaults
These were not explicitly confirmed; the PRD assumes the stated default. Flag
any you want changed before `/architect`:
- **Q1 (assumed):** "Saved" is an **independent flag**, orthogonal to the
  decision state — not a fourth mutually-exclusive decision.
- **Q2 (assumed):** Accept/Decline **auto-removes** from Saved (see AC above).
- **Q6 (assumed):** **iOS only**; Android/Web not in scope.
- **Q7 (assumed):** **Single local user, device-local** — no auth/multi-user.
- **Q8 (assumed):** Shortlist **persists across launches and works offline**.
- **Q9 (assumed):** Saved profiles are **retained from cache trim** while saved.
- **Q12 (assumed):** **No cap**; order is **most-recently-saved first**.
