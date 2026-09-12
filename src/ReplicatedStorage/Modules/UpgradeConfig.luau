--!strict

local UpgradeConfig = {}

UpgradeConfig.MaxLevel = 50
UpgradeConfig.BaseCost = 6000
UpgradeConfig.CostGrowth = 1.58

-- Economy 1D: first luck/bag is the session-1 win (~10–15 min), before Bronze.
UpgradeConfig.EarlyCosts = {
	[0] = 2000,
	[1] = 4500,
	[2] = 8000,
}

UpgradeConfig.LuckPerLevel = 0.035
UpgradeConfig.ValuePerLevel = 0.02

-- Catch speed upgrade: at MaxLevel → ~30% shorter cooldown.
UpgradeConfig.MaxCatchCooldownReduction = 0.30

-- Bag capacity: base 30 + 5 per BagLevel, max 150 (level 24).
UpgradeConfig.BaseBagCapacity = 30
UpgradeConfig.BagSlotsPerLevel = 5
UpgradeConfig.MaxBagLevel = 24
UpgradeConfig.BagAlmostFullRatio = 0.9

export type UpgradeId = "luck" | "value" | "speed" | "bag"

export type RobuxSkipDefinition = {
	UpgradeId: UpgradeId,
	Name: string,
	RobuxPrice: number,
	-- Creator Dashboard → Developer Products. Paste ID here (0 = not configured).
	ProductId: number,
}

-- One Robux purchase maxes that upgrade. Coins still buy +1 level.
-- Priced vs VIP 99 R$: bag < VIP; speed ≈ VIP; luck/value a bit above (2.75x / 2x everywhere).
UpgradeConfig.RobuxSkip = {
	luck = { UpgradeId = "luck", Name = "Luck MAX", RobuxPrice = 149, ProductId = 0 },
	value = { UpgradeId = "value", Name = "Value MAX", RobuxPrice = 149, ProductId = 0 },
	speed = { UpgradeId = "speed", Name = "Catch Speed MAX", RobuxPrice = 99, ProductId = 0 },
	bag = { UpgradeId = "bag", Name = "Bag MAX", RobuxPrice = 49, ProductId = 0 },
} :: { [string]: RobuxSkipDefinition }

function UpgradeConfig.ClampLevel(level: number): number
	return math.clamp(math.floor(level), 0, UpgradeConfig.MaxLevel)
end

function UpgradeConfig.ClampBagLevel(level: number): number
	return math.clamp(math.floor(level), 0, UpgradeConfig.MaxBagLevel)
end

function UpgradeConfig.GetLuckBonus(level: number): number
	return 1 + UpgradeConfig.ClampLevel(level) * UpgradeConfig.LuckPerLevel
end

function UpgradeConfig.GetValueMultiplier(level: number): number
	return 1 + UpgradeConfig.ClampLevel(level) * UpgradeConfig.ValuePerLevel
end

-- Divisor applied to catch cooldown (1 = none). Max level ≈ 1/(1-0.30) ≈ 1.429.
function UpgradeConfig.GetCatchSpeedBonus(level: number): number
	local t = UpgradeConfig.ClampLevel(level) / UpgradeConfig.MaxLevel
	local maxSpeed = 1 / (1 - UpgradeConfig.MaxCatchCooldownReduction)
	return 1 + (maxSpeed - 1) * t
end

function UpgradeConfig.GetCatchCooldownReductionPercent(level: number): number
	local bonus = UpgradeConfig.GetCatchSpeedBonus(level)
	return math.floor((1 - (1 / bonus)) * 100 + 0.5)
end

function UpgradeConfig.GetBagCapacity(bagLevel: number): number
	return UpgradeConfig.BaseBagCapacity
		+ UpgradeConfig.ClampBagLevel(bagLevel) * UpgradeConfig.BagSlotsPerLevel
end

-- Cost to buy the next level (from current level -> level+1).
function UpgradeConfig.GetCost(level: number): number?
	local clamped = UpgradeConfig.ClampLevel(level)
	if clamped >= UpgradeConfig.MaxLevel then
		return nil
	end

	local earlyCost = UpgradeConfig.EarlyCosts[clamped]
	if typeof(earlyCost) == "number" then
		return earlyCost
	end

	return math.floor(UpgradeConfig.BaseCost * (UpgradeConfig.CostGrowth ^ clamped))
end

function UpgradeConfig.GetBagCost(bagLevel: number): number?
	local clamped = UpgradeConfig.ClampBagLevel(bagLevel)
	if clamped >= UpgradeConfig.MaxBagLevel then
		return nil
	end

	local earlyCost = UpgradeConfig.EarlyCosts[clamped]
	if typeof(earlyCost) == "number" then
		return earlyCost
	end

	return math.floor(UpgradeConfig.BaseCost * (UpgradeConfig.CostGrowth ^ clamped))
end

function UpgradeConfig.IsValidId(upgradeId: string): boolean
	return upgradeId == "luck" or upgradeId == "value" or upgradeId == "speed" or upgradeId == "bag"
end

function UpgradeConfig.GetMaxLevelFor(upgradeId: string): number
	if upgradeId == "bag" then
		return UpgradeConfig.MaxBagLevel
	end
	return UpgradeConfig.MaxLevel
end

function UpgradeConfig.GetRobuxSkip(upgradeId: string): RobuxSkipDefinition?
	return UpgradeConfig.RobuxSkip[upgradeId]
end

function UpgradeConfig.GetByProductId(productId: number): RobuxSkipDefinition?
	if productId <= 0 then
		return nil
	end
	for _, def in pairs(UpgradeConfig.RobuxSkip) do
		if def.ProductId == productId then
			return def
		end
	end
	return nil
end

function UpgradeConfig.IsProductConfigured(def: RobuxSkipDefinition): boolean
	return def.RobuxPrice > 0 and def.ProductId > 0
end

return UpgradeConfig
