--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local BaitConfig = require(Modules:WaitForChild("BaitConfig"))
local NumberFormat = require(Modules:WaitForChild("NumberFormat"))
local PetConfig = require(Modules:WaitForChild("PetConfig"))
local ShopConfig = require(Modules:WaitForChild("ShopConfig"))

local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local InventoryMetaService = require(script.Parent:WaitForChild("InventoryMetaService"))
local PetCatalogService = require(script.Parent:WaitForChild("PetCatalogService"))
local PetEquipService = require(script.Parent:WaitForChild("PetEquipService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local TutorialService = require(script.Parent:WaitForChild("TutorialService"))
local GoalService = require(script.Parent:WaitForChild("GoalService"))
local EventService = require(script.Parent:WaitForChild("EventService"))
local CompanionService = require(script.Parent:WaitForChild("CompanionService"))
local PotionService = require(script.Parent:WaitForChild("PotionService"))

PetCatalogService.InitializeAsync()

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local openShopRemote = remotes:WaitForChild("OpenShop") :: RemoteEvent
local buyItemRemote = remotes:WaitForChild("BuyItem") :: RemoteEvent
local sellPetRemote = remotes:WaitForChild("SellPet") :: RemoteEvent
local sellAllPetsRemote = remotes:WaitForChild("SellAllPets") :: RemoteEvent
local sellBulkPetsRemote = remotes:WaitForChild("SellBulkPets") :: RemoteEvent
local togglePetLockRemote = remotes:WaitForChild("TogglePetLock") :: RemoteEvent
local toggleHotbarPinRemote = remotes:WaitForChild("ToggleHotbarPin") :: RemoteEvent
local shopResultRemote = remotes:WaitForChild("ShopResult") :: RemoteEvent

local SHOP_STATION_TAG = "BaitShopStation"
local lastActionAt: { [Player]: number } = {}
local boundPrompts: { [ProximityPrompt]: boolean } = {}
local boundDetectors: { [ClickDetector]: boolean } = {}
local ACTION_COOLDOWN = 0.2

local function getCoins(player: Player): number
	local coins = player:GetAttribute("Coins")
	if typeof(coins) ~= "number" then
		return 0
	end

	return coins
end

local function setCoins(player: Player, amount: number)
	player:SetAttribute("Coins", math.max(0, math.floor(amount)))
	PlayerDataService.MarkDirty(player)
end

local function getSellPayout(basePrice: number, player: Player, eventTag: string?): number
	local mult = PlayerDataService.GetValueMultiplier(player)
	local worldSell = EventService.GetSellMultiplier()
	local tagSell = EventService.GetTagSellMultiplier(eventTag)
	local companionSell = CompanionService.GetSellMultiplier(player)
	local potionSell = PotionService.GetSellMultiplier(player)
	return math.max(0, math.floor(basePrice * mult * worldSell * tagSell * companionSell * potionSell))
end

local function getActiveBaitPayload(player: Player)
	local baitId = PlayerDataService.GetActiveBaitId(player)
	local definition = BaitConfig.GetById(baitId)
	return {
		Id = baitId,
		Name = if definition then definition.Name else "Basic Bait",
		LuckMultiplier = if definition then definition.LuckMultiplier else 1,
		CatchSpeed = if definition then definition.CatchSpeed else 1,
		Icon = if definition then definition.Icon else "🪱",
	}
end

local function serializeShopItems(player: Player)
	local unlocked = PlayerDataService.GetUnlockedBaits(player)
	local unlockedSet: { [string]: boolean } = {}
	for _, baitId in ipairs(unlocked) do
		unlockedSet[baitId] = true
	end

	local items = {}

	for _, item in ipairs(ShopConfig.Items) do
		table.insert(items, {
			Id = item.Id,
			Name = item.Name,
			Kind = item.Kind,
			Price = item.Price,
			RobuxPrice = item.RobuxPrice,
			ProductId = item.ProductId,
			BaitId = item.BaitId,
			LuckMultiplier = item.LuckMultiplier,
			CatchSpeed = item.CatchSpeed,
			Icon = item.Icon,
			Description = item.Description,
			Owned = unlockedSet[item.BaitId] == true,
			Color = {
				R = item.Color.R,
				G = item.Color.G,
				B = item.Color.B,
			},
		})
	end

	return items
end

local function buildInventoryPayload(player: Player)
	local pets = InventoryService.GetPets(player)
	local tags = InventoryService.GetPetTags(player)
	local entries = {}
	local valueMult = PlayerDataService.GetValueMultiplier(player)
	local worldSell = EventService.GetSellMultiplier()
	local companionSell = CompanionService.GetSellMultiplier(player)
	local potionSell = PotionService.GetSellMultiplier(player)
	local locked = PlayerDataService.GetLockedPetIndices(player)
	local pins = PlayerDataService.GetHotbarPins(player)
	local lockedSet: { [number]: boolean } = {}
	for _, index in ipairs(locked) do
		lockedSet[index] = true
	end
	local pinSlotByIndex: { [number]: number } = {}
	for slot, invIndex in ipairs(pins) do
		if invIndex > 0 then
			pinSlotByIndex[invIndex] = slot
		end
	end

	for index, petName in ipairs(pets) do
		local definition = PetConfig.GetByName(petName)
		local basePrice = if definition then definition.SellPrice else 50
		local eventTag = tags[index]
		if typeof(eventTag) ~= "string" or eventTag == "" then
			eventTag = nil
		end
		local tagSell = EventService.GetTagSellMultiplier(eventTag)
		table.insert(entries, {
			Index = index,
			Name = petName,
			Rarity = if definition then definition.Rarity else "Unknown",
			OneIn = if definition then definition.OneIn else 0,
			SellPrice = math.max(0, math.floor(basePrice * valueMult * worldSell * tagSell * companionSell * potionSell)),
			Icon = if definition then definition.Icon else "🐾",
			Description = if definition then definition.Description else "Unknown pet.",
			Locked = lockedSet[index] == true,
			HotbarSlot = pinSlotByIndex[index],
			EventTag = eventTag,
		})
	end

	return entries
end

local function refreshHeldPet(player: Player)
	PetEquipService.RefreshAllEquipped(player, function(slot)
		local pets = InventoryService.GetPets(player)
		local pins = PlayerDataService.GetHotbarPins(player)
		local invIndex = InventoryMetaService.ResolveHotbarInventoryIndex(pins, slot, #pets)
		if not invIndex then
			return nil, nil
		end
		local petName = pets[invIndex]
		if typeof(petName) ~= "string" then
			return nil, nil
		end
		return petName, InventoryService.GetPetTag(player, invIndex)
	end)
end

local function removePetWithMeta(player: Player, index: number): (string?, string?)
	local petName, eventTag = InventoryService.RemovePetAt(player, index)
	if not petName then
		return nil, nil
	end
	PetEquipService.OnPetRemoved(player, index)
	PlayerDataService.OnInventoryPetRemoved(player, index)
	refreshHeldPet(player)
	return petName, eventTag
end

local function removePetsWithMeta(player: Player, indices: { number }): { { Name: string, EventTag: string?, Index: number } }
	if #indices == 0 then
		return {}
	end

	local removed = InventoryService.RemovePetsAt(player, indices)
	if #removed == 0 then
		return removed
	end

	local removedIndices = table.create(#removed)
	for _, entry in ipairs(removed) do
		table.insert(removedIndices, entry.Index)
		PetEquipService.OnPetRemoved(player, entry.Index)
	end
	PlayerDataService.OnInventoryPetsRemoved(player, removedIndices)
	refreshHeldPet(player)
	return removed
end

local function sendShopSnapshot(player: Player, message: string?, mode: string?)
	shopResultRemote:FireClient(player, {
		Type = "Snapshot",
		Mode = mode,
		Message = message,
		Coins = getCoins(player),
		ActiveBait = getActiveBaitPayload(player),
		UnlockedBaits = PlayerDataService.GetUnlockedBaits(player),
		Items = serializeShopItems(player),
		Pets = buildInventoryPayload(player),
	})
end

local function sendError(player: Player, message: string)
	shopResultRemote:FireClient(player, {
		Type = "Error",
		Message = message,
		Coins = getCoins(player),
		ActiveBait = getActiveBaitPayload(player),
		UnlockedBaits = PlayerDataService.GetUnlockedBaits(player),
		Items = serializeShopItems(player),
		Pets = buildInventoryPayload(player),
	})
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

local function openPanel(player: Player, mode: string)
	openShopRemote:FireClient(player, {
		Type = "Open",
		Mode = mode,
		Coins = getCoins(player),
		ActiveBait = getActiveBaitPayload(player),
		UnlockedBaits = PlayerDataService.GetUnlockedBaits(player),
		Items = serializeShopItems(player),
		Pets = buildInventoryPayload(player),
	})

	if mode == "Buy" then
		TutorialService.NotifyAction(player, "open_shop")
	elseif mode == "Sell" then
		TutorialService.NotifyAction(player, "open_sell")
	end
end

local function resolveModeFromInstance(instance: Instance?): string?
	local current = instance
	while current do
		local mode = current:GetAttribute("ShopMode")
		if typeof(mode) == "string" and (mode == "Buy" or mode == "Sell") then
			return mode
		end

		local lowerName = string.lower(current.Name)
		if lowerName == "shop" or lowerName == "buyinteraction" then
			return "Buy"
		end
		if lowerName == "sell" or lowerName == "sellinteraction" then
			return "Sell"
		end

		if current:IsA("ProximityPrompt") then
			local action = string.lower(current.ActionText)
			local objectText = string.lower(current.ObjectText)
			if string.find(action, "shop", 1, true) or string.find(action, "sklep", 1, true) or objectText == "shop" then
				return "Buy"
			end
			if string.find(action, "sell", 1, true) or string.find(action, "sprzed", 1, true) or objectText == "sell" then
				return "Sell"
			end
		end

		current = current.Parent
	end

	return nil
end

buyItemRemote.OnServerEvent:Connect(function(player, itemId)
	if not canAct(player) then
		return
	end

	if typeof(itemId) ~= "string" then
		sendError(player, "Invalid shop item.")
		return
	end

	local item = ShopConfig.GetItem(itemId)
	if not item then
		sendError(player, "That item does not exist.")
		return
	end

	if item.Kind ~= "BaitUnlock" then
		sendError(player, "Unsupported shop item.")
		return
	end

	-- Already owned: equip from shop instead of erroring.
	if PlayerDataService.HasBaitUnlocked(player, item.BaitId) then
		local ok, err = PlayerDataService.SetActiveBait(player, item.BaitId)
		if not ok then
			sendError(player, err or "Could not equip bait.")
			return
		end
		sendShopSnapshot(
			player,
			string.format("Equipped %s (%s luck).", item.Name, BaitConfig.FormatLuck(item.LuckMultiplier)),
			"Buy"
		)
		return
	end

	local coins = getCoins(player)
	if item.Price > 0 and coins < item.Price then
		sendError(player, "Not enough coins.")
		return
	end

	if item.Price > 0 then
		setCoins(player, coins - item.Price)
	end

	local unlocked = PlayerDataService.UnlockBait(player, item.BaitId)
	if not unlocked then
		if item.Price > 0 then
			setCoins(player, coins)
		end
		sendError(player, "Could not unlock bait.")
		return
	end

	PlayerDataService.SetActiveBait(player, item.BaitId)

	sendShopSnapshot(
		player,
		string.format(
			"Unlocked & equipped %s (unlimited, %s luck).",
			item.Name,
			BaitConfig.FormatLuck(item.LuckMultiplier)
		),
		"Buy"
	)
end)

sellPetRemote.OnServerEvent:Connect(function(player, petIndex)
	if not canAct(player) then
		return
	end

	if typeof(petIndex) ~= "number" then
		sendError(player, "Invalid pet selection.")
		return
	end

	local index = math.floor(petIndex)
	if PlayerDataService.IsPetLocked(player, index) then
		sendError(player, "That pet is locked. Unlock it before selling.")
		return
	end

	local petName, eventTag = removePetWithMeta(player, index)
	if not petName then
		sendError(player, "You don't own that pet.")
		return
	end

	local definition = PetConfig.GetByName(petName)
	local basePrice = if definition then definition.SellPrice else 50
	local sellPrice = getSellPayout(basePrice, player, eventTag)
	setCoins(player, getCoins(player) + sellPrice)
	GoalService.OnCoinsEarned(player, sellPrice)
	sendShopSnapshot(player, string.format("Sold %s for %s coins.", petName, NumberFormat.FormatCoins(sellPrice)), "Sell")
	TutorialService.NotifyAction(player, "sell_pet")
end)

local function sellMatchingUnlocked(player: Player, shouldSell: (string, number) -> boolean): (number, number)
	local pets = InventoryService.GetPets(player)
	local indicesToSell: { number } = {}
	local payoutByIndex: { [number]: number } = {}

	for index = #pets, 1, -1 do
		if not PlayerDataService.IsPetLocked(player, index) then
			local petName = pets[index]
			if shouldSell(petName, index) then
				local definition = PetConfig.GetByName(petName)
				local basePrice = if definition then definition.SellPrice else 50
				local eventTag = InventoryService.GetPetTag(player, index)
				payoutByIndex[index] = getSellPayout(basePrice, player, eventTag)
				table.insert(indicesToSell, index)
			end
		end
	end

	if #indicesToSell == 0 then
		return 0, 0
	end

	local removed = removePetsWithMeta(player, indicesToSell)
	local soldCount = 0
	local totalCoins = 0
	for _, entry in ipairs(removed) do
		totalCoins += payoutByIndex[entry.Index] or 0
		soldCount += 1
	end

	if totalCoins > 0 then
		setCoins(player, getCoins(player) + totalCoins)
		GoalService.OnCoinsEarned(player, totalCoins)
	end

	return soldCount, totalCoins
end

sellAllPetsRemote.OnServerEvent:Connect(function(player, confirmed)
	if not canAct(player) then
		return
	end
	if confirmed ~= true then
		sendError(player, "Confirm sell all first.")
		return
	end

	local soldCount, totalCoins = sellMatchingUnlocked(player, function()
		return true
	end)

	if soldCount == 0 then
		sendError(player, "No unlocked pets to sell.")
		return
	end

	sendShopSnapshot(
		player,
		string.format("Sold %d unlocked pets for %s coins.", soldCount, NumberFormat.FormatCoins(totalCoins)),
		"Sell"
	)
	TutorialService.NotifyAction(player, "sell_all")
end)

sellBulkPetsRemote.OnServerEvent:Connect(function(player, payload)
	if not canAct(player) then
		return
	end
	if typeof(payload) ~= "table" then
		sendError(player, "Invalid bulk sell request.")
		return
	end

	local mode = payload.Mode
	if mode == "Commons" then
		local soldCount, totalCoins = sellMatchingUnlocked(player, function(petName)
			local definition = PetConfig.GetByName(petName)
			local rarity = if definition then definition.Rarity else "Common"
			return rarity == "Common"
		end)
		if soldCount == 0 then
			sendError(player, "No unlocked Common pets to sell.")
			return
		end
		sendShopSnapshot(
			player,
			string.format("Sold %d Commons for %s coins.", soldCount, NumberFormat.FormatCoins(totalCoins)),
			"Sell"
		)
		TutorialService.NotifyAction(player, "sell_all")
		return
	end

	if mode == "BelowOrEqualRarity" then
		local maxRarity = payload.Rarity
		if typeof(maxRarity) ~= "string" or table.find(PetConfig.RarityOrder, maxRarity) == nil then
			sendError(player, "Invalid rarity filter.")
			return
		end
		local soldCount, totalCoins = sellMatchingUnlocked(player, function(petName)
			local definition = PetConfig.GetByName(petName)
			local rarity = if definition then definition.Rarity else "Common"
			return InventoryMetaService.RarityAtOrBelow(rarity, maxRarity)
		end)
		if soldCount == 0 then
			sendError(player, string.format("No unlocked pets at %s or below.", maxRarity))
			return
		end
		sendShopSnapshot(
			player,
			string.format("Sold %d pets (%s or below) for %s coins.", soldCount, maxRarity, NumberFormat.FormatCoins(totalCoins)),
			"Sell"
		)
		TutorialService.NotifyAction(player, "sell_all")
		return
	end

	sendError(player, "Unknown bulk sell mode.")
end)

togglePetLockRemote.OnServerEvent:Connect(function(player, petIndex)
	if not canAct(player) then
		return
	end
	if typeof(petIndex) ~= "number" then
		return
	end
	PlayerDataService.ToggleLockPet(player, math.floor(petIndex))
	sendShopSnapshot(player, nil, "Sell")
end)

toggleHotbarPinRemote.OnServerEvent:Connect(function(player, petIndex)
	if not canAct(player) then
		return
	end
	if typeof(petIndex) ~= "number" then
		return
	end
	PlayerDataService.ToggleHotbarPin(player, math.floor(petIndex))
	sendShopSnapshot(player, nil, nil)
end)

local function bindStation(station: Instance)
	if not station:IsA("BasePart") then
		return
	end

	local mode = resolveModeFromInstance(station)
	if not mode then
		return
	end

	local function bindPrompt(prompt: ProximityPrompt)
		if boundPrompts[prompt] then
			return
		end

		boundPrompts[prompt] = true
		prompt.ActionText = if mode == "Buy" then "Open Shop" else "Sell Pets"
		prompt.ObjectText = if mode == "Buy" then "Shop" else "Sell"
		prompt:SetAttribute("ShopMode", mode)
		prompt.Triggered:Connect(function(player)
			openPanel(player, mode)
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

	local detector = station:FindFirstChildOfClass("ClickDetector")
	if detector and not boundDetectors[detector] then
		boundDetectors[detector] = true
		detector.MouseClick:Connect(function(player)
			openPanel(player, mode)
		end)
	end
end

for _, station in ipairs(CollectionService:GetTagged(SHOP_STATION_TAG)) do
	bindStation(station)
end

CollectionService:GetInstanceAddedSignal(SHOP_STATION_TAG):Connect(bindStation)

-- Catch map prompts that already existed under shop/sell, including "Otwórz sklep".
ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	local mode = resolveModeFromInstance(prompt)
	if mode then
		-- Normalize leftover Polish labels if any still appear.
		if mode == "Buy" then
			prompt.ActionText = "Open Shop"
			prompt.ObjectText = "Shop"
		else
			prompt.ActionText = "Sell Pets"
			prompt.ObjectText = "Sell"
		end
		openPanel(player, mode)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastActionAt[player] = nil
end)

local PurchaseReceiptService = require(script.Parent:WaitForChild("PurchaseReceiptService"))
PurchaseReceiptService.BindBaitGrant(function(player: Player, baitId: string): (boolean, string?)
	if not PlayerDataService.IsLoaded(player) then
		return false, "Player data not loaded."
	end
	if not BaitConfig.IsValidId(baitId) then
		return false, "Unknown bait."
	end

	local alreadyOwned = PlayerDataService.HasBaitUnlocked(player, baitId)
	if not alreadyOwned then
		local unlocked = PlayerDataService.UnlockBait(player, baitId)
		if not unlocked then
			return false, "Could not unlock bait."
		end
	end

	PlayerDataService.SetActiveBait(player, baitId)
	local definition = BaitConfig.GetById(baitId)
	local name = if definition then definition.Name else baitId
	local luck = if definition then definition.LuckMultiplier else 1
	local prefix = if alreadyOwned then "Equipped" else "Unlocked & equipped"
	sendShopSnapshot(
		player,
		string.format("%s %s (unlimited, %s luck).", prefix, name, BaitConfig.FormatLuck(luck)),
		"Buy"
	)
	return true, nil
end)
