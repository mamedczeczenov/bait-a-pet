--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local LeaderboardConfig = require(Modules:WaitForChild("LeaderboardConfig"))
local LeaderboardBoard = require(Modules:WaitForChild("LeaderboardBoard"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))

local remote = LeaderboardService.EnsureRemote()

local cashDirtyAt: { [Player]: number } = {}
local lastCashUpdateAt: { [Player]: number } = {}
local coinSignals: { [Player]: RBXScriptConnection } = {}
local mountedKind: { [BasePart]: LeaderboardConfig.BoardKind } = {}
local dumpedOnce = false

local lastSnapshot: LeaderboardService.Snapshot = {
	Playtime = {},
	Cash = {},
}
local lastFetchAt = 0

local function paintMounted()
	for part, kind in pairs(mountedKind) do
		if part.Parent then
			local entries = if kind == "playtime" then lastSnapshot.Playtime else lastSnapshot.Cash
			LeaderboardBoard.PaintPart(part, kind, entries)
		else
			mountedKind[part] = nil
		end
	end
end

local function mountBoards(): number
	local found = LeaderboardConfig.FindBoards()
	for _, target in ipairs(found) do
		if not mountedKind[target.Part] then
			LeaderboardBoard.Mount(target)
			mountedKind[target.Part] = target.Kind
			print(string.format(
				"[LeaderboardServer] Mounted %s on %s faces=%s",
				target.Kind,
				target.Part:GetFullName(),
				tostring(target.Faces[1])
			))
		end
	end

	if #found == 0 and not dumpedOnce then
		dumpedOnce = true
		warn(LeaderboardConfig.DebugDump())
	end

	paintMounted()
	return #found
end

local function refreshBoards(updatePlayers: boolean)
	if updatePlayers then
		for _, player in ipairs(Players:GetPlayers()) do
			if PlayerDataService.CanPersist(player) then
				PlayerDataService.FlushPlaytime(player)
				PlayerDataService.MarkDirty(player)
				LeaderboardService.UpdatePlayer(player)
			end
		end
	end
	lastSnapshot = LeaderboardService.FetchSnapshot()
	lastFetchAt = os.clock()
	LeaderboardService.PushSnapshot(nil, lastSnapshot)
	mountBoards()
end

local function waitUntilLoaded(player: Player)
	local deadline = os.clock() + 25
	while os.clock() < deadline and not PlayerDataService.IsLoaded(player) do
		task.wait(0.1)
	end
end

local function bindCoins(player: Player)
	local existing = coinSignals[player]
	if existing then
		existing:Disconnect()
	end
	coinSignals[player] = player:GetAttributeChangedSignal("Coins"):Connect(function()
		if PlayerDataService.CanPersist(player) then
			cashDirtyAt[player] = os.clock()
		end
	end)
end

local function onPlayerReady(player: Player)
	waitUntilLoaded(player)
	if not player.Parent then
		return
	end

	bindCoins(player)
	if PlayerDataService.CanPersist(player) then
		task.spawn(function()
			LeaderboardService.UpdatePlayer(player)
		end)
	end
	LeaderboardService.PushSnapshot(player, lastSnapshot)
end

remote.OnServerEvent:Connect(function(player, payload)
	if typeof(payload) ~= "table" then
		return
	end
	if payload.Type == "Ready" then
		LeaderboardService.PushSnapshot(player, lastSnapshot)
	end
end)

Players.PlayerAdded:Connect(function(player)
	task.defer(onPlayerReady, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(onPlayerReady, player)
end

Players.PlayerRemoving:Connect(function(player)
	local conn = coinSignals[player]
	if conn then
		conn:Disconnect()
		coinSignals[player] = nil
	end
	cashDirtyAt[player] = nil
	lastCashUpdateAt[player] = nil
	if PlayerDataService.IsLoaded(player) then
		PlayerDataService.FlushPlaytime(player)
	end
	LeaderboardService.UpdatePlayer(player)
end)

Workspace.DescendantAdded:Connect(function(instance)
	if LeaderboardConfig.KindFromInstance(instance) then
		task.defer(mountBoards)
	end
end)

task.spawn(function()
	for _ = 1, 10 do
		if mountBoards() > 0 then
			break
		end
		task.wait(1)
	end
end)

task.spawn(function()
	while true do
		task.wait(1)

		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			if PlayerDataService.CanPersist(player) then
				local dirtyAt = cashDirtyAt[player]
				if dirtyAt and (now - dirtyAt) >= LeaderboardConfig.CashDebounceSeconds then
					local last = lastCashUpdateAt[player] or 0
					if now - last >= LeaderboardConfig.CashDebounceSeconds then
						cashDirtyAt[player] = nil
						lastCashUpdateAt[player] = now
						task.spawn(function()
							LeaderboardService.UpdatePlayer(player)
						end)
					end
				end
			end
		end

		if now - lastFetchAt >= LeaderboardConfig.RefreshSeconds then
			refreshBoards(true)
		end
	end
end)

task.delay(3, function()
	refreshBoards(true)
end)
