--!strict
-- Number and time formatting shared by server labels and client UI.

local Format = {}

local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }

function Format.number(value: number): string
	value = math.floor(value)
	if math.abs(value) < 1000 then
		return tostring(value)
	end
	local tier = math.min(math.floor(math.log10(math.abs(value)) / 3), #suffixes - 1)
	local scaled = value / (1000 ^ tier)
	local text = if scaled >= 100 then string.format("%d", scaled) else string.format("%.1f", scaled)
	text = string.gsub(text, "%.0$", "")
	return text .. suffixes[tier + 1]
end

function Format.time(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds < 60 then
		return string.format("%ds", seconds)
	elseif seconds < 3600 then
		return string.format("%dm %02ds", seconds // 60, seconds % 60)
	end
	return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
end

return Format
