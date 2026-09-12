--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local function handleChat(player: Player, message: string)
	if not RunService:IsStudio() then
		return
	end

	local trimmed = string.gsub(message, "^%s+", "")
	local lower = string.lower(trimmed)

	if lower == "/resettutorial" then
		return
	end

	if lower == "/vip" or lower == "/vip on" then
		if not PlayerDataService.IsLoaded(player) then
			return
		end
		-- Session only — do not persist into live DataStore.
		PlayerDataService.SetVipAccess(player, true, false)
		print(string.format("[Debug] VIP access ON (session) for %s", player.Name))
		return
	end

	if lower == "/vip off" then
		if not PlayerDataService.IsLoaded(player) then
			return
		end
		PlayerDataService.SetVipAccess(player, false, true)
		print(string.format("[Debug] VIP access OFF for %s", player.Name))
		return
	end

	if lower == "/groupchestreset" then
		if not PlayerDataService.IsLoaded(player) then
			return
		end
		local data = PlayerDataService.GetData(player)
		if data then
			data.GroupChestClaimed = false
			player:SetAttribute("GroupChestClaimed", false)
			PlayerDataService.MarkDirty(player)
			print(string.format("[Debug] Group chest claim reset for %s", player.Name))
		end
		return
	end

	if lower == "/map2unlock" or lower == "/unlockmap2" or lower == "map2unlock" or lower == "map2unlocked" then
		if not PlayerDataService.IsLoaded(player) then
			return
		end
		PlayerDataService.UnlockMap2(player)
		local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
		local petResult = remotes and remotes:FindFirstChild("PetResult")
		if petResult and petResult:IsA("RemoteEvent") then
			petResult:FireClient(player, {
				Type = "Map2Unlock",
				Message = "Map 2 unlocked — Walk 2 followers + Carry 2 pets in hands!",
			})
		end
		print(string.format(
			"[Debug] Map2Unlocked for %s (max equip=%d, max walk=%d)",
			player.Name,
			2,
			2
		))
		return
	end

	if lower == "/map3unlock" or lower == "/unlockmap3" then
		if not PlayerDataService.IsLoaded(player) then
			return
		end
		PlayerDataService.UnlockMap3(player)
		local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
		local petResult = remotes and remotes:FindFirstChild("PetResult")
		if petResult and petResult:IsA("RemoteEvent") then
			petResult:FireClient(player, {
				Type = "Map3Unlock",
				Message = "Map 3 unlocked — Carry 3 pets in hands!",
			})
		end
		print(string.format(
			"[Debug] Map3Unlocked for %s (max equip=%d)",
			player.Name,
			PlayerDataService.GetMaxEquippedPets(player)
		))
		return
	end

	local amountText = string.match(lower, "^/givecoins%s+(%d+)$")
	if amountText then
		if not PlayerDataService.IsLoaded(player) then
			return
		end
		local amount = tonumber(amountText)
		if typeof(amount) ~= "number" or amount <= 0 then
			return
		end
		local capped = math.min(math.floor(amount), 100000000)
		PlayerDataService.AddCoins(player, capped)
		return
	end

	local EventService = require(script.Parent:WaitForChild("EventService"))
	if lower == "/event stop" then
		EventService.Stop("Event stopped (debug).")
		print("[Debug] World event stopped")
		return
	end

	local eventId = string.match(lower, "^/event%s+([%w_]+)$")
	if eventId then
		if eventId == "next" then
			local nextEvent = EventService.PickNext()
			EventService.Start(nextEvent.Id)
			print(string.format("[Debug] Started event %s", nextEvent.Id))
			return
		end
		if EventService.Start(eventId) then
			print(string.format("[Debug] Started event %s", eventId))
		else
			print(string.format("[Debug] Unknown event id: %s", eventId))
		end
		return
	end

	if lower == "/watchad" then
		if not PlayerDataService.IsLoaded(player) then
			return
		end
		local AdRewardService = require(script.Parent:WaitForChild("AdRewardService"))
		local ok, err = AdRewardService.DebugGrant(player)
		print(string.format("[Debug] watchad for %s: %s", player.Name, if ok then "ok" else tostring(err)))
		return
	end

	local potionId = string.match(lower, "^/givepotion%s+([%w_]+)$")
	if potionId then
		if not PlayerDataService.IsLoaded(player) then
			return
		end
		local PotionService = require(script.Parent:WaitForChild("PotionService"))
		local PotionConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("PotionConfig"))
		if not PotionConfig.IsPotionId(potionId) then
			print("[Debug] Usage: /givepotion luck|sell|super_luck|super_sell|super_bundle")
			return
		end
		local ok, err = PotionService.AddOwned(player, potionId, 1)
		print(string.format("[Debug] givepotion %s for %s: %s", potionId, player.Name, if ok then "ok" else tostring(err)))
		return
	end

	local giftMinutes = string.match(lower, "^/gifttime%s+(%d+)$")
	if giftMinutes then
		local minutes = tonumber(giftMinutes)
		if typeof(minutes) ~= "number" then
			return
		end
		local GiftService = require(script.Parent:WaitForChild("GiftService"))
		GiftService.DebugSetElapsed(player, minutes * 60)
		print(string.format("[Debug] gift elapsed set to %d min for %s", minutes, player.Name))
		return
	end
end

local function bindPlayer(player: Player)
	player.Chatted:Connect(function(message)
		handleChat(player, message)
	end)
end

Players.PlayerAdded:Connect(bindPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	bindPlayer(player)
end
