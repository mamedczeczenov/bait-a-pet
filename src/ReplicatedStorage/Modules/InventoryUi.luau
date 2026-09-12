--!strict

local PetConfig = require(script.Parent:WaitForChild("PetConfig"))

export type PetRow = {
	Index: number,
	Name: string,
	Rarity: string,
	OneIn: number?,
	SellPrice: number,
	Icon: string,
	Description: string,
	Locked: boolean?,
	HotbarSlot: number?,
}

local InventoryUi = {}

InventoryUi.SortModes = { "Rarity", "Value", "Newest" }
InventoryUi.BulkRarities = { "Common", "Uncommon", "Rare", "Epic" }

function InventoryUi.SortPets(pets: { PetRow }, mode: string): { PetRow }
	local copy = table.clone(pets)
	if mode == "Value" then
		table.sort(copy, function(a, b)
			if a.SellPrice == b.SellPrice then
				return a.Index > b.Index
			end
			return a.SellPrice > b.SellPrice
		end)
	elseif mode == "Newest" then
		table.sort(copy, function(a, b)
			return a.Index > b.Index
		end)
	else
		table.sort(copy, function(a, b)
			local ai = table.find(PetConfig.RarityOrder, a.Rarity) or 0
			local bi = table.find(PetConfig.RarityOrder, b.Rarity) or 0
			if ai == bi then
				if a.SellPrice == b.SellPrice then
					return a.Index > b.Index
				end
				return a.SellPrice > b.SellPrice
			end
			return ai > bi
		end)
	end
	return copy
end

function InventoryUi.CountSellable(pets: { PetRow }): (number, number)
	local count = 0
	local value = 0
	for _, pet in ipairs(pets) do
		if pet.Locked ~= true then
			count += 1
			value += pet.SellPrice
		end
	end
	return count, value
end

return InventoryUi
