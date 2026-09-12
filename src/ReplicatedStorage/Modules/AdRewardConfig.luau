--!strict

--[[
	Daily rewarded-video track.
	Every completed ad: coins.
	Milestone potions at 5 / 10 watches. Resets at UTC midnight (same as Daily).

	Roblox requires a Developer Product as the AdReward vehicle.
	Create one in Creator Dashboard (Monetization → Developer Products),
	paste the ID here, and enable Rewarded Video under Monetization → Ads.
]]

local DailyConfig = require(script.Parent:WaitForChild("DailyConfig"))
local PotionConfig = require(script.Parent:WaitForChild("PotionConfig"))

export type Milestone = {
	At: number,
	PotionId: string,
}

local AdRewardConfig = {}

-- Creator Dashboard → Developer Products. Paste ID here.
AdRewardConfig.ProductId = 0
-- Optional Ads → Placements ID (0 = default placement).
AdRewardConfig.PlacementId = 0

-- Economy 1D: 10 ads ≈ 1.5k/day — helps F2P, cannot buy Bronze in 15 min.
AdRewardConfig.CoinsPerAd = 150
AdRewardConfig.DailyMax = 10

AdRewardConfig.Milestones = {
	{ At = 5, PotionId = "luck" },
	{ At = 10, PotionId = "super_bundle" },
} :: { Milestone }

function AdRewardConfig.GetUtcDayKey(unixTime: number?): string
	return DailyConfig.GetUtcDayKey(unixTime)
end

function AdRewardConfig.IsProductConfigured(): boolean
	return AdRewardConfig.ProductId > 0
end

function AdRewardConfig.IsProductId(productId: number): boolean
	return AdRewardConfig.IsProductConfigured() and productId == AdRewardConfig.ProductId
end

function AdRewardConfig.ClampWatched(count: number): number
	if typeof(count) ~= "number" or count ~= count then
		return 0
	end
	return math.clamp(math.floor(count), 0, AdRewardConfig.DailyMax)
end

function AdRewardConfig.GetMilestonePotionName(potionId: string): string
	local def = PotionConfig.Get(potionId)
	if def then
		return def.Name
	end
	return potionId
end

function AdRewardConfig.GetMilestoneDescription(potionId: string): string
	local def = PotionConfig.Get(potionId)
	if def then
		return def.Description
	end
	return ""
end

return AdRewardConfig
