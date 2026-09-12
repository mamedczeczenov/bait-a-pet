--!strict

local InventoryService = {}

local inventories: { [Player]: { string } } = {}
local petTags: { [Player]: { string } } = {}

local function getOrCreatePetFolder(player: Player): Folder
	local existingFolder = player:FindFirstChild("Pets")
	if existingFolder and existingFolder:IsA("Folder") then
		return existingFolder
	end

	local petFolder = Instance.new("Folder")
	petFolder.Name = "Pets"
	petFolder.Parent = player

	return petFolder
end

local function normalizeTag(tag: string?): string
	if typeof(tag) == "string" and tag ~= "" then
		return tag
	end
	return ""
end

local function rebuildPetFolder(player: Player)
	local inventory = inventories[player]
	local tags = petTags[player]
	if not inventory or not tags then
		return
	end

	local petFolder = getOrCreatePetFolder(player)
	for _, child in ipairs(petFolder:GetChildren()) do
		if child:IsA("StringValue") then
			child:Destroy()
		end
	end

	for index, petName in ipairs(inventory) do
		local petValue = Instance.new("StringValue")
		petValue.Name = petName
		petValue.Value = petName
		local tag = tags[index] or ""
		if tag ~= "" then
			petValue:SetAttribute("EventTag", tag)
		end
		petValue.Parent = petFolder
	end
end

function InventoryService.InitPlayer(player: Player, startingPets: { string }?, startingTags: { string }?)
	inventories[player] = {}
	petTags[player] = {}
	local petFolder = getOrCreatePetFolder(player)

	for _, child in ipairs(petFolder:GetChildren()) do
		if child:IsA("StringValue") then
			child:Destroy()
		end
	end

	if startingPets then
		for index, petName in ipairs(startingPets) do
			local tag = if startingTags then startingTags[index] else nil
			InventoryService.AddPet(player, petName, tag)
		end
	end
end

function InventoryService.AddPet(player: Player, petName: string, eventTag: string?): number
	local inventory = inventories[player]
	if not inventory then
		inventory = {}
		inventories[player] = inventory
	end

	local tags = petTags[player]
	if not tags then
		tags = {}
		petTags[player] = tags
	end

	local tag = normalizeTag(eventTag)
	table.insert(inventory, petName)
	table.insert(tags, tag)

	local petFolder = getOrCreatePetFolder(player)
	local petValue = Instance.new("StringValue")
	petValue.Name = petName
	petValue.Value = petName
	if tag ~= "" then
		petValue:SetAttribute("EventTag", tag)
	end
	petValue.Parent = petFolder

	return #inventory
end

function InventoryService.RemovePetAt(player: Player, index: number): (string?, string?)
	local inventory = inventories[player]
	local tags = petTags[player]
	if not inventory or not tags then
		return nil, nil
	end

	if index < 1 or index > #inventory then
		return nil, nil
	end

	local petName = table.remove(inventory, index)
	local tag = table.remove(tags, index) or ""
	if not petName then
		return nil, nil
	end

	rebuildPetFolder(player)
	return petName, if tag ~= "" then tag else nil
end

--[[
	Remove multiple pets in one pass (highest index first) and rebuild the
	replicated Pets folder once. Returns entries in the same order as `indices`
	were processed (descending index order).
]]
function InventoryService.RemovePetsAt(player: Player, indices: { number }): { { Name: string, EventTag: string?, Index: number } }
	local inventory = inventories[player]
	local tags = petTags[player]
	local removed: { { Name: string, EventTag: string?, Index: number } } = {}
	if not inventory or not tags or #indices == 0 then
		return removed
	end

	local ordered = table.clone(indices)
	table.sort(ordered, function(a, b)
		return a > b
	end)

	local seen: { [number]: boolean } = {}
	for _, index in ipairs(ordered) do
		if typeof(index) == "number" and not seen[index] then
			seen[index] = true
			local floored = math.floor(index)
			if floored >= 1 and floored <= #inventory then
				local petName = table.remove(inventory, floored)
				local tag = table.remove(tags, floored) or ""
				if petName then
					table.insert(removed, {
						Name = petName,
						EventTag = if tag ~= "" then tag else nil,
						Index = floored,
					})
				end
			end
		end
	end

	if #removed > 0 then
		rebuildPetFolder(player)
	end
	return removed
end

function InventoryService.ClearPets(player: Player): { string }
	local inventory = inventories[player]
	if not inventory then
		return {}
	end

	local removedPets = table.clone(inventory)
	table.clear(inventory)
	local tags = petTags[player]
	if tags then
		table.clear(tags)
	end

	local petFolder = getOrCreatePetFolder(player)
	for _, child in ipairs(petFolder:GetChildren()) do
		if child:IsA("StringValue") then
			child:Destroy()
		end
	end

	return removedPets
end

function InventoryService.HasSession(player: Player): boolean
	return inventories[player] ~= nil
end

function InventoryService.GetPets(player: Player): { string }
	local inventory = inventories[player]
	if not inventory then
		return {}
	end

	return table.clone(inventory)
end

function InventoryService.GetPetTags(player: Player): { string }
	local tags = petTags[player]
	if not tags then
		return {}
	end
	return table.clone(tags)
end

function InventoryService.GetPetTag(player: Player, index: number): string?
	local tags = petTags[player]
	if not tags then
		return nil
	end
	local tag = tags[index]
	if typeof(tag) == "string" and tag ~= "" then
		return tag
	end
	return nil
end

function InventoryService.GetCount(player: Player): number
	local inventory = inventories[player]
	if not inventory then
		return 0
	end

	return #inventory
end

function InventoryService.CleanupPlayer(player: Player)
	inventories[player] = nil
	petTags[player] = nil
end

return InventoryService
