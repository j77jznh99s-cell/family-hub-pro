---
tags: [project, ios]
updated: 2026-10-06
---
# Family Hub

iPhone app for keeping in touch with family, with lock screen and home screen widgets.

- **Code:** branch `claude/family-hub-widget-1w7cv9`, folder `FamilyHub/` (App, Packages, Widget, `project.yml`).
- **State (from git history, 2026-09-22):** streaks, XP, badges, favorites, progress and personalization added and documented.
- **2026-10-03 code review** (`5b87ea8`, local only, push failed): 5 bugs fixed in `FamilyHubCore` (data file could be
  overwritten after a failed load → now backed up to `familyhub.unreadable.json`; streaks broke on midnight DST in
  Chile etc.; negative XP showed top level), 12 tests added. Full findings: `FamilyHub/REVIEW-2026-10-03.md`.
  **Not compiled or run** (no Swift on the PC).
- **Details:** `FamilyHub/README.md` on that branch.

## Tasks
- [ ] **owner:** confirm next steps (TestFlight? App Store? more features?)
- [ ] **owner:** on a Mac, run `cd FamilyHub/Packages/FamilyHubCore && swift test` to check the 2026-10-03 review fixes (or push so CI runs).
- [ ] **owner:** 3 product questions from the review: (1) send a "text anyone to keep your streak" reminder when nobody is due? (2) people with 30+ day cadences always score "reconnect" (+25, badge) even when on time — only count when overdue? (3) raising the daily goal wipes past streaks — keep, or store the goal per day?
- [ ] **app-engineer:** after a failed load, refuse to save and tell the user (builds on the new backup file).
- [x] **app-engineer:** the widget's ✓ can be lost if the app saves its older in-memory copy first (review #12) — fixed 2026-10-06 with `Store.update` read-modify-write (`b64728a`, local only, not compiled).
- [x] **app-engineer:** `AppModel.upsert` replaced the whole `Person`, so saving an edit sheet opened before a widget ✓ put back the old `lastContacted` — fixed 2026-10-06 with a `Person.applyingEdits` 3-way merge + 4 tests (`a25463d`, local only, not compiled).
- [ ] **app-engineer (optional):** coordinate app/widget file access with `NSFileCoordinator` (the race window is now one read+write).
- [x] **app-engineer:** new fields on `Person`, `ReachOut`, `Opener`, `LifeContext`, `Preferences` must be optional/defaulted so old files still load — done 2026-10-06: tolerant `init(from:)` on all 5 (no field breaks old files today; unknown theme/kind falls back instead of failing the file) + 15 `CompatibilityTests` + README note (`88472e2`, local only, not compiled).
- [ ] **owner (optional):** 3 defaults chosen in `88472e2`, easy to change: an opener with no date counts as stale (gets rewritten); an unknown reach-out kind loads as "late" with its points kept (the kind is lost if saved again); a stored daily goal/cadence of 0 or less loads as 1.
- [x] **app-engineer:** correctness review of `FamilyHubCore` (2026-10-03, `5b87ea8`).
- Note for agents: building and running iOS needs Xcode on a Mac; the cloud sandbox can only edit and review code.
