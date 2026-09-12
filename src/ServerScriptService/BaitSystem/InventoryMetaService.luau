--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PetConfig = require(Modules:WaitForChild("PetConfig"))

local InventoryMetaService = {}

local MAX_HOTBAR = 9

local function ensureFolder(player: Player, name: string): Folder
	local existing = player:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = player
	return folder
end

local function syncIndexBoolFolder(player: Player, folderName: string, indices: { number })
	local folder = ensureFolder(player, folderName)
	local keep: { [string]: boolean } = {}
	for _, index in ipairs(indices) do
		local key = tostring(index)
		keep[key] = true
		local existing = folder:FindFirstChild(key)
		if not existing then
			local marker = Instance.new("BoolValue")
			marker.Name = key
			marker.Value = true
			marker.Parent = folder
		end
	end
	for _, child in ipairs(folder:GetChildren()) do
		if not keep[child.Name] then
			child:Destroy()
		end
	end
end

local function syncHotbarPinsFolder(player: Player, pins: { number })
	local folder = ensureFolder(player, "HotbarPins")
	local keep: { [string]: boolean } = {}
	for slot, invIndex in ipairs(pins) do
		if invIndex > 0 then
			local key = tostring(slot)
			keep[key] = true
			local existing = folder:FindFirstChild(key)
			if existing and existing:IsA("IntValue") then
				existing.Value = invIndex
			else
				if existing then
					existing:Destroy()
				end
				local value = Instance.new("IntValue")
				value.Name = key
				value.Value = invIndex
				value.Parent = folder
			end
		end
	end
	for _, child in ipairs(folder:GetChildren()) do
		if not keep[child.Name] then
			child:Destroy()
		end
	end
end

function InventoryMetaService.SanitizeLockedIndices(raw: any, petCount: number): { number }
	local locked = {}
	local seen: { [number]: boolean } = {}
	if typeof(raw) ~= "table" then
		return locked
	end
	for _, value in ipairs(raw) do
		if typeof(value) == "number" then
			local index = math.floor(value)
			if index >= 1 and index <= petCount and not seen[index] then
				seen[index] = true
				table.insert(locked, index)
			end
		end
	end
	table.sort(locked)
	return locked
end

function InventoryMetaService.SanitizeHotbarPins(raw: any, petCount: number): { number }
	local pins = table.create(MAX_HOTBAR, 0)
	if typeof(raw) ~= "table" then
		return pins
	end

	local usedInv: { [number]: boolean } = {}
	for slot = 1, MAX_HOTBAR do
		local value = raw[slot]
		if typeof(value) == "number" then
			local invIndex = math.floor(value)
			if invIndex >= 1 and invIndex <= petCount and not usedInv[invIndex] then
				pins[slot] = invIndex
				usedInv[invIndex] = true
			end
		end
	end
	return pins
end

function InventoryMetaService.SyncPlayer(player: Player, lockedIndices: { number }, hotbarPins: { number })
	syncIndexBoolFolder(player, "LockedPets", lockedIndices)
	syncHotbarPinsFolder(player, hotbarPins)
end

function InventoryMetaService.IsLocked(lockedIndices: { number }, index: number): boolean
	for _, locked in ipairs(lockedIndices) do
		if locked == index then
			return true
		end
	end
	return false
end

function InventoryMetaService.ToggleLock(lockedIndices: { number }, index: number, petCount: number): { number }
	if index < 1 or index > petCount then
		return lockedIndices
	end

	local nextLocked = {}
	local removed = false
	for _, locked in ipairs(lockedIndices) do
		if locked == index then
			removed = true
		else
			table.insert(nextLocked, locked)
		end
	end
	if not removed then
		table.insert(nextLocked, index)
		table.sort(nextLocked)
	end
	return nextLocked
end

function InventoryMetaService.RemapAfterRemove(lockedIndices: { number }, hotbarPins: { number }, removedIndex: number): ({ number }, { number })
	local nextLocked = {}
	for _, locked in ipairs(lockedIndices) do
		if locked < removedIndex then
			table.insert(nextLocked, locked)
		elseif locked > removedIndex then
			table.insert(nextLocked, locked - 1)
		end
	end

	local nextPins = table.create(MAX_HOTBAR, 0)
	for slot = 1, MAX_HOTBAR do
		local invIndex = hotbarPins[slot] or 0
		if invIndex == removedIndex then
			nextPins[slot] = 0
		elseif invIndex > removedIndex then
			nextPins[slot] = invIndex - 1
		else
			nextPins[slot] = invIndex
		end
	end

	return nextLocked, nextPins
end

-- Apply several removals; process highest index first so remaps stay consistent.
function InventoryMetaService.RemapAfterRemoves(lockedIndices: { number }, hotbarPins: { number }, removedIndices: { number }): ({ number }, { number })
	if #removedIndices == 0 then
		return lockedIndices, hotbarPins
	end

	local ordered = table.clone(removedIndices)
	table.sort(ordered, function(a, b)
		return a > b
	end)

	local nextLocked = lockedIndices
	local nextPins = hotbarPins
	for _, removedIndex in ipairs(ordered) do
		nextLocked, nextPins = InventoryMetaService.RemapAfterRemove(nextLocked, nextPins, removedIndex)
	end
	return nextLocked, nextPins
end

function InventoryMetaService.ClearAll(): ({ number }, { number })
	return {}, table.create(MAX_HOTBAR, 0)
end

function InventoryMetaService.FindPinSlot(hotbarPins: { number }, inventoryIndex: number): number?
	for slot = 1, MAX_HOTBAR do
		if (hotbarPins[slot] or 0) == inventoryIndex then
			return slot
		end
	end
	return nil
end

function InventoryMetaService.TogglePin(hotbarPins: { number }, inventoryIndex: number, petCount: number): { number }
	if inventoryIndex < 1 or inventoryIndex > petCount then
		return hotbarPins
	end

	local nextPins = table.clone(hotbarPins)
	while #nextPins < MAX_HOTBAR do
		table.insert(nextPins, 0)
	end

	local existingSlot = InventoryMetaService.FindPinSlot(nextPins, inventoryIndex)
	if existingSlot then
		nextPins[existingSlot] = 0
		return nextPins
	end

	for slot = 1, MAX_HOTBAR do
		if (nextPins[slot] or 0) == 0 then
			nextPins[slot] = inventoryIndex
			return nextPins
		end
	end

	-- Hotbar full: replace last slot.
	nextPins[MAX_HOTBAR] = inventoryIndex
	return nextPins
end

function InventoryMetaService.HasAnyPin(hotbarPins: { number }): boolean
	for slot = 1, MAX_HOTBAR do
		if (hotbarPins[slot] or 0) > 0 then
			return true
		end
	end
	return false
end

function InventoryMetaService.ResolveHotbarInventoryIndex(hotbarPins: { number }, hotbarSlot: number, petCount: number): number?
	if hotbarSlot < 1 or hotbarSlot > MAX_HOTBAR then
		return nil
	end

	if InventoryMetaService.HasAnyPin(hotbarPins) then
		local invIndex = hotbarPins[hotbarSlot] or 0
		if invIndex >= 1 and invIndex <= petCount then
			return invIndex
		end
		return nil
	end

	if hotbarSlot <= petCount then
		return hotbarSlot
	end
	return nil
end

function InventoryMetaService.RarityAtOrBelow(rarity: string, maxRarity: string): boolean
	local rarityIndex = table.find(PetConfig.RarityOrder, rarity)
	local maxIndex = table.find(PetConfig.RarityOrder, maxRarity)
	if typeof(rarityIndex) ~= "number" or typeof(maxIndex) ~= "number" then
		return rarity == maxRarity
	end
	return rarityIndex <= maxIndex
end

function InventoryMetaService.GetMaxHotbarSlots(): number
	return MAX_HOTBAR
end

return InventoryMetaService
