---
tags: [memory, export]
updated: 2026-10-07
---
# AI Memory Export

Portable snapshot of what the vault reliably says about the owner, for pasting into — or sending as a
file to — another AI assistant. Built from this vault only (no private chat history beyond what's
already recorded here). Regenerate when it goes stale; the live version always lives at
`vault/Memory/AI Memory Export.md` on `main` in `j77jznh99s-cell/family-hub-pro`.

## Identity
- The user's time zone is US Eastern.
- The user's GitHub account is `j77jznh99s-cell`.

## Profession & work
- The user is an independent builder who makes games, apps and digital products to earn real revenue (inferred: self-employed or side business).
- The user runs a team of specialist AI agents (game designer, engineers, QA, researcher, product maker, knowledge keeper, video analyst) coordinated by an orchestrator session.

## Communication preferences
- The user wants short chat replies, with detail put in a doc or their notes vault instead.
- The user wants plain language and click-by-click steps whenever they have to act themselves (for example in Roblox Studio, Xcode or GitHub settings).
- The user prefers in-depth research and "the best answer possible" over quick takes.
- The user wants anything unverified clearly flagged (for example code not play-tested, or iOS code that's never been compiled because the sandbox has no Xcode).
- The user often asks "what needs me" / "what needs my help" to get a punch list of open decisions and blockers, rather than a full status report.

## Interests & hobbies
- The user keeps returning to Roblox game development and Roblox market trends.
- The user is interested in AI agent automation, including StarNet (a pixel-art desktop app for running agent teams).
- The user is interested in trading (crypto perpetuals and forex), with a strong emphasis on risk control.
- The user is interested in using AI for everyday personal tools too, not just the business projects — e.g. asked about replicating a wearable AI conversation-recorder as a phone feature instead of buying hardware.

## Ongoing projects
- **Sproutling Isles** (Roblox): an original grow-and-snatch simulator; core systems, analytics, leaderboards, a Halloween event ("Hollow Harvest") and a codes system are built but still not play-tested in Roblox Studio as of this export. It was targeting a closed beta 2–8 Oct 2026 and public launch 10 Oct 2026, pending a clean Studio play-test by about 1 Oct — **that target has now passed and the beta window itself is about to end with still no play-test done**; the owner needs to either run it imminently or make a call on the timeline. The test plan itself has been polished and double-checked (no code changes needed) and is ready to run. Separately waiting on the user to create 13 Robux game passes/dev products and answer about 20 pending design/budget decisions (see the vault's `Decisions.md`).
- **Family Hub** (iPhone app): helps the user stay in touch with family — streaks, XP, badges, AI-written text openers, lock/home screen widgets. Just got a new feature, the **Catch-Up Recorder**: tap-record a quick recap after a call, on-device transcription, then AI writes a summary, a note for that person's profile, and a follow-up checklist, plus a free-text "ask about this conversation" box. Built on the user's own request after they saw an ad for a $200 AI wearable recorder and asked if something similar could live on their phone instead — the answer given was that always-on background recording isn't possible as a plain iOS app (the OS blocks that), but on-demand recording is, so that's what got built. **Completely unverified** — no Xcode in the build sandbox, so the owner still needs to compile and test it on a real device. What's next for Family Hub overall (TestFlight? App Store?) is still undecided.
- **Clip Studio**: a Node web app that turns long videos into AI-selected short clips, with a newer branch adding an AI presenter (HeyGen videos, content calendar); merge decision is pending with the user.
- **Bybit Trading Bot**: a scaffolded perpetuals bot in which an AI proposes trades and a deterministic risk-gate server approves or rejects every order. Hard rule: never weaken the risk gate or place live orders without the owner's explicit go-ahead.
- **Trading Agent**: a Python forex research and paper-trading toolkit that sends daily setup alerts for the user to review and place themselves; blocked on OANDA account setup.
- **Gumroad Digital Products**: a plan to sell original digital products (family printables, Roblox guides, or templates) drafted by agents and approved by the user; the first product line is not yet chosen (family printables is the standing recommendation).
- **StarNet Automation**: a plan to run the agent team on the user's laptop via StarNet; current recommendation is to put this on hold since the cloud setup already covers the same need.
- **Video Analyst**: a newer agent capability (not a product) — give it a tutorial video/series (uploaded file or YouTube link) and it breaks it down into a written brief, then produces a condensed ~5-minute video+audio recap via Descript. Built on request; its first real run (a YouTube link) failed on an import error and hasn't been retried yet.
- **Command Deck**: a one-off status-hub web page (Artifact) built on request, showing every project's real state and the agent roster — a snapshot the owner can refresh on request, not a live feed.
- An hourly cloud Routine normally works through a task queue around the clock, and a morning summary is sent at about 7:45 am Eastern — **the hourly Routine is currently paused** (owner's own call, partly to save cost while the task queue was empty); the morning summary keeps running regardless.

## Working style & values
- The user insists that all games and products are original: genre conventions are fine, but never copied names, art, code, brands or characters — this extends informally to feature names too (e.g. declined to name a feature after a commercial product it was inspired by).
- The user wants everything done the cheapest way that still works, and never wants anything paid for without being notified first.
- The user wants AI resource use kept lean (cheapest capable model per job, capped steps and spend) — including pausing automation entirely when it's running with nothing to do, since idle runs still cost money.
- The user never wants a trading risk gate weakened or live orders placed without their explicit written go-ahead.
- The user wants agents to remember context across sessions and never ask them to repeat what is already recorded.
- The user likes to hear a recommended option when a decision is put to them.
- The user tends to ask Claude to choose when the choice is technical, and decides personally on money, branding and launch matters (inferred).
- When a request is ambiguous (which test, which device, which app), the user is fine being asked a direct clarifying question rather than having Claude guess.

## Tools & environment
- The user works mostly from a phone using the Claude app, and sometimes from a laptop where Roblox Studio is installed; also has a Mac with Xcode for iOS work (inferred from the Family Hub project needing it).
- The user has an iPhone (confirmed directly) and has asked about AI-wearable-style hardware (smart glasses, AI recorder pendants) as alternatives/supplements to phone-based AI features.
- The user uses GitHub as the single source of truth for notes and code, and has Obsidian installed but not synced.
- The user uses Claude Code on the web with cloud Routines, and has an Anthropic API account for agent workloads.
- The user's projects use Luau with Rojo (Roblox), Node.js, Swift/iOS, TypeScript and Python.
- The cloud sandbox this work happens in has no Roblox Studio, no Xcode/Swift toolchain, and no Docker daemon — anything needing those must be built here (code written, reviewed) but tested by the owner on their own devices.

## Anything else durable
- The user keeps a Markdown "vault" in the repo `j77jznh99s-cell/family-hub-pro` (branch `main`) as their long-term memory, and new AI sessions should read it first.
- The user wants Roblox games monetized through time and cosmetics, never through power over other players (inferred from an accepted design pillar).
- The user has a running Decisions log (`vault/Memory/Decisions.md`) with ~20+ small/large pending decisions across projects, most with a recommended default already proposed — worth checking there for anything not summarized above.
