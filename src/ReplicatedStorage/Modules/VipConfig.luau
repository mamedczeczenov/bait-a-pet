--!strict

--[[
	VIP gamepass config.
	GamePassId > 0: ownership from MarketplaceService (join + purchase).
	0 = disabled (nobody gets VIP; Studio /vip on|off still works for map QA).
]]

local VipConfig = {}

-- Creator Dashboard Game Pass ID (soft launch).
-- Live price is 99 R$ (set on the pass, not here). Potion / bait / upgrade
-- Robux prices are balanced against that: snacks < VIP < mid bait skips.
VipConfig.GamePassId = 1942164267

VipConfig.PromptMessage = "VIP unlocks the VIP cave (4x luck)."
VipConfig.PurchaseFailedMessage = "VIP purchase cancelled or failed."

function VipConfig.IsConfigured(): boolean
	return typeof(VipConfig.GamePassId) == "number" and VipConfig.GamePassId > 0
end

return VipConfig
