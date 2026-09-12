--!strict

local NumberFormat = {}

local SUFFIXES = {
	{ 1e24, "Sp" },
	{ 1e21, "Sx" },
	{ 1e18, "Qi" },
	{ 1e15, "Q" },
	{ 1e12, "T" },
	{ 1e9, "B" },
	{ 1e6, "M" },
	{ 1e3, "K" },
}

local function trimTrailingZero(formatted: string): string
	return (string.gsub(formatted, "%.0$", ""))
end

-- Compact display: 999 → "999", 1200 → "1.2K", 3500000 → "3.5M", etc.
function NumberFormat.FormatCompact(n: number): string
	local value = if typeof(n) == "number" then n else 0
	local sign = if value < 0 then "-" else ""
	local absValue = math.abs(value)

	if absValue < 1000 then
		if absValue == math.floor(absValue) then
			return sign .. tostring(math.floor(absValue))
		end
		return sign .. trimTrailingZero(string.format("%.1f", absValue))
	end

	for _, entry in ipairs(SUFFIXES) do
		local threshold = entry[1] :: number
		local suffix = entry[2] :: string
		if absValue >= threshold then
			local scaled = absValue / threshold
			return sign .. trimTrailingZero(string.format("%.1f", scaled)) .. suffix
		end
	end

	return sign .. tostring(math.floor(absValue))
end

function NumberFormat.FormatCoins(n: number): string
	return NumberFormat.FormatCompact(n)
end

-- Luck multipliers: small values keep one decimal; large use compact + "x".
function NumberFormat.FormatLuck(mult: number): string
	local value = if typeof(mult) == "number" then mult else 1
	if value < 10 then
		return trimTrailingZero(string.format("%.1f", value)) .. "x"
	end
	return NumberFormat.FormatCompact(value) .. "x"
end

-- Playtime: "12m", "3h 5m", "2d 4h".
function NumberFormat.FormatDuration(seconds: number): string
	local total = math.max(0, math.floor(if typeof(seconds) == "number" then seconds else 0))
	local days = math.floor(total / 86400)
	local hours = math.floor((total % 86400) / 3600)
	local minutes = math.floor((total % 3600) / 60)
	if days > 0 then
		return string.format("%dd %dh", days, hours)
	end
	if hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	end
	return string.format("%dm", minutes)
end

return NumberFormat
