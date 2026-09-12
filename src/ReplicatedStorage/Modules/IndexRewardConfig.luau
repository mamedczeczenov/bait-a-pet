--!strict

--[[
	One-time coin rewards for first-time Pet Index discovery claims
	and Index completion milestones (percent + rarity tiers).
]]

export type MilestoneKind = "percent" | "rarity"

export type MilestoneDefinition = {
	Id: string,
	Kind: MilestoneKind,
	Label: string,
	RewardCoins: number,
	-- percent: 10..100; rarity: PetConfig rarity name
	Target: number | string,
}

local IndexRewardConfig = {}

-- Economy 1D: discovery snacks, not bait skips. Late rarity claims stay Map 1 long-tail.
IndexRewardConfig.RewardByRarity = {
	Common = 15,
	Uncommon = 40,
	Rare = 120,
	Epic = 500,
	Legendary = 2800,
	Mythic = 9000,
	Angelic = 25000,
	Glorious = 65000,
	Radiant = 170000,
	Secret = 450000,
	Eternal = 1200000,
	Divine = 3500000,
}

IndexRewardConfig.PercentMilestones = {
	{ Id = "pct_10", Kind = "percent", Label = "10% Index", RewardCoins = 400, Target = 10 },
	{ Id = "pct_25", Kind = "percent", Label = "25% Index", RewardCoins = 1800, Target = 25 },
	{ Id = "pct_50", Kind = "percent", Label = "50% Index", RewardCoins = 12000, Target = 50 },
	{ Id = "pct_75", Kind = "percent", Label = "75% Index", RewardCoins = 60000, Target = 75 },
	{ Id = "pct_100", Kind = "percent", Label = "100% Index", RewardCoins = 350000, Target = 100 },
} :: { MilestoneDefinition }

IndexRewardConfig.RarityCompleteRewards = {
	Common = 1500,
	Uncommon = 4000,
	Rare = 12000,
	Epic = 40000,
	Legendary = 120000,
	Mythic = 350000,
	Angelic = 800000,
	Glorious = 1500000,
	Radiant = 3000000,
	Secret = 6000000,
	Eternal = 12000000,
	Divine = 25000000,
}

local RARITY_ORDER = {
	"Common",
	"Uncommon",
	"Rare",
	"Epic",
	"Legendary",
	"Mythic",
	"Angelic",
	"Glorious",
	"Radiant",
	"Secret",
	"Eternal",
	"Divine",
}

local rewardById: { [string]: number } = {}
local definitionById: { [string]: MilestoneDefinition } = {}

local function registerMilestone(def: MilestoneDefinition)
	definitionById[def.Id] = def
	rewardById[def.Id] = math.max(0, math.floor(def.RewardCoins))
end

for _, def in ipairs(IndexRewardConfig.PercentMilestones) do
	registerMilestone(def)
end

IndexRewardConfig.RarityMilestones = {} :: { MilestoneDefinition }
for _, rarity in ipairs(RARITY_ORDER) do
	local coins = IndexRewardConfig.RarityCompleteRewards[rarity] or 0
	local def: MilestoneDefinition = {
		Id = "rarity_" .. rarity,
		Kind = "rarity",
		Label = rarity .. " complete",
		RewardCoins = coins,
		Target = rarity,
	}
	table.insert(IndexRewardConfig.RarityMilestones, def)
	registerMilestone(def)
end

function IndexRewardConfig.GetReward(rarity: string): number
	local reward = IndexRewardConfig.RewardByRarity[rarity]
	if typeof(reward) == "number" then
		return math.max(0, math.floor(reward))
	end
	return IndexRewardConfig.RewardByRarity.Common
end

function IndexRewardConfig.GetPercentMilestones(): { MilestoneDefinition }
	return IndexRewardConfig.PercentMilestones
end

function IndexRewardConfig.GetRarityMilestones(): { MilestoneDefinition }
	return IndexRewardConfig.RarityMilestones
end

function IndexRewardConfig.GetAllMilestones(): { MilestoneDefinition }
	local all: { MilestoneDefinition } = {}
	for _, def in ipairs(IndexRewardConfig.PercentMilestones) do
		table.insert(all, def)
	end
	for _, def in ipairs(IndexRewardConfig.RarityMilestones) do
		table.insert(all, def)
	end
	return all
end

function IndexRewardConfig.GetMilestone(id: string): MilestoneDefinition?
	return definitionById[id]
end

function IndexRewardConfig.GetMilestoneReward(id: string): number
	local reward = rewardById[id]
	if typeof(reward) == "number" then
		return reward
	end
	return 0
end

function IndexRewardConfig.IsValidMilestoneId(id: string): boolean
	return definitionById[id] ~= nil
end

return IndexRewardConfig
