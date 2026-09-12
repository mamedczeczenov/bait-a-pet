--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Remotes MUST exist before any other BaitSystem script WaitForChild("Remotes").
-- Create them before requiring modules that may hang or error.
local function getOrCreateFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function getOrCreateRemoteEvent(parent: Instance, name: string): RemoteEvent
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local function getOrCreateRemoteFunction(parent: Instance, name: string): RemoteFunction
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end

	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local function ensureRemotes()
	local remotesFolder = getOrCreateFolder(ReplicatedStorage, "Remotes")
	getOrCreateRemoteEvent(remotesFolder, "StartBait")
	getOrCreateRemoteEvent(remotesFolder, "SubmitLuck")
	getOrCreateRemoteEvent(remotesFolder, "PetResult")
	getOrCreateRemoteEvent(remotesFolder, "OpenShop")
	getOrCreateRemoteEvent(remotesFolder, "BuyItem")
	getOrCreateRemoteEvent(remotesFolder, "SellPet")
	getOrCreateRemoteEvent(remotesFolder, "SellAllPets")
	getOrCreateRemoteEvent(remotesFolder, "ShopResult")
	getOrCreateRemoteEvent(remotesFolder, "RequestTeleport")
	getOrCreateRemoteEvent(remotesFolder, "OpenMapPicker")
	getOrCreateRemoteEvent(remotesFolder, "EquipPet")
	getOrCreateRemoteEvent(remotesFolder, "OpenUpgrade")
	getOrCreateRemoteEvent(remotesFolder, "BuyUpgrade")
	getOrCreateRemoteEvent(remotesFolder, "UsePotion")
	getOrCreateRemoteEvent(remotesFolder, "UpgradeResult")
	getOrCreateRemoteEvent(remotesFolder, "SelectBait")
	getOrCreateRemoteEvent(remotesFolder, "RequestThrow")
	getOrCreateRemoteEvent(remotesFolder, "Tutorial")
	getOrCreateRemoteEvent(remotesFolder, "UpdateSettings")
	getOrCreateRemoteEvent(remotesFolder, "Goals")
	getOrCreateRemoteEvent(remotesFolder, "Daily")
	getOrCreateRemoteEvent(remotesFolder, "AdReward")
	getOrCreateRemoteEvent(remotesFolder, "Gifts")
	getOrCreateRemoteEvent(remotesFolder, "WorldEvent")
	getOrCreateRemoteEvent(remotesFolder, "TogglePetLock")
	getOrCreateRemoteEvent(remotesFolder, "ToggleHotbarPin")
	getOrCreateRemoteEvent(remotesFolder, "SellBulkPets")
	getOrCreateRemoteEvent(remotesFolder, "OpenSodaMachine")
	getOrCreateRemoteEvent(remotesFolder, "FuseCompanion")
	getOrCreateRemoteEvent(remotesFolder, "SodaMachineResult")
	getOrCreateRemoteEvent(remotesFolder, "SetCompanion")
	getOrCreateRemoteEvent(remotesFolder, "CompanionResult")
	getOrCreateRemoteEvent(remotesFolder, "Index")
	getOrCreateRemoteEvent(remotesFolder, "GroupChest")
	getOrCreateRemoteEvent(remotesFolder, "AfkTick")
	getOrCreateRemoteEvent(remotesFolder, "Leaderboards")
	getOrCreateRemoteFunction(remotesFolder, "GetPetCatalog")
end

ensureRemotes()

local PetCatalogService = require(script.Parent:WaitForChild("PetCatalogService"))

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CompanionConfig = require(Modules:WaitForChild("CompanionConfig"))

local SHOP_STATION_TAG = "BaitShopStation"
local UPGRADE_STATION_TAG = "UpgradeStation"
local PORTAL_STATION_TAG = "PortalStation"
local AFK_PORTAL_STATION_TAG = "AfkPortalStation"
local SODA_STATION_TAG = CompanionConfig.StationTag
local STATION_DISPLAY_NAME = CompanionConfig.StationDisplayName
local GROUP_CHEST_STATION_TAG = "GroupChestStation"

local function getOrCreatePart(parent: Instance, name: string, size: Vector3, cframe: CFrame): Part
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Part") then
		return existing
	end

	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.Parent = parent
	return part
end

local Modules = ReplicatedStorage:WaitForChild("Modules")
local BaitConfig = require(Modules:WaitForChild("BaitConfig"))
local CaveConfig = require(Modules:WaitForChild("CaveConfig"))
local GroupChestConfig = require(Modules:WaitForChild("GroupChestConfig"))
local PlaceConfig = require(Modules:WaitForChild("PlaceConfig"))

local function getReferenceCFrame(container: Instance): CFrame?
	if container:IsA("Model") then
		return container:GetPivot()
	end

	if container:IsA("BasePart") then
		return container.CFrame
	end

	local nestedPart = container:FindFirstChildWhichIsA("BasePart", true)
	if nestedPart then
		return nestedPart.CFrame
	end

	return nil
end

local function getCatchZoneCFrame(caveContainer: Instance): CFrame
	local referenceCFrame = getReferenceCFrame(caveContainer)
	if referenceCFrame then
		return referenceCFrame * CFrame.new(0, 2, -6)
	end

	local spawnLocation = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLocation then
		return spawnLocation.CFrame * CFrame.new(0, 2, -12)
	end

	return CFrame.new(0, 3, -16)
end

local function stripCavePrompts(root: Instance)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			local action = string.lower(descendant.ActionText)
			local object = string.lower(descendant.ObjectText)
			if string.find(action, "bait", 1, true)
				or string.find(action, "throw", 1, true)
				or string.find(object, "cave", 1, true)
				or string.find(object, "pool", 1, true)
			then
				descendant:Destroy()
			end
		end
	end

	local throwPoint = root:FindFirstChild("ThrowPoint", true)
	if throwPoint then
		local prompt = throwPoint:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt:Destroy()
		end
	end
end

local function isCaveName(name: string): boolean
	-- Normal caves only — VipCave is handled separately so Normal ThrowPoint stays untouched.
	return CaveConfig.IsNormalCaveName(name)
end

local function findCaveInstances(): { Instance }
	local caves: { Instance } = {}
	local seen: { [Instance]: boolean } = {}

	local function addCave(instance: Instance)
		if seen[instance] then
			return
		end
		seen[instance] = true
		table.insert(caves, instance)
	end

	for _, tagged in ipairs(CollectionService:GetTagged(BaitConfig.CaveTag)) do
		if tagged:IsA("Model") or tagged:IsA("Folder") or tagged:IsA("BasePart") then
			if not CaveConfig.IsVipName(tagged.Name) then
				addCave(tagged)
			end
		end
	end

	for _, child in ipairs(Workspace:GetChildren()) do
		if isCaveName(child.Name) then
			addCave(child)
		end
	end

	-- Fallback: nested Cave / Cave2 models if not top-level.
	if #caves == 0 then
		for _, descendant in ipairs(Workspace:GetDescendants()) do
			if isCaveName(descendant.Name)
				and (descendant:IsA("Model") or descendant:IsA("Folder") or descendant:IsA("BasePart"))
			then
				addCave(descendant)
			end
		end
	end

	if #caves == 0 then
		local folder = Instance.new("Folder")
		folder.Name = "Cave"
		folder.Parent = Workspace
		addCave(folder)
	end

	return caves
end

local function ensureCatchZoneForCave(caveContainer: Instance, index: number): Part
	local zoneName = if index == 1 then "ThrowPoint" else string.format("ThrowPoint%d", index)
	local parentForZone: Instance = if caveContainer:IsA("Model") or caveContainer:IsA("Folder")
		then caveContainer
		else caveContainer.Parent or Workspace

	-- Never reposition an existing Normal ThrowPoint.
	local throwPoint = getOrCreatePart(parentForZone, zoneName, Vector3.new(6, 1, 6), getCatchZoneCFrame(caveContainer))
	throwPoint.Material = Enum.Material.Slate
	throwPoint.Color = Color3.fromRGB(88, 88, 88)
	throwPoint.Transparency = 1
	throwPoint.CanCollide = false
	throwPoint.CanTouch = false
	throwPoint.CanQuery = true
	throwPoint.CastShadow = false
	throwPoint:SetAttribute("CaveType", CaveConfig.Normal)
	throwPoint:SetAttribute("RequiresVip", false)
	throwPoint:SetAttribute("CaveLuckMult", CaveConfig.GetPlaceLuckMultiplier(CaveConfig.Normal))

	local prompt = throwPoint:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt:Destroy()
	end

	local catchZone = throwPoint:FindFirstChild("CatchZone")
	local zone: Part
	if catchZone and catchZone:IsA("Part") then
		zone = catchZone
	else
		if catchZone then
			catchZone:Destroy()
		end
		zone = Instance.new("Part")
		zone.Name = "CatchZone"
		zone.Parent = throwPoint
	end

	local diameter = BaitConfig.CatchZoneRadius * 2
	zone.Size = Vector3.new(diameter, 12, diameter)
	zone.CFrame = throwPoint.CFrame + Vector3.new(0, 5, 0)
	zone.Anchored = true
	zone.CanCollide = false
	zone.CanTouch = false
	zone.CanQuery = true
	zone.Transparency = 1
	zone.CastShadow = false
	zone:SetAttribute("CaveIndex", index)
	zone:SetAttribute("CaveType", CaveConfig.Normal)
	zone:SetAttribute("RequiresVip", false)
	zone:SetAttribute("CaveLuckMult", CaveConfig.GetPlaceLuckMultiplier(CaveConfig.Normal))
	zone:SetAttribute("CatchRadius", BaitConfig.CatchZoneRadius)
	CollectionService:AddTag(zone, BaitConfig.CatchZoneTag)

	stripCavePrompts(caveContainer)
	print(string.format("[BaitBootstrap] Bound normal catch zone for '%s' (%s)", caveContainer:GetFullName(), zone:GetFullName()))
	return zone
end

local function clearLegacyVipCatchZones(keep: BasePart?)
	for _, zone in ipairs(CollectionService:GetTagged(BaitConfig.CatchZoneTag)) do
		if zone:IsA("BasePart") and zone ~= keep then
			local isVip = zone:GetAttribute("CaveType") == CaveConfig.Vip
				or zone:GetAttribute("RequiresVip") == true
				or CaveConfig.ResolveTypeFromZone(zone) == CaveConfig.Vip
			if isVip and not CaveConfig.HasMarker(zone, CaveConfig.VipCatchMarker) then
				CollectionService:RemoveTag(zone, BaitConfig.CatchZoneTag)
				if zone.Name == "CatchZone" or zone:GetAttribute("BootstrapManaged") == true then
					zone:Destroy()
				end
			end
		end
	end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("BasePart")
			and descendant.Name == "ThrowPointVip"
			and descendant:GetAttribute("BootstrapManaged") == true
			and descendant ~= keep
		then
			descendant:Destroy()
		end
	end
end

local function ensureVipCatchZone(_vipCave: Instance?): Part?
	local vipCatch = CaveConfig.FindVipCatchPart()
	if not vipCatch then
		warn("[BaitBootstrap] VipCatch marker not found (Attribute name=VipCatch or Name=VipCatch). VIP catch disabled.")
		clearLegacyVipCatchZones(nil)
		return nil
	end

	clearLegacyVipCatchZones(vipCatch)

	vipCatch:SetAttribute("CaveType", CaveConfig.Vip)
	vipCatch:SetAttribute("RequiresVip", true)
	vipCatch:SetAttribute("CaveLuckMult", CaveConfig.VipLuckMultiplier)
	vipCatch:SetAttribute("RequireStandOn", true)
	vipCatch:SetAttribute("CatchRadius", math.max(vipCatch.Size.X, vipCatch.Size.Z) * 0.5 + 3)

	local prompt = vipCatch:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt:Destroy()
	end

	local oldZone = vipCatch:FindFirstChild("CatchZone")
	if oldZone then
		CollectionService:RemoveTag(oldZone, BaitConfig.CatchZoneTag)
		oldZone:Destroy()
	end

	CollectionService:AddTag(vipCatch, BaitConfig.CatchZoneTag)

	local vipCave = CaveConfig.FindVipCave()
	if vipCave then
		vipCave:SetAttribute("CaveType", CaveConfig.Vip)
		stripCavePrompts(vipCave)
	end

	print(string.format(
		"[BaitBootstrap] Bound VIP catch to marker '%s' (%dx luck, stand-on only)",
		vipCatch:GetFullName(),
		CaveConfig.VipLuckMultiplier
	))
	return vipCatch
end

local function ensureCaveInteraction()
	local caves = findCaveInstances()
	local firstZone: Part? = nil

	for index, cave in ipairs(caves) do
		local zone = ensureCatchZoneForCave(cave, index)
		if not firstZone then
			firstZone = zone
		end
	end

	ensureVipCatchZone(CaveConfig.FindVipCave())
	if not CaveConfig.FindVipCatchPart() then
		warn("[BaitBootstrap] Place a platform with Attribute name=VipCatch for VIP catching.")
	end
	if not CaveConfig.FindVipSpawnPart() then
		warn("[BaitBootstrap] Place VipSpawn (Texture/Part Attribute name=VipSpawn) for VIP teleport.")
	end
	if not CaveConfig.FindThrowSpawnPart() then
		warn("[BaitBootstrap] Place ThrowSpawn (Attribute name=ThrowSpawn) for normal THROW teleport.")
	end

	local petSpawn = Workspace:FindFirstChild("PetSpawn")
	if (not petSpawn or not petSpawn:IsA("Part")) and firstZone then
		local newPetSpawn = Instance.new("Part")
		newPetSpawn.Name = "PetSpawn"
		newPetSpawn.Size = Vector3.new(4, 1, 4)
		newPetSpawn.CFrame = firstZone.CFrame * CFrame.new(0, -5, -8)
		newPetSpawn.Anchored = true
		newPetSpawn.Transparency = 1
		newPetSpawn.CanCollide = false
		newPetSpawn.Parent = Workspace
	end
end

local function findNamedInstance(targetName: string): Instance?
	local lowerName = string.lower(targetName)
	local best: Instance? = nil

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if string.lower(descendant.Name) == lowerName then
			-- Prefer models/parts over random nested values/folders with same name.
			if descendant:IsA("Model") or descendant:IsA("BasePart") then
				return descendant
			end
			if not best then
				best = descendant
			end
		end
	end

	return best
end

local function getStationCFrame(target: Instance): CFrame
	local reference = getReferenceCFrame(target)
	if reference then
		return reference
	end

	return CFrame.new(0, 5, 0)
end

local function ensureStationInteraction(targetName: string, mode: string, actionText: string, objectText: string)
	local target = findNamedInstance(targetName)
	if not target then
		warn(string.format("[BaitBootstrap] Missing Workspace object named '%s'. Shop/%s will not work until it exists.", targetName, mode))
		return
	end

	local searchRoot: Instance = if target:IsA("Model") or target:IsA("Folder") or target:IsA("BasePart")
		then target
		else target.Parent or Workspace

	local existingPrompts: { ProximityPrompt } = {}
	if searchRoot:IsA("ProximityPrompt") then
		table.insert(existingPrompts, searchRoot)
	end
	for _, descendant in ipairs(searchRoot:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			table.insert(existingPrompts, descendant)
		end
	end

	-- Replace old prompts like "Otwórz sklep" and wire them into our shop system.
	local mapPromptCount = 0
	for _, prompt in ipairs(existingPrompts) do
		-- Skip prompts we create on dedicated interaction parts; those are handled below.
		if prompt.Parent and string.find(prompt.Parent.Name, "Interaction", 1, true) then
			-- keep backup handling separate
		else
			mapPromptCount += 1
			prompt.ActionText = actionText
			prompt.ObjectText = objectText
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance, 18)
			prompt.RequiresLineOfSight = false
			prompt.Enabled = true
			prompt:SetAttribute("ShopMode", mode)

			local host = prompt.Parent
			if host and host:IsA("BasePart") then
				host:SetAttribute("ShopMode", mode)
				CollectionService:AddTag(host, SHOP_STATION_TAG)
			elseif host then
				-- Prompt may sit on an Attachment; tag nearest BasePart.
				local part = host:FindFirstAncestorWhichIsA("BasePart")
				if part then
					part:SetAttribute("ShopMode", mode)
					CollectionService:AddTag(part, SHOP_STATION_TAG)
				end
			end

			print(string.format("[BaitBootstrap] Rewired prompt '%s' on %s -> %s / %s", prompt:GetFullName(), mode, actionText, objectText))
		end
	end

	local parentForPart: Instance = if target:IsA("Model") or target:IsA("Folder") then target else target.Parent or Workspace
	local interactionName = string.format("%sInteraction", mode)
	local existing = parentForPart:FindFirstChild(interactionName)
	local interaction: Part

	if existing and existing:IsA("Part") then
		interaction = existing
	else
		if existing then
			existing:Destroy()
		end

		interaction = Instance.new("Part")
		interaction.Name = interactionName
		interaction.Parent = parentForPart
	end

	interaction.Size = Vector3.new(10, 8, 10)
	interaction.CFrame = getStationCFrame(target) + Vector3.new(0, 2, 0)
	interaction.Anchored = true
	interaction.CanCollide = false
	interaction.CanTouch = false
	interaction.CanQuery = true
	interaction.Transparency = 1
	interaction.CastShadow = false
	interaction:SetAttribute("ShopMode", mode)
	CollectionService:AddTag(interaction, SHOP_STATION_TAG)

	local prompt = interaction:FindFirstChild("ProximityPrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") then
		if prompt then
			prompt:Destroy()
		end
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ProximityPrompt"
		prompt.Parent = interaction
	end

	-- If the map already has its own shop/sell prompt, hide the backup one
	-- so the player only sees a single "Open Shop" / "Sell Pets" action.
	local hasMapPrompt = mapPromptCount > 0
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Enabled = not hasMapPrompt
	prompt:SetAttribute("ShopMode", mode)

	local clickDetector = interaction:FindFirstChildOfClass("ClickDetector")
	if not clickDetector then
		clickDetector = Instance.new("ClickDetector")
		clickDetector.Parent = interaction
	end
	clickDetector.MaxActivationDistance = 32

	print(string.format("[BaitBootstrap] Bound '%s' -> %s (%s)", target:GetFullName(), mode, interaction:GetFullName()))
end

local function ensureExistingShopStations()
	ensureStationInteraction("shop", "Buy", "Open Shop", "Shop")
	ensureStationInteraction("sell", "Sell", "Sell Pets", "Sell")

	local leftoverShopNpc = Workspace:FindFirstChild("ShopNpc")
	if leftoverShopNpc then
		leftoverShopNpc:Destroy()
	end
end

local function ensureUpgradeStation()
	local target = findNamedInstance("upgrade")
	if not target then
		warn("[BaitBootstrap] Missing Workspace object named 'upgrade'. Upgrade station will not work until it exists.")
		return
	end

	local searchRoot: Instance = if target:IsA("Model") or target:IsA("Folder") or target:IsA("BasePart")
		then target
		else target.Parent or Workspace

	local mapPromptCount = 0
	for _, descendant in ipairs(searchRoot:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			mapPromptCount += 1
			descendant.ActionText = "Open Upgrades"
			descendant.ObjectText = "Upgrades"
			descendant.HoldDuration = 0
			descendant.MaxActivationDistance = math.max(descendant.MaxActivationDistance, 18)
			descendant.RequiresLineOfSight = false
			descendant.Enabled = true
			descendant:SetAttribute("IsUpgradeStation", true)

			local host = descendant.Parent
			if host and host:IsA("BasePart") then
				host:SetAttribute("IsUpgradeStation", true)
				CollectionService:AddTag(host, UPGRADE_STATION_TAG)
			elseif host then
				local part = host:FindFirstAncestorWhichIsA("BasePart")
				if part then
					part:SetAttribute("IsUpgradeStation", true)
					CollectionService:AddTag(part, UPGRADE_STATION_TAG)
				end
			end
		end
	end

	if target:IsA("BasePart") then
		target:SetAttribute("IsUpgradeStation", true)
		CollectionService:AddTag(target, UPGRADE_STATION_TAG)
	elseif target:IsA("Model") then
		local primary = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
		if primary then
			primary:SetAttribute("IsUpgradeStation", true)
			CollectionService:AddTag(primary, UPGRADE_STATION_TAG)
		end
	end

	local parentForPart: Instance = if target:IsA("Model") or target:IsA("Folder") then target else target.Parent or Workspace
	local interactionName = "UpgradeInteraction"
	local existing = parentForPart:FindFirstChild(interactionName)
	local interaction: Part

	if existing and existing:IsA("Part") then
		interaction = existing
	else
		if existing then
			existing:Destroy()
		end
		interaction = Instance.new("Part")
		interaction.Name = interactionName
		interaction.Parent = parentForPart
	end

	interaction.Size = Vector3.new(10, 8, 10)
	interaction.CFrame = getStationCFrame(target) + Vector3.new(0, 2, 0)
	interaction.Anchored = true
	interaction.CanCollide = false
	interaction.CanTouch = false
	interaction.CanQuery = true
	interaction.Transparency = 1
	interaction.CastShadow = false
	interaction:SetAttribute("IsUpgradeStation", true)
	CollectionService:AddTag(interaction, UPGRADE_STATION_TAG)

	local prompt = interaction:FindFirstChild("ProximityPrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") then
		if prompt then
			prompt:Destroy()
		end
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ProximityPrompt"
		prompt.Parent = interaction
	end

	prompt.ActionText = "Open Upgrades"
	prompt.ObjectText = "Upgrades"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Enabled = mapPromptCount == 0
	prompt:SetAttribute("IsUpgradeStation", true)

	print(string.format("[BaitBootstrap] Bound upgrade station '%s'", target:GetFullName()))
end

local function validateMap2Setup()
	local removed = CaveConfig.CleanupLegacyAutoMap2()
	if removed > 0 then
		warn(string.format("[BaitBootstrap] Removed %d legacy auto Map2 artifact(s).", removed))
	end

	if PlaceConfig.IsMainPlace() then
		print(string.format(
			"[BaitBootstrap] Main place — portal opens map picker (Map 2 %d / Map 3 %d).",
			PlaceConfig.Map2PlaceId,
			PlaceConfig.Map3PlaceId
		))
		if CaveConfig.FindAfkPortal() then
			print("[BaitBootstrap] Main place — AFK portal found (Attribute name=AFK portal).")
		end
		return
	end

	if PlaceConfig.IsAfkPlace() then
		print(string.format(
			"[BaitBootstrap] AFK place %d — overlay lobby, no cave / shop / Map 2 portal.",
			PlaceConfig.AfkPlaceId
		))
		return
	end

	if PlaceConfig.IsMap2Place() then
		local spawn = CaveConfig.ResolveMap2SpawnPart()
		if spawn then
			print(string.format("[BaitBootstrap] Map 2 place — arrival spawn: %s", spawn:GetFullName()))
		else
			local spawnLocation = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
			if spawnLocation then
				print(string.format("[BaitBootstrap] Map 2 place — using SpawnLocation: %s", spawnLocation:GetFullName()))
			else
				warn("[BaitBootstrap] Map 2 place — add Part with Attribute name=Map2Spawn (or a SpawnLocation) for portal arrival.")
			end
		end

		if CaveConfig.FindMapPortal() then
			print(string.format(
				"[BaitBootstrap] Map 2 place — portal picker -> mapa 1 lub mapa 3 (place %d / %d)",
				PlaceConfig.MainPlaceId,
				PlaceConfig.Map3PlaceId
			))
		end
		if CaveConfig.FindAfkPortal() then
			print("[BaitBootstrap] Map 2 place — AFK portal bound (Attribute name=AFK portal).")
		end
		return
	end

	if PlaceConfig.IsMap3Place() then
		local spawn = CaveConfig.FindMap3SpawnPart()
		if spawn then
			print(string.format("[BaitBootstrap] Map 3 place — arrival spawn: %s", spawn:GetFullName()))
		else
			local spawnLocation = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
			if spawnLocation then
				print(string.format("[BaitBootstrap] Map 3 place — using SpawnLocation: %s", spawnLocation:GetFullName()))
			else
				warn("[BaitBootstrap] Map 3 place — add Part with Attribute name=Map3Spawn (or a SpawnLocation) for portal arrival.")
			end
		end

		if CaveConfig.FindMapPortal() then
			print(string.format(
				"[BaitBootstrap] Map 3 place — portal picker -> mapa 1 lub mapa 2 (place %d / %d)",
				PlaceConfig.MainPlaceId,
				PlaceConfig.Map2PlaceId
			))
		else
			warn("[BaitBootstrap] Map 3 — brak obiektu 'portal' w Workspace. Dodaj portal wyboru map.")
		end
		if CaveConfig.FindAfkPortal() then
			print("[BaitBootstrap] Map 3 place — AFK portal bound (Attribute name=AFK portal).")
		end
		return
	end

	warn(string.format(
		"[BaitBootstrap] Unknown place id %d — set MainPlaceId / Map2PlaceId / Map3PlaceId in PlaceConfig.luau.",
		game.PlaceId
	))
end

local function bindBuiltPortal(
	target: Instance,
	portalDestination: string,
	portalLabel: string,
	actionText: string,
	stationTag: string,
	interactionName: string
)
	local searchRoot: Instance = if target:IsA("Model") or target:IsA("Folder") or target:IsA("BasePart")
		then target
		else target.Parent or Workspace

	local mapPromptCount = 0
	for _, descendant in ipairs(searchRoot:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			mapPromptCount += 1
		end
	end

	local parentForPart: Instance = if target:IsA("Model") or target:IsA("Folder") then target else target.Parent or Workspace
	local existing = parentForPart:FindFirstChild(interactionName)
	local interaction: Part

	if existing and existing:IsA("Part") then
		interaction = existing
	else
		if existing then
			existing:Destroy()
		end
		interaction = Instance.new("Part")
		interaction.Name = interactionName
		interaction.Parent = parentForPart
	end

	interaction.Size = Vector3.new(14, 10, 14)
	interaction.CFrame = getStationCFrame(target) + Vector3.new(0, 2, 0)
	interaction.Anchored = true
	interaction.CanCollide = false
	interaction.CanTouch = false
	interaction.CanQuery = true
	interaction.Transparency = 1
	interaction.CastShadow = false
	interaction:SetAttribute("PortalDestination", portalDestination)
	CollectionService:AddTag(interaction, stationTag)

	for _, descendant in ipairs(searchRoot:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") and not descendant:IsDescendantOf(interaction) then
			descendant.Enabled = false
		end
	end

	if target:IsA("BasePart") then
		target:SetAttribute("PortalDestination", portalDestination)
		CollectionService:AddTag(target, stationTag)
	elseif target:IsA("Model") then
		local primary = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
		if primary then
			primary:SetAttribute("PortalDestination", portalDestination)
			CollectionService:AddTag(primary, stationTag)
		end
	end

	local prompt = interaction:FindFirstChild("ProximityPrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") then
		if prompt then
			prompt:Destroy()
		end
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ProximityPrompt"
		prompt.Parent = interaction
	end

	prompt.ActionText = actionText
	prompt.ObjectText = portalLabel
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 24
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Enabled = true
	prompt:SetAttribute("PortalDestination", portalDestination)

	local clickDetector = interaction:FindFirstChildOfClass("ClickDetector")
	if not clickDetector then
		clickDetector = Instance.new("ClickDetector")
		clickDetector.Parent = interaction
	end
	clickDetector.MaxActivationDistance = 32

	print(string.format(
		"[BaitBootstrap] Bound portal '%s' -> %s (backup prompt, disabled %d map prompt(s))",
		target:GetFullName(),
		portalDestination,
		mapPromptCount
	))
end

local function ensurePortalInteraction()
	if PlaceConfig.IsAfkPlace() then
		return
	end

	local mapPortal = CaveConfig.FindMapPortal()
	if mapPortal then
		bindBuiltPortal(mapPortal, "picker", "Worlds", "Teleport", PORTAL_STATION_TAG, "PortalInteraction")
	else
		if PlaceConfig.IsMap2Place() then
			warn("[BaitBootstrap] Map 2 — brak obiektu 'portal' w Workspace. Dodaj portal wyboru map.")
		elseif PlaceConfig.IsMap3Place() then
			warn("[BaitBootstrap] Map 3 — brak obiektu 'portal' w Workspace. Dodaj portal wyboru map.")
		elseif PlaceConfig.IsHubPlace() then
			warn("[BaitBootstrap] Missing Workspace object named 'portal'. Map picker will not work until it exists.")
		end
	end

	local afkPortal = CaveConfig.FindAfkPortal()
	if afkPortal then
		bindBuiltPortal(afkPortal, "afk", "AFK", "Go AFK", AFK_PORTAL_STATION_TAG, "AfkPortalInteraction")
	elseif PlaceConfig.IsHubPlace() or PlaceConfig.IsMap2Place() or PlaceConfig.IsMap3Place() then
		warn("[BaitBootstrap] Missing AFK portal (Attribute name=AFK portal). HUD PORTAL still teleports to the map portal.")
	end
end

local function normalizeStationKey(value: string): string
	local lower = string.lower(value)
	-- Treat "petów" / "petow" as the same map name key.
	lower = string.gsub(lower, "ó", "o")
	lower = string.gsub(lower, "%s+", " ")
	return string.gsub(lower, "^%s*(.-)%s*$", "%1")
end

local function isPetMachineName(name: string): boolean
	local key = normalizeStationKey(name)
	if key == "maszyna do petow" or key == "soda machine" or key == "sodamachine" then
		return true
	end
	for _, stationName in ipairs(CompanionConfig.StationNames) do
		if normalizeStationKey(stationName) == key then
			return true
		end
	end
	return false
end

local function findSodaMachineTarget(): Instance?
	for _, name in ipairs(CompanionConfig.StationNames) do
		local found = findNamedInstance(name)
		if found then
			return found
		end
	end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		local attrName = descendant:GetAttribute("Name")
		if typeof(attrName) == "string" and isPetMachineName(attrName) then
			if descendant:IsA("Model") or descendant:IsA("BasePart") then
				return descendant
			end
			local part = descendant:FindFirstAncestorWhichIsA("BasePart")
				or descendant:FindFirstAncestorWhichIsA("Model")
			if part then
				return part
			end
			return descendant
		end
		if descendant:GetAttribute("IsSodaMachine") == true then
			if descendant:IsA("Model") or descendant:IsA("BasePart") then
				return descendant
			end
		end
	end

	return nil
end

local function ensureSodaMachineStation()
	local target = findSodaMachineTarget()
	if not target then
		warn("[BaitBootstrap] Missing Workspace object named 'maszyna do petow'. Companion fuse will not work until it exists.")
		return
	end

	local searchRoot: Instance = if target:IsA("Model") or target:IsA("Folder") or target:IsA("BasePart")
		then target
		else target.Parent or Workspace

	local mapPromptCount = 0
	for _, descendant in ipairs(searchRoot:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			mapPromptCount += 1
			descendant.ActionText = "Use Machine"
			descendant.ObjectText = STATION_DISPLAY_NAME
			descendant.HoldDuration = 0
			descendant.MaxActivationDistance = math.max(descendant.MaxActivationDistance, 18)
			descendant.RequiresLineOfSight = false
			descendant.Enabled = true
			descendant:SetAttribute("IsSodaMachine", true)

			local host = descendant.Parent
			if host and host:IsA("BasePart") then
				host:SetAttribute("IsSodaMachine", true)
				CollectionService:AddTag(host, SODA_STATION_TAG)
			elseif host then
				local part = host:FindFirstAncestorWhichIsA("BasePart")
				if part then
					part:SetAttribute("IsSodaMachine", true)
					CollectionService:AddTag(part, SODA_STATION_TAG)
				end
			end
		end
	end

	if target:IsA("BasePart") then
		target:SetAttribute("IsSodaMachine", true)
		CollectionService:AddTag(target, SODA_STATION_TAG)
	elseif target:IsA("Model") then
		local primary = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
		if primary then
			primary:SetAttribute("IsSodaMachine", true)
			CollectionService:AddTag(primary, SODA_STATION_TAG)
		end
	end

	local parentForPart: Instance = if target:IsA("Model") or target:IsA("Folder") then target else target.Parent or Workspace
	local interactionName = "SodaMachineInteraction"
	local existing = parentForPart:FindFirstChild(interactionName)
	local interaction: Part

	if existing and existing:IsA("Part") then
		interaction = existing
	else
		if existing then
			existing:Destroy()
		end
		interaction = Instance.new("Part")
		interaction.Name = interactionName
		interaction.Parent = parentForPart
	end

	interaction.Size = Vector3.new(10, 8, 10)
	interaction.CFrame = getStationCFrame(target) + Vector3.new(0, 2, 0)
	interaction.Anchored = true
	interaction.CanCollide = false
	interaction.CanTouch = false
	interaction.CanQuery = true
	interaction.Transparency = 1
	interaction.CastShadow = false
	interaction:SetAttribute("IsSodaMachine", true)
	CollectionService:AddTag(interaction, SODA_STATION_TAG)

	local prompt = interaction:FindFirstChild("ProximityPrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") then
		if prompt then
			prompt:Destroy()
		end
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ProximityPrompt"
		prompt.Parent = interaction
	end

	prompt.ActionText = "Use Machine"
	prompt.ObjectText = STATION_DISPLAY_NAME
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Enabled = mapPromptCount == 0
	prompt:SetAttribute("IsSodaMachine", true)

	print(string.format("[BaitBootstrap] Bound pet machine '%s' as '%s'", target:GetFullName(), STATION_DISPLAY_NAME))
end

local function findGroupChestTarget(): Instance?
	local nameFallback: Instance? = nil

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		local attr = CaveConfig.GetMarkerAttribute(descendant)
		local attrMatch = typeof(attr) == "string" and GroupChestConfig.IsMarker(attr)
		local nameMatch = GroupChestConfig.IsMarker(descendant.Name)

		if attrMatch then
			if descendant:IsA("Model") or descendant:IsA("BasePart") then
				return descendant
			end
			if (descendant:IsA("Texture") or descendant:IsA("Decal")) and descendant.Parent then
				local parent = descendant.Parent
				if parent:IsA("BasePart") or parent:IsA("Model") then
					return parent
				end
			end
			local host = descendant:FindFirstAncestorWhichIsA("BasePart")
				or descendant:FindFirstAncestorWhichIsA("Model")
			if host then
				return host
			end
		elseif nameMatch and (descendant:IsA("Model") or descendant:IsA("BasePart")) and not nameFallback then
			nameFallback = descendant
		end
	end

	return nameFallback
end

local function tagGroupChestHost(host: Instance)
	host:SetAttribute("IsGroupChest", true)
	CollectionService:AddTag(host, GROUP_CHEST_STATION_TAG)
end

local function ensureGroupChestStation()
	local target = findGroupChestTarget()
	if not target then
		warn("[BaitBootstrap] Missing Workspace object with Attribute name='skrzynia vip'. Group chest will not work until it exists.")
		return
	end

	local searchRoot: Instance = if target:IsA("Model") or target:IsA("Folder") or target:IsA("BasePart")
		then target
		else target.Parent or Workspace

	local mapPromptCount = 0
	for _, descendant in ipairs(searchRoot:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			mapPromptCount += 1
			descendant.ActionText = GroupChestConfig.ActionText
			descendant.ObjectText = GroupChestConfig.ObjectText
			descendant.HoldDuration = 0
			descendant.MaxActivationDistance = math.max(descendant.MaxActivationDistance, 18)
			descendant.RequiresLineOfSight = false
			descendant.Enabled = true
			descendant:SetAttribute("IsGroupChest", true)

			local host = descendant.Parent
			if host and host:IsA("BasePart") then
				tagGroupChestHost(host)
			elseif host then
				local part = host:FindFirstAncestorWhichIsA("BasePart")
				if part then
					tagGroupChestHost(part)
				end
			end
		end
	end

	if target:IsA("BasePart") then
		tagGroupChestHost(target)
	elseif target:IsA("Model") then
		local primary = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
		if primary then
			tagGroupChestHost(primary)
		end
	end

	local parentForPart: Instance = if target:IsA("Model") or target:IsA("Folder") then target else target.Parent or Workspace
	local interactionName = "GroupChestInteraction"
	local existing = parentForPart:FindFirstChild(interactionName)
	local interaction: Part

	if existing and existing:IsA("Part") then
		interaction = existing
	else
		if existing then
			existing:Destroy()
		end
		interaction = Instance.new("Part")
		interaction.Name = interactionName
		interaction.Parent = parentForPart
	end

	interaction.Size = Vector3.new(10, 8, 10)
	interaction.CFrame = getStationCFrame(target) + Vector3.new(0, 2, 0)
	interaction.Anchored = true
	interaction.CanCollide = false
	interaction.CanTouch = false
	interaction.CanQuery = true
	interaction.Transparency = 1
	interaction.CastShadow = false
	tagGroupChestHost(interaction)

	local prompt = interaction:FindFirstChild("ProximityPrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") then
		if prompt then
			prompt:Destroy()
		end
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ProximityPrompt"
		prompt.Parent = interaction
	end

	prompt.ActionText = GroupChestConfig.ActionText
	prompt.ObjectText = GroupChestConfig.ObjectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Enabled = mapPromptCount == 0
	prompt:SetAttribute("IsGroupChest", true)

	print(string.format(
		"[BaitBootstrap] Bound group chest '%s' -> group %d",
		target:GetFullName(),
		GroupChestConfig.GroupId
	))
end

ensureRemotes()
ensureCaveInteraction()
validateMap2Setup()
ensureExistingShopStations()
ensureUpgradeStation()
ensurePortalInteraction()
ensureSodaMachineStation()
ensureGroupChestStation()
PetCatalogService.InitializeAsync()

-- Own MarketplaceService.ProcessReceipt (ShopServer / UpgradeServer bind grants).
require(script.Parent:WaitForChild("PurchaseReceiptService"))

do
	local PetConfig = require(Modules:WaitForChild("PetConfig"))
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local getPetCatalog = remotes:WaitForChild("GetPetCatalog") :: RemoteFunction
	getPetCatalog.OnServerInvoke = function(_player: Player)
		PetCatalogService.Initialize()
		local payload = {}
		for _, pet in ipairs(PetConfig.Pets) do
			table.insert(payload, {
				Name = pet.Name,
				Rarity = pet.Rarity,
				OneIn = pet.OneIn,
				SellPrice = pet.SellPrice,
				Weight = pet.Weight,
				Icon = pet.Icon,
				Description = pet.Description,
				ColorR = pet.Color.R,
				ColorG = pet.Color.G,
				ColorB = pet.Color.B,
			})
		end
		return payload
	end
end
