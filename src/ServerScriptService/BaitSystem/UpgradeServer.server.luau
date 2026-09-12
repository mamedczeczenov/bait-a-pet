--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlaceConfig = require(Modules:WaitForChild("PlaceConfig"))
local PotionConfig = require(Modules:WaitForChild("PotionConfig"))
local UpgradeConfig = require(Modules:WaitForChild("UpgradeConfig"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local PotionService = require(script.Parent:WaitForChild("PotionService"))
local TutorialService = require(script.Parent:WaitForChild("TutorialService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local openUpgradeRemote = remotes:WaitForChild("OpenUpgrade") :: RemoteEvent
local buyUpgradeRemote = remotes:WaitForChild("BuyUpgrade") :: RemoteEvent
local usePotionRemote = remotes:WaitForChild("UsePotion") :: RemoteEvent
local upgradeResultRemote = remotes:WaitForChild("UpgradeResult") :: RemoteEvent

local UPGRADE_STATION_TAG = "UpgradeStation"
local ACTION_COOLDOWN = 0.2
local lastActionAt: { [Player]: number } = {}
local boundPrompts: { [ProximityPrompt]: boolean } = {}

local function getCoins(player: Player): number
	local coins = player:GetAttribute("Coins")
	if typeof(coins) ~= "number" then
		return 0
	end
	return coins
end

local function setCoins(player: Player, amount: number)
	player:SetAttribute("Coins", math.max(0, math.floor(amount)))
end

local function getLevel(player: Player, upgradeId: string): number
	if upgradeId == "luck" then
		local level = player:GetAttribute("LuckLevel")
		return if typeof(level) == "number" then UpgradeConfig.ClampLevel(level) else 0
	end

	if upgradeId == "speed" then
		return PlayerDataService.GetSpeedLevel(player)
	end

	if upgradeId == "bag" then
		return PlayerDataService.GetBagLevel(player)
	end

	local level = player:GetAttribute("ValueLevel")
	return if typeof(level) == "number" then UpgradeConfig.ClampLevel(level) else 0
end

local function buildSnapshot(player: Player, message: string?)
	local luckLevel = getLevel(player, "luck")
	local valueLevel = getLevel(player, "value")
	local speedLevel = getLevel(player, "speed")
	local bagLevel = getLevel(player, "bag")
	local bagCapacity = UpgradeConfig.GetBagCapacity(bagLevel)
	local potions = PotionService.BuildSnapshot(player)

	return {
		Type = "Snapshot",
		Message = message,
		Coins = getCoins(player),
		LuckLevel = luckLevel,
		ValueLevel = valueLevel,
		SpeedLevel = speedLevel,
		BagLevel = bagLevel,
		BagCapacity = bagCapacity,
		PetCount = InventoryService.GetCount(player),
		LuckBonus = UpgradeConfig.GetLuckBonus(luckLevel),
		ValueMult = UpgradeConfig.GetValueMultiplier(valueLevel),
		CatchSpeedBonus = UpgradeConfig.GetCatchSpeedBonus(speedLevel),
		CatchCooldownReductionPercent = UpgradeConfig.GetCatchCooldownReductionPercent(speedLevel),
		LuckCost = UpgradeConfig.GetCost(luckLevel),
		ValueCost = UpgradeConfig.GetCost(valueLevel),
		SpeedCost = UpgradeConfig.GetCost(speedLevel),
		BagCost = UpgradeConfig.GetBagCost(bagLevel),
		MaxLevel = UpgradeConfig.MaxLevel,
		MaxBagLevel = UpgradeConfig.MaxBagLevel,
		PotionLuckCount = potions.PotionLuckCount,
		PotionSellCount = potions.PotionSellCount,
		PotionSuperLuckCount = potions.PotionSuperLuckCount,
		PotionSuperSellCount = potions.PotionSuperSellCount,
		PotionSuperBundleCount = potions.PotionSuperBundleCount,
		PotionLuckRemaining = potions.PotionLuckRemaining,
		PotionSellRemaining = potions.PotionSellRemaining,
		PotionLuckMult = potions.PotionLuckMult,
		PotionSellMult = potions.PotionSellMult,
		PotionLuckPrice = potions.PotionLuckPrice,
		PotionSellPrice = potions.PotionSellPrice,
		PotionSuperLuckRobux = potions.PotionSuperLuckRobux,
		PotionSuperSellRobux = potions.PotionSuperSellRobux,
		PotionSuperBundleRobux = potions.PotionSuperBundleRobux,
		PotionDurationSeconds = potions.PotionDurationSeconds,
	}
end

local function sendResult(player: Player, message: string?)
	upgradeResultRemote:FireClient(player, buildSnapshot(player, message))
end

local function sendError(player: Player, message: string)
	local snapshot = buildSnapshot(player, message)
	snapshot.Type = "Error"
	upgradeResultRemote:FireClient(player, snapshot)
end

local function canAct(player: Player): boolean
	if not PlayerDataService.IsLoaded(player) then
		return false
	end

	local now = os.clock()
	local last = lastActionAt[player] or 0
	if now - last < ACTION_COOLDOWN then
		return false
	end

	lastActionAt[player] = now
	return true
end

local function openPanel(player: Player)
	if not PlayerDataService.IsLoaded(player) then
		return
	end
	openUpgradeRemote:FireClient(player, buildSnapshot(player, nil))
	TutorialService.NotifyAction(player, "open_upgrade")
end

local function isUpgradePrompt(instance: Instance?): boolean
	local current = instance
	while current do
		if CollectionService:HasTag(current, UPGRADE_STATION_TAG) then
			return true
		end

		if current:GetAttribute("IsUpgradeStation") == true then
			return true
		end

		local lowerName = string.lower(current.Name)
		if lowerName == "upgrade" or lowerName == "upgradeinteraction" then
			return true
		end

		if current:IsA("ProximityPrompt") then
			local action = string.lower(current.ActionText)
			local objectText = string.lower(current.ObjectText)
			if string.find(action, "upgrade", 1, true) or objectText == "upgrades" or objectText == "upgrade" then
				return true
			end
		end

		current = current.Parent
	end

	return false
end

local function applyUpgradeToLevel(player: Player, upgradeId: string, nextLevel: number): string
	if upgradeId == "luck" then
		PlayerDataService.ApplyUpgradeLevels(player, nextLevel, getLevel(player, "value"))
		return string.format("Luck upgraded to level %d (%.2fx).", nextLevel, UpgradeConfig.GetLuckBonus(nextLevel))
	elseif upgradeId == "value" then
		PlayerDataService.ApplyUpgradeLevels(player, getLevel(player, "luck"), nextLevel)
		local percent = math.floor((UpgradeConfig.GetValueMultiplier(nextLevel) - 1) * 100 + 0.5)
		return string.format("Value Multiplier upgraded to level %d (+%d%%).", nextLevel, percent)
	elseif upgradeId == "speed" then
		PlayerDataService.ApplySpeedLevel(player, nextLevel)
		return string.format(
			"Catch Speed upgraded to level %d (-%d%% cooldown).",
			nextLevel,
			UpgradeConfig.GetCatchCooldownReductionPercent(nextLevel)
		)
	end

	PlayerDataService.ApplyBagLevel(player, nextLevel)
	return string.format(
		"Bag upgraded to level %d (%d slots).",
		nextLevel,
		UpgradeConfig.GetBagCapacity(nextLevel)
	)
end

local function bindStation(station: Instance)
	if not station:IsA("BasePart") then
		return
	end

	local function bindPrompt(prompt: ProximityPrompt)
		if boundPrompts[prompt] then
			return
		end

		boundPrompts[prompt] = true
		prompt.ActionText = "Open Upgrades"
		prompt.ObjectText = "Upgrades"
		prompt:SetAttribute("IsUpgradeStation", true)
		prompt.Triggered:Connect(function(player)
			openPanel(player)
		end)
	end

	local directPrompt = station:FindFirstChildOfClass("ProximityPrompt")
	if directPrompt then
		bindPrompt(directPrompt)
	end

	for _, descendant in ipairs(station:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			bindPrompt(descendant)
		end
	end
end

buyUpgradeRemote.OnServerEvent:Connect(function(player, upgradeId)
	if not canAct(player) then
		return
	end

	if typeof(upgradeId) == "string" then
		local potionDef = PotionConfig.GetByShopId(upgradeId)
		if potionDef then
			if potionDef.Currency == "Robux" then
				sendError(player, "Buy this potion with Robux.")
				return
			end

			local coins = getCoins(player)
			if coins < potionDef.Price then
				sendError(player, "Not enough coins.")
				return
			end

			local added, addError = PotionService.AddOwned(player, potionDef.Id, 1)
			if not added then
				sendError(player, addError or "Could not buy potion.")
				return
			end

			setCoins(player, coins - potionDef.Price)
			PlayerDataService.MarkDirty(player)
			local owned = PotionService.GetOwned(player, potionDef.Id)
			sendResult(player, string.format("Bought %s (%d owned). Use it from your backpack or hotbar.", potionDef.Name, owned))
			return
		end
	end

	if typeof(upgradeId) ~= "string" or not UpgradeConfig.IsValidId(upgradeId) then
		sendError(player, "Invalid upgrade.")
		return
	end

	local level = getLevel(player, upgradeId)
	local cost = if upgradeId == "bag"
		then UpgradeConfig.GetBagCost(level)
		else UpgradeConfig.GetCost(level)
	if not cost then
		sendError(player, "Upgrade is already maxed.")
		return
	end

	local coins = getCoins(player)
	if coins < cost then
		sendError(player, "Not enough coins.")
		return
	end

	setCoins(player, coins - cost)
	local message = applyUpgradeToLevel(player, upgradeId, level + 1)
	PlayerDataService.MarkDirty(player)
	sendResult(player, message)
end)

usePotionRemote.OnServerEvent:Connect(function(player, potionId)
	if not canAct(player) then
		return
	end

	if typeof(potionId) ~= "string" or not PotionConfig.IsPotionId(potionId) then
		sendError(player, "Invalid potion.")
		return
	end

	if PlaceConfig.IsAfkPlace() then
		sendError(player, "Potions don't work in the AFK lobby.")
		return
	end

	local ok, message = PotionService.Use(player, potionId)
	if not ok then
		sendError(player, message or "Could not use potion.")
		return
	end

	sendResult(player, message)
end)

for _, station in ipairs(CollectionService:GetTagged(UPGRADE_STATION_TAG)) do
	bindStation(station)
end

CollectionService:GetInstanceAddedSignal(UPGRADE_STATION_TAG):Connect(bindStation)

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if isUpgradePrompt(prompt) then
		prompt.ActionText = "Open Upgrades"
		prompt.ObjectText = "Upgrades"
		openPanel(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastActionAt[player] = nil
end)

local PurchaseReceiptService = require(script.Parent:WaitForChild("PurchaseReceiptService"))

PurchaseReceiptService.BindPotionNotify(function(player: Player, message: string)
	sendResult(player, message)
end)

PurchaseReceiptService.BindUpgradeGrant(function(player: Player, upgradeId: string): (boolean, string?)
	if not PlayerDataService.IsLoaded(player) then
		return false, "Player data not loaded."
	end
	if not UpgradeConfig.IsValidId(upgradeId) then
		return false, "Invalid upgrade."
	end

	local maxLevel = UpgradeConfig.GetMaxLevelFor(upgradeId)
	local current = getLevel(player, upgradeId)
	if current >= maxLevel then
		sendResult(player, "Upgrade is already maxed.")
		return true, nil
	end

	local skip = UpgradeConfig.GetRobuxSkip(upgradeId)
	local label = if skip then skip.Name else upgradeId
	local message = applyUpgradeToLevel(player, upgradeId, maxLevel)
	PlayerDataService.MarkDirty(player)
	sendResult(player, string.format("%s — %s", label, message))
	return true, nil
end)
