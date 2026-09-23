-- In-memory session for each player plus the shared economy helpers every service uses.

local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Species = require(Shared.Species)
local SproutModel = require(Shared.SproutModel)
local Format = require(Shared.Format)

local Net = require(script.Parent.Net)

export type Session = {
	player: Player,
	data: { [string]: any },
	persist: boolean,
	plot: Model?,
	selectedSeed: string?,
	stock: { [string]: number },
	lockUntil: number,
	shieldUntil: number,
	carrying: any?, -- set by SnatchService while this player carries a stolen Sproutling
	snatchReadyAt: number,
	luckUntil: number,
	pondReadyAt: number,
	passes: { [string]: boolean },
	joinedAt: number,
	dewRemainder: number,
	leaving: boolean?, -- set once the player starts leaving; stops autosaves and double saves
	serverMovedAt: number?, -- os.clock() of the last server teleport of this player's character
	serverMovedTo: Vector3?, -- where that teleport put them (the carry speed check measures from here too)
}

local State = {}
State.sessions = {} :: { [Player]: Session }
State.rng = Random.new()

function State.get(player: Player): Session?
	return State.sessions[player]
end

function State.multiplier(session: Session): number
	local m = 1 + session.data.rebirths * Config.RebirthBonus
	if session.passes.DoubleDew then
		m *= 2
	end
	if session.passes.VIP then
		m *= 1.1
	end
	return m
end

function State.padCapacity(session: Session): number
	return Config.BasePads + (if session.passes.BigGreenhouse then Config.BonusPadsPass else 0)
end

function State.income(session: Session): number
	local total = 0
	local capacity = State.padCapacity(session)
	for key, sprout in session.data.pads do
		-- pads above capacity (e.g. a refunded Big Greenhouse pass) don't earn
		local pad = tonumber(key)
		if pad and pad <= capacity then
			total += SproutModel.income(sprout)
		end
	end
	return total * State.multiplier(session)
end

function State.sellValue(sprout): number
	local species = Species.get(sprout.s)
	if not species then
		return 0
	end
	local base = SproutModel.income(sprout) / species.dewPerSecond -- mutation * size
	return math.floor(species.price * Config.SellRatio * base)
end

function State.newUid(): string
	return string.sub(HttpService:GenerateGUID(false), 1, 8)
end

----------------------------------------------------------------------------------------------
-- replication to the client (attributes + leaderstats + Seeds folder)

function State.syncDew(session: Session)
	local player = session.player
	player:SetAttribute("Dew", session.data.dew)
	player:SetAttribute("Income", State.income(session))
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		(stats :: any).Dew.Value = Format.number(session.data.dew)
		;(stats :: any).Rebirths.Value = session.data.rebirths
	end
end

function State.syncSeeds(session: Session)
	local folder = session.player:FindFirstChild("Seeds")
	if not folder then
		return
	end
	for _, species in Species.List do
		local value = folder:FindFirstChild(species.id) :: IntValue?
		local count = session.data.seeds[species.id] or 0
		if count > 0 and not value then
			local v = Instance.new("IntValue")
			v.Name = species.id
			v.Value = count
			v.Parent = folder
		elseif value then
			if count > 0 then
				value.Value = count
			else
				value:Destroy()
			end
		end
	end
end

function State.syncAll(session: Session)
	local player = session.player
	State.syncDew(session)
	State.syncSeeds(session)
	player:SetAttribute("Rebirths", session.data.rebirths)
	player:SetAttribute("RebirthCost", Config.RebirthBaseCost * Config.RebirthCostGrowth ^ session.data.rebirths)
	player:SetAttribute("SelectedSeed", session.selectedSeed or "")
	player:SetAttribute("ShieldUntil", session.shieldUntil)
	player:SetAttribute("LuckUntil", session.luckUntil)
	player:SetAttribute("Streak", session.data.streak)
	player:SetAttribute("LastDaily", session.data.lastDaily)
	player:SetAttribute("StarterBought", session.data.starterBought)
	player:SetAttribute("Stored", #session.data.storage)
	player:SetAttribute("Stock", HttpService:JSONEncode(session.stock))
	for key, owned in session.passes do
		player:SetAttribute("Pass_" .. key, owned)
	end
end

----------------------------------------------------------------------------------------------
-- economy

function State.addDew(session: Session, amount: number)
	amount = math.floor(amount)
	session.data.dew += amount
	if amount > 0 then
		session.data.totalDew += amount
	end
	State.syncDew(session)
end

function State.spendDew(session: Session, amount: number): boolean
	if session.data.dew < amount then
		return false
	end
	session.data.dew -= amount
	State.syncDew(session)
	return true
end

function State.addSeeds(session: Session, speciesId: string, count: number)
	session.data.seeds[speciesId] = (session.data.seeds[speciesId] or 0) + count
	if session.data.seeds[speciesId] <= 0 then
		session.data.seeds[speciesId] = nil
	end
	State.syncSeeds(session)
end

function State.notify(session: Session, text: string, color: string?)
	Net.notify(session.player, text, color)
end

return State
