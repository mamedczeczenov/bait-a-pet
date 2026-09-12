--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local BaitConfig = require(Modules:WaitForChild("BaitConfig"))
local LuckConfig = require(Modules:WaitForChild("LuckConfig"))
local PityConfig = require(Modules:WaitForChild("PityConfig"))
local CaveConfig = require(Modules:WaitForChild("CaveConfig"))
local PlaceConfig = require(Modules:WaitForChild("PlaceConfig"))

local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local PetService = require(script.Parent:WaitForChild("PetService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local TutorialService = require(script.Parent:WaitForChild("TutorialService"))
local GoalService = require(script.Parent:WaitForChild("GoalService"))
local EventService = require(script.Parent:WaitForChild("EventService"))
local CompanionService = require(script.Parent:WaitForChild("CompanionService"))
local PotionService = require(script.Parent:WaitForChild("PotionService"))
local GiftService = require(script.Parent:WaitForChild("GiftService"))

-- Never deadlock if BaitBootstrap is late / failed: create remotes here too.
local function ensureRemoteEvent(folder: Folder, name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder or not remotesFolder:IsA("Folder") then
	if remotesFolder then
		remotesFolder:Destroy()
	end
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end
local remotes = remotesFolder :: Folder
local startBaitRemote = ensureRemoteEvent(remotes, "StartBait")
local submitLuckRemote = ensureRemoteEvent(remotes, "SubmitLuck")
local petResultRemote = ensureRemoteEvent(remotes, "PetResult")
local selectBaitRemote = ensureRemoteEvent(remotes, "SelectBait")
local requestThrowRemote = ensureRemoteEvent(remotes, "RequestThrow")

type PlayerState = {
	AwaitingLuck: boolean,
	IsThrowing: boolean,
	LastPromptAt: number,
	LastSubmitAt: number,
	LastCatchAt: number,
	CatchOrigin: CFrame?,
	CatchZone: BasePart?,
	CaveLuckMult: number,
}

local playerStates: { [Player]: PlayerState } = {}

local PROMPT_COOLDOWN = 0.25
local SUBMIT_COOLDOWN = 0.25
local SELECT_COOLDOWN = 0.15
local lastSelectAt: { [Player]: number } = {}

local function getState(player: Player): PlayerState
	local existingState = playerStates[player]
	if existingState then
		return existingState
	end

	local newState: PlayerState = {
		AwaitingLuck = false,
		IsThrowing = false,
		LastPromptAt = 0,
		LastSubmitAt = 0,
		LastCatchAt = 0,
		CatchOrigin = nil,
		CatchZone = nil,
		CaveLuckMult = 1,
	}

	playerStates[player] = newState
	return newState
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

local function getCatchCooldownForPlayer(player: Player): number
	local upgradeSpeed = PlayerDataService.GetCatchSpeedBonus(player)
	return BaitConfig.GetCatchCooldown(PlayerDataService.GetActiveBaitId(player), upgradeSpeed)
end

local function getCooldownRemaining(player: Player): number
	local state = getState(player)
	local remaining = getCatchCooldownForPlayer(player) - (os.clock() - state.LastCatchAt)
	return math.max(0, remaining)
end

local function setCooldownAttribute(player: Player)
	local remaining = getCooldownRemaining(player)
	if remaining > 0 then
		player:SetAttribute("CatchCooldownUntil", Workspace:GetServerTimeNow() + remaining)
	else
		player:SetAttribute("CatchCooldownUntil", 0)
	end
end

local function sendError(player: Player, message: string)
	petResultRemote:FireClient(player, {
		Type = "Error",
		Message = message,
		ActiveBait = getActiveBaitPayload(player),
		CooldownRemaining = getCooldownRemaining(player),
	})
end

local function openLuckBar(player: Player)
	startBaitRemote:FireClient(player, {
		Type = "OpenLuckBar",
		ActiveBait = getActiveBaitPayload(player),
	})
end

local function getNearestCatchZone(rootPosition: Vector3): (BasePart?, number)
	local zones: { BasePart } = {}
	for _, zone in ipairs(CollectionService:GetTagged(BaitConfig.CatchZoneTag)) do
		if zone:IsA("BasePart") and zone.Parent then
			table.insert(zones, zone)
		end
	end
	return CaveConfig.ChooseThrowZone(rootPosition, zones)
end

local function getCatchOriginFromZone(zone: BasePart): CFrame
	local throwPoint = zone.Parent
	if throwPoint and throwPoint:IsA("BasePart") then
		return throwPoint.CFrame + Vector3.new(0, 2, 0)
	end

	return zone.CFrame
end

local function initializePlayer(player: Player)
	player:SetAttribute("IsThrowing", false)
	player:SetAttribute("CatchCooldownUntil", 0)

	local state = getState(player)
	state.AwaitingLuck = false
	state.IsThrowing = false
	state.LastPromptAt = 0
	state.LastSubmitAt = 0
	state.LastCatchAt = 0
	state.CatchOrigin = nil
	state.CatchZone = nil
	state.CaveLuckMult = 1

	local ok, err = pcall(function()
		PlayerDataService.Load(player)
	end)
	if not ok then
		warn(string.format("[BaitServer] Load failed for %s: %s", player.Name, tostring(err)))
	end
	if not PlayerDataService.IsLoaded(player) then
		PlayerDataService.ForceLoadDefaults(player)
	end
	print(string.format("[BaitServer] Player ready: %s (loaded=%s)", player.Name, tostring(PlayerDataService.IsLoaded(player))))
end

local function clearPlayerState(player: Player)
	playerStates[player] = nil
	lastSelectAt[player] = nil
	PlayerDataService.Cleanup(player)
	InventoryService.CleanupPlayer(player)
end

local function ensurePlayerLoaded(player: Player): boolean
	if PlayerDataService.IsLoaded(player) then
		return true
	end
	pcall(function()
		PlayerDataService.Load(player)
	end)
	if not PlayerDataService.IsLoaded(player) then
		PlayerDataService.ForceLoadDefaults(player)
	end
	return PlayerDataService.IsLoaded(player)
end

local function canStartThrow(player: Player): (boolean, string?, BasePart?)
	local state = getState(player)

	if PlaceConfig.IsAfkPlace() then
		return false, "AFK lobby — cave throws are disabled.", nil
	end

	if not ensurePlayerLoaded(player) then
		return false, "Still loading...", nil
	end

	if state.IsThrowing or state.AwaitingLuck then
		return false, "You are already throwing bait.", nil
	end

	local cooldownRemaining = getCooldownRemaining(player)
	if cooldownRemaining > 0 then
		return false, string.format("Wait %.1fs before catching again.", cooldownRemaining), nil
	end

	if PlayerDataService.IsBagFull(player) then
		local capacity = PlayerDataService.GetBagCapacity(player)
		return false, string.format("Bag full (%d/%d) — sell pets or upgrade bag.", capacity, capacity), nil
	end

	local baitId = PlayerDataService.GetActiveBaitId(player)
	if not PlayerDataService.HasBaitUnlocked(player, baitId) then
		return false, "You don't have any bait unlocked!", nil
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false, "Character not ready.", nil
	end

	local zone = getNearestCatchZone(root.Position)
	if not zone then
		return false, "Stand at spawn or near a cave to throw bait.", nil
	end

	local caveType = CaveConfig.ResolveTypeFromZone(zone)
	if CaveConfig.RequiresVip(caveType) and not PlayerDataService.HasVipAccess(player) then
		return false, CaveConfig.VipLockedMessage, nil
	end

	local now = os.clock()
	if now - state.LastPromptAt < PROMPT_COOLDOWN then
		return false, nil, nil
	end

	state.LastPromptAt = now
	return true, nil, zone
end

local function handleThrowRequest(player: Player)
	local allowed, reason, zone = canStartThrow(player)
	if not allowed then
		if reason then
			sendError(player, reason)
		end
		return
	end

	local state = getState(player)
	state.AwaitingLuck = true
	state.CatchOrigin = if zone then getCatchOriginFromZone(zone) else nil
	state.CatchZone = zone
	state.CaveLuckMult = PlayerDataService.GetCaveLuckMultiplier(player, zone)
	openLuckBar(player)
end

local function resolveThrow(player: Player, position: number)
	local state = getState(player)
	state.AwaitingLuck = false
	state.IsThrowing = true
	player:SetAttribute("IsThrowing", true)

	local activeBait = getActiveBaitPayload(player)

	petResultRemote:FireClient(player, {
		Type = "ThrowAccepted",
		ActiveBait = activeBait,
	})
	TutorialService.NotifyAction(player, "throw_started")

	if not player.Parent then
		return
	end

	local barLuck = LuckConfig.GetLuckMultiplier(position)
	local luckBonus = PlayerDataService.GetLuckBonus(player)
	local baitLuck = activeBait.LuckMultiplier
	local buffLuck = GoalService.GetLuckBuffMultiplier(player)
	local companionLuck = CompanionService.GetLuckMultiplier(player)
	local caveLuck = if state.CaveLuckMult > 0 then state.CaveLuckMult else 1
	local eventLuck = EventService.GetLuckMultiplier()
	local potionLuck = PotionService.GetLuckMultiplier(player)
	local giftLuck = GiftService.GetLuckMultiplier(player)
	local luckMultiplier = barLuck * luckBonus * baitLuck * buffLuck * companionLuck * caveLuck * eventLuck * potionLuck * giftLuck
	local pityFails = PlayerDataService.GetEpicPityFails(player)
	local pityMult = PityConfig.GetWeightMultiplier(pityFails)
	local pet = PetService.RollPet(luckMultiplier, pityMult)
	local catchTag = EventService.GetCatchTag()
	local inventoryCount = InventoryService.AddPet(player, pet.Name, catchTag)
	PlayerDataService.SyncBagAttributes(player)
	local isNew = PlayerDataService.MarkPetDiscovered(player, pet.Name)
	if isNew then
		task.defer(function()
			local IndexService = require(script.Parent:WaitForChild("IndexService"))
			IndexService.TryGrantMap3FromIndex(player)
		end)
	end
	PlayerDataService.RegisterCatchForPity(player, pet.Rarity)

	local origin = state.CatchOrigin
	if not origin then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local zone = getNearestCatchZone(root.Position)
			if zone then
				origin = getCatchOriginFromZone(zone)
			end
		end
	end

	PetService.SpawnReveal(player, pet.Name, origin, catchTag)
	PlayerDataService.MarkDirty(player)
	GoalService.ConsumeLuckBuffCatch(player)
	GoalService.OnPetCaught(player, pet.Rarity)

	state.LastCatchAt = os.clock()
	state.CatchOrigin = nil
	state.CatchZone = nil
	state.CaveLuckMult = 1
	setCooldownAttribute(player)

	local bagCapacity = PlayerDataService.GetBagCapacity(player)
	local almostFull = PlayerDataService.IsBagAlmostFull(player)
	if almostFull then
		if player:GetAttribute("BagWarnArmed") ~= true then
			player:SetAttribute("BagWarnArmed", true)
			petResultRemote:FireClient(player, {
				Type = "BagWarn",
				Message = string.format(
					"Bag almost full (%d/%d) — sell pets or upgrade bag.",
					inventoryCount,
					bagCapacity
				),
			})
		end
	else
		player:SetAttribute("BagWarnArmed", false)
	end

	petResultRemote:FireClient(player, {
		Type = "Result",
		ActiveBait = activeBait,
		PetName = pet.Name,
		Rarity = pet.Rarity,
		LuckMultiplier = luckMultiplier,
		BaitLuck = baitLuck,
		CaveLuck = caveLuck,
		EventLuck = eventLuck,
		EventTag = catchTag,
		InventoryCount = inventoryCount,
		BagCapacity = bagCapacity,
		CooldownRemaining = getCatchCooldownForPlayer(player),
		IsNew = isNew,
		LuckBuffCatches = player:GetAttribute("LuckBuffCatches"),
		LuckBuffMult = player:GetAttribute("LuckBuffMult"),
	})
	TutorialService.NotifyAction(player, "catch_pet")

	state.IsThrowing = false
	player:SetAttribute("IsThrowing", false)
end

local function isValidLuckPosition(position: any): boolean
	if typeof(position) ~= "number" then
		return false
	end

	if position ~= position then
		return false
	end

	return position >= 0 and position <= 1
end

requestThrowRemote.OnServerEvent:Connect(handleThrowRequest)

submitLuckRemote.OnServerEvent:Connect(function(player, position)
	local state = getState(player)
	local now = os.clock()

	if now - state.LastSubmitAt < SUBMIT_COOLDOWN then
		return
	end

	state.LastSubmitAt = now

	if not state.AwaitingLuck or state.IsThrowing then
		sendError(player, "No bait throw is ready right now.")
		return
	end

	local baitId = PlayerDataService.GetActiveBaitId(player)
	if not PlayerDataService.HasBaitUnlocked(player, baitId) then
		state.AwaitingLuck = false
		state.CatchOrigin = nil
		state.CatchZone = nil
		state.CaveLuckMult = 1
		sendError(player, "You don't have any bait unlocked!")
		return
	end

	if not isValidLuckPosition(position) then
		state.AwaitingLuck = false
		state.CatchOrigin = nil
		state.CatchZone = nil
		state.CaveLuckMult = 1
		sendError(player, "Invalid luck value submitted.")
		return
	end

	-- Re-validate catch zone distance / VIP so clients cannot skip the throw gate.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		state.AwaitingLuck = false
		state.CatchOrigin = nil
		state.CatchZone = nil
		state.CaveLuckMult = 1
		sendError(player, "Character not ready.")
		return
	end

	local zone = getNearestCatchZone(root.Position)
	if not zone then
		state.AwaitingLuck = false
		state.CatchOrigin = nil
		state.CatchZone = nil
		state.CaveLuckMult = 1
		sendError(player, "Stand at spawn or near a cave to throw bait.")
		return
	end

	local caveType = CaveConfig.ResolveTypeFromZone(zone)
	if CaveConfig.RequiresVip(caveType) and not PlayerDataService.HasVipAccess(player) then
		state.AwaitingLuck = false
		state.CatchOrigin = nil
		state.CatchZone = nil
		state.CaveLuckMult = 1
		sendError(player, CaveConfig.VipLockedMessage)
		return
	end

	state.CatchZone = zone
	state.CatchOrigin = getCatchOriginFromZone(zone)
	state.CaveLuckMult = PlayerDataService.GetCaveLuckMultiplier(player, zone)

	local luckPosition = position :: number
	resolveThrow(player, luckPosition)
end)

selectBaitRemote.OnServerEvent:Connect(function(player, baitId)
	if not PlayerDataService.IsLoaded(player) then
		return
	end

	if typeof(baitId) ~= "string" then
		return
	end

	local now = os.clock()
	local last = lastSelectAt[player] or 0
	if now - last < SELECT_COOLDOWN then
		return
	end
	lastSelectAt[player] = now

	local ok, err = PlayerDataService.SetActiveBait(player, baitId)
	if not ok then
		sendError(player, err or "Could not select bait.")
	end
end)

Players.PlayerAdded:Connect(initializePlayer)
Players.PlayerRemoving:Connect(clearPlayerState)

game:BindToClose(function()
	PlayerDataService.BindToClose()
end)

for _, player in Players:GetPlayers() do
	task.spawn(initializePlayer, player)
end
