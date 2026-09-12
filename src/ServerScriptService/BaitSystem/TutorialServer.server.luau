--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local TutorialService = require(script.Parent:WaitForChild("TutorialService"))

local tutorialRemote = TutorialService.EnsureRemote()

local function waitUntilLoaded(player: Player, timeoutSeconds: number): boolean
	local deadline = os.clock() + timeoutSeconds
	while os.clock() < deadline do
		if PlayerDataService.IsLoaded(player) then
			return true
		end
		task.wait(0.1)
	end
	return PlayerDataService.IsLoaded(player)
end

local function onPlayerReady(player: Player)
	if not waitUntilLoaded(player, 20) then
		return
	end

	TutorialService.SyncPlayer(player)
	TutorialService.ScheduleAutoStart(player)
end

tutorialRemote.OnServerEvent:Connect(function(player, payload)
	if typeof(payload) ~= "table" then
		return
	end

	local payloadType = payload.Type
	if typeof(payloadType) ~= "string" then
		return
	end

	if not PlayerDataService.IsLoaded(player) then
		return
	end

	if payloadType == "Ready" then
		TutorialService.PushState(player)
		return
	end

	if payloadType == "Skip" then
		TutorialService.Skip(player)
		return
	end

	if payloadType == "Replay" then
		TutorialService.Replay(player)
		return
	end

	if payloadType == "Reset" then
		if RunService:IsStudio() then
			TutorialService.Reset(player)
			TutorialService.ScheduleAutoStart(player)
		end
		return
	end
end)

Players.PlayerAdded:Connect(function(player)
	task.defer(onPlayerReady, player)
	player.Chatted:Connect(function(message)
		local trimmed = string.lower(string.gsub(message, "^%s+", ""))
		if trimmed == "/resettutorial" and RunService:IsStudio() then
			TutorialService.Reset(player)
			TutorialService.ScheduleAutoStart(player)
		end
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(onPlayerReady, player)
	player.Chatted:Connect(function(message)
		local trimmed = string.lower(string.gsub(message, "^%s+", ""))
		if trimmed == "/resettutorial" and RunService:IsStudio() then
			TutorialService.Reset(player)
			TutorialService.ScheduleAutoStart(player)
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	TutorialService.Cleanup(player)
end)

-- Ensure remote exists even if bootstrap order changes.
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if remotes then
	TutorialService.EnsureRemote()
end
