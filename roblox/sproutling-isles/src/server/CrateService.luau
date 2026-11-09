-- Reward crates (Shared/Crates): earned from level-ups, the arena and quests, or bought at the
-- Royal Treasury's crate vault. The client asks to open one; the server rolls, pays out, and
-- tells the client which reward came up so the opening reel can stop on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crates = require(Shared.Crates)
local Loot = require(Shared.Loot)

local State = require(script.Parent.State)
local InventoryService = require(script.Parent.InventoryService)
local LootService = require(script.Parent.LootService)
local LevelService = require(script.Parent.LevelService)

local CrateService = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local CrateRemote = Instance.new("RemoteEvent")
CrateRemote.Name = "Crate" -- client -> server: ("open", tier); server -> client: ("result", tier, rewardIndex)
CrateRemote.Parent = remotes

local rng = Random.new()
local busy: { [Player]: number } = {}

-- Gives a crate (level-ups, arena, quests).
function CrateService.give(player: Player, tier: string, count: number?)
	local session = State.get(player)
	if not session or not Crates.Tiers[tier] then
		return
	end
	session.data.crates = session.data.crates or {}
	session.data.crates[tier] = (session.data.crates[tier] or 0) + (count or 1)
	player:SetAttribute("Crates_" .. tier, session.data.crates[tier])
end

local function open(player: Player, tier: any)
	local session = State.get(player)
	if not session or typeof(tier) ~= "string" or not Crates.Tiers[tier] then
		return
	end
	if os.clock() < (busy[player] or 0) then
		return
	end
	local data = session.data
	data.crates = data.crates or {}
	if (data.crates[tier] or 0) <= 0 then
		State.notify(session, "You have no " .. Crates.Tiers[tier].name .. "s.", "#ffb070")
		return
	end
	busy[player] = os.clock() + 2.5
	data.crates[tier] -= 1
	player:SetAttribute("Crates_" .. tier, data.crates[tier])
	State.track(session, "crate")
	local index = Crates.roll(tier, rng:NextNumber())
	local reward = Crates.Tiers[tier].rewards[index]
	-- the reel spins for a couple of seconds on the client; pay out once it lands
	CrateRemote:FireClient(player, "result", tier, index)
	task.delay(2.4, function()
		if not player.Parent then
			return
		end
		if reward.kind == "dew" then
			State.addDew(session, reward.amount or 0, "Crate:" .. tier)
		elseif reward.kind == "xp" then
			LevelService.addXP(player, reward.amount or 0, "Crate")
		elseif reward.kind == "potion" then
			data.consumables = data.consumables or {}
			data.consumables.potion_health = (data.consumables.potion_health or 0) + (reward.amount or 1)
		elseif reward.kind == "material" then
			InventoryService.addMaterial(player, reward.id :: string, reward.amount or 1)
		elseif reward.kind == "weapon" then
			LootService.giveWeapon(player, Loot.rollWeapon(rng, reward.rarity or 1))
		end
		State.notify(session, Crates.Tiers[tier].name .. ": " .. reward.label .. "!", "#ffd27a")
		InventoryService.push(player)
	end)
end

-- One free crate a day for logging in; every 7th day in a row adds a silver one.
local function dailyCrate(player: Player)
	for _ = 1, 40 do
		if State.get(player) then
			break
		end
		task.wait(0.5)
	end
	local session = State.get(player)
	if not session then
		return
	end
	local data = session.data
	local today = os.time() // 86400
	data.dailyCrate = data.dailyCrate or { day = 0, streak = 0 }
	local daily = data.dailyCrate
	if daily.day >= today then
		return
	end
	daily.streak = if daily.day == today - 1 then daily.streak + 1 else 1
	daily.day = today
	CrateService.give(player, "wood")
	local extra = ""
	if daily.streak % 7 == 0 then
		CrateService.give(player, "silver")
		extra = " and a Silver Crate for a 7-day streak"
	end
	State.notify(session, string.format("Daily gift: a Wooden Crate%s! (day %d in a row) Open it with K.", extra, daily.streak), "#ffd27a")
end

function CrateService.init()
	local Players = game:GetService("Players")
	Players.PlayerAdded:Connect(function(player)
		task.spawn(dailyCrate, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(dailyCrate, player)
	end
	CrateRemote.OnServerEvent:Connect(function(player, action, tier)
		if action == "open" then
			open(player, tier)
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return CrateService
