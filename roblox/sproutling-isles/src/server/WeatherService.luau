-- Natural weather cycle, Robux-summoned weather, sky tinting and mutation rolls.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Weather = require(Shared.Weather)

local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local Analytics = require(script.Parent.Analytics)

local WeatherService = {}

local current: Weather.WeatherType? = nil
local endsAt = 0
local defaultAmbient = Lighting.OutdoorAmbient
local defaultFog = Lighting.FogColor
-- 3d WeatherStart / WeatherSummonHatches
local summonedBy: Player? = nil -- set by start()'s byPlayer arg; nil for natural weather
local hatchesThisWeather = 0 -- reset every start(), read (and only reported) at stop() if summoned

-- Hollow Harvest hook: lets EventService spawn/despawn Wisp Lanterns on Spooky Fog start/stop
-- without WeatherService needing to require EventService (that would be circular, since PlotService
-- requires EventService for the hatch Moonberry grant). Called only on a *fresh* start/stop, never
-- on a stacking extension, so a Robux summon during a scheduled Fog can't spawn a second wave.
local startCallbacks: { (Weather.WeatherType, Player?) -> () } = {}
local stopCallbacks: { (Weather.WeatherType) -> () } = {}

function WeatherService.onStart(fn: (Weather.WeatherType, Player?) -> ())
	table.insert(startCallbacks, fn)
end

function WeatherService.onStop(fn: (Weather.WeatherType) -> ())
	table.insert(stopCallbacks, fn)
end

local function fireStart(w: Weather.WeatherType, byPlayer: Player?)
	for _, fn in startCallbacks do
		local ok, err = pcall(fn, w, byPlayer)
		if not ok then
			warn("[WeatherService] onStart callback failed:", err)
		end
	end
end

local function fireStop(w: Weather.WeatherType)
	for _, fn in stopCallbacks do
		local ok, err = pcall(fn, w)
		if not ok then
			warn("[WeatherService] onStop callback failed:", err)
		end
	end
end

local function tweenSky(color: Color3?)
	local goal = if color
		then { OutdoorAmbient = color, FogColor = color, FogEnd = 900 }
		else { OutdoorAmbient = defaultAmbient, FogColor = defaultFog, FogEnd = 100000 }
	TweenService:Create(Lighting, TweenInfo.new(4), goal):Play()
end

function WeatherService.current(): Weather.WeatherType?
	if current and os.clock() < endsAt then
		return current
	end
	return nil
end

function WeatherService.growthSpeed(): number
	local w = WeatherService.current()
	return if w then w.growthSpeed else 1
end

function WeatherService.start(id: string, byPlayer: Player?)
	local w = Weather.Types[id]
	if not w then
		return
	end
	-- stacking the same weather extends it; a different one replaces it
	local fresh = true
	if current == w and os.clock() < endsAt then
		endsAt += Config.WeatherDurationSeconds
		fresh = false
	else
		-- Hollow Harvest edge case: a different weather (e.g. a Robux Aurora) summoned mid-Fog
		-- replaces it outright, without going through stop()'s natural end-of-timer path. Fire the
		-- stop hooks for the outgoing weather here so EventService can despawn its lanterns, and
		-- call out the swap distinctly from the incoming weather's own announce.
		if current and current ~= w then
			local outgoing = current
			fireStop(outgoing)
			if outgoing.id == "spookyfog" then
				Net.announce("The " .. w.name .. " burned away the fog!", "#b4a0ff")
			end
		end
		current = w
		endsAt = os.clock() + Config.WeatherDurationSeconds
	end
	summonedBy = byPlayer
	hatchesThisWeather = 0
	ReplicatedStorage:SetAttribute("Weather", w.id)
	ReplicatedStorage:SetAttribute("WeatherEndsIn", endsAt - os.clock())
	tweenSky(w.sky)
	local text = w.announce
	if byPlayer then
		text = byPlayer.DisplayName .. " summoned " .. w.name .. "! " .. text
	end
	Net.announce(text, "#b4a0ff")
	-- 3d WeatherStart: LogCustomEvent needs a player. A summon attributes to the summoner; natural
	-- weather has no player to anchor it to, so it's logged against any online player as a
	-- representative sample (documented interpretation, not in the spec).
	local target = byPlayer or Players:GetPlayers()[1]
	if target then
		Analytics.custom(target, "WeatherStart", 1, { w.id, if byPlayer then "summon" else "natural" })
	end
	if fresh then
		fireStart(w, byPlayer)
	end
end

-- 3d hook: PlotService calls this whenever a Sproutling hatches, so the counter below can prove
-- summoned weather (Robux purchases) benefits everyone on the server, not just the buyer.
function WeatherService.registerHatch()
	if WeatherService.current() then
		hatchesThisWeather += 1
	end
end

local function stop()
	local weatherId = if current then current.id else "clear"
	if summonedBy then
		Analytics.custom(summonedBy, "WeatherSummonHatches", hatchesThisWeather, { weatherId })
	end
	local ending = current
	summonedBy = nil
	current = nil
	ReplicatedStorage:SetAttribute("Weather", "")
	tweenSky(nil)
	Net.announce("The weather clears.", "#dddddd")
	if ending then
		fireStop(ending)
	end
end

-- Returns a mutation id (or nil) for a Sproutling hatching right now for this player.
function WeatherService.rollMutation(session): string?
	local luck = if session.luckUntil > os.time() then 2 else 1
	local w = WeatherService.current()
	if w and w.mutation and State.rng:NextNumber() < w.mutationChance * luck then
		return w.mutation
	end
	if State.rng:NextNumber() < Config.GoldenChance * luck then
		return "golden"
	end
	return nil
end

function WeatherService.rollSize(): number
	if State.rng:NextNumber() < Config.HugeChance then
		return Config.HugeSize
	end
	-- skewed towards small: 0.8 .. 1.5
	local r = State.rng:NextNumber()
	return math.floor((0.8 + r * r * 0.7) * 100) / 100
end

-- 5. Hardened to explicitly skip naturalWeight <= 0 entries (e.g. spookyfog): in the previous
-- version this only worked because Random:NextNumber()'s half-open [0, 1) range makes roll == 0
-- astronomically unlikely, which would otherwise let a 0-weight entry win if it happened to be the
-- first one Lua's unordered table iteration visited. Skipping them outright removes that edge case
-- instead of relying on floating-point luck.
local function pickNatural(): string
	local total = 0
	for _, w in Weather.Types do
		if w.naturalWeight > 0 then
			total += w.naturalWeight
		end
	end
	local roll = State.rng:NextNumber() * total
	for id, w in Weather.Types do
		if w.naturalWeight > 0 then
			roll -= w.naturalWeight
			if roll <= 0 then
				return id
			end
		end
	end
	return "drizzle"
end

function WeatherService.init()
	ReplicatedStorage:SetAttribute("Weather", "")
	task.spawn(function()
		local nextNatural = os.clock() + State.rng:NextInteger(Config.WeatherEverySeconds[1], Config.WeatherEverySeconds[2]) * 0.5
		while true do
			task.wait(1)
			if current and os.clock() >= endsAt then
				stop()
				nextNatural = os.clock() + State.rng:NextInteger(Config.WeatherEverySeconds[1], Config.WeatherEverySeconds[2])
			elseif current then
				ReplicatedStorage:SetAttribute("WeatherEndsIn", endsAt - os.clock())
			elseif os.clock() >= nextNatural then
				WeatherService.start(pickNatural())
			end
		end
	end)
end

return WeatherService
