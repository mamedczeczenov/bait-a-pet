--!strict

--[[
	Session playtime gifts. Not persisted — leave/rejoin from the Roblox menu resets.
]]

export type GiftDefinition = {
	Tier: number,
	Seconds: number,
	Mult: number,
	Name: string,
}

export type GiftState = "Locked" | "Ready" | "Claimed"

local GiftConfig = {}

GiftConfig.MaxElapsedSeconds = 24 * 60 * 60
GiftConfig.LeaveWarningSeconds = 4.5

GiftConfig.Gifts = {
	{ Tier = 1, Seconds = 5 * 60, Mult = 1.1, Name = "5 Minute Gift" },
	{ Tier = 2, Seconds = 20 * 60, Mult = 1.2, Name = "20 Minute Gift" },
	{ Tier = 3, Seconds = 40 * 60, Mult = 1.3, Name = "40 Minute Gift" },
	{ Tier = 4, Seconds = 60 * 60, Mult = 1.5, Name = "1 Hour Gift" },
	{ Tier = 5, Seconds = 2 * 60 * 60, Mult = 2, Name = "2 Hour Gift" },
} :: { GiftDefinition }

function GiftConfig.Count(): number
	return #GiftConfig.Gifts
end

function GiftConfig.Get(tier: number): GiftDefinition?
	if typeof(tier) ~= "number" then
		return nil
	end
	local index = math.floor(tier)
	return GiftConfig.Gifts[index]
end

function GiftConfig.GetLuckForTier(claimedTier: number): number
	local gift = GiftConfig.Get(claimedTier)
	if gift then
		return gift.Mult
	end
	return 1
end

function GiftConfig.ClampTier(tier: number): number
	if typeof(tier) ~= "number" then
		return 0
	end
	return math.clamp(math.floor(tier), 0, GiftConfig.Count())
end

function GiftConfig.ClampElapsed(elapsed: number): number
	if typeof(elapsed) ~= "number" or elapsed ~= elapsed then
		return 0
	end
	return math.clamp(elapsed, 0, GiftConfig.MaxElapsedSeconds)
end

function GiftConfig.GetState(elapsed: number, claimedTier: number, tier: number): GiftState
	local gift = GiftConfig.Get(tier)
	if not gift then
		return "Locked"
	end
	if claimedTier >= tier then
		return "Claimed"
	end
	if claimedTier ~= tier - 1 then
		return "Locked"
	end
	if elapsed >= gift.Seconds then
		return "Ready"
	end
	return "Locked"
end

function GiftConfig.RemainingSeconds(elapsed: number, claimedTier: number, tier: number): number
	local gift = GiftConfig.Get(tier)
	if not gift then
		return 0
	end
	if claimedTier >= tier then
		return 0
	end
	return math.max(0, gift.Seconds - elapsed)
end

function GiftConfig.HasReady(elapsed: number, claimedTier: number): boolean
	local nextTier = claimedTier + 1
	return GiftConfig.GetState(elapsed, claimedTier, nextTier) == "Ready"
end

function GiftConfig.FormatMult(mult: number): string
	local value = if typeof(mult) == "number" then mult else 1
	local text = string.format("%.1f", value)
	text = string.gsub(text, "%.0$", "")
	return "×" .. text
end

function GiftConfig.FormatCountdown(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	local h = math.floor(s / 3600)
	local m = math.floor((s % 3600) / 60)
	local rem = s % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, rem)
	end
	return string.format("%d:%02d", m, rem)
end

return GiftConfig
