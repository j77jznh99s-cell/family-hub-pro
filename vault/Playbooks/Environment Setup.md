---
tags: [playbook, tools]
---
# Environment Setup

## Cloud sandbox (Claude Code on the web)
- Fresh container every session. Only what's committed to GitHub survives.
- Roblox tooling isn't preinstalled. Install from crates.io (reachable; GitHub release downloads are blocked):
  ```bash
  cargo install rojo --locked      # builds the .rbxlx from src/
  cargo install lune --locked      # runs tools/bake-map to bake the map into the place
  cargo install selene --locked    # Luau lint (uses roblox/sproutling-isles/roblox_min.yml)
  ```
  This takes about 5–8 minutes in total. Run the installs in the background.
- Blocked hosts seen: roblox.com, wikipedia.org and several stats trackers. Web search works, but most page fetches don't.
- **Not possible in the sandbox:** running Roblox Studio or Xcode. The owner tests on the laptop.

## Owner's laptop
- Roblox Studio: open `roblox/sproutling-isles/build/SproutlingIsles.rbxlx`.
- Optional: GitHub Desktop to clone the repo; Obsidian → "Open folder as vault" → the repo's `vault/` folder.
- Optional sync: the Obsidian Git community plugin (pull on open, push on save) keeps Obsidian and GitHub in step.

## Phone
- Claude app for sessions; the GitHub app to read vault notes and code.
