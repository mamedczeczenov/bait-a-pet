--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local NumberFormat = require(Modules:WaitForChild("NumberFormat"))
local PotionConfig = require(Modules:WaitForChild("PotionConfig"))
local PotionPurchase = require(Modules:WaitForChild("PotionPurchase"))
local RobuxPurchase = require(Modules:WaitForChild("RobuxPurchase"))
local UpgradeConfig = require(Modules:WaitForChild("UpgradeConfig"))
local UiIcon = require(Modules:WaitForChild("UiIcon"))
local UiTheme = require(Modules:WaitForChild("UiTheme"))
local UiToast = require(Modules:WaitForChild("UiToast"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local openUpgradeRemote = remotes:WaitForChild("OpenUpgrade") :: RemoteEvent
local buyUpgradeRemote = remotes:WaitForChild("BuyUpgrade") :: RemoteEvent
local usePotionRemote = remotes:WaitForChild("UsePotion") :: RemoteEvent
local upgradeResultRemote = remotes:WaitForChild("UpgradeResult") :: RemoteEvent

local screenGui = UiTheme.Create("ScreenGui", {
	Name = "UpgradeGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 8,
}, playerGui) :: ScreenGui
UiTheme.MobileScale(screenGui)

local panel = UiTheme.Panel({
	Name = "UpgradePanel",
	Size = UDim2.fromOffset(600, 580),
	Parent = screenGui,
	Visible = false,
})

local _, closeButton = UiTheme.Header(panel, "Upgrades", function()
	panel.Visible = false
end)
if closeButton then
	UiIcon.ApplyToButton(closeButton, "btn_close", 22)
end

local balanceLabel = UiTheme.Label({
	Name = "Balance",
	Text = "Coins: 0",
	Parent = panel,
	Position = UDim2.fromOffset(20, 52),
	Size = UDim2.new(1, -40, 0, 24),
	TextSize = 17,
	Color = UiTheme.Colors.AccentAmber,
	Font = UiTheme.FontMedium,
	XAlign = Enum.TextXAlignment.Right,
})

local statusLabel = UiTheme.Label({
	Name = "Status",
	Text = "Coins: +1 level. Robux: skip to MAX.",
	Parent = panel,
	Position = UDim2.fromOffset(20, 76),
	Size = UDim2.new(1, -40, 0, 20),
	TextSize = 13,
	Color = UiTheme.Colors.TextDim,
})

local list = UiTheme.Create("ScrollingFrame", {
	Name = "List",
	BackgroundColor3 = UiTheme.Colors.BgRaised,
	Position = UDim2.fromOffset(12, 100),
	Size = UDim2.fromOffset(576, 464),
	CanvasSize = UDim2.fromOffset(0, 0),
	ZIndex = 2,
	BorderSizePixel = 0,
}, panel) :: ScrollingFrame
UiTheme.StyleScrollingFrame(list)
UiTheme.Corner(list, UiTheme.CornerSmall)
UiTheme.Stroke(list, UiTheme.Colors.Stroke, 3, 0)
UiTheme.EnsureScrollPadding(list)

local listLayout = UiTheme.Create("UIListLayout", {
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, list) :: UIListLayout
UiTheme.BindScrollCanvas(list, listLayout)

type RowRefs = {
	Root: Frame,
	LevelLabel: TextLabel,
	BonusLabel: TextLabel,
	BuyButton: TextButton,
	RobuxButton: TextButton,
}

type PotionRowRefs = {
	Root: Frame,
	OwnedLabel: TextLabel,
	BonusLabel: TextLabel,
	BuyButton: TextButton,
	UseButton: TextButton,
}

local function createUpgradeRow(name: string, layoutOrder: number, variant: UiTheme.ButtonVariant, iconKey: string): RowRefs
	local row = UiTheme.Row({
		Name = name .. "Row",
		Parent = list,
		Size = UDim2.new(1, 0, 0, 92),
		LayoutOrder = layoutOrder,
	})

	UiIcon.Mount(row, {
		Key = iconKey,
		Name = "RowIcon",
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.fromOffset(12, 28),
		ZIndex = 3,
		ImageSize = 28,
	})

	UiTheme.Label({
		Name = "Title",
		Text = name,
		Parent = row,
		Position = UDim2.fromOffset(56, 10),
		Size = UDim2.fromOffset(220, 22),
		TextSize = 18,
		Font = UiTheme.FontTitle,
	})

	local levelLabel = UiTheme.Label({
		Name = "Level",
		Text = "Level 0 / 50",
		Parent = row,
		Position = UDim2.fromOffset(56, 34),
		Size = UDim2.fromOffset(220, 18),
		TextSize = 14,
		Color = UiTheme.Colors.TextDim,
		Font = UiTheme.FontMedium,
	})

	local bonusLabel = UiTheme.Label({
		Name = "Bonus",
		Text = "Bonus: 1.00x",
		Parent = row,
		Position = UDim2.fromOffset(56, 56),
		Size = UDim2.fromOffset(220, 20),
		TextSize = 14,
		Color = UiTheme.ButtonColor(variant),
		Font = UiTheme.FontTitle,
	})

	local robuxButton = UiTheme.Button({
		Name = "Robux",
		Text = "MAX",
		Parent = row,
		Size = UDim2.fromOffset(100, 40),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -120, 0.5, 0),
		Variant = "vip",
		TextSize = 14,
	})

	local buyButton = UiTheme.Button({
		Name = "Buy",
		Text = "Upgrade",
		Parent = row,
		Size = UDim2.fromOffset(100, 40),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Variant = variant,
		TextSize = 15,
	})

	return {
		Root = row,
		LevelLabel = levelLabel,
		BonusLabel = bonusLabel,
		BuyButton = buyButton,
		RobuxButton = robuxButton,
	}
end

local function createPotionRow(name: string, layoutOrder: number, variant: UiTheme.ButtonVariant, iconKey: string): PotionRowRefs
	local row = UiTheme.Row({
		Name = name .. "Row",
		Parent = list,
		Size = UDim2.new(1, 0, 0, 108),
		LayoutOrder = layoutOrder,
	})

	UiIcon.Mount(row, {
		Key = iconKey,
		Name = "RowIcon",
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.fromOffset(12, 36),
		ZIndex = 3,
		ImageSize = 28,
	})

	UiTheme.Label({
		Name = "Title",
		Text = name,
		Parent = row,
		Position = UDim2.fromOffset(56, 10),
		Size = UDim2.fromOffset(230, 22),
		TextSize = 18,
		Font = UiTheme.FontTitle,
	})

	local ownedLabel = UiTheme.Label({
		Name = "Owned",
		Text = "Owned: 0",
		Parent = row,
		Position = UDim2.fromOffset(56, 34),
		Size = UDim2.fromOffset(230, 18),
		TextSize = 14,
		Color = UiTheme.Colors.TextDim,
		Font = UiTheme.FontMedium,
	})

	local bonusLabel = UiTheme.Label({
		Name = "Bonus",
		Text = "×2 for 3 min",
		Parent = row,
		Position = UDim2.fromOffset(56, 56),
		Size = UDim2.fromOffset(230, 36),
		TextSize = 14,
		Color = UiTheme.ButtonColor(variant),
		Font = UiTheme.FontTitle,
	})

	local buyButton = UiTheme.Button({
		Name = "Buy",
		Text = "Buy",
		Parent = row,
		Size = UDim2.fromOffset(118, 36),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 14),
		Variant = variant,
		TextSize = 14,
	})

	local useButton = UiTheme.Button({
		Name = "Use",
		Text = "Use",
		Parent = row,
		Size = UDim2.fromOffset(118, 36),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -14),
		Variant = "primary",
		TextSize = 14,
	})

	return {
		Root = row,
		OwnedLabel = ownedLabel,
		BonusLabel = bonusLabel,
		BuyButton = buyButton,
		UseButton = useButton,
	}
end

local luckRow = createUpgradeRow("Luck", 1, "blue", "station_upgrade_luck")
local speedRow = createUpgradeRow("Catch Speed", 2, "pink", "action_throw")
local valueRow = createUpgradeRow("Value Multiplier", 3, "green", "station_upgrade_value")
local bagRow = createUpgradeRow("Bag Capacity", 4, "cyan", "hud_inventory")

local potionRows: { [string]: PotionRowRefs } = {}
for index, def in ipairs(PotionConfig.Potions) do
	local variant: UiTheme.ButtonVariant = if def.Currency == "Robux"
		then "vip"
		elseif def.Channel == "luck" then "blue"
		else "green"
	potionRows[def.Id] = createPotionRow(def.Name, 4 + index, variant, def.IconKey)
end
UiTheme.AddScrollSpacer(list, 20)

local lastPayload: any = nil
local luckRemainValue = 0
local luckRemainAt = os.clock()
local sellRemainValue = 0
local sellRemainAt = os.clock()

local function formatCost(cost: number?): string
	if cost == nil then
		return "MAX"
	end
	return NumberFormat.FormatCoins(cost) .. "$"
end

local function styleBuyButton(button: TextButton, cost: number?, variant: UiTheme.ButtonVariant)
	button.Text = formatCost(cost)
	button.AutoButtonColor = cost ~= nil
	button.BackgroundColor3 = if cost ~= nil then UiTheme.ButtonColor(variant) else UiTheme.Colors.BgMuted
end

local function styleRobuxButton(button: TextButton, skip: UpgradeConfig.RobuxSkipDefinition?, cost: number?)
	if cost == nil then
		button.Text = "MAX"
		button.AutoButtonColor = false
		button.BackgroundColor3 = UiTheme.Colors.BgMuted
		return
	end
	local price = if skip then skip.RobuxPrice else 0
	button.Text = string.format("MAX %d R$", price)
	button.AutoButtonColor = true
	button.BackgroundColor3 = UiTheme.ButtonColor("vip")
end

local function stylePotionButtons(row: PotionRowRefs, owned: number, def: PotionConfig.PotionDefinition)
	if def.Currency == "Robux" then
		row.BuyButton.Text = string.format("%d R$", def.RobuxPrice)
		row.BuyButton.AutoButtonColor = true
		row.BuyButton.BackgroundColor3 = UiTheme.ButtonColor("vip")
	else
		row.BuyButton.Text = formatCost(def.Price)
		row.BuyButton.AutoButtonColor = true
		row.BuyButton.BackgroundColor3 = UiTheme.ButtonColor(if def.Channel == "luck" then "blue" else "green")
	end

	local canUse = owned > 0
	row.UseButton.Text = "Use"
	row.UseButton.AutoButtonColor = canUse
	row.UseButton.BackgroundColor3 = if canUse then UiTheme.ButtonColor("primary") else UiTheme.Colors.BgMuted
end

local function potionBonusText(remaining: number, channel: string, activeMult: number, idleText: string): string
	if remaining > 0 then
		return string.format("Active ×%.0f  ·  %s left", math.max(1, activeMult), PotionConfig.FormatTime(remaining))
	end
	return idleText
end

local function potionRowBonus(def: PotionConfig.PotionDefinition, luckRemaining: number, sellRemaining: number, luckMult: number, sellMult: number): string
	if PotionConfig.IsBundle(def) then
		if luckRemaining > 0 or sellRemaining > 0 then
			return string.format(
				"Active ×%.0f luck + ×%.0f sell",
				if luckRemaining > 0 then luckMult else 1,
				if sellRemaining > 0 then sellMult else 1
			)
		end
		return def.Description
	end
	local remaining = if def.Channel == "luck" then luckRemaining else sellRemaining
	local activeMult = if def.Channel == "luck" then luckMult else sellMult
	return potionBonusText(remaining, def.Channel, activeMult, def.Description)
end

local function applyPayload(payload: any, openPanel: boolean?)
	if typeof(payload) ~= "table" then
		return
	end

	lastPayload = payload

	if openPanel then
		panel.Visible = true
	end

	local coins = if typeof(payload.Coins) == "number" then payload.Coins else 0
	balanceLabel.Text = string.format("Coins: %s", NumberFormat.FormatCoins(coins))

	local maxLevel = if typeof(payload.MaxLevel) == "number" then payload.MaxLevel else 50
	local maxBagLevel = if typeof(payload.MaxBagLevel) == "number" then payload.MaxBagLevel else 24
	local luckLevel = if typeof(payload.LuckLevel) == "number" then payload.LuckLevel else 0
	local valueLevel = if typeof(payload.ValueLevel) == "number" then payload.ValueLevel else 0
	local speedLevel = if typeof(payload.SpeedLevel) == "number" then payload.SpeedLevel else 0
	local bagLevel = if typeof(payload.BagLevel) == "number" then payload.BagLevel else 0
	local bagCapacity = if typeof(payload.BagCapacity) == "number" then payload.BagCapacity else 30
	local petCount = if typeof(payload.PetCount) == "number" then payload.PetCount else 0
	local luckBonus = if typeof(payload.LuckBonus) == "number" then payload.LuckBonus else 1
	local valueMult = if typeof(payload.ValueMult) == "number" then payload.ValueMult else 1
	local speedReduction = if typeof(payload.CatchCooldownReductionPercent) == "number"
		then payload.CatchCooldownReductionPercent
		else 0
	local luckCost = if typeof(payload.LuckCost) == "number" then payload.LuckCost else nil
	local valueCost = if typeof(payload.ValueCost) == "number" then payload.ValueCost else nil
	local speedCost = if typeof(payload.SpeedCost) == "number" then payload.SpeedCost else nil
	local bagCost = if typeof(payload.BagCost) == "number" then payload.BagCost else nil

	luckRow.LevelLabel.Text = string.format("Level %d / %d", luckLevel, maxLevel)
	luckRow.BonusLabel.Text = string.format("Catch luck: %.2fx", luckBonus)
	styleBuyButton(luckRow.BuyButton, luckCost, "blue")
	styleRobuxButton(luckRow.RobuxButton, UpgradeConfig.GetRobuxSkip("luck"), luckCost)

	speedRow.LevelLabel.Text = string.format("Level %d / %d", speedLevel, maxLevel)
	speedRow.BonusLabel.Text = string.format("Cooldown: -%d%%", speedReduction)
	styleBuyButton(speedRow.BuyButton, speedCost, "pink")
	styleRobuxButton(speedRow.RobuxButton, UpgradeConfig.GetRobuxSkip("speed"), speedCost)

	valueRow.LevelLabel.Text = string.format("Level %d / %d", valueLevel, maxLevel)
	valueRow.BonusLabel.Text = string.format("Sell value: %.2fx", valueMult)
	styleBuyButton(valueRow.BuyButton, valueCost, "green")
	styleRobuxButton(valueRow.RobuxButton, UpgradeConfig.GetRobuxSkip("value"), valueCost)

	bagRow.LevelLabel.Text = string.format("Level %d / %d", bagLevel, maxBagLevel)
	bagRow.BonusLabel.Text = string.format("Pets: %d / %d", petCount, bagCapacity)
	styleBuyButton(bagRow.BuyButton, bagCost, "cyan")
	styleRobuxButton(bagRow.RobuxButton, UpgradeConfig.GetRobuxSkip("bag"), bagCost)

	local ownedById = {
		luck = if typeof(payload.PotionLuckCount) == "number" then payload.PotionLuckCount else 0,
		sell = if typeof(payload.PotionSellCount) == "number" then payload.PotionSellCount else 0,
		super_luck = if typeof(payload.PotionSuperLuckCount) == "number" then payload.PotionSuperLuckCount else 0,
		super_sell = if typeof(payload.PotionSuperSellCount) == "number" then payload.PotionSuperSellCount else 0,
		super_bundle = if typeof(payload.PotionSuperBundleCount) == "number" then payload.PotionSuperBundleCount else 0,
	}
	local luckRemaining = if typeof(payload.PotionLuckRemaining) == "number" then payload.PotionLuckRemaining else 0
	local sellRemaining = if typeof(payload.PotionSellRemaining) == "number" then payload.PotionSellRemaining else 0
	local luckMult = if typeof(payload.PotionLuckMult) == "number" then payload.PotionLuckMult else 1
	local sellMult = if typeof(payload.PotionSellMult) == "number" then payload.PotionSellMult else 1
	luckRemainValue = luckRemaining
	luckRemainAt = os.clock()
	sellRemainValue = sellRemaining
	sellRemainAt = os.clock()

	for _, def in ipairs(PotionConfig.Potions) do
		local row = potionRows[def.Id]
		if row then
			local owned = ownedById[def.Id] or 0
			row.OwnedLabel.Text = string.format("Owned: %d", owned)
			row.BonusLabel.Text = potionRowBonus(def, luckRemaining, sellRemaining, luckMult, sellMult)
			stylePotionButtons(row, owned, def)
		end
	end
end

local function liveChannelRemaining(channel: string): number
	if channel == "luck" then
		return math.max(0, luckRemainValue - (os.clock() - luckRemainAt))
	end
	return math.max(0, sellRemainValue - (os.clock() - sellRemainAt))
end

local function liveChannelMult(channel: string): number
	local attr = if channel == "luck" then localPlayer:GetAttribute("PotionLuckMult") else localPlayer:GetAttribute("PotionSellMult")
	if typeof(attr) == "number" then
		return attr
	end
	return 1
end

local function refreshPotionTimersFromAttributes()
	if not panel.Visible then
		return
	end
	for _, def in ipairs(PotionConfig.Potions) do
		local row = potionRows[def.Id]
		if row then
			row.BonusLabel.Text = potionRowBonus(
				def,
				liveChannelRemaining("luck"),
				liveChannelRemaining("sell"),
				liveChannelMult("luck"),
				liveChannelMult("sell")
			)
		end
	end
end

luckRow.BuyButton.MouseButton1Click:Connect(function()
	buyUpgradeRemote:FireServer("luck")
end)

speedRow.BuyButton.MouseButton1Click:Connect(function()
	buyUpgradeRemote:FireServer("speed")
end)

valueRow.BuyButton.MouseButton1Click:Connect(function()
	buyUpgradeRemote:FireServer("value")
end)

bagRow.BuyButton.MouseButton1Click:Connect(function()
	buyUpgradeRemote:FireServer("bag")
end)

local function promptUpgradeRobux(upgradeId: string, cost: number?)
	if cost == nil then
		return
	end
	local def = UpgradeConfig.GetRobuxSkip(upgradeId)
	if not def then
		return
	end
	RobuxPurchase.Prompt(def.ProductId, def.Name, def.RobuxPrice, function(message)
		statusLabel.Text = message
		UiToast.Show(message)
	end)
end

luckRow.RobuxButton.MouseButton1Click:Connect(function()
	promptUpgradeRobux("luck", if lastPayload then lastPayload.LuckCost else 0)
end)

speedRow.RobuxButton.MouseButton1Click:Connect(function()
	promptUpgradeRobux("speed", if lastPayload then lastPayload.SpeedCost else 0)
end)

valueRow.RobuxButton.MouseButton1Click:Connect(function()
	promptUpgradeRobux("value", if lastPayload then lastPayload.ValueCost else 0)
end)

bagRow.RobuxButton.MouseButton1Click:Connect(function()
	promptUpgradeRobux("bag", if lastPayload then lastPayload.BagCost else 0)
end)

local COUNT_ATTR = PotionConfig.CountAttributes

for _, def in ipairs(PotionConfig.Potions) do
	local row = potionRows[def.Id]
	if row then
		local potionId = def.Id
		local shopId = def.ShopId
		local isRobux = def.Currency == "Robux"
		row.BuyButton.MouseButton1Click:Connect(function()
			if isRobux then
				PotionPurchase.Prompt(potionId, function(message)
					statusLabel.Text = message
					UiToast.Show(message)
				end)
			else
				buyUpgradeRemote:FireServer(shopId)
			end
		end)
		row.UseButton.MouseButton1Click:Connect(function()
			local attrName = COUNT_ATTR[potionId]
			local owned = if attrName then localPlayer:GetAttribute(attrName) else 0
			if typeof(owned) == "number" and owned <= 0 then
				return
			end
			usePotionRemote:FireServer(potionId)
		end)
	end
end

openUpgradeRemote.OnClientEvent:Connect(function(payload)
	applyPayload(payload, true)
	UiTheme.BounceIn(panel, 0.75)
	UiTheme.QueueScrollCanvas(list)
end)

upgradeResultRemote.OnClientEvent:Connect(function(payload)
	applyPayload(payload, false)
	if typeof(payload) == "table" and typeof(payload.Message) == "string" and payload.Message ~= "" then
		statusLabel.Text = payload.Message
		UiToast.Show(payload.Message)
	end
end)

localPlayer:GetAttributeChangedSignal("PotionLuckRemaining"):Connect(function()
	local remaining = localPlayer:GetAttribute("PotionLuckRemaining")
	if typeof(remaining) == "number" then
		luckRemainValue = remaining
		luckRemainAt = os.clock()
	end
	refreshPotionTimersFromAttributes()
end)
localPlayer:GetAttributeChangedSignal("PotionSellRemaining"):Connect(function()
	local remaining = localPlayer:GetAttribute("PotionSellRemaining")
	if typeof(remaining) == "number" then
		sellRemainValue = remaining
		sellRemainAt = os.clock()
	end
	refreshPotionTimersFromAttributes()
end)

local function refreshOwnedFromAttribute(payloadKey: string, attrName: string)
	if not panel.Visible or typeof(lastPayload) ~= "table" then
		return
	end
	local count = localPlayer:GetAttribute(attrName)
	if typeof(count) == "number" then
		lastPayload[payloadKey] = count
		applyPayload(lastPayload, false)
	end
end

localPlayer:GetAttributeChangedSignal("PotionLuckCount"):Connect(function()
	refreshOwnedFromAttribute("PotionLuckCount", "PotionLuckCount")
end)
localPlayer:GetAttributeChangedSignal("PotionSellCount"):Connect(function()
	refreshOwnedFromAttribute("PotionSellCount", "PotionSellCount")
end)
localPlayer:GetAttributeChangedSignal("PotionSuperLuckCount"):Connect(function()
	refreshOwnedFromAttribute("PotionSuperLuckCount", "PotionSuperLuckCount")
end)
localPlayer:GetAttributeChangedSignal("PotionSuperSellCount"):Connect(function()
	refreshOwnedFromAttribute("PotionSuperSellCount", "PotionSuperSellCount")
end)
localPlayer:GetAttributeChangedSignal("PotionSuperBundleCount"):Connect(function()
	refreshOwnedFromAttribute("PotionSuperBundleCount", "PotionSuperBundleCount")
end)
localPlayer:GetAttributeChangedSignal("PotionLuckMult"):Connect(refreshPotionTimersFromAttributes)
localPlayer:GetAttributeChangedSignal("PotionSellMult"):Connect(refreshPotionTimersFromAttributes)

RunService.Heartbeat:Connect(function()
	refreshPotionTimersFromAttributes()
end)
