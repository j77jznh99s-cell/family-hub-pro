---
tags: [playbook, memory]
updated: 2026-10-08
---
# Knowledge Graph

A structured layer on top of the vault's plain-Markdown memory: nodes (people, projects, decisions,
tasks, or anything else worth naming) connected by typed edges (`owns`, `has_decision`, `blocks`,
`relates_to`, ...). It exists to answer multi-hop questions the vault's free text can't answer
directly — "what decisions are blocking StarNet?" instead of grepping every note.

**Why this instead of the VPS/Telegram agent from the 2026-10-08 tutorial video:** that setup wanted
a rented VPS + Tailscale + always-on messaging bridge just to get a knowledge graph. This gets the
graph itself — the actual learning/recall benefit — with none of the cost, hosting, or security
surface. See [[Agent Platform Comparison]] and [[Decisions]] #21 for why a separate always-on agent
platform is on hold.

## Where it lives
- Data: `vault/Memory/knowledge-graph.json` (plain JSON, git-tracked like the rest of the vault).
- Code: `tools/knowledge-graph/graph.js` (library) + `tools/knowledge-graph/cli.js` (CLI).
- Tests: `tests/knowledgeGraph.test.js` (`npm test` runs it along with Clip Studio's own tests).

No server, no new npm dependency, no API key. Any agent or the owner can read/write it with plain
`node` from the repo root.

## Schema
- **Node**: `{ id, type, label, data, createdAt, updatedAt }`. `id` defaults to `type:slug(label)`
  if you don't pass one (e.g. `project:clip-studio`). `data` is free-form JSON for whatever extra
  fields matter (status, dates, numbers).
- **Edge**: `{ from, to, type, data, createdAt }`. Directional; both ends must already exist.

No fixed enum of types — use whatever's natural (`project`, `person`, `decision`, `task`,
`workout`, `muscle`, ...) and stay consistent within a topic so traversal queries make sense.

## CLI usage
```bash
# add a node (id auto-derived from type:label if --id omitted)
node tools/knowledge-graph/cli.js add-node --type project --label "Clip Studio" --data '{"status":"active"}'

# connect two existing nodes
node tools/knowledge-graph/cli.js add-edge --from owner --to project:clip-studio --type owns

# look up one node
node tools/knowledge-graph/cli.js get project:clip-studio

# search
node tools/knowledge-graph/cli.js find --type project
node tools/knowledge-graph/cli.js find --label clip

# one-hop neighbors (direction: out | in | both; optional --edge-type filter)
node tools/knowledge-graph/cli.js neighbors owner --direction out --edge-type owns

# multi-hop: follow a chain of edge types and get the final layer of nodes
node tools/knowledge-graph/cli.js traverse owner --path owns,has_decision

# counts by type
node tools/knowledge-graph/cli.js stats
```

All commands accept `--file <path>` to point at a different graph file (mainly for tests/experiments
— normal use just takes the default `vault/Memory/knowledge-graph.json`).

## What's seeded today (2026-10-08)
One `person` node (`owner`), one `project` node per table row in [[00 Home]] (`owns` edges from
`owner`), and one `decision` node for [[Decisions]] #21 linked from `project:starnet-automation` via
`has_decision`. Extend it as real multi-hop questions come up — don't pre-build structure nobody
queries yet.

## Who maintains it
`knowledge-keeper` (see [[Team Roster]]) keeps it in sync with [[Decisions]] and the project notes as
part of normal end-of-session memory upkeep. Any agent can add nodes/edges relevant to its own work
before handing off.
