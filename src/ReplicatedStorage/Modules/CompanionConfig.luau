--!strict

--[[
	Maszyna do petów (companion fuse).
	Spend FuseCount unlocked copies of the same pet → permanent follower
	with luck + sell buffs scaled by that pet's rarity.
	Default 1 walker; Map 2 unlock allows 2 walkers (buff = best of active).
]]

local PetConfig = require(script.Parent:WaitForChild("PetConfig"))

export type BuffTier = {
	LuckMult: number,
	SellMult: number,
}

local CompanionConfig = {}

CompanionConfig.FuseCount = 3
CompanionConfig.ModelName = "CompanionPet"
CompanionConfig.FollowHeight = 2.1
-- Offset in character local space: right, up, back.
CompanionConfig.FollowOffset = Vector3.new(2.4, 0.15, 3.2)
CompanionConfig.FollowOffset2 = Vector3.new(-2.4, 0.15, 3.2)
CompanionConfig.FollowLerp = 14
CompanionConfig.MaxWalkDefault = 1
CompanionConfig.MaxWalkMap2 = 2
CompanionConfig.StationTag = "SodaMachineStation"
CompanionConfig.StationDisplayName = "Maszyna do petów"
CompanionConfig.StationNames = {
	"maszyna do petow",
	"Maszyna do petow",
	"maszyna do petów",
	"Maszyna do petów",
	-- Legacy map names (kept as fallback).
	"Soda Machine",
	"SodaMachine",
	"sodamachine",
}

-- Both luck and sell; higher rarities pay off more for the 3-pet cost.
-- Economy 1D: Common 1.05× stays — first companion is a Map 1 spice, not a Bronze skip.
CompanionConfig.BuffByRarity = {
	Common = { LuckMult = 1.05, SellMult = 1.05 },
	Uncommon = { LuckMult = 1.08, SellMult = 1.08 },
	Rare = { LuckMult = 1.12, SellMult = 1.1 },
	Epic = { LuckMult = 1.18, SellMult = 1.15 },
	Legendary = { LuckMult = 1.25, SellMult = 1.22 },
	Mythic = { LuckMult = 1.35, SellMult = 1.3 },
	Angelic = { LuckMult = 1.45, SellMult = 1.38 },
	Glorious = { LuckMult = 1.55, SellMult = 1.45 },
	Radiant = { LuckMult = 1.65, SellMult = 1.52 },
	Secret = { LuckMult = 1.75, SellMult = 1.6 },
	Eternal = { LuckMult = 1.85, SellMult = 1.68 },
	Divine = { LuckMult = 2.0, SellMult = 1.8 },
} :: { [string]: BuffTier }

function CompanionConfig.GetBuff(rarity: string): BuffTier
	local tier = CompanionConfig.BuffByRarity[rarity]
	if tier then
		return tier
	end
	return CompanionConfig.BuffByRarity.Common
end

function CompanionConfig.GetBuffForPet(petName: string): (BuffTier, string)
	local definition = PetConfig.GetByName(petName)
	local rarity = if definition then definition.Rarity else "Common"
	return CompanionConfig.GetBuff(rarity), rarity
end

return CompanionConfig
