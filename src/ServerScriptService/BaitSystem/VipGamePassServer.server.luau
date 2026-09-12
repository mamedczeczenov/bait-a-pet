--!strict

--[[
	VIP Game Pass ownership → VipAccess.

	Live contract (ready.md §2 VIP live):
	- no pass → VipAccess false (cave lock + purchase prompt on client)
	- purchase → VipAccess true immediately (4× luck via CaveConfig)
	- rejoin → UserOwnsGamePassAsync restores VipAccess

	Game Pass is source of truth. DataStore VipAccess is cleared on load until
	this script confirms ownership (see PlayerDataService.loadPlayer).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local VipConfig = require(Modules:WaitForChild("VipConfig"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local MAX_OWNERSHIP_ATTEMPTS = 5
local RETRY_DELAY_SEC = 2

-- Session grants from a successful purchase prompt this server.
-- Prevents a late/stale UserOwnsGamePassAsync(false) from revoking VIP right after buy.
local sessionPurchaseGrant: { [Player]: boolean } = {}
local pendingPurchaseGrant: { [Player]: boolean } = {}

local function setVip(player: Player, enabled: boolean)
	PlayerDataService.SetVipAccess(player, enabled, true)
end

local function applyOwnership(player: Player, attempt: number?)
	if not player.Parent then
		return
	end
	if not PlayerDataService.IsLoaded(player) then
		return
	end

	if not VipConfig.IsConfigured() then
		-- Pass disabled: nobody gets VIP from ownership (Studio /vip still works).
		setVip(player, false)
		return
	end

	-- Purchase on this server already confirmed — never downgrade from ownership poll.
	if sessionPurchaseGrant[player] == true or pendingPurchaseGrant[player] == true then
		sessionPurchaseGrant[player] = true
		pendingPurchaseGrant[player] = nil
		setVip(player, true)
		return
	end

	local attemptNum = attempt or 1
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VipConfig.GamePassId)
	end)

	if not ok then
		warn(string.format(
			"[VipGamePass] Ownership check failed for %s (attempt %d/%d): %s",
			player.Name,
			attemptNum,
			MAX_OWNERSHIP_ATTEMPTS,
			tostring(owns)
		))
		-- Do not force VipAccess=false on API errors (would soft-wipe paying users).
		if attemptNum < MAX_OWNERSHIP_ATTEMPTS and player.Parent then
			task.delay(RETRY_DELAY_SEC, function()
				applyOwnership(player, attemptNum + 1)
			end)
		end
		return
	end

	local hasPass = owns == true
	setVip(player, hasPass)
	print(string.format(
		"[VipGamePass] %s owns pass %d = %s",
		player.Name,
		VipConfig.GamePassId,
		tostring(hasPass)
	))
end

local function grantFromPurchase(player: Player)
	sessionPurchaseGrant[player] = true
	pendingPurchaseGrant[player] = nil

	if not PlayerDataService.IsLoaded(player) then
		pendingPurchaseGrant[player] = true
		print(string.format("[VipGamePass] Queued VIP grant for %s (data not loaded yet).", player.Name))
		return
	end

	setVip(player, true)
	print(string.format("[VipGamePass] Granted VIP to %s via purchase.", player.Name))
end

local function onPlayerReady(player: Player)
	task.spawn(function()
		local deadline = os.clock() + 30
		while not PlayerDataService.IsLoaded(player) and player.Parent and os.clock() < deadline do
			task.wait(0.2)
		end
		if not player.Parent or not PlayerDataService.IsLoaded(player) then
			return
		end

		if pendingPurchaseGrant[player] == true then
			grantFromPurchase(player)
			return
		end

		applyOwnership(player, 1)
	end)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if not VipConfig.IsConfigured() then
		return
	end
	if gamePassId ~= VipConfig.GamePassId then
		return
	end
	if wasPurchased ~= true then
		return
	end
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end

	grantFromPurchase(player)
end)

Players.PlayerRemoving:Connect(function(player)
	sessionPurchaseGrant[player] = nil
	pendingPurchaseGrant[player] = nil
end)

Players.PlayerAdded:Connect(onPlayerReady)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerReady(player)
end
