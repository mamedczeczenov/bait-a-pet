--!strict

--[[
	Client prompt for Robux potion Developer Products.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local PotionConfig = require(script.Parent:WaitForChild("PotionConfig"))

local PotionPurchase = {}

local lastPromptAt = 0
local PROMPT_COOLDOWN = 1.25
local lastOnMessage: ((string) -> ())? = nil
local lastPotionId: string? = nil

function PotionPurchase.Prompt(potionId: string, onMessage: ((string) -> ())?): boolean
	local player = Players.LocalPlayer
	if not player then
		return false
	end

	local def = PotionConfig.Get(potionId)
	if not def or def.Currency ~= "Robux" then
		if onMessage then
			onMessage("Invalid potion.")
		end
		return false
	end

	if not PotionConfig.IsProductConfigured(def) then
		if onMessage then
			onMessage("Create Developer Products in Creator Dashboard and paste IDs into PotionConfig.")
		end
		return false
	end

	local now = os.clock()
	if now - lastPromptAt < PROMPT_COOLDOWN then
		return false
	end
	lastPromptAt = now
	lastOnMessage = onMessage
	lastPotionId = potionId

	local infoOk, infoOrErr = pcall(function()
		return MarketplaceService:GetProductInfo(def.ProductId, Enum.InfoType.Product)
	end)
	if not infoOk then
		warn(string.format("[PotionPurchase] GetProductInfo failed for %d: %s", def.ProductId, tostring(infoOrErr)))
		if onMessage then
			onMessage("Product unavailable. Check the Developer Product ID / publish.")
		end
		return false
	end

	local info = infoOrErr :: { [string]: any }
	if info.IsForSale ~= true then
		if onMessage then
			onMessage("This potion is not for sale in Creator Dashboard.")
		end
		return false
	end

	if onMessage then
		local price = info.PriceInRobux
		if typeof(price) == "number" then
			onMessage(string.format("Buy %s for %d R$?", def.Name, price))
		else
			onMessage(string.format("Buy %s?", def.Name))
		end
	end

	local promptOk, promptErr = pcall(function()
		MarketplaceService:PromptProductPurchase(player, def.ProductId)
	end)
	if not promptOk then
		warn(string.format("[PotionPurchase] Prompt failed for %d: %s", def.ProductId, tostring(promptErr)))
		if onMessage then
			onMessage("Could not open Robux purchase. Try again in the live game.")
		end
		return false
	end

	return true
end

MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, wasPurchased)
	if player ~= Players.LocalPlayer then
		return
	end
	local onMessage = lastOnMessage
	local potionId = lastPotionId
	lastOnMessage = nil
	lastPotionId = nil
	if not onMessage then
		return
	end

	local def = PotionConfig.GetByProductId(productId)
	if potionId and not def then
		def = PotionConfig.Get(potionId)
	end
	if wasPurchased == true then
		onMessage(string.format("Bought %s!", if def then def.Name else "potion"))
	else
		onMessage("Purchase cancelled.")
	end
end)

return PotionPurchase
