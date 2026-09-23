---
tags: [index, setup]
---
# Start Here: laptop

Everything from the phone sessions is in this vault. Here's how to open it on the laptop and keep it in sync.

## Option A: quick look (5 minutes, read-only snapshot)
1. Go to **github.com/j77jznh99s-cell/family-hub-pro**.
2. Check the branch dropdown says **main**, then click **Code → Download ZIP**.
3. Unzip it (right-click → Extract All).
4. In Obsidian: **Open folder as vault** → choose the extracted `family-hub-pro-main/vault` folder.

Edits you make in this copy **won't** reach GitHub or Claude. Use Option B for real work.

## Option B: two-way sync (recommended, about 15 minutes, one time)
1. Install **GitHub Desktop** (desktop.github.com) and sign in.
2. **File → Clone repository** → pick `family-hub-pro` → choose a folder, for example `Documents\family-hub-pro`.
3. In GitHub Desktop, set **Current branch** to **main**.
4. In Obsidian: **Open folder as vault** → `Documents\family-hub-pro\vault`.
5. Optional, for automatic sync: Obsidian → Settings → Community plugins → Browse → install **Git** → enable it → turn on "Auto pull on startup" and "Auto commit-and-sync interval: 10 min".
   Without the plugin: before you start, click **Fetch/Pull** in GitHub Desktop; when you finish, **Commit to main → Push**.

Claude sessions write to the vault on `main`. Pull first, so you see the latest notes.

## Continuing with Claude on the laptop
- Open **claude.ai/code** in a browser, start a session on `family-hub-pro`, and say **"Follow CLAUDE.md"**. It reads this vault automatically.
- To continue the exact same conversation, open the session link from your phone's Claude app.

## Playing the game on the laptop
- In GitHub Desktop, switch the branch to `claude/roblox-popular-game-trends-6u7sie` and open `roblox/sproutling-isles/build/SproutlingIsles.rbxlx` in Roblox Studio.
- Or download that one file from GitHub (branch dropdown → that branch → open the file → **Download raw file**).
- Test plan: [[Sproutling Isles - QA Review]].

## Where things are
- [[00 Home]]: the index · [[Active Context]]: what's next · [[Decisions]]: the 15 questions waiting for you
- [[Sproutling Isles - Design Doc]]: the full game design (vault copy)
