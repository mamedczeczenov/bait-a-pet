--!strict

local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GroupChestConfig = require(Modules:WaitForChild("GroupChestConfig"))
local NumberFormat = require(Modules:WaitForChild("NumberFormat"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

export type ClaimKind = "Open" | "Claimed" | "NeedGroup" | "AlreadyClaimed" | "Error"

local GroupChestService = {}

local remote: RemoteEvent? = nil
local cachedGroupName = "Group"
local groupNameLoaded = false

local function getRemote(): RemoteEvent
	if remote and remote.Parent then
		return remote
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local existing = remotes:FindFirstChild("GroupChest")
	if existing and existing:IsA("RemoteEvent") then
		remote = existing
		return existing
	end

	local created = Instance.new("RemoteEvent")
	created.Name = "GroupChest"
	created.Parent = remotes
	remote = created
	return created
end

function GroupChestService.EnsureRemote(): RemoteEvent
	return getRemote()
end

local function ensureGroupName()
	if groupNameLoaded then
		return
	end
	groupNameLoaded = true
	task.spawn(function()
		local ok, info = pcall(function()
			return GroupService:GetGroupInfoAsync(GroupChestConfig.GroupId)
		end)
		if ok and typeof(info) == "table" and typeof(info.Name) == "string" and info.Name ~= "" then
			cachedGroupName = info.Name
		end
	end)
end

local function isInConfiguredGroup(player: Player): (boolean, string?)
	local ok, result = pcall(function()
		return player:IsInGroup(GroupChestConfig.GroupId)
	end)
	if not ok then
		return false, GroupChestConfig.CheckFailedMessage
	end
	return result == true, nil
end

function GroupChestService.BuildPayload(player: Player, kind: ClaimKind, message: string?): { [string]: any }
	ensureGroupName()
	local claimed = PlayerDataService.HasGroupChestClaimed(player)
	local inGroup, checkError = isInConfiguredGroup(player)
	local coins = math.max(0, math.floor(GroupChestConfig.RewardCoins))
	return {
		Type = kind,
		Message = message,
		GroupId = GroupChestConfig.GroupId,
		GroupName = cachedGroupName,
		GroupIcon = GroupChestConfig.GroupIcon,
		ItemName = GroupChestConfig.ItemName,
		RewardCoins = coins,
		Claimed = claimed,
		InGroup = inGroup == true,
		CheckError = checkError,
	}
end

function GroupChestService.Push(player: Player, kind: ClaimKind, message: string?)
	getRemote():FireClient(player, GroupChestService.BuildPayload(player, kind, message))
end

function GroupChestService.Open(player: Player): (boolean, string?)
	if not PlayerDataService.IsLoaded(player) then
		return false, GroupChestConfig.LoadingMessage
	end
	GroupChestService.Push(player, "Open", nil)
	return true, nil
end

function GroupChestService.Claim(player: Player): (boolean, ClaimKind, string)
	if not PlayerDataService.IsLoaded(player) then
		return false, "Error", GroupChestConfig.LoadingMessage
	end

	if PlayerDataService.HasGroupChestClaimed(player) then
		return false, "AlreadyClaimed", GroupChestConfig.AlreadyClaimedMessage
	end

	local inGroup, checkError = isInConfiguredGroup(player)
	if checkError then
		return false, "Error", checkError
	end
	if not inGroup then
		return false, "NeedGroup", GroupChestConfig.NeedGroupMessage
	end

	local coins = math.max(0, math.floor(GroupChestConfig.RewardCoins))
	if coins > 0 then
		PlayerDataService.AddCoins(player, coins)
	end
	PlayerDataService.MarkGroupChestClaimed(player)

	return true, "Claimed", string.format(
		GroupChestConfig.ClaimedMessage,
		NumberFormat.FormatCoins(coins)
	)
end

ensureGroupName()

return GroupChestService
