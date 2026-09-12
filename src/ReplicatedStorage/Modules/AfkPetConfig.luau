--!strict

--[[
	AFK-only collection. Separate from cave pets.
	Models / icons can be swapped later; ids stay stable.
	Economy 1D: sells stay below cave Commons so overnight AFK cannot match manual Map 1.
]]

export type AfkPetDefinition = {
	Id: string,
	Name: string,
	Rarity: string,
	Weight: number,
	SellPrice: number,
	Icon: string,
	IconKey: string,
	IsTrophy: boolean,
}

local AfkPetConfig = {}

AfkPetConfig.Pets = {
	{
		Id = "pillow_pup",
		Name = "Pillow Pup",
		Rarity = "Common",
		Weight = 40,
		SellPrice = 4,
		Icon = "🐶",
		IconKey = "afk_pet_pillow_pup",
		IsTrophy = false,
	},
	{
		Id = "couch_cat",
		Name = "Couch Cat",
		Rarity = "Common",
		Weight = 32,
		SellPrice = 5,
		Icon = "🐱",
		IconKey = "afk_pet_couch_cat",
		IsTrophy = false,
	},
	{
		Id = "snack_slug",
		Name = "Snack Slug",
		Rarity = "Common",
		Weight = 24,
		SellPrice = 6,
		Icon = "🐌",
		IconKey = "afk_pet_snack_slug",
		IsTrophy = false,
	},
	{
		Id = "lazy_llama",
		Name = "Lazy Llama",
		Rarity = "Uncommon",
		Weight = 12,
		SellPrice = 14,
		Icon = "🦙",
		IconKey = "afk_pet_lazy_llama",
		IsTrophy = false,
	},
	{
		Id = "hammock_hawk",
		Name = "Hammock Hawk",
		Rarity = "Rare",
		Weight = 6,
		SellPrice = 25,
		Icon = "🦅",
		IconKey = "afk_pet_hammock_hawk",
		IsTrophy = false,
	},
	{
		Id = "idle_crown",
		Name = "Idle Crown",
		Rarity = "Trophy",
		Weight = 1,
		SellPrice = 50,
		Icon = "👑",
		IconKey = "afk_pet_idle_crown",
		IsTrophy = true,
	},
} :: { AfkPetDefinition }

local byId: { [string]: AfkPetDefinition } = {}
for _, def in ipairs(AfkPetConfig.Pets) do
	byId[def.Id] = def
end

function AfkPetConfig.Get(petId: string): AfkPetDefinition?
	return byId[petId]
end

function AfkPetConfig.GetTotalWeight(): number
	local total = 0
	for _, def in ipairs(AfkPetConfig.Pets) do
		total += def.Weight
	end
	return total
end

function AfkPetConfig.GetTrophyWeight(): number
	local total = 0
	for _, def in ipairs(AfkPetConfig.Pets) do
		if def.IsTrophy then
			total += def.Weight
		end
	end
	return total
end

function AfkPetConfig.RollWeighted(): AfkPetDefinition
	local total = AfkPetConfig.GetTotalWeight()
	local roll = math.random() * math.max(1e-9, total)
	local running = 0
	for _, def in ipairs(AfkPetConfig.Pets) do
		running += def.Weight
		if roll <= running then
			return def
		end
	end
	return AfkPetConfig.Pets[#AfkPetConfig.Pets]
end

return AfkPetConfig
