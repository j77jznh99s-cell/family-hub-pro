-- Player levels (Shared/Levels): XP from monsters, quests, the arena, tomes and hatching.
--
-- Each level-up gives a reward crate (Shared/Crates), and fires LevelUp to every client: the
-- player who levelled gets the big celebration screen, everyone nearby sees a pillar of light.
-- Level and XP are mirrored as player attributes (Level, XP, XPNext) for the HUD and as a
-- "Level" leaderstat, and reported to the level leaderboard.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Levels = require(Shared.Levels)
local Crates = require(Shared.Crates)

local State = require(script.Parent.State)
local LeaderboardService = require(script.Parent.LeaderboardService)

local LevelService = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local LevelUpRemote = Instance.new("RemoteEvent")
LevelUpRemote.Name = "LevelUp" -- server -> all clients: (player, level, rank, unlock lines, crate tier)
LevelUpRemote.Parent = remotes

local function sync(player: Player, data: any)
	player:SetAttribute("Level", data.level)
	player:SetAttribute("XP", math.floor(data.xp))
	player:SetAttribute("XPNext", Levels.xpFor(data.level))
	player:SetAttribute("Rank", Levels.rank(data.level))
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Level") :: IntValue?
	if stats and not value then
		local v = Instance.new("IntValue")
		v.Name = "Level"
		v.Parent = stats
		value = v
	end
	if value then
		value.Value = data.level
	end
	for _, tier in Crates.Order do
		player:SetAttribute("Crates_" .. tier, data.crates and data.crates[tier] or 0)
	end
end

function LevelService.level(player: Player): number
	local session = State.get(player)
	return session and session.data.level or 1
end

-- Adds XP and handles any level-ups it causes.
function LevelService.addXP(player: Player, amount: number, _reason: string?)
	local session = State.get(player)
	if not session or amount <= 0 then
		return
	end
	local data = session.data
	data.level = data.level or 1
	data.xp = (data.xp or 0) + amount
	data.crates = data.crates or {}
	local levelled = false
	while data.level < Levels.Max and data.xp >= Levels.xpFor(data.level) do
		data.xp -= Levels.xpFor(data.level)
		data.level += 1
		levelled = true
		local tier = Levels.crateFor(data.level)
		data.crates[tier] = (data.crates[tier] or 0) + 1
		LevelUpRemote:FireAllClients(player, data.level, Levels.rank(data.level), Levels.unlocksAt(data.level), tier)
	end
	if data.level >= Levels.Max then
		data.xp = math.min(data.xp, Levels.xpFor(data.level))
	end
	sync(player, data)
	if levelled then
		LeaderboardService.reportStat(player, "level", data.level)
	end
end

function LevelService.init()
	local function watch(player: Player)
		task.spawn(function()
			for _ = 1, 60 do
				local session = State.get(player)
				if session and player:FindFirstChild("leaderstats") then
					session.data.level = session.data.level or 1
					session.data.xp = session.data.xp or 0
					sync(player, session.data)
					LeaderboardService.reportStat(player, "level", session.data.level)
					return
				end
				task.wait(0.5)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
end

return LevelService
