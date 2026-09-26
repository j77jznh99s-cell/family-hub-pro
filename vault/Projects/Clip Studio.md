---
tags: [project, web-app]
updated: 2026-09-23
---
# Clip Studio

AI video clipper: upload a long video and get back AI-selected short clips (ffmpeg segmentation,
optional Whisper transcripts, Claude scoring, captions, download).

- **Code:** branch `claude/video-clip-detection-mvp-g18ggk` (the repo's current default branch), repo root (`src/`, `public/`, `tests/`).
- **State (from git history):** Phase 1 MVP and hardening done (2026-09-21); Phase 2 optional Postgres, Redis queue, S3, Whisper captions and Stripe billing added (2026-09-21).
- **Details:** the branch's `README.md`.
- **Newest code (found 2026-09-26):** branch `claude/hourly-project-processing-ejbqs4` has 32 more commits (23–24 Sep) from the
  hourly session: an **AI presenter** (trend research, sourced scripts, HeyGen digital-twin videos, captions, a weekly content
  calendar, `--fill-week`, a pre-posting check, spend tracking), deploy health check `/healthz?deep=1`, a security pass
  (constant-time tokens, failed-auth limit), and Node 22. Not merged into `claude/video-clip-detection-mvp-g18ggk` yet.
- **Pages from that session:** Clip Studio https://claude.ai/artifact/DkWmfS4mvKmSuHEuVsf29p · AI Presenter https://claude.ai/artifact/7rUQvzaSF1y57PPhGFRRfG · Project Home https://claude.ai/artifact/CSXkQRWHXxfADK8jCswZmf

## Tasks
- [ ] **qa-tester:** review the hourly branch (tests, CI, bugs); the owner decides whether to merge it.
- [ ] **owner:** confirm what's next for Clip Studio (deploy? pricing? more features?) so an agent can pick it up
