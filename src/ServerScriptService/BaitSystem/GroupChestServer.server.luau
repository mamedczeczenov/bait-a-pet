--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GroupChestConfig = require(Modules:WaitForChild("GroupChestConfig"))

local GroupChestService = require(script.Parent:WaitForChild("GroupChestService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local STATION_TAG = GroupChestConfig.StationTag
local ACTION_COOLDOWN = 0.4
local lastActionAt: { [Player]: number } = {}
local boundPrompts: { [ProximityPrompt]: boolean } = {}

local groupChestRemote = GroupChestService.EnsureRemote()

local function canAct(player: Player): boolean
	if not PlayerDataService.IsLoaded(player) then
		GroupChestService.Push(player, "Error", GroupChestConfig.LoadingMessage)
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

local function tryOpen(player: Player)
	if not PlayerDataService.IsLoaded(player) then
		GroupChestService.Push(player, "Error", GroupChestConfig.LoadingMessage)
		return
	end
	GroupChestService.Open(player)
end

local function tryClaim(player: Player)
	if not canAct(player) then
		return
	end
	local _ok, kind, message = GroupChestService.Claim(player)
	GroupChestService.Push(player, kind, message)
end

local function isGroupChestPrompt(instance: Instance?): boolean
	local current = instance
	while current do
		if CollectionService:HasTag(current, STATION_TAG) then
			return true
		end
		if current:GetAttribute("IsGroupChest") == true then
			return true
		end
		if current:IsA("ProximityPrompt") then
			local objectText = string.lower(current.ObjectText)
			if GroupChestConfig.IsMarker(current.ObjectText) or string.find(objectText, "vip chest", 1, true) then
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
		prompt.ActionText = GroupChestConfig.ActionText
		prompt.ObjectText = GroupChestConfig.ObjectText
		prompt:SetAttribute("IsGroupChest", true)
		prompt.Triggered:Connect(tryOpen)
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

for _, station in ipairs(CollectionService:GetTagged(STATION_TAG)) do
	bindStation(station)
end
CollectionService:GetInstanceAddedSignal(STATION_TAG):Connect(bindStation)

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if boundPrompts[prompt] then
		return
	end
	if isGroupChestPrompt(prompt) then
		prompt.ActionText = GroupChestConfig.ActionText
		prompt.ObjectText = GroupChestConfig.ObjectText
		boundPrompts[prompt] = true
		tryOpen(player)
	end
end)

groupChestRemote.OnServerEvent:Connect(function(player, action)
	if typeof(action) ~= "string" or action ~= "Claim" then
		return
	end
	tryClaim(player)
end)

Players.PlayerRemoving:Connect(function(player)
	lastActionAt[player] = nil
end)
