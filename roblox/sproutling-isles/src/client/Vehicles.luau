-- Vehicles on the client: the garage (G), riding boats and flying machines, and the paint shops.
--
-- The server welds the vehicle on and sets VehicleClass/VehicleSpeed/VehicleFlight. Land
-- vehicles just make you walk faster. For water and air the character is held by a
-- LinearVelocity and an AlignOrientation on its root (the client owns its character's
-- physics): boats stick to the sea surface and stop at the beach; "hover" craft climb with
-- Space and sink with Ctrl; "glide" craft (the Ornithopter) always fly forward where the camera
-- points, W for more speed. Phones get Up/Down buttons while flying.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Vehicles = require(Shared:WaitForChild("Vehicles"))
local Shops = require(Shared:WaitForChild("Shops"))
local Landscape = require(Shared:WaitForChild("Landscape"))

local VehicleClient = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local VehicleRemote = remotes:WaitForChild("Vehicle") :: RemoteEvent
local ActionRemote = remotes:WaitForChild("InventoryAction") :: RemoteEvent
local OpenShopRemote = remotes:WaitForChild("OpenShop") :: RemoteEvent

local FONT = Enum.Font.FredokaOne
local TITLE = Enum.Font.Fantasy
local PANEL = Color3.fromRGB(40, 32, 28)
local CARD = Color3.fromRGB(66, 54, 46)
local GOLD = Color3.fromRGB(240, 200, 110)
local WHITE = Color3.new(1, 1, 1)

local function make(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	return inst
end

local function corner(r: number): UICorner
	return make("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function label(text: string, size: UDim2, pos: UDim2, color: Color3?, parent: Instance?): TextLabel
	return make("TextLabel", {
		BackgroundTransparency = 1,
		Size = size,
		Position = pos,
		Font = FONT,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = color or WHITE,
		TextStrokeTransparency = 0.6,
		Text = text,
		Parent = parent,
	})
end

local function button(text: string, size: UDim2, pos: UDim2, color: Color3, parent: Instance, onClick: () -> ()): TextButton
	local b = make("TextButton", {
		Size = size,
		Position = pos,
		BackgroundColor3 = color,
		Font = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.5,
		Text = text,
		Parent = parent,
	}, { corner(6) })
	b.Activated:Connect(onClick)
	return b
end

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local gui = make("ScreenGui", { Name = "VehicleGui", ResetOnSpawn = false, Parent = player:WaitForChild("PlayerGui") })

local function window(title: string, w: number, h: number): (Frame, Frame)
	local frame = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = PANEL,
		Visible = false,
		Parent = gui,
	}, { corner(10), make("UIStroke", { Color = GOLD, Thickness = 2 }) })
	local scale = make("UIScale", { Parent = frame })
	local function fit()
		local camera = workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		scale.Scale = math.min(1, (view.X - 20) / w, (view.Y - 80) / h)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -60, 0, 32), Font = TITLE, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD, Text = title, Parent = frame })
	button("X", UDim2.fromOffset(30, 30), UDim2.new(1, -38, 0, 8), Color3.fromRGB(150, 60, 60), frame, function()
		frame.Visible = false
	end)
	local list = make("ScrollingFrame", {
		BackgroundColor3 = Color3.fromRGB(30, 24, 22),
		Position = UDim2.fromOffset(14, 48),
		Size = UDim2.new(1, -28, 1, -62),
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = frame,
	}, {
		make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10) }),
	})
	return frame, list
end

local function clear(container: Instance)
	for _, c in container:GetChildren() do
		if c:IsA("Frame") or c:IsA("TextLabel") then
			c:Destroy()
		end
	end
end

----------------------------------------------------------------------------------------------
-- garage

local garage, garageList = window("Garage", 560, 440)

local function renderGarage()
	clear(garageList)
	local level = player:GetAttribute("Level") or 1
	local riding = player:GetAttribute("VehicleId")
	for i, v in Vehicles.List do
		local owned = player:GetAttribute("Vehicle_" .. v.id) == true
		local row = make("Frame", { BackgroundColor3 = CARD, Size = UDim2.new(1, 0, 0, 58), LayoutOrder = i, Parent = garageList }, { corner(6) })
		local paint = Vehicles.Paints[player:GetAttribute("VPaint_" .. v.id) or 1]
		make("Frame", { Position = UDim2.fromOffset(8, 12), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = rgb(paint.rgb), Parent = row }, { corner(17) })
		label(v.name .. "  (" .. v.kind .. ")", UDim2.new(0.62, -50, 0, 24), UDim2.fromOffset(50, 4), if owned then GOLD else Color3.fromRGB(180, 170, 160), row)
		local info = if owned then v.blurb elseif level >= v.level then "Buy at the " .. v.shopName .. " (" .. v.price .. " Dew)" else "Unlocks at level " .. v.level .. " - " .. v.shopName
		label(info, UDim2.new(0.62, -50, 0, 18), UDim2.fromOffset(50, 32), Color3.fromRGB(210, 200, 185), row)
		if owned then
			if riding == v.id then
				button("Get off", UDim2.new(0.34, 0, 0, 34), UDim2.new(0.64, 0, 0, 12), Color3.fromRGB(150, 80, 60), row, function()
					VehicleRemote:FireServer("dismiss")
				end)
			else
				button("Ride", UDim2.new(0.34, 0, 0, 34), UDim2.new(0.64, 0, 0, 12), Color3.fromRGB(70, 140, 80), row, function()
					VehicleRemote:FireServer("summon", v.id)
					garage.Visible = false
				end)
			end
		end
	end
end

function VehicleClient.toggleGarage()
	garage.Visible = not garage.Visible
	if garage.Visible then
		renderGarage()
	end
end

local garageButton = button("Garage (G)", UDim2.fromOffset(110, 34), UDim2.new(0, 12, 0, 256), Color3.fromRGB(80, 110, 150), gui, VehicleClient.toggleGarage)
garageButton.Name = "GarageButton"
player:GetAttributeChangedSignal("VehicleId"):Connect(function()
	if garage.Visible then
		renderGarage()
	end
end)

----------------------------------------------------------------------------------------------
-- paint shops

local paintWin, paintList = window("Paint Shop", 600, 470)
local paintClass: string? = nil

local function renderPaint()
	if not paintClass then
		return
	end
	clear(paintList)
	local any = false
	for i, v in Vehicles.List do
		if v.class == paintClass and player:GetAttribute("Vehicle_" .. v.id) == true then
			any = true
			local row = make("Frame", { BackgroundColor3 = CARD, Size = UDim2.new(1, 0, 0, 128), LayoutOrder = i, Parent = paintList }, { corner(6) })
			label(v.name, UDim2.new(1, -16, 0, 24), UDim2.fromOffset(8, 4), GOLD, row)
			for s, slot in { "paint", "trim" } do
				local current = player:GetAttribute((if slot == "paint" then "VPaint_" else "VTrim_") .. v.id) or 1
				label(if slot == "paint" then "Paint" else "Trim", UDim2.fromOffset(60, 20), UDim2.fromOffset(8, 32 + (s - 1) * 46), WHITE, row)
				for k, p in Vehicles.Paints do
					local swatch = make("TextButton", {
						Position = UDim2.fromOffset(70 + (k - 1) * 40, 28 + (s - 1) * 46),
						Size = UDim2.fromOffset(34, 34),
						BackgroundColor3 = rgb(p.rgb),
						Text = "",
						Parent = row,
					}, { corner(17), make("UIStroke", { Color = if k == current then GOLD else Color3.fromRGB(30, 25, 20), Thickness = if k == current then 3 else 1 }) })
					swatch.Activated:Connect(function()
						ActionRemote:FireServer("paint", { vehicle = v.id, slot = slot, index = k })
					end)
				end
			end
		end
	end
	if not any then
		label("You don't own anything to paint here yet.", UDim2.new(1, 0, 0, 30), UDim2.new(), Color3.fromRGB(220, 210, 190), paintList)
	end
	label(string.format("Each coat costs %d Dew. Re-summon your vehicle to see new colours.", Vehicles.PaintPrice), UDim2.new(1, 0, 0, 20), UDim2.new(), Color3.fromRGB(170, 255, 200), paintList).LayoutOrder = 999
end

player.AttributeChanged:Connect(function(name)
	if paintWin.Visible and (name:sub(1, 7) == "VPaint_" or name:sub(1, 6) == "VTrim_") then
		renderPaint()
	end
end)

OpenShopRemote.OnClientEvent:Connect(function(key: string, name: string)
	local shop = Shops.Catalog[key]
	if shop and shop.customize then
		paintClass = shop.customize
		local heading = paintWin:FindFirstChildOfClass("TextLabel")
		if heading then
			heading.Text = name
		end
		paintWin.Visible = true
		renderPaint()
	end
end)

----------------------------------------------------------------------------------------------
-- riding water and air

local controls: any = nil
pcall(function()
	controls = require((player:WaitForChild("PlayerScripts") :: any):WaitForChild("PlayerModule")):GetControls()
end)

local vertical = 0 -- +1 climb, -1 dive
local active: { lv: LinearVelocity, ao: AlignOrientation, att: Attachment, conn: RBXScriptConnection }? = nil
local yaw = 0

local function stopRide()
	if active then
		active.conn:Disconnect()
		active.lv:Destroy()
		active.ao:Destroy()
		active.att:Destroy()
		active = nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
	end
	ContextActionService:UnbindAction("VehicleUp")
	ContextActionService:UnbindAction("VehicleDown")
end

local function startRide(class: string)
	stopRide()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	humanoid.PlatformStand = true
	local att = Instance.new("Attachment")
	att.Name = "VehicleAttachment"
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = 1e7
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = root
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = 1e7
	ao.Responsiveness = 18
	ao.Parent = root
	local _, y = root.CFrame:ToOrientation()
	yaw = y
	local flight = player:GetAttribute("VehicleFlight")
	local function bindFlightButtons()
		local function hold(dir: number)
			return function(_, state: Enum.UserInputState)
				if state == Enum.UserInputState.Begin then
					vertical = dir
				elseif state == Enum.UserInputState.End then
					vertical = 0
				end
				return Enum.ContextActionResult.Pass
			end
		end
		ContextActionService:BindAction("VehicleUp", hold(1), true, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
		ContextActionService:BindAction("VehicleDown", hold(-1), true, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
		ContextActionService:SetTitle("VehicleUp", "Up")
		ContextActionService:SetTitle("VehicleDown", "Down")
		ContextActionService:SetPosition("VehicleUp", UDim2.new(1, -170, 1, -290))
		ContextActionService:SetPosition("VehicleDown", UDim2.new(1, -110, 1, -290))
	end
	if class == "air" then
		bindFlightButtons()
	end
	local conn = RunService.RenderStepped:Connect(function()
		if not root.Parent then
			stopRide()
			return
		end
		local speed = player:GetAttribute("VehicleSpeed") or 30
		local camera = workspace.CurrentCamera
		local look = camera.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		flatLook = if flatLook.Magnitude > 0.01 then flatLook.Unit else Vector3.new(0, 0, -1)
		local flatRight = Vector3.new(-flatLook.Z, 0, flatLook.X)
		local move = if controls then controls:GetMoveVector() else Vector3.zero
		local dir = flatRight * move.X + flatLook * -move.Z
		if dir.Magnitude > 1 then
			dir = dir.Unit
		end
		local pos = root.Position
		local velocity: Vector3
		local roll = 0
		if class == "water" then
			local target = Landscape.WaterLevel + 2.8
			local horizontal = dir * speed
			local ahead = pos + dir * 8
			if dir.Magnitude > 0.1 and (Landscape.inPlayArea(ahead.X, ahead.Z) or Landscape.height(ahead.X, ahead.Z) > Landscape.WaterLevel - 0.6) then
				horizontal = Vector3.zero -- the beach: hop off here
			end
			velocity = Vector3.new(horizontal.X, (target - pos.Y) * 5, horizontal.Z)
		elseif flight == "glide" then
			local throttle = 0.45 + 0.55 * math.max(0, -move.Z)
			velocity = look * speed * throttle + Vector3.new(0, vertical * speed * 0.4 - 4, 0)
			dir = flatLook
			roll = -move.X * 0.5
		else
			velocity = dir * speed + Vector3.new(0, vertical * speed * 0.6, 0)
		end
		-- stay above the ground and below the clouds
		local ground = if Landscape.inPlayArea(pos.X, pos.Z) then 0.5 else Landscape.height(pos.X, pos.Z)
		if class == "air" then
			if pos.Y < ground + 4 then
				velocity = Vector3.new(velocity.X, math.max(velocity.Y, (ground + 4 - pos.Y) * 4), velocity.Z)
			end
			if pos.Y > 900 then
				velocity = Vector3.new(velocity.X, math.min(velocity.Y, 0), velocity.Z)
			end
		end
		lv.VectorVelocity = velocity
		if dir.Magnitude > 0.1 then
			yaw = math.atan2(-dir.X, -dir.Z)
		end
		ao.CFrame = CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, roll)
	end)
	active = { lv = lv, ao = ao, att = att, conn = conn }
end

local function onClass()
	local class = player:GetAttribute("VehicleClass")
	if class == "water" or class == "air" then
		startRide(class)
	else
		stopRide()
	end
end
player:GetAttributeChangedSignal("VehicleClass"):Connect(onClass)
player.CharacterAdded:Connect(function()
	active = nil
	vertical = 0
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.G then
		VehicleClient.toggleGarage()
	end
end)

return VehicleClient
