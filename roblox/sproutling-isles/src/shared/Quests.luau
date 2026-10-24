--!strict
-- Quests, the people who give them, and the things they send you to find. All original.
--
-- WildsBuilder builds each person's camp out in the open land (or on a sky isle) near `near`,
-- scatters their quest items around it and marks enemy camps and places to visit; the server
-- (QuestService) finds all of those by attribute in the map. Objectives:
--   slay    kill `count` enemies of kind `target`
--   collect pick up `count` quest items of kind `target` (each spot once per player)
--   visit   stand at each of the `spots` (QuestSpot markers)
--   bring   hand over materials from your bag
--   talk    speak to the person `npc` (deliveries)
-- Quests unlock in order through `requires`. Rewards: Dew, materials, a weapon of at least
-- `weapon` rarity, potions, or an unlock ("skyward" lets the wind shrines carry you to the sky isles).

local Quests = {}

-- Colours are { r, g, b } (0-255) so this module loads anywhere, including offline under Lune.
export type RGB = { number }
export type Look = { skin: RGB, shirt: RGB, pants: RGB, hair: RGB, hat: string?, hatColor: RGB?, prop: string? }
export type Npc = {
	id: string,
	name: string,
	title: string,
	greeting: string,
	look: Look,
	near: { number }, -- desired x, z (or a sky isle by name in `isle`)
	isle: string?,
	site: string?, -- a levelled Landscape site to camp on (the mountain camps)
	offset: { number }?, -- with site: stand this x, z from its centre (villagers round a square)
	fixed: { number }?, -- exact x, y, z (the guide on the garden island)
	facing: { number }?, -- with fixed: x, z direction to face
	camp: string, -- what WildsBuilder builds round them
}

export type Objective = {
	kind: string,
	target: string?,
	count: number?,
	spots: { string }?,
	materials: { [string]: number }?,
	npc: string?,
	text: string,
}

export type Reward = { dew: number?, materials: { [string]: number }?, weapon: number?, potions: number?, unlock: string?, crate: string? }

export type Quest = {
	id: string,
	name: string,
	giver: string,
	turnIn: string?, -- defaults to the giver
	requires: { string }?,
	auto: boolean?, -- completes itself the moment it's done (and starts `nextQuest`)
	nextQuest: string?,
	intro: string,
	finish: string,
	objective: Objective,
	reward: Reward,
}

local function rgb(r: number, g: number, b: number): RGB
	return { r, g, b }
end

----------------------------------------------------------------------------------------------
-- quest items (they live in the quest log, not the bag)

Quests.Items = {
	satchel = { name = "Lost Satchel", color = rgb(150, 100, 60) },
	amber = { name = "Amberwood Knot", color = rgb(255, 170, 60) },
	ghostcap = { name = "Ghostcap Mushroom", color = rgb(200, 230, 255) },
	lamb = { name = "Stray Lamb", color = rgb(245, 245, 240) },
	glowstone = { name = "Glowstone", color = rgb(120, 235, 255) },
	relic = { name = "Old Fort Relic", color = rgb(205, 160, 90) },
	shard = { name = "Starfall Shard", color = rgb(255, 235, 150) },
	snowbloom = { name = "Snowbloom", color = rgb(235, 245, 255) },
	goat = { name = "Runaway Goat", color = rgb(225, 215, 200) },
	pearlshell = { name = "Pearl Oyster", color = rgb(230, 220, 240) },
	driftwood = { name = "Wreck Timber", color = rgb(160, 120, 80) },
} :: { [string]: { name: string, color: RGB } }

-- Where the items lie: around a person's camp (`npc`, `count`, `spread` studs), on the sky isles
-- (`isles`, `perIsle`), or across open Landscape sites (`sites`, `count`: Saltmere's beaches).
Quests.ItemSpots = {
	{ item = "satchel", npc = "bryn", count = 7, spread = 220 },
	{ item = "amber", npc = "maple", count = 7, spread = 180 },
	{ item = "ghostcap", npc = "ilsa", count = 8, spread = 200 },
	{ item = "lamb", npc = "tamsin", count = 7, spread = 200 },
	{ item = "glowstone", npc = "gorrim", count = 8, spread = 190 },
	{ item = "relic", npc = "dorran", count = 6, spread = 110 },
	{ item = "shard", isles = true, perIsle = 2 },
	{ item = "snowbloom", npc = "hesk", count = 8, spread = 170 },
	{ item = "goat", npc = "tobbin", count = 7, spread = 160 },
	{ item = "pearlshell", sites = { "cove", "strand" }, count = 8 },
	{ item = "driftwood", sites = { "strand", "cove" }, count = 7 },
} :: { any }

----------------------------------------------------------------------------------------------
-- people

Quests.Npcs = {
	mara = {
		id = "mara", name = "Mara Brightfoot", title = "Guide to the Isles", camp = "guide", near = { 0, 0 }, fixed = { -156, 20, 1266 }, facing = { 0, 1 },
		greeting = "Welcome to Greenhollow Gardens! Your garden house is down the lane, and the city's just up the road. Let me show you around.",
		look = { skin = rgb(235, 195, 160), shirt = rgb(240, 170, 60), pants = rgb(90, 110, 70), hair = rgb(160, 80, 50), hat = "straw", hatColor = rgb(240, 215, 140), prop = "letter" },
	},
	bryn = {
		id = "bryn", name = "Bryn Ashgrove", title = "Forest Warden", camp = "ranger", near = { -800, 60 },
		greeting = "Keep your eyes on the treeline, traveller. The woods are hungrier this season.",
		look = { skin = rgb(225, 180, 140), shirt = rgb(60, 110, 60), pants = rgb(90, 70, 50), hair = rgb(120, 70, 40), hat = "hood", hatColor = rgb(50, 95, 55), prop = "bow" },
	},
	maple = {
		id = "maple", name = "Old Maple", title = "Woodcutter", camp = "woodcutter", near = { -900, 520 },
		greeting = "Mind the stumps. Some of these trees are older than the city walls.",
		look = { skin = rgb(205, 160, 120), shirt = rgb(170, 60, 50), pants = rgb(70, 60, 50), hair = rgb(200, 200, 195), hat = "cap", hatColor = rgb(120, 90, 60), prop = "axe" },
	},
	ilsa = {
		id = "ilsa", name = "Sister Ilsa", title = "Herbalist", camp = "herbalist", near = { 640, 700 },
		greeting = "Every root and cap in these woods can heal something, if you know how to ask.",
		look = { skin = rgb(240, 205, 175), shirt = rgb(120, 90, 160), pants = rgb(90, 70, 120), hair = rgb(60, 45, 40), hat = "hood", hatColor = rgb(100, 75, 140), prop = "staff" },
	},
	tamsin = {
		id = "tamsin", name = "Tamsin Burr", title = "Shepherd", camp = "shepherd", near = { -470, 1560 },
		greeting = "Have you seen any little woolly wanderers? Mine never stay where I put them.",
		look = { skin = rgb(230, 190, 150), shirt = rgb(230, 200, 120), pants = rgb(100, 80, 60), hair = rgb(220, 150, 70), hat = "straw", hatColor = rgb(235, 210, 130), prop = "crook" },
	},
	gorrim = {
		id = "gorrim", site = "minecamp", name = "Gorrim Deepdelve", title = "Mountain Miner", camp = "mine", near = { -260, -960 },
		greeting = "The mountain sings if you dig deep enough. Lately it's been growling.",
		look = { skin = rgb(200, 150, 110), shirt = rgb(110, 85, 60), pants = rgb(60, 55, 55), hair = rgb(150, 70, 40), hat = "helmet", hatColor = rgb(230, 190, 60), prop = "pick" },
	},
	oswin = {
		id = "oswin", site = "hermitage", name = "Oswin the Hermit", title = "Keeper of Cairns", camp = "hermit", near = { 720, -420 },
		greeting = "Few climb this high. Fewer climb back down wiser. Which will you be?",
		look = { skin = rgb(215, 175, 140), shirt = rgb(140, 130, 110), pants = rgb(110, 100, 85), hair = rgb(235, 235, 230), hat = "hood", hatColor = rgb(125, 115, 100), prop = "staff" },
	},
	pell = {
		id = "pell", site = "observatory", name = "Aeronaut Pell", title = "Sky Scholar", camp = "observatory", near = { 280, -860 },
		greeting = "Those islands up there aren't clouds, friend. And I mean to stand on one.",
		look = { skin = rgb(235, 195, 160), shirt = rgb(60, 90, 160), pants = rgb(70, 60, 55), hair = rgb(90, 60, 40), hat = "goggles", hatColor = rgb(120, 80, 50), prop = "spyglass" },
	},
	dorran = {
		id = "dorran", name = "Captain Dorran", title = "Old Fort Watch", camp = "fortcamp", near = { 640, 1400 },
		greeting = "The old fort's dead don't stay dead. Someone has to keep the count.",
		look = { skin = rgb(190, 140, 105), shirt = rgb(150, 40, 45), pants = rgb(60, 60, 70), hair = rgb(40, 35, 30), hat = "helmet", hatColor = rgb(160, 160, 170), prop = "sword" },
	},
	pip = {
		id = "pip", name = "Pip Quickstep", title = "Lost Courier", camp = "courier", near = { 150, 1470 },
		greeting = "I'm not lost! I'm... taking the scenic route. For the third day.",
		look = { skin = rgb(245, 210, 180), shirt = rgb(70, 140, 200), pants = rgb(200, 180, 140), hair = rgb(240, 200, 90), hat = "cap", hatColor = rgb(200, 60, 60), prop = "letter" },
	},
	brannoc = {
		id = "brannoc", site = "emberpeak", name = "Brannoc Ashbeard", title = "Firesmith", camp = "forge", near = { -850, 1520 },
		greeting = "Hot enough for you? This peak's my forge. And under it sleeps the hottest thing in the Isles.",
		look = { skin = rgb(190, 130, 95), shirt = rgb(70, 50, 40), pants = rgb(50, 45, 42), hair = rgb(200, 80, 30), hat = "cap", hatColor = rgb(60, 55, 50), prop = "pick" },
	},
	-- Highcrag, the mountain village below Ember Peak
	hesk = {
		id = "hesk", site = "highcrag", offset = { 16, 0 }, name = "Elder Hesk", title = "Highcrag Elder", camp = "villager", near = { -770, 1615 },
		greeting = "Welcome to Highcrag, the last hearth before the peak. Sit, warm yourself. Then, if you would, help us.",
		look = { skin = rgb(210, 165, 125), shirt = rgb(120, 60, 50), pants = rgb(80, 70, 60), hair = rgb(230, 230, 225), hat = "hood", hatColor = rgb(140, 70, 55), prop = "staff" },
	},
	yara = {
		id = "yara", site = "highcrag", offset = { 5.5, 15 }, name = "Yara Swiftwind", title = "Mountain Guide", camp = "villager", near = { -770, 1615 },
		greeting = "Every path on this mountain, I've walked twice. The best one goes over Saltwind Pass to the sea.",
		look = { skin = rgb(190, 140, 105), shirt = rgb(70, 120, 160), pants = rgb(90, 80, 70), hair = rgb(40, 30, 25), hat = "goggles", hatColor = rgb(110, 80, 50), prop = "spyglass" },
	},
	tobbin = {
		id = "tobbin", site = "highcrag", offset = { 10.3, -12.3 }, name = "Old Tobbin", title = "Goatherd", camp = "villager", near = { -770, 1615 },
		greeting = "Goats! Up the cliffs, down the cliffs. Never where I left them.",
		look = { skin = rgb(220, 180, 140), shirt = rgb(150, 120, 70), pants = rgb(90, 75, 55), hair = rgb(190, 190, 185), hat = "cap", hatColor = rgb(110, 90, 60), prop = "crook" },
	},
	-- Saltmere, the beach village over Saltwind Pass
	quill = {
		id = "quill", site = "saltmere", offset = { 0, 16 }, name = "Harbourmaster Quill", title = "Keeper of Saltmere Pier", camp = "villager", near = { -905, 1792 },
		greeting = "Ahoy! Mind the tide. Lately it's been coming in when it shouldn't, and bringing things with it.",
		look = { skin = rgb(200, 150, 110), shirt = rgb(40, 60, 110), pants = rgb(220, 215, 200), hair = rgb(120, 70, 40), hat = "cap", hatColor = rgb(30, 40, 80), prop = "spyglass" },
	},
	finn = {
		id = "finn", site = "saltmere", offset = { 15, 5.5 }, name = "Finnick Deepbreath", title = "Pearl Diver", camp = "villager", near = { -905, 1792 },
		greeting = "Hold your breath long enough and the sea tells you its secrets. Mostly where the pearls are.",
		look = { skin = rgb(170, 120, 85), shirt = rgb(60, 170, 170), pants = rgb(230, 200, 140), hair = rgb(250, 230, 160), hat = "goggles", hatColor = rgb(60, 120, 140), prop = "letter" },
	},
	coralie = {
		id = "coralie", site = "saltmere", offset = { -15, 5.5 }, name = "Coralie", title = "Tidesinger", camp = "villager", near = { -905, 1792 },
		greeting = "Listen. Under the waves, something vast is singing back to me. It is not a friendly song.",
		look = { skin = rgb(235, 200, 175), shirt = rgb(80, 190, 200), pants = rgb(50, 110, 150), hair = rgb(60, 160, 170), hat = "circlet", hatColor = rgb(255, 210, 230), prop = "staff" },
	},
	lyra = {
		id = "lyra", name = "Lyra", title = "Cloudkeeper", camp = "skycamp", near = { 0, 0 }, isle = "Cloudkeeper's Rest",
		greeting = "Welcome to the high air. Breathe slowly; the wind here has opinions.",
		look = { skin = rgb(240, 225, 215), shirt = rgb(200, 230, 255), pants = rgb(170, 200, 240), hair = rgb(250, 250, 255), hat = "circlet", hatColor = rgb(255, 220, 120), prop = "staff" },
	},
	vael = {
		id = "vael", name = "Sage Vael", title = "Watcher of the Storm", camp = "skyshrine", near = { 0, 0 }, isle = "Stormcrown",
		greeting = "The storm has a heart, and it is beating faster. Can you hear it?",
		look = { skin = rgb(210, 190, 230), shirt = rgb(60, 50, 110), pants = rgb(40, 35, 80), hair = rgb(180, 200, 255), hat = "hood", hatColor = rgb(70, 60, 130), prop = "staff" },
	},
} :: { [string]: Npc }

-- Places to visit (Oswin's cairns on three peaks): desired x, z; WildsBuilder picks the highest
-- open ground nearby.
Quests.Spots = {
	-- places in the city for Mara's tour (marked on things CityBuilder made)
	spotMarket = { name = "the Market Square", find = { "TravelPoint", "market" } },
	spotYard = { name = "the Barracks training yard", find = { "DummySpot", true } },
	spotArena = { name = "the Arena gate", find = { "ArenaGate", true } },
	spotPort = { name = "the Airship Port", find = { "TravelPoint", "port" } },
	cairnWest = { name = "West Peak Cairn", near = { -1060, -260 } },
	cairnNorth = { name = "North Peak Cairn", near = { 620, -1000 } },
	cairnSouth = { name = "South Peak Cairn", near = { 820, 1700 } },
	-- Yara's lookouts round Highcrag
	lookEmber = { name = "Westcrag Lookout", near = { -1060, 1330 } },
	lookPass = { name = "Saltwind Pass Summit", find = { "Lookout", "pass" } },
	lookEast = { name = "Eastcrag Lookout", near = { -700, 1790 } },
} :: { [string]: any }

-- Enemy camps the quests need, beside a person's camp (offset x, z from it), on a levelled
-- Landscape site (`site`, offset from its centre) or on a named isle.
Quests.Camps = {
	{ npc = "bryn", offset = { -90, 70 }, kind = "wolf", count = 4 },
	{ npc = "maple", offset = { 100, -80 }, kind = "goblin", count = 4 },
	{ npc = "tamsin", offset = { 90, 90 }, kind = "slime", count = 5 },
	{ npc = "gorrim", offset = { 110, 60 }, kind = "golem", count = 3 },
	{ npc = "gorrim", offset = { -120, 40 }, kind = "golem", count = 2 },
	{ npc = "pell", offset = { 80, 70 }, kind = "bat", count = 5 },
	{ npc = "dorran", offset = { -80, 40 }, kind = "skeleton", count = 5 },
	{ npc = "brannoc", offset = { 90, 60 }, kind = "emberimp", count = 5 },
	{ npc = "hesk", offset = { 110, 40 }, kind = "rockmite", count = 5 },
	{ npc = "hesk", offset = { -60, -110 }, kind = "rockmite", count = 4 },
	{ npc = "tobbin", offset = { 140, 90 }, kind = "wolf", count = 4 },
	{ site = "strand", offset = { -10, -4 }, kind = "reefcrab", count = 4 },
	{ site = "cove", offset = { 0, 0 }, kind = "reefcrab", count = 3 },
	{ site = "strand", offset = { 22, 14 }, kind = "driftjelly", count = 4 },
	{ isle = "Windward Isle", kind = "wisp", count = 3 },
	{ isle = "Starfall Isle", kind = "wisp", count = 3 },
	{ isle = "Gale Rock", kind = "wisp", count = 3 },
	{ isle = "Stormcrown", kind = "wisp", count = 3 },
	{ isle = "Stormcrown", kind = "stormcaller", count = 1, boss = true },
} :: { any }

----------------------------------------------------------------------------------------------
-- quests

Quests.List = {
	-- Mara's tour of the Isles: each step finishes itself and starts the next
	{
		id = "guide_city", name = "Into the City", giver = "mara", auto = true, nextQuest = "guide_yard",
		intro = "Walk up Greenhollow Lane to the Grand Way and into Sproutling City. Find the Market Square. Follow the beam of light!",
		finish = "The market! Shops, stalls and a fountain. Now, let's get you ready for trouble.",
		objective = { kind = "visit", spots = { "spotMarket" }, text = "Reach the Market Square" },
		reward = { dew = 100, crate = "wood" },
	},
	{
		id = "guide_yard", name = "The Training Yard", giver = "mara", requires = { "guide_city" }, auto = true, nextQuest = "guide_hunt",
		intro = "Find the Barracks training yard. Hit the dummies there: click to swing, 1/2/3 to swap weapons, Shift to roll.",
		finish = "Good form! Time to try it on something that hits back.",
		objective = { kind = "visit", spots = { "spotYard" }, text = "Visit the training yard" },
		reward = { dew = 80, potions = 2 },
	},
	{
		id = "guide_hunt", name = "First Hunt", giver = "mara", requires = { "guide_yard" }, auto = true, nextQuest = "guide_arena",
		intro = "Bog Slimes gather in the hills around the island. Defeat three of them. H drinks a healing draught if you need one.",
		finish = "Your first hunt! Every monster gives XP; watch your level badge climb.",
		objective = { kind = "slay", target = "slime", count = 3, text = "Defeat Bog Slimes" },
		reward = { dew = 120, crate = "wood" },
	},
	{
		id = "guide_arena", name = "Sand and Glory", giver = "mara", requires = { "guide_hunt" }, auto = true, nextQuest = "guide_port",
		intro = "The Arena is where heroes test themselves in waves of monsters. Go and see its gate.",
		finish = "Start a trial there whenever you feel brave. Crates for every fifth wave!",
		objective = { kind = "visit", spots = { "spotArena" }, text = "Find the Arena gate" },
		reward = { dew = 120 },
	},
	{
		id = "guide_port", name = "Wheels and Wings", giver = "mara", requires = { "guide_arena" }, auto = true, nextQuest = "guide_help",
		intro = "West of the city is the Airship Port. Airships fly you anywhere, and the Aerie Workshop builds flying machines for heroes of high level.",
		finish = "Carriages, boats, flying machines... level up and they're yours. Press G for your garage and M for the map.",
		objective = { kind = "visit", spots = { "spotPort" }, text = "Visit the Airship Port" },
		reward = { dew = 150, crate = "silver" },
	},
	{
		id = "guide_help", name = "Folk in Need", giver = "mara", requires = { "guide_port" }, turnIn = "bryn",
		intro = "People all over the Isles need a hand. Start with Bryn, the Forest Warden west of the city. Look for the gold ! over their heads.",
		finish = "Mara sent you? Good. I could use someone like you.",
		objective = { kind = "talk", npc = "bryn", text = "Find Bryn the Forest Warden" },
		reward = { dew = 100, crate = "wood" },
	},
	{
		id = "bryn_wolves", name = "Wolves at the Treeline", giver = "bryn",
		intro = "A pack of ashen wolves has been circling my outpost. Thin them out before they get bold.",
		finish = "That'll quiet the nights. Here, for your trouble.",
		objective = { kind = "slay", target = "wolf", count = 6, text = "Defeat Ashen Wolves" },
		reward = { dew = 120, materials = { pelt = 2 } },
	},
	{
		id = "bryn_satchels", name = "Lost Satchels", giver = "bryn",
		intro = "Travellers fled the wolves and dropped their packs all through the western woods. Bring them back.",
		finish = "Their owners will be glad. Take this blade; it served me well.",
		objective = { kind = "collect", target = "satchel", count = 5, text = "Find Lost Satchels in the woods" },
		reward = { dew = 160, weapon = 2 },
	},
	{
		id = "maple_amber", name = "Amberwood Knots", giver = "maple",
		intro = "Old trees weep amber when they fall. Gather the knots before the goblins burn them for warmth.",
		finish = "Lovely and sticky. These will make fine lamp oil.",
		objective = { kind = "collect", target = "amber", count = 5, text = "Gather Amberwood Knots" },
		reward = { dew = 140, potions = 2 },
	},
	{
		id = "maple_goblins", name = "Thornbacks in the Pines", giver = "maple", requires = { "maple_amber" },
		intro = "Those thornback goblins chopped my best tree. Chop them back, would you?",
		finish = "Ha! That'll teach them to swing an axe they can't lift.",
		objective = { kind = "slay", target = "goblin", count = 6, text = "Defeat Thornback Goblins" },
		reward = { dew = 180, weapon = 2 },
	},
	{
		id = "pip_letter", name = "A Letter for Ilsa", giver = "pip", turnIn = "ilsa",
		intro = "This letter is for Sister Ilsa in the eastern woods. I'd go myself, but... which way is east?",
		finish = "A letter from my sister in the city! Thank you, dear. Pip sends you this.",
		objective = { kind = "talk", npc = "ilsa", text = "Deliver the letter to Sister Ilsa" },
		reward = { dew = 90, potions = 1 },
	},
	{
		id = "ilsa_ghostcaps", name = "Ghostcap Gathering", giver = "ilsa",
		intro = "Ghostcaps glow pale in the shade of the eastern forest. I need a basketful.",
		finish = "Perfect caps. Not a nibble on them. You have a gentle hand.",
		objective = { kind = "collect", target = "ghostcap", count = 6, text = "Pick Ghostcap Mushrooms" },
		reward = { dew = 130, materials = { dewcap = 2 } },
	},
	{
		id = "ilsa_remedy", name = "Moonmint Remedy", giver = "ilsa", requires = { "ilsa_ghostcaps" },
		intro = "For the remedy I also need moonmint and sunleaf. Wild herb patches grow them, and so does your garden.",
		finish = "Now we brew. Take some for the road; you'll need them where you're going.",
		objective = { kind = "bring", materials = { moonmint = 3, sunleaf = 3 }, text = "Bring 3 Moonmint and 3 Sunleaf" },
		reward = { dew = 160, potions = 4 },
	},
	{
		id = "tamsin_lambs", name = "Strays on the Ridge", giver = "tamsin",
		intro = "My lambs have wandered off across the hills again. Find them and send them home?",
		finish = "There they are, the little rascals! Bless you.",
		objective = { kind = "collect", target = "lamb", count = 5, text = "Find Stray Lambs" },
		reward = { dew = 140, materials = { sunleaf = 3 } },
	},
	{
		id = "tamsin_slimes", name = "Bog Trouble", giver = "tamsin", requires = { "tamsin_lambs" },
		intro = "Bog slimes keep oozing into the meadow and the flock won't graze. Clear them out.",
		finish = "The grass can breathe again. Here, you've earned this.",
		objective = { kind = "slay", target = "slime", count = 8, text = "Defeat Bog Slimes" },
		reward = { dew = 150, weapon = 2 },
	},
	{
		id = "gorrim_golems", name = "Crag Golems", giver = "gorrim",
		intro = "Rocks that walk and punch. They came out of the deep seam and won't let me near it.",
		finish = "Rubble at last. Good, honest rubble.",
		objective = { kind = "slay", target = "golem", count = 5, text = "Defeat Crag Golems" },
		reward = { dew = 220, weapon = 3 },
	},
	{
		id = "gorrim_glow", name = "Glowstone Seams", giver = "gorrim", requires = { "gorrim_golems" },
		intro = "With the golems gone, the glowstone's free for the taking. It lights up when the wind blows. Odd stuff.",
		finish = "Look how it hums. Pell up at the observatory will want to hear about this.",
		objective = { kind = "collect", target = "glowstone", count = 6, text = "Mine Glowstone" },
		reward = { dew = 200, materials = { ore = 3 } },
	},
	{
		id = "gorrim_deep", name = "Into the Deep", giver = "gorrim", requires = { "gorrim_glow" },
		intro = "The deep seam is open, and something big woke up down there. The Crag King. Go through the mine mouth by my camp (level 12 or more) and put him back to sleep. Permanently.",
		finish = "The mountain's quiet. Too quiet. Ha! Take this, you've earned it.",
		objective = { kind = "slay", target = "cragking", count = 1, text = "Defeat the Crag King in the Deepdelve Mines" },
		reward = { dew = 500, weapon = 4, crate = "gold" },
	},
	{
		id = "brannoc_imps", name = "Sparks on the Slopes", giver = "brannoc",
		intro = "Ember imps keep crawling out of the vents and stealing my coal. Stamp them out. Mind your boots: their touch sets you alight. The Alchemist sells Fireward Tonic.",
		finish = "Ha! Nothing like a quiet forge. Take this, and take it seriously: what's below is worse.",
		objective = { kind = "slay", target = "emberimp", count = 8, text = "Defeat Ember Imps" },
		reward = { dew = 400, potions = 3, crate = "silver" },
	},
	{
		id = "brannoc_heart", name = "Heart of the Caldera", giver = "brannoc", requires = { "brannoc_imps" },
		intro = "Pyrrhax, the Molten Wyrm, stirs in the caldera under this peak (level 20 or more). Burning hounds, ash wraiths, rivers of lava. Bring back one of its scales and I'll forge you something legendary.",
		finish = "A real wyrm scale, still warm! You're a legend now, friend. Here's your reward, fresh from the anvil.",
		objective = { kind = "slay", target = "pyrrhax", count = 1, text = "Defeat Pyrrhax in the Emberdeep Caldera" },
		reward = { dew = 1200, weapon = 5, crate = "gold" },
	},
	-- Highcrag
	{
		id = "hesk_mites", name = "Mites in the Terraces", giver = "hesk",
		intro = "Rockmites have burrowed up from the deep mines and are chewing through our terrace walls. Crush them before the houses slide down the mountain. Careful: their bite cracks your guard (Shattered) and the next blow lands harder.",
		finish = "The walls are holding. Highcrag thanks you. Take this; our smiths made it for days like this.",
		objective = { kind = "slay", target = "rockmite", count = 8, text = "Crush Rockmites round Highcrag" },
		reward = { dew = 450, weapon = 4 },
	},
	{
		id = "hesk_snowbloom", name = "Snowbloom for the Beacon", giver = "hesk", requires = { "hesk_mites" },
		intro = "The beacon in our square burns on snowbloom oil. The flowers grow in the cold cracks round the village. Gather them before the frost bites them black.",
		finish = "Smell that? The beacon will burn bright all winter. Brannoc up the peak could use a hand too, if you're brave.",
		objective = { kind = "collect", target = "snowbloom", count = 6, text = "Gather Snowbloom round Highcrag" },
		reward = { dew = 380, potions = 3, crate = "silver" },
	},
	{
		id = "tobbin_goats", name = "Goats on the Cliffs", giver = "tobbin",
		intro = "My goats have scattered up every ledge again. Bring them home and I'll have cheese for you by supper.",
		finish = "All home and bleating. Here, mountain cheese and coin. Don't tell the goats.",
		objective = { kind = "collect", target = "goat", count = 5, text = "Find Runaway Goats" },
		reward = { dew = 340, materials = { pelt = 3 } },
	},
	{
		id = "tobbin_wolves", name = "The Grey Pack", giver = "tobbin", requires = { "tobbin_goats" },
		intro = "Wolves have followed the goats up from the valley. Chase them off for good.",
		finish = "Not a howl tonight. You've a herder's heart and a hunter's arm.",
		objective = { kind = "slay", target = "wolf", count = 6, text = "Defeat Ashen Wolves above Highcrag" },
		reward = { dew = 360, weapon = 4 },
	},
	{
		id = "yara_lookouts", name = "The Three Lookouts", giver = "yara",
		intro = "A guide has to know the land. Climb to the three lookouts round Highcrag: Westcrag beyond Ember Peak, the Saltwind Pass summit and Eastcrag. From the pass you'll see the sea.",
		finish = "Now you know the mountain. And you've seen Saltmere down on the beach. They've been asking for help.",
		objective = { kind = "visit", spots = { "lookEmber", "lookPass", "lookEast" }, text = "Visit the three lookouts" },
		reward = { dew = 420, potions = 2 },
	},
	{
		id = "yara_pass", name = "Over Saltwind Pass", giver = "yara", requires = { "yara_lookouts" }, turnIn = "quill",
		intro = "Take this letter over Saltwind Pass to Harbourmaster Quill in Saltmere. Follow the trail west out of the square, over the summit and down to the beach.",
		finish = "A letter from Yara! She says you're the one to help us. Welcome to Saltmere, friend.",
		objective = { kind = "talk", npc = "quill", text = "Deliver Yara's letter to Harbourmaster Quill in Saltmere" },
		reward = { dew = 300, crate = "silver" },
	},
	-- Saltmere
	{
		id = "quill_crabs", name = "Claws on the Sand", giver = "quill",
		intro = "Reefclaw crabs have marched out of the sea cave and taken the beach. Their pinch soaks you to the bone and slows you right down. Drive them back. The Tide Market sells Tidebalm if you need it.",
		finish = "The fishers can mend their nets again. Here's your share of the catch money.",
		objective = { kind = "slay", target = "reefcrab", count = 8, text = "Defeat Reefclaw Crabs on Saltmere beach" },
		reward = { dew = 500, potions = 3 },
	},
	{
		id = "quill_timber", name = "Wreck Timber", giver = "quill", requires = { "quill_crabs" },
		intro = "The storm tide broke three boats. Wreck timber's washed up all along the shore; bring me enough to patch them.",
		finish = "Good seasoned planks, salt and all. The boats will float by morning.",
		objective = { kind = "collect", target = "driftwood", count = 6, text = "Gather Wreck Timber along the shore" },
		reward = { dew = 420, weapon = 4 },
	},
	{
		id = "finn_pearls", name = "Pearls of the Shallows", giver = "finn",
		intro = "The tide has thrown oysters fat with pearls up along the shore and the dunes. Bring me some, and mind the jellies.",
		finish = "Look at the shine on these! You've a diver's eye.",
		objective = { kind = "collect", target = "pearlshell", count = 6, text = "Gather Pearl Oysters along the shore" },
		reward = { dew = 400, materials = { pearl = 3 } },
	},
	{
		id = "finn_jellies", name = "Sting of the Tide", giver = "finn", requires = { "finn_pearls" },
		intro = "Drift jellies are crowding the shallows. One brush and you're soaked and stung. Clear a few so we can dive again.",
		finish = "The water's clear. Fancy a swim? No? Fair. Take this instead.",
		objective = { kind = "slay", target = "driftjelly", count = 6, text = "Defeat Drift Jellies in the shallows" },
		reward = { dew = 450, weapon = 4, crate = "silver" },
	},
	{
		id = "coralie_abyss", name = "Song of the Abyss", giver = "coralie", requires = { "quill_crabs", "finn_pearls" },
		intro = "The singer under the waves is Thalvorn, the Tide Kraken. It wakes in the Tidewrack Grotto, the sea cave by our beach (level 25 or more). Crabs, jellies, the deepscale lurkers... all of them are its children. Silence it, and the tide will turn back.",
		finish = "The sea is singing a gentler song. Saltmere will never forget you. Take Thalvorn's ink; it holds the tide's own colour.",
		objective = { kind = "slay", target = "thalvorn", count = 1, text = "Defeat Thalvorn in the Tidewrack Grotto" },
		reward = { dew = 1500, weapon = 5, crate = "gold" },
	},
	{
		id = "oswin_cairns", name = "The Hermit's Cairns", giver = "oswin",
		intro = "Three cairns stand on three peaks. Visit each and listen to the wind. Then come back and tell me what it said.",
		finish = "It spoke of islands, didn't it? It always does. Go and find Pell.",
		objective = { kind = "visit", spots = { "cairnWest", "cairnNorth", "cairnSouth" }, text = "Visit the three peak cairns" },
		reward = { dew = 240, potions = 2 },
	},
	{
		id = "pell_skyward", name = "Ride the Wind", giver = "pell", requires = { "gorrim_glow", "oswin_cairns" },
		intro = "The wind shrines can lift a person to the sky isles, but gloom bats have nested in the vents. Clear them, and I'll tune a Skyward Charm for you.",
		finish = "The charm is singing. Step onto any wind shrine and hold on to your hat!",
		objective = { kind = "slay", target = "bat", count = 6, text = "Clear the Gloom Bats from the shrine" },
		reward = { dew = 250, unlock = "skyward" },
	},
	{
		id = "dorran_bones", name = "Bones of the Old Fort", giver = "dorran",
		intro = "The fort's old garrison keeps rising. Put them back to rest.",
		finish = "Quiet again, for a while. Have this; it belonged to a better soldier than me.",
		objective = { kind = "slay", target = "skeleton", count = 8, text = "Defeat Crypt Skeletons at the Old Fort" },
		reward = { dew = 230, weapon = 3 },
	},
	{
		id = "dorran_relics", name = "Relics of the Watch", giver = "dorran", requires = { "dorran_bones" },
		intro = "Their badges and keepsakes are scattered in the ruins. Gather them so we can honour the old watch.",
		finish = "Every one accounted for. Thank you, friend of the watch.",
		objective = { kind = "collect", target = "relic", count = 5, text = "Gather Old Fort Relics" },
		reward = { dew = 200, potions = 2 },
	},
	{
		id = "lyra_wisps", name = "Storm Wisps", giver = "lyra", requires = { "pell_skyward" },
		intro = "Storm wisps are drifting over the isles and frightening the sky gardens. Scatter them.",
		finish = "Calm air again. You fight well for a ground-walker.",
		objective = { kind = "slay", target = "wisp", count = 8, text = "Defeat Storm Wisps on the sky isles" },
		reward = { dew = 280, weapon = 3 },
	},
	{
		id = "lyra_shards", name = "Starfall Shards", giver = "lyra", requires = { "lyra_wisps" },
		intro = "Fallen starlight has crystallised across the isles. Gather the shards before the storm drinks them.",
		finish = "So bright! These will hold the storm back. Sage Vael on Stormcrown should see you now.",
		objective = { kind = "collect", target = "shard", count = 8, text = "Gather Starfall Shards across the sky isles" },
		reward = { dew = 320, weapon = 4 },
	},
	{
		id = "vael_storm", name = "Heart of the Storm", giver = "vael", requires = { "lyra_shards" },
		intro = "At Stormcrown's peak the Stormcaller gathers the gale. End it, and the skies will be safe to roam.",
		finish = "The sky is quiet. Sproutling Isles owes you more than it knows.",
		objective = { kind = "slay", target = "stormcaller", count = 1, text = "Defeat the Stormcaller" },
		reward = { dew = 700, weapon = 5 },
	},
} :: { Quest }

Quests.ById = {} :: { [string]: Quest }
for _, q in Quests.List do
	Quests.ById[q.id] = q
end

function Quests.get(id: string): Quest?
	return Quests.ById[id]
end

-- The count an objective needs (visit: number of spots; bring/talk: 1).
function Quests.goal(q: Quest): number
	local o = q.objective
	if o.kind == "visit" then
		return #(o.spots or {})
	elseif o.kind == "slay" or o.kind == "collect" then
		return o.count or 1
	end
	return 1
end

return Quests
