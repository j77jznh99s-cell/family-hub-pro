# CLAUDE.md — read this first, every session

This repo is the owner's **workspace and long-term memory**. Several projects live here, and
`vault/` is a shared knowledge base (an Obsidian-compatible folder of Markdown notes) that
carries context between sessions, devices (phone and laptop) and agents.

## Start of every session (do this before anything else)

1. Read `vault/00 Home.md` (the index).
2. Read `vault/Memory/Active Context.md` for what's in flight and what the owner wants next.
3. Open the relevant project note in `vault/Projects/` and its **Tasks** list.
4. If you're a subagent, read your own role card in `vault/Agents/Team Roster.md`.

Don't ask the owner to repeat context that is already in the vault.

## End of every session / task (not optional)

Before you finish, update memory so the next session can pick up where you left off:

1. Add a dated entry at the **top** of `vault/Memory/Session Log.md` (template: `vault/Templates/Session Log Entry.md`).
2. Update the project's task list: tick done items, add new ones with an owner role.
3. Record any decision the owner made in `vault/Memory/Decisions.md`.
4. Rewrite `vault/Memory/Active Context.md` so it's true *now* (keep it under ~40 lines).
5. Commit and push the vault changes on the branch you're working on.

## Projects

| Project | Where the code lives (branch → folder) | Vault note |
| --- | --- | --- |
| Sproutling Isles (Roblox game) | `claude/roblox-popular-game-trends-6u7sie` → `roblox/sproutling-isles/` | `vault/Projects/Sproutling Isles.md` |
| Clip Studio (AI video clipper) | `claude/video-clip-detection-mvp-g18ggk` → repo root (`src/`) | `vault/Projects/Clip Studio.md` |
| Family Hub (iPhone app + widgets) | `claude/family-hub-widget-1w7cv9` → `FamilyHub/` | `vault/Projects/Family Hub.md` |
| Bybit trading bot (risk-gated) | `claude/bybit-trading-bot-risk-gate-r7apfr` → repo root | `vault/Projects/Bybit Trading Bot.md` |

## Agents

Specialist subagents are defined in `.claude/agents/` (one per job title). The main session acts
as **orchestrator**: it picks the right agent, gives it a precise brief (including which vault notes
to read), then checks the result and writes memory. See `vault/Playbooks/How Agents Work.md`.

## House rules

- The owner often works from a phone. Keep chat replies short and put detail in the vault or a doc.
- Games must be **original**: borrow genre conventions, never names, art or code from other games.
- Never commit secrets (`.env`, API keys, Roblox cookies). Use `.env.example` for placeholders.
- Trading bot: never weaken or bypass the risk gate, and never place live orders without the owner's explicit go-ahead.
- Flag anything you could not verify (for example, Roblox code not play-tested in Studio).
