--!strict

--[[
	Client-only VIP Game Pass purchase prompt.
	Surfaces Marketplace errors instead of failing silently.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local VipConfig = require(script.Parent:WaitForChild("VipConfig"))

local VipPurchase = {}

local lastPromptAt = 0
local PROMPT_COOLDOWN = 1.25
local lastOnMessage: ((string) -> ())? = nil

function VipPurchase.Prompt(onMessage: ((string) -> ())?): boolean
	local player = Players.LocalPlayer
	if not player then
		return false
	end

	if not VipConfig.IsConfigured() then
		if onMessage then
			onMessage("VIP is not configured yet.")
		end
		return false
	end

	local now = os.clock()
	if now - lastPromptAt < PROMPT_COOLDOWN then
		return false
	end
	lastPromptAt = now
	lastOnMessage = onMessage

	local passId = VipConfig.GamePassId

	local infoOk, infoOrErr = pcall(function()
		return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
	end)

	if not infoOk then
		warn(string.format("[VipPurchase] GetProductInfo failed for %d: %s", passId, tostring(infoOrErr)))
		if onMessage then
			onMessage("VIP pass unavailable (wrong place or not published).")
		end
		return false
	end

	local info = infoOrErr :: { [string]: any }
	if info.IsForSale ~= true then
		warn(string.format("[VipPurchase] Pass %d is not for sale.", passId))
		if onMessage then
			onMessage("VIP pass is not for sale in Creator Dashboard.")
		end
		return false
	end

	if onMessage then
		local price = info.PriceInRobux
		if typeof(price) == "number" then
			onMessage(string.format("%s (%d R$)", VipConfig.PromptMessage, price))
		else
			onMessage(VipConfig.PromptMessage)
		end
	end

	local promptOk, promptErr = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, passId)
	end)

	if not promptOk then
		warn(string.format("[VipPurchase] Prompt failed for %d: %s", passId, tostring(promptErr)))
		if onMessage then
			onMessage("Could not open VIP purchase. Try again in the live game (not Studio).")
		end
		return false
	end

	return true
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if player ~= Players.LocalPlayer then
		return
	end
	if not VipConfig.IsConfigured() or gamePassId ~= VipConfig.GamePassId then
		return
	end

	local onMessage = lastOnMessage
	lastOnMessage = nil
	if not onMessage then
		return
	end

	if wasPurchased == true then
		onMessage("VIP unlocked — 4x luck in the VIP cave.")
	else
		onMessage(VipConfig.PurchaseFailedMessage)
	end
end)

return VipPurchase
