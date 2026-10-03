---
tags: [project, ios]
updated: 2026-10-03
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
- [ ] **app-engineer:** the widget's ✓ can be lost if the app saves its older in-memory copy first — reload the file before saving (review finding #12).
- [ ] **app-engineer:** new fields on `Person`, `ReachOut`, `Opener`, `LifeContext`, `Preferences` must be optional/defaulted so old files still load (add a note to the README).
- [x] **app-engineer:** correctness review of `FamilyHubCore` (2026-10-03, `5b87ea8`).
- Note for agents: building and running iOS needs Xcode on a Mac; the cloud sandbox can only edit and review code.
