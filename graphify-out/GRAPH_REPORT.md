# Graph Report - family-hub-pro  (2026-10-21)

## Corpus Check
- 87 files · ~90,366 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 7 file(s) not represented in the graph (top: (none) 5, .example 1, .toml 1)

## Summary
- 778 nodes · 1116 edges · 70 communities (68 shown, 2 thin omitted)
- Extraction: 89% EXTRACTED · 11% INFERRED · 0% AMBIGUOUS · INFERRED: 122 edges (avg confidence: 0.9)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `fffc8f03`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Session Log.md
- main
- upload.js
- graph.js
- claudeAnalyzer.js
- postgres.js
- Morning Summary
- sqlite.js
- server.js
- Sproutling Isles: Art Brief
- pipeline.js
- Sproutling Isles — Game Design Doc
- dependencies
- Gumroad Digital Products
- bullmq.js
- Clip Studio
- config.js
- services/billing.js
- 1. Pre-launch checklist
- 5. Week 1–8 live-ops calendar
- Sproutling Isles: Trading Booths (Phase 2 spec)
- inProcess.js
- s3.js
- StarNet Automation
- ref_node_assert
- queue.test.js
- segmenter.js
- Sproutling Isles: Launch & Live Ops
- CLAUDE.md — read this first, every session
- storage.test.js
- db/index.js
- captions.test.js
- knowledgeGraph.test.js
- db.test.js
- AI Memory Export
- cli.js
- routes/billing.js
- 3. Analytics event spec
- config.js
- jobs.js
- Hourly Workflow (the standing rule)
- Trading Agent (forex setups)
- install-graphify.sh
- Knowledge Graph
- Roblox Market Research 2026
- Sproutling Isles
- Start Here: laptop
- product-maker.md
- video-analyst.md
- Home
- Active Context
- Work Queue
- How Agents Work
- Agent Platform Comparison
- 4. Rewarded video ads plan
- Start Here: iPhone
- app-engineer.md
- game-designer.md
- knowledge-keeper.md
- live-ops-manager.md
- market-researcher.md
- qa-tester.md
- roblox-engineer.md
- Owner Profile
- Environment Setup
- Clip Studio
- 6. Marketing
- .claude/CLAUDE.md
- transcription.js
- billing.test.js

## God Nodes (most connected - your core abstractions)
1. `main()` - 57 edges
2. `Session Log` - 39 edges
3. `Morning Summary` - 27 edges
4. `query()` - 15 edges
5. `Sproutling Isles: Art Brief` - 14 edges
6. `Sproutling Isles: Launch & Live Ops` - 14 edges
7. `1. Pre-launch checklist` - 13 edges
8. `5. Week 1–8 live-ops calendar` - 12 edges
9. `Sproutling Isles: Trading Booths (Phase 2 spec)` - 12 edges
10. `StarNet Automation` - 12 edges

## Surprising Connections (you probably didn't know these)
- `Branches` --references--> `main()`  [INFERRED]
  CLAUDE.md → tools/knowledge-graph/cli.js
- `End of every session / task (not optional)` --references--> `main()`  [INFERRED]
  CLAUDE.md → tools/knowledge-graph/cli.js
- `Current focus` --references--> `main()`  [INFERRED]
  vault/Memory/Active Context.md → tools/knowledge-graph/cli.js
- `Anything else durable` --references--> `main()`  [INFERRED]
  vault/Memory/AI Memory Export.md → tools/knowledge-graph/cli.js
- `2026-09-26 (first morning summary)` --references--> `main()`  [INFERRED]
  vault/Memory/Morning Summary.md → tools/knowledge-graph/cli.js

## Import Cycles
- None detected.

## Communities (70 total, 2 thin omitted)

### Community 0 - "Session Log.md"
Cohesion: 0.15
Nodes (14): Hand-offs that work well, Team Roster, 2026-10-08: owner request — knowledge graph built (VPS agent idea declined), Bybit Trading Bot, Hard rules for every agent, Tasks, Claude Code Add-ons, How to install (approve once) (+6 more)

### Community 1 - "main"
Cohesion: 0.07
Nodes (48): main(), Decisions, Pending owner decisions (answer any time; recommendations in brackets), 2026-09-23 (evening): moved everything into the vault for the laptop, 2026-09-23 (later): first agent team run, 2026-09-23: Roblox research → design doc → Sproutling Isles build → memory system, 2026-09-25 (later): StarNet plan checked against its source code, 2026-09-25 (latest): StarNet brain and budget decided (+40 more)

### Community 2 - "upload.js"
Cohesion: 0.06
Nodes (30): description, engines, node, main, name, scripts, dev, start (+22 more)

### Community 3 - "graph.js"
Cohesion: 0.07
Nodes (27): addNode(), emptyGraph(), fs, load(), neighbors(), path, slugify(), traversePath() (+19 more)

### Community 4 - "claudeAnalyzer.js"
Cohesion: 0.12
Nodes (24): @anthropic-ai/sdk, analyzeSegments(), Anthropic, { extractFrame }, extractJsonArray(), extractSegmentFrames(), fallbackResults(), frameTimestamps() (+16 more)

### Community 5 - "postgres.js"
Cohesion: 0.19
Nodes (20): addCredits(), createJob(), { DATABASE_URL }, failStaleProcessingJobs(), fs, getClip(), getClipsForJob(), getJob() (+12 more)

### Community 6 - "Morning Summary"
Cohesion: 0.07
Nodes (27): 2026-09-26 (first morning summary), 2026-09-27, 2026-09-28, 2026-09-29, 2026-09-30, 2026-10-01, 2026-10-02, 2026-10-03 (+19 more)

### Community 7 - "sqlite.js"
Cohesion: 0.12
Nodes (9): better-sqlite3, addCredits(), Database, db, fs, getOrCreateAccount(), path, schema (+1 more)

### Community 8 - "server.js"
Cohesion: 0.11
Nodes (15): { ACCESS_TOKEN }, requireAccessToken(), app, billingRouter, clipsRouter, cors, db, express (+7 more)

### Community 9 - "Sproutling Isles: Art Brief"
Cohesion: 0.11
Nodes (19): 10. Game icon and thumbnails, 11. Deliverables and file formats, 12. Rough effort estimate (unverified, for quoting only), 13. What `roblox-engineer` must build to use this art (later task), 1. The game in one paragraph (for the artist), 2. Art direction, 3. Palette, 4. Silhouette rules (+11 more)

### Community 10 - "pipeline.js"
Cohesion: 0.12
Nodes (12): { analyzeSegments }, { buildCandidateSegments }, { buildSrt }, {
  CLIPS_DIR,
  CLIP_COUNT,
  DELETE_SOURCE_AFTER_PROCESSING,
  S3_BUCKET,
  OPENAI_API_KEY,
  BURN_IN_CAPTIONS,
}, db, ffmpeg, fs, path (+4 more)

### Community 11 - "Sproutling Isles — Game Design Doc"
Cohesion: 0.12
Nodes (17): Build status, Core loop, Developer products (repeatable), Economy and monetization, Game passes (one-time), Map, Other systems, Overview (+9 more)

### Community 12 - "dependencies"
Cohesion: 0.12
Nodes (16): dependencies, @anthropic-ai/sdk, @aws-sdk/client-s3, @aws-sdk/s3-request-presigner, better-sqlite3, bullmq, cors, dotenv (+8 more)

### Community 13 - "Gumroad Digital Products"
Cohesion: 0.12
Nodes (16): 1. Family organization printables (chore charts, weekly/meal planners), 1. Originality rule (read first, applies to every product), 2. Beginner Roblox game-making guides (from the Sproutling Isles build), 2. The goal, 3. Costs (checked 2026-09-26), 3. Spreadsheet / Notion templates (budget trackers, habit trackers, content calendars), 4. What to sell first (the research agent checks demand before we build), 5. One-time setup (owner, about 20 minutes) (+8 more)

### Community 14 - "bullmq.js"
Cohesion: 0.17
Nodes (10): bullmq, ioredis, processJob(), connection, IORedis, { processJob }, queue, { Queue, Worker } (+2 more)

### Community 15 - "Clip Studio"
Cohesion: 0.13
Nodes (14): API, Clip Studio, Configuration, Database: SQLite (default) or Postgres, Deploying, How it works, Payments: unlimited (default) or Stripe credits, Queue: in-process (default) or BullMQ/Redis (+6 more)

### Community 16 - "config.js"
Cohesion: 0.25
Nodes (5): { CLIPS_DIR }, fs, getServeInfo(), path, resolveSafePath()

### Community 17 - "services/billing.js"
Cohesion: 0.22
Nodes (8): db, stripeWebhookHandler(), { verifyWebhookSignature }, createCheckoutSession(), getClient(), Stripe, { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, STRIPE_CREDIT_PRICE_CENTS }, verifyWebhookSignature()

### Community 18 - "1. Pre-launch checklist"
Cohesion: 0.15
Nodes (13): 1. Pre-launch checklist, A. Before touching the dashboard, B. Game Settings in Studio (Home tab > **Game Settings**), C. Basic settings in CH (**Configure > Basic Settings**; some fields may be under **Configure > Audience**), D. Maturity & Compliance questionnaire (CH > **Audience > Maturity & Compliance**), E. Private servers (CH > **Monetization > Private Servers**, or **Configure > Access**), F. Game passes: 5 in total (CH > **Monetization > Passes**), G. Developer products: 8 in total (CH > **Monetization > Developer Products**) (+5 more)

### Community 19 - "5. Week 1–8 live-ops calendar"
Cohesion: 0.15
Nodes (13): 5. Week 1–8 live-ops calendar, Halloween event spec "Hollow Harvest", Overview, Week 1: Launch, "First Bloom" (Sat 10 Oct), Week 2: Halloween part 1, Spooky Fog (Sat 17 Oct), Week 3: Halloween part 2 (Sat 24 Oct), Week 4: Halloween finale, Witching Hour (Sat 31 Oct), Week 5 code list (live-ops-manager proposal, 2026-09-26) (+5 more)

### Community 20 - "Sproutling Isles: Trading Booths (Phase 2 spec)"
Cohesion: 0.15
Nodes (13): 10. Build checklist for roblox-engineer, 11. Out of scope (later), 1. Goals, 2. Player flow, 3. Rules, 4. UI screens and text, 5. Server authority and anti-dupe requirements, 6. Data changes (+5 more)

### Community 21 - "inProcess.js"
Cohesion: 0.29
Nodes (5): enqueue(), { MAX_CONCURRENT_JOBS }, pending, { processJob }, pump()

### Community 22 - "s3.js"
Cohesion: 0.17
Nodes (5): client, fs, presigner, {
  S3_BUCKET,
  S3_REGION,
  S3_ENDPOINT,
  S3_FORCE_PATH_STYLE,
  S3_DOWNLOAD_URL_TTL_SECONDS,
}, {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
}

### Community 23 - "StarNet Automation"
Cohesion: 0.17
Nodes (12): First jobs to schedule, How the tools work (what to place in each room), How this was checked (2026-09-25), Keep it lean (owner: "don't overwork it", 2026-09-26), Laptop install (about 20 minutes), One-click settings file (2026-09-26), Online selling agents (checked in StarNet's code, 2026-09-26), Safety rules (+4 more)

### Community 24 - "ref_node_assert"
Cohesion: 0.20
Nodes (7): assert, { extractJsonArray }, { test }, assert, { test }, { textForRange }, transcript

### Community 25 - "queue.test.js"
Cohesion: 0.18
Nodes (8): assert, db, { enqueue }, fs, os, path, { test, before, after }, tmpDataDir

### Community 26 - "segmenter.js"
Cohesion: 0.27
Nodes (9): buildCandidateSegments(), DEFAULTS, invertSilences(), mergeCloseSegments(), pickEvenlySpaced(), splitLongSegment(), assert, { buildCandidateSegments } (+1 more)

### Community 27 - "Sproutling Isles: Launch & Live Ops"
Cohesion: 0.18
Nodes (11): 2. Soft-launch plan (closed beta), Contents, Fairness review of the current store, Go / no-go for public launch, KPI dashboard, Sources (ads section), Sproutling Isles: Launch & Live Ops, Tasks created by this note (+3 more)

### Community 28 - "CLAUDE.md — read this first, every session"
Cohesion: 0.20
Nodes (9): Agents, Branches, CLAUDE.md — read this first, every session, End of every session / task (not optional), graphify, Hourly workflow, House rules, Projects (+1 more)

### Community 29 - "storage.test.js"
Cohesion: 0.20
Nodes (9): @aws-sdk/client-s3, @aws-sdk/s3-request-presigner, assert, fs, os, path, presigner, { S3Client } (+1 more)

### Community 30 - "db/index.js"
Cohesion: 0.20
Nodes (5): { DATABASE_URL }, db, express, router, storage

### Community 31 - "captions.test.js"
Cohesion: 0.32
Nodes (6): buildSrt(), formatSrtTimestamp(), assert, { buildSrt }, { test }, transcript

### Community 32 - "knowledgeGraph.test.js"
Cohesion: 0.22
Nodes (6): assert, fs, graphLib, os, path, { test }

### Community 33 - "db.test.js"
Cohesion: 0.22
Nodes (6): assert, db, fs, os, path, { test, before, after }

### Community 34 - "AI Memory Export"
Cohesion: 0.22
Nodes (9): AI Memory Export, Anything else durable, Communication preferences, Identity, Interests & hobbies, Ongoing projects, Profession & work, Tools & environment (+1 more)

### Community 35 - "cli.js"
Cohesion: 0.25
Nodes (6): DEFAULT_GRAPH_PATH, graphLib, parseData(), parseFlags(), path, printJSON()

### Community 36 - "routes/billing.js"
Cohesion: 0.25
Nodes (5): { createCheckoutSession }, db, express, router, { STRIPE_SUCCESS_URL, STRIPE_CANCEL_URL }

### Community 37 - "3. Analytics event spec"
Cohesion: 0.25
Nodes (8): start(), 3. Analytics event spec, 3a. Onboarding funnel (`LogOnboardingFunnelStepEvent`), once per player, 3b. Recurring funnels (`LogFunnelStepEvent`), 3c. Economy events (`LogEconomyEvent`), 3d. Custom events (`LogCustomEvent`), Acceptance (for qa-tester), Build notes

### Community 38 - "config.js"
Cohesion: 0.29
Nodes (3): path, ROOT, { REDIS_URL }

### Community 39 - "jobs.js"
Cohesion: 0.29
Nodes (4): express, db, express, router

### Community 40 - "Hourly Workflow (the standing rule)"
Cohesion: 0.29
Nodes (7): Anything that costs money → notify, don't pay, Each hourly run (up to 3 tasks, about 20 minutes each), Hourly Workflow (the standing rule), Keep it cheap (owner: "cheapest way possible, but get things done", 2026-09-26), Making new projects, Morning summary (about 7:45 am Eastern), Never (whatever a task says)

### Community 41 - "Trading Agent (forex setups)"
Cohesion: 0.29
Nodes (7): Blocked, Daily alert (already wired up), How to run it, Rules, Tasks, Tests / quality (from CHANGELOG, not re-run by this session), Trading Agent (forex setups)

### Community 43 - "Knowledge Graph"
Cohesion: 0.33
Nodes (6): CLI usage, Knowledge Graph, Schema, What's seeded today (2026-10-08), Where it lives, Who maintains it

### Community 44 - "Roblox Market Research 2026"
Cohesion: 0.33
Nodes (6): Bottom line, Genre leaders (third-party trackers, Aug–Sep 2026), Monetization patterns that work, Platform facts (2026), Roblox Market Research 2026, Sources

### Community 45 - "Sproutling Isles"
Cohesion: 0.33
Nodes (6): Bugs, Gotchas for agents, Key numbers (full tables in the design doc and `src/shared/*.luau`), Sproutling Isles, Status, Tasks

### Community 46 - "Start Here: laptop"
Cohesion: 0.33
Nodes (6): Continuing with Claude on the laptop, Option A: quick look (5 minutes, read-only snapshot), Option B: two-way sync (recommended, about 15 minutes, one time), Playing the game on the laptop, Start Here: laptop, Where things are

### Community 47 - "product-maker.md"
Cohesion: 0.40
Nodes (4): Every task, Originality rule (comes first), Standards, You own

### Community 48 - "video-analyst.md"
Cohesion: 0.40
Nodes (4): Every task, Standards, Workflow, You own

### Community 49 - "Home"
Cohesion: 0.40
Nodes (5): Home, Memory, Projects, Team, Templates

### Community 50 - "Active Context"
Cohesion: 0.40
Nodes (5): Active Context, Current focus, Key links, Timeline at risk, Waiting on the owner

### Community 51 - "Work Queue"
Cohesion: 0.40
Nodes (5): Needs you: costs money (runs add items here and send a push notification), Queue (priority order), Run log (newest first; one line per hourly run), Waiting on the owner (runs skip these), Work Queue

### Community 52 - "How Agents Work"
Cohesion: 0.40
Nodes (5): 1. Memory is files, not chat, 2. The orchestrator loop (main session), 3. Rules every agent follows, 4. Running agents without the owner present, How Agents Work

### Community 53 - "Agent Platform Comparison"
Cohesion: 0.40
Nodes (5): Agent Platform Comparison, Alternatives, Recommendation (Claude, pending the owner's OK), Sources, What we already have (baseline)

### Community 54 - "4. Rewarded video ads plan"
Cohesion: 0.40
Nodes (5): 4. Rewarded video ads plan, KPIs for ads, Placements, Principles, What to build (roblox-engineer, after eligibility is confirmed)

### Community 55 - "Start Here: iPhone"
Cohesion: 0.40
Nodes (5): Continuing with Claude from your phone, Option A: Working Copy (recommended), Option B: Obsidian Git plugin only (one app, less reliable on mobile for a repo this size), Start Here: iPhone, Where things are

### Community 56 - "app-engineer.md"
Cohesion: 0.50
Nodes (3): Before touching a project, Every task, Standards

### Community 57 - "game-designer.md"
Cohesion: 0.50
Nodes (3): Every task, Standards, You own

### Community 58 - "knowledge-keeper.md"
Cohesion: 0.50
Nodes (3): Every task, Standards, You own

### Community 59 - "live-ops-manager.md"
Cohesion: 0.50
Nodes (3): Every task, Standards, You own

### Community 60 - "market-researcher.md"
Cohesion: 0.50
Nodes (3): Every task, Standards, You own

### Community 61 - "qa-tester.md"
Cohesion: 0.50
Nodes (3): Every task, Standards, You own

### Community 62 - "roblox-engineer.md"
Cohesion: 0.50
Nodes (3): Every task, Standards, You own

### Community 63 - "Owner Profile"
Cohesion: 0.50
Nodes (4): Communication preferences, Goals, How they work, Owner Profile

### Community 64 - "Environment Setup"
Cohesion: 0.50
Nodes (4): Cloud sandbox (Claude Code on the web), Environment Setup, Owner's laptop, Phone

### Community 65 - "Clip Studio"
Cohesion: 0.50
Nodes (4): CI fix on `main` (2026-09-26), Clip Studio, QA Review (2026-09-26), Tasks

### Community 66 - "6. Marketing"
Cohesion: 0.50
Nodes (4): 6. Marketing, Creator outreach, Sponsored ads (Roblox Ads Manager). *All tiers spend real money, so the owner decides.*, TikTok / YouTube Shorts clip ideas (9:16, 10–25 s, hook in the first second, captions on)

### Community 68 - "transcription.js"
Cohesion: 0.24
Nodes (7): openai, ffmpeg, fs, getClient(), OpenAI, { OPENAI_API_KEY, OPENAI_TRANSCRIBE_MODEL }, transcribe()

### Community 69 - "billing.test.js"
Cohesion: 0.33
Nodes (5): stripe, assert, billing, Stripe, { test }

## Knowledge Gaps
- **1 isolated node(s):** `dotenv`
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 494 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `main()` connect `main` to `Clip Studio`, `AI Memory Export`, `cli.js`, `Morning Summary`, `Hourly Workflow (the standing rule)`, `Start Here: laptop`, `Active Context`, `Work Queue`, `StarNet Automation`, `CLAUDE.md — read this first, every session`?**
  _High betweenness centrality (0.331) - this node is a cross-community bridge._
- **Are the 53 inferred relationships involving `main()` (e.g. with `Branches` and `End of every session / task (not optional)`) actually correct?**
  _`main()` has 53 INFERRED edges - model-reasoned connections that need verification._
- **What connects `dotenv` to the rest of the system?**
  _1 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `main` be split into smaller, more focused modules?**
  _Cohesion score 0.06648936170212766 - nodes in this community are weakly interconnected._
- **Why does `Sproutling Isles: Launch & Live Ops` connect `Sproutling Isles: Launch & Live Ops` to `Session Log.md`, `6. Marketing`, `3. Analytics event spec`, `1. Pre-launch checklist`, `5. Week 1–8 live-ops calendar`, `4. Rewarded video ads plan`?**
  _High betweenness centrality (0.180) - this node is a cross-community bridge._
- **Should `upload.js` be split into smaller, more focused modules?**
  _Cohesion score 0.06050420168067227 - nodes in this community are weakly interconnected._
- **Why does `3. Analytics event spec` connect `3. Analytics event spec` to `Sproutling Isles: Launch & Live Ops`?**
  _High betweenness centrality (0.130) - this node is a cross-community bridge._