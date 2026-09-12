--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local PetCatalogService = require(script.Parent:WaitForChild("PetCatalogService"))
local IndexService = require(script.Parent:WaitForChild("IndexService"))

local indexRemote = IndexService.EnsureRemote()

local lastActionAt: { [Player]: number } = {}
local ACTION_COOLDOWN = 0.25

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

	pcall(function()
		PetCatalogService.Initialize()
	end)
	IndexService.PushSnapshot(player, nil)
end

indexRemote.OnServerEvent:Connect(function(player, payload)
	if typeof(payload) ~= "table" then
		return
	end
	if not canAct(player) then
		return
	end

	local payloadType = payload.Type
	if payloadType == "Ready" then
		pcall(function()
			PetCatalogService.Initialize()
		end)
		IndexService.PushSnapshot(player, nil)
		return
	end

	if payloadType == "Claim" then
		local petName = payload.PetName
		if typeof(petName) ~= "string" then
			return
		end
		local ok, err = IndexService.Claim(player, petName)
		if not ok and err then
			IndexService.PushSnapshot(player, err)
		end
		return
	end

	if payloadType == "ClaimMilestone" then
		local milestoneId = payload.MilestoneId
		if typeof(milestoneId) ~= "string" then
			return
		end
		local ok, err = IndexService.ClaimMilestone(player, milestoneId)
		if not ok and err then
			IndexService.PushSnapshot(player, err)
		end
		return
	end

	if payloadType == "ClaimAll" then
		local ok, err = IndexService.ClaimAll(player)
		if not ok and err then
			IndexService.PushSnapshot(player, err)
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

task.defer(function()
	pcall(function()
		PetCatalogService.Initialize()
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		if PlayerDataService.IsLoaded(player) then
			IndexService.PushSnapshot(player, nil)
		end
	end
end)

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if remotes then
	IndexService.EnsureRemote()
end
