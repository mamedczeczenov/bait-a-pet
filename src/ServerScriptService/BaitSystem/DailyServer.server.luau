--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local DailyService = require(script.Parent:WaitForChild("DailyService"))

local dailyRemote = DailyService.EnsureRemote()

local lastActionAt: { [Player]: number } = {}
local ACTION_COOLDOWN = 0.35

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

local function onPlayerReady(player: Player)
	local deadline = os.clock() + 20
	while os.clock() < deadline and not PlayerDataService.IsLoaded(player) do
		task.wait(0.1)
	end
	if not PlayerDataService.IsLoaded(player) then
		return
	end

	DailyService.PushSnapshot(player, nil)
end

dailyRemote.OnServerEvent:Connect(function(player, payload)
	if typeof(payload) ~= "table" then
		return
	end
	if not canAct(player) then
		return
	end

	local payloadType = payload.Type
	if payloadType == "Ready" then
		DailyService.PushSnapshot(player, nil)
		return
	end

	if payloadType == "Claim" then
		local ok, err = DailyService.Claim(player)
		if not ok and err then
			DailyService.PushSnapshot(player, err)
		end
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
end)

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if remotes then
	DailyService.EnsureRemote()
end
