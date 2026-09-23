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

## Tasks
- [ ] **owner:** confirm what's next for Clip Studio (deploy? pricing? more features?) so an agent can pick it up
