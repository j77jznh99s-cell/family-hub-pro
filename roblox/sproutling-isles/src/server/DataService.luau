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
--   inFlight[userId]  - number of UpdateAsync writes running for this player (nil when idle,
--                       else 1; only a release save that outwaited a stuck write makes it 2)
--   released[userId]  - the leave-save ran: "saved" if it wrote (lock released), "lost" if another
--                       server owned the profile. Later non-release saves are dropped either way so
--                       a late write can't re-take the lock; they return true only after "saved",
--                       so a receipt waits for the owning server instead (cleared on next load)
--   active            - save() calls not yet returned, waiting or writing (for BindToClose)
local inFlight: { [number]: number } = {}
local released: { [number]: "saved" | "lost" } = {}
local active = 0
-- pending[userId]: the same count per player. load waits for 0 so a leave-save still queued behind
-- another write can't land after a fast rejoin's load (stale data, and released re-set on the new session)
local pending: { [number]: number } = {}

local function track(userId: number, delta: number)
	active += delta
	local n = (pending[userId] or 0) + delta
	pending[userId] = if n > 0 then n else nil
end

-- A leave-save waits this long for a running write instead of the usual 30 s, so it is not lost.
local RELEASE_WAIT_SECONDS = 120

-- True once no write is running for this player; false if the timeout ran out first.
-- No yield between a true result and the caller's inFlight increment, so two waiters can't both start.
local function waitIdle(userId: number, timeout: number, busy: { [number]: number }?): boolean
	local deadline = os.clock() + timeout
	local map = busy or inFlight
	while map[userId] do
		if os.clock() >= deadline then
			return false
		end
		task.wait(0.1)
	end
	return true
end

-- Number of saves still in progress, waiting or writing (BindToClose waits for this to reach 0).
function DataService.pendingSaves(): number
	return active
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
		-- Halloween "Hollow Harvest" (EventService.luau). berries = Moonberries balance;
		-- lanternDay = UTC day (os.time() // 86400) the +20 daily-first-lantern bonus was last paid;
		-- stallBuys = { [itemId] = { day = utcDay, n = count } } per-item daily purchase caps.
		event = { id = "halloween2026", berries = 0, lanternDay = 0, stallBuys = {} },
		skins = {}, -- [skinId] = true once earned, e.g. skins.haunted; kept forever, earn-only
		skin = "", -- currently equipped cosmetic plot skin id ("" = none)
		codes = {}, -- [code] = true once redeemed, ever (Week 5 Codes system, see CodesService.luau)
		-- Week 1 launch incentive: true once earned (first-ever join fell inside Week 1), independent
		-- of whether the real Roblox badge could be awarded yet (Config.FoundingGardenerBadgeId may
		-- still be 0). Backs the title/cosmetic-greenhouse-flag part of the spec later; see
		-- init.server.luau and Events.FoundingGardenerWindow.
		foundingGardener = false,
		-- Week 8 "Frostbloom Seedling" teaser: a login-day tracker only, no reward yet. `days` is the
		-- set of distinct UTC calendar days (os.time() // 86400) recorded inside
		-- Events.FrostbloomTeaserWindow; `qualified` flips true once 3 distinct days are recorded (see
		-- Events.FrostbloomTeaserDaysNeeded). The Frostfawn seed grant is a future task for whatever
		-- builds the Frostbloom Advent Gift system, which should check this flag on Day 1 (Sat 12 Dec).
		frostbloomTeaser = { days = {}, qualified = false },
		-- RPG (LootService): best rarity owned per weapon, and monster materials for cooking
		gear = { sword = { r = 1 }, bow = { r = 1 }, staff = { r = 1 } },
		materials = {}, -- [materialId] = count
		bag = {}, -- weapons carried: { u = uid, b = base, r = rarity } (InventoryService)
		armor = 0, -- worn armour tier, see Shared/Shops.Armor
		consumables = {}, -- [itemId] = count (potions, meals)
		unlocks = {}, -- [unlockId] = true: "companion" (Beast Tamer), "horse" (Stables), "skyward" (quest)
		quests = { active = {}, done = {}, caches = {} }, -- QuestService
		level = 1, -- LevelService
		xp = 0, -- XP towards the next level
		vehicles = {}, -- [vehicleId] = { paint = index, trim = index } (Shared/Vehicles)
		crates = { wood = 1, silver = 0, gold = 0 }, -- unopened reward crates (Shared/Crates)
		arenaBest = 0, -- best arena wave survived
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
-- When load gives up (profile unread) it reports false: a returning player must not get new-player rewards.
function DataService.load(player: Player): ({ [string]: any }, boolean, boolean)
	if not store then
		return DataService.defaultData(), false, true
	end
	-- a fast rejoin to this same server must not read data older than the leave-save still in flight;
	-- if that write is still stuck after 30 s, run this session unsaved rather than load stale data
	if not waitIdle(player.UserId, 30, pending) then
		warn("[Sproutling] load gave up for", player.Name, "(previous save still running), progress will not save")
		return DataService.defaultData(), false, false
	end
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
	return DataService.defaultData(), false, false
end

function DataService.save(player: Player, data, release: boolean): boolean
	if not store then
		return true
	end
	local userId = player.UserId
	track(userId, 1)
	if not waitIdle(userId, if release then RELEASE_WAIT_SECONDS else 30) and not release then
		-- another write is still running: never overlap it. Autosaves retry next round; a receipt
		-- returns NotProcessedYet and Roblox redelivers it.
		track(userId, -1)
		warn("[Sproutling] save deferred for", player.Name, "(previous save still running)")
		return false
	end
	-- A release that waited RELEASE_WAIT_SECONDS writes anyway: a request that hasn't returned in
	-- 2 min has failed in practice, and dropping the leave-save would lose the session's progress.
	if released[userId] then
		track(userId, -1)
		-- this player already left; nothing newer to write. Only report success if the leave-save
		-- actually landed, else a receipt would confirm a grant that never got saved.
		return released[userId] == "saved"
	end
	inFlight[userId] = (inFlight[userId] or 0) + 1
	local wrote = false
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function(old)
			old = old or {}
			if old.lock and old.lock.job ~= jobId then
				wrote = false
				return nil -- another server took over; never overwrite its newer data
			end
			old.data = data
			old.lock = if release then nil else { job = jobId, t = os.time() }
			wrote = true
			return old
		end)
	end)
	local left = (inFlight[userId] or 1) - 1
	inFlight[userId] = if left > 0 then left else nil
	track(userId, -1)
	if ok and release then
		released[userId] = if wrote then "saved" else "lost"
	end
	if not ok then
		warn("[Sproutling] save failed for", player.Name, err)
	elseif not wrote then
		warn("[Sproutling] save skipped for", player.Name, "(another server owns the profile)")
	end
	-- false when nothing was written, so ProcessReceipt doesn't report a grant that never got saved
	return ok and wrote
end

return DataService
