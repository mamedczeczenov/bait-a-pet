--!strict

export type BaitDefinition = {
	Id: string,
	Name: string,
	LuckMultiplier: number,
	-- 1 = normal catch cooldown; >1 shortens cooldown (CatchCooldown / CatchSpeed).
	CatchSpeed: number,
	Price: number,
	RobuxPrice: number,
	-- Creator Dashboard → Developer Products. Paste ID here (0 = not configured).
	ProductId: number,
	Icon: string,
	Description: string,
	Color: Color3,
	StartingUnlocked: boolean,
}

local NumberFormat = require(script.Parent:WaitForChild("NumberFormat"))

local BaitConfig = {}

BaitConfig.DefaultBaitId = "basic"
BaitConfig.CatchZoneTag = "BaitCatchZone"
BaitConfig.CaveTag = "BaitCave"
BaitConfig.CatchZoneRadius = 50
BaitConfig.CatchCooldown = 2.8
BaitConfig.RevealWalkDuration = 1.0
BaitConfig.RevealWalkStudsPerSecond = 9
BaitConfig.MinCatchCooldown = 1.1

-- Economy 1D Map 1 coin ladder (F2P, Fisch-like tool upgrades — not PS99 15-min worlds):
-- Bronze ~50–75 min, Copper day 2, Silver 2–3 days casual. Gold+ is Map 1 long tail.
-- Robux skips, priced vs VIP gamepass (99 R$ for 4x luck in the VIP cave, forever).
-- Bronze 3x < VIP 4x, so VIP stays the better first "power" buy. From Copper (8x) up,
-- baits cost more than VIP because they beat 4x luck everywhere.
BaitConfig.Baits = {
	{
		Id = "basic",
		Name = "Basic Bait",
		LuckMultiplier = 1,
		CatchSpeed = 1,
		Price = 0,
		RobuxPrice = 0,
		ProductId = 0,
		Icon = "🪱",
		Description = "Free starter bait. 1x luck. Unlimited once unlocked.",
		Color = Color3.fromRGB(140, 110, 70),
		StartingUnlocked = true,
	},
	{
		Id = "bronze",
		Name = "Bronze Bait",
		LuckMultiplier = 3,
		CatchSpeed = 1,
		Price = 16000,
		RobuxPrice = 49,
		ProductId = 0,
		Icon = "🥉",
		Description = "3x luck. Affordable step up. Buy once for unlimited use.",
		Color = Color3.fromRGB(180, 120, 70),
		StartingUnlocked = false,
	},
	{
		Id = "copper",
		Name = "Copper Bait",
		LuckMultiplier = 8,
		CatchSpeed = 1,
		Price = 55000,
		RobuxPrice = 149,
		ProductId = 0,
		Icon = "🟤",
		Description = "8x luck. Step between Bronze and Silver.",
		Color = Color3.fromRGB(200, 110, 55),
		StartingUnlocked = false,
	},
	{
		Id = "silver",
		Name = "Silver Bait",
		LuckMultiplier = 25,
		CatchSpeed = 1,
		Price = 165000,
		RobuxPrice = 249,
		ProductId = 0,
		Icon = "🥈",
		Description = "25x luck. Buy once for unlimited use.",
		Color = Color3.fromRGB(170, 185, 205),
		StartingUnlocked = false,
	},
	{
		Id = "cobalt",
		Name = "Cobalt Bait",
		LuckMultiplier = 80,
		CatchSpeed = 1.05,
		Price = 480000,
		RobuxPrice = 399,
		ProductId = 0,
		Icon = "🔵",
		Description = "80x luck · 1.05x catch speed.",
		Color = Color3.fromRGB(50, 110, 220),
		StartingUnlocked = false,
	},
	{
		Id = "platinum",
		Name = "Platinum Bait",
		LuckMultiplier = 450,
		CatchSpeed = 1.1,
		Price = 1800000,
		RobuxPrice = 599,
		ProductId = 0,
		Icon = "⚪",
		Description = "450x luck · 1.1x catch speed.",
		Color = Color3.fromRGB(210, 220, 235),
		StartingUnlocked = false,
	},
	{
		Id = "gold",
		Name = "Gold Bait",
		LuckMultiplier = 2500,
		CatchSpeed = 1.1,
		Price = 6500000,
		RobuxPrice = 799,
		ProductId = 0,
		Icon = "🥇",
		Description = "2.5Kx luck · 1.1x catch speed.",
		Color = Color3.fromRGB(230, 180, 60),
		StartingUnlocked = false,
	},
	{
		Id = "diamond",
		Name = "Diamond Bait",
		LuckMultiplier = 15000,
		CatchSpeed = 1.15,
		Price = 22000000,
		RobuxPrice = 999,
		ProductId = 0,
		Icon = "💎",
		Description = "15Kx luck · 1.15x catch speed.",
		Color = Color3.fromRGB(140, 220, 255),
		StartingUnlocked = false,
	},
	{
		Id = "nebula",
		Name = "Nebula Bait",
		LuckMultiplier = 90000,
		CatchSpeed = 1.2,
		Price = 75000000,
		RobuxPrice = 1499,
		ProductId = 0,
		Icon = "🌌",
		Description = "90Kx luck · 1.2x catch speed.",
		Color = Color3.fromRGB(120, 70, 200),
		StartingUnlocked = false,
	},
	{
		Id = "fortune",
		Name = "Fortune Bait",
		LuckMultiplier = 250000,
		CatchSpeed = 1.25,
		Price = 150000000,
		RobuxPrice = 1999,
		ProductId = 0,
		Icon = "🍀",
		Description = "250Kx luck · 1.25x catch speed. Endgame bait.",
		Color = Color3.fromRGB(70, 190, 120),
		StartingUnlocked = false,
	},
} :: { BaitDefinition }

function BaitConfig.GetById(baitId: string): BaitDefinition?
	for _, bait in ipairs(BaitConfig.Baits) do
		if bait.Id == baitId then
			return bait
		end
	end

	return nil
end

function BaitConfig.GetLuckMultiplier(baitId: string): number
	local bait = BaitConfig.GetById(baitId)
	if bait then
		return bait.LuckMultiplier
	end

	return 1
end

function BaitConfig.GetCatchSpeed(baitId: string): number
	local bait = BaitConfig.GetById(baitId)
	if bait and typeof(bait.CatchSpeed) == "number" and bait.CatchSpeed > 0 then
		return bait.CatchSpeed
	end
	return 1
end

function BaitConfig.GetCatchCooldown(baitId: string, upgradeSpeed: number?): number
	local speed = BaitConfig.GetCatchSpeed(baitId)
	local upSpeed = 1
	if typeof(upgradeSpeed) == "number" and upgradeSpeed > 0 then
		upSpeed = upgradeSpeed
	end
	local cooldown = BaitConfig.CatchCooldown / math.max(0.5, speed) / math.max(1, upSpeed)
	return math.max(BaitConfig.MinCatchCooldown, cooldown)
end

function BaitConfig.GetStartingUnlocked(): { string }
	local unlocked = {}
	for _, bait in ipairs(BaitConfig.Baits) do
		if bait.StartingUnlocked then
			table.insert(unlocked, bait.Id)
		end
	end
	return unlocked
end

function BaitConfig.IsValidId(baitId: string): boolean
	return BaitConfig.GetById(baitId) ~= nil
end

function BaitConfig.GetByProductId(productId: number): BaitDefinition?
	if productId <= 0 then
		return nil
	end
	for _, bait in ipairs(BaitConfig.Baits) do
		if bait.ProductId == productId then
			return bait
		end
	end
	return nil
end

function BaitConfig.IsProductConfigured(bait: BaitDefinition): boolean
	return bait.RobuxPrice > 0 and bait.ProductId > 0
end

function BaitConfig.FormatLuck(mult: number): string
	return NumberFormat.FormatLuck(mult)
end

function BaitConfig.FormatSpeed(speed: number): string
	if speed <= 1.001 then
		return ""
	end
	return NumberFormat.FormatCompact(speed) .. "x spd"
end

return BaitConfig
