--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CompanionConfig = require(Modules:WaitForChild("CompanionConfig"))
local PetConfig = require(Modules:WaitForChild("PetConfig"))

local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local CompanionFollowService = require(script.Parent:WaitForChild("CompanionFollowService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local PetEquipService = require(script.Parent:WaitForChild("PetEquipService"))
local InventoryMetaService = require(script.Parent:WaitForChild("InventoryMetaService"))

export type FuseOption = {
	PetName: string,
	Rarity: string,
	Icon: string,
	Count: number,
	UnlockedCount: number,
	CanFuse: boolean,
	LuckMult: number,
	SellMult: number,
}

local CompanionService = {}

local function clampActiveNames(names: { string }, maxCount: number): { string }
	local cleaned: { string } = {}
	for _, name in ipairs(names) do
		if typeof(name) == "string" and name ~= "" and PetConfig.IsKnownPet(name) then
			local dup = false
			for _, existing in ipairs(cleaned) do
				if existing == name then
					dup = true
					break
				end
			end
			if not dup then
				table.insert(cleaned, name)
			end
		end
		if #cleaned >= maxCount then
			break
		end
	end
	return cleaned
end

local function computeBuffFromNames(names: { string }): (number, number, string)
	local luckMult = 1
	local sellMult = 1
	local rarity = ""
	for _, petName in ipairs(names) do
		local buff, resolvedRarity = CompanionConfig.GetBuffForPet(petName)
		if buff.LuckMult > luckMult then
			luckMult = buff.LuckMult
		end
		if buff.SellMult > sellMult then
			sellMult = buff.SellMult
		end
		if rarity == "" then
			rarity = resolvedRarity
		end
	end
	return luckMult, sellMult, rarity
end

local function syncCompanionAttributes(player: Player, names: { string })
	local luckMult, sellMult, rarity = computeBuffFromNames(names)
	local primary = names[1] or ""
	local secondary = names[2] or ""

	player:SetAttribute("CompanionPetName", primary)
	player:SetAttribute("CompanionPetName2", secondary)
	if #names == 0 then
		player:SetAttribute("CompanionPetNames", "")
	elseif #names == 1 then
		player:SetAttribute("CompanionPetNames", primary)
	else
		player:SetAttribute("CompanionPetNames", string.format("%s,%s", primary, secondary))
	end
	player:SetAttribute("CompanionWalkCount", #names)
	player:SetAttribute("CompanionWalkMax", CompanionService.GetMaxWalk(player))
	player:SetAttribute("CompanionRarity", rarity)
	player:SetAttribute("CompanionLuckMult", luckMult)
	player:SetAttribute("CompanionSellMult", sellMult)
end

local function writeActiveNames(player: Player, names: { string })
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end
	local maxCount = CompanionService.GetMaxWalk(player)
	local cleaned = clampActiveNames(names, maxCount)
	data.CompanionPetNames = cleaned
	data.CompanionPetName = cleaned[1] or ""
	syncCompanionAttributes(player, cleaned)
	PlayerDataService.MarkDirty(player)
end

function CompanionService.GetMaxWalk(player: Player): number
	if PlayerDataService.HasMap2Unlocked(player) then
		return CompanionConfig.MaxWalkMap2 or 2
	end
	return CompanionConfig.MaxWalkDefault or 1
end

function CompanionService.GetActiveNames(player: Player): { string }
	local data = PlayerDataService.GetData(player)
	if data and typeof(data.CompanionPetNames) == "table" and #data.CompanionPetNames > 0 then
		return clampActiveNames(data.CompanionPetNames, CompanionService.GetMaxWalk(player))
	end
	local primary = CompanionService.GetPetName(player)
	if primary ~= "" then
		return { primary }
	end
	return {}
end

function CompanionService.GetPetName(player: Player): string
	local data = PlayerDataService.GetData(player)
	if data then
		if typeof(data.CompanionPetNames) == "table" and typeof(data.CompanionPetNames[1]) == "string" then
			return data.CompanionPetNames[1]
		end
		if typeof(data.CompanionPetName) == "string" then
			return data.CompanionPetName
		end
	end
	local attr = player:GetAttribute("CompanionPetName")
	if typeof(attr) == "string" then
		return attr
	end
	return ""
end

function CompanionService.GetLuckMultiplier(player: Player): number
	local attr = player:GetAttribute("CompanionLuckMult")
	if typeof(attr) == "number" and attr > 0 then
		return attr
	end
	local luckMult = computeBuffFromNames(CompanionService.GetActiveNames(player))
	return luckMult
end

function CompanionService.GetSellMultiplier(player: Player): number
	local attr = player:GetAttribute("CompanionSellMult")
	if typeof(attr) == "number" and attr > 0 then
		return attr
	end
	local _, sellMult = computeBuffFromNames(CompanionService.GetActiveNames(player))
	return sellMult
end

function CompanionService.ApplyAttributes(player: Player)
	local names = CompanionService.GetActiveNames(player)
	syncCompanionAttributes(player, names)
end

function CompanionService.GetUnlocked(player: Player): { string }
	local data = PlayerDataService.GetData(player)
	if data and typeof(data.UnlockedCompanions) == "table" then
		return table.clone(data.UnlockedCompanions)
	end
	return {}
end

function CompanionService.IsUnlocked(player: Player, petName: string): boolean
	local data = PlayerDataService.GetData(player)
	if not data then
		return false
	end
	for _, name in ipairs(data.UnlockedCompanions) do
		if name == petName then
			return true
		end
	end
	return false
end

local function unlockCompanion(player: Player, petName: string)
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end
	for _, name in ipairs(data.UnlockedCompanions) do
		if name == petName then
			return
		end
	end
	table.insert(data.UnlockedCompanions, petName)
	local folder = player:FindFirstChild("UnlockedCompanions")
	if not folder or not folder:IsA("Folder") then
		if folder then
			folder:Destroy()
		end
		folder = Instance.new("Folder")
		folder.Name = "UnlockedCompanions"
		folder.Parent = player
	end
	if not folder:FindFirstChild(petName) then
		local marker = Instance.new("BoolValue")
		marker.Name = petName
		marker.Value = true
		marker.Parent = folder
	end
end

local function refreshFollowers(player: Player)
	local names = CompanionService.GetActiveNames(player)
	CompanionFollowService.RefreshAll(player, names)
end

function CompanionService.SetActive(player: Player, petName: string): (boolean, string)
	-- Toggle Walk: add / remove / replace depending on Map2 unlock slots.
	if typeof(petName) ~= "string" or petName == "" then
		return false, "Pick a companion."
	end
	if not PetConfig.IsKnownPet(petName) then
		return false, "Unknown pet."
	end
	if not CompanionService.IsUnlocked(player, petName) then
		return false, "Fuse that pet at the Maszyna do petów first."
	end

	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "Player data not loaded."
	end

	local maxWalk = CompanionService.GetMaxWalk(player)
	local current = CompanionService.GetActiveNames(player)
	local nextNames: { string } = table.clone(current)

	local existingIndex: number? = nil
	for index, name in ipairs(nextNames) do
		if name == petName then
			existingIndex = index
			break
		end
	end

	if existingIndex then
		table.remove(nextNames, existingIndex)
		writeActiveNames(player, nextNames)
		refreshFollowers(player)
		if #nextNames == 0 then
			return true, string.format("%s stopped walking with you.", petName)
		end
		return true, string.format(
			"Walking with %d/%d · %s",
			#nextNames,
			maxWalk,
			table.concat(nextNames, " + ")
		)
	end

	if #nextNames >= maxWalk then
		if maxWalk <= 1 then
			nextNames = { petName }
		else
			table.remove(nextNames, 1)
			table.insert(nextNames, petName)
		end
	else
		table.insert(nextNames, petName)
	end

	writeActiveNames(player, nextNames)
	local spawned = CompanionFollowService.SpawnAll(player, nextNames)
	local luckMult, sellMult = computeBuffFromNames(nextNames)
	local message = string.format(
		"Walking %d/%d: %s · luck %.2fx · sell %.2fx",
		#nextNames,
		maxWalk,
		table.concat(nextNames, " + "),
		luckMult,
		sellMult
	)
	if maxWalk < 2 then
		message ..= " (Unlock Map 2 for 2 followers.)"
	end
	if not spawned then
		message ..= " (Follower will appear when you spawn.)"
	end
	return true, message
end

function CompanionService.ListFuseOptions(player: Player): { FuseOption }
	local pets = InventoryService.GetPets(player)
	local counts: { [string]: number } = {}
	local unlockedCounts: { [string]: number } = {}

	for index, petName in ipairs(pets) do
		counts[petName] = (counts[petName] or 0) + 1
		if not PlayerDataService.IsPetLocked(player, index) then
			unlockedCounts[petName] = (unlockedCounts[petName] or 0) + 1
		end
	end

	local options: { FuseOption } = {}
	for petName, total in pairs(counts) do
		local unlocked = unlockedCounts[petName] or 0
		local definition = PetConfig.GetByName(petName)
		local rarity = if definition then definition.Rarity else "Common"
		local buff = CompanionConfig.GetBuff(rarity)
		table.insert(options, {
			PetName = petName,
			Rarity = rarity,
			Icon = if definition then definition.Icon else "🐾",
			Count = total,
			UnlockedCount = unlocked,
			CanFuse = unlocked >= CompanionConfig.FuseCount,
			LuckMult = buff.LuckMult,
			SellMult = buff.SellMult,
		})
	end

	table.sort(options, function(a, b)
		if a.CanFuse ~= b.CanFuse then
			return a.CanFuse
		end
		local ai = table.find(PetConfig.RarityOrder, a.Rarity) or 0
		local bi = table.find(PetConfig.RarityOrder, b.Rarity) or 0
		if ai ~= bi then
			return ai > bi
		end
		return a.PetName < b.PetName
	end)

	return options
end

local function removePetsWithMeta(player: Player, indices: { number }): number
	if #indices == 0 then
		return 0
	end

	local removed = InventoryService.RemovePetsAt(player, indices)
	if #removed == 0 then
		return 0
	end

	local removedIndices = table.create(#removed)
	for _, entry in ipairs(removed) do
		table.insert(removedIndices, entry.Index)
		PetEquipService.OnPetRemoved(player, entry.Index)
	end
	PlayerDataService.OnInventoryPetsRemoved(player, removedIndices)
	return #removed
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

function CompanionService.Fuse(player: Player, petName: string): (boolean, string)
	if typeof(petName) ~= "string" or petName == "" then
		return false, "Pick a pet to fuse."
	end
	if not PetConfig.IsKnownPet(petName) then
		return false, "Unknown pet."
	end

	local pets = InventoryService.GetPets(player)
	local indices: { number } = {}
	for index = #pets, 1, -1 do
		if pets[index] == petName and not PlayerDataService.IsPetLocked(player, index) then
			table.insert(indices, index)
			if #indices >= CompanionConfig.FuseCount then
				break
			end
		end
	end

	if #indices < CompanionConfig.FuseCount then
		return false, string.format("Need %d unlocked %s.", CompanionConfig.FuseCount, petName)
	end

	local consumed = removePetsWithMeta(player, indices)
	if consumed < CompanionConfig.FuseCount then
		return false, "Failed to consume pets."
	end
	refreshHeldPet(player)

	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "Player data not loaded."
	end

	unlockCompanion(player, petName)

	local maxWalk = CompanionService.GetMaxWalk(player)
	local nextNames = CompanionService.GetActiveNames(player)
	local already = false
	for _, name in ipairs(nextNames) do
		if name == petName then
			already = true
			break
		end
	end
	if not already then
		if #nextNames >= maxWalk then
			if maxWalk <= 1 then
				nextNames = { petName }
			else
				table.remove(nextNames, 1)
				table.insert(nextNames, petName)
			end
		else
			table.insert(nextNames, petName)
		end
	end
	writeActiveNames(player, nextNames)

	local spawned = CompanionFollowService.SpawnAll(player, nextNames)
	local buff, rarity = CompanionConfig.GetBuffForPet(petName)
	local message = string.format(
		"%s companion ready! +%.0f%% luck, +%.0f%% sell (%s).",
		petName,
		(buff.LuckMult - 1) * 100,
		(buff.SellMult - 1) * 100,
		rarity
	)
	if not spawned then
		message ..= " (Follower will appear when you spawn.)"
	end
	return true, message
end

function CompanionService.OnPlayerReady(player: Player)
	CompanionService.ApplyAttributes(player)
	local names = CompanionService.GetActiveNames(player)
	if #names > 0 then
		task.defer(function()
			if player.Parent then
				CompanionFollowService.RefreshAll(player, names)
			end
		end)
	end
end

function CompanionService.OnCharacterAdded(player: Player)
	local names = CompanionService.GetActiveNames(player)
	if #names == 0 then
		CompanionFollowService.Despawn(player)
		return
	end
	task.defer(function()
		if player.Parent and player.Character then
			CompanionFollowService.RefreshAll(player, names)
		end
	end)
end

function CompanionService.Cleanup(player: Player)
	CompanionFollowService.Despawn(player)
end

return CompanionService
