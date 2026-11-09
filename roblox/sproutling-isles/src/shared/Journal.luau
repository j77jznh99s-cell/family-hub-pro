--!strict
-- The Monster Journal: every monster in the Isles, grouped by where it lives. Defeating one for
-- the first time "discovers" its entry (a little Dew); defeating enough of them "masters" it
-- (more Dew and XP). Discovering every entry in a region pays the region's reward once.
-- JournalService keeps the counts in data.journal; the client shows them (N or the button).

local Journal = {}

export type Region = { id: string, name: string, blurb: string, kinds: { string }, reward: { dew: number, crate: string } }

Journal.Regions = {
	{
		id = "wilds", name = "The Wild Lands", blurb = "Hills, woods and sky isles",
		kinds = { "slime", "goblin", "wolf", "wisp", "treant", "stormcaller" },
		reward = { dew = 600, crate = "silver" },
	},
	{
		id = "crypt", name = "The Hollow Crypt", blurb = "Shadow: they leave you Cursed",
		kinds = { "skeleton", "bat", "warden" },
		reward = { dew = 500, crate = "silver" },
	},
	{
		id = "mines", name = "The Deepdelve Mines", blurb = "Earth: they leave you Shattered",
		kinds = { "golem", "rockmite", "shardback", "cragking" },
		reward = { dew = 900, crate = "gold" },
	},
	{
		id = "emberdeep", name = "The Emberdeep Caldera", blurb = "Fire: they set you Burning",
		kinds = { "emberimp", "magmahound", "cinderwraith", "pyrrhax" },
		reward = { dew = 1400, crate = "gold" },
	},
	{
		id = "tidewrack", name = "The Tidewrack Grotto", blurb = "Water: they leave you Soaked",
		kinds = { "reefcrab", "driftjelly", "lurker", "thalvorn" },
		reward = { dew = 1800, crate = "gold" },
	},
} :: { Region }

Journal.DiscoverDew = 25 -- first defeat of a kind
Journal.MasterDew = 150 -- mastering a kind
Journal.MasterXP = 120
Journal.MasterKills = 25 -- defeats to master a monster...
Journal.BossMasterKills = 3 -- ...or a boss

Journal.RegionOf = {} :: { [string]: Region }
for _, region in Journal.Regions do
	for _, kind in region.kinds do
		Journal.RegionOf[kind] = region
	end
end

-- Defeats needed to master `kind` (`isBoss` from Shared/Combat).
function Journal.masterAt(isBoss: boolean?): number
	return if isBoss then Journal.BossMasterKills else Journal.MasterKills
end

return Journal
