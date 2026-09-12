--!strict

local PetConfig = require(script.Parent:WaitForChild("PetConfig"))

local PityConfig = {}

-- Soft pity: after GraceFails without Epic+, boost Epic–Legendary only (not Angelic+).
-- Economy 1D: keep 1C window — VIP 4× must not pity-rush Glorious.
PityConfig.MinRarity = "Epic"
PityConfig.MaxRarity = "Legendary"
PityConfig.GraceFails = 60
PityConfig.BonusPerFail = 0.04 -- +4% Epic–Legendary weight per fail past grace
PityConfig.MaxBonusMult = 1.75

function PityConfig.IsPityBoostRarity(rarity: string): boolean
	local minIndex = table.find(PetConfig.RarityOrder, PityConfig.MinRarity)
	local maxIndex = table.find(PetConfig.RarityOrder, PityConfig.MaxRarity)
	local rarityIndex = table.find(PetConfig.RarityOrder, rarity)
	if typeof(minIndex) ~= "number" or typeof(maxIndex) ~= "number" or typeof(rarityIndex) ~= "number" then
		return false
	end
	return rarityIndex >= minIndex and rarityIndex <= maxIndex
end

-- Any Epic+ catch clears the fail streak (including Mythic+).
function PityConfig.IsPitySuccessRarity(rarity: string): boolean
	local minIndex = table.find(PetConfig.RarityOrder, PityConfig.MinRarity)
	local rarityIndex = table.find(PetConfig.RarityOrder, rarity)
	if typeof(minIndex) ~= "number" or typeof(rarityIndex) ~= "number" then
		return false
	end
	return rarityIndex >= minIndex
end

-- Back-compat alias used by older call sites for "success" checks.
function PityConfig.IsPityRarity(rarity: string): boolean
	return PityConfig.IsPitySuccessRarity(rarity)
end

function PityConfig.GetWeightMultiplier(failCount: number): number
	local fails = math.max(0, math.floor(failCount))
	local pastGrace = math.max(0, fails - PityConfig.GraceFails)
	if pastGrace <= 0 then
		return 1
	end

	local mult = 1 + pastGrace * PityConfig.BonusPerFail
	return math.clamp(mult, 1, PityConfig.MaxBonusMult)
end

return PityConfig
