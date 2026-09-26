-- Game pass ownership and developer product receipts.
-- Fill in the real IDs in ReplicatedStorage.Shared.Products once they exist on the Creator Dashboard.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Products = require(Shared.Products)
local Config = require(Shared.Config)

local State = require(script.Parent.State)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local WeatherService = require(script.Parent.WeatherService)
local ShopService = require(script.Parent.ShopService)

local MonetizationService = {}

local MAX_RECEIPTS = 50

-- 3a step 11 "FirstPurchase": fires once, ever, for either a dev product grant or a game pass
-- purchase (whichever a player buys first).
local function markFirstPurchase(session: State.Session)
	if not session.data.onb.FirstPurchase then
		session.data.onb.FirstPurchase = true
		Analytics.onboarding(session.player, "FirstPurchase")
	end
end

local function applyPass(session: State.Session, key: string)
	if session.passes[key] then
		return
	end
	session.passes[key] = true
	session.player:SetAttribute("Pass_" .. key, true)
	if key == "BigGreenhouse" then
		PlotService.refillPads(session)
		PlotService.renderPads(session)
	elseif key == "VIP" then
		session.player:SetAttribute("VIP", true)
	end
	State.syncDew(session)
end

function MonetizationService.loadPasses(session: State.Session)
	local studioTest = RunService:IsStudio() and Config.StudioTestPasses
	for _, pass in Products.Passes do
		if studioTest then
			applyPass(session, pass.key)
		elseif pass.id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, session.player.UserId, pass.id)
			if ok and owns then
				applyPass(session, pass.key)
			end
		end
	end
end

-- Each handler returns true when the purchase was granted.
local handlers: { [string]: (State.Session) -> boolean } = {
	-- The store hides the Starter Pack once StarterBought is set, so a repeat can only come from an
	-- old/stale prompt. It then grants just the 5,000 Dew (the seeds stay one-time). Refusing repeats
	-- instead is an owner decision (QA m15).
	StarterPack = function(session)
		if not session.data.starterBought then
			session.data.starterBought = true
			session.player:SetAttribute("StarterBought", true)
			State.addSeeds(session, "mushroomph", 2)
		end
		State.addDew(session, 5_000, "IAP:StarterPack")
		return true
	end,
	DewSmall = function(session)
		State.addDew(session, math.max(500, State.income(session) * 15 * 60), "IAP:DewSmall")
		return true
	end,
	DewLarge = function(session)
		State.addDew(session, math.max(20_000, State.income(session) * 3 * 3600), "IAP:DewLarge")
		return true
	end,
	InstantGrow = function(session)
		local now = os.time()
		for _, plant in session.data.soil do
			plant.ready = math.min(plant.ready, now)
		end
		return true
	end,
	LuckBoost = function(session)
		session.luckUntil = math.max(session.luckUntil, os.time()) + 15 * 60
		session.data.luckUntil = session.luckUntil -- M5: saved, absolute Unix time, survives rejoin/hops
		session.player:SetAttribute("LuckUntil", session.luckUntil)
		return true
	end,
	RestockNow = function(session)
		ShopService.rollStock(session)
		return true
	end,
	SummonStarfall = function(session)
		WeatherService.start("starfall", session.player)
		return true
	end,
	SummonAurora = function(session)
		WeatherService.start("aurora", session.player)
		return true
	end,
}

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local session = player and State.get(player)
	local product = Products.ProductById[receipt.ProductId]
	if not session or not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receipts = session.data.receipts
	if table.find(receipts, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	-- M5: in a live server a non-saving session (DataStore load failed) would lose the purchase on
	-- leave, so don't grant it; Roblox retries the receipt on a later join where saving works.
	-- In Studio without API access nothing ever saves: we grant in memory so products can be tested,
	-- and that grant is simply gone when the test stops (expected).
	if not session.persist and not RunService:IsStudio() then
		State.notify(session, "Saving is unavailable right now, so " .. product.name .. " will be delivered next time you join.", "#ffb070")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local handler = handlers[product.key]
	if not handler or not handler(session) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	markFirstPurchase(session)
	table.insert(receipts, receipt.PurchaseId)
	while #receipts > MAX_RECEIPTS do
		table.remove(receipts, 1)
	end
	State.notify(session, "Thanks for buying " .. product.name .. "!", "#ffe070")
	if session.persist and not DataService.save(player :: Player, session.data, false) then
		-- the grant is recorded in memory, so a retry will not double-grant it
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.init()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local session = State.get(player)
		if not purchased or not session then
			return
		end
		for _, pass in Products.Passes do
			if pass.id == passId then
				applyPass(session, pass.key)
				markFirstPurchase(session)
				State.notify(session, "You unlocked " .. pass.name .. "!", "#ffe070")
			end
		end
	end)
end

return MonetizationService
