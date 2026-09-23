# Clip Studio

Upload a long-form video, get back a handful of AI-selected short clips ready to download and share.

## How it works

1. **Upload** — client drops a video into the dashboard (or `POST /api/upload`).
2. **Segment** — `ffmpeg silencedetect` finds natural speech pauses and turns the video into candidate 12–90s segments (falls back to fixed-length windows if there's no clear silence structure).
3. **Transcribe** *(optional — see below)* — audio is pulled and sent to Whisper for a timestamped transcript.
4. **Score** — for each candidate segment, Claude scores/titles it using the transcript text (when available) plus a few sample frames — or frames alone if no transcript.
5. **Cut** — the top-scoring segments (`CLIP_COUNT`, default 4) get trimmed into individual `.mp4` files with `ffmpeg`, with captions burned in when a transcript is available.
6. **Store** — clips/thumbnails land on local disk by default, or get uploaded to S3 if configured.
7. **Deliver** — the dashboard polls job status and lists finished clips with a thumbnail, title, score, and a download link.

Every subsystem beyond the core pipeline — Postgres, Redis-backed queue, S3, Whisper captions, Stripe billing — is **optional and additive**: leave its env vars unset and the app behaves exactly like the zero-config Phase 1 build (SQLite, in-process queue, local disk, frame-only scoring, unlimited uploads). Set the relevant env var(s) and that subsystem turns on with no code changes.

## Running locally

```bash
npm install
cp .env.example .env   # fill in ANTHROPIC_API_KEY at minimum
npm start
```

Requires `ffmpeg` + `ffprobe` on PATH. On Debian/Ubuntu: `apt-get install ffmpeg`. On macOS: `brew install ffmpeg`.

Open `http://localhost:3000`. If you set `ACCESS_TOKEN` in `.env`, open `http://localhost:3000/?token=YOUR_TOKEN` once so the dashboard remembers it (stored in `localStorage`).

Run the test suite with `npm test` (uses SQLite + the in-process queue by default; see below for running it against real Postgres/Redis).

## Configuration

Full list with comments in `.env.example`. The only required var is `ANTHROPIC_API_KEY`. `ACCESS_TOKEN` is technically optional but **you should set it before sending a link to anyone** — without it, the API and dashboard are open to anyone with the URL. Send clients `https://your-app/?token=...`.

### Vertical clips

Set `CLIP_ASPECT=9:16` (or `1:1`, `4:5`, any `W:H`) to center-crop every exported clip to that ratio for TikTok/Reels/Shorts. It takes the largest centered window that fits the source frame, so nothing gets upscaled, and any captions are burned in after the crop so they fit the vertical frame. Thumbnails get the same crop so the dashboard previews match the clips. Leave it unset to keep the source aspect ratio.

## Scaling up (each is optional)

### Database: SQLite (default) or Postgres

Set `DATABASE_URL` to switch from the zero-config SQLite file to Postgres — needed once more than one process/instance touches the database, or you want the DB to survive a redeploy without a volume. Both drivers implement the identical function set (`src/db/sqlite.js` / `src/db/postgres.js`), dispatched by `src/db/index.js`; nothing else in the app needs to know which is active. Verified against a real local Postgres 16 instance (full CRUD, credits, stale-job recovery, idempotent webhook recording) — `tests/db.test.js` runs against whichever driver is active, and CI runs it against both.

### Queue: in-process (default) or BullMQ/Redis

Set `REDIS_URL` to switch from the default in-process array (fine for one instance, but loses anything still queued if the process crashes) to a BullMQ-backed queue in Redis. This is what actually lets the app scale horizontally — multiple instances running their own Worker against the same Redis queue coordinate automatically, each job runs exactly once. Verified against a real local Redis instance, including that a job queued while no worker is running gets picked up automatically once one starts (`tests/queue.test.js`, run against both drivers in CI).

### Storage: local disk (default) or S3

Set `S3_BUCKET` to have finished clips/thumbnails uploaded to S3 (or any S3-compatible provider — set `S3_ENDPOINT` for Cloudflare R2, MinIO, etc.) instead of staying on local disk. `ffmpeg` still needs local scratch space to actually cut the clip; the S3 driver uploads that output and deletes the local scratch copy immediately after (see `src/services/storage/`). Downloads/thumbnails are then served via short-lived presigned URLs (redirect, not proxied) instead of streamed from local disk. The upload/presigning logic is covered by `tests/storage.test.js` against a mocked S3 client — **there's no live AWS smoke test in this repo**; do one manual upload/download against your real bucket before pointing real client traffic at it.

### Transcript-based scoring + captions: off (default) or Whisper

Set `OPENAI_API_KEY` to transcribe audio via Whisper and use the actual transcript — not just sampled frames — to score which moments are worth clipping (this was Phase 1's biggest acknowledged weakness). When a transcript is available, captions are also burned into the exported clips (disable with `BURN_IN_CAPTIONS=false` if you want the scoring improvement without visible captions). If transcription fails for any reason (bad key, quota, network), the job logs a warning and falls back to the original frame-only scoring rather than failing — see `safeTranscribe` in `src/services/pipeline.js`. SRT generation/timing logic is unit tested (`tests/captions.test.js`); **there's no live Whisper smoke test in this repo** since it needs a real API key — try one real video before relying on it.

### Payments: unlimited (default) or Stripe credits

Set `STRIPE_SECRET_KEY` (+ `STRIPE_WEBHOOK_SECRET`) to require a purchased credit for every upload instead of the default unlimited/manual-invoicing mode. **This app doesn't have a per-client login system** — accounts are identified by a plain `accountId` string the client includes in the request; it isn't validated against anything else. That's a real simplification, appropriate for a small number of clients you're onboarding by hand (send each one their own `accountId` alongside the shared `ACCESS_TOKEN`), not a substitute for real auth if you outgrow that.

- `POST /api/billing/checkout` — body `{ accountId, quantity }`, returns `{ url }` (a Stripe Checkout URL, one credit per `quantity` unit at `STRIPE_CREDIT_PRICE_CENTS`).
- `GET /api/billing/balance?accountId=...` — returns `{ accountId, credits }`.
- `POST /api/billing/webhook` — Stripe calls this on `checkout.session.completed`; not behind `ACCESS_TOKEN` (Stripe doesn't have it) — protected instead by Stripe's own signature (`STRIPE_WEBHOOK_SECRET`), verified via `stripe.webhooks.constructEvent`. Idempotent per Stripe event id, so webhook retries can't double-credit an account.
- `POST /api/upload` additionally requires an `accountId` field/query param when Stripe billing is on, and returns `402` if that account has no credits left.

Verified end-to-end against real Stripe signature generation (no live Stripe account needed for this — `Stripe.webhooks.generateTestHeaderString` produces a real, correctly-signed test event): credit gating (400 with no `accountId`, 402 with zero credits), a signed webhook granting credits, replaying the same webhook not double-crediting, a forged/tampered webhook being rejected, and a successful upload consuming exactly one credit. **Checkout session creation itself isn't tested against a live Stripe account** (only mocked) — do one real purchase in Stripe test mode before going live.

## Deploying

**Railway:**
1. New project → deploy from this repo. Railway will pick up the `Dockerfile` automatically (this is what gets you `ffmpeg` — don't skip it). If you instead let it use Nixpacks, `nixpacks.toml` also installs `ffmpeg`.
2. If staying on the SQLite/local-disk defaults: attach a volume mounted at `/app/data` and set `UPLOAD_DIR`, `CLIPS_DIR`, `DATA_DIR` under it — otherwise uploads/clips/the DB vanish on every redeploy. If you've switched on Postgres and S3 instead, you don't need a volume.
3. Set `ANTHROPIC_API_KEY` and `ACCESS_TOKEN`, plus whichever of `DATABASE_URL` / `REDIS_URL` / `S3_BUCKET` / `OPENAI_API_KEY` / `STRIPE_SECRET_KEY` you're turning on.

**Anywhere else:** the `Dockerfile` is self-contained (Node + ffmpeg); any container platform (Render, Fly.io, a plain VM) works the same way. `Procfile` is there for Heroku.

## API

- `POST /api/upload` — multipart, field `video` (+ `accountId` field/query param if Stripe billing is on). Returns `202 { jobId }`, or `400` with a readable `error` if the file isn't a usable video (checked with `ffprobe` before any credit is spent).
- `GET /api/jobs` — list jobs.
- `GET /api/jobs/:id` — job status + `clips[]` once processing finishes. `processingSeconds` is the pipeline's wall-clock time once the job completes or fails.
- `GET /api/stats` — usage totals: jobs by status, jobs in the last 24h/7d, failure rate, total clips, source minutes processed, average/max processing time.
- `GET /api/jobs/:id/clips/:clipId/file` — download a clip (redirects to a presigned URL when using S3).
- `GET /api/jobs/:id/clips/:clipId/thumbnail` — clip thumbnail (same).
- `POST /api/billing/checkout`, `GET /api/billing/balance`, `POST /api/billing/webhook` — only mounted when `STRIPE_SECRET_KEY` is set; see above.

All `/api/*` routes require `ACCESS_TOKEN` (header `x-access-token` or `?token=`) when it's configured, except `/api/billing/webhook` (see above).

## Still open — needs a product decision, not just code

- **Real per-client auth.** The `accountId` string used for billing isn't validated against anything (see Payments above) — fine for a handful of hand-onboarded clients, not for self-serve signup.
- **Wider format test matrix.** Uploads are now probed with `ffprobe` and rejected up front (400, no credit spent) if they're unreadable, truncated, audio-only, or missing duration/dimensions, but there's still no exhaustive matrix of exotic containers/codecs (ProRes, HEVC 10-bit, VFR phone footage, etc.).
- **Deeper analytics.** `GET /api/stats` covers processing time and volume, but there's no per-client breakdown (no real client identity yet, see above) and no tracking of how clips perform once posted.
- **Subject-aware vertical crop.** `CLIP_ASPECT=9:16` (see Configuration) does a fixed center crop; it doesn't track the speaker, so off-center subjects can end up partly out of frame.
