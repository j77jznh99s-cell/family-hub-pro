---
tags: [project, ios]
updated: 2026-10-07
---
# Family Hub

iPhone app for keeping in touch with family, with lock screen and home screen widgets.

- **Code:** branch `claude/family-hub-widget-1w7cv9`, folder `FamilyHub/` (App, Packages, Widget, `project.yml`).
- **State (from git history, 2026-09-22):** streaks, XP, badges, favorites, progress and personalization added and documented.
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
- **Details:** `FamilyHub/README.md` on that branch (now documents the new feature + its on-device-only limitation).

## Tasks
- [ ] **owner:** build it — `cd FamilyHub/Packages/FamilyHubCore && swift test` for the new
  `CatchUpSummarizerTests` (15 tests, logic-only, no device needed), then `xcodegen` + run on a real
  iPhone (simulator mic/speech is unreliable) and exercise: People row swipe → record ~10s → Generate
  Summary → Save to profile → ask a question; also the Today-tab mic entry point with no person
  preselected. Report back anything that doesn't compile or doesn't work as described — this is
  real, un-run code, not a guarantee.
- [ ] **owner:** confirm next steps (TestFlight? App Store? more features?) — this was the open
  question before the Catch-Up Recorder request came in; still open.
- Note for agents: building and running iOS needs Xcode on a Mac; the cloud sandbox can only edit and review code.
