# Daily Streaks Kit for Roblox

Give players 3 daily tasks, rewards for each one, a bonus for finishing all of them, and a
streak that grows every day they come back. It includes a ready-made panel that works on phone,
PC and console. To hook it into your game, you add one line wherever something happens.

```lua
DailyStreaks.track(player, "collect", 1)
```

## What's inside

| File | Where it goes | What it does |
| --- | --- | --- |
| `src/shared/Config.luau` | ReplicatedStorage › DailyStreaks › **Config** (ModuleScript) | Your tasks, rewards, reset time, colours. The only file you need to edit |
| `src/shared/Logic.luau` | ReplicatedStorage › DailyStreaks › **Logic** (ModuleScript) | Task rolling, progress and streak rules (no Roblox services, unit-tested) |
| `src/server/DailyStreaksService.luau` | ServerScriptService › DailyStreaks › **DailyStreaksService** (ModuleScript) | Saving, rewards, the API |
| `src/server/Main.server.luau` | ServerScriptService › DailyStreaks › **Main** (Script) | Starts the service |
| `src/client/DailyStreaksClient.client.luau` | StarterPlayer › StarterPlayerScripts › DailyStreaks › **DailyStreaksClient** (LocalScript) | The panel, button and pop-up messages |
| `examples/ExampleUsage.server.luau` | ServerScriptService (Script, optional) | Shows how to hook it into your game |
| `tests/Logic.spec.luau` | not in your game | Tests for the logic (`luau tests/Logic.spec.luau`) |

## Install

**With Rojo:** `rojo serve` in this folder, then connect from Studio. `default.project.json` maps
everything to the right places.

**By hand (no Rojo):**
1. In ReplicatedStorage, add a Folder named `DailyStreaks`. Inside it, add two ModuleScripts named
   `Config` and `Logic` and paste in the two files from `src/shared`.
2. In ServerScriptService, add a Folder named `DailyStreaks`. Inside it, add a ModuleScript named
   `DailyStreaksService` and a Script named `Main`, and paste in the two files from `src/server`.
3. In StarterPlayer › StarterPlayerScripts, add a LocalScript and paste in
   `src/client/DailyStreaksClient.client.luau`.
4. Optional: paste `examples/ExampleUsage.server.luau` into a Script in ServerScriptService.
5. To test saving in Studio, turn on Game Settings › Security › **Enable Studio Access to API Services**.

Press Play. A **Daily 0/3** button appears at the bottom left. You can also press **J** to open the panel.

## Set up your tasks

Open `Config.luau` and edit `Config.Pool`:

```lua
{ id = "fish", text = "Catch %d fish", stat = "fish", target = 10, reward = 200 },
{ id = "boss", text = "Defeat %d boss", stat = "boss", target = 1, reward = 400, minLevel = 10 },
```

Then count it from your own server code:

```lua
local DailyStreaks = require(game.ServerScriptService.DailyStreaks.DailyStreaksService)
DailyStreaks.track(player, "fish", 1)
```

- `minutes` is counted for you, once per minute played (`Config.TrackPlaytime`).
- Several tasks can share a stat, and one `track` call counts toward all of them.
- **Don't rename an `id` after launch**, because ids are saved with each player. You can remove a
  task safely: players who had it today just won't see it any more.

## Rewards

By default, rewards are added to a `leaderstats` value named `Coins` (`Config.LeaderstatName`).
To give items, XP or anything else, set `Config.LeaderstatName = nil` and use the signals:

```lua
DailyStreaks.TaskCompleted:Connect(function(player, task)
	-- task.id, task.reward, task.stat ...
end)

DailyStreaks.AllCompleted:Connect(function(player, streak, isMilestone)
	-- isMilestone is true every Config.StreakMilestoneEvery days in a row
end)
```

## API (server only)

| Call | What it does |
| --- | --- |
| `DailyStreaks.track(player, stat, amount?)` | Count progress (`amount` defaults to 1). Safe to call before the player's data has loaded, because it's queued |
| `DailyStreaks.open(player)` | Open the panel for a player, e.g. from an NPC |
| `DailyStreaks.getState(player)` | Read today's tasks, streak and best streak |
| `DailyStreaks.setLevelProvider(fn)` | Use your own level system for `minLevel` tasks (default: the `Level` attribute on the Player) |
| `DailyStreaks.TaskCompleted` / `.AllCompleted` | Signals, see above |

**Task boards:** tag any Part with `DailyTaskBoard` (Tag Editor), and it gets a "Daily tasks" prompt that opens the panel.

## How it works

- **New tasks every day** at `Config.ResetHourUTC` (default midnight UTC). Each player gets their
  own mix, and only tasks their level allows. A player gets the same tasks on every server all day.
- **Streak:** finish every task in a day and the streak goes up. If you miss a day, it goes back to 0.
  Your best streak is kept.
- **Saving:** one DataStore key per player, autosaved every 2 minutes, on leave and on shutdown.
  If loading fails, that session doesn't save, so it never overwrites good data.
- **Security:** progress only comes from server code. The client can only ask to refresh the
  panel, at most once a second.

## Limits

- Saves are last-write-wins with no session locking. That's fine for this small amount of data. If
  a player joins a second server within seconds of leaving the first, they could lose up to 2
  minutes of task progress.
- Text is English only. You can change the strings in `Config.luau` and the client script.

## Licence

See `LICENSE.txt`. You can use it in any game, including paid and commercial ones. You can't resell
or share the kit's files.
