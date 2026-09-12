--!strict

--[[
	Held pets are parented under Workspace.HeldPets (NOT the character).
	Parenting skinned pet models into the avatar (Motor6D/Bones/Humanoid leftovers)
	breaks Humanoid walking — especially with 2 pets. Companions already use this
	pattern successfully.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PetConfig = require(Modules:WaitForChild("PetConfig"))
local PetRarityFx = require(Modules:WaitForChild("PetRarityFx"))

local PetEquipService = {}

local MAX_HOTBAR_SLOTS = 9
local EQUIPPED_MODEL_PREFIX = "HeldPet_"
local LEGACY_EQUIPPED_MODEL_NAME = "HeldPet"
local HELD_FOLDER_NAME = "HeldPets"
local HELD_TARGET_HEIGHT = 1.45

export type EquippedPet = {
	Slot: number,
	PetName: string,
	EventTag: string?,
}

local equippedPets: { [Player]: { EquippedPet } } = {}
local heldModels: { [Player]: { Model } } = {}
local heldFolder: Folder? = nil

local function getHeldFolder(): Folder
	local existing = heldFolder
	if existing and existing.Parent then
		return existing
	end
	local found = Workspace:FindFirstChild(HELD_FOLDER_NAME)
	if found and found:IsA("Folder") then
		heldFolder = found
		return found
	end
	local created = Instance.new("Folder")
	created.Name = HELD_FOLDER_NAME
	created.Parent = Workspace
	heldFolder = created
	return created
end

local function getRightHand(character: Model): BasePart?
	local rightHand = character:FindFirstChild("RightHand")
	if rightHand and rightHand:IsA("BasePart") then
		return rightHand
	end

	local rightArm = character:FindFirstChild("Right Arm")
	if rightArm and rightArm:IsA("BasePart") then
		return rightArm
	end

	return nil
end

local function getLeftHand(character: Model): BasePart?
	local leftHand = character:FindFirstChild("LeftHand")
	if leftHand and leftHand:IsA("BasePart") then
		return leftHand
	end

	local leftArm = character:FindFirstChild("Left Arm")
	if leftArm and leftArm:IsA("BasePart") then
		return leftArm
	end

	return nil
end

local function resolveAttach(character: Model, equipIndex: number): (BasePart?, CFrame)
	local right = getRightHand(character)
	local left = getLeftHand(character)
	local upper = character:FindFirstChild("UpperTorso")
	local torso = if upper and upper:IsA("BasePart")
		then upper
		else character:FindFirstChild("Torso")
	local root = character:FindFirstChild("HumanoidRootPart")

	local handGrip = CFrame.new(0, -0.15, -0.85) * CFrame.Angles(0, math.rad(180), 0)

	if equipIndex == 1 then
		if right then
			return right, handGrip
		end
		if torso and torso:IsA("BasePart") then
			return torso, CFrame.new(1.1, 0.15, 0.35) * CFrame.Angles(0, math.rad(160), 0)
		end
	elseif equipIndex == 2 then
		if left then
			return left, handGrip
		end
		if torso and torso:IsA("BasePart") then
			return torso, CFrame.new(-1.15, 0.15, 0.35) * CFrame.Angles(0, math.rad(200), 0)
		end
		if right then
			return right, CFrame.new(0.7, -0.05, -0.7) * CFrame.Angles(0, math.rad(180), 0)
		end
	else
		-- Map 3 extra carry: sit on the back so both hands stay free.
		if torso and torso:IsA("BasePart") then
			return torso, CFrame.new(0, 0.45, 0.9) * CFrame.Angles(0, 0, 0)
		end
		if root and root:IsA("BasePart") then
			return root, CFrame.new(0, 1.1, 0.85) * CFrame.Angles(0, 0, 0)
		end
	end

	if right then
		return right, handGrip
	end
	if left then
		return left, handGrip
	end
	if torso and torso:IsA("BasePart") then
		return torso, CFrame.new(0, 0.25, -0.85) * CFrame.Angles(0, math.rad(180), 0)
	end
	if root and root:IsA("BasePart") then
		local side = if equipIndex == 1 then 1.2 else -1.2
		return root, CFrame.new(side, 0.4, -0.6) * CFrame.Angles(0, math.rad(180), 0)
	end
	return nil, CFrame.new()
end

local function clearLegacyCharacterModels(character: Model)
	for _, child in ipairs(character:GetChildren()) do
		if child.Name == LEGACY_EQUIPPED_MODEL_NAME
			or string.sub(child.Name, 1, #EQUIPPED_MODEL_PREFIX) == EQUIPPED_MODEL_PREFIX
		then
			child:Destroy()
		end
	end
end

local function destroyHeldModels(player: Player)
	local models = heldModels[player]
	if models then
		for _, model in ipairs(models) do
			if model.Parent then
				model:Destroy()
			end
		end
	end
	heldModels[player] = {}
end

local function ensurePrimaryPart(model: Model): BasePart?
	local primary = model.PrimaryPart
	if primary and primary:IsA("BasePart") then
		return primary
	end

	local best: BasePart? = nil
	local bestVolume = -1
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
			if volume > bestVolume then
				bestVolume = volume
				best = descendant
			end
		end
	end

	if best then
		model.PrimaryPart = best
	end
	return best
end

local function prepareHeldParts(model: Model)
	-- Same approach as companions: keep skinned joints, anchor everything,
	-- never put physics/Humanoid into the player character.
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Humanoid")
			or descendant:IsA("Animator")
			or descendant:IsA("AnimationController")
		then
			descendant:Destroy()
		elseif descendant:IsA("BaseScript") or descendant:IsA("LocalScript") then
			descendant.Disabled = true
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			descendant.CastShadow = false
		end
	end
end

local function scaleModelUniform(model: Model, targetHeight: number)
	local okBox, _cf, size = pcall(function()
		return model:GetBoundingBox()
	end)
	if not okBox or typeof(size) ~= "Vector3" then
		local okExtents, extents = pcall(function()
			return model:GetExtentsSize()
		end)
		if not okExtents or typeof(extents) ~= "Vector3" then
			return
		end
		size = extents
	end

	local height = math.max(size.Y, size.X, size.Z, 0.05)
	local ratio = math.clamp(targetHeight / height, 0.08, 0.7)
	local currentScale = 1
	local okScale, scaleValue = pcall(function()
		return model:GetScale()
	end)
	if okScale and typeof(scaleValue) == "number" then
		currentScale = scaleValue
	end

	local scaleOk = pcall(function()
		model:ScaleTo(currentScale * ratio)
	end)
	if scaleOk then
		return
	end

	local pivot = model:GetPivot()
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local relative = pivot:ToObjectSpace(descendant.CFrame)
			descendant.Size = descendant.Size * ratio
			descendant.CFrame = pivot * CFrame.new(relative.Position * ratio) * (relative - relative.Position)
		elseif descendant:IsA("DataModelMesh") then
			descendant.Scale = descendant.Scale * ratio
			descendant.Offset = descendant.Offset * ratio
		end
	end
end

local function createFallbackHeldModel(petName: string, rarity: string, equipIndex: number): Model
	local held = Instance.new("Model")
	held.Name = EQUIPPED_MODEL_PREFIX .. tostring(equipIndex)

	local part = Instance.new("Part")
	part.Name = "Root"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(1.1, 1.1, 1.1)
	part.Color = PetConfig.GetRarityColor(rarity)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.Parent = held
	held.PrimaryPart = part

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(80, 24)
	billboard.StudsOffset = Vector3.new(0, 1.1, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = petName
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	return held
end

local function createHeldModel(
	player: Player,
	petName: string,
	eventTag: string?,
	equipIndex: number
): Model?
	local definition = PetConfig.GetByName(petName)
	local rarity = if definition then definition.Rarity else "Common"

	local held: Model? = nil
	local petsFolder = ServerStorage:FindFirstChild("Pets")
	if petsFolder and petsFolder:IsA("Folder") then
		local template = petsFolder:FindFirstChild(petName)
		if template and template:IsA("Model") then
			held = template:Clone()
		end
	end

	if not held then
		held = createFallbackHeldModel(petName, rarity, equipIndex)
	else
		held.Name = EQUIPPED_MODEL_PREFIX .. tostring(equipIndex)
	end

	local primary = ensurePrimaryPart(held)
	if not primary then
		held:Destroy()
		warn(string.format("[PetEquip] No PrimaryPart for pet '%s'", petName))
		return nil
	end

	local rarityValue = held:FindFirstChild("Rarity")
	if rarityValue and rarityValue:IsA("StringValue") and rarityValue.Value ~= "" then
		rarity = rarityValue.Value
	end

	held:SetAttribute("OwnerUserId", player.UserId)
	held:SetAttribute("PetName", petName)
	held:SetAttribute("EquipIndex", equipIndex)
	held:SetAttribute("IsHeldPet", true)
	if typeof(eventTag) == "string" and eventTag ~= "" then
		held:SetAttribute("EventTag", eventTag)
	end

	held.Parent = getHeldFolder()
	scaleModelUniform(held, PetRarityFx.GetHeldHeight(rarity, HELD_TARGET_HEIGHT))
	prepareHeldParts(held)

	primary = held.PrimaryPart or primary
	held.PrimaryPart = primary

	PetRarityFx.ApplyWorldFx(held, rarity)
	PetRarityFx.ApplyEventFx(held, eventTag)

	return held
end

local function syncEquippedAttributes(player: Player)
	local list = equippedPets[player] or {}
	local slot1 = if list[1] then list[1].Slot else 0
	local slot2 = if list[2] then list[2].Slot else 0
	local slot3 = if list[3] then list[3].Slot else 0
	player:SetAttribute("EquippedPetSlot", slot1)
	player:SetAttribute("EquippedPetSlot2", slot2)
	player:SetAttribute("EquippedPetSlot3", slot3)
	player:SetAttribute("EquippedPetCount", #list)
	if #list == 0 then
		player:SetAttribute("EquippedPetSlots", "")
	else
		local pieces = {}
		for _, entry in ipairs(list) do
			table.insert(pieces, tostring(entry.Slot))
		end
		player:SetAttribute("EquippedPetSlots", table.concat(pieces, ","))
	end
end

local function snapHeldToHands(player: Player)
	local character = player.Character
	local models = heldModels[player]
	if not character or not models then
		return
	end

	for index, model in ipairs(models) do
		if not model.Parent then
			continue
		end
		local hand, localGrip = resolveAttach(character, index)
		if hand then
			model:PivotTo(hand.CFrame * localGrip)
		end
	end
end

local function rebuildVisuals(player: Player): boolean
	local character = player.Character
	if character then
		clearLegacyCharacterModels(character)
	end

	destroyHeldModels(player)

	local list = equippedPets[player] or {}
	if not character then
		syncEquippedAttributes(player)
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		syncEquippedAttributes(player)
		return false
	end

	local models: { Model } = {}
	for index, entry in ipairs(list) do
		local model = createHeldModel(player, entry.PetName, entry.EventTag, index)
		if model then
			table.insert(models, model)
		else
			warn(string.format(
				"[PetEquip] Visual create failed for %s slot=%d pet=%s (kept equipped)",
				player.Name,
				entry.Slot,
				entry.PetName
			))
		end
	end
	heldModels[player] = models
	snapHeldToHands(player)
	syncEquippedAttributes(player)
	return #list > 0
end

local function findEquippedIndex(list: { EquippedPet }, slot: number): number?
	for index, entry in ipairs(list) do
		if entry.Slot == slot then
			return index
		end
	end
	return nil
end

function PetEquipService.GetMaxSlots(): number
	return MAX_HOTBAR_SLOTS
end

function PetEquipService.GetMaxEquipped(player: Player): number
	local maxAttr = player:GetAttribute("MaxEquippedPets")
	if typeof(maxAttr) == "number" and maxAttr >= 1 then
		return math.clamp(math.floor(maxAttr), 1, 3)
	end
	if player:GetAttribute("Map3Unlocked") == true or player:GetAttribute("Map3Unlocked") == 1 then
		return 3
	end
	local unlockedAttr = player:GetAttribute("Map2Unlocked")
	if unlockedAttr == true or unlockedAttr == 1 then
		return 2
	end
	return 1
end

function PetEquipService.GetEquippedSlot(player: Player): number?
	local list = equippedPets[player]
	if list and list[1] then
		return list[1].Slot
	end
	return nil
end

function PetEquipService.GetEquippedSlots(player: Player): { number }
	local list = equippedPets[player] or {}
	local slots = table.create(#list)
	for _, entry in ipairs(list) do
		table.insert(slots, entry.Slot)
	end
	return slots
end

function PetEquipService.Unequip(player: Player)
	equippedPets[player] = {}
	destroyHeldModels(player)
	syncEquippedAttributes(player)

	local character = player.Character
	if character then
		clearLegacyCharacterModels(character)
	end
end

function PetEquipService.EquipSlot(
	player: Player,
	slot: number,
	petName: string,
	eventTag: string?,
	maxEquipped: number?
): boolean
	if slot < 1 or slot > MAX_HOTBAR_SLOTS then
		return false
	end

	local character = player.Character
	if not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	local maxCount = if typeof(maxEquipped) == "number" and maxEquipped > 0
		then math.floor(maxEquipped)
		else PetEquipService.GetMaxEquipped(player)
	maxCount = math.clamp(maxCount, 1, 3)

	local list = equippedPets[player]
	if not list then
		list = {}
		equippedPets[player] = list
	end

	local existingIndex = findEquippedIndex(list, slot)
	if existingIndex then
		table.remove(list, existingIndex)
		rebuildVisuals(player)
		return true
	end

	local entry: EquippedPet = {
		Slot = slot,
		PetName = petName,
		EventTag = eventTag,
	}

	if #list >= maxCount then
		if maxCount == 1 then
			list[1] = entry
		else
			table.remove(list, 1)
			table.insert(list, entry)
		end
	else
		table.insert(list, entry)
	end

	return rebuildVisuals(player)
end

function PetEquipService.RefreshEquipped(player: Player, petName: string?, eventTag: string?)
	local list = equippedPets[player]
	if not list or #list == 0 then
		return
	end

	if typeof(petName) ~= "string" then
		PetEquipService.Unequip(player)
		return
	end

	list[1].PetName = petName
	list[1].EventTag = eventTag
	rebuildVisuals(player)
end

function PetEquipService.RefreshAllEquipped(
	player: Player,
	resolvePet: (slot: number) -> (string?, string?)
)
	local list = equippedPets[player]
	if not list or #list == 0 then
		return
	end

	local nextList: { EquippedPet } = {}
	for _, entry in ipairs(list) do
		local petName, eventTag = resolvePet(entry.Slot)
		if typeof(petName) == "string" then
			table.insert(nextList, {
				Slot = entry.Slot,
				PetName = petName,
				EventTag = eventTag,
			})
		end
	end

	equippedPets[player] = nextList
	if #nextList == 0 then
		PetEquipService.Unequip(player)
		return
	end
	rebuildVisuals(player)
end

function PetEquipService.OnPetRemoved(player: Player, _removedIndex: number)
	-- Equipped value is a hotbar slot (stable). Inventory pin remap is handled elsewhere.
end

function PetEquipService.OnPetsCleared(player: Player)
	PetEquipService.Unequip(player)
end

function PetEquipService.CleanupPlayer(player: Player)
	destroyHeldModels(player)
	equippedPets[player] = nil
	heldModels[player] = nil
end

RunService.Heartbeat:Connect(function()
	for player, models in pairs(heldModels) do
		if not player.Parent then
			destroyHeldModels(player)
			heldModels[player] = nil
			continue
		end
		if #models == 0 then
			continue
		end

		local character = player.Character
		if not character then
			continue
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			continue
		end

		for index, model in ipairs(models) do
			if not model.Parent then
				continue
			end
			local hand, localGrip = resolveAttach(character, index)
			if hand then
				model:PivotTo(hand.CFrame * localGrip)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	PetEquipService.CleanupPlayer(player)
end)

return PetEquipService
