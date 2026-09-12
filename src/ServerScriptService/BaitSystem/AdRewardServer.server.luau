--!strict

local AdService = game:GetService("AdService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local AdRewardConfig = require(Modules:WaitForChild("AdRewardConfig"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local AdRewardService = require(script.Parent:WaitForChild("AdRewardService"))
local PurchaseReceiptService = require(script.Parent:WaitForChild("PurchaseReceiptService"))

local adRemote = AdRewardService.EnsureRemote()

local lastActionAt: { [Player]: number } = {}
local showingAd: { [Player]: boolean } = {}
local ACTION_COOLDOWN = 0.6

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

local function showResultName(result: any): string
	if typeof(result) == "EnumItem" then
		return result.Name
	end
	return tostring(result)
end

local function showRewardedAd(player: Player)
	if showingAd[player] then
		AdRewardService.PushSnapshot(player, "Ad already playing.")
		AdRewardService.FireShowResult(player, false, "Busy")
		return
	end

	if not AdRewardService.CanWatch(player) then
		AdRewardService.PushSnapshot(player, "No ads left today. Come back tomorrow (UTC).")
		AdRewardService.FireShowResult(player, false, "Capped")
		return
	end

	if not AdRewardConfig.IsProductConfigured() then
		if RunService:IsStudio() then
			AdRewardService.GrantWatch(player)
			AdRewardService.FireShowResult(player, true, "StudioSimulate")
			return
		end
		AdRewardService.PushSnapshot(player, "Create a Developer Product and paste its ID into AdRewardConfig.")
		AdRewardService.FireShowResult(player, false, "NotConfigured")
		return
	end

	showingAd[player] = true
	local ok, result = pcall(function()
		local reward = AdService:CreateAdRewardFromDevProductId(AdRewardConfig.ProductId)
		if AdRewardConfig.PlacementId > 0 then
			return AdService:ShowRewardedVideoAdAsync(player, reward, AdRewardConfig.PlacementId)
		end
		return AdService:ShowRewardedVideoAdAsync(player, reward)
	end)

	if not ok then
		showingAd[player] = nil
		warn(string.format("[AdReward] Show failed for %s: %s", player.Name, tostring(result)))
		AdRewardService.PushSnapshot(player, "Could not play an ad. Try again in a moment.")
		AdRewardService.FireShowResult(player, false, "Error")
		return
	end

	local name = showResultName(result)
	if name == "ShowCompleted" then
		AdRewardService.PushSnapshot(player, "Ad finished — granting reward...")
		task.delay(15, function()
			showingAd[player] = nil
		end)
	else
		showingAd[player] = nil
		if name == "AdNotReady" then
			AdRewardService.PushSnapshot(player, "No ad ready right now. Try again in a bit.")
		elseif name == "ShowCanceled" or name == "UserCanceled" then
			AdRewardService.PushSnapshot(player, "Ad cancelled. Watch the whole video to get the reward.")
		else
			AdRewardService.PushSnapshot(player, "Ad did not complete (" .. name .. ").")
		end
	end
	AdRewardService.FireShowResult(player, name == "ShowCompleted", name)
end

PurchaseReceiptService.BindAdRewardGrant(function(player: Player)
	showingAd[player] = nil
	return AdRewardService.GrantWatch(player)
end)

local function onPlayerReady(player: Player)
	local deadline = os.clock() + 20
	while os.clock() < deadline and not PlayerDataService.IsLoaded(player) do
		task.wait(0.1)
	end
	if not PlayerDataService.IsLoaded(player) then
		return
	end
	AdRewardService.PushSnapshot(player, nil)
end

adRemote.OnServerEvent:Connect(function(player, payload)
	if typeof(payload) ~= "table" then
		return
	end
	if not canAct(player) then
		return
	end

	local payloadType = payload.Type
	if payloadType == "Ready" then
		AdRewardService.PushSnapshot(player, nil)
		return
	end

	if payloadType == "Watch" then
		task.spawn(showRewardedAd, player)
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
	showingAd[player] = nil
end)
