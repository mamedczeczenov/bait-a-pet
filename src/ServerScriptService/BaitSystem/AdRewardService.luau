--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local AdRewardConfig = require(Modules:WaitForChild("AdRewardConfig"))
local NumberFormat = require(Modules:WaitForChild("NumberFormat"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local PotionService = require(script.Parent:WaitForChild("PotionService"))

local AdRewardService = {}

local remote: RemoteEvent? = nil

local function getRemote(): RemoteEvent
	if remote and remote.Parent then
		return remote
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local existing = remotes:FindFirstChild("AdReward")
	if existing and existing:IsA("RemoteEvent") then
		remote = existing
		return existing
	end

	local created = Instance.new("RemoteEvent")
	created.Name = "AdReward"
	created.Parent = remotes
	remote = created
	return created
end

function AdRewardService.EnsureRemote(): RemoteEvent
	return getRemote()
end

local function syncAttributes(player: Player, data: PlayerDataService.PlayerData)
	player:SetAttribute("AdsWatchedToday", data.AdsWatchedToday)
	player:SetAttribute("LastAdRewardDay", data.LastAdRewardDay)
end

function AdRewardService.NormalizeDay(player: Player): PlayerDataService.PlayerData?
	local data = PlayerDataService.GetData(player)
	if not data then
		return nil
	end

	local today = AdRewardConfig.GetUtcDayKey()
	if data.LastAdRewardDay ~= today then
		data.AdsWatchedToday = 0
		data.LastAdRewardDay = today
		syncAttributes(player, data)
		PlayerDataService.MarkDirty(player)
	else
		data.AdsWatchedToday = AdRewardConfig.ClampWatched(data.AdsWatchedToday)
		syncAttributes(player, data)
	end

	return data
end

function AdRewardService.GetWatched(player: Player): number
	local data = AdRewardService.NormalizeDay(player)
	if not data then
		return 0
	end
	return data.AdsWatchedToday
end

function AdRewardService.Remaining(player: Player): number
	return math.max(0, AdRewardConfig.DailyMax - AdRewardService.GetWatched(player))
end

function AdRewardService.CanWatch(player: Player): boolean
	if not PlayerDataService.IsLoaded(player) then
		return false
	end
	if AdRewardService.Remaining(player) <= 0 then
		return false
	end
	if AdRewardConfig.IsProductConfigured() then
		return true
	end
	return RunService:IsStudio()
end

local function buildMilestones(watched: number): { { [string]: any } }
	local list = {}
	for _, milestone in ipairs(AdRewardConfig.Milestones) do
		table.insert(list, {
			At = milestone.At,
			PotionId = milestone.PotionId,
			Name = AdRewardConfig.GetMilestonePotionName(milestone.PotionId),
			Description = AdRewardConfig.GetMilestoneDescription(milestone.PotionId),
			Claimed = watched >= milestone.At,
		})
	end
	return list
end

local function buildPayload(player: Player, message: string?): { [string]: any }?
	local data = AdRewardService.NormalizeDay(player)
	if not data then
		return nil
	end

	local watched = data.AdsWatchedToday
	return {
		Type = "Snapshot",
		Message = message,
		AdsWatched = watched,
		DailyMax = AdRewardConfig.DailyMax,
		CoinsPerAd = AdRewardConfig.CoinsPerAd,
		Remaining = math.max(0, AdRewardConfig.DailyMax - watched),
		CanWatch = AdRewardService.CanWatch(player),
		Configured = AdRewardConfig.IsProductConfigured(),
		StudioSimulate = RunService:IsStudio() and not AdRewardConfig.IsProductConfigured(),
		Today = AdRewardConfig.GetUtcDayKey(),
		Milestones = buildMilestones(watched),
	}
end

function AdRewardService.PushSnapshot(player: Player, message: string?)
	local payload = buildPayload(player, message)
	if not payload then
		return
	end
	getRemote():FireClient(player, payload)
end

function AdRewardService.FireShowResult(player: Player, ok: boolean, resultName: string?)
	getRemote():FireClient(player, {
		Type = "ShowResult",
		Ok = ok,
		Result = resultName,
	})
end

function AdRewardService.GrantWatch(player: Player): (boolean, string?)
	if not PlayerDataService.IsLoaded(player) then
		return false, "Still loading..."
	end

	local data = AdRewardService.NormalizeDay(player)
	if not data then
		return false, "Still loading..."
	end

	if data.AdsWatchedToday >= AdRewardConfig.DailyMax then
		AdRewardService.PushSnapshot(player, "Daily ads already complete. Come back tomorrow (UTC).")
		return true, nil
	end

	local before = data.AdsWatchedToday
	local nextCount = AdRewardConfig.ClampWatched(before + 1)
	data.AdsWatchedToday = nextCount
	syncAttributes(player, data)

	PlayerDataService.AddCoins(player, AdRewardConfig.CoinsPerAd)

	local extras: { string } = {}
	for _, milestone in ipairs(AdRewardConfig.Milestones) do
		if before < milestone.At and nextCount >= milestone.At then
			local added, addError = PotionService.AddOwned(player, milestone.PotionId, 1)
			if added then
				table.insert(extras, AdRewardConfig.GetMilestonePotionName(milestone.PotionId))
			else
				warn(string.format("[AdReward] Potion grant failed for %s: %s", player.Name, tostring(addError)))
			end
		end
	end

	PlayerDataService.MarkDirty(player)

	local message = string.format(
		"Ad %d/%d! +%s coins.",
		nextCount,
		AdRewardConfig.DailyMax,
		NumberFormat.FormatCoins(AdRewardConfig.CoinsPerAd)
	)
	if #extras > 0 then
		message = message .. " Bonus: " .. table.concat(extras, " + ") .. "!"
	end
	if nextCount >= AdRewardConfig.DailyMax then
		message = message .. " Track complete for today."
	end

	AdRewardService.PushSnapshot(player, message)
	return true, message
end

function AdRewardService.DebugGrant(player: Player): (boolean, string?)
	if not RunService:IsStudio() then
		return false, "Studio only."
	end
	return AdRewardService.GrantWatch(player)
end

return AdRewardService
