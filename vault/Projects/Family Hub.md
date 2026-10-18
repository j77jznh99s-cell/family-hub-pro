---
tags: [project, ios]
updated: 2026-10-15
---
# Family Hub

iPhone app for keeping in touch with family, with lock screen and home screen widgets.

- **Code:** branch `claude/family-hub-widget-1w7cv9`, folder `FamilyHub/` (App, Packages, Widget, `project.yml`).
- **State (from git history, 2026-09-22):** streaks, XP, badges, favorites, progress and personalization added and documented.
- **2026-10-03 code review** (`5b87ea8`, local only, push failed): 5 bugs fixed in `FamilyHubCore` (data file could be
  overwritten after a failed load → now backed up to `familyhub.unreadable.json`; streaks broke on midnight DST in
  Chile etc.; negative XP showed top level), 12 tests added. Full findings: `FamilyHub/REVIEW-2026-10-03.md`.
  **Not compiled or run** (no Swift on the PC).
- **Catch-Up Recorder, built 2026-10-07 (`0f097d3`) on owner request** (saw an ad for a $200 AI
  wearable recorder, asked if something similar could live on their phone instead). Tap-to-record a
  conversation recap (not always-on — iOS blocks background mic access, which is exactly why that
  hardware exists as a separate device; flagged honestly in chat and in the README). On-device
  speech-to-text (`RecordingService.swift`), then Claude turns the transcript into a summary, a
  suggested note for that person's profile (feeds back into the existing opener-writing system), and
  a follow-up checklist (`CatchUpSummarizer.swift`, mirrors `OpenerGenerator`'s exact request/error
  pattern, reuses `OpenerError`). Also a free-text "ask about this conversation" box. Entry points:
  swipe-left on a person in **People**, or the mic button in **Today**'s toolbar. Privacy matches the
  app's existing stance exactly: only first name/relationship/notes ever sent to Claude (tested —
  phone numbers/last names asserted absent from the built prompt), no raw audio ever leaves the
  device or gets persisted, only transcript text. I reviewed the full diff myself before recording
  this done: 11 files, ~800 lines, follows every existing convention (tolerant JSON decode in
  `Store.swift`, same Keychain/Prefs usage as the rest of the app). **Completely unverified** —
  no Swift toolchain or Xcode in the sandbox, so none of it has been compiled, let alone run.
- **Branches diverged (found 2026-10-10):** the cloud's Catch-Up Recorder (`0f097d3`, on GitHub) and the local PC
  runs' fixes (`5b87ea8` … `88472e2`, local only, never pushed) are on two different tips of
  `claude/family-hub-widget-1w7cv9`. **Merged locally 2026-10-14 (`1a32998`, not pushed, not compiled):** one
  `Models.swift` conflict, both sides kept; `CatchUpNote` now decodes tolerantly like the other stored types.
- **Details:** `FamilyHub/README.md` on that branch (now documents the new feature + its on-device-only limitation).

## Tasks
- [x] **app-engineer:** merge the local `claude/family-hub-widget-1w7cv9` (`88472e2`) with `origin/claude/family-hub-widget-1w7cv9` (`0f097d3`); check the Catch-Up Recorder's `Store.swift` changes against the local `Store.update` and tolerant-decoding changes — done 2026-10-14 (`1a32998`, local only, not compiled).
- [x] **app-engineer:** Catch-Up Recorder: a recorded transcript is lost if summarising fails or there's no API key — done 2026-10-15 (`9a3e9cb`, local only, not compiled): transcript saved as a note when recording stops (also when recognition ends on its own), summary later fills the same note; new "Earlier catch-ups" list in the recorder ("Not summarised yet", tap to retry, swipe to delete).
- [x] **app-engineer:** Catch-Up Recorder: ticked follow-up items aren't saved — done 2026-10-15 (`9a3e9cb`): new `CatchUpNote.checkedActionItems` (decodes to empty on old files), saved via `Store.update`; a new summary clears old ticks. Tests added, not run.
- [x] **app-engineer:** Catch-Up Recorder: the profile note's "Saved" state isn't stored, so reopening an old catch-up could add the same note to the profile twice — done 2026-10-17 (`ad6ee49`, local only, not compiled): new `CatchUpNote.noteSavedToPersonID` (nil on old files), set in the same `Store.update` write as the append (`AppData.saveCatchUpNoteToProfile`, a no-op if already saved); a new summary or a different person can be saved again. 5 tests added/extended, not run.
- [ ] **app-engineer (small):** Catch-Up Recorder: show the live transcript while recording (today it appears only after Stop).
- [ ] **owner:** saved catch-ups are listed only inside the recorder — enough, or also on each person's page? And swipe-to-delete there has no undo — keep it?
- [ ] **owner:** the new "Catch-up" swipe on People (`PeopleView.swift:22–25`) probably replaces swipe-to-delete, and there's no Edit button, so people may no longer be deletable there. Pick: Delete in the swipe, an Edit button, or move Catch-up to the leading edge. Unverified on device.
- [ ] **owner:** build it — `cd FamilyHub/Packages/FamilyHubCore && swift test` for the new
  `CatchUpSummarizerTests` (15 tests, logic-only, no device needed) and the 2026-10-03/06 review fixes, then
  `xcodegen` + run on a real iPhone (simulator mic/speech is unreliable) and exercise: People row swipe → record
  ~10s → Generate Summary → Save to profile → ask a question; also the Today-tab mic entry point with no person
  preselected. Report back anything that doesn't compile or doesn't work as described — this is
  real, un-run code, not a guarantee.
- [ ] **owner:** confirm next steps (TestFlight? App Store? more features?) — still open.
- [ ] **owner:** 3 product questions from the review: (1) send a "text anyone to keep your streak" reminder when nobody is due? (2) people with 30+ day cadences always score "reconnect" (+25, badge) even when on time — only count when overdue? (3) raising the daily goal wipes past streaks — keep, or store the goal per day?
- [ ] **app-engineer:** after a failed load, refuse to save and tell the user (builds on the new backup file).
- [x] **app-engineer:** the widget's ✓ can be lost if the app saves its older in-memory copy first (review #12) — fixed 2026-10-06 with `Store.update` read-modify-write (`b64728a`, local only, not compiled).
- [x] **app-engineer:** `AppModel.upsert` replaced the whole `Person`, so saving an edit sheet opened before a widget ✓ put back the old `lastContacted` — fixed 2026-10-06 with a `Person.applyingEdits` 3-way merge + 4 tests (`a25463d`, local only, not compiled).
- [ ] **app-engineer (optional):** coordinate app/widget file access with `NSFileCoordinator` (the race window is now one read+write).
- [x] **app-engineer:** new fields on `Person`, `ReachOut`, `Opener`, `LifeContext`, `Preferences` must be optional/defaulted so old files still load — done 2026-10-06: tolerant `init(from:)` on all 5 (no field breaks old files today; unknown theme/kind falls back instead of failing the file) + 15 `CompatibilityTests` + README note (`88472e2`, local only, not compiled).
- [ ] **owner (optional):** 3 defaults chosen in `88472e2`, easy to change: an opener with no date counts as stale (gets rewritten); an unknown reach-out kind loads as "late" with its points kept (the kind is lost if saved again); a stored daily goal/cadence of 0 or less loads as 1.
- [x] **app-engineer:** correctness review of `FamilyHubCore` (2026-10-03, `5b87ea8`).
- Note for agents: building and running iOS needs Xcode on a Mac; the cloud sandbox can only edit and review code.
