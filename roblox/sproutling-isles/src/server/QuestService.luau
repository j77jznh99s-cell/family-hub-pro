-- Quests: the people out in the wilds (Shared/Quests), their quests, quest items, cairns, the
-- wind shrines to the sky isles and the sky caches.
--
-- Everything is found by attribute in the map WildsBuilder made (see its header). Progress is
-- saved in session.data.quests = { active = { [questId] = progress }, done = { [questId] = true },
-- caches = { [isleName] = true } }, where progress = { n = kills or items, taken = { [nodeId] = true },
-- visited = { [spotId] = true }, talked = bool }. The client gets a snapshot after every change
-- (QuestState) and opens the talk window when the server says so (QuestDialog).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Quests = require(Shared.Quests)
local Loot = require(Shared.Loot)
local Combat = require(Shared.Combat)

local State = require(script.Parent.State)
local Prompts = require(script.Parent.Prompts)
local InventoryService = require(script.Parent.InventoryService)
local LootService = require(script.Parent.LootService)
local EnemyService = require(script.Parent.EnemyService)

local QuestService = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local function remote(name: string): RemoteEvent
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotes
	return event
end
local StateRemote = remote("QuestState") -- server -> client: (snapshot)
local ActionRemote = remote("QuestAction") -- client -> server: ("accept" | "turnin" | "abandon", questId)
local DialogRemote = remote("QuestDialog") -- server -> client: (npcId)

local TALK_RANGE = 22
local MAX_ACTIVE = 6
local rng = Random.new()

local npcRoots: { [string]: BasePart } = {}
local nodes: { [string]: { part: BasePart, item: string } } = {}
local spots: { [string]: Vector3 } = {}
local camps: { [string]: { Vector3 } } = {} -- enemy kind -> camp positions
local shrines: { [string]: BasePart } = {}
local landings: { [string]: Vector3 } = {}

----------------------------------------------------------------------------------------------
-- progress

type Progress = { n: number, taken: { [string]: boolean }, visited: { [string]: boolean }, talked: boolean? }

local function data(player: Player): any?
	local session = State.get(player)
	if not session then
		return nil
	end
	local d = session.data
	d.quests = d.quests or {}
	d.quests.active = d.quests.active or {}
	d.quests.done = d.quests.done or {}
	d.quests.caches = d.quests.caches or {}
	return d
end

local function hasMaterials(d: any, need: { [string]: number }?): boolean
	for id, count in need or {} do
		if (d.materials[id] or 0) < count then
			return false
		end
	end
	return true
end

-- How far along a quest is, and whether it can be handed in.
local function progressOf(d: any, q: Quests.Quest, p: Progress): (number, boolean)
	local o = q.objective
	local goal = Quests.goal(q)
	local n = 0
	if o.kind == "slay" or o.kind == "collect" then
		n = p.n
	elseif o.kind == "visit" then
		for _ in p.visited do
			n += 1
		end
	elseif o.kind == "talk" then
		n = if p.talked then 1 else 0
	elseif o.kind == "bring" then
		n = if hasMaterials(d, o.materials) then 1 else 0
	end
	return math.min(n, goal), n >= goal
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function nearest(from: Vector3, list: { Vector3 }): Vector3?
	local best, bestD = nil, math.huge
	for _, p in list do
		local d = (p - from).Magnitude
		if d < bestD then
			best, bestD = p, d
		end
	end
	return best
end

-- Where the tracker should point for a quest.
local function targetOf(player: Player, q: Quests.Quest, p: Progress, ready: boolean): Vector3?
	local root = rootOf(player)
	local from = if root then root.Position else Vector3.zero
	local o = q.objective
	if ready or o.kind == "bring" then
		local turnIn = npcRoots[q.turnIn or q.giver]
		return turnIn and turnIn.Position
	end
	if o.kind == "talk" then
		local npc = npcRoots[o.npc or ""]
		return npc and npc.Position
	elseif o.kind == "slay" then
		return nearest(from, camps[o.target or ""] or {})
	elseif o.kind == "collect" then
		local list = {}
		for id, node in nodes do
			if node.item == o.target and not p.taken[id] then
				table.insert(list, node.part.Position)
			end
		end
		return nearest(from, list)
	elseif o.kind == "visit" then
		local list = {}
		for _, id in o.spots or {} do
			if not p.visited[id] and spots[id] then
				table.insert(list, spots[id])
			end
		end
		return nearest(from, list)
	end
	return nil
end

local function push(player: Player)
	local d = data(player)
	if not d then
		return
	end
	local active = {}
	for id, p in d.quests.active do
		local q = Quests.get(id)
		if q then
			local n, ready = progressOf(d, q, p)
			active[id] = { n = n, goal = Quests.goal(q), ready = ready, target = targetOf(player, q, p, ready) }
		end
	end
	StateRemote:FireClient(player, { active = active, done = d.quests.done, skyward = d.unlocks and d.unlocks.skyward == true })
end
QuestService.push = push

local function notify(player: Player, text: string, color: string?)
	local session = State.get(player)
	if session then
		State.notify(session, text, color)
	end
end

local function nearNpc(player: Player, npcId: string): boolean
	local root, npc = rootOf(player), npcRoots[npcId]
	return root ~= nil and npc ~= nil and (root.Position - npc.Position).Magnitude <= TALK_RANGE
end

----------------------------------------------------------------------------------------------
-- actions

local function canStart(d: any, q: Quests.Quest): boolean
	if d.quests.done[q.id] or d.quests.active[q.id] then
		return false
	end
	for _, req in q.requires or {} do
		if not d.quests.done[req] then
			return false
		end
	end
	return true
end

local function giveReward(player: Player, d: any, q: Quests.Quest)
	local r = q.reward
	local session = State.get(player)
	if r.dew and session then
		State.addDew(session, r.dew, "Quest:" .. q.id)
	end
	for id, count in r.materials or {} do
		InventoryService.addMaterial(player, id, count)
	end
	if r.weapon then
		LootService.giveWeapon(player, Loot.rollWeapon(rng, r.weapon))
	end
	if r.potions then
		d.consumables = d.consumables or {}
		d.consumables.potion_health = (d.consumables.potion_health or 0) + r.potions
	end
	if r.unlock then
		d.unlocks = d.unlocks or {}
		d.unlocks[r.unlock] = true
		player:SetAttribute("Unlock_" .. r.unlock, true)
	end
	InventoryService.push(player)
end

local function onAction(player: Player, action: any, questId: any)
	local d = data(player)
	if not d or typeof(questId) ~= "string" then
		return
	end
	local q = Quests.get(questId)
	if not q then
		return
	end
	if action == "accept" then
		if not nearNpc(player, q.giver) or not canStart(d, q) then
			return
		end
		local count = 0
		for _ in d.quests.active do
			count += 1
		end
		if count >= MAX_ACTIVE then
			notify(player, "Your quest log is full. Finish or drop a quest first.", "#ffb070")
			return
		end
		d.quests.active[q.id] = { n = 0, taken = {}, visited = {}, talked = false }
		notify(player, "New quest: " .. q.name, "#ffd27a")
	elseif action == "turnin" then
		local p = d.quests.active[q.id]
		if not p or not nearNpc(player, q.turnIn or q.giver) then
			return
		end
		local _, ready = progressOf(d, q, p)
		if not ready then
			return
		end
		if q.objective.kind == "bring" then
			for id, count in q.objective.materials or {} do
				d.materials[id] -= count
				if d.materials[id] <= 0 then
					d.materials[id] = nil
				end
			end
		end
		d.quests.active[q.id] = nil
		d.quests.done[q.id] = true
		giveReward(player, d, q)
		notify(player, "Quest complete: " .. q.name .. "!", "#a0ffa0")
	elseif action == "abandon" then
		if d.quests.active[q.id] then
			d.quests.active[q.id] = nil
			notify(player, "Dropped: " .. q.name, "#d8d8d8")
		end
	end
	push(player)
end

local function talk(player: Player, npcId: string)
	local d = data(player)
	if not d or not nearNpc(player, npcId) then
		return
	end
	-- deliveries finish by speaking to the right person
	for id, p in d.quests.active do
		local q = Quests.get(id)
		if q and q.objective.kind == "talk" and q.objective.npc == npcId and not p.talked then
			p.talked = true
		end
	end
	push(player)
	DialogRemote:FireClient(player, npcId)
end

local function pickUp(player: Player, nodeId: string)
	local d = data(player)
	local node = nodes[nodeId]
	local root = rootOf(player)
	if not d or not node or not root or (root.Position - node.part.Position).Magnitude > 16 then
		return
	end
	for id, p in d.quests.active do
		local q = Quests.get(id)
		if q and q.objective.kind == "collect" and q.objective.target == node.item and not p.taken[nodeId] then
			local goal = Quests.goal(q)
			if p.n < goal then
				p.taken[nodeId] = true
				p.n += 1
				notify(player, string.format("%s %d/%d", Quests.Items[node.item].name, p.n, goal), if p.n >= goal then "#a0ffa0" else "#ffe9a0")
				push(player)
				return
			end
		end
	end
	local already = false
	for _, p in d.quests.active do
		if p.taken[nodeId] then
			already = true
		end
	end
	notify(player, if already then "You've already taken this one." else "Nothing you need here right now. Someone nearby might.", "#d8d8d8")
end

local function onKill(player: Player, kindId: string)
	local d = data(player)
	if not d then
		return
	end
	local changed = false
	for id, p in d.quests.active do
		local q = Quests.get(id)
		if q and q.objective.kind == "slay" and q.objective.target == kindId then
			local goal = Quests.goal(q)
			if p.n < goal then
				p.n += 1
				changed = true
				if p.n >= goal then
					notify(player, q.name .. ": done! Return to " .. Quests.Npcs[q.turnIn or q.giver].name .. ".", "#a0ffa0")
				end
			end
		end
	end
	if changed then
		push(player)
	end
end

local function teleport(player: Player, to: Vector3)
	local character = player.Character
	local root = rootOf(player)
	if character and root then
		pcall(player.RequestStreamAroundAsync, player, to, 3)
		character:PivotTo(CFrame.new(to + Vector3.new(0, 4, 0)))
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

----------------------------------------------------------------------------------------------

function QuestService.init(map: Instance)
	local wilds = map:FindFirstChild("Wilds")
	if not wilds then
		warn("[QuestService] Map.Wilds is missing; quests are disabled")
		return
	end
	for _, d in map:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		local npcId = d:GetAttribute("QuestNpc")
		local item = d:GetAttribute("QuestItem")
		local spot = d:GetAttribute("QuestSpot")
		local camp = d:GetAttribute("CampKind")
		local shrine = d:GetAttribute("WindShrine")
		local landing = d:GetAttribute("SkyLanding")
		local stone = d:GetAttribute("WindStone")
		local cache = d:GetAttribute("SkyCache")
		if typeof(npcId) == "string" and Quests.Npcs[npcId] then
			npcRoots[npcId] = d
			local prompt = Prompts.create(d, "Talk", Quests.Npcs[npcId].name, 0)
			prompt.MaxActivationDistance = 14
			prompt.Triggered:Connect(function(player)
				talk(player, npcId)
			end)
		elseif typeof(item) == "string" then
			local nodeId = d:GetAttribute("QuestNodeId") :: string
			nodes[nodeId] = { part = d, item = item }
			local prompt = Prompts.create(d, "Pick up", Quests.Items[item] and Quests.Items[item].name or item, 0.5)
			prompt.Triggered:Connect(function(player)
				pickUp(player, nodeId)
			end)
		elseif typeof(spot) == "string" then
			spots[spot] = d.Position
		elseif typeof(camp) == "string" then
			camps[camp] = camps[camp] or {}
			table.insert(camps[camp], d.Position)
		elseif typeof(shrine) == "string" then
			shrines[shrine] = d
			local prompt = Prompts.create(d, "Ride the updraft", shrine, 0.6)
			prompt.MaxActivationDistance = 14
			prompt.Triggered:Connect(function(player)
				local pd = data(player)
				if not pd or player:GetAttribute("InDungeon") then
					return
				end
				if not (pd.unlocks and pd.unlocks.skyward) then
					notify(player, "The wind won't lift you yet. Aeronaut Pell at the mountain observatory knows how.", "#bfe3ff")
					return
				end
				local to = landings[shrine]
				if to then
					notify(player, "The updraft lifts you to " .. shrine .. "!", "#bfe3ff")
					teleport(player, to)
				end
			end)
		elseif typeof(landing) == "string" then
			landings[landing] = d.Position
		elseif typeof(stone) == "string" then
			local prompt = Prompts.create(d, "Ride the wind down", "Wind Stone", 0.6)
			prompt.Triggered:Connect(function(player)
				local base = shrines[stone]
				if base then
					teleport(player, base.Position + Vector3.new(14, 2, 0))
				end
			end)
		elseif typeof(cache) == "string" then
			local prompt = Prompts.create(d, "Open", "Sky Cache", 0.8)
			prompt.Triggered:Connect(function(player)
				local pd = data(player)
				if not pd then
					return
				end
				if pd.quests.caches[cache] then
					notify(player, "You've already emptied this cache.", "#d8d8d8")
					return
				end
				pd.quests.caches[cache] = true
				LootService.openChest(player, "sky")
			end)
		end
	end
	-- the old hill camps count as places to hunt too
	for _, c in Combat.Camps do
		camps[c.kind] = camps[c.kind] or {}
		table.insert(camps[c.kind], Vector3.new(c.x, 0, c.z))
	end

	ActionRemote.OnServerEvent:Connect(onAction)
	EnemyService.onKill(onKill)

	local function onPlayer(player: Player)
		task.spawn(function()
			for _ = 1, 30 do
				if State.get(player) then
					break
				end
				task.wait(1)
			end
			push(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end

	-- places to visit, and refreshed tracker targets
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(1)
			tick += 1
			for _, player in Players:GetPlayers() do
				local d = data(player)
				local root = rootOf(player)
				if d and root then
					local changed = false
					for id, p in d.quests.active do
						local q = Quests.get(id)
						if q and q.objective.kind == "visit" then
							for _, spotId in q.objective.spots or {} do
								local pos = spots[spotId]
								if pos and not p.visited[spotId] and (root.Position - pos).Magnitude < 30 then
									p.visited[spotId] = true
									changed = true
									notify(player, "The wind whispers at " .. Quests.Spots[spotId].name .. "...", "#bfe3ff")
								end
							end
						end
					end
					if changed or (tick % 5 == 0 and next(d.quests.active) ~= nil) then
						push(player)
					end
				end
			end
		end
	end)
end

return QuestService
