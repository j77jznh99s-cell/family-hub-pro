---
tags: [project, automation]
status: setup (waiting on the owner's laptop install)
updated: 2026-09-25
---
# StarNet Automation

The owner wants to run the agent team as a **working automation system**, like the StarNet
Reel by `androo.agi` ("AI Agent Business Factory").

> **Checked against StarNet's source code** (commit `7ee93ce`, 23 Sep 2026, release v0.12.4) on
> 2026-09-25. Its own docs say "code is the source of truth", and its README overstates some things,
> so every claim below was checked in the code. See "How this was checked" at the bottom.

## What StarNet is
- A free, open-source (MIT) **desktop app** for Windows and macOS: a pixel-art space station where
  real AI agents do real work, with real cost.
- **Rooms** are teams. **Objects you place in a room give its agents tools.** The layout is the workflow.
- It **can't run on an iPhone**. It runs on the laptop, and the laptop must be on for jobs to run.
  From the phone, you talk to it through Telegram, Discord, Slack, Signal or Matrix.
- Official source: github.com/androoAGI/starnet. Downloads: github.com/androoAGI/starnet-releases/releases/latest
  (v0.12.4, released 20 Sep 2026). Many forks exist, so use **only** these two.

## Laptop install (about 20 minutes)
1. **Clone this repo first** ([[Start Here - Laptop]], Option B) so the agents can read the vault.
2. Download StarNet from the releases page:
   - Windows: `StarNet_<version>_x64-setup.exe`
   - Mac with an M chip: `StarNet_<version>_aarch64.dmg` (Intel Mac: `x64.dmg`)
3. Install it. If Windows or macOS says the publisher is unknown or the app is "damaged", **stop**.
   Don't bypass the warning (StarNet's install guide says the same).
4. Pick a "brain" (SETTINGS → PROVIDERS). **There is no "sign in with Claude"**: Anthropic works only with an API key.
   - **Anthropic API key** (console.anthropic.com, pay as you go, **separate from a Claude.ai subscription**). Best quality.
   - **OpenRouter key**: one key for many models, pay as you go.
   - **ChatGPT sign-in** ("Codex"): uses an existing ChatGPT subscription, no key.
   - **Ollama**: free and local, but weaker (install ollama.com, then `ollama pull llama3.1`).
5. **Set spending caps before running anything** (SETTINGS → Budget: per run, per agent, per day, overall).
   **Every cap starts at 0, which means *no limit*.**
6. **Projects → add folder** → pick the cloned `family-hub-pro` folder. This does two useful things:
   - Agents can **read** the whole repo. **Writes ask you first.** `.env` files and `.git` internals are always blocked.
   - StarNet loads our `CLAUDE.md` as house rules, so the vault protocol and the trading-bot rules apply to its
     agents. **This only happens in chats opened from the project and in jobs whose working folder is the repo.**

## How the tools work (what to place in each room)
| Object to place | What it gives the agent | Asks you first? | In scheduled / Night Shift runs |
| --- | --- | --- | --- |
| WORKSTATION | A seat, so an agent works there | — | — |
| SHELF, RACK, SAFE or VAULT* | Files: read, write, edit | Writes: yes | Reads only (repo); writes only in the agent's own folder, and only if you allow "build while away" |
| DISH, UPLINK or BEACON | Web search and web pages | Reading: no | Allowed |
| CORE | Long-term memory and saved skills | No | Allowed |
| WORKBENCH | Shell commands and tests | **Every command** | **Blocked**, unless you give that one scheduled job its own "unattended terminal" grant |

\*StarNet's "VAULT" object is only a file cabinet. It has nothing to do with our Obsidian `vault/`.

## The station layout (start small)
Your laptop copy of the repo is on `main`, which has the vault but **not** the Roblox game code or
the other projects' code (those live on their own branches). So phase 1 is vault-only work.

**Phase 1: research and planning (works on `main`)**
| Room | Crew (paste text from `.claude/agents/<name>.md` into INSTRUCTIONS) | Place |
| --- | --- | --- |
| Bridge | knowledge-keeper | WORKSTATION, SHELF, CORE |
| Research Lab | market-researcher | WORKSTATION, DISH, SHELF |
| Design Bay | game-designer, live-ops-manager | WORKSTATION, SHELF, CORE |

**Phase 2: building (later, after phase 1 works)**
Check out the project branch in a second folder (for example `git worktree add ../sproutling claude/roblox-popular-game-trends-6u7sie`),
add that folder as a second project, and add a Build Bay (roblox-engineer) and a QA Deck (qa-tester)
with a WORKBENCH. **Leave out the trading bot completely.**

## First jobs to schedule
| Job | Agent | When | Send result to |
| --- | --- | --- | --- |
| Summarize [[Active Context]] and open tasks | knowledge-keeper | Weekdays, 8 am | Your Telegram chat |
| Refresh [[Roblox Market Research 2026]] with sources | market-researcher | Mondays | The station (local) |

When creating each job: set its **working folder** to the repo, and **connect Telegram first** (a job
can only send to a chat that's already connected; otherwise it fails its pre-check).
These jobs only **read** the repo and the web, so they run unattended without extra permissions.
Anything they'd change comes back to you as a result. You (or a Claude session) put it in the vault.

## Safety rules
- **Trading bot:** not in StarNet at all. No Bybit keys, no live orders, and nothing touches the risk gate.
- **Git:** say **no** if an agent asks to run `git push`. You review changes and push them yourself.
- **Night Shift:** keep it off for the first week. When on, it does at most one action every ~45 minutes,
  up to the daily "leash" count you set, and the E-STOP halts it.
- Never paste API keys into the vault or the repo. StarNet stores keys in the OS keychain and hides them in logs.

## Tasks
- [ ] **Owner:** answer [[Decisions]] #16–17 (brain and budget).
- [ ] **Owner:** clone the repo, install StarNet, pick the brain, set the caps, add the repo folder (steps above).
- [ ] **Owner + Claude:** build the phase 1 rooms and run the morning summary once by hand before scheduling it.
- [ ] **knowledge-keeper:** after the first week, record what worked here and decide on phase 2.

## How this was checked (2026-09-25)
Read StarNet's code in a Claude cloud session: `sidecar/providers/registry.js` (sign-in options),
`sidecar/budgetcaps.js` (caps, 0 = no cap), `sidecar/capability/registry.js` and `frontend/app/propsprites.js`
(objects and tools), `sidecar/tools/builtin/fs.js`, `sidecar/pathtrust.js` and `sidecar/projectbless.js`
(folder access and `CLAUDE.md` loading), `sidecar/permissions.js` (unattended rules), `sidecar/cron-store.js`
(job delivery), `sidecar/tools/registry.js` (which tools ask first) and `sidecar/nightshift.js`.
Reviewed in two passes: the first found the errors listed below, the second re-checked every new claim.

**Not verified:** StarNet wasn't run. The cloud sandbox blocks running outside code, and it's a desktop app.
Screen and menu names come from the code and docs, so they may look slightly different in the app.

**Fixed from the first version (2026-09-25):** there's no "Anthropic sign-in" (it needs an API key);
budget caps default to no limit; agents only see the repo after you add it as a project; the Roblox code
isn't on `main`; scheduled jobs can't write files or run commands on their own; `CLAUDE.md`
only loads for project chats and jobs with the repo as their working folder.
