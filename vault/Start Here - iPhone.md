---
tags: [index, setup]
---
# Start Here: iPhone

Two-way sync between this vault and Obsidian on iPhone. No laptop needed. About 15 minutes, one time.

**Recommended: Working Copy + Obsidian.** More reliable on iOS than running git inside Obsidian
itself, and this repo is sizeable (Roblox map assets, multiple branches), which can strain
Obsidian's own mobile git plugin. An alternative using that plugin is below if you'd rather have one
app instead of two.

## Option A: Working Copy (recommended)
1. Install **Working Copy** from the App Store (free to clone/read; a one-time in-app purchase
   unlocks push/write and background auto-sync — worth it if you'll edit notes from your phone).
2. Open Working Copy → **+** → **Clone repository** → paste:
   `https://github.com/j77jznh99s-cell/family-hub-pro.git`
3. Sign in with your GitHub account when prompted (OAuth, or a Personal Access Token if you prefer —
   github.com → Settings → Developer settings → Personal access tokens → generate one scoped to just
   this repo, `repo` permission only. Treat it like a password; don't share it).
4. Once cloned, confirm the branch shown in Working Copy is **main**.
5. Install **Obsidian** from the App Store.
6. In Obsidian: **Open folder as vault** → **Browse** → **On My iPhone** → **Working Copy** →
   `family-hub-pro` → `vault`. (Working Copy exposes its repos to the iOS Files picker, so Obsidian
   can open straight into the `vault` subfolder without needing the whole repo as the vault root.)
7. **To sync:** open Working Copy and tap **Pull** before reading (gets the latest from Claude
   sessions/laptop), then **Commit** → **Push** after you edit in Obsidian. This isn't automatic like
   the laptop's plugin setup — you trigger it in Working Copy. If you bought the sync unlock, turn on
   its background auto-sync instead so you don't have to remember.

## Option B: Obsidian Git plugin only (one app, less reliable on mobile for a repo this size)
1. Install Obsidian → Settings → Community plugins → turn off Restricted mode → Browse → install and
   enable **Git**.
2. Get a GitHub Personal Access Token (as in Option A step 3).
3. Command palette → **Git: Clone an existing remote repo** → paste the repo URL, your GitHub
   username, and the token as the password when asked. Point it at a new empty folder.
4. Once cloned, open the `vault` subfolder as your Obsidian vault.
5. Plugin settings → turn on **Auto pull on boot** and set a **auto commit-and-sync interval**
   (10 min, matching the laptop setup), so it behaves like the desktop version.
6. If clone/sync is slow or flaky given the repo's size, switch to Option A — Working Copy's native
   git implementation handles large repos better than Obsidian's in-app one.

## Continuing with Claude from your phone
- Open **claude.ai/code** in Safari (or the Claude app), start/continue a session on `family-hub-pro`.
- Claude sessions always write to `vault/` on **main** — pull in Working Copy (or let the plugin
  auto-pull) before reading, so you see the latest notes.

## Where things are
- [[00 Home]]: the index · [[Active Context]]: what's next · [[Decisions]]: pending questions
- [[Start Here - Laptop]]: the equivalent laptop/desktop setup
