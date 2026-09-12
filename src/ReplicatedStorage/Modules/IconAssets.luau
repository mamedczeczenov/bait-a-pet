--!strict

--[[
	Central UI icon registry.
	Image = rbxassetid://… after upload (see tools/upload-icons.mjs).
	Until Image is set, Mount() falls back to Emoji.
]]

local IconAssets = {}

export type IconKey = string

-- Fallback emoji (always available).
IconAssets.Emoji = {
	hud_coins = "🪙",
	hud_luck = "🍀",
	hud_pets = "🐶",
	hud_inventory = "🐶",
	hud_index = "📖",
	hud_rewards = "🎁",
	hud_gifts = "🎁",
	hud_settings = "⚙️",
	btn_close = "X",

	bait_basic = "🪱",
	bait_bronze = "🥉",
	bait_copper = "🟤",
	bait_silver = "🥈",
	bait_cobalt = "🔵",
	bait_platinum = "⚪",
	bait_gold = "🥇",
	bait_diamond = "💎",
	bait_nebula = "🌌",
	bait_fortune = "🍀",

	action_throw = "🎣",
	action_auto_throw = "🔁",
	badge_new = "NEW",
	luck_bar_knob = "●",

	event_rain = "🌧️",
	event_rainbow = "🌈",
	event_lucky = "🍀",
	event_market = "💰",
	event_storm = "⚡",
	event_soon = "⏳",

	tp_shop = "🛒",
	tp_sell = "💵",
	tp_throw = "🎯",
	tp_vip = "👑",
	tp_vip_locked = "🔒",
	tp_afk = "💤",
	tp_portal = "🌀",

	inv_lock = "🔒",
	inv_unlock = "🔓",
	inv_pin = "📌",
	inv_walk = "🐾",
	inv_sort = "↕️",

	station_upgrade_luck = "✨",
	station_upgrade_value = "📈",
	station_soda = "🥤",

	currency_coin_sm = "🪙",
	tab_buy = "BUY",
	tab_sell = "SELL",
	tab_daily = "Daily",
	tab_ads = "Ads",
	tab_goals = "Goals",
	rewards_daily = "📅",
	rewards_ads = "📺",
	rewards_goals = "🎯",
	badge_claim_dot = "●",
	catch_locked = "🔒",
	ui_check = "✓",

	rarity_badge_legendary = "★",
	rarity_badge_mythic = "★",
	rarity_badge_angelic = "✦",
	rarity_badge_glorious = "✦",
	rarity_badge_radiant = "✧",
	rarity_badge_secret = "?",
	rarity_badge_eternal = "∞",
	rarity_badge_divine = "◆",

	hotbar_slot_empty = "+",
	tutorial_arrow = "▼",
	tutorial_guide = "❓",
	confirm_sell = "💰",
	vip_crown = "👑",

	afk_pet_pillow_pup = "🐶",
	afk_pet_couch_cat = "🐱",
	afk_pet_snack_slug = "🐌",
	afk_pet_lazy_llama = "🦙",
	afk_pet_hammock_hawk = "🦅",
	afk_pet_idle_crown = "👑",
} :: { [string]: string }

-- Filled by tools/upload-icons.mjs → IconAssetIds.luau (merged at runtime if present).
IconAssets.Image = {} :: { [string]: string }

IconAssets.BaitIdToKey = {
	basic = "bait_basic",
	bronze = "bait_bronze",
	copper = "bait_copper",
	silver = "bait_silver",
	cobalt = "bait_cobalt",
	platinum = "bait_platinum",
	gold = "bait_gold",
	diamond = "bait_diamond",
	nebula = "bait_nebula",
	fortune = "bait_fortune",
} :: { [string]: string }

IconAssets.EventIdToKey = {
	rain = "event_rain",
	rainbow = "event_rainbow",
	lucky = "event_lucky",
	market = "event_market",
	storm = "event_storm",
} :: { [string]: string }

IconAssets.RarityBadgeKey = {
	Legendary = "rarity_badge_legendary",
	Mythic = "rarity_badge_mythic",
	Angelic = "rarity_badge_angelic",
	Glorious = "rarity_badge_glorious",
	Radiant = "rarity_badge_radiant",
	Secret = "rarity_badge_secret",
	Eternal = "rarity_badge_eternal",
	Divine = "rarity_badge_divine",
} :: { [string]: string }

local function normalizeImageUri(value: string): string?
	if value == "" then
		return nil
	end
	if string.sub(value, 1, 11) == "rbxassetid:" or string.sub(value, 1, 13) == "rbxthumb://" then
		return value
	end
	if string.match(value, "^%d+$") then
		return "rbxassetid://" .. value
	end
	return value
end

function IconAssets.LoadGeneratedIds(map: { [string]: string })
	for key, value in pairs(map) do
		local uri = normalizeImageUri(value)
		if uri then
			IconAssets.Image[key] = uri
		end
	end
end

-- Optional generated module written by upload tool.
do
	local generatedModule = script.Parent:FindFirstChild("IconAssetIds")
	if generatedModule and generatedModule:IsA("ModuleScript") then
		local ok, generated = pcall(require, generatedModule)
		if ok and typeof(generated) == "table" then
			local ids = (generated :: any).Ids or generated
			if typeof(ids) == "table" then
				IconAssets.LoadGeneratedIds(ids :: { [string]: string })
			end
		end
	end
end

function IconAssets.GetEmoji(key: string): string
	return IconAssets.Emoji[key] or "❓"
end

function IconAssets.GetImage(key: string): string?
	local raw = IconAssets.Image[key]
	if typeof(raw) ~= "string" or raw == "" then
		return nil
	end
	return normalizeImageUri(raw)
end

function IconAssets.HasImage(key: string): boolean
	return IconAssets.GetImage(key) ~= nil
end

function IconAssets.KeyForBaitId(baitId: string): string
	return IconAssets.BaitIdToKey[baitId] or "bait_basic"
end

function IconAssets.KeyForEventId(eventId: string): string
	return IconAssets.EventIdToKey[eventId] or "event_rain"
end

function IconAssets.KeyForRarityBadge(rarity: string): string?
	return IconAssets.RarityBadgeKey[rarity]
end

return IconAssets
