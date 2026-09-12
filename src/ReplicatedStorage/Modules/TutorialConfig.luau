--!strict

export type TutorialStepDefinition = {
	Id: string,
	Title: string,
	Body: string,
	Highlight: string?,
	AllowedActions: { [string]: boolean },
	CompleteOn: { [string]: boolean },
	SoftLockHint: string,
}

local TutorialConfig = {}

TutorialConfig.StartDelaySeconds = 2.5
TutorialConfig.StepStuckHintSeconds = 60
-- Economy 1D: tutorial payout is a few Common sells, not a shop skip.
TutorialConfig.RewardCoins = 80
TutorialConfig.StepCount = 4

TutorialConfig.Steps = {
	{
		Id = "goto_cave",
		Title = "Go to the cave",
		Body = "Click THROW at the top of the screen to teleport to the cave.",
		Highlight = "teleport_throw",
		AllowedActions = {
			teleport_throw = true,
			throw_bait = true,
		},
		CompleteOn = {
			teleport_throw = true,
			throw_started = true,
		},
		SoftLockHint = "First click THROW at the top to reach the cave.",
	},
	{
		Id = "catch_pet",
		Title = "Catch a pet",
		Body = "Near the cave, throw bait and press SPACE when the luck bar is high. You must catch a pet.",
		Highlight = "throw_bait",
		AllowedActions = {
			teleport_throw = true,
			throw_bait = true,
		},
		CompleteOn = {
			catch_pet = true,
		},
		SoftLockHint = "First catch a pet: throw bait + SPACE on the luck bar.",
	},
	{
		Id = "sell_pet",
		Title = "Sell a pet",
		Body = "Click SELL at the top, open the sell panel, and sell your caught pet for coins.",
		Highlight = "teleport_sell",
		AllowedActions = {
			teleport_sell = true,
			teleport_throw = true,
			throw_bait = true,
			open_sell = true,
			sell_pet = true,
			sell_all = true,
		},
		CompleteOn = {
			sell_pet = true,
			sell_all = true,
		},
		SoftLockHint = "First sell a pet: click SELL, then sell in the panel.",
	},
	{
		Id = "shop_or_upgrade",
		Title = "Shop or upgrades",
		Body = "Open SHOP or an upgrade station to see what you can spend coins on.",
		Highlight = "teleport_shop",
		AllowedActions = {
			teleport_shop = true,
			teleport_sell = true,
			teleport_throw = true,
			throw_bait = true,
			open_sell = true,
			open_shop = true,
			open_upgrade = true,
			sell_pet = true,
			sell_all = true,
			buy_item = true,
			buy_upgrade = true,
		},
		CompleteOn = {
			open_shop = true,
			open_upgrade = true,
			teleport_shop = true,
		},
		SoftLockHint = "Open the shop (SHOP) or an upgrade station.",
	},
} :: { TutorialStepDefinition }

TutorialConfig.StuckHints = {
	[1] = "Hint: THROW is at the top of the screen. You can also walk to the cave and throw bait.",
	[2] = "Hint: stand close to the cave until the throw button turns green, then SPACE on high luck.",
	[3] = "Hint: click red SELL at the top, then sell a pet in the panel.",
	[4] = "Hint: click green SHOP at the top or walk to an upgrade station on the map.",
}

function TutorialConfig.GetStep(stepIndex: number): TutorialStepDefinition?
	return TutorialConfig.Steps[stepIndex]
end

return TutorialConfig
