--!strict
-- Vehicles you can own: bought at the Carriage Works (land), the Boatwright (water) and the Aerie
-- Workshop (air), each unlocked at a player level. Paint and trim are changed at the
-- Coachpaint Atelier, the Sailmaker and the Aerie paint loft. G opens your garage.
--
-- Classes: land vehicles ride the ground (a speed boost like the horse); water vehicles hold to
-- the sea surface; air vehicles fly ("hover": climb and hold altitude; "glide": always moving
-- forward like a plane). `kind` is what the vehicle is in everyday terms.

local Vehicles = {}

export type Vehicle = {
	id: string,
	name: string,
	kind: string,
	class: string, -- "land" | "water" | "air"
	flight: string?, -- air: "hover" | "glide"
	level: number,
	price: number,
	speed: number,
	shop: string,
	shopName: string,
	blurb: string,
}

Vehicles.List = {
	{ id = "wagon", name = "Horse & Wagon", kind = "horse and trailer", class = "land", level = 3, price = 1200, speed = 14, shop = "carriages", shopName = "Carriage Works", blurb = "A sturdy horse pulling a little trailer." },
	{ id = "carriage", name = "Carriage", kind = "car", class = "land", level = 6, price = 3200, speed = 22, shop = "carriages", shopName = "Carriage Works", blurb = "A quick two-horse carriage for the open road." },
	{ id = "coach", name = "Royal Coach", kind = "luxury car", class = "land", level = 14, price = 11000, speed = 30, shop = "carriages", shopName = "Carriage Works", blurb = "Gilded wheels, four white horses, no traffic." },
	{ id = "rowboat", name = "Rowboat", kind = "boat", class = "water", level = 2, price = 600, speed = 26, shop = "boats", shopName = "Boatwright", blurb = "Small, steady and easy to row." },
	{ id = "sloop", name = "Sloop", kind = "sailing boat", class = "water", level = 9, price = 5200, speed = 42, shop = "boats", shopName = "Boatwright", blurb = "A swift single-mast sailing boat." },
	{ id = "barge", name = "Swan Barge", kind = "speedboat", class = "water", level = 20, price = 16000, speed = 60, shop = "boats", shopName = "Boatwright", blurb = "A gleaming swan-prowed racer." },
	{ id = "ornithopter", name = "Ornithopter", kind = "plane", class = "air", flight = "glide", level = 16, price = 14000, speed = 70, shop = "aircraft", shopName = "Aerie Workshop", blurb = "Flapping canvas wings. Keep moving or glide down." },
	{ id = "aerialscrew", name = "Aerial Screw", kind = "helicopter", class = "air", flight = "hover", level = 24, price = 28000, speed = 55, shop = "aircraft", shopName = "Aerie Workshop", blurb = "A spinning sail lifts you straight up and holds you there." },
	{ id = "skyship", name = "Personal Skyship", kind = "airship", class = "air", flight = "hover", level = 34, price = 60000, speed = 80, shop = "aircraft", shopName = "Aerie Workshop", blurb = "Your own little airship. Fast, high and grand." },
	{ id = "griffin", name = "Storm Griffin", kind = "legendary flying mount", class = "air", flight = "hover", level = 50, price = 150000, speed = 110, shop = "aircraft", shopName = "Aerie Workshop", blurb = "Only legends ride the storm." },
} :: { Vehicle }

Vehicles.ById = {} :: { [string]: Vehicle }
for _, v in Vehicles.List do
	Vehicles.ById[v.id] = v
end

function Vehicles.get(id: string): Vehicle?
	return Vehicles.ById[id]
end

-- Paint and trim colours ({ r, g, b }); index 1 is the default.
Vehicles.Paints = {
	{ name = "Oak", rgb = { 150, 105, 65 } },
	{ name = "Royal Red", rgb = { 185, 45, 50 } },
	{ name = "Deep Blue", rgb = { 45, 75, 160 } },
	{ name = "Forest", rgb = { 50, 120, 70 } },
	{ name = "Ivory", rgb = { 240, 235, 220 } },
	{ name = "Gold", rgb = { 225, 180, 60 } },
	{ name = "Plum", rgb = { 120, 60, 140 } },
	{ name = "Sky", rgb = { 120, 190, 245 } },
	{ name = "Ebony", rgb = { 45, 40, 40 } },
	{ name = "Rose", rgb = { 240, 130, 170 } },
	{ name = "Ember", rgb = { 240, 120, 40 } },
	{ name = "Mint", rgb = { 130, 220, 170 } },
}
Vehicles.PaintPrice = 40

return Vehicles
