--!strict

local AfkPetConfig = require(script.Parent:WaitForChild("AfkPetConfig"))

local AfkConfig = {}

AfkConfig.ThrowInterval = 30
AfkConfig.ReconnectAfter = 16 * 60
AfkConfig.PotionLuckChance = 0.01
AfkConfig.PotionSellChance = 0.01
AfkConfig.BasePetChance = 0.02
AfkConfig.MaxPetChance = 0.10
AfkConfig.BagCapacity = 30
-- Paste rbxassetid://… when the BAIT A PET! lobby image is ready.
AfkConfig.LogoImage = ""

AfkConfig.EnterTitle = "Go AFK?"
AfkConfig.EnterBody =
	"You will not catch cave pets. You get coins, potions, and rare AFK pets. One throw every 30s."
AfkConfig.EnterConfirm = "Go AFK"
AfkConfig.LeaveTitle = "Leave AFK?"
AfkConfig.LeaveBody = "Auto-throw will stop and you will return to the lobby."
AfkConfig.LeaveConfirm = "Return To Lobby"
AfkConfig.RejoinMessage = "Rejoining so AFK can keep throwing…"
AfkConfig.BagFullMessage = "AFK bag full — sell or lock space."
AfkConfig.StudioTeleportMessage =
	"Studio: teleport to the AFK place does not run. Publish the AFK lobby and test in the Roblox app — or Play inside the AFK place to preview the overlay."

function AfkConfig.GetLuck(baitLuck: number, luckUpgradeBonus: number, giftLuck: number?): number
	local bait = if typeof(baitLuck) == "number" then baitLuck else 1
	local upgrade = if typeof(luckUpgradeBonus) == "number" then luckUpgradeBonus else 1
	local gift = if typeof(giftLuck) == "number" and giftLuck > 0 then giftLuck else 1
	return math.max(0.05, bait * upgrade * gift)
end

-- 2% at luck 1, soft-cap toward 10% as luck grows.
function AfkConfig.GetPetDropChance(afkLuck: number): number
	local luck = math.max(1, afkLuck)
	local t = math.log(luck)
	local span = AfkConfig.MaxPetChance - AfkConfig.BasePetChance
	return AfkConfig.BasePetChance + span * (t / (t + 3))
end

function AfkConfig.GetTrophyChance(afkLuck: number): number
	local total = AfkPetConfig.GetTotalWeight()
	local trophy = AfkPetConfig.GetTrophyWeight()
	if total <= 0 then
		return 0
	end
	return AfkConfig.GetPetDropChance(afkLuck) * (trophy / total)
end

function AfkConfig.GetWeightedPetChance(afkLuck: number, petId: string): number
	local def = AfkPetConfig.Get(petId)
	local total = AfkPetConfig.GetTotalWeight()
	if not def or total <= 0 then
		return 0
	end
	return AfkConfig.GetPetDropChance(afkLuck) * (def.Weight / total)
end

function AfkConfig.FormatChance(chance: number): string
	local pct = chance * 100
	if pct >= 10 then
		return string.format("%.0f%%", pct)
	end
	if pct >= 1 then
		return string.format("%.1f%%", pct)
	end
	return string.format("%.2f%%", pct)
end

function AfkConfig.FormatCountdown(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	local m = math.floor(s / 60)
	local rem = s % 60
	if m > 1 then
		return string.format("%d MINUTES %d SECONDS UNTIL NEXT ROLL", m, rem)
	end
	if m == 1 then
		return string.format("1 MINUTE %d SECONDS UNTIL NEXT ROLL", rem)
	end
	if rem == 1 then
		return "1 SECOND UNTIL NEXT ROLL"
	end
	return string.format("%d SECONDS UNTIL NEXT ROLL", rem)
end

return AfkConfig
