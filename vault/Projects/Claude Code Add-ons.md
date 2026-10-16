---
tags: [tooling]
updated: 2026-10-16
---
# Claude Code Add-ons

From an Instagram reel (dbg_lab, "4 tools for coding") the owner sent on 2026-10-16. Status: **researched,
not installed** — the cloud sandbox's safety check blocks an agent from adding third-party plugins/hooks to
the repo on its own. The owner needs to approve or run the steps below.

| # | Tool | What it is | Verdict |
| - | ---- | ---------- | ------- |
| 1 | **PonyTail** (`DietrichGebert/ponytail`) | Plugin that pushes the agent to write the least code that works (YAGNI). `/ponytail-review` gives a delete-list for the current diff, `/ponytail-audit` scans the whole repo. Hooks inject its rules at session start. | **Install.** Hooks read: only write a mode flag in `~/.claude` and print rules. Fits house style (owner likes short, simple). |
| 2 | **Graphify** (`Graphify-Labs/graphify`, PyPI `graphifyy`) | Turns a codebase into a knowledge graph (`graphify-out/graph.json`, `GRAPH_REPORT.md`) so the agent reads less. Local tree-sitter parsing, no telemetry. | **Optional.** Overlaps with our own [[Knowledge Graph]] (that one is for the vault/projects; Graphify is for code). Most useful on Clip Studio and Sproutling Isles. |
| 3 | **Agent Skills** (`addyosmani/agent-skills`) | Slash commands for the dev cycle: `/spec` `/plan` `/build` `/test` `/review` `/code-simplify` `/ship`. MIT. | **Install.** Matches how our agents already work. |
| 4 | **OmniRoute** (`diegosouzapw/OmniRoute`) | Self-hosted proxy that routes Claude Code through many (often free) model providers. | **Don't install.** Sends code and API keys through third-party pools, has published CVEs, and logging into subscriptions through it can break provider terms. Free models are also weaker. |

## How to install (approve once)
Add this to `.claude/settings.json` in the repo (so every session, cloud and laptop, gets it):
```json
{
  "extraKnownMarketplaces": {
    "ponytail": { "source": { "source": "github", "repo": "DietrichGebert/ponytail" } },
    "addy-agent-skills": { "source": { "source": "github", "repo": "addyosmani/agent-skills" } }
  },
  "enabledPlugins": {
    "ponytail@ponytail": true,
    "agent-skills@addy-agent-skills": true
  }
}
```
Or in Claude Code on the laptop: `/plugin marketplace add DietrichGebert/ponytail` → `/plugin install ponytail@ponytail`,
then `/plugin marketplace add addyosmani/agent-skills` → `/plugin install agent-skills@addy-agent-skills`.

Graphify (laptop): `uv tool install graphifyy` → `graphify install --project --platform claude` → in Claude Code run `/graphify .`

## Watch out
- PonyTail's rules load into **every** session, including the hourly Routine (when resumed). Turn off per session with `/ponytail off`.
- Third-party plugins update themselves from GitHub; re-check their hooks if one changes a lot.
