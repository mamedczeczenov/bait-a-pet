--!strict

local BaitConfig = require(script.Parent:WaitForChild("BaitConfig"))

export type ShopItem = {
	Id: string,
	Name: string,
	Kind: string,
	Price: number,
	RobuxPrice: number,
	ProductId: number,
	BaitId: string,
	LuckMultiplier: number,
	CatchSpeed: number,
	Icon: string,
	Description: string,
	Color: Color3,
}

local ShopConfig = {}

-- Economy 1D: enough for tutorial sells, not a Bronze skip.
ShopConfig.StartingCoins = 50

local function buildShopItems(): { ShopItem }
	local items = {}

	-- Include free starter bait so it can be re-equipped from the shop.
	for _, bait in ipairs(BaitConfig.Baits) do
		table.insert(items, {
			Id = bait.Id .. "_unlock",
			Name = bait.Name,
			Kind = "BaitUnlock",
			Price = bait.Price,
			RobuxPrice = bait.RobuxPrice,
			ProductId = bait.ProductId,
			BaitId = bait.Id,
			LuckMultiplier = bait.LuckMultiplier,
			CatchSpeed = bait.CatchSpeed,
			Icon = bait.Icon,
			Description = bait.Description,
			Color = bait.Color,
		})
	end

	return items
end

ShopConfig.Items = buildShopItems()

function ShopConfig.GetItem(itemId: string): ShopItem?
	for _, item in ipairs(ShopConfig.Items) do
		if item.Id == itemId then
			return item
		end
	end

	return nil
end

return ShopConfig
