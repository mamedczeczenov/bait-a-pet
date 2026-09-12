--!strict

--[[
	Full-screen AFK lobby overlay. Only enabled on the AFK place.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local AfkConfig = require(Modules:WaitForChild("AfkConfig"))
local AfkPetConfig = require(Modules:WaitForChild("AfkPetConfig"))
local FeelSound = require(Modules:WaitForChild("FeelSound"))
local PlaceConfig = require(Modules:WaitForChild("PlaceConfig"))
local PotionConfig = require(Modules:WaitForChild("PotionConfig"))
local IconAssets = require(Modules:WaitForChild("IconAssets"))
local UiIcon = require(Modules:WaitForChild("UiIcon"))
local UiTheme = require(Modules:WaitForChild("UiTheme"))

if not PlaceConfig.IsAfkPlace() then
	return
end

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local afkTickRemote = remotes:WaitForChild("AfkTick") :: RemoteEvent
local requestTeleportRemote = remotes:WaitForChild("RequestTeleport") :: RemoteEvent

local ACCENT = Color3.fromRGB(80, 210, 255)
local ACCENT_HOT = Color3.fromRGB(40, 150, 230)
local NAVY = Color3.fromRGB(16, 24, 42)
local PANEL = Color3.fromRGB(28, 40, 62)
local ROW = Color3.fromRGB(16, 24, 40)

local coins = 0
local sessionCoins = 0
local nextRollAt = Workspace:GetServerTimeNow() + AfkConfig.ThrowInterval
local interval = AfkConfig.ThrowInterval
local afkLuck = 1
local potionLuckChance = AfkConfig.PotionLuckChance
local potionSellChance = AfkConfig.PotionSellChance
local musicOn = true
local receivedLines: { string } = {}
local MAX_LOG = 24

local function formatInt(n: number): string
	local s = tostring(math.floor(math.abs(n)))
	local k
	repeat
		s, k = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	if n < 0 then
		return "-" .. s
	end
	return s
end

local function findAfkMusic(): Sound?
	local named = SoundService:FindFirstChild("AfkMusic")
	if named and named:IsA("Sound") then
		return named
	end
	local world = Workspace:FindFirstChild("AfkMusic")
	if world and world:IsA("Sound") then
		return world
	end
	return nil
end

local screenGui = UiTheme.Create("ScreenGui", {
	Name = "AfkLobbyGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 70,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui) :: ScreenGui
UiTheme.MobileScale(screenGui)

local root = UiTheme.Create("Frame", {
	Name = "Root",
	BackgroundColor3 = NAVY,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Active = true,
	ClipsDescendants = true,
	ZIndex = 1,
}, screenGui) :: Frame
UiTheme.Gradient(root, Color3.fromRGB(48, 92, 138), Color3.fromRGB(22, 44, 78), 90)

local wallpaper = UiTheme.Create("Frame", {
	Name = "Wallpaper",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1.35, 1.35),
	ZIndex = 1,
}, root) :: Frame

do
	local patternKeys = {
		"bait_basic",
		"hud_coins",
		"hud_pets",
		"bait_gold",
		"action_throw",
		"vip_crown",
		"bait_diamond",
		"hud_rewards",
		"station_upgrade_luck",
		"bait_nebula",
	}
	local cols = 8
	local rows = 6
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			local key = patternKeys[((row * cols + col) % #patternKeys) + 1]
			local x = (col + 0.5) / cols
			local y = (row + 0.5) / rows
			if row % 2 == 1 then
				x += 0.5 / cols
			end

			local tile = UiTheme.Create("ImageLabel", {
				Name = "Tile",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(x, y),
				Size = UDim2.fromOffset(78, 78),
				Image = IconAssets.GetImage(key) or "",
				ImageTransparency = 0.78,
				ImageColor3 = Color3.fromRGB(180, 230, 255),
				ScaleType = Enum.ScaleType.Fit,
				Rotation = if (row + col) % 2 == 0 then -14 else 12,
				ZIndex = 1,
			}, wallpaper) :: ImageLabel

			if tile.Image == "" then
				tile:Destroy()
				local emoji = UiTheme.Create("TextLabel", {
					Name = "Tile",
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(x, y),
					Size = UDim2.fromOffset(78, 78),
					Font = UiTheme.FontTitle,
					Text = IconAssets.GetEmoji(key),
					TextSize = 42,
					TextColor3 = ACCENT,
					TextTransparency = 0.82,
					Rotation = if (row + col) % 2 == 0 then -14 else 12,
					ZIndex = 1,
				}, wallpaper) :: TextLabel
				emoji.TextStrokeTransparency = 1
			end
		end
	end
end

local centerGlow = UiTheme.Create("Frame", {
	Name = "CenterGlow",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = ACCENT,
	BackgroundTransparency = 0.84,
	BorderSizePixel = 0,
	Position = UDim2.new(0.5, 0, 0.48, 0),
	Size = UDim2.fromOffset(560, 560),
	ZIndex = 1,
}, root) :: Frame
UiTheme.Corner(centerGlow, UDim.new(1, 0))

local timerWrap = UiTheme.Create("Frame", {
	Name = "Timer",
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundTransparency = 1,
	Position = UDim2.new(0.5, 0, 0, 18),
	Size = UDim2.new(0.72, 0, 0, 58),
	ZIndex = 2,
}, root) :: Frame

local barBg = UiTheme.Create("Frame", {
	Name = "BarBg",
	BackgroundColor3 = Color3.fromRGB(18, 32, 52),
	BorderSizePixel = 0,
	Size = UDim2.new(1, 0, 0, 18),
	ZIndex = 3,
}, timerWrap) :: Frame
UiTheme.Corner(barBg, UDim.new(1, 0))
UiTheme.Stroke(barBg, ACCENT, 2, 0)

local barFill = UiTheme.Create("Frame", {
	Name = "Fill",
	BackgroundColor3 = ACCENT,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 4,
}, barBg) :: Frame
UiTheme.Corner(barFill, UDim.new(1, 0))
UiTheme.Gradient(barFill, Color3.fromRGB(140, 235, 255), ACCENT_HOT, 0)

local countdownLabel = UiTheme.Create("TextLabel", {
	Name = "Countdown",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 24),
	Size = UDim2.new(1, 0, 0, 32),
	Font = UiTheme.FontTitle,
	Text = AfkConfig.FormatCountdown(interval),
	TextColor3 = UiTheme.Colors.Text,
	TextSize = 22,
	ZIndex = 3,
}, timerWrap) :: TextLabel
UiTheme.TextStroke(countdownLabel, 2.4)

local coinsBox = UiTheme.Create("Frame", {
	Name = "Coins",
	BackgroundColor3 = PANEL,
	BorderSizePixel = 0,
	Position = UDim2.new(0, 24, 0, 92),
	Size = UDim2.fromOffset(220, 64),
	ZIndex = 3,
}, root) :: Frame
UiTheme.Corner(coinsBox, UiTheme.CornerPanel)
UiTheme.Stroke(coinsBox, ACCENT, 3, 0)

UiIcon.Mount(coinsBox, {
	Key = "hud_coins",
	Name = "Icon",
	Position = UDim2.fromOffset(8, 8),
	Size = UDim2.fromOffset(48, 48),
	ImageSize = 34,
	ZIndex = 5,
})

local coinsLabel = UiTheme.Create("TextLabel", {
	Name = "Value",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(58, 0),
	Size = UDim2.new(1, -66, 1, 0),
	Font = UiTheme.FontTitle,
	Text = "0",
	TextColor3 = UiTheme.Colors.Text,
	TextSize = 26,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 4,
}, coinsBox) :: TextLabel
UiTheme.TextStroke(coinsLabel, 2.2)

local sessionBox = UiTheme.Create("Frame", {
	Name = "Session",
	BackgroundColor3 = PANEL,
	BorderSizePixel = 0,
	Position = UDim2.new(0, 24, 0, 168),
	Size = UDim2.fromOffset(220, 54),
	ZIndex = 3,
}, root) :: Frame
UiTheme.Corner(sessionBox, UiTheme.CornerSmall)
UiTheme.Stroke(sessionBox, UiTheme.Colors.Stroke, 3, 0)

UiIcon.Mount(sessionBox, {
	Key = "currency_coin_sm",
	Name = "Icon",
	Position = UDim2.fromOffset(8, 11),
	Size = UDim2.fromOffset(32, 32),
	ImageSize = 22,
	ZIndex = 5,
})

local sessionLabel = UiTheme.Create("TextLabel", {
	Name = "Value",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(42, 0),
	Size = UDim2.new(1, -50, 1, 0),
	Font = UiTheme.FontTitle,
	Text = "EARNED  0",
	TextColor3 = UiTheme.Colors.Text,
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 4,
}, sessionBox) :: TextLabel
UiTheme.TextStroke(sessionLabel, 2)

local received = UiTheme.Create("Frame", {
	Name = "Received",
	BackgroundColor3 = ROW,
	BorderSizePixel = 0,
	Position = UDim2.new(0, 24, 0, 236),
	Size = UDim2.new(0, 260, 1, -330),
	ZIndex = 3,
}, root) :: Frame
UiTheme.Corner(received, UiTheme.CornerPanel)
UiTheme.Stroke(received, ACCENT, 3, 0)

UiTheme.Create("TextLabel", {
	Name = "Title",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(12, 8),
	Size = UDim2.new(1, -24, 0, 24),
	Font = UiTheme.FontTitle,
	Text = "RECEIVED",
	TextColor3 = ACCENT,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 4,
}, received)

local receivedList = UiTheme.Create("ScrollingFrame", {
	Name = "List",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(10, 36),
	Size = UDim2.new(1, -20, 1, -46),
	CanvasSize = UDim2.fromOffset(0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 8,
	ScrollBarImageColor3 = ACCENT,
	ZIndex = 4,
}, received) :: ScrollingFrame

UiTheme.Create("UIListLayout", {
	Padding = UDim.new(0, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, receivedList)

local logo = UiTheme.Create("Frame", {
	Name = "Logo",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(28, 52, 86),
	BorderSizePixel = 0,
	Position = UDim2.new(0.5, 0, 0.48, 0),
	Size = UDim2.fromOffset(340, 340),
	ZIndex = 2,
}, root) :: Frame
UiTheme.Corner(logo, UDim.new(0, 28))
UiTheme.Stroke(logo, ACCENT, 4, 0)
UiTheme.Gradient(logo, Color3.fromRGB(54, 98, 148), Color3.fromRGB(24, 46, 82), 90)

local logoImage = UiTheme.Create("ImageLabel", {
	Name = "Art",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Image = AfkConfig.LogoImage,
	ScaleType = Enum.ScaleType.Crop,
	Visible = AfkConfig.LogoImage ~= "",
	ZIndex = 3,
}, logo) :: ImageLabel
UiTheme.Corner(logoImage, UDim.new(0, 28))

local logoTitle = UiTheme.Create("TextLabel", {
	Name = "Title",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.46, 0),
	Size = UDim2.new(1, -24, 0, 64),
	Font = UiTheme.FontTitle,
	Text = "BAIT A PET!",
	TextColor3 = ACCENT,
	TextSize = 42,
	Visible = AfkConfig.LogoImage == "",
	ZIndex = 4,
}, logo) :: TextLabel
UiTheme.TextStroke(logoTitle, 3)

UiTheme.Create("TextLabel", {
	Name = "Subtitle",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.62, 0),
	Size = UDim2.new(1, -24, 0, 36),
	Font = UiTheme.FontTitle,
	Text = "AFK LOBBY",
	TextColor3 = UiTheme.Colors.Text,
	TextSize = 26,
	ZIndex = 4,
}, logo)

local chances = UiTheme.Create("Frame", {
	Name = "Chances",
	AnchorPoint = Vector2.new(1, 0),
	BackgroundColor3 = PANEL,
	BorderSizePixel = 0,
	Position = UDim2.new(1, -24, 0, 92),
	Size = UDim2.new(0, 300, 1, -200),
	ZIndex = 3,
}, root) :: Frame
UiTheme.Corner(chances, UiTheme.CornerPanel)
UiTheme.Stroke(chances, ACCENT, 3, 0)

UiTheme.Create("TextLabel", {
	Name = "Title",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, 10),
	Size = UDim2.new(1, -28, 0, 26),
	Font = UiTheme.FontTitle,
	Text = "CHANCES",
	TextColor3 = ACCENT,
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 4,
}, chances)

local chancesList = UiTheme.Create("ScrollingFrame", {
	Name = "List",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(12, 42),
	Size = UDim2.new(1, -24, 1, -54),
	CanvasSize = UDim2.fromOffset(0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 8,
	ScrollBarImageColor3 = ACCENT,
	ZIndex = 4,
}, chances) :: ScrollingFrame

UiTheme.Create("UIListLayout", {
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, chancesList)

type ChanceRow = {
	Chance: TextLabel,
	Title: TextLabel,
}

local chanceRows: { [string]: ChanceRow } = {}

local function makeChanceRow(id: string, order: number, iconKey: string, title: string): ChanceRow
	local row = UiTheme.Create("Frame", {
		Name = id,
		BackgroundColor3 = ROW,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -6, 0, 44),
		LayoutOrder = order,
		ZIndex = 5,
	}, chancesList) :: Frame
	UiTheme.Corner(row, UiTheme.CornerChip)

	UiIcon.Mount(row, {
		Key = iconKey,
		Name = "Icon",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(32, 32),
		ImageSize = 24,
		ZIndex = 6,
	})

	local chanceLabel = UiTheme.Create("TextLabel", {
		Name = "Chance",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(42, 2),
		Size = UDim2.new(1, -50, 0, 18),
		Font = UiTheme.FontTitle,
		Text = "",
		TextColor3 = ACCENT,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
	}, row) :: TextLabel
	UiTheme.TextStroke(chanceLabel, 1.6)

	local titleLabel = UiTheme.Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(42, 20),
		Size = UDim2.new(1, -50, 0, 20),
		Font = UiTheme.FontBody,
		Text = title,
		TextColor3 = UiTheme.Colors.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 6,
	}, row) :: TextLabel

	local created = {
		Chance = chanceLabel,
		Title = titleLabel,
	}
	chanceRows[id] = created
	return created
end

local luckPotion = PotionConfig.Get("luck")
local sellPotion = PotionConfig.Get("sell")

makeChanceRow("coins", 1, "hud_coins", "Coins (virtual cave sell)")
makeChanceRow(
	"luck",
	2,
	if luckPotion then luckPotion.IconKey else "station_upgrade_luck",
	"Luck Potion"
)
makeChanceRow(
	"sell",
	3,
	if sellPotion then sellPotion.IconKey else "station_upgrade_value",
	"Sell Potion"
)

local petRowOrder = 4
for _, def in ipairs(AfkPetConfig.Pets) do
	makeChanceRow(def.Id, petRowOrder, def.IconKey, string.format("%s  ·  %s", def.Name, def.Rarity))
	petRowOrder += 1
end

local leaveButton = UiTheme.Button({
	Name = "Return",
	Parent = root,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -22),
	Size = UDim2.fromOffset(280, 52),
	Text = "Return To Lobby",
	TextSize = 20,
	Variant = "danger",
	ZIndex = 6,
})

local musicButton = UiTheme.Button({
	Name = "Music",
	Parent = root,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -24, 1, -22),
	Size = UDim2.fromOffset(168, 40),
	Text = "Music: ON",
	TextSize = 14,
	Variant = "muted",
	ZIndex = 6,
})

local confirmOverlay = UiTheme.Create("Frame", {
	Name = "Confirm",
	BackgroundColor3 = Color3.fromRGB(10, 12, 18),
	BackgroundTransparency = 0.35,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 20,
}, root) :: Frame

local confirmDialog = UiTheme.Create("Frame", {
	Name = "Dialog",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = UiTheme.Colors.BgRaised,
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(400, 200),
	ZIndex = 21,
}, confirmOverlay) :: Frame
UiTheme.Corner(confirmDialog, UiTheme.CornerPanel)
UiTheme.Stroke(confirmDialog, UiTheme.Colors.Stroke, 4, 0)

UiTheme.Create("TextLabel", {
	Name = "Title",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 16),
	Size = UDim2.fromOffset(360, 28),
	Font = UiTheme.FontTitle,
	Text = AfkConfig.LeaveTitle,
	TextColor3 = UiTheme.Colors.TextDark,
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 22,
}, confirmDialog)

UiTheme.Create("TextLabel", {
	Name = "Body",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 52),
	Size = UDim2.fromOffset(360, 70),
	Font = UiTheme.FontBody,
	Text = AfkConfig.LeaveBody,
	TextColor3 = UiTheme.Colors.TextDim,
	TextSize = 16,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 22,
}, confirmDialog)

local confirmYes = UiTheme.Button({
	Name = "Yes",
	Parent = confirmDialog,
	Position = UDim2.fromOffset(20, 136),
	Size = UDim2.fromOffset(170, 42),
	Text = AfkConfig.LeaveConfirm,
	TextSize = 15,
	Variant = "danger",
	ZIndex = 22,
})

local confirmCancel = UiTheme.Button({
	Name = "Cancel",
	Parent = confirmDialog,
	Position = UDim2.fromOffset(210, 136),
	Size = UDim2.fromOffset(170, 42),
	Text = "Cancel",
	TextSize = 16,
	Variant = "muted",
	ZIndex = 22,
})

local function refreshChances()
	local coinsRow = chanceRows.coins
	if coinsRow then
		coinsRow.Chance.Text = "EVERY ROLL"
	end
	local luckRow = chanceRows.luck
	if luckRow then
		luckRow.Chance.Text = AfkConfig.FormatChance(potionLuckChance)
	end
	local sellRow = chanceRows.sell
	if sellRow then
		sellRow.Chance.Text = AfkConfig.FormatChance(potionSellChance)
	end
	for _, def in ipairs(AfkPetConfig.Pets) do
		local row = chanceRows[def.Id]
		if row then
			row.Chance.Text = AfkConfig.FormatChance(AfkConfig.GetWeightedPetChance(afkLuck, def.Id))
		end
	end
end

local function refreshTotals()
	coinsLabel.Text = formatInt(coins)
	sessionLabel.Text = "EARNED  " .. formatInt(sessionCoins)
end

local function pushReceived(text: string)
	table.insert(receivedLines, 1, text)
	while #receivedLines > MAX_LOG do
		table.remove(receivedLines)
	end
	for _, child in ipairs(receivedList:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for index, line in ipairs(receivedLines) do
		local row = UiTheme.Create("TextLabel", {
			Name = "Line",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -4, 0, 22),
			Font = UiTheme.FontBody,
			LayoutOrder = index,
			Text = line,
			TextColor3 = UiTheme.Colors.Text,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 5,
		}, receivedList) :: TextLabel
		row.TextTruncate = Enum.TextTruncate.AtEnd
	end
end

local function applyMusic()
	musicButton.Text = if musicOn then "Music: ON" else "Music: OFF"
	local sound = findAfkMusic()
	if sound then
		sound.Looped = true
		if musicOn then
			if not sound.IsPlaying then
				sound:Play()
			end
		else
			sound:Stop()
		end
	end
end

local function applyPayload(payload: { [string]: any })
	if typeof(payload.Coins) == "number" then
		coins = payload.Coins
	end
	if typeof(payload.SessionCoins) == "number" then
		sessionCoins = payload.SessionCoins
	end
	if typeof(payload.Interval) == "number" then
		interval = payload.Interval
	end
	if typeof(payload.NextRollAt) == "number" then
		nextRollAt = payload.NextRollAt
	end
	if payload.Kind == "Tick" and (nextRollAt - Workspace:GetServerTimeNow()) <= 0.05 then
		nextRollAt = Workspace:GetServerTimeNow() + interval
	end
	if typeof(payload.AfkLuck) == "number" then
		afkLuck = payload.AfkLuck
	end
	if typeof(payload.PotionLuckChance) == "number" then
		potionLuckChance = payload.PotionLuckChance
	end
	if typeof(payload.PotionSellChance) == "number" then
		potionSellChance = payload.PotionSellChance
	end
	refreshTotals()
	refreshChances()

	local drops = payload.Drops
	if typeof(drops) == "table" then
		for _, drop in ipairs(drops) do
			if typeof(drop) == "table" and typeof(drop.Text) == "string" then
				pushReceived(drop.Text)
				if drop.Type == "Coins" then
					FeelSound.Play("Sell", 0.45)
				elseif drop.Type == "Potion" or drop.Type == "Pet" then
					FeelSound.Play("Buy", 0.5)
				end
			end
		end
	end
end

afkTickRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	applyPayload(payload)
end)

leaveButton.MouseButton1Click:Connect(function()
	confirmOverlay.Visible = true
end)

confirmCancel.MouseButton1Click:Connect(function()
	confirmOverlay.Visible = false
end)

confirmYes.MouseButton1Click:Connect(function()
	confirmOverlay.Visible = false
	requestTeleportRemote:FireServer("map1")
end)

musicButton.MouseButton1Click:Connect(function()
	musicOn = not musicOn
	applyMusic()
end)

RunService.Heartbeat:Connect(function()
	local t = os.clock()
	wallpaper.Position = UDim2.new(
		0.5 + math.sin(t * 0.07) * 0.025,
		0,
		0.5 + math.cos(t * 0.055) * 0.025,
		0
	)
	wallpaper.Rotation = math.sin(t * 0.03) * 1.6
	centerGlow.BackgroundTransparency = 0.82 + math.sin(t * 1.15) * 0.04
	centerGlow.Size = UDim2.fromOffset(540 + math.sin(t * 0.9) * 24, 540 + math.sin(t * 0.9) * 24)

	local remaining = nextRollAt - Workspace:GetServerTimeNow()
	if remaining <= 0 then
		countdownLabel.Text = "ROLLING..."
		barFill.Size = UDim2.fromScale(0, 1)
		return
	end
	countdownLabel.Text = AfkConfig.FormatCountdown(remaining)
	local alpha = math.clamp(remaining / math.max(0.001, interval), 0, 1)
	barFill.Size = UDim2.fromScale(alpha, 1)
end)

coins = if typeof(localPlayer:GetAttribute("Coins")) == "number" then localPlayer:GetAttribute("Coins") :: number else 0
refreshTotals()
refreshChances()
applyMusic()
pushReceived("AFK started — first roll in 30s.")
