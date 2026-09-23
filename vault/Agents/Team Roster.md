---
tags: [agents]
---
# Team Roster

Each role is a Claude Code subagent defined in `.claude/agents/<name>.md`. The main session (the
**orchestrator**) sends work to them. Every agent follows [[How Agents Work]].

| Agent (job title) | Owns | Reads first | Writes | Never does |
| --- | --- | --- | --- | --- |
| `market-researcher` | Trend and competitor research, revenue benchmarks | [[Roblox Market Research 2026]], [[Active Context]] | Research notes in `vault/Projects/`, with sources and as-of dates | Present unverified numbers as fact |
| `game-designer` | Game design: loops, economy, balance, specs, art briefs | Project note, design doc, `src/shared/Config.luau` + `Species.luau` | Specs and briefs in the vault; tunables in shared config | Write gameplay systems code |
| `roblox-engineer` | Luau and Rojo code, map, saving, monetization code | Project note, `roblox/sproutling-isles/README.md`, the relevant `src/` files | Code, README, build file | Change design numbers without a spec or decision |
| `qa-tester` | Reviews, lint and build checks, test plans, bug lists | Project note, the diff or PR, open tasks | Bug reports and test plans in the vault | Mark something verified that wasn't run |
| `live-ops-manager` | Events calendar, monetization tuning, analytics, launch checklist | Project note, design doc (Economy + Retention) | Live-ops plans, event specs, KPI reviews | Add pay-to-win items |
| `app-engineer` | Non-Roblox code: [[Clip Studio]], [[Family Hub]], [[Bybit Trading Bot]] | That project's note and README | Code on that project's branch | Touch the trading bot's risk gate or live trading without explicit owner approval |
| `knowledge-keeper` | Vault hygiene: logs, decisions, active context, links | [[Active Context]], [[Session Log]], git log | Memory notes | Invent decisions or facts |

## Hand-offs that work well
- Design spec (**game-designer**) → build (**roblox-engineer**) → review (**qa-tester**) → memory update (**knowledge-keeper**)
- Trend refresh (**market-researcher**) → roadmap proposal (**live-ops-manager**) → owner decides → [[Decisions]]
