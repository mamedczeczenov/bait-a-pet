--!strict

--[[
	Single MarketplaceService.ProcessReceipt owner.
	ShopServer / UpgradeServer / AdRewardServer bind grant callbacks so baits,
	upgrades, potions, and rewarded-video ads all settle through one handler.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local AdRewardConfig = require(Modules:WaitForChild("AdRewardConfig"))
local BaitConfig = require(Modules:WaitForChild("BaitConfig"))
local PotionConfig = require(Modules:WaitForChild("PotionConfig"))
local UpgradeConfig = require(Modules:WaitForChild("UpgradeConfig"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local PotionService = require(script.Parent:WaitForChild("PotionService"))

local PurchaseReceiptService = {}

type BaitGrant = (Player, string) -> (boolean, string?)
type UpgradeGrant = (Player, string) -> (boolean, string?)
type PotionNotify = (Player, string) -> ()
type AdRewardGrant = (Player) -> (boolean, string?)

local baitGrant: BaitGrant? = nil
local upgradeGrant: UpgradeGrant? = nil
local potionNotify: PotionNotify? = nil
local adRewardGrant: AdRewardGrant? = nil

function PurchaseReceiptService.BindBaitGrant(handler: BaitGrant)
	baitGrant = handler
end

function PurchaseReceiptService.BindUpgradeGrant(handler: UpgradeGrant)
	upgradeGrant = handler
end

function PurchaseReceiptService.BindPotionNotify(handler: PotionNotify)
	potionNotify = handler
end

function PurchaseReceiptService.BindAdRewardGrant(handler: AdRewardGrant)
	adRewardGrant = handler
end

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local productId = receiptInfo.ProductId
	local purchaseId = receiptInfo.PurchaseId

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not PlayerDataService.IsLoaded(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if typeof(purchaseId) == "string" and PlayerDataService.HasProcessedPurchase(player, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	if AdRewardConfig.IsProductId(productId) then
		if not adRewardGrant then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, err = adRewardGrant(player)
		if not ok then
			warn(string.format("[Receipt] Ad reward grant failed for %s: %s", player.Name, tostring(err)))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if typeof(purchaseId) == "string" then
			PlayerDataService.MarkProcessedPurchase(player, purchaseId)
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local potionDef = PotionConfig.GetByProductId(productId)
	if potionDef then
		local added, addError = PotionService.AddOwned(player, potionDef.Id, 1)
		if not added then
			warn(string.format("[Receipt] Potion grant failed for %s: %s", player.Name, tostring(addError)))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if typeof(purchaseId) == "string" then
			PlayerDataService.MarkProcessedPurchase(player, purchaseId)
		end
		local message = string.format("Bought %s (%d owned). Use it from your backpack or hotbar.", potionDef.Name, PotionService.GetOwned(player, potionDef.Id))
		if potionNotify then
			potionNotify(player, message)
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local baitDef = BaitConfig.GetByProductId(productId)
	if baitDef then
		if not baitGrant then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, err = baitGrant(player, baitDef.Id)
		if not ok then
			warn(string.format("[Receipt] Bait grant failed for %s: %s", player.Name, tostring(err)))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if typeof(purchaseId) == "string" then
			PlayerDataService.MarkProcessedPurchase(player, purchaseId)
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local skipDef = UpgradeConfig.GetByProductId(productId)
	if skipDef then
		if not upgradeGrant then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, err = upgradeGrant(player, skipDef.UpgradeId)
		if not ok then
			warn(string.format("[Receipt] Upgrade grant failed for %s: %s", player.Name, tostring(err)))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if typeof(purchaseId) == "string" then
			PlayerDataService.MarkProcessedPurchase(player, purchaseId)
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

return PurchaseReceiptService
