--!strict

--[[
	Fallback only: server mounts SurfaceGuis on the map parts.
	If Rojo didn't sync the server script, this still tries locally.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules", 15)
if not Modules then
	warn("[LeaderboardClient] ReplicatedStorage.Modules missing")
	return
end

local configModule = Modules:WaitForChild("LeaderboardConfig", 10)
local boardModule = Modules:WaitForChild("LeaderboardBoard", 10)
if not configModule or not boardModule then
	warn("[LeaderboardClient] LeaderboardConfig/LeaderboardBoard missing — sync Rojo to Studio.")
	return
end

local LeaderboardConfig = require(configModule)
local LeaderboardBoard = require(boardModule)

local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
if remotes then
	local remote = remotes:WaitForChild("Leaderboards", 10)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer({ Type = "Ready" })
	end
end

local function hasMountedGui(): boolean
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("SurfaceGui") and string.find(descendant.Name, LeaderboardConfig.GuiNamePrefix, 1, true) == 1 then
			return true
		end
	end
	return false
end

task.delay(4, function()
	if hasMountedGui() then
		return
	end

	warn("[LeaderboardClient] Server did not mount boards — trying locally.")
	warn(LeaderboardConfig.DebugDump())

	local found = LeaderboardConfig.FindBoards()
	for _, target in ipairs(found) do
		LeaderboardBoard.Mount(target)
		print("[LeaderboardClient] Local mount", target.Kind, target.Part:GetFullName())
	end
end)
