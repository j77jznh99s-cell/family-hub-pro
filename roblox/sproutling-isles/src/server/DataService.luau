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

-- Returns data table and whether it is backed by the DataStore.
function DataService.load(player: Player): ({ [string]: any }, boolean)
	if not store then
		return DataService.defaultData(), false
	end
	for attempt = 1, 6 do
		local loaded = nil
		local locked = false
		local ok, err = pcall(function()
			store:UpdateAsync(key(player), function(old)
				old = old or {}
				local lock = old.lock
				if attempt < 6 and lock and lock.job ~= jobId and os.time() - lock.t < Config.SessionLockSeconds then
					locked = true
					return nil -- cancel write, another server still owns this profile
				end
				old.lock = { job = jobId, t = os.time() }
				loaded = old.data
				return old
			end)
		end)
		if ok and not locked then
			return reconcile(loaded or DataService.defaultData()), true
		end
		if not ok then
			warn("[Sproutling] load failed for", player.Name, err)
			if RunService:IsStudio() then
				return DataService.defaultData(), false
			end
		end
		if not player.Parent then
			break
		end
		task.wait(5)
	end
	return DataService.defaultData(), false
end

function DataService.save(player: Player, data, release: boolean): boolean
	if not store then
		return true
	end
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
	if not ok then
		warn("[Sproutling] save failed for", player.Name, err)
	end
	return ok
end

return DataService
