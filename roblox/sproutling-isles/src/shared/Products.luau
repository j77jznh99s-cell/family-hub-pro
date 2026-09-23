--!strict
-- Robux catalogue. IDs are 0 until you create the passes/products on the Creator Dashboard
-- and paste the real IDs here. Items with id 0 still show in the in-game store, with a "Set ID"
-- button instead of a price, and can't be bought.

export type Pass = { key: string, id: number, name: string, price: number, description: string }
export type Product = { key: string, id: number, name: string, price: number, description: string }

local Products = {}

Products.Passes = {
	{ key = "DoubleDew", id = 0, name = "2x Dew", price = 249, description = "Double all Dew income, forever." },
	{ key = "BigGreenhouse", id = 0, name = "Big Greenhouse", price = 199, description = "+4 display pads for more Sproutlings." },
	{ key = "SturdyGate", id = 0, name = "Sturdy Gate", price = 99, description = "Gate lock lasts 90s instead of 60s." },
	{ key = "LuckyRod", id = 0, name = "Lucky Rod", price = 149, description = "Double rare catches at the Wishing Pond." },
	{ key = "VIP", id = 0, name = "VIP", price = 149, description = "Golden VIP name tag and +10% Dew." },
} :: { Pass }

Products.DevProducts = {
	{ key = "StarterPack", id = 0, name = "Starter Pack", price = 49, description = "One-time: 2 Mushroomph seeds + 5,000 Dew." },
	{ key = "DewSmall", id = 0, name = "Dew Pouch", price = 29, description = "15 minutes of your current income (min 500 Dew)." },
	{ key = "DewLarge", id = 0, name = "Dew Barrel", price = 249, description = "3 hours of your current income (min 20,000 Dew)." },
	{ key = "InstantGrow", id = 0, name = "Instant Grow", price = 39, description = "Every seed in your soil finishes growing now." },
	{ key = "LuckBoost", id = 0, name = "Luck Boost (15 min)", price = 49, description = "Double mutation chances on your hatches." },
	{ key = "RestockNow", id = 0, name = "Restock Shop", price = 25, description = "Instantly re-roll your seed shop stock." },
	{ key = "SummonStarfall", id = 0, name = "Summon Starfall", price = 199, description = "Starts a server-wide Starfall. Everyone cheers your name." },
	{ key = "SummonAurora", id = 0, name = "Summon Aurora", price = 399, description = "Starts a server-wide Aurora (Prismatic x6 hatches)." },
} :: { Product }

Products.PassByKey = {} :: { [string]: Pass }
for _, pass in Products.Passes do
	Products.PassByKey[pass.key] = pass
end

Products.ProductById = {} :: { [number]: Product }
for _, product in Products.DevProducts do
	if product.id ~= 0 then
		Products.ProductById[product.id] = product
	end
end

return Products
