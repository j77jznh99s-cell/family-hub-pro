# Graph Report - family-hub-pro  (2026-11-20)

## Corpus Check
- 93 files · ~115,187 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 7 file(s) not represented in the graph (top: (none) 5, .example 1, .toml 1)

## Summary
- 887 nodes · 1280 edges · 78 communities (72 shown, 6 thin omitted)
- Extraction: 89% EXTRACTED · 11% INFERRED · 0% AMBIGUOUS · INFERRED: 141 edges (avg confidence: 0.9)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `9dcd07ed`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- 00 Home.md
- main
- server.js
- graph.js
- claudeAnalyzer.js
- postgres.js
- Morning Summary
- sqlite.js
- steps
- Sproutling Isles: Art Brief
- pipeline.js
- Sproutling Isles — Game Design Doc
- upload.js
- Gumroad Digital Products
- services/billing.js
- Clip Studio
- config.js
- Session Log.md
- 1. Pre-launch checklist
- 5. Week 1–8 live-ops calendar
- Sproutling Isles: Trading Booths (Phase 2 spec)
- bullmq.js
- s3.js
- StarNet Automation
- ref_node_assert
- queue.test.js
- segmenter.js
- Sproutling Isles: Launch & Live Ops
- CLAUDE.md — read this first, every session
- storage.test.js
- routes/billing.js
- package.json
- knowledgeGraph.test.js
- db.test.js
- AI Memory Export
- cli.js
- Runs (newest first)
- 3. Analytics event spec
- Team Roster.md
- captions.test.js
- Hourly Workflow (the standing rule)
- Trading Agent (forex setups)
- install-graphify.sh
- Knowledge Graph
- Roblox Market Research 2026
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
- Starling Heist
- Bybit Trading Bot
- Claude Code Add-ons
- Halloween event spec "Hollow Harvest"
- ffmpeg.js
- Demand brief (2026-11-09)
- Crypto Signals (momentum checkpoint system)
- ref_path
- clips.js
- Decisions

## God Nodes (most connected - your core abstractions)
1. `main()` - 70 edges
2. `Morning Summary` - 57 edges
3. `Session Log` - 39 edges
4. `Sproutling Isles: Launch & Live Ops` - 14 edges
5. `Sproutling Isles: Art Brief` - 14 edges
6. `1. Pre-launch checklist` - 13 edges
7. `query()` - 13 edges
8. `5. Week 1–8 live-ops calendar` - 12 edges
9. `Sproutling Isles: Trading Booths (Phase 2 spec)` - 12 edges
10. `StarNet Automation` - 12 edges

## Surprising Connections (you probably didn't know these)
- `End of every session / task (not optional)` --references--> `main()`  [INFERRED]
  CLAUDE.md → tools/knowledge-graph/cli.js
- `Branches` --references--> `main()`  [INFERRED]
  CLAUDE.md → tools/knowledge-graph/cli.js
- `Current focus` --references--> `main()`  [INFERRED]
  vault/Memory/Active Context.md → tools/knowledge-graph/cli.js
- `2026-11-10` --references--> `main()`  [INFERRED]
  vault/Memory/Morning Summary.md → tools/knowledge-graph/cli.js
- `2026-10-07` --references--> `main()`  [INFERRED]
  vault/Memory/Morning Summary.md → tools/knowledge-graph/cli.js

## Import Cycles
- None detected.

## Communities (78 total, 6 thin omitted)

### Community 1 - "main"
Cohesion: 0.08
Nodes (41): main(), 2026-09-23 (evening): moved everything into the vault for the laptop, 2026-09-23 (later): first agent team run, 2026-09-23: Roblox research → design doc → Sproutling Isles build → memory system, 2026-09-25 (later): StarNet plan checked against its source code, 2026-09-25 (latest): StarNet brain and budget decided, 2026-09-25: StarNet automation setup, 2026-09-26: agent platform comparison (StarNet alternatives) (+33 more)

### Community 2 - "server.js"
Cohesion: 0.15
Nodes (8): requireAccessToken(), express, router, router, app, cors, express, path

### Community 3 - "graph.js"
Cohesion: 0.05
Nodes (37): addNode(), emptyGraph(), fs, load(), neighbors(), path, save(), slugify() (+29 more)

### Community 4 - "claudeAnalyzer.js"
Cohesion: 0.29
Nodes (11): analyzeSegments(), Anthropic, extractJsonArray(), extractSegmentFrames(), fallbackResults(), frameTimestamps(), fs, getClient() (+3 more)

### Community 5 - "postgres.js"
Cohesion: 0.21
Nodes (19): addCredits(), createJob(), failStaleProcessingJobs(), fs, getClip(), getClipsForJob(), getJob(), getOrCreateAccount() (+11 more)

### Community 6 - "Morning Summary"
Cohesion: 0.04
Nodes (57): 2026-09-26 (first morning summary), 2026-09-27, 2026-09-28, 2026-09-29, 2026-09-30, 2026-10-01, 2026-10-02, 2026-10-03 (+49 more)

### Community 7 - "sqlite.js"
Cohesion: 0.12
Nodes (8): addCredits(), Database, db, fs, getOrCreateAccount(), path, schema, spendCreditIfAvailable()

### Community 8 - "steps"
Cohesion: 0.06
Nodes (31): DATABASE_URL, POSTGRES_DB, POSTGRES_PASSWORD, POSTGRES_USER, REDIS_URL, jobs, test, name (+23 more)

### Community 9 - "Sproutling Isles: Art Brief"
Cohesion: 0.11
Nodes (19): 10. Game icon and thumbnails, 11. Deliverables and file formats, 12. Rough effort estimate (unverified, for quoting only), 13. What `roblox-engineer` must build to use this art (later task), 1. The game in one paragraph (for the artist), 2. Art direction, 3. Palette, 4. Silhouette rules (+11 more)

### Community 10 - "pipeline.js"
Cohesion: 0.15
Nodes (9): Transcript-based scoring + captions: off (default) or Whisper, fs, path, safeTranscribe(), { v4: uuid }, fs, getClient(), OpenAI (+1 more)

### Community 11 - "Sproutling Isles — Game Design Doc"
Cohesion: 0.12
Nodes (17): Build status, Core loop, Developer products (repeatable), Economy and monetization, Game passes (one-time), Map, Other systems, Overview (+9 more)

### Community 12 - "upload.js"
Cohesion: 0.15
Nodes (9): diskStorage, express, fs, multer, path, rateLimit, upload, uploadLimiter (+1 more)

### Community 13 - "Gumroad Digital Products"
Cohesion: 0.12
Nodes (16): 1. Family organization printables (chore charts, weekly/meal planners), 1. Originality rule (read first, applies to every product), 2. Beginner Roblox game-making guides (from the Sproutling Isles build), 2. The goal, 3. Costs (checked 2026-09-26), 3. Spreadsheet / Notion templates (budget trackers, habit trackers, content calendars), 4. What to sell first (the research agent checks demand before we build), 5. One-time setup (owner, about 20 minutes) (+8 more)

### Community 14 - "services/billing.js"
Cohesion: 0.31
Nodes (5): stripeWebhookHandler(), createCheckoutSession(), getClient(), Stripe, verifyWebhookSignature()

### Community 15 - "Clip Studio"
Cohesion: 0.15
Nodes (12): API, Clip Studio, Configuration, Database: SQLite (default) or Postgres, Deploying, How it works, Payments: unlimited (default) or Stripe credits, Queue: in-process (default) or BullMQ/Redis (+4 more)

### Community 16 - "config.js"
Cohesion: 0.29
Nodes (4): fs, getServeInfo(), path, resolveSafePath()

### Community 17 - "Session Log.md"
Cohesion: 0.03
Nodes (62): 2026-09-27: OANDA re-check and hourly cost check, 2026-10-03 15:05: local hourly run — Sproutling Isles market trend refresh, 2026-10-03 16:00: local hourly run — Family Hub core code review, 2026-10-03 17:00: local hourly run — Bybit risk gate fails closed on bad data, 2026-10-03 18:30: local hourly run — Clip Studio presenter QA fixes, 2026-10-03 20:00: local hourly run — Sproutling Isles outside-game purchases, 2026-10-03: owner request — build a brand-new Roblox game from scratch, 2026-10-03: owner request — polish the Sproutling Isles test plan for the laptop (+54 more)

### Community 18 - "1. Pre-launch checklist"
Cohesion: 0.15
Nodes (13): 1. Pre-launch checklist, A. Before touching the dashboard, B. Game Settings in Studio (Home tab > **Game Settings**), C. Basic settings in CH (**Configure > Basic Settings**; some fields may be under **Configure > Audience**), D. Maturity & Compliance questionnaire (CH > **Audience > Maturity & Compliance**), E. Private servers (CH > **Monetization > Private Servers**, or **Configure > Access**), F. Game passes: 5 in total (CH > **Monetization > Passes**), G. Developer products: 8 in total (CH > **Monetization > Developer Products**) (+5 more)

### Community 19 - "5. Week 1–8 live-ops calendar"
Cohesion: 0.17
Nodes (12): 5. Week 1–8 live-ops calendar, Overview, Week 1: Launch, "First Bloom" (Sat 10 Oct), Week 2: Halloween part 1, Spooky Fog (Sat 17 Oct), Week 3: Halloween part 2 (Sat 24 Oct), Week 4: Halloween finale, Witching Hour (starts Friday 30 Oct night US), Week 5 code list (live-ops-manager proposal, 2026-09-26), Week 5: Leaderboards, Codes and ads (Sat 7 Nov) (+4 more)

### Community 20 - "Sproutling Isles: Trading Booths (Phase 2 spec)"
Cohesion: 0.15
Nodes (13): 10. Build checklist for roblox-engineer, 11. Out of scope (later), 1. Goals, 2. Player flow, 3. Rules, 4. UI screens and text, 5. Server authority and anti-dupe requirements, 6. Data changes (+5 more)

### Community 21 - "bullmq.js"
Cohesion: 0.17
Nodes (9): processJob(), connection, IORedis, queue, { Queue, Worker }, worker, enqueue(), pending (+1 more)

### Community 22 - "s3.js"
Cohesion: 0.18
Nodes (4): client, fs, presigner, {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
}

### Community 23 - "StarNet Automation"
Cohesion: 0.17
Nodes (12): First jobs to schedule, How the tools work (what to place in each room), How this was checked (2026-09-25), Keep it lean (owner: "don't overwork it", 2026-09-26), Laptop install (about 20 minutes), One-click settings file (2026-09-26), Online selling agents (checked in StarNet's code, 2026-09-26), Safety rules (+4 more)

### Community 24 - "ref_node_assert"
Cohesion: 0.15
Nodes (10): assert, Stripe, { test }, assert, { test }, assert, { test }, assert (+2 more)

### Community 25 - "queue.test.js"
Cohesion: 0.22
Nodes (6): assert, fs, os, path, { test, before, after }, tmpDataDir

### Community 26 - "segmenter.js"
Cohesion: 0.48
Nodes (6): buildCandidateSegments(), DEFAULTS, invertSilences(), mergeCloseSegments(), pickEvenlySpaced(), splitLongSegment()

### Community 27 - "Sproutling Isles: Launch & Live Ops"
Cohesion: 0.18
Nodes (11): 2. Soft-launch plan (closed beta), Contents, Fairness review of the current store, Go / no-go for public launch, KPI dashboard, Sources (ads section), Sproutling Isles: Launch & Live Ops, Tasks created by this note (+3 more)

### Community 28 - "CLAUDE.md — read this first, every session"
Cohesion: 0.20
Nodes (9): Agents, Branches, CLAUDE.md — read this first, every session, End of every session / task (not optional), graphify, Hourly workflow, House rules, Projects (+1 more)

### Community 29 - "storage.test.js"
Cohesion: 0.25
Nodes (7): assert, fs, os, path, presigner, { S3Client }, { test, mock }

### Community 30 - "routes/billing.js"
Cohesion: 0.29
Nodes (4): express@^4.21.1, express, express, router

### Community 31 - "package.json"
Cohesion: 0.07
Nodes (40): dependencies, @anthropic-ai/sdk@^0.32.1, @aws-sdk/client-s3@^3.699.0, @aws-sdk/s3-request-presigner@^3.699.0, better-sqlite3@^11.5.0, bullmq@^5.34.1, cors@^2.8.5, dotenv@^16.4.5 (+32 more)

### Community 32 - "knowledgeGraph.test.js"
Cohesion: 0.25
Nodes (5): assert, fs, os, path, { test }

### Community 33 - "db.test.js"
Cohesion: 0.25
Nodes (5): assert, fs, os, path, { test, before, after }

### Community 34 - "AI Memory Export"
Cohesion: 0.22
Nodes (9): AI Memory Export, Anything else durable, Communication preferences, Identity, Interests & hobbies, Ongoing projects, Profession & work, Tools & environment (+1 more)

### Community 35 - "cli.js"
Cohesion: 0.29
Nodes (5): DEFAULT_GRAPH_PATH, parseData(), parseFlags(), path, printJSON()

### Community 36 - "Runs (newest first)"
Cohesion: 0.40
Nodes (5): Ideas queue (for later runs), Run 1, 2026-10-24 ~05:00: Monster Journal, Run 2, 2026-10-24: Daily Tasks, Runs (newest first), Sproutling Isles: Overnight Runs

### Community 37 - "3. Analytics event spec"
Cohesion: 0.22
Nodes (9): start(), 2026-10-21 (late): Sproutling Isles world reshape, 3. Analytics event spec, 3a. Onboarding funnel (`LogOnboardingFunnelStepEvent`), once per player, 3b. Recurring funnels (`LogFunnelStepEvent`), 3c. Economy events (`LogEconomyEvent`), 3d. Custom events (`LogCustomEvent`), Acceptance (for qa-tester) (+1 more)

### Community 38 - "Team Roster.md"
Cohesion: 0.17
Nodes (6): Hand-offs that work well, Team Roster, Family Hub, Tasks, 2026-09-27: Import failed — https://youtu.be/FwOTs4UxQS4, Video Analyst Runs

### Community 39 - "captions.test.js"
Cohesion: 0.38
Nodes (5): buildSrt(), formatSrtTimestamp(), assert, { test }, transcript

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
Cohesion: 0.29
Nodes (7): Bottom line, Genre leaders (third-party trackers, Aug–Sep 2026), Monetization patterns that work, Platform facts (2026), Refresh 2026-10-03, Roblox Market Research 2026, Sources

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
Cohesion: 0.40
Nodes (5): CI fix on `main` (2026-09-26), Clip Studio, QA Review (2026-09-26), QA Review 2: calendar / weekly / usage (2026-10-06), Tasks

### Community 66 - "6. Marketing"
Cohesion: 0.50
Nodes (4): 6. Marketing, Creator outreach, Sponsored ads (Roblox Ads Manager). *All tiers spend real money, so the owner decides.*, TikTok / YouTube Shorts clip ideas (9:16, 10–25 s, hook in the first second, captions on)

### Community 68 - "Starling Heist"
Cohesion: 0.40
Nodes (5): Rules followed (details in docs/COMPLIANCE.md), Starling Heist, Status / verification, Tasks, The game in one paragraph

### Community 69 - "Bybit Trading Bot"
Cohesion: 0.67
Nodes (3): Bybit Trading Bot, Hard rules for every agent, Tasks

### Community 70 - "Claude Code Add-ons"
Cohesion: 0.67
Nodes (3): Claude Code Add-ons, How to install (approve once), Watch out

### Community 71 - "Halloween event spec "Hollow Harvest""
Cohesion: 0.67
Nodes (3): Halloween event spec "Hollow Harvest", Hollow Harvest weekly drops — proposal (2026-10-06), Spotlight re-check (2026-10-16)

### Community 72 - "ffmpeg.js"
Cohesion: 0.22
Nodes (11): checkAvailable(), detectSilences(), escapeForFilterPath(), { execFile }, execFileAsync, extractAudio(), extractClip(), extractFrame() (+3 more)

### Community 73 - "Demand brief (2026-11-09)"
Cohesion: 0.20
Nodes (10): 1. Roblox developer kits (Luau systems, Studio plugins), 2. 2D pixel-art packs (itch.io first), 3. 3D low-poly model packs, Demand brief (2026-11-09), First pack: Daily Streaks Kit (built 2026-11-09), Game Asset Store, Licences and AI rules, Recommendation (+2 more)

### Community 74 - "Crypto Signals (momentum checkpoint system)"
Cohesion: 0.33
Nodes (6): Blocked, Crypto Signals (momentum checkpoint system), Planned build order, Status, Tasks, What it is

### Community 75 - "ref_path"
Cohesion: 0.17
Nodes (6): { chromium }, path, sizes, themes, path, ROOT

## Knowledge Gaps
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `start()` connect `3. Analytics event spec` to `server.js`?**
  _High betweenness centrality (0.202) - this node is a cross-community bridge._
- **Are the 66 inferred relationships involving `main()` (e.g. with `Branches` and `End of every session / task (not optional)`) actually correct?**
  _`main()` has 66 INFERRED edges - model-reasoned connections that need verification._
- **Should `main` be split into smaller, more focused modules?**
  _Cohesion score 0.08292682926829269 - nodes in this community are weakly interconnected._
- **Why does `main()` connect `main` to `Clip Studio`, `AI Memory Export`, `cli.js`, `3. Analytics event spec`, `Morning Summary`, `ffmpeg.js`, `Hourly Workflow (the standing rule)`, `Decisions`, `Start Here: laptop`, `Session Log.md`, `Active Context`, `Work Queue`, `StarNet Automation`, `CLAUDE.md — read this first, every session`?**
  _High betweenness centrality (0.178) - this node is a cross-community bridge._
- **Should `graph.js` be split into smaller, more focused modules?**
  _Cohesion score 0.05226480836236934 - nodes in this community are weakly interconnected._
- **Why does `2026-10-21 (late): Sproutling Isles world reshape` connect `3. Analytics event spec` to `Session Log.md`, `main`?**
  _High betweenness centrality (0.169) - this node is a cross-community bridge._
- **Should `Morning Summary` be split into smaller, more focused modules?**
  _Cohesion score 0.03508771929824561 - nodes in this community are weakly interconnected._