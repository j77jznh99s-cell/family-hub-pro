# Store listing draft (Gumroad + itch.io)

> Internal file. Don't put it in the buyer's zip. The owner reviews, edits and publishes.

**Title:** Daily Streaks Kit for Roblox: Daily Tasks, Rewards and Login Streaks

**Price:** $9.99 (test price; check sales after 30 days)

**Short description:** Drop-in daily tasks with streaks for your Roblox game. It saves player
data, works on phone, PC and console, and you hook it up with one line of code per task.

**Description:**
Give players a reason to come back every day. Each player gets 3 tasks a day, chosen from
your own list. They get a reward for each task, a bonus for finishing all three, and a streak that
grows every day they return. Every 5th day in a row pays a milestone bonus.

- One line to count progress: `DailyStreaks.track(player, "collect", 1)`
- All settings in one file: tasks, rewards, reset time, colours, shortcut key
- Ready-made panel built in code (no image assets), with a countdown, streak, progress bars and pop-up messages
- Works on touch, mouse/keyboard and gamepad
- Saves with DataStores (retries, autosave, shutdown save, never overwrites data after a failed load)
- Level-gated tasks, task-board parts, and signals to give your own items or XP
- Server-checked progress: players can't fake it from the client
- Rojo project included, and step-by-step install for plain Studio
- Unit tests for the task and streak logic

**What you get:** Luau source (6 scripts), README, example script, licence.

**Licence:** Use it in any number of your games, including commercial ones. You can't resell or redistribute the files.

**Tags:** roblox, luau, daily-quests, daily-rewards, streak, retention, game-system, scripts

**itch.io settings:** Kind = Assets; Classification = "Game assets"; **AI disclosure = "AI Generated"**
(an AI agent wrote the code, which a human reviewed). This is required on every itch.io asset page since Nov 2024.

**Honesty notes (keep in the listing):** this is code only, with no 3D models or images. It needs a Roblox
experience to drop into.

## Before publishing (owner checklist)
- [ ] Play-tested in Studio: tasks show, progress counts, rewards are paid, and the streak carries over (set
      `ResetHourUTC` to the next hour to watch a reset), saving works with API access on.
- [ ] `luau tests/Logic.spec.luau` passes.
- [ ] Originality check ([[Gumroad Digital Products]] section 6) passed.
- [ ] Screenshots: the panel open, a toast, and the button (take them in Studio).
- [ ] Zip `src/`, `examples/`, `tests/`, `default.project.json`, `README.md`, `LICENSE.txt` (not this file).
