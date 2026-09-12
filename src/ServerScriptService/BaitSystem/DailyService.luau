--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local DailyConfig = require(Modules:WaitForChild("DailyConfig"))
local NumberFormat = require(Modules:WaitForChild("NumberFormat"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local GoalService = require(script.Parent:WaitForChild("GoalService"))

local DailyService = {}

local remote: RemoteEvent? = nil

local function getRemote(): RemoteEvent
	if remote and remote.Parent then
		return remote
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local existing = remotes:FindFirstChild("Daily")
	if existing and existing:IsA("RemoteEvent") then
		remote = existing
		return existing
	end

	local created = Instance.new("RemoteEvent")
	created.Name = "Daily"
	created.Parent = remotes
	remote = created
	return created
end

function DailyService.EnsureRemote(): RemoteEvent
	return getRemote()
end

local function buildPayload(player: Player, message: string?): { [string]: any }?
	local data = PlayerDataService.GetData(player)
	if not data then
		return nil
	end

	local today = DailyConfig.GetUtcDayKey()
	local canClaim = DailyConfig.IsClaimable(data.LastDailyClaimDay, nil)
	local previewStreak = if canClaim
		then DailyConfig.NextStreak(data.DailyStreak, data.LastDailyClaimDay, nil)
		else math.clamp(data.DailyStreak, 0, DailyConfig.MaxStreak)
	local previewCoins = DailyConfig.GetCoinReward(math.max(1, previewStreak))

	return {
		Type = "Snapshot",
		Message = message,
		CanClaim = canClaim,
		Streak = data.DailyStreak,
		PreviewStreak = previewStreak,
		PreviewCoins = previewCoins,
		LastClaimDay = data.LastDailyClaimDay,
		Today = today,
		MaxStreak = DailyConfig.MaxStreak,
		BuffCatches = DailyConfig.BuffCatches,
		BuffMult = DailyConfig.BuffMult,
		LuckBuffCatches = data.LuckBuffCatches,
		LuckBuffMult = data.LuckBuffMult,
	}
end

function DailyService.PushSnapshot(player: Player, message: string?)
	local payload = buildPayload(player, message)
	if not payload then
		return
	end
	getRemote():FireClient(player, payload)
end

function DailyService.Claim(player: Player): (boolean, string?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "Still loading..."
	end

	if not DailyConfig.IsClaimable(data.LastDailyClaimDay, nil) then
		return false, "Already claimed today. Come back tomorrow (UTC)."
	end

	local nextStreak = DailyConfig.NextStreak(data.DailyStreak, data.LastDailyClaimDay, nil)
	local coins = DailyConfig.GetCoinReward(nextStreak)

	data.DailyStreak = nextStreak
	data.LastDailyClaimDay = DailyConfig.GetUtcDayKey()
	player:SetAttribute("DailyStreak", data.DailyStreak)
	player:SetAttribute("LastDailyClaimDay", data.LastDailyClaimDay)

	PlayerDataService.AddCoins(player, coins)

	if DailyConfig.BuffCatches > 0 then
		data.LuckBuffCatches += DailyConfig.BuffCatches
		data.LuckBuffMult = math.max(data.LuckBuffMult, DailyConfig.BuffMult)
		GoalService.SyncAttributes(player)
	end

	PlayerDataService.MarkDirty(player)

	local buffText = ""
	if DailyConfig.BuffCatches > 0 then
		buffText = string.format(
			" + %.0f%% luck for %d catches",
			(DailyConfig.BuffMult - 1) * 100,
			DailyConfig.BuffCatches
		)
	end

	DailyService.PushSnapshot(
		player,
		string.format("Daily claimed! +%s coins (streak %d)%s.", NumberFormat.FormatCoins(coins), nextStreak, buffText)
	)
	return true, nil
end

return DailyService
