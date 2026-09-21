# Clip Studio — Phase 1 MVP

Upload a long-form video, get back a handful of AI-selected short clips ready to download and share.

## How it works

1. **Upload** — client drops a video into the dashboard (or `POST /api/upload`).
2. **Segment** — `ffmpeg silencedetect` finds natural speech pauses and turns the video into candidate 12–90s segments (falls back to fixed-length windows if there's no clear silence structure).
3. **Score** — for each candidate segment, a few representative frames are pulled and sent to Claude, which scores/titles each one based on visual signal (expression, gesture, on-screen text, energy).
4. **Cut** — the top-scoring segments (`CLIP_COUNT`, default 4) get trimmed into individual `.mp4` files with `ffmpeg`.
5. **Deliver** — the dashboard polls job status and lists finished clips with a thumbnail, title, score, and a download link.

Everything runs as one synchronous pipeline per upload — no queue yet (see Phase 2 below).

### Honest limitation

Claude only sees sampled video frames here, not audio/transcript — there's no speech-to-text step in Phase 1. Segment *boundaries* come from audio silence detection (so cuts land on natural pauses), but the *scoring* of which moments are worth clipping is visual-only. That's good enough to ship this week; a transcript-based pass (Whisper or similar) is the highest-leverage Phase 2 upgrade for scoring accuracy.

## Running locally

```bash
npm install
cp .env.example .env   # fill in ANTHROPIC_API_KEY at minimum
npm start
```

Requires `ffmpeg` + `ffprobe` on PATH. On Debian/Ubuntu: `apt-get install ffmpeg`. On macOS: `brew install ffmpeg`.

Open `http://localhost:3000`. If you set `ACCESS_TOKEN` in `.env`, open `http://localhost:3000/?token=YOUR_TOKEN` once so the dashboard remembers it (stored in `localStorage`).

## Configuration

See `.env.example`. Key ones:

- `ANTHROPIC_API_KEY` — required.
- `ACCESS_TOKEN` — shared secret gating the API and dashboard. **Set this before sending a link to a client** — without it, anyone with the URL can upload/download. Send clients `https://your-app/?token=...`.
- `CLIP_COUNT` — how many clips to produce per video (default 4).
- `MAX_UPLOAD_MB` — upload size cap (default 2GB).

## Storage: local disk + SQLite (deliberately, for Phase 1)

No S3, no Postgres yet. Uploaded videos, generated clips, and the SQLite DB all live under `./uploads`, `./clips`, `./data`. This is the "free alternative" path — it works out of the box with zero cloud setup, but:

- **It does not survive a redeploy** on most platforms (Railway/Heroku containers have ephemeral disks unless you attach a volume). For anything beyond a same-day demo, either attach a persistent volume to those three directories, or do the Phase 2 S3 migration below.
- SQLite is fine for single-instance, low-concurrency use, which is exactly the Phase 1 situation (one operator, one job running at a time).

## Deploying

**Railway (recommended for this week):**
1. New project → deploy from this repo. Railway will pick up the `Dockerfile` automatically (this is what gets you `ffmpeg` — don't skip it). If you instead let it use Nixpacks, `nixpacks.toml` also installs `ffmpeg`.
2. Attach a volume mounted at `/app/data` and set `UPLOAD_DIR=/app/data/uploads`, `CLIPS_DIR=/app/data/clips`, `DATA_DIR=/app/data/db` — otherwise uploads/clips vanish on every redeploy.
3. Set `ANTHROPIC_API_KEY` and `ACCESS_TOKEN` in the environment.

**Anywhere else:** the `Dockerfile` is self-contained (Node + ffmpeg); any container platform (Render, Fly.io, a plain VM) works the same way. `Procfile` is there for Heroku.

## API

- `POST /api/upload` — multipart, field `video`. Returns `202 { jobId }`.
- `GET /api/jobs` — list jobs.
- `GET /api/jobs/:id` — job status + `clips[]` once processing finishes.
- `GET /api/jobs/:id/clips/:clipId/file` — download a clip.
- `GET /api/jobs/:id/clips/:clipId/thumbnail` — clip thumbnail.

All `/api/*` routes require `ACCESS_TOKEN` (header `x-access-token` or `?token=`) when it's configured.

## Phase 2 (production-ready) — not built yet

- **Job queue** (BullMQ/Redis or similar) so uploads don't block on synchronous processing and multiple jobs can run concurrently.
- **S3 (or R2)** for video/clip storage instead of local disk — required for any multi-instance or ephemeral-disk deployment.
- **Postgres** instead of SQLite once there's more than one process touching the DB.
- **Transcript-based scoring** (Whisper) — biggest quality lever for clip selection; combine with the current visual scoring.
- **Payments** — Stripe Checkout + a plan/credits model gating uploads.
- **Multiple format support / validation** hardening (codecs, container edge cases, corrupt uploads).
- **Analytics** — track processing time, clip performance, client usage.
- **Real auth** (per-client accounts) instead of a single shared `ACCESS_TOKEN`.
