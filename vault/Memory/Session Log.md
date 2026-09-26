---
tags: [memory, log]
---
# Session Log

Newest first. One entry per working session. Use [[Session Log Entry]] as the template.

---

## 2026-09-26 (evening): hourly workflow restarted
**Device:** phone · **Branch:** `claude/working-automation-system-al8rz1` → synced to `main` · **Agents used:** none

**Owner asked:** go back to the hourly workflow plan, keep working on projects, make new ones based on our work, and send a morning summary.

**What was done**
- Found the old plan: session `session_01HkUDBZ…` ran a 20-minute loop on 23–25 Sep (Clip Studio AI presenter, a `trading-agent` repo,
  artifact pages). Its queue was in a temp file (gone), it's blocked on OANDA setup, and it is very large (~758k tokens), so it isn't resumed.
- Wrote [[Hourly Workflow]] (the standing rule), seeded [[Work Queue]], created [[Morning Summary]] and [[Trading Agent]],
  and recorded the hourly branch's Clip Studio work in [[Clip Studio]]. Added the workflow to `CLAUDE.md`.
- Created two Routines: hourly work (fresh session each hour) and the morning summary (~7:45 am Eastern).

**Not verified**
- [[Trading Agent]] is written from Routine records, not the code (first queue item fixes that).
- The first hourly run hasn't happened yet.

- Owner then asked for the cheapest setup, no direct charges, payment alerts, and a 20-minute pace. Routines can't run more often than hourly,
  so each hourly run now does up to 3 tasks (~20 min each). Added "Keep it cheap" and "costs money → notify" rules, set cheaper models
  for knowledge-keeper (Haiku) and market-researcher, live-ops-manager, product-maker (Sonnet), and test-fired the hourly Routine.

**Next:** see [[Active Context]].

---

## 2026-09-26 (later): Gumroad selling plan
**Device:** phone · **Branch:** `claude/working-automation-system-al8rz1` → synced to `main` · **Agents used:** none

**Owner asked:** go ahead with Gumroad; make all products original and put that at the start.

**What was done**
- Wrote [[Gumroad Digital Products]] with the **originality rule as section 1**, then costs, starter product lines, setup, crew workflow with an originality checklist, and guardrails.
- Added the rule to the `CLAUDE.md` house rules (StarNet agents load `CLAUDE.md`), a new `product-maker` agent, and a row in [[Team Roster]].
- Checked Gumroad fees (10% + $0.50 direct, 30% via Discover) and API product creation (recent, docs conflicting, so the owner publishes by hand).

**Not verified**
- Gumroad's own API docs were blocked from the sandbox; API facts come from search results and GitHub.

**Decisions:** Gumroad first; all products original. Pending: #20 first product line.

**Next:** see [[Active Context]].

---

## 2026-09-26: StarNet models and safety caps chosen
**Device:** phone · **Branch:** `claude/working-automation-system-al8rz1` → synced to `main` · **Agents used:** none

**Owner asked:** pick the model that's most effective for each job.

**What was done**
- Chose per agent/job: Haiku 4.5 (knowledge-keeper summaries), Sonnet 5 (market research), Opus 5 (design, on demand only).
- Applied the safety defaults: $1 per run, Night Shift off for week 1. Recorded in [[Decisions]] and [[StarNet Automation]].
- Owner then asked not to overwork it: added a "Keep it lean" section (medium effort, 25-step and 2-agent limits, caching on), checked in StarNet's code.
- Owner asked Claude to set them: added `starnet/station-settings.json` (a StarNet import file with the $5/day and $1/run caps). The step and agent limits and each agent's model can't be imported, so they stay a 2-minute manual step.
- Verified the import file against StarNet's importer (valid; per-day cap is soft, per-run cap is hard). Checked online selling: Shopify, Gumroad, Lemon Squeezy, print-on-demand, Stripe/PayPal/Square are supported; Etsy is manual only; eBay, Amazon, Facebook Marketplace, Poshmark and Mercari have no integration. Waiting on the owner: what they sell and where. Owner said "anything on the available platforms": recommended Gumroad digital products first, print-on-demand later (decision #19).

**Next:** see [[Active Context]].

---

## 2026-09-25 (latest): StarNet brain and budget decided
**Device:** phone · **Branch:** `claude/working-automation-system-al8rz1` → synced to `main` · **Agents used:** none

**Owner decided:** Anthropic API key; $5/day, paid from the prepaid deposit already in the Anthropic Console.

**What was done**
- Recorded both in [[Decisions]] and added the setup steps to [[StarNet Automation]] (keep Console auto-reload off).
- New pending decision #18: which Claude model (with 2026 prices). #17 narrowed to the per-run cap and Night Shift.

**Next:** see [[Active Context]].

---

## 2026-09-25 (later): StarNet plan checked against its source code
**Device:** phone · **Branch:** `claude/working-automation-system-al8rz1` → synced to `main` · **Agents used:** none

**Owner asked:** back-test the StarNet information and review it several times for the best result.

**What was done**
- Pass 1: checked every claim in [[StarNet Automation]] against StarNet's code (not its README). Found 5 errors:
  no Claude sign-in (API key only), budget caps default to no limit, agents need the repo added as a project,
  the Roblox code isn't on `main`, and scheduled jobs can't write or run commands.
- Rewrote the note: real object names (SHELF, DISH, CORE, WORKBENCH), a permissions table, a phased layout
  (vault-only first), and job setup steps.
- Pass 2: re-checked the new claims. Added that `CLAUDE.md` only loads for project chats and jobs with the repo as
  their working folder, and that Telegram must be connected before a job can send to it.
- Corrected decisions #16–17.

**Not verified**
- StarNet still wasn't run (the sandbox blocks outside code; it's a desktop app). Menu names come from the code.

**Next:** see [[Active Context]].

---

## 2026-09-25: StarNet automation setup
**Device:** phone · **Branch:** `claude/working-automation-system-al8rz1` → synced to `main` · **Agents used:** none

**Owner asked:** "start this working automation system" (screenshot of the StarNet Reel by androo.agi).

**What was done**
- Found StarNet's official open-source repo (github.com/androoAGI/starnet, MIT, v0.12.4) and read its README and install guide.
- Wrote [[StarNet Automation]]: laptop install steps, a station layout that maps the [[Team Roster]] to rooms, first scheduled jobs, and safety rules.
- Added pending decisions #16–17 (brain and budget) to [[Decisions]], and linked the note from [[00 Home]].

**Not verified**
- StarNet was not run: the cloud sandbox blocks running outside code, and it's a Windows/macOS desktop app. It must be installed on the laptop.

**Next:** see [[Active Context]].

---

## 2026-09-23 (evening): moved everything into the vault for the laptop
**Device:** phone · **Branch:** `claude/roblox-popular-game-trends-6u7sie` → synced to `main`

**Owner asked:** move all the information into the Obsidian files, to continue on the laptop.

**What was done**
- Exported the Claude design doc into [[Sproutling Isles - Design Doc]] (now the working copy) and added the map image in `vault/Attachments/`.
- Added [[Start Here - Laptop]] (download or clone, open in Obsidian, optional Obsidian Git sync, continuing with Claude, playing the game).
- Linked both from [[00 Home]], [[Sproutling Isles]] and [[Active Context]].

**Next:** see [[Active Context]].

---

## 2026-09-23 (later): first agent team run
**Device:** phone · **Branch:** `claude/roblox-popular-game-trends-6u7sie` (+ `main`) · **Agents used:** qa-tester, game-designer, live-ops-manager, roblox-engineer

**Owner asked:** "Let's get started" with the agent and memory setup.

**What was done**
- Created the `main` branch with `CLAUDE.md`, `vault/` and `.claude/agents/`, and added branch rules to `CLAUDE.md`. The owner changed the default-branch setting, but GitHub still reported the old default at the last check.
- qa-tester: [[Sproutling Isles - QA Review]] found 1 blocker (nobody could see snatch prompts), 6 majors and 18 minors, and wrote a Studio test plan.
- roblox-engineer fixed the blocker, all 6 majors and 14 minors (anti-cheat speed and reach checks, Bonk moved to R, rebirth-during-snatch, saved shop stock and luck, Studio shield off, save ordering). Lint is clean and the place was rebuilt and baked.
- game-designer: [[Sproutling Isles - Art Brief]] and [[Sproutling Isles - Trading Spec]].
- live-ops-manager: [[Sproutling Isles - Launch & Live Ops]] (checklist, beta, analytics spec, ads, weeks 1–8, Halloween "Hollow Harvest", marketing).
- Collected 15 pending owner decisions, with recommendations, in [[Decisions]].

**Not verified**
- Still nothing run in Roblox Studio. The anti-cheat thresholds (1.3x speed, 2.5 s burst) are estimates.
- Roblox menu paths, the ads API and platform limits in the new notes were written from memory or search summaries.

**Next:** see [[Active Context]].

---

## 2026-09-23: Roblox research → design doc → Sproutling Isles build → memory system
**Device:** phone (Claude app, cloud session) · **Branch:** `claude/roblox-popular-game-trends-6u7sie`

**Owner asked**
1. Which Roblox games to build, based on 2026 trends in engagement and spending, with in-depth research.
2. A game design doc for the top pick, built directly for Roblox Studio, with a map that uses several games as reference and is completely original.
3. How to continue on a laptop; whether GitHub or Obsidian could hold shared knowledge.
4. A setup where agents keep memory, know their job, and work on their own.

**What was done**
- Research, summarised in [[Roblox Market Research 2026]]. Top pick: a collect/grow/trade simulator with a social twist.
- Design doc "Sproutling Isles — Game Design Doc" in Claude Docs (link in [[Sproutling Isles]]).
- Built `roblox/sproutling-isles/` (Rojo + Luau): the map, all core systems, saving and monetization code. The map is baked into `build/SproutlingIsles.rbxlx`. Lint is clean and the map preview has been rendered.
- Created this vault, `CLAUDE.md` and the agent team in `.claude/agents/`.

**Not verified**
- The game has not been run inside Roblox Studio (not available in the cloud sandbox).
- The research figures come from search summaries; most source pages were blocked for direct reading.

**Next:** see [[Active Context]].
