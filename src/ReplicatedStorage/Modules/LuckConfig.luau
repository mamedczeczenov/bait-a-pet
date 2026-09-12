--!strict

local LuckConfig = {}

-- Skill bar: missing is harsh, nailing it is juicy (Roblox big-number feel).
LuckConfig.MinMultiplier = 0.25
LuckConfig.MaxMultiplier = 8
LuckConfig.FillSpeed = 0.9

function LuckConfig.GetLuckMultiplier(fillAmount: number): number
	local clamped = math.clamp(fillAmount, 0, 1)
	return LuckConfig.MinMultiplier + (LuckConfig.MaxMultiplier - LuckConfig.MinMultiplier) * clamped
end

function LuckConfig.GetFillPercent(fillAmount: number): number
	return math.clamp(fillAmount, 0, 1) * 100
end

return LuckConfig
