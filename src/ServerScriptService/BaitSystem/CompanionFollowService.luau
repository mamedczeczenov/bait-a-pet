--!strict

--[[
	Spawns real 3D companion pets that follow the player and face their avatar (skin).
	Supports up to 2 followers (Map 2 unlock) on left/right offsets.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CompanionConfig = require(Modules:WaitForChild("CompanionConfig"))
local PetConfig = require(Modules:WaitForChild("PetConfig"))
local PetRarityFx = require(Modules:WaitForChild("PetRarityFx"))

local CompanionFollowService = {}

type FollowEntry = {
	Model: Model,
	Offset: Vector3,
}

local entriesByPlayer: { [Player]: { FollowEntry } } = {}
local folder: Folder? = nil

local TARGET_HEIGHT = 2.2

local function getFolder(): Folder
	local existing = folder
	if existing and existing.Parent then
		return existing
	end
	local created = Workspace:FindFirstChild("Companions")
	if created and created:IsA("Folder") then
		folder = created
		return created
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = "Companions"
	newFolder.Parent = Workspace
	folder = newFolder
	return newFolder
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

local function prepareFollowParts(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Humanoid") then
			descendant:Destroy()
		elseif descendant:IsA("Animator") or descendant:IsA("AnimationController") then
			descendant:Destroy()
		elseif descendant:IsA("BaseScript") or descendant:IsA("LocalScript") then
			descendant.Disabled = true
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			descendant.CastShadow = true
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

	local height = math.max(size.Y, size.X * 0.85, size.Z * 0.85, 0.05)
	local ratio = math.clamp(targetHeight / height, 0.12, 1.4)
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

local function getLookTarget(character: Model, root: BasePart): Vector3
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	return root.Position + Vector3.new(0, 1.4, 0)
end

local function offsetForIndex(index: number): Vector3
	if index <= 1 then
		return CompanionConfig.FollowOffset
	end
	return CompanionConfig.FollowOffset2 or Vector3.new(-CompanionConfig.FollowOffset.X, CompanionConfig.FollowOffset.Y, CompanionConfig.FollowOffset.Z)
end

function CompanionFollowService.Despawn(player: Player)
	local entries = entriesByPlayer[player]
	if entries then
		for _, entry in ipairs(entries) do
			if entry.Model.Parent then
				entry.Model:Destroy()
			end
		end
	end
	entriesByPlayer[player] = nil
end

local function spawnOne(player: Player, petName: string, index: number, root: BasePart, character: Model): FollowEntry?
	local petsFolder = ServerStorage:FindFirstChild("Pets")
	if not petsFolder or not petsFolder:IsA("Folder") then
		warn("[CompanionFollowService] Missing ServerStorage.Pets")
		return nil
	end

	local template = petsFolder:FindFirstChild(petName)
	if not template or not template:IsA("Model") then
		warn("[CompanionFollowService] Missing pet model:", petName)
		return nil
	end

	local rarity = "Common"
	local rarityValue = template:FindFirstChild("Rarity")
	if rarityValue and rarityValue:IsA("StringValue") and rarityValue.Value ~= "" then
		rarity = rarityValue.Value
	else
		local definition = PetConfig.GetByName(petName)
		if definition then
			rarity = definition.Rarity
		end
	end

	local pet = template:Clone()
	pet.Name = CompanionConfig.ModelName .. "_" .. tostring(index)
	local primary = ensurePrimaryPart(pet)
	if not primary then
		pet:Destroy()
		return nil
	end

	pet:SetAttribute("OwnerUserId", player.UserId)
	pet:SetAttribute("PetName", petName)
	pet:SetAttribute("Rarity", rarity)
	pet:SetAttribute("IsCompanion3D", true)
	pet:SetAttribute("FollowIndex", index)

	pet.Parent = getFolder()
	scaleModelUniform(pet, TARGET_HEIGHT)
	prepareFollowParts(pet)

	primary = pet.PrimaryPart or primary
	pet.PrimaryPart = primary

	local offset = offsetForIndex(index)
	local spawnAt = (root.CFrame * CFrame.new(offset.X, offset.Y, offset.Z)).Position
	local lookAt = getLookTarget(character, root)
	pet:PivotTo(CFrame.lookAt(spawnAt, lookAt))

	PetRarityFx.ApplyWorldFx(pet, rarity)
	return {
		Model = pet,
		Offset = offset,
	}
end

function CompanionFollowService.Spawn(player: Player, petName: string): boolean
	return CompanionFollowService.SpawnAll(player, { petName })
end

function CompanionFollowService.SpawnAll(player: Player, petNames: { string }): boolean
	CompanionFollowService.Despawn(player)

	local cleaned: { string } = {}
	for _, name in ipairs(petNames) do
		if typeof(name) == "string" and name ~= "" then
			local already = false
			for _, existing in ipairs(cleaned) do
				if existing == name then
					already = true
					break
				end
			end
			if not already then
				table.insert(cleaned, name)
			end
		end
		if #cleaned >= 2 then
			break
		end
	end

	if #cleaned == 0 then
		return false
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	local entries: { FollowEntry } = {}
	for index, petName in ipairs(cleaned) do
		local entry = spawnOne(player, petName, index, root, character :: Model)
		if entry then
			table.insert(entries, entry)
		end
	end
	entriesByPlayer[player] = entries
	return #entries > 0
end

function CompanionFollowService.Refresh(player: Player, petName: string?)
	if typeof(petName) ~= "string" or petName == "" then
		CompanionFollowService.Despawn(player)
		return
	end
	CompanionFollowService.Spawn(player, petName)
end

function CompanionFollowService.RefreshAll(player: Player, petNames: { string }?)
	if typeof(petNames) ~= "table" or #petNames == 0 then
		CompanionFollowService.Despawn(player)
		return
	end
	CompanionFollowService.SpawnAll(player, petNames)
end

RunService.Heartbeat:Connect(function(dt)
	local lerpAlpha = math.clamp(CompanionConfig.FollowLerp * dt, 0, 1)

	for player, entries in pairs(entriesByPlayer) do
		if not player.Parent then
			CompanionFollowService.Despawn(player)
			continue
		end

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			continue
		end

		local lookAt = getLookTarget(character :: Model, root)
		local kept: { FollowEntry } = {}
		for _, entry in ipairs(entries) do
			local model = entry.Model
			if not model.Parent then
				continue
			end

			local targetPos = (root.CFrame * CFrame.new(entry.Offset.X, entry.Offset.Y, entry.Offset.Z)).Position
			local current = model:GetPivot()
			local nextPos = current.Position:Lerp(targetPos, lerpAlpha)
			local desired = CFrame.lookAt(nextPos, Vector3.new(lookAt.X, nextPos.Y, lookAt.Z))
			local nextCf = current:Lerp(desired, math.clamp(lerpAlpha * 1.35, 0, 1))
			local facing = CFrame.lookAt(nextCf.Position, lookAt)
			model:PivotTo(facing)
			table.insert(kept, entry)
		end
		entriesByPlayer[player] = kept
	end
end)

Players.PlayerRemoving:Connect(function(player)
	CompanionFollowService.Despawn(player)
end)

return CompanionFollowService
