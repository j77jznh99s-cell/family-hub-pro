-- Daily Streaks Kit: settings. Edit this file to fit your game; everything else can stay as is.

local Config = {}

-- How many tasks each player gets per day, and when tasks reset (hour of the day, UTC, 0-23).
Config.TasksPerDay = 3
Config.ResetHourUTC = 0

-- The task pool. Each player gets TasksPerDay different tasks from it each day.
--   id       unique name (saved with the player, so don't rename ids after launch)
--   text     shown to the player; %d becomes the target
--   stat     what your scripts count with DailyStreaks.track(player, stat, amount)
--   target   how many are needed
--   reward   paid to Config.LeaderstatName when the task is done (0 for none)
--   minLevel optional: only offered when the player's level is at least this
-- "minutes" is counted automatically while Config.TrackPlaytime is true.
Config.Pool = {
	{ id = "play", text = "Play for %d minutes", stat = "minutes", target = 10, reward = 100 },
	{ id = "collect", text = "Collect %d coins", stat = "collect", target = 50, reward = 150 },
	{ id = "defeat", text = "Defeat %d enemies", stat = "defeat", target = 15, reward = 200 },
	{ id = "win", text = "Win %d round", stat = "win", target = 1, reward = 250 },
	{ id = "chest", text = "Open %d chests", stat = "chest", target = 3, reward = 150 },
	{ id = "boss", text = "Defeat %d boss", stat = "boss", target = 1, reward = 400, minLevel = 10 },
}

-- Bonus for finishing every task in a day, and a bigger one every Nth full day in a row.
Config.AllDoneBonus = 300
Config.StreakMilestoneEvery = 5 -- 0 turns milestones off
Config.StreakMilestoneBonus = 1000

-- Rewards are added to this leaderstats value (IntValue or NumberValue) if the player has it.
-- Set to nil to pay rewards only through the TaskCompleted / AllCompleted signals.
Config.LeaderstatName = "Coins"

-- Count "minutes" automatically, one per minute in game.
Config.TrackPlaytime = true

-- Saving. Turn on "Enable Studio Access to API Services" in Game Settings to save in Studio.
Config.SaveData = true
Config.DataStoreName = "DailyStreaks_v1"

-- Player's level, used for minLevel. Default reads a "Level" attribute on the Player; replace with
-- DailyStreaks.setLevelProvider(function(player) return ... end) from your own server script.
Config.LevelAttribute = "Level"

-- UI
Config.ToggleKey = Enum.KeyCode.J -- keyboard shortcut to open/close the panel
Config.ShowButton = true -- the "Daily" button on screen
Config.BoardTag = "DailyTaskBoard" -- tag any part with this (Tag Editor) to add an "open" prompt
Config.Colors = {
	panel = Color3.fromRGB(28, 32, 44),
	row = Color3.fromRGB(40, 46, 62),
	text = Color3.fromRGB(240, 242, 248),
	muted = Color3.fromRGB(160, 168, 190),
	accent = Color3.fromRGB(255, 196, 64),
	bar = Color3.fromRGB(90, 200, 120),
	barBack = Color3.fromRGB(22, 26, 36),
	done = Color3.fromRGB(120, 230, 150),
}

return Config
