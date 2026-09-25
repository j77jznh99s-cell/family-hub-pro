---
tags: [project, automation]
status: setup (waiting on the owner's laptop install)
updated: 2026-09-25
---
# StarNet Automation

The owner wants to run the agent team as a **working automation system**, like the StarNet
Reel by `androo.agi` ("AI Agent Business Factory").

## What StarNet is
- A free, open-source (MIT) **desktop app** for Windows and macOS: a pixel-art space station where
  real AI agents do real work.
- **Rooms** are teams with set permissions, **hallways** are hand-offs between teams, and
  **placed objects** give agents tools. The layout you draw is the workflow the agents run.
- Other features: agents run at the same time, **Night Shift** (agents keep working inside a leash
  you set), cron schedules, an **OUTBOX** folder for finished files, budgets and a spending ledger,
  MCP connectors, and chat with the station from Telegram, Discord or Slack.
- Official source: github.com/androoAGI/starnet (v0.12.4 on 2026-09-25). Downloads:
  github.com/androoAGI/starnet-releases/releases/latest. Many forks exist, so use **only** these two.
- It **can't run on an iPhone**. It needs the laptop and must stay on for agents to keep working.

## Laptop install (about 15 minutes)
1. Download the installer from the releases page:
   - Windows: `StarNet_<version>_x64-setup.exe`
   - Mac with an M chip: `StarNet_<version>_aarch64.dmg` (Intel Mac: `x64.dmg`)
2. Install it. If Windows or macOS says the publisher is unknown or the app is "damaged",
   **stop** and don't bypass the warning (the StarNet install guide says the same).
3. On first launch, choose a "brain" (the AI model):
   - **Anthropic sign-in** or an **OpenRouter key** for the best results (costs money per run), or
   - **Ollama** for free, local, weaker results (install ollama.com, run `ollama pull llama3.1`).
4. **Set a budget first** (a daily spending cap) before you start any agent.

## The station layout for this workspace
One room per project, using the roles from [[Team Roster]]. For each agent, paste the text from
`.claude/agents/<name>.md` as its instructions and give it read access to the `vault/` folder.

| Room | Crew (from [[Team Roster]]) | Tools to grant | Hand-off lane to |
| --- | --- | --- | --- |
| Bridge (orchestrator) | knowledge-keeper | Read/write `vault/` | Every room |
| Research Lab | market-researcher | Web search | Design Bay |
| Design Bay | game-designer, live-ops-manager | Read/write `vault/` | Build Bay |
| Build Bay (Roblox) | roblox-engineer | Files in `roblox/sproutling-isles/` | QA Deck |
| App Workshop | app-engineer | Files in the Clip Studio / Family Hub folders | QA Deck |
| QA Deck | qa-tester | Read code, run tests | Bridge |
| Trading Desk | app-engineer (read-only) | Read-only, **no exchange keys** | Bridge |

Good first jobs to schedule:
- **Every morning:** knowledge-keeper summarizes [[Active Context]] and open tasks, and sends it to the OUTBOX (or Telegram).
- **Weekly:** market-researcher refreshes [[Roblox Market Research 2026]].
- **On demand:** Design Bay → Build Bay → QA Deck for each new Sproutling Isles feature.

## Safety rules (same as `CLAUDE.md`)
- **Trading bot:** no Bybit keys in StarNet, no live orders, and nothing touches the risk gate
  without the owner's explicit go-ahead.
- Keep **Night Shift** on a tight leash and a budget cap. Review its log each morning.
- Never paste API keys into the vault or the repo. StarNet keeps keys in the OS keychain.
- Keep work in git: agents change files in the cloned repo, and the owner reviews and pushes.

## Tasks
- [ ] **Owner:** install StarNet on the laptop (steps above) and pick a brain.
- [ ] **Owner:** decide the provider and the daily budget (see [[Decisions]], pending #16–17).
- [ ] **Owner:** clone this repo on the laptop ([[Start Here - Laptop]], Option B) so agents can read the vault.
- [ ] **Owner + Claude:** build the rooms in the table above, then run one test job (the morning summary).
- [ ] **knowledge-keeper:** after the first week, record what worked in this note.

## Not verified
- Claude read StarNet's README and install guide but **could not run it** in the cloud sandbox
  (running outside code is blocked there, and it's a desktop app). Menu names above come from its docs.
