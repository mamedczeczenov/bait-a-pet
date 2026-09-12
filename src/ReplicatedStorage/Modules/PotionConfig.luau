--!strict

--[[
	Consumable potions bought from Upgrades.
	Stored in the backpack and usable from the hotbar (and still from Upgrades).
	Coin potions: unlimited stock, ×2 for 3 min.
	Robux super potions: Developer Products, ×4 for 5 min.
	Same-channel use extends duration and keeps the strongest multiplier.
	Timer only runs while the player is in-session (pauses offline).
]]

export type PotionId = "luck" | "sell" | "super_luck" | "super_sell" | "super_bundle"
export type PotionChannel = "luck" | "sell"
export type PotionCurrency = "Coins" | "Robux"

export type PotionDefinition = {
	Id: PotionId,
	ShopId: string,
	Name: string,
	Channel: PotionChannel,
	Channels: { PotionChannel }?,
	Currency: PotionCurrency,
	Mult: number,
	Price: number,
	RobuxPrice: number,
	ProductId: number,
	DurationSeconds: number,
	IconKey: string,
	Description: string,
}

local PotionConfig = {}

PotionConfig.TechnicalMaxOwned = 99999
PotionConfig.MaxRemainingSeconds = 60 * 60
PotionConfig.DurationSeconds = 180
-- Economy 1D: after Copper (55k). Permanent bait always wins vs a 3-min potion.
PotionConfig.Price = 65000

PotionConfig.CountAttributes = {
	luck = "PotionLuckCount",
	sell = "PotionSellCount",
	super_luck = "PotionSuperLuckCount",
	super_sell = "PotionSuperSellCount",
	super_bundle = "PotionSuperBundleCount",
} :: { [string]: string }

PotionConfig.Potions = {
	{
		Id = "luck",
		ShopId = "potion_luck",
		Name = "Luck Potion",
		Channel = "luck",
		Currency = "Coins",
		Mult = 2,
		Price = PotionConfig.Price,
		RobuxPrice = 0,
		ProductId = 0,
		DurationSeconds = PotionConfig.DurationSeconds,
		IconKey = "station_upgrade_luck",
		Description = "×2 catch luck for 3 minutes.",
	},
	{
		Id = "sell",
		ShopId = "potion_sell",
		Name = "Sell Potion",
		Channel = "sell",
		Currency = "Coins",
		Mult = 2,
		Price = PotionConfig.Price,
		RobuxPrice = 0,
		ProductId = 0,
		DurationSeconds = PotionConfig.DurationSeconds,
		IconKey = "station_upgrade_value",
		Description = "×2 sell value for 3 minutes.",
	},
	{
		Id = "super_luck",
		ShopId = "potion_super_luck",
		Name = "Super Luck Potion",
		Channel = "luck",
		Currency = "Robux",
		Mult = 4,
		Price = 0,
		RobuxPrice = 9,
		-- Creator Dashboard → Developer Products. Paste ID here.
		ProductId = 0,
		DurationSeconds = 300,
		IconKey = "event_lucky",
		Description = "×4 catch luck for 5 minutes.",
	},
	{
		Id = "super_sell",
		ShopId = "potion_super_sell",
		Name = "Super Sell Potion",
		Channel = "sell",
		Currency = "Robux",
		Mult = 4,
		Price = 0,
		RobuxPrice = 9,
		-- Creator Dashboard → Developer Products. Paste ID here.
		ProductId = 0,
		DurationSeconds = 300,
		IconKey = "event_market",
		Description = "×4 sell value for 5 minutes.",
	},
	{
		Id = "super_bundle",
		ShopId = "potion_super_bundle",
		Name = "Super Bundle",
		Channel = "luck",
		Channels = { "luck", "sell" },
		Currency = "Robux",
		Mult = 4,
		Price = 0,
		RobuxPrice = 15,
		-- Creator Dashboard → Developer Products. Paste ID here.
		ProductId = 0,
		DurationSeconds = 300,
		IconKey = "vip_crown",
		Description = "×4 luck and ×4 sell for 5 minutes.",
	},
} :: { PotionDefinition }

local byId: { [string]: PotionDefinition } = {}
local byShopId: { [string]: PotionDefinition } = {}
local byProductId: { [number]: PotionDefinition } = {}
for _, def in ipairs(PotionConfig.Potions) do
	byId[def.Id] = def
	byShopId[def.ShopId] = def
	if def.ProductId > 0 then
		byProductId[def.ProductId] = def
	end
end

function PotionConfig.IsPotionId(potionId: string): boolean
	return byId[potionId] ~= nil
end

function PotionConfig.IsShopId(shopId: string): boolean
	return byShopId[shopId] ~= nil
end

function PotionConfig.Get(potionId: string): PotionDefinition?
	return byId[potionId]
end

function PotionConfig.GetByShopId(shopId: string): PotionDefinition?
	return byShopId[shopId]
end

function PotionConfig.GetByProductId(productId: number): PotionDefinition?
	return byProductId[productId]
end

function PotionConfig.GetChannels(def: PotionDefinition): { PotionChannel }
	if typeof(def.Channels) == "table" and #def.Channels > 0 then
		return def.Channels
	end
	return { def.Channel }
end

function PotionConfig.IsBundle(def: PotionDefinition): boolean
	return #PotionConfig.GetChannels(def) > 1
end

function PotionConfig.IsProductConfigured(def: PotionDefinition): boolean
	return def.Currency == "Robux" and def.ProductId > 0
end

function PotionConfig.GetChannelMultiplier(remainingSeconds: number, activeMult: number): number
	if remainingSeconds <= 0 then
		return 1
	end
	return math.max(1, activeMult)
end

function PotionConfig.FormatTime(seconds: number): string
	local s = math.max(0, math.floor(seconds + 0.5))
	local m = math.floor(s / 60)
	return string.format("%d:%02d", m, s % 60)
end

function PotionConfig.ClampOwned(count: number): number
	return math.clamp(math.floor(count), 0, PotionConfig.TechnicalMaxOwned)
end

function PotionConfig.ClampRemaining(seconds: number): number
	return math.clamp(seconds, 0, PotionConfig.MaxRemainingSeconds)
end

function PotionConfig.ClampActiveMult(mult: number): number
	if typeof(mult) ~= "number" or mult ~= mult then
		return 1
	end
	return math.clamp(mult, 1, 4)
end

function PotionConfig.GetCountAttribute(potionId: string): string?
	return PotionConfig.CountAttributes[potionId]
end

function PotionConfig.GetOwnedFromPlayer(player: Player, potionId: string): number
	local attrName = PotionConfig.CountAttributes[potionId]
	if not attrName then
		return 0
	end
	local value = player:GetAttribute(attrName)
	if typeof(value) == "number" then
		return PotionConfig.ClampOwned(value)
	end
	return 0
end

function PotionConfig.GetButtonVariant(def: PotionDefinition): "vip" | "blue" | "green"
	if def.Currency == "Robux" then
		return "vip"
	end
	if def.Channel == "luck" then
		return "blue"
	end
	return "green"
end

return PotionConfig
