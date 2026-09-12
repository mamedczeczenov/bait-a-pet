--!strict

--[[
	Client prompt for any Developer Product (baits, upgrade skips, etc.).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local RobuxPurchase = {}

local lastPromptAt = 0
local PROMPT_COOLDOWN = 1.25
local lastOnMessage: ((string) -> ())? = nil
local lastName: string? = nil

function RobuxPurchase.Prompt(productId: number, displayName: string, robuxPrice: number, onMessage: ((string) -> ())?): boolean
	local player = Players.LocalPlayer
	if not player then
		return false
	end

	if productId <= 0 then
		if onMessage then
			onMessage("Create Developer Products in Creator Dashboard and paste IDs into config.")
		end
		return false
	end

	local now = os.clock()
	if now - lastPromptAt < PROMPT_COOLDOWN then
		return false
	end
	lastPromptAt = now
	lastOnMessage = onMessage
	lastName = displayName

	local infoOk, infoOrErr = pcall(function()
		return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
	end)
	if not infoOk then
		warn(string.format("[RobuxPurchase] GetProductInfo failed for %d: %s", productId, tostring(infoOrErr)))
		if onMessage then
			onMessage("Product unavailable. Check the Developer Product ID / publish.")
		end
		return false
	end

	local info = infoOrErr :: { [string]: any }
	if info.IsForSale ~= true then
		if onMessage then
			onMessage("This product is not for sale in Creator Dashboard.")
		end
		return false
	end

	if onMessage then
		local price = info.PriceInRobux
		if typeof(price) == "number" then
			onMessage(string.format("Buy %s for %d R$?", displayName, price))
		elseif robuxPrice > 0 then
			onMessage(string.format("Buy %s for %d R$?", displayName, robuxPrice))
		else
			onMessage(string.format("Buy %s?", displayName))
		end
	end

	local promptOk, promptErr = pcall(function()
		MarketplaceService:PromptProductPurchase(player, productId)
	end)
	if not promptOk then
		warn(string.format("[RobuxPurchase] Prompt failed for %d: %s", productId, tostring(promptErr)))
		if onMessage then
			onMessage("Could not open Robux purchase. Try again in the live game.")
		end
		return false
	end

	return true
end

MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, _productId, wasPurchased)
	if player ~= Players.LocalPlayer then
		return
	end
	local onMessage = lastOnMessage
	local name = lastName
	lastOnMessage = nil
	lastName = nil
	if not onMessage then
		return
	end

	if wasPurchased == true then
		onMessage(string.format("Bought %s!", name or "item"))
	else
		onMessage("Purchase cancelled.")
	end
end)

return RobuxPurchase
