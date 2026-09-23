---
tags: [memory]
updated: 2026-09-23
---
# Active Context

> Rewrite this note at the end of every session so it's true *now*. Keep it short.

## Current focus
**[[Sproutling Isles]]**: an original Roblox grow-and-snatch simulator. The design doc is done and a
full first build is pushed (not yet play-tested in Roblox Studio).

## Waiting on the owner
- [ ] Play-test `roblox/sproutling-isles/build/SproutlingIsles.rbxlx` in Roblox Studio on the laptop and report errors.
- [ ] Decide: should snatching stay core, or become an opt-in PvP toggle? (Question left as a comment in the design doc.)
- [ ] Create the 5 game passes and 8 developer products on the Creator Dashboard, and share their IDs.
- [ ] Choose where memory lives long-term (see "Open setup question" below).

## Next up for agents
1. Fix whatever the first Studio play-test turns up (roblox-engineer, then qa-tester).
2. Art pass plan: replace placeholder part-built Sproutlings (game-designer writes the brief).
3. Phase 2: Trading Booths (game-designer spec, then roblox-engineer build).

## Open setup question
Claude Code sessions start from the repo's **default branch**, which is currently
`claude/video-clip-detection-mvp-g18ggk`. For memory to load automatically in every new session,
`CLAUDE.md`, `.claude/agents/` and `vault/` must be on the default branch. Recommended: create a `main`
branch containing them, and make it the default in GitHub settings.

## Key links
- Design doc: https://claude.ai/code/artifact/a3a37801-bd42-4d71-a221-69ce94bf62e6
- Code: branch `claude/roblox-popular-game-trends-6u7sie`, folder `roblox/sproutling-isles/`
