--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlaceConfig = require(Modules:WaitForChild("PlaceConfig"))
local PotionConfig = require(Modules:WaitForChild("PotionConfig"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local PotionService = {}

local ticking = false
local lastPersistAt: { [Player]: number } = {}

local COUNT_FIELD: { [string]: string } = {
	luck = "PotionLuckCount",
	sell = "PotionSellCount",
	super_luck = "PotionSuperLuckCount",
	super_sell = "PotionSuperSellCount",
	super_bundle = "PotionSuperBundleCount",
}

local function syncAttributes(player: Player, data: PlayerDataService.PlayerData)
	if data.PotionLuckRemaining <= 0 then
		data.PotionLuckActiveMult = 1
	end
	if data.PotionSellRemaining <= 0 then
		data.PotionSellActiveMult = 1
	end
	player:SetAttribute("PotionLuckCount", data.PotionLuckCount)
	player:SetAttribute("PotionSellCount", data.PotionSellCount)
	player:SetAttribute("PotionSuperLuckCount", data.PotionSuperLuckCount)
	player:SetAttribute("PotionSuperSellCount", data.PotionSuperSellCount)
	player:SetAttribute("PotionSuperBundleCount", data.PotionSuperBundleCount)
	player:SetAttribute("PotionLuckRemaining", data.PotionLuckRemaining)
	player:SetAttribute("PotionSellRemaining", data.PotionSellRemaining)
	player:SetAttribute("PotionLuckMult", PotionConfig.GetChannelMultiplier(data.PotionLuckRemaining, data.PotionLuckActiveMult))
	player:SetAttribute("PotionSellMult", PotionConfig.GetChannelMultiplier(data.PotionSellRemaining, data.PotionSellActiveMult))
end

local function getCount(data: PlayerDataService.PlayerData, potionId: string): number
	local field = COUNT_FIELD[potionId]
	if not field then
		return 0
	end
	local value = (data :: any)[field]
	if typeof(value) == "number" then
		return value
	end
	return 0
end

local function setCount(data: PlayerDataService.PlayerData, potionId: string, count: number)
	local field = COUNT_FIELD[potionId]
	if not field then
		return
	end
	(data :: any)[field] = PotionConfig.ClampOwned(count)
end

local function getChannelRemaining(data: PlayerDataService.PlayerData, channel: string): number
	if channel == "luck" then
		return data.PotionLuckRemaining
	end
	return data.PotionSellRemaining
end

local function setChannelRemaining(data: PlayerDataService.PlayerData, channel: string, remaining: number)
	if channel == "luck" then
		data.PotionLuckRemaining = PotionConfig.ClampRemaining(remaining)
	else
		data.PotionSellRemaining = PotionConfig.ClampRemaining(remaining)
	end
end

local function getChannelMult(data: PlayerDataService.PlayerData, channel: string): number
	if channel == "luck" then
		return data.PotionLuckActiveMult
	end
	return data.PotionSellActiveMult
end

local function setChannelMult(data: PlayerDataService.PlayerData, channel: string, mult: number)
	if channel == "luck" then
		data.PotionLuckActiveMult = PotionConfig.ClampActiveMult(mult)
	else
		data.PotionSellActiveMult = PotionConfig.ClampActiveMult(mult)
	end
end

function PotionService.SyncAttributes(player: Player)
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end
	syncAttributes(player, data)
end

function PotionService.GetOwned(player: Player, potionId: string): number
	local data = PlayerDataService.GetData(player)
	if not data then
		return 0
	end
	return getCount(data, potionId)
end

function PotionService.GetRemaining(player: Player, channel: string): number
	local data = PlayerDataService.GetData(player)
	if not data then
		return 0
	end
	return getChannelRemaining(data, channel)
end

function PotionService.GetLuckMultiplier(player: Player): number
	local remaining = player:GetAttribute("PotionLuckRemaining")
	local active = player:GetAttribute("PotionLuckMult")
	if typeof(remaining) == "number" and typeof(active) == "number" then
		return PotionConfig.GetChannelMultiplier(remaining, active)
	end
	return 1
end

function PotionService.GetSellMultiplier(player: Player): number
	local remaining = player:GetAttribute("PotionSellRemaining")
	local active = player:GetAttribute("PotionSellMult")
	if typeof(remaining) == "number" and typeof(active) == "number" then
		return PotionConfig.GetChannelMultiplier(remaining, active)
	end
	return 1
end

function PotionService.BuildSnapshot(player: Player): { [string]: any }
	local luckDef = PotionConfig.Get("luck")
	local sellDef = PotionConfig.Get("sell")
	local superLuckDef = PotionConfig.Get("super_luck")
	local superSellDef = PotionConfig.Get("super_sell")
	local superBundleDef = PotionConfig.Get("super_bundle")
	return {
		PotionLuckCount = PotionService.GetOwned(player, "luck"),
		PotionSellCount = PotionService.GetOwned(player, "sell"),
		PotionSuperLuckCount = PotionService.GetOwned(player, "super_luck"),
		PotionSuperSellCount = PotionService.GetOwned(player, "super_sell"),
		PotionSuperBundleCount = PotionService.GetOwned(player, "super_bundle"),
		PotionLuckRemaining = PotionService.GetRemaining(player, "luck"),
		PotionSellRemaining = PotionService.GetRemaining(player, "sell"),
		PotionLuckMult = PotionService.GetLuckMultiplier(player),
		PotionSellMult = PotionService.GetSellMultiplier(player),
		PotionLuckPrice = if luckDef then luckDef.Price else PotionConfig.Price,
		PotionSellPrice = if sellDef then sellDef.Price else PotionConfig.Price,
		PotionSuperLuckRobux = if superLuckDef then superLuckDef.RobuxPrice else 9,
		PotionSuperSellRobux = if superSellDef then superSellDef.RobuxPrice else 9,
		PotionSuperBundleRobux = if superBundleDef then superBundleDef.RobuxPrice else 15,
		PotionDurationSeconds = PotionConfig.DurationSeconds,
	}
end

function PotionService.HasProcessedPurchase(player: Player, purchaseId: string): boolean
	return PlayerDataService.HasProcessedPurchase(player, purchaseId)
end

function PotionService.MarkProcessedPurchase(player: Player, purchaseId: string)
	PlayerDataService.MarkProcessedPurchase(player, purchaseId)
end

function PotionService.AddOwned(player: Player, potionId: string, amount: number): (boolean, string?)
	if not PlayerDataService.IsLoaded(player) then
		return false, "Still loading..."
	end
	local def = PotionConfig.Get(potionId)
	if not def then
		return false, "Invalid potion."
	end
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "Still loading..."
	end

	local add = math.max(0, math.floor(amount))
	if add <= 0 then
		return false, "Invalid amount."
	end

	local owned = getCount(data, potionId)
	if owned + add > PotionConfig.TechnicalMaxOwned then
		return false, string.format("Too many %ss.", def.Name)
	end

	setCount(data, potionId, owned + add)
	syncAttributes(player, data)
	PlayerDataService.MarkDirty(player)
	return true, nil
end

function PotionService.Use(player: Player, potionId: string): (boolean, string?)
	if not PlayerDataService.IsLoaded(player) then
		return false, "Still loading..."
	end
	local def = PotionConfig.Get(potionId)
	if not def then
		return false, "Invalid potion."
	end
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "Still loading..."
	end

	local owned = getCount(data, potionId)
	if owned <= 0 then
		return false, string.format("You don't have a %s.", def.Name)
	end

	local channels = PotionConfig.GetChannels(def)
	local anyExtend = false
	for _, channel in ipairs(channels) do
		local before = getChannelRemaining(data, channel)
		if PotionConfig.ClampRemaining(before + def.DurationSeconds) > before then
			anyExtend = true
			break
		end
	end
	if not anyExtend then
		return false, string.format("%s timer is already maxed.", def.Name)
	end

	setCount(data, potionId, owned - 1)
	local applied: { string } = {}
	for _, channel in ipairs(channels) do
		local before = getChannelRemaining(data, channel)
		local nextRemaining = PotionConfig.ClampRemaining(before + def.DurationSeconds)
		local nextMult = math.max(getChannelMult(data, channel), def.Mult)
		setChannelRemaining(data, channel, nextRemaining)
		setChannelMult(data, channel, nextMult)
		table.insert(applied, string.format("×%.0f %s %s", nextMult, channel, PotionConfig.FormatTime(nextRemaining)))
	end
	syncAttributes(player, data)
	PlayerDataService.MarkDirty(player)

	return true, string.format("%s active — %s.", def.Name, table.concat(applied, " + "))
end

function PotionService.TickPlayer(player: Player, dt: number)
	if dt <= 0 or not PlayerDataService.IsLoaded(player) then
		return
	end
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end

	local luckBefore = data.PotionLuckRemaining
	local sellBefore = data.PotionSellRemaining
	if luckBefore <= 0 and sellBefore <= 0 then
		return
	end

	-- AFK lobby pauses potion timers; they resume in the cave world.
	if PlaceConfig.IsAfkPlace() or player:GetAttribute("AfkThrow") == true then
		return
	end

	if luckBefore > 0 then
		data.PotionLuckRemaining = PotionConfig.ClampRemaining(luckBefore - dt)
	end
	if sellBefore > 0 then
		data.PotionSellRemaining = PotionConfig.ClampRemaining(sellBefore - dt)
	end

	syncAttributes(player, data)

	local luckEnded = luckBefore > 0 and data.PotionLuckRemaining <= 0
	local sellEnded = sellBefore > 0 and data.PotionSellRemaining <= 0
	if luckEnded or sellEnded then
		PlayerDataService.MarkDirty(player)
		lastPersistAt[player] = os.clock()
		return
	end

	local last = lastPersistAt[player] or 0
	if os.clock() - last >= 15 then
		lastPersistAt[player] = os.clock()
		PlayerDataService.MarkDirty(player)
	end
end

function PotionService.StartTicking()
	if ticking then
		return
	end
	ticking = true

	task.spawn(function()
		local last = os.clock()
		while ticking do
			task.wait(1)
			local now = os.clock()
			local dt = now - last
			last = now
			for _, player in ipairs(Players:GetPlayers()) do
				PotionService.TickPlayer(player, dt)
			end
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	lastPersistAt[player] = nil
end)

return PotionService
