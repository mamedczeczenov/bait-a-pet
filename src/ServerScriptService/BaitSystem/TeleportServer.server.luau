--!strict

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local BaitConfig = require(Modules:WaitForChild("BaitConfig"))
local CaveConfig = require(Modules:WaitForChild("CaveConfig"))
local PlaceConfig = require(Modules:WaitForChild("PlaceConfig"))
local AfkConfig = require(Modules:WaitForChild("AfkConfig"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestTeleportRemote = remotes:WaitForChild("RequestTeleport") :: RemoteEvent
local openMapPickerRemote = remotes:WaitForChild("OpenMapPicker") :: RemoteEvent
local petResultRemote = remotes:WaitForChild("PetResult") :: RemoteEvent

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local TutorialService = require(script.Parent:WaitForChild("TutorialService"))
local GiftService = require(script.Parent:WaitForChild("GiftService"))
local IndexService = require(script.Parent:WaitForChild("IndexService"))

local PORTAL_STATION_TAG = "PortalStation"
local COOLDOWN_SECONDS = 0.25
local TELEPORT_RETRY_DELAY = 1.25
local MAX_TELEPORT_RETRIES = 2
local ROOT_HEIGHT = 3
local lastTeleportAt: { [Player]: number } = {}

type PendingCrossPlaceTeleport = {
	TargetPlaceId: number,
	DestinationId: string,
	TeleportData: { [string]: any },
	Retries: number,
}

local pendingCrossPlaceTeleports: { [Player]: PendingCrossPlaceTeleport } = {}
local boundPortalPrompts: { [ProximityPrompt]: boolean } = {}
local boundPortalDetectors: { [ClickDetector]: boolean } = {}

type DestConfig = {
	Names: { string },
	ApproachSign: number,
	StandGap: number,
}

local DESTINATIONS: { [string]: DestConfig } = {
	shop = {
		Names = { "shop", "BuyInteraction" },
		ApproachSign = 1,
		StandGap = 8,
	},
	sell = {
		Names = { "sell", "SellInteraction" },
		ApproachSign = 1,
		StandGap = 8,
	},
	-- Same as pre-VIP: stand in front of ThrowPoint (not the Cave model).
	throw = {
		Names = { "ThrowPoint" },
		ApproachSign = 1,
		StandGap = 10,
	},
	-- Same approach as throw, but on the VIP catch pad only.
	throw_vip = {
		Names = { "ThrowPointVip" },
		ApproachSign = 1,
		StandGap = 10,
	},
	map2 = {
		Names = {},
		ApproachSign = 1,
		StandGap = 8,
	},
	map3 = {
		Names = {},
		ApproachSign = 1,
		StandGap = 8,
	},
	map1 = {
		Names = {},
		ApproachSign = 1,
		StandGap = 8,
	},
	afk = {
		Names = {},
		ApproachSign = 1,
		StandGap = 8,
	},
}

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local function isUnderVip(instance: Instance): boolean
	local current: Instance? = instance
	while current and current ~= Workspace do
		if CaveConfig.IsVipName(current.Name) then
			return true
		end
		if current:GetAttribute("CaveType") == CaveConfig.Vip or current:GetAttribute("RequiresVip") == true then
			return true
		end
		current = current.Parent
	end
	return false
end

local function findNamedInstance(targetName: string, skipVip: boolean?): Instance?
	local lowerName = string.lower(targetName)
	local best: Instance? = nil

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if string.lower(descendant.Name) == lowerName then
			if skipVip and isUnderVip(descendant) then
				continue
			end
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

-- Normal THROW pad: prefer map ThrowPoint (skip VIP), then tagged normal CatchZone.
local function findNormalThrowTarget(): Instance?
	local byName = findNamedInstance("ThrowPoint", true)
	if byName then
		return byName
	end

	local pad = CaveConfig.FindNormalThrowPad()
	if pad then
		return pad
	end

	for _, zone in ipairs(CollectionService:GetTagged(BaitConfig.CatchZoneTag)) do
		if not zone:IsA("BasePart") then
			continue
		end
		if CaveConfig.ResolveTypeFromZone(zone) == CaveConfig.Vip or isUnderVip(zone) then
			continue
		end
		local parent = zone.Parent
		if parent and (parent:IsA("BasePart") or parent:IsA("Model")) then
			return parent
		end
		return zone
	end

	-- Multi-cave pads: ThrowPoint2, ThrowPoint3, ...
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("BasePart")
			and string.match(descendant.Name, "^ThrowPoint%d+$")
			and not isUnderVip(descendant)
		then
			return descendant
		end
	end

	return nil
end

local function flatten(vector: Vector3): Vector3
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude < 0.05 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

local function getTargetBounds(target: Instance): (CFrame?, Vector3?)
	return CaveConfig.GetBounds(target)
end

local function buildExcludeList(target: Instance, destinationId: string): { Instance }
	local exclude: { Instance } = { target }

	local buy = findNamedInstance("BuyInteraction")
	local sell = findNamedInstance("SellInteraction")
	if buy then
		table.insert(exclude, buy)
	end
	if sell then
		table.insert(exclude, sell)
	end

	-- Only exclude invisible pads / catch volumes — NOT whole Cave / VipCave models.
	-- Walkable ground in front of caves is often parented under those models; excluding
	-- them makes the ground ray miss and snap to the wrong place (bridge / sea / cliffs).
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("BasePart")
			and (
				descendant.Name == "ThrowPoint"
				or descendant.Name == "ThrowPointVip"
				or string.match(descendant.Name, "^ThrowPoint%d+$")
				or descendant.Name == "CatchZone"
				or string.find(descendant.Name, "Interaction", 1, true) ~= nil
			)
		then
			table.insert(exclude, descendant)
		end
	end

	if target:IsA("BasePart") then
		for _, descendant in ipairs(target:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.CanCollide == false then
				table.insert(exclude, descendant)
			end
		end
	end

	return exclude
end

local function raycastGroundNear(position: Vector3, referenceY: number, exclude: { Instance }): Vector3?
	raycastParams.FilterDescendantsInstances = exclude

	local startY = math.max(referenceY + 8, position.Y + 8)
	local origin = Vector3.new(position.X, startY, position.Z)
	local result = Workspace:Raycast(origin, Vector3.new(0, -(startY - (referenceY - 30)), 0), raycastParams)
	if result then
		return result.Position
	end

	return nil
end

local function getHorizontalApproach(targetCFrame: CFrame, approachSign: number): Vector3
	local look = targetCFrame.LookVector
	local lookFlat = Vector3.new(look.X, 0, look.Z)

	if lookFlat.Magnitude < 0.35 then
		local rightFlat = flatten(targetCFrame.RightVector)
		return rightFlat * approachSign
	end

	return lookFlat.Unit * approachSign
end

local function getFrontFacingCFrame(target: Instance, destinationId: string, config: DestConfig): CFrame?
	local targetCFrame, size = getTargetBounds(target)
	if not targetCFrame or not size then
		return nil
	end

	local targetPos = targetCFrame.Position
	local approachDir = getHorizontalApproach(targetCFrame, config.ApproachSign)
	-- For throw pads use a small stand gap from the pad itself — do not inflate by
	-- halfDepth of a large parent model (that overshoots the catch area).
	local distance = config.StandGap
	if destinationId ~= "throw" and destinationId ~= "throw_vip" then
		local halfDepth = math.max(size.Z, size.X) * 0.5
		distance = halfDepth + config.StandGap
	end

	local candidate = Vector3.new(
		targetPos.X + approachDir.X * distance,
		targetPos.Y,
		targetPos.Z + approachDir.Z * distance
	)

	local exclude = buildExcludeList(target, destinationId)
	local ground = raycastGroundNear(candidate, targetPos.Y, exclude)

	local standPos: Vector3
	if ground then
		standPos = Vector3.new(ground.X, ground.Y + ROOT_HEIGHT, ground.Z)
	else
		standPos = Vector3.new(candidate.X, targetPos.Y + ROOT_HEIGHT, candidate.Z)
	end

	local lookAtPoint = Vector3.new(targetPos.X, standPos.Y, targetPos.Z)
	if (lookAtPoint - standPos).Magnitude < 0.1 then
		lookAtPoint = standPos - approachDir
	end

	return CFrame.lookAt(standPos, lookAtPoint)
end

local function resolveDestination(destinationId: string): CFrame?
	local config = DESTINATIONS[destinationId]
	if not config then
		return nil
	end

	-- THROW: teleport onto map marker Attribute name=ThrowSpawn.
	if destinationId == "throw" then
		local markerCFrame = CaveConfig.GetThrowSpawnCFrame(ROOT_HEIGHT)
		if markerCFrame then
			return markerCFrame
		end
		-- Fallback if ThrowSpawn is missing on the map.
		local target = findNormalThrowTarget()
		if target then
			return getFrontFacingCFrame(target, destinationId, config)
		end
		return nil
	end

	-- VIP: teleport onto map marker Attribute name=VipSpawn (Texture/Part).
	if destinationId == "throw_vip" then
		return CaveConfig.GetVipSpawnCFrame(ROOT_HEIGHT)
	end

	-- Cross-place maps — handled by TeleportService, not CFrame.
	if destinationId == "map2" or destinationId == "map1" or destinationId == "map3" then
		return nil
	end

	for _, name in ipairs(config.Names) do
		local target = findNamedInstance(name, false)
		if target then
			local cframe = getFrontFacingCFrame(target, destinationId, config)
			if cframe then
				return cframe
			end
		end
	end

	return nil
end

local function sendTeleportError(player: Player, message: string)
	petResultRemote:FireClient(player, {
		Type = "Error",
		Message = message,
	})
end

local function formatCrossPlaceTeleportError(
	teleportResult: Enum.TeleportResult?,
	errorMessage: string?,
	destinationId: string
): string
	if RunService:IsStudio() then
		return "Teleport między mapami nie działa w Studio. Opublikuj obie mapy (File → Publish) i testuj w aplikacji Roblox."
	end

	local details = if typeof(errorMessage) == "string" then errorMessage else ""

	if teleportResult == Enum.TeleportResult.GameNotFound then
		return "Nie znaleziono mapy docelowej. Opublikuj place „map 2” przez File → Publish to Roblox."
	end

	if string.find(details, "773", 1, true)
		or string.find(details, "Unauthorized", 1, true)
		or string.find(details, "restricted", 1, true)
	then
		return "Błąd 773 — opublikuj place „map 2” (File → Publish to Roblox), potem testuj w grze online."
	end

	if destinationId == "map2" then
		return "Nie udało się teleportować na mapę 2. Opublikuj place „map 2” i testuj poza Studio."
	end
	if destinationId == "map3" then
		return "Nie udało się teleportować na mapę 3. Opublikuj place „map 3” i testuj poza Studio."
	end
	if destinationId == "afk" then
		return "Nie udało się teleportować do AFK lobby. Opublikuj place AFK i testuj poza Studio."
	end

	return "Nie udało się teleportować. Spróbuj ponownie w opublikowanej grze."
end

local function buildTeleportOptions(teleportData: { [string]: any }): TeleportOptions
	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions.ShouldReserveServer = false
	teleportOptions:SetTeleportData(teleportData)
	return teleportOptions
end

local function invokeCrossPlaceTeleport(
	player: Player,
	targetPlaceId: number,
	teleportData: { [string]: any }
): (boolean, string?)
	local teleportOptions = buildTeleportOptions(teleportData)

	local okAsync, errAsync = pcall(function()
		TeleportService:TeleportAsync(targetPlaceId, { player }, teleportOptions)
	end)
	if okAsync then
		return true, nil
	end

	local okLegacy, errLegacy = pcall(function()
		TeleportService:Teleport(targetPlaceId, player, teleportData)
	end)
	if okLegacy then
		return true, nil
	end

	return false, tostring(errAsync) .. " | " .. tostring(errLegacy)
end

local function beginCrossPlaceTeleport(
	player: Player,
	targetPlaceId: number,
	destinationId: string,
	teleportData: { [string]: any }
): boolean
	pendingCrossPlaceTeleports[player] = {
		TargetPlaceId = targetPlaceId,
		DestinationId = destinationId,
		TeleportData = teleportData,
		Retries = 0,
	}

	local ok, err = invokeCrossPlaceTeleport(player, targetPlaceId, teleportData)
	if ok then
		return true
	end

	pendingCrossPlaceTeleports[player] = nil
	warn(string.format(
		"[TeleportServer] Cross-place teleport to '%s' (place %d) failed: %s",
		destinationId,
		targetPlaceId,
		tostring(err)
	))
	sendTeleportError(player, formatCrossPlaceTeleportError(nil, err, destinationId))
	return false
end

TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
	local pending = pendingCrossPlaceTeleports[player]
	if not pending then
		return
	end

	warn(string.format(
		"[TeleportServer] TeleportInitFailed for %s -> %s (%d): %s %s",
		player.Name,
		pending.DestinationId,
		pending.TargetPlaceId,
		tostring(teleportResult),
		tostring(errorMessage)
	))

	if pending.Retries >= MAX_TELEPORT_RETRIES then
		pendingCrossPlaceTeleports[player] = nil
		sendTeleportError(
			player,
			formatCrossPlaceTeleportError(teleportResult, errorMessage, pending.DestinationId)
		)
		return
	end

	pending.Retries += 1
	task.delay(TELEPORT_RETRY_DELAY, function()
		if not player.Parent then
			pendingCrossPlaceTeleports[player] = nil
			return
		end

		local ok, err = invokeCrossPlaceTeleport(player, pending.TargetPlaceId, pending.TeleportData)
		if not ok then
			pendingCrossPlaceTeleports[player] = nil
			sendTeleportError(
				player,
				formatCrossPlaceTeleportError(teleportResult, err, pending.DestinationId)
			)
		end
	end)
end)

local pendingArrivalSpawn: { [Player]: boolean } = {}

local function markArrivalFromTeleport(player: Player)
	local joinData = player:GetJoinData()
	local teleportData = joinData.TeleportData
	if typeof(teleportData) ~= "table" then
		return
	end

	local destination = teleportData.Destination
	if typeof(destination) ~= "string" then
		return
	end

	local normalized = string.lower(destination)
	if normalized == "map2" or normalized == "map1" or normalized == "map3" or normalized == "throw" or normalized == "afk" then
		pendingArrivalSpawn[player] = true
	end
end

local function applyArrivalSpawn(player: Player, character: Model)
	if not pendingArrivalSpawn[player] then
		return
	end
	pendingArrivalSpawn[player] = nil

	local joinData = player:GetJoinData()
	local teleportData = if typeof(joinData.TeleportData) == "table" then joinData.TeleportData else nil
	local destination = if teleportData then teleportData.Destination else nil

	local spawnCFrame: CFrame? = nil
	if destination == "map3" then
		spawnCFrame = CaveConfig.GetMap3SpawnCFrame(ROOT_HEIGHT)
	elseif destination == "map2" then
		spawnCFrame = CaveConfig.GetMap2SpawnCFrame(ROOT_HEIGHT)
	elseif destination == "afk" then
		spawnCFrame = CaveConfig.GetAfkSpawnCFrame(ROOT_HEIGHT)
	elseif destination == "map1" or destination == "throw" then
		if PlaceConfig.IsMap3Place() then
			spawnCFrame = CaveConfig.GetMap3SpawnCFrame(ROOT_HEIGHT)
		elseif PlaceConfig.IsMap2Place() then
			spawnCFrame = CaveConfig.GetMap2SpawnCFrame(ROOT_HEIGHT)
		elseif PlaceConfig.IsAfkPlace() then
			spawnCFrame = CaveConfig.GetAfkSpawnCFrame(ROOT_HEIGHT)
		else
			spawnCFrame = CaveConfig.GetThrowSpawnCFrame(ROOT_HEIGHT)
		end
	end

	if not spawnCFrame then
		local spawnLocation = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		if spawnLocation then
			spawnCFrame = spawnLocation.CFrame + Vector3.new(0, ROOT_HEIGHT, 0)
		end
	end

	if not spawnCFrame then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		root = character:WaitForChild("HumanoidRootPart", 8)
	end
	if not root or not root:IsA("BasePart") then
		return
	end

	root.CFrame = spawnCFrame
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function tryUnlockMap2(player: Player)
	if not PlayerDataService.IsLoaded(player) then
		return
	end
	local newly = PlayerDataService.UnlockMap2(player)
	if newly then
		petResultRemote:FireClient(player, {
			Type = "Map2Unlock",
			Message = "Map 2 unlocked — Walk 2 followers + Carry 2 in hands!",
		})
	end
end

local function tryUnlockMap3(player: Player)
	if not PlayerDataService.IsLoaded(player) then
		return
	end
	local newly = PlayerDataService.UnlockMap3(player)
	if newly then
		petResultRemote:FireClient(player, {
			Type = "Map3Unlock",
			Message = "Map 3 unlocked — Carry 3 pets in hands!",
		})
	end
end

local function canTravelToMap3(player: Player): (boolean, string)
	if PlayerDataService.HasMap3Unlocked(player) then
		return true, ""
	end
	return IndexService.MeetsMap3IndexRequirement(player)
end

local function teleportToPlace(player: Player, destinationId: string): boolean
	if destinationId == "map2" and PlaceConfig.IsMap2Place() then
		sendTeleportError(player, "You are already on Map 2.")
		return false
	end
	if destinationId == "map3" and PlaceConfig.IsMap3Place() then
		sendTeleportError(player, "You are already on Map 3.")
		return false
	end
	if destinationId == "map1" and PlaceConfig.IsMainPlace() then
		sendTeleportError(player, "Jesteś już na mapie 1.")
		return false
	end
	if destinationId == "afk" then
		if PlaceConfig.IsAfkPlace() then
			sendTeleportError(player, "You are already in the AFK lobby.")
			return false
		end
		if player:GetAttribute("TutorialCompleted") ~= true then
			sendTeleportError(player, "Finish the guide first.")
			return false
		end
	end

	if destinationId == "map3" then
		local allowed, lockReason = canTravelToMap3(player)
		if not allowed then
			sendTeleportError(player, lockReason)
			return false
		end
	end

	local targetPlaceId = PlaceConfig.GetPlaceIdForDestination(destinationId)
	if typeof(targetPlaceId) ~= "number" or targetPlaceId <= 0 then
		sendTeleportError(player, "Target place is not configured.")
		return false
	end

	local teleportDestination = destinationId

	if destinationId == "map2" then
		-- Unlock dual-equip as soon as the player commits to Map 2
		-- (including Studio, where cross-place teleport cannot run).
		tryUnlockMap2(player)
	elseif destinationId == "map3" then
		tryUnlockMap3(player)
	end

	if RunService:IsStudio() then
		if destinationId == "map2" then
			sendTeleportError(
				player,
				"Studio: teleport do Map 2 nie działa, ale dual Walk + Carry jest już odblokowany. Kliknij Walk na 2 companionach."
			)
		elseif destinationId == "map3" then
			sendTeleportError(
				player,
				"Studio: teleport do Map 3 nie działa, ale extra Carry slot jest już odblokowany jeśli spełniasz warunek Index 2."
			)
		elseif destinationId == "afk" then
			sendTeleportError(player, AfkConfig.StudioTeleportMessage)
		else
			sendTeleportError(
				player,
				"Teleport między mapami nie działa w Studio. Opublikuj mapy i testuj w aplikacji Roblox (nie Play w Studio)."
			)
		end
		return false
	end

	if destinationId == "afk" then
		PlayerDataService.SetAfkThrow(player, true)
	elseif destinationId == "map1" then
		PlayerDataService.SetAfkThrow(player, false)
	end

	local teleportData = {
		Destination = teleportDestination,
		FromPlaceId = game.PlaceId,
	}
	GiftService.AttachTeleportData(player, teleportData)

	-- Flush before leaving this place so map hops cannot race the DataStore.
	PlayerDataService.Save(player)

	return beginCrossPlaceTeleport(player, targetPlaceId, destinationId, teleportData)
end

local function teleportPlayer(player: Player, destinationId: string): boolean
	local now = os.clock()
	local lastAt = lastTeleportAt[player]
	if lastAt and (now - lastAt) < COOLDOWN_SECONDS then
		return false
	end

	local character = player.Character
	if not character then
		return false
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return false
	end

	if destinationId == "throw_vip" and not PlayerDataService.HasVipAccess(player) then
		sendTeleportError(player, CaveConfig.VipLockedMessage)
		return false
	end

	if destinationId == "map2" or destinationId == "map1" or destinationId == "map3" or destinationId == "afk" then
		lastTeleportAt[player] = now
		return teleportToPlace(player, destinationId)
	end

	local destination = resolveDestination(destinationId)
	if not destination then
		warn(string.format("[TeleportServer] Missing destination for '%s'", destinationId))
		if destinationId == "throw_vip" then
			sendTeleportError(player, "VipSpawn marker not found (Attribute name=VipSpawn).")
		elseif destinationId == "throw" then
			sendTeleportError(player, "ThrowSpawn marker not found (Attribute name=ThrowSpawn).")
		end
		return false
	end

	lastTeleportAt[player] = now
	root.CFrame = destination
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

requestTeleportRemote.OnServerEvent:Connect(function(player, destinationId)
	if typeof(destinationId) ~= "string" then
		return
	end

	local normalized = string.lower(destinationId)
	if not DESTINATIONS[normalized] then
		return
	end

	if not teleportPlayer(player, normalized) then
		return
	end

	if normalized == "throw" then
		TutorialService.NotifyAction(player, "teleport_throw")
	elseif normalized == "throw_vip" then
		TutorialService.NotifyAction(player, "teleport_throw_vip")
	elseif normalized == "sell" then
		TutorialService.NotifyAction(player, "teleport_sell")
	elseif normalized == "shop" then
		TutorialService.NotifyAction(player, "teleport_shop")
	end
end)

local function openMapPicker(player: Player)
	local choices = PlaceConfig.GetPortalChoices()
	if #choices == 0 then
		return
	end

	local options = {}
	for _, id in ipairs(choices) do
		local locked = false
		local lockReason = ""
		if id == "map3" then
			local allowed, reason = canTravelToMap3(player)
			if not allowed then
				locked = true
				lockReason = reason
			end
		end
		table.insert(options, {
			Id = id,
			Label = PlaceConfig.GetMapLabel(id),
			Locked = locked,
			LockReason = lockReason,
		})
	end

	openMapPickerRemote:FireClient(player, {
		Type = "Picker",
		CurrentMap = PlaceConfig.GetMapKey(),
		Options = options,
	})
end

local function isMapPortalInstance(instance: Instance): boolean
	if CollectionService:HasTag(instance, PORTAL_STATION_TAG) then
		return true
	end
	if string.lower(instance.Name) == "portal" then
		return true
	end
	local dest = instance:GetAttribute("PortalDestination")
	if typeof(dest) == "string" then
		local lower = string.lower(dest)
		if lower == "picker" or lower == "map1" or lower == "map2" or lower == "map3" then
			return true
		end
	end
	return false
end

local function resolvePortalDestination(prompt: ProximityPrompt): string?
	local promptDest = prompt:GetAttribute("PortalDestination")
	if typeof(promptDest) == "string" and string.lower(promptDest) == "picker" then
		return "picker"
	end

	local current: Instance? = prompt.Parent
	while current and current ~= Workspace do
		if isMapPortalInstance(current) then
			return "picker"
		end
		current = current.Parent
	end

	return nil
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if resolvePortalDestination(prompt) then
		openMapPicker(player)
	end
end)

local function bindPortalPrompt(prompt: ProximityPrompt)
	if boundPortalPrompts[prompt] then
		return
	end

	boundPortalPrompts[prompt] = true
	prompt.Triggered:Connect(function(player)
		if resolvePortalDestination(prompt) then
			openMapPicker(player)
		end
	end)
end

local function bindPortalStation(station: Instance)
	for _, descendant in ipairs(station:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			bindPortalPrompt(descendant)
		end
	end

	local directPrompt = station:FindFirstChildOfClass("ProximityPrompt")
	if directPrompt then
		bindPortalPrompt(directPrompt)
	end

	local detector = station:FindFirstChildOfClass("ClickDetector")
	if detector and not boundPortalDetectors[detector] then
		boundPortalDetectors[detector] = true
		detector.MouseClick:Connect(function(player)
			openMapPicker(player)
		end)
	end
end

for _, station in ipairs(CollectionService:GetTagged(PORTAL_STATION_TAG)) do
	bindPortalStation(station)
end

CollectionService:GetInstanceAddedSignal(PORTAL_STATION_TAG):Connect(bindPortalStation)

Players.PlayerAdded:Connect(function(player)
	markArrivalFromTeleport(player)

	task.spawn(function()
		local deadline = os.clock() + 25
		while player.Parent and not PlayerDataService.IsLoaded(player) do
			if os.clock() >= deadline then
				return
			end
			task.wait(0.1)
		end
		if not player.Parent or not PlayerDataService.IsLoaded(player) then
			return
		end

		local joinData = player:GetJoinData()
		local teleportData = joinData.TeleportData
		local arrivedMap2 = PlaceConfig.IsMap2Place()
		local arrivedMap3 = PlaceConfig.IsMap3Place()
		if typeof(teleportData) == "table" then
			if teleportData.Destination == "map2" then
				arrivedMap2 = true
			end
			if teleportData.Destination == "map3" then
				arrivedMap3 = true
			end
		end

		if arrivedMap2 then
			tryUnlockMap2(player)
		end
		if arrivedMap3 then
			local allowed = canTravelToMap3(player)
			if allowed then
				tryUnlockMap3(player)
			end
		end
	end)

	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			applyArrivalSpawn(player, character)
		end)
	end)

	if player.Character then
		task.defer(function()
			applyArrivalSpawn(player, player.Character :: Model)
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastTeleportAt[player] = nil
	pendingArrivalSpawn[player] = nil
	pendingCrossPlaceTeleports[player] = nil
end)
