-- Daily Streaks Kit: example. Shows the three ways to hook the kit into your game.
-- Delete this script once you've wired up your own events.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local DailyStreaks = require(ServerScriptService:WaitForChild("DailyStreaks"):WaitForChild("DailyStreaksService"))

-- 1. A "Coins" leaderstat so the default rewards have somewhere to go (skip if you have one).
Players.PlayerAdded:Connect(function(player)
	if not player:FindFirstChild("leaderstats") then
		local stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		local coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Parent = stats
		stats.Parent = player
	end
end)

-- 2. Count progress from your own game events. The stat names match Config.Pool.
--    Here: any part named "Coin" counts as a collected coin when touched.
local function hookCoin(part: BasePart)
	local taken = false
	part.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and not taken then
			taken = true
			DailyStreaks.track(player, "collect", 1)
			part.Transparency = 1
			task.delay(5, function()
				part.Transparency = 0
				taken = false
			end)
		end
	end)
end
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and d.Name == "Coin" then
		hookCoin(d)
	end
end

-- Other examples (put these where your game decides the event happened, on the server):
--   DailyStreaks.track(killer, "defeat", 1)
--   DailyStreaks.track(winner, "win", 1)
--   DailyStreaks.track(player, "chest", 1)

-- 3. Give extra rewards your own way.
DailyStreaks.AllCompleted:Connect(function(player, streak, isMilestone)
	if isMilestone then
		print(player.Name .. " hit a " .. streak .. "-day streak. Give them something special here.")
	end
end)

-- Optional: use your own level system for minLevel tasks.
-- DailyStreaks.setLevelProvider(function(player) return MyLevels.get(player) end)
