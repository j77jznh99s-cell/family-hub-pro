--!strict
-- Builds a Sproutling's look out of primitive parts: round body, face, species topper,
-- and a halo + tint when it carries a mutation. All parts are anchored and non-colliding;
-- callers position the model with :PivotTo().

local Species = require(script.Parent.Species)
local Weather = require(script.Parent.Weather)

export type Sprout = { s: string, m: string?, z: number, u: string }

local SproutModel = {}

local function newPart(model: Model, name: string, shape: Enum.PartType?, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = offset
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Parent = model
	return p
end

local function addTopper(model: Model, kind: string, s: number, top: number, leaf: Color3)
	if kind == "Leaf" then
		newPart(model, "Stem", Enum.PartType.Cylinder, Vector3.new(0.9 * s, 0.25 * s, 0.25 * s), CFrame.new(0, top + 0.3 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), leaf)
		newPart(model, "Leaf", nil, Vector3.new(1.4 * s, 0.15 * s, 0.8 * s), CFrame.new(0.5 * s, top + 0.75 * s, 0) * CFrame.Angles(0, 0, math.rad(-25)), leaf, Enum.Material.Grass)
	elseif kind == "Petals" then
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2
			newPart(model, "Petal", Enum.PartType.Ball, Vector3.new(0.8 * s, 0.5 * s, 0.8 * s), CFrame.new(math.cos(a) * 0.55 * s, top + 0.25 * s, math.sin(a) * 0.55 * s), leaf)
		end
		newPart(model, "Center", Enum.PartType.Ball, Vector3.new(0.55 * s, 0.55 * s, 0.55 * s), CFrame.new(0, top + 0.4 * s, 0), Color3.fromRGB(255, 220, 90))
	elseif kind == "Cap" then
		newPart(model, "Cap", Enum.PartType.Ball, Vector3.new(3.2 * s, 1.4 * s, 3.2 * s), CFrame.new(0, top + 0.1 * s, 0), leaf)
		for i = 0, 3 do
			local a = i / 4 * math.pi * 2 + 0.4
			newPart(model, "Spot", Enum.PartType.Ball, Vector3.new(0.45 * s, 0.3 * s, 0.45 * s), CFrame.new(math.cos(a) * 0.9 * s, top + 0.6 * s, math.sin(a) * 0.9 * s), Color3.new(1, 1, 1))
		end
	elseif kind == "Spikes" then
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			newPart(model, "Spike", nil, Vector3.new(0.25 * s, 0.9 * s, 0.25 * s), CFrame.new(math.cos(a) * 0.9 * s, top - 0.2 * s, math.sin(a) * 0.9 * s) * CFrame.Angles(math.sin(a) * 0.5, 0, -math.cos(a) * 0.5), leaf, Enum.Material.Neon)
		end
	elseif kind == "Pad" then
		newPart(model, "Pad", Enum.PartType.Cylinder, Vector3.new(0.2 * s, 2.6 * s, 2.6 * s), CFrame.new(0, top, 0) * CFrame.Angles(0, 0, math.rad(90)), leaf, Enum.Material.Grass)
		newPart(model, "Bud", Enum.PartType.Ball, Vector3.new(0.6 * s, 0.6 * s, 0.6 * s), CFrame.new(0.5 * s, top + 0.3 * s, 0.3 * s), Color3.fromRGB(255, 170, 200))
	elseif kind == "Flame" then
		newPart(model, "Flame", Enum.PartType.Ball, Vector3.new(1.3 * s, 1.8 * s, 1.3 * s), CFrame.new(0, top + 0.5 * s, 0), leaf, Enum.Material.Neon)
		newPart(model, "FlameTip", Enum.PartType.Ball, Vector3.new(0.7 * s, 1.1 * s, 0.7 * s), CFrame.new(0, top + 1.3 * s, 0), Color3.fromRGB(255, 240, 150), Enum.Material.Neon)
	elseif kind == "Crystal" then
		for i = -1, 1 do
			newPart(model, "Crystal", nil, Vector3.new(0.5 * s, (1.6 - math.abs(i) * 0.5) * s, 0.5 * s), CFrame.new(i * 0.5 * s, top + 0.5 * s, 0) * CFrame.Angles(0, math.rad(45), math.rad(i * -20)), leaf, Enum.Material.Glass)
		end
	end
end

-- Dew per second a single Sproutling earns before player multipliers.
function SproutModel.income(sprout: Sprout): number
	local species = Species.get(sprout.s)
	if not species then
		return 0
	end
	local mutation = sprout.m and Weather.Mutations[sprout.m]
	return species.dewPerSecond * (mutation and mutation.multiplier or 1) * sprout.z
end

function SproutModel.displayName(sprout: Sprout): string
	local species = Species.get(sprout.s)
	local name = species and species.name or sprout.s
	local mutation = sprout.m and Weather.Mutations[sprout.m]
	if sprout.z >= 2 then
		name = "Huge " .. name
	end
	if mutation then
		name = mutation.name .. " " .. name
	end
	return name
end

function SproutModel.build(sprout: Sprout, withLabel: boolean?): Model
	local species = Species.get(sprout.s) or Species.List[1]
	local mutation = sprout.m and Weather.Mutations[sprout.m]
	local s = 1.4 * sprout.z

	local model = Instance.new("Model")
	model.Name = "Sprout_" .. species.id

	local bodyColor = species.body
	if mutation then
		bodyColor = bodyColor:Lerp(mutation.color, 0.45)
	end
	local body = newPart(model, "Body", Enum.PartType.Ball, Vector3.new(2.4 * s, 2.1 * s, 2.4 * s), CFrame.new(0, 1.05 * s, 0), bodyColor, if sprout.m == "golden" then Enum.Material.Foil else Enum.Material.SmoothPlastic)
	model.PrimaryPart = body
	body.PivotOffset = CFrame.new(0, -1.05 * s, 0) -- pivot at the feet so PivotTo() stands it on a surface

	-- face points towards -Z (model front)
	for _, side in { -1, 1 } do
		newPart(model, "Eye", Enum.PartType.Ball, Vector3.new(0.42 * s, 0.5 * s, 0.3 * s), CFrame.new(side * 0.45 * s, 1.3 * s, -1.05 * s), Color3.fromRGB(30, 30, 40))
		newPart(model, "Shine", Enum.PartType.Ball, Vector3.new(0.14 * s, 0.14 * s, 0.1 * s), CFrame.new(side * 0.45 * s + 0.08 * s, 1.42 * s, -1.2 * s), Color3.new(1, 1, 1), Enum.Material.Neon)
		newPart(model, "Cheek", Enum.PartType.Ball, Vector3.new(0.4 * s, 0.22 * s, 0.1 * s), CFrame.new(side * 0.8 * s, 1.0 * s, -0.98 * s), Color3.fromRGB(255, 150, 160))
		newPart(model, "Foot", Enum.PartType.Ball, Vector3.new(0.7 * s, 0.4 * s, 0.9 * s), CFrame.new(side * 0.55 * s, 0.15 * s, -0.3 * s), species.leaf)
	end

	addTopper(model, species.topper, s, 2.1 * s, species.leaf)

	if mutation then
		local halo = newPart(model, "Halo", Enum.PartType.Cylinder, Vector3.new(0.15 * s, 2 * s, 2 * s), CFrame.new(0, 3.3 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), mutation.color, Enum.Material.Neon)
		halo.Transparency = 0.3
		local light = Instance.new("PointLight")
		light.Color = mutation.color
		light.Range = 10
		light.Brightness = 1.5
		light.Parent = body
	end

	if withLabel then
		local gui = Instance.new("BillboardGui")
		gui.Name = "Info"
		gui.Size = UDim2.fromOffset(200, 50)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 3.2 * s + 1.5, 0)
		gui.MaxDistance = 70
		gui.LightInfluence = 0
		gui.Parent = body
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Name"
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.fromScale(1, 0.55)
		nameLabel.Font = Enum.Font.FredokaOne
		nameLabel.TextScaled = true
		nameLabel.Text = SproutModel.displayName(sprout)
		nameLabel.TextColor3 = Species.RarityColors[species.rarity]
		nameLabel.TextStrokeTransparency = 0.3
		nameLabel.Parent = gui
		local incomeLabel = nameLabel:Clone()
		incomeLabel.Name = "Income"
		incomeLabel.Position = UDim2.fromScale(0, 0.55)
		incomeLabel.Size = UDim2.fromScale(1, 0.45)
		incomeLabel.TextColor3 = Color3.fromRGB(150, 230, 255)
		incomeLabel.Text = ""
		incomeLabel.Parent = gui
	end

	return model
end

-- Converts an anchored display model into a carryable one welded to `root`.
function SproutModel.weldTo(model: Model, root: BasePart, offset: CFrame)
	local body = model.PrimaryPart :: BasePart
	model:PivotTo(root.CFrame * offset)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= body then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = body
	weld.Parent = body
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
		end
	end
end

return SproutModel
