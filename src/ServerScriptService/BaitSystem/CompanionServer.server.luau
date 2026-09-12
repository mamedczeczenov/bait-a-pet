--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CompanionConfig = require(Modules:WaitForChild("CompanionConfig"))

local CompanionService = require(script.Parent:WaitForChild("CompanionService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local openRemote = remotes:WaitForChild("OpenSodaMachine") :: RemoteEvent
local fuseRemote = remotes:WaitForChild("FuseCompanion") :: RemoteEvent
local resultRemote = remotes:WaitForChild("SodaMachineResult") :: RemoteEvent
local setCompanionRemote = remotes:WaitForChild("SetCompanion") :: RemoteEvent
local companionResultRemote = remotes:WaitForChild("CompanionResult") :: RemoteEvent

local STATION_TAG = CompanionConfig.StationTag
local STATION_DISPLAY_NAME = CompanionConfig.StationDisplayName
local ACTION_COOLDOWN = 0.25
local lastActionAt: { [Player]: number } = {}
local boundPrompts: { [ProximityPrompt]: boolean } = {}
local readyPlayers: { [Player]: boolean } = {}

local function normalizeStationKey(value: string): string
	local lower = string.lower(value)
	lower = string.gsub(lower, "ó", "o")
	lower = string.gsub(lower, "%s+", " ")
	return string.gsub(lower, "^%s*(.-)%s*$", "%1")
end

local function isPetMachineName(name: string): boolean
	local key = normalizeStationKey(name)
	if key == "maszyna do petow"
		or key == "soda machine"
		or key == "sodamachine"
		or key == "sodamachineinteraction"
	then
		return true
	end
	for _, stationName in ipairs(CompanionConfig.StationNames) do
		if normalizeStationKey(stationName) == key then
			return true
		end
	end
	return false
end

local function buildSnapshot(player: Player, message: string?)
	local names = CompanionService.GetActiveNames(player)
	local petName = names[1] or ""
	local rarity = player:GetAttribute("CompanionRarity")
	return {
		Type = "Snapshot",
		Message = message,
		FuseCount = CompanionConfig.FuseCount,
		Options = CompanionService.ListFuseOptions(player),
		CompanionPetName = petName,
		CompanionPetName2 = names[2] or "",
		CompanionPetNames = names,
		CompanionWalkMax = CompanionService.GetMaxWalk(player),
		CompanionRarity = if typeof(rarity) == "string" then rarity else "",
		CompanionLuckMult = CompanionService.GetLuckMultiplier(player),
		CompanionSellMult = CompanionService.GetSellMultiplier(player),
		UnlockedCompanions = CompanionService.GetUnlocked(player),
	}
end

local function sendResult(player: Player, message: string?)
	resultRemote:FireClient(player, buildSnapshot(player, message))
end

local function sendError(player: Player, message: string)
	resultRemote:FireClient(player, {
		Type = "Error",
		Message = message,
		FuseCount = CompanionConfig.FuseCount,
		Options = CompanionService.ListFuseOptions(player),
		CompanionPetName = CompanionService.GetPetName(player),
		CompanionRarity = player:GetAttribute("CompanionRarity") or "",
		CompanionLuckMult = CompanionService.GetLuckMultiplier(player),
		CompanionSellMult = CompanionService.GetSellMultiplier(player),
		UnlockedCompanions = CompanionService.GetUnlocked(player),
	})
end

local function canAct(player: Player): boolean
	if not PlayerDataService.IsLoaded(player) then
		return false
	end
	local now = os.clock()
	local last = lastActionAt[player] or 0
	if now - last < ACTION_COOLDOWN then
		return false
	end
	lastActionAt[player] = now
	return true
end

local function openPanel(player: Player)
	if not PlayerDataService.IsLoaded(player) then
		return
	end
	openRemote:FireClient(player, buildSnapshot(player, nil))
end

local function isSodaPrompt(instance: Instance?): boolean
	local current = instance
	while current do
		if CollectionService:HasTag(current, STATION_TAG) then
			return true
		end
		if current:GetAttribute("IsSodaMachine") == true then
			return true
		end

		if isPetMachineName(current.Name) then
			return true
		end

		if current:IsA("ProximityPrompt") then
			local action = string.lower(current.ActionText)
			local objectText = string.lower(current.ObjectText)
			if string.find(action, "soda", 1, true)
				or string.find(objectText, "soda", 1, true)
				or string.find(action, "companion", 1, true)
				or string.find(objectText, "maszyna", 1, true)
				or string.find(objectText, "petow", 1, true)
				or string.find(objectText, "petów", 1, true)
			then
				return true
			end
		end

		current = current.Parent
	end
	return false
end

local function bindStation(station: Instance)
	if not station:IsA("BasePart") then
		return
	end

	local function bindPrompt(prompt: ProximityPrompt)
		if boundPrompts[prompt] then
			return
		end
		boundPrompts[prompt] = true
		prompt.ActionText = "Use Machine"
		prompt.ObjectText = STATION_DISPLAY_NAME
		prompt:SetAttribute("IsSodaMachine", true)
		prompt.Triggered:Connect(function(player)
			openPanel(player)
		end)
	end

	local directPrompt = station:FindFirstChildOfClass("ProximityPrompt")
	if directPrompt then
		bindPrompt(directPrompt)
	end
	for _, descendant in ipairs(station:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			bindPrompt(descendant)
		end
	end
end

fuseRemote.OnServerEvent:Connect(function(player, petName)
	if not canAct(player) then
		return
	end
	if typeof(petName) ~= "string" then
		sendError(player, "Pick a pet to fuse.")
		return
	end

	local ok, message = CompanionService.Fuse(player, petName)
	if ok then
		sendResult(player, message)
		companionResultRemote:FireClient(player, {
			Type = "Snapshot",
			Message = message,
			CompanionPetName = CompanionService.GetPetName(player),
			UnlockedCompanions = CompanionService.GetUnlocked(player),
		})
	else
		sendError(player, message)
	end
end)

setCompanionRemote.OnServerEvent:Connect(function(player, petName)
	if not canAct(player) then
		return
	end
	if typeof(petName) ~= "string" then
		companionResultRemote:FireClient(player, {
			Type = "Error",
			Message = "Pick a companion.",
			CompanionPetName = CompanionService.GetPetName(player),
			UnlockedCompanions = CompanionService.GetUnlocked(player),
		})
		return
	end

	local ok, message = CompanionService.SetActive(player, petName)
	local names = CompanionService.GetActiveNames(player)
	companionResultRemote:FireClient(player, {
		Type = if ok then "Snapshot" else "Error",
		Message = message,
		CompanionPetName = names[1] or "",
		CompanionPetName2 = names[2] or "",
		CompanionPetNames = names,
		CompanionWalkMax = CompanionService.GetMaxWalk(player),
		UnlockedCompanions = CompanionService.GetUnlocked(player),
	})
end)

for _, station in ipairs(CollectionService:GetTagged(STATION_TAG)) do
	bindStation(station)
end
CollectionService:GetInstanceAddedSignal(STATION_TAG):Connect(bindStation)

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	-- Skip prompts already handled by bindPrompt to avoid double-opening the UI.
	if boundPrompts[prompt] then
		return
	end
	if isSodaPrompt(prompt) then
		prompt.ActionText = "Use Machine"
		prompt.ObjectText = STATION_DISPLAY_NAME
		boundPrompts[prompt] = true
		openPanel(player)
	end
end)

local function waitUntilLoaded(player: Player)
	local deadline = os.clock() + 30
	while player.Parent and not PlayerDataService.IsLoaded(player) and os.clock() < deadline do
		task.wait(0.1)
	end
	if player.Parent and PlayerDataService.IsLoaded(player) and not readyPlayers[player] then
		readyPlayers[player] = true
		CompanionService.OnPlayerReady(player)
	end
end

local function bindPlayer(player: Player)
	player.CharacterAdded:Connect(function()
		if PlayerDataService.IsLoaded(player) then
			CompanionService.OnCharacterAdded(player)
		end
	end)
	task.spawn(waitUntilLoaded, player)
end

Players.PlayerAdded:Connect(bindPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	bindPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	lastActionAt[player] = nil
	readyPlayers[player] = nil
	CompanionService.Cleanup(player)
end)
