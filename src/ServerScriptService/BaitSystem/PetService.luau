--!strict

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local BaitConfig = require(Modules:WaitForChild("BaitConfig"))
local CatchFeelConfig = require(Modules:WaitForChild("CatchFeelConfig"))
local PetConfig = require(Modules:WaitForChild("PetConfig"))
local PetWorldDisplay = require(Modules:WaitForChild("PetWorldDisplay"))
local PityConfig = require(Modules:WaitForChild("PityConfig"))

local PetCatalogService = require(script.Parent:WaitForChild("PetCatalogService"))

type PetDefinition = {
	Name: string,
	Rarity: string,
	Weight: number,
	Color: Color3,
	SellPrice: number?,
	OneIn: number?,
	Icon: string?,
	Description: string?,
}

local PetService = {}

local function getPetDefinitionByName(petName: string): PetDefinition?
	PetCatalogService.Initialize()
	for _, pet in ipairs(PetConfig.Pets) do
		if pet.Name == petName then
			return pet
		end
	end

	return nil
end

local function getAdjustedWeight(baseWeight: number, rarityBias: number, luckMultiplier: number): number
	-- Compress OneIn span (Common vs Divine is ~1e14× raw) so luck can actually shift odds.
	local softPower = PetConfig.LuckSoftWeightPower or 0.18
	local neutralBias = PetConfig.LuckNeutralBias or 0.12
	local exponentScale = PetConfig.LuckExponentScale or 1.0

	local luck = math.max(0.05, luckMultiplier)
	local softBase = baseWeight ^ softPower
	-- Below neutral (Common/Uncommon): luck^negative → suppressed at high luck.
	-- Above neutral (Epic+): luck^positive → boosted.
	local exponent = (rarityBias - neutralBias) * exponentScale
	local luckMult = luck ^ exponent
	return math.max(1e-18, softBase * luckMult)
end

local REVEAL_FOLDER_NAME = "PetReveals"
local revealFolder: Folder? = nil

local function getRevealFolder(): Folder
	local existing = revealFolder
	if existing and existing.Parent then
		return existing
	end
	local found = Workspace:FindFirstChild(REVEAL_FOLDER_NAME)
	if found and found:IsA("Folder") then
		revealFolder = found
		return found
	end
	local created = Instance.new("Folder")
	created.Name = REVEAL_FOLDER_NAME
	created.Parent = Workspace
	revealFolder = created
	return created
end

local function flatten(vector: Vector3): Vector3
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude < 0.05 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

local function getPlayerLookTarget(player: Player, fallback: Vector3): Vector3
	local character = player.Character
	if not character then
		return fallback
	end
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position + Vector3.new(0, 1.4, 0)
	end
	return fallback
end

local function animateFlyIn(display: Model, player: Player, startPos: Vector3, endPos: Vector3, duration: number)
	task.spawn(function()
		local startTime = os.clock()
		local travel = (endPos - startPos).Magnitude
		local arcHeight = math.clamp(travel * 0.32, 1.8, 5.2)
		local lookAt = getPlayerLookTarget(player, endPos)
		PetWorldDisplay.SetLookingAt(display, startPos, lookAt)

		while display.Parent do
			local alpha = math.clamp((os.clock() - startTime) / duration, 0, 1)
			local eased = alpha * alpha * (3 - 2 * alpha)
			local pos = startPos:Lerp(endPos, eased)
			-- Burst out of the cave, then settle in front of the player.
			local lift = math.sin(eased * math.pi) * arcHeight
			if eased < 0.22 then
				lift += (1 - eased / 0.22) * 0.35
			end
			local worldPos = pos + Vector3.new(0, lift, 0)
			lookAt = getPlayerLookTarget(player, endPos)
			PetWorldDisplay.SetLookingAt(display, worldPos, lookAt)
			if alpha >= 1 then
				break
			end
			task.wait()
		end

		if display.Parent then
			local t0 = os.clock()
			while display.Parent and os.clock() - t0 < 0.28 do
				local a = (os.clock() - t0) / 0.28
				local y = math.sin(a * math.pi) * 0.28
				lookAt = getPlayerLookTarget(player, endPos)
				PetWorldDisplay.SetLookingAt(display, endPos + Vector3.new(0, y, 0), lookAt)
				task.wait()
			end
		end

		while display.Parent do
			lookAt = getPlayerLookTarget(player, endPos)
			PetWorldDisplay.SetLookingAt(display, endPos, lookAt)
			task.wait()
		end
	end)
end

function PetService.RollPet(luckMultiplier: number, pityMultiplier: number?): PetDefinition
	PetCatalogService.Initialize()

	local pets = PetConfig.Pets
	if #pets == 0 then
		error("[PetService] No pets in catalog to roll.")
	end

	local pityMult = if typeof(pityMultiplier) == "number" and pityMultiplier > 0 then pityMultiplier else 1

	local totalWeight = 0
	local weightedPets = {}

	for _, pet in ipairs(pets) do
		local bias = PetConfig.RarityBias[pet.Rarity] or 1
		local adjustedWeight = getAdjustedWeight(pet.Weight, bias, luckMultiplier)

		if pityMult > 1 and PityConfig.IsPityBoostRarity(pet.Rarity) then
			adjustedWeight *= pityMult
		end

		totalWeight += adjustedWeight
		table.insert(weightedPets, {
			Pet = pet,
			Weight = adjustedWeight,
		})
	end

	local roll = math.random() * totalWeight
	local runningWeight = 0

	for _, entry in ipairs(weightedPets) do
		runningWeight += entry.Weight
		if roll <= runningWeight then
			return entry.Pet
		end
	end

	return weightedPets[#weightedPets].Pet
end

function PetService.SpawnReveal(player: Player, petName: string, originCFrame: CFrame?, eventTag: string?): Model?
	PetCatalogService.Initialize()

	local petsFolder = ServerStorage:FindFirstChild("Pets")
	if not petsFolder or not petsFolder:IsA("Folder") then
		return nil
	end

	local template = petsFolder:FindFirstChild(petName)
	if not template or not template:IsA("Model") then
		return nil
	end

	local rarity = "Common"
	local rarityValue = template:FindFirstChild("Rarity")
	if rarityValue and rarityValue:IsA("StringValue") and rarityValue.Value ~= "" then
		rarity = rarityValue.Value
	else
		local definition = getPetDefinitionByName(petName)
		if definition then
			rarity = definition.Rarity
		end
	end

	local display = PetWorldDisplay.Create(template, {
		Name = string.format("%sReveal", petName),
		PetName = petName,
		StudSize = 2.7,
		Rarity = rarity,
		CatchAura = CatchFeelConfig.GetRevealAura(rarity),
		EventTag = eventTag,
		AlwaysOnTop = false,
	})
	if not display then
		return nil
	end

	display:SetAttribute("OwnerUserId", player.UserId)

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")

	local mouthPos: Vector3
	if originCFrame then
		mouthPos = originCFrame.Position
	else
		local petSpawn = Workspace:FindFirstChild("PetSpawn")
		if petSpawn and petSpawn:IsA("BasePart") then
			mouthPos = petSpawn.Position + Vector3.new(0, 1.2, 0)
		elseif rootPart and rootPart:IsA("BasePart") then
			mouthPos = (rootPart.CFrame * CFrame.new(0, 0, -10)).Position + Vector3.new(0, 1.2, 0)
		else
			mouthPos = Vector3.new(0, 5, 0)
		end
	end

	local towardPlayer = Vector3.new(0, 0, -1)
	if rootPart and rootPart:IsA("BasePart") then
		towardPlayer = flatten(rootPart.Position - mouthPos)
	end

	-- Start a little inside the cave so the pet bursts out of the mouth.
	local startPos = mouthPos - towardPlayer * 2.4 + Vector3.new(0, 0.35, 0)

	local endPos: Vector3
	if rootPart and rootPart:IsA("BasePart") then
		endPos = rootPart.Position - towardPlayer * 4.8 + Vector3.new(0, 1.35, 0)
		if (endPos - startPos).Magnitude < 4 then
			endPos = startPos + towardPlayer * 6.5 + Vector3.new(0, 1.35, 0)
		end
	else
		endPos = startPos + towardPlayer * 6 + Vector3.new(0, 1.2, 0)
	end

	local flyScale = CatchFeelConfig.GetFlyInScale(rarity)
	local maxFly = if flyScale > 1 then 2.8 else 2.2
	local duration = math.clamp(
		(endPos - startPos).Magnitude / BaitConfig.RevealWalkStudsPerSecond * flyScale,
		0.85,
		maxFly
	)

	PetWorldDisplay.SetLookingAt(display, startPos, getPlayerLookTarget(player, endPos))
	display.Parent = getRevealFolder()
	CollectionService:AddTag(display, CatchFeelConfig.RevealTag)
	animateFlyIn(display, player, startPos, endPos, duration)

	task.delay(PetConfig.RevealDuration, function()
		if display.Parent then
			display:Destroy()
		end
	end)

	return display
end

function PetService.GetPetDefinition(petName: string): PetDefinition?
	return getPetDefinitionByName(petName)
end

return PetService
