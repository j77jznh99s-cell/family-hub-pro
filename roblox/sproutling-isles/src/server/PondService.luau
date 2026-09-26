-- Wishing Pond (free casts) and the Sky Well (better loot, rebirth 1+).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Species = require(Shared.Species)
local Format = require(Shared.Format)

local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local Analytics = require(script.Parent.Analytics)
local Prompts = require(script.Parent.Prompts)

local PondService = {}

-- Outcome weights (sum 100). "dew" currently pays 15-45 s of the player's income (min 25).
-- TODO(game-designer/owner, QA m10): the design intent was "minutes of income"; decide which is right.
local POND_TABLE = {
	{ kind = "dew", weight = 55 },
	{ kind = "seed", weight = 35, rarities = { Common = 80, Uncommon = 20 } },
	{ kind = "seed", weight = 8, rarities = { Rare = 75, Epic = 25 }, lucky = true },
	{ kind = "seed", weight = 1.8, rarities = { Legendary = 1 }, lucky = true },
	{ kind = "seed", weight = 0.18, rarities = { Mythic = 1 }, lucky = true },
	{ kind = "seed", weight = 0.02, rarities = { Secret = 1 }, lucky = true },
}

local SKY_TABLE = {
	{ kind = "dew", weight = 40 },
	{ kind = "seed", weight = 30, rarities = { Uncommon = 60, Rare = 40 } },
	{ kind = "seed", weight = 22, rarities = { Rare = 40, Epic = 60 }, lucky = true },
	{ kind = "seed", weight = 6, rarities = { Legendary = 1 }, lucky = true },
	{ kind = "seed", weight = 1.6, rarities = { Mythic = 1 }, lucky = true },
	{ kind = "seed", weight = 0.4, rarities = { Secret = 1 }, lucky = true },
}

local function roll(lootTable, luckyRod: boolean)
	local total = 0
	for _, entry in lootTable do
		total += entry.weight * (if luckyRod and entry.lucky then 2 else 1)
	end
	local r = State.rng:NextNumber() * total
	for _, entry in lootTable do
		r -= entry.weight * (if luckyRod and entry.lucky then 2 else 1)
		if r <= 0 then
			return entry
		end
	end
	return lootTable[1]
end

local function bobber(position: Vector3)
	local p = Instance.new("Part")
	p.Name = "Bobber"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(1.2, 1.2, 1.2)
	p.Anchored = true
	p.CanCollide = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 90, 90)
	p.Position = position
	p.Parent = workspace
	Debris:AddItem(p, Config.PondBiteSeconds + 0.5)
end

local function cast(player: Player, lootTable, where: Vector3, label: string)
	local session = State.get(player)
	if not session then
		return
	end
	local now = os.clock()
	if now < session.pondReadyAt then
		State.notify(session, "The water is still settling. Try again in " .. math.ceil(session.pondReadyAt - now) .. "s.", "#a0e0ff")
		return
	end
	session.pondReadyAt = now + Config.PondCooldownSeconds
	if not session.data.onb.FirstPondCast then
		session.data.onb.FirstPondCast = true
		Analytics.onboarding(player, "FirstPondCast")
	end
	bobber(where + Vector3.new((State.rng:NextNumber() - 0.5) * 20, 0, -8 - State.rng:NextNumber() * 20))
	State.notify(session, "You make a wish at the " .. label .. "...", "#a0e0ff")
	task.wait(Config.PondBiteSeconds)
	if not player.Parent then
		return
	end
	local entry = roll(lootTable, session.passes.LuckyRod == true)
	if entry.kind == "dew" then
		local amount = math.max(25, State.income(session) * 30 * (0.5 + State.rng:NextNumber()))
		State.addDew(session, amount, "Pond")
		State.notify(session, "The " .. label .. " gave you " .. Format.number(amount) .. " Dew!", "#a0e0ff")
	else
		local species = Species.rollByRarity(entry.rarities, State.rng)
		State.addSeeds(session, species.id, 1)
		State.notify(session, "You fished up a " .. species.name .. " seed (" .. species.rarity .. ")!", "#ffe070")
		if table.find({ "Legendary", "Mythic", "Secret" }, species.rarity) then
			Net.announce(player.DisplayName .. " fished a " .. species.rarity .. " " .. species.name .. " seed from the " .. label .. "!", "#ffe070")
		end
	end
end

function PondService.init(map: Instance)
	local pond = map.Pond
	for i = 1, 4 do
		local spot = pond:FindFirstChild("CastSpot" .. i) :: BasePart
		local prompt = Prompts.create(spot, "Cast (free)", "Wishing Pond")
		prompt.Triggered:Connect(function(player)
			cast(player, POND_TABLE, spot.Position, "Wishing Pond")
		end)
	end

	local well = map.SkyGarden:FindFirstChild("SkyWell") :: BasePart
	local wellPrompt = Prompts.create(well, "Make a wish", "Sky Well")
	wellPrompt.Triggered:Connect(function(player)
		local session = State.get(player)
		if session and session.data.rebirths >= 1 then
			cast(player, SKY_TABLE, well.Position + Vector3.new(0, 1, 12), "Sky Well")
		elseif session then
			State.notify(session, "The Sky Well only answers players who have rebirthed.", "#d0a0ff")
		end
	end)
end

return PondService
