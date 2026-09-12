--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CatchFeelConfig = require(Modules:WaitForChild("CatchFeelConfig"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local updateSettingsRemote = remotes:WaitForChild("UpdateSettings") :: RemoteEvent

local lastActionAt: { [Player]: number } = {}
local ACTION_COOLDOWN = 0.2

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

updateSettingsRemote.OnServerEvent:Connect(function(player, payload)
	if not canAct(player) then
		return
	end
	if typeof(payload) ~= "table" then
		return
	end

	if payload.Type == "CelebrationMinRarity" then
		local rarity = payload.Value
		if typeof(rarity) ~= "string" then
			return
		end
		PlayerDataService.SetCelebrationMinRarity(player, CatchFeelConfig.NormalizeMinRarity(rarity))
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastActionAt[player] = nil
end)
