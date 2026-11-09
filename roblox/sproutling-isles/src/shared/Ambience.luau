--!strict
-- Lighting look for Sproutling Isles: a bright, saturated, slightly hazy afternoon.
--
-- Like MapBuilder it touches no services, so it runs both at server start (on game.Lighting)
-- and offline under Lune (tools/bake-map.luau), which passes its own Roblox API table.
-- Apply() is idempotent: it finds or creates each effect by class name and sets its properties.
--
-- WeatherService tints the Atmosphere during weather and restores Ambience.Clear afterwards,
-- because once an Atmosphere exists Roblox ignores Lighting.Fog*.

local Ambience = {}

local Instance = Instance
local Color3 = Color3

function Ambience.useApi(api: any)
	Instance = api.Instance
	Color3 = api.Color3
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Clear-weather Atmosphere values (WeatherService tweens back to these).
function Ambience.clearAtmosphere(): { [string]: any }
	return {
		Density = 0.3,
		Offset = 0.22,
		Color = rgb(205, 225, 255),
		Decay = rgb(110, 150, 215),
		Glare = 0.3,
		Haze = 1.3,
	}
end

-- Atmosphere values while a weather with this sky colour is active.
function Ambience.weatherAtmosphere(sky: Color3, thick: boolean): { [string]: any }
	return {
		Density = if thick then 0.55 else 0.42,
		Offset = 0.1,
		Color = sky,
		Decay = sky,
		Glare = 0,
		Haze = if thick then 2.6 else 1.8,
	}
end

local function ensure(lighting: Instance, className: string): Instance
	local existing = lighting:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local effect = Instance.new(className)
	effect.Name = className
	effect.Parent = lighting
	return effect
end

local function set(target: Instance, props: { [string]: any })
	for key, value in props do
		(target :: any)[key] = value
	end
end

function Ambience.Apply(lighting: Instance)
	set(lighting, {
		Brightness = 3,
		ClockTime = 15.2,
		GeographicLatitude = 30,
		ExposureCompensation = 0.15,
		Ambient = rgb(125, 118, 145),
		OutdoorAmbient = rgb(145, 150, 175),
		ColorShift_Top = rgb(255, 232, 200),
		ColorShift_Bottom = rgb(120, 150, 210),
		EnvironmentDiffuseScale = 1,
		EnvironmentSpecularScale = 1,
		GlobalShadows = true,
	})

	set(ensure(lighting, "Atmosphere"), Ambience.clearAtmosphere())

	-- Neon parts (lanterns, crystals, beams, plot rims) glow softly.
	set(ensure(lighting, "BloomEffect"), {
		Intensity = 0.85,
		Size = 30,
		Threshold = 1.35,
	})

	-- Push colours a little: greener grass, bluer sea, warmer light.
	set(ensure(lighting, "ColorCorrectionEffect"), {
		Saturation = 0.22,
		Contrast = 0.1,
		Brightness = 0.03,
		TintColor = rgb(255, 248, 238),
	})

	set(ensure(lighting, "SunRaysEffect"), {
		Intensity = 0.09,
		Spread = 0.75,
	})

	-- Soft depth blur only on the far horizon, so the floating islets read as distant.
	set(ensure(lighting, "DepthOfFieldEffect"), {
		FarIntensity = 0.12,
		FocusDistance = 260,
		InFocusRadius = 300,
		NearIntensity = 0,
	})

	set(ensure(lighting, "Sky"), {
		SunAngularSize = 16,
		MoonAngularSize = 11,
		StarCount = 3000,
		CelestialBodiesShown = true,
	})
end

return Ambience
