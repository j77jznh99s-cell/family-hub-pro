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

export type Reward = { dew: number?, materials: { [string]: number }?, weapon: number?, potions: number?, unlock: string? }

export type Quest = {
	id: string,
	name: string,
	giver: string,
	turnIn: string?, -- defaults to the giver
	requires: { string }?,
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
} :: { [string]: { name: string, color: RGB } }

-- Where the items lie: around a person's camp (`npc`, `count`, `spread` studs), or on the
-- sky isles (`isles`, `perIsle`).
Quests.ItemSpots = {
	{ item = "satchel", npc = "bryn", count = 7, spread = 220 },
	{ item = "amber", npc = "maple", count = 7, spread = 180 },
	{ item = "ghostcap", npc = "ilsa", count = 8, spread = 200 },
	{ item = "lamb", npc = "tamsin", count = 7, spread = 200 },
	{ item = "glowstone", npc = "gorrim", count = 8, spread = 190 },
	{ item = "relic", npc = "dorran", count = 6, spread = 110 },
	{ item = "shard", isles = true, perIsle = 2 },
} :: { any }

----------------------------------------------------------------------------------------------
-- people

Quests.Npcs = {
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
	cairnWest = { name = "West Peak Cairn", near = { -1060, -260 } },
	cairnNorth = { name = "North Peak Cairn", near = { 620, -1000 } },
	cairnSouth = { name = "South Peak Cairn", near = { 820, 1700 } },
} :: { [string]: { name: string, near: { number } } }

-- Enemy camps the quests need, beside a person's camp (offset x, z from it) or on a named isle.
Quests.Camps = {
	{ npc = "bryn", offset = { -90, 70 }, kind = "wolf", count = 4 },
	{ npc = "maple", offset = { 100, -80 }, kind = "goblin", count = 4 },
	{ npc = "tamsin", offset = { 90, 90 }, kind = "slime", count = 5 },
	{ npc = "gorrim", offset = { 110, 60 }, kind = "golem", count = 3 },
	{ npc = "gorrim", offset = { -120, 40 }, kind = "golem", count = 2 },
	{ npc = "pell", offset = { 80, 70 }, kind = "bat", count = 5 },
	{ npc = "dorran", offset = { -80, 40 }, kind = "skeleton", count = 5 },
	{ isle = "Windward Isle", kind = "wisp", count = 3 },
	{ isle = "Starfall Isle", kind = "wisp", count = 3 },
	{ isle = "Gale Rock", kind = "wisp", count = 3 },
	{ isle = "Stormcrown", kind = "wisp", count = 3 },
	{ isle = "Stormcrown", kind = "stormcaller", count = 1, boss = true },
} :: { any }

----------------------------------------------------------------------------------------------
-- quests

Quests.List = {
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
