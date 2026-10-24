-- The Monster Journal (Shared/Journal): counts each player's defeats per monster kind in
-- data.journal.kills, pays for discoveries, masteries and completed regions (each once), and
-- sends the client its journal after every change.
--
-- Journal remote: server -> client ("state", { kills = {...}, regions = { [id] = true } })

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Journal = require(Shared.Journal)
local Combat = require(Shared.Combat)

local State = require(script.Parent.State)
local EnemyService = require(script.Parent.EnemyService)
local LevelService = require(script.Parent.LevelService)
local CrateService = require(script.Parent.CrateService)

local JournalService = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local JournalRemote = Instance.new("RemoteEvent")
JournalRemote.Name = "Journal"
JournalRemote.Parent = remotes

type Book = { kills: { [string]: number }, regions: { [string]: boolean } }

local function bookOf(session: any): Book
	session.data.journal = session.data.journal or { kills = {}, regions = {} }
	local book = session.data.journal
	book.kills = book.kills or {}
	book.regions = book.regions or {}
	return book
end

local function push(player: Player)
	local session = State.get(player)
	if session then
		JournalRemote:FireClient(player, "state", bookOf(session))
	end
end

local function onKill(player: Player, kindId: string)
	local session = State.get(player)
	local kind = Combat.Enemies[kindId]
	local region = Journal.RegionOf[kindId]
	if not session or not kind or not region then
		return
	end
	local book = bookOf(session)
	local count = (book.kills[kindId] or 0) + 1
	book.kills[kindId] = count
	if count == 1 then
		State.addDew(session, Journal.DiscoverDew, "Journal")
		State.notify(session, string.format("New Monster Journal entry: %s! (+%d Dew)", kind.name, Journal.DiscoverDew), "#c8e6ff")
		-- every entry in the region discovered: the region's reward, once
		if not book.regions[region.id] then
			local all = true
			for _, k in region.kinds do
				if (book.kills[k] or 0) < 1 then
					all = false
					break
				end
			end
			if all then
				book.regions[region.id] = true
				State.addDew(session, region.reward.dew, "JournalRegion")
				CrateService.give(player, region.reward.crate)
				State.notify(session, string.format("Journal complete: %s! +%d Dew and a crate.", region.name, region.reward.dew), "#ffd27a")
			end
		end
	end
	if count == Journal.masterAt(kind.boss) then
		State.addDew(session, Journal.MasterDew, "JournalMaster")
		LevelService.addXP(player, Journal.MasterXP, "Journal")
		State.notify(session, string.format("Mastered: %s (%d defeated). +%d Dew", kind.name, count, Journal.MasterDew), "#a0ffa0")
	end
	push(player)
end

function JournalService.init()
	EnemyService.onKill(onKill)
	local function onPlayer(player: Player)
		task.spawn(function()
			for _ = 1, 40 do
				if State.get(player) then
					break
				end
				task.wait(0.5)
			end
			push(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
end

return JournalService
