--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local LeaderboardConfig = require(Modules:WaitForChild("LeaderboardConfig"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

export type Entry = {
	Rank: number,
	UserId: number,
	Name: string,
	DisplayName: string,
	Value: number,
}

export type Snapshot = {
	Playtime: { Entry },
	Cash: { Entry },
}

local LeaderboardService = {}

local playtimeStore: OrderedDataStore? = nil
local cashStore: OrderedDataStore? = nil
local storeInitFailed = false

local nameCache: { [number]: { Name: string, DisplayName: string } } = {}

local function getStores(): (OrderedDataStore?, OrderedDataStore?)
	if playtimeStore and cashStore then
		return playtimeStore, cashStore
	end
	if storeInitFailed then
		return nil, nil
	end

	local okPlay, playResult = pcall(function()
		return DataStoreService:GetOrderedDataStore(LeaderboardConfig.PlaytimeStoreName)
	end)
	local okCash, cashResult = pcall(function()
		return DataStoreService:GetOrderedDataStore(LeaderboardConfig.CashStoreName)
	end)

	if okPlay and playResult and okCash and cashResult then
		playtimeStore = playResult
		cashStore = cashResult
		return playtimeStore, cashStore
	end

	storeInitFailed = true
	warn("[LeaderboardService] OrderedDataStore unavailable:", playResult, cashResult)
	return nil, nil
end

local function clampScore(value: number): number
	if typeof(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, 9e15)
end

local function snapshotFromPlayer(player: Player): (number?, number?)
	if player:GetAttribute("LeaderboardCanPersist") ~= true then
		return nil, nil
	end

	local coinsAttr = player:GetAttribute("Coins")
	local coins = if typeof(coinsAttr) == "number" then math.max(0, math.floor(coinsAttr)) else nil

	if PlayerDataService.IsLoaded(player) then
		if not PlayerDataService.CanPersist(player) then
			return nil, nil
		end
		local playtime = PlayerDataService.GetPlaytimeSeconds(player)
		local data = PlayerDataService.GetData(player)
		if coins == nil and data then
			coins = data.Coins
		end
		return playtime, coins or 0
	end

	local playtimeAttr = player:GetAttribute("PlaytimeSeconds")
	if typeof(playtimeAttr) == "number" and coins ~= nil then
		return math.max(0, math.floor(playtimeAttr)), coins
	end

	return nil, nil
end

function LeaderboardService.EnsureRemote(): RemoteEvent
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes or not remotes:IsA("Folder") then
		if remotes then
			remotes:Destroy()
		end
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local existing = remotes:FindFirstChild("Leaderboards")
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	if existing then
		existing:Destroy()
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = "Leaderboards"
	remote.Parent = remotes
	return remote
end

function LeaderboardService.UpdatePlayer(player: Player): boolean
	local playStore, moneyStore = getStores()
	if not playStore or not moneyStore then
		return false
	end

	local playtime, coins = snapshotFromPlayer(player)
	if playtime == nil or coins == nil then
		return false
	end

	local key = tostring(player.UserId)
	local okPlay = pcall(function()
		playStore:SetAsync(key, clampScore(playtime))
	end)
	local okCash = pcall(function()
		moneyStore:SetAsync(key, clampScore(coins))
	end)

	if not okPlay or not okCash then
		warn(string.format("[LeaderboardService] SetAsync failed for %s (play=%s cash=%s)", player.Name, tostring(okPlay), tostring(okCash)))
		return false
	end

	nameCache[player.UserId] = {
		Name = player.Name,
		DisplayName = player.DisplayName,
	}
	return true
end

local function resolveNames(userIds: { number }): { [number]: { Name: string, DisplayName: string } }
	local missing: { number } = {}
	for _, userId in ipairs(userIds) do
		local online = Players:GetPlayerByUserId(userId)
		if online then
			nameCache[userId] = {
				Name = online.Name,
				DisplayName = online.DisplayName,
			}
		elseif not nameCache[userId] then
			table.insert(missing, userId)
		end
	end

	if #missing > 0 then
		local ok, infos = pcall(function()
			return UserService:GetUserInfosByUserIdsAsync(missing)
		end)
		if ok and typeof(infos) == "table" then
			for _, info in ipairs(infos) do
				if typeof(info) == "table" and typeof(info.Id) == "number" then
					local username = if typeof(info.Username) == "string" then info.Username else "Player"
					local display = if typeof(info.DisplayName) == "string" and info.DisplayName ~= "" then info.DisplayName else username
					nameCache[info.Id] = {
						Name = username,
						DisplayName = display,
					}
				end
			end
		else
			for _, userId in ipairs(missing) do
				local nameOk, name = pcall(function()
					return Players:GetNameFromUserIdAsync(userId)
				end)
				if nameOk and typeof(name) == "string" then
					nameCache[userId] = {
						Name = name,
						DisplayName = name,
					}
				end
			end
		end
	end

	return nameCache
end

local function fetchStore(store: OrderedDataStore, kind: string): { Entry }
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, LeaderboardConfig.TopCount)
	end)
	if not ok or not pages then
		warn("[LeaderboardService] GetSortedAsync failed for", kind, pages)
		return {}
	end

	local pageOk, page = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not pageOk or typeof(page) ~= "table" then
		return {}
	end

	local userIds: { number } = {}
	local raw: { { UserId: number, Value: number } } = {}
	for _, entry in ipairs(page) do
		local userId = tonumber(entry.key)
		local value = entry.value
		if typeof(userId) == "number" and userId > 0 and typeof(value) == "number" then
			table.insert(userIds, userId)
			table.insert(raw, {
				UserId = userId,
				Value = math.max(0, math.floor(value)),
			})
		end
	end

	resolveNames(userIds)

	local entries: { Entry } = {}
	for index, row in ipairs(raw) do
		local names = nameCache[row.UserId]
		table.insert(entries, {
			Rank = index,
			UserId = row.UserId,
			Name = if names then names.Name else ("Player " .. tostring(row.UserId)),
			DisplayName = if names then names.DisplayName else ("Player " .. tostring(row.UserId)),
			Value = row.Value,
		})
	end
	return entries
end

function LeaderboardService.FetchSnapshot(): Snapshot
	local playStore, moneyStore = getStores()
	if not playStore or not moneyStore then
		return {
			Playtime = {},
			Cash = {},
		}
	end

	return {
		Playtime = fetchStore(playStore, "playtime"),
		Cash = fetchStore(moneyStore, "cash"),
	}
end

function LeaderboardService.PushSnapshot(player: Player?, snapshot: Snapshot)
	local remote = LeaderboardService.EnsureRemote()
	local payload = {
		Type = "Snapshot",
		Playtime = snapshot.Playtime,
		Cash = snapshot.Cash,
	}
	if player then
		remote:FireClient(player, payload)
	else
		remote:FireAllClients(payload)
	end
end

return LeaderboardService
