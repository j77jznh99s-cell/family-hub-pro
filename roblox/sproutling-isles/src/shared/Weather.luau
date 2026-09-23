--!strict
-- Weather events and the mutations they can apply when a Sproutling hatches.

export type Mutation = {
	id: string,
	name: string,
	multiplier: number,
	color: Color3,
}

export type WeatherType = {
	id: string,
	name: string,
	growthSpeed: number, -- 2 = plants grow twice as fast while it lasts
	mutation: string?,
	mutationChance: number,
	naturalWeight: number, -- 0 = only via Robux summon
	sky: Color3,
	announce: string,
}

local Weather = {}

Weather.Mutations = {
	golden = { id = "golden", name = "Golden", multiplier = 4, color = Color3.fromRGB(255, 205, 50) },
	dewy = { id = "dewy", name = "Dewy", multiplier = 1.5, color = Color3.fromRGB(120, 200, 255) },
	charged = { id = "charged", name = "Charged", multiplier = 2, color = Color3.fromRGB(255, 255, 110) },
	starry = { id = "starry", name = "Starry", multiplier = 3, color = Color3.fromRGB(190, 170, 255) },
	prismatic = { id = "prismatic", name = "Prismatic", multiplier = 6, color = Color3.fromRGB(255, 120, 230) },
} :: { [string]: Mutation }

Weather.Types = {
	drizzle = { id = "drizzle", name = "Drizzle", growthSpeed = 2, mutation = "dewy", mutationChance = 0.3, naturalWeight = 50, sky = Color3.fromRGB(150, 170, 190), announce = "A Drizzle rolls in: plants grow 2x faster and may hatch Dewy!" },
	thunder = { id = "thunder", name = "Thunderbloom", growthSpeed = 1.5, mutation = "charged", mutationChance = 0.2, naturalWeight = 30, sky = Color3.fromRGB(90, 90, 120), announce = "Thunderbloom! Hatches may come out Charged (x2)!" },
	starfall = { id = "starfall", name = "Starfall", growthSpeed = 1, mutation = "starry", mutationChance = 0.15, naturalWeight = 15, sky = Color3.fromRGB(40, 40, 90), announce = "Stars are falling! Hatches may turn Starry (x3)!" },
	aurora = { id = "aurora", name = "Aurora", growthSpeed = 1.5, mutation = "prismatic", mutationChance = 0.1, naturalWeight = 5, sky = Color3.fromRGB(80, 200, 170), announce = "AURORA! Prismatic (x6) hatches are possible!" },
} :: { [string]: WeatherType }

return Weather
