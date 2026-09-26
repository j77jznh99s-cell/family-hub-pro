-- Cross-server leaderboards: top lifetime Dew earners and each player's single rarest hatch.
-- Displayed on a physical board in the Plaza (near the Rebirth Shrine, see MapBuilder.luau).
--
-- The only spec for this feature is one line in
-- vault/Projects/Sproutling Isles - Launch & Live Ops.md ("Week 5": in-world leaderboards,
-- income and rarest hatch). Everything below is this engineer's design call, flagged for
-- game-designer/owner review:
--   - Uses OrderedDataStoreService so rankings are global across every server, matching how
--     the game already treats Dew and rebirths as server-independent progress.
--   - Income score = `data.totalDew` (lifetime Dew earned, already tracked by State.addDew).
--     Written on the same 5-minute batch/leave cadence as the income analytics Source event
--     (see init.server.luau's flushIncome), so this adds zero extra per-tick DataStore writes.
--   - Rarest-hatch score = rarityIndex * 1000 + species.order, using the exact same rarity and
--     species ordering Species.luau already defines elsewhere (Species.RarityOrder, .order).
--     Only written when a hatch beats the player's own previous best (session.data.bestHatch),
--     so a whole session of common hatches costs zero DataStore writes for that player.
--   - OrderedDataStore values must be plain numbers, so player names and (for the hatch board)
--     the species/rarity text live in a small companion plain DataStore, refreshed alongside
--     the score so they never go stale relative to it.
--   - The physical board refreshes every Config.LeaderboardRefreshSeconds by re-querying both
--     OrderedDataStores. An empty result (fresh deploy, no data anywhere yet) shows a
--     "be the first" message instead of erroring.

local DataStoreService = game:GetService("DataStoreService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Species = require(Shared.Species)
local Format = require(Shared.Format)

local LeaderboardService = {}

local RARITY_INDEX: { [string]: number } = {}
for index, rarity in Species.RarityOrder do
	RARITY_INDEX[rarity] = index
end

local incomeStore: OrderedDataStore? = nil
local hatchStore: OrderedDataStore? = nil
local metaStore: GlobalDataStore? = nil

do
	local okIncome, income = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.DataStoreName .. "_LB_Income")
	end)
	local okHatch, hatch = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.DataStoreName .. "_LB_Hatch")
	end)
	local okMeta, meta = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName .. "_LB_Meta")
	end)
	if okIncome then
		incomeStore = income
	end
	if okHatch then
		hatchStore = hatch
	end
	if okMeta then
		metaStore = meta
	end
	if not (okIncome and okHatch and okMeta) then
		warn("[Sproutling] leaderboard DataStores unavailable, boards will stay empty:", income, hatch, meta)
	end
end

local incomeLabel: TextLabel? = nil
local hatchLabel: TextLabel? = nil

local function keyOf(player: Player): string
	return tostring(player.UserId)
end

-- Player name (and, for the hatch board, species/rarity text) kept alongside the OrderedDataStore
-- score. Fire-and-forget: a failed write here never blocks gameplay, and just leaves the board
-- showing the previous (or no) name until it succeeds another time.
local function setMeta(player: Player, patch: { [string]: any })
	if not metaStore then
		return
	end
	task.spawn(function()
		pcall(function()
			metaStore:UpdateAsync(keyOf(player), function(old)
				old = old or {}
				for k, v in patch do
					old[k] = v
				end
				return old
			end)
		end)
	end)
end

local function getMeta(key: string): { [string]: any }?
	if not metaStore then
		return nil
	end
	local ok, value = pcall(function()
		return metaStore:GetAsync(key)
	end)
	if ok then
		return value
	end
	return nil
end

-- Call on the same batched cadence as the income analytics Source event (never per-tick).
function LeaderboardService.reportIncome(player: Player, totalDew: number)
	if incomeStore then
		local score = math.floor(totalDew)
		task.spawn(function()
			pcall(function()
				(incomeStore :: OrderedDataStore):SetAsync(keyOf(player), score)
			end)
		end)
	end
	setMeta(player, { name = player.DisplayName })
end

-- Call right after a hatch. `session` is the player's State.Session; `species` is the just-hatched
-- Species row. Only writes to the DataStore when this beats the player's saved best.
function LeaderboardService.reportHatch(player: Player, session: any, species: any)
	local rarityIndex = RARITY_INDEX[species.rarity] or 0
	local order = species.order or 0
	local newScore = rarityIndex * 1000 + order
	local best = session.data.bestHatch
	local bestScore = (best and (best.rarityIndex * 1000 + best.order)) or 0
	if newScore <= bestScore then
		return
	end
	session.data.bestHatch = { rarityIndex = rarityIndex, order = order, species = species.id }
	if hatchStore then
		task.spawn(function()
			pcall(function()
				(hatchStore :: OrderedDataStore):SetAsync(keyOf(player), newScore)
			end)
		end)
	end
	setMeta(player, { name = player.DisplayName, hatchSpecies = species.name, hatchRarity = species.rarity })
end

----------------------------------------------------------------------------------------------
-- physical board display

local function fetchTop(store: OrderedDataStore?): { { key: string, value: number } }
	if not store then
		return {}
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, Config.LeaderboardSize)
	end)
	if not ok or not pages then
		return {}
	end
	local ok2, page = pcall(function()
		return (pages :: DataStorePages):GetCurrentPage()
	end)
	if not ok2 then
		return {}
	end
	return page or {}
end

local function render(label: TextLabel?, title: string, lines: { string })
	if not label then
		return
	end
	if #lines == 0 then
		label.Text = title .. "\n\nNo entries yet -\nbe the first!"
		return
	end
	local out = { title, "" }
	for _, line in lines do
		table.insert(out, line)
	end
	label.Text = table.concat(out, "\n")
end

function LeaderboardService.refresh()
	local incomeEntries = fetchTop(incomeStore)
	local incomeLines = {}
	for i, entry in incomeEntries do
		local meta = getMeta(entry.key)
		local name = (meta and meta.name) or ("Player " .. entry.key)
		table.insert(incomeLines, i .. ". " .. name .. " - " .. Format.number(entry.value) .. " Dew")
	end
	render(incomeLabel, "\240\159\143\134 TOP INCOME", incomeLines)

	local hatchEntries = fetchTop(hatchStore)
	local hatchLines = {}
	for i, entry in hatchEntries do
		local meta = getMeta(entry.key)
		local name = (meta and meta.name) or ("Player " .. entry.key)
		local species = (meta and meta.hatchSpecies) or "?"
		local rarity = (meta and meta.hatchRarity) or "?"
		table.insert(hatchLines, i .. ". " .. name .. " - " .. species .. " (" .. rarity .. ")")
	end
	render(hatchLabel, "\240\159\140\159 RAREST HATCH", hatchLines)
end

-- `map` is the built map (see MapBuilder.buildLeaderboards); missing parts (a stale bake from
-- before this feature) are handled gracefully so a republish is never required to avoid errors.
function LeaderboardService.init(map: Instance)
	local plaza = map:FindFirstChild("Plaza")
	local board = plaza and plaza:FindFirstChild("Leaderboards")
	local incomeBoard = board and board:FindFirstChild("IncomeBoard")
	local hatchBoard = board and board:FindFirstChild("RarityBoard")
	local incomeGui = incomeBoard and incomeBoard:FindFirstChild("Label")
	local hatchGui = hatchBoard and hatchBoard:FindFirstChild("Label")
	incomeLabel = incomeGui and (incomeGui:FindFirstChild("Text") :: TextLabel?)
	hatchLabel = hatchGui and (hatchGui:FindFirstChild("Text") :: TextLabel?)

	task.spawn(function()
		while true do
			LeaderboardService.refresh()
			task.wait(Config.LeaderboardRefreshSeconds)
		end
	end)
end

return LeaderboardService
