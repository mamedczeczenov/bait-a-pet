--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GiftService = require(script.Parent:WaitForChild("GiftService"))

local giftsRemote = GiftService.EnsureRemote()

local lastActionAt: { [Player]: number } = {}
local ACTION_COOLDOWN = 0.35

local function canAct(player: Player): boolean
	local now = os.clock()
	local last = lastActionAt[player] or 0
	if now - last < ACTION_COOLDOWN then
		return false
	end
	lastActionAt[player] = now
	return true
end

local function onPlayerReady(player: Player)
	GiftService.StartForPlayer(player)
	GiftService.PushSnapshot(player)
end

giftsRemote.OnServerEvent:Connect(function(player, payload)
	if typeof(payload) ~= "table" then
		return
	end
	if not canAct(player) then
		return
	end

	local payloadType = payload.Type
	if payloadType == "Ready" then
		GiftService.StartForPlayer(player)
		GiftService.PushSnapshot(player)
		return
	end

	if payloadType == "Claim" then
		GiftService.Claim(player, payload.Tier)
		return
	end
end)

Players.PlayerAdded:Connect(function(player)
	task.defer(onPlayerReady, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(onPlayerReady, player)
end

Players.PlayerRemoving:Connect(function(player)
	lastActionAt[player] = nil
	GiftService.Clear(player)
end)

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if remotes then
	GiftService.EnsureRemote()
end
