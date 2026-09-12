--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local InventoryMetaService = require(script.Parent:WaitForChild("InventoryMetaService"))
local PetEquipService = require(script.Parent:WaitForChild("PetEquipService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local equipPetRemote = remotes:WaitForChild("EquipPet") :: RemoteEvent
local petResultRemote = remotes:WaitForChild("PetResult") :: RemoteEvent

local lastEquipAt: { [Player]: number } = {}
local EQUIP_COOLDOWN = 0.15

local function resolvePetFromHotbarSlot(player: Player, slot: number): (string?, string?, number?)
	local pets = InventoryService.GetPets(player)
	local pins = PlayerDataService.GetHotbarPins(player)
	local invIndex = InventoryMetaService.ResolveHotbarInventoryIndex(pins, slot, #pets)
	if not invIndex then
		return nil, nil, nil
	end
	local petName = pets[invIndex]
	if typeof(petName) ~= "string" then
		return nil, nil, nil
	end
	return petName, InventoryService.GetPetTag(player, invIndex), invIndex
end

local function ensureHotbarSlotForInventory(player: Player, inventoryIndex: number): number?
	local pets = InventoryService.GetPets(player)
	if inventoryIndex < 1 or inventoryIndex > #pets then
		return nil
	end

	local pins = PlayerDataService.GetHotbarPins(player)
	local existing = InventoryMetaService.FindPinSlot(pins, inventoryIndex)
	if existing then
		return existing
	end

	-- No pins + inventory index fits hotbar: slot N == inventory index N.
	if not InventoryMetaService.HasAnyPin(pins) and inventoryIndex <= PetEquipService.GetMaxSlots() then
		return inventoryIndex
	end

	-- Always land on a real hotbar slot (1-9). Auto-pin when needed
	-- (inventory index > 9, or other pets already pinned).
	PlayerDataService.ToggleHotbarPin(player, inventoryIndex)
	pins = PlayerDataService.GetHotbarPins(player)
	return InventoryMetaService.FindPinSlot(pins, inventoryIndex)
end

local function rebuildEquipped(player: Player)
	PetEquipService.RefreshAllEquipped(player, function(slot)
		local petName, eventTag = resolvePetFromHotbarSlot(player, slot)
		return petName, eventTag
	end)
end

local function isSlotEquipped(player: Player, slot: number): boolean
	for _, equippedSlot in ipairs(PetEquipService.GetEquippedSlots(player)) do
		if equippedSlot == slot then
			return true
		end
	end
	return false
end

local function getMaxEquipped(player: Player): number
	return PlayerDataService.GetMaxEquippedPets(player)
end

local function equipHotbarSlot(player: Player, hotbarSlot: number)
	local petName, eventTag = resolvePetFromHotbarSlot(player, hotbarSlot)
	if typeof(petName) ~= "string" then
		petResultRemote:FireClient(player, {
			Type = "EquipHint",
			Message = "Pin this pet to the hotbar first, or use Carry in inventory.",
		})
		return
	end

	local maxEquipped = getMaxEquipped(player)
	local equippedBefore = PetEquipService.GetEquippedSlots(player)
	local togglingOff = isSlotEquipped(player, hotbarSlot)
	local wasFullSingle = (not togglingOff) and #equippedBefore >= 1 and maxEquipped < 2

	PetEquipService.EquipSlot(player, hotbarSlot, petName, eventTag, maxEquipped)
	local equippedAfter = PetEquipService.GetEquippedSlots(player)
	local slotsAttr = player:GetAttribute("EquippedPetSlots")

	print(string.format(
		"[PetEquip] %s slot=%d max=%d unlocked=%s before=%d after=%d slots=%s",
		player.Name,
		hotbarSlot,
		maxEquipped,
		tostring(PlayerDataService.HasMap2Unlocked(player)),
		#equippedBefore,
		#equippedAfter,
		tostring(slotsAttr)
	))

	if wasFullSingle then
		petResultRemote:FireClient(player, {
			Type = "EquipHint",
			Message = "Only 1 Carry slot — unlock Map 2 (or /map2unlock) for 2 pets in hands.",
		})
	else
		petResultRemote:FireClient(player, {
			Type = "EquipHint",
			Message = string.format(
				"Carry %d/%d in hands.",
				#equippedAfter,
				maxEquipped
			),
		})
	end
end

local function bindCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then
		return
	end

	task.defer(function()
		if player.Character ~= character then
			return
		end
		rebuildEquipped(player)
	end)

	humanoid.Died:Connect(function()
		local slots = PetEquipService.GetEquippedSlots(player)
		player:SetAttribute("EquippedPetSlot", slots[1] or 0)
		player:SetAttribute("EquippedPetSlot2", slots[2] or 0)
		player:SetAttribute("EquippedPetSlot3", slots[3] or 0)
		player:SetAttribute("EquippedPetCount", #slots)
	end)
end

equipPetRemote.OnServerEvent:Connect(function(player, payload)
	local now = os.clock()
	local lastAt = lastEquipAt[player] or 0
	if now - lastAt < EQUIP_COOLDOWN then
		return
	end
	lastEquipAt[player] = now

	if not PlayerDataService.IsLoaded(player) then
		return
	end

	local hotbarSlot: number? = nil

	if typeof(payload) == "number" then
		hotbarSlot = math.floor(payload)
	elseif typeof(payload) == "table" then
		local invIndex = payload.InventoryIndex
		if typeof(invIndex) == "number" then
			hotbarSlot = ensureHotbarSlotForInventory(player, math.floor(invIndex))
			if not hotbarSlot then
				petResultRemote:FireClient(player, {
					Type = "EquipHint",
					Message = "Could not hold that pet.",
				})
				return
			end
		elseif typeof(payload.HotbarSlot) == "number" then
			hotbarSlot = math.floor(payload.HotbarSlot)
		end
	end

	if typeof(hotbarSlot) ~= "number" then
		return
	end
	if hotbarSlot < 1 or hotbarSlot > PetEquipService.GetMaxSlots() then
		return
	end

	equipHotbarSlot(player, hotbarSlot)
end)

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("EquippedPetSlot", 0)
	player:SetAttribute("EquippedPetSlot2", 0)
	player:SetAttribute("EquippedPetCount", 0)
	player:SetAttribute("EquippedPetSlots", "")

	player.CharacterAdded:Connect(function(character)
		bindCharacter(player, character)
	end)

	if player.Character then
		bindCharacter(player, player.Character)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastEquipAt[player] = nil
	PetEquipService.CleanupPlayer(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	player:SetAttribute("EquippedPetSlot", player:GetAttribute("EquippedPetSlot") or 0)
	player:SetAttribute("EquippedPetSlot2", player:GetAttribute("EquippedPetSlot2") or 0)
	player:SetAttribute("EquippedPetCount", player:GetAttribute("EquippedPetCount") or 0)
	player.CharacterAdded:Connect(function(character)
		bindCharacter(player, character)
	end)
	if player.Character then
		bindCharacter(player, player.Character)
	end
end
