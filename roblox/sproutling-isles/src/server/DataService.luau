-- Loads and saves player profiles with a lightweight session lock so a player who hops
-- servers quickly can't load stale data (which would let snatched Sproutlings be duplicated).
-- In Studio without API access, profiles run in memory only.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local DataService = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[Sproutling] DataStore unavailable, progress will not save:", result)
	end
end

local jobId = if game.JobId ~= "" then game.JobId else "studio"

-- Saves are serialised per player so an older write can never land after a newer one:
--   inFlight[userId]  - a save for this player is running right now
--   released[userId]  - the leave-save (lock release) is done; later non-release saves are
--                       dropped so a late autosave can't re-take the lock (cleared on next load)
local inFlight: { [number]: boolean } = {}
local released: { [number]: boolean } = {}

local function waitIdle(userId: number, timeout: number)
	local deadline = os.clock() + timeout
	while inFlight[userId] and os.clock() < deadline do
		task.wait(0.1)
	end
end

-- Number of saves currently running (BindToClose waits for this to reach 0).
function DataService.pendingSaves(): number
	local n = 0
	for _ in inFlight do
		n += 1
	end
	return n
end

function DataService.defaultData()
	return {
		dew = Config.StartingDew,
		totalDew = 0,
		rebirths = 0,
		seeds = table.clone(Config.StartingSeeds),
		soil = {}, -- [tostring(tile)] = { s = speciesId, ready = unixTime, total = seconds }
		pads = {}, -- [tostring(pad)] = sprout
		storage = {}, -- array of sprouts
		streak = 0,
		lastDaily = 0,
		playSeconds = 0,
		starterBought = false,
		receipts = {},
		stock = {}, -- [speciesId] = count left in this player's Seed Shop
		stockEpoch = 0, -- the restock time (ShopService.nextRestockAt) the saved stock belongs to
		luckUntil = 0, -- Luck Boost end, absolute Unix time so it survives server hops
		shieldForfeited = false, -- true once the player has snatched (no new-player shield after that)
		onb = {}, -- [stepName] = true once that onboarding funnel step has been logged, ever
		bestHatch = { rarityIndex = 0, order = 0, species = "" }, -- highest rarity/species ever
		-- hatched (0 = none yet); backs the rarest-hatch leaderboard, see LeaderboardService.
	}
end

local function reconcile(data)
	local defaults = DataService.defaultData()
	for key, value in defaults do
		if data[key] == nil then
			data[key] = value
		end
	end
	return data
end

local function key(player: Player): string
	return "p_" .. player.UserId
end

-- Returns data table, whether it is backed by the DataStore, and whether this is a brand-new
-- save (no profile existed for this player before this load) -- used to fire the "Joined"
-- onboarding step exactly once, ever, even after this field is added to already-existing saves.
function DataService.load(player: Player): ({ [string]: any }, boolean, boolean)
	if not store then
		return DataService.defaultData(), false, true
	end
	-- a fast rejoin to this same server must not read data older than the leave-save still in flight
	waitIdle(player.UserId, 30)
	released[player.UserId] = nil
	for attempt = 1, 6 do
		local loaded = nil
		local locked = false
		local isNew = false
		local ok, err = pcall(function()
			store:UpdateAsync(key(player), function(old)
				old = old or {}
				local lock = old.lock
				if attempt < 6 and lock and lock.job ~= jobId and os.time() - lock.t < Config.SessionLockSeconds then
					locked = true
					return nil -- cancel write, another server still owns this profile
				end
				old.lock = { job = jobId, t = os.time() }
				isNew = old.data == nil
				loaded = old.data
				return old
			end)
		end)
		if ok and not locked then
			return reconcile(loaded or DataService.defaultData()), true, isNew
		end
		if not ok then
			warn("[Sproutling] load failed for", player.Name, err)
			if RunService:IsStudio() then
				return DataService.defaultData(), false, true
			end
		end
		if not player.Parent then
			break
		end
		task.wait(5)
	end
	return DataService.defaultData(), false, true
end

function DataService.save(player: Player, data, release: boolean): boolean
	if not store then
		return true
	end
	local userId = player.UserId
	waitIdle(userId, 30)
	if released[userId] then
		return true -- this player already left and released the lock; nothing newer to write
	end
	inFlight[userId] = true
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function(old)
			old = old or {}
			if old.lock and old.lock.job ~= jobId then
				return nil -- another server took over; never overwrite its newer data
			end
			old.data = data
			old.lock = if release then nil else { job = jobId, t = os.time() }
			return old
		end)
	end)
	inFlight[userId] = nil
	if ok and release then
		released[userId] = true
	end
	if not ok then
		warn("[Sproutling] save failed for", player.Name, err)
	end
	return ok
end

return DataService
