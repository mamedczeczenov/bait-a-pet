--!strict

export type GoalKind = "CatchCount" | "DiscoverRarity" | "EarnCoins"

export type GoalTemplate = {
	Id: string,
	Kind: GoalKind,
	Target: number,
	TargetRarity: string?,
	RewardCoins: number,
	BuffCatches: number,
	BuffMult: number,
	Difficulty: string,
	Title: string,
	Description: string,
}

export type GoalInstance = {
	Uid: string,
	TemplateId: string,
	Progress: number,
	ReadyToClaim: boolean,
}

local GoalConfig = {}

GoalConfig.ActiveSlots = 3
GoalConfig.DefaultBuffMult = 1

-- Economy 1D: targets stay multi-session; rewards feel like bags of sells, not bait skips.
GoalConfig.Templates = {
	{
		Id = "catch_25",
		Kind = "CatchCount",
		Target = 25,
		RewardCoins = 250,
		BuffCatches = 2,
		BuffMult = 1.05,
		Difficulty = "easy",
		Title = "Catch 25 pets",
		Description = "Catch any 25 pets at the cave.",
	},
	{
		Id = "catch_60",
		Kind = "CatchCount",
		Target = 60,
		RewardCoins = 550,
		BuffCatches = 3,
		BuffMult = 1.06,
		Difficulty = "medium",
		Title = "Catch 60 pets",
		Description = "Catch any 60 pets.",
	},
	{
		Id = "catch_120",
		Kind = "CatchCount",
		Target = 120,
		RewardCoins = 950,
		BuffCatches = 4,
		BuffMult = 1.08,
		Difficulty = "hard",
		Title = "Catch 120 pets",
		Description = "Catch any 120 pets.",
	},
	{
		Id = "discover_rare",
		Kind = "DiscoverRarity",
		Target = 1,
		TargetRarity = "Rare",
		RewardCoins = 300,
		BuffCatches = 2,
		BuffMult = 1.05,
		Difficulty = "easy",
		Title = "Discover Rare",
		Description = "Catch a Rare (or higher) pet.",
	},
	{
		Id = "discover_epic",
		Kind = "DiscoverRarity",
		Target = 1,
		TargetRarity = "Epic",
		RewardCoins = 750,
		BuffCatches = 3,
		BuffMult = 1.06,
		Difficulty = "medium",
		Title = "Discover Epic",
		Description = "Catch an Epic (or higher) pet.",
	},
	{
		Id = "discover_legendary",
		Kind = "DiscoverRarity",
		Target = 1,
		TargetRarity = "Legendary",
		RewardCoins = 1600,
		BuffCatches = 4,
		BuffMult = 1.08,
		Difficulty = "hard",
		Title = "Discover Legendary",
		Description = "Catch a Legendary (or higher) pet.",
	},
	{
		Id = "earn_1500",
		Kind = "EarnCoins",
		Target = 2500,
		RewardCoins = 220,
		BuffCatches = 2,
		BuffMult = 1.04,
		Difficulty = "easy",
		Title = "Earn 2,500 coins",
		Description = "Earn 2,500 coins from selling or rewards.",
	},
	{
		Id = "earn_8000",
		Kind = "EarnCoins",
		Target = 14000,
		RewardCoins = 600,
		BuffCatches = 3,
		BuffMult = 1.06,
		Difficulty = "medium",
		Title = "Earn 14,000 coins",
		Description = "Earn 14,000 coins from selling or rewards.",
	},
	{
		Id = "earn_25000",
		Kind = "EarnCoins",
		Target = 45000,
		RewardCoins = 1200,
		BuffCatches = 4,
		BuffMult = 1.08,
		Difficulty = "hard",
		Title = "Earn 45,000 coins",
		Description = "Earn 45,000 coins from selling or rewards.",
	},
} :: { GoalTemplate }

local byId: { [string]: GoalTemplate } = {}
for _, template in ipairs(GoalConfig.Templates) do
	byId[template.Id] = template
end

function GoalConfig.GetTemplate(templateId: string): GoalTemplate?
	return byId[templateId]
end

function GoalConfig.GetTemplatesByDifficulty(difficulty: string): { GoalTemplate }
	local list = {}
	for _, template in ipairs(GoalConfig.Templates) do
		if template.Difficulty == difficulty then
			table.insert(list, template)
		end
	end
	return list
end

return GoalConfig
