--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PotionConfig = require(Modules:WaitForChild("PotionConfig"))
local PlaceConfig = require(Modules:WaitForChild("PlaceConfig"))
local UiIcon = require(Modules:WaitForChild("UiIcon"))
local UiTheme = require(Modules:WaitForChild("UiTheme"))

local screenGui = UiTheme.Create("ScreenGui", {
	Name = "PotionHud",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 24,
}, playerGui) :: ScreenGui
UiTheme.MobileScale(screenGui)
if PlaceConfig.IsAfkPlace() then
	screenGui.Enabled = false
end

local stack = UiTheme.Create("Frame", {
	Name = "Stack",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -18, 0.5, 0),
	Size = UDim2.fromOffset(188, 92),
	BackgroundTransparency = 1,
	Active = false,
	ZIndex = 2,
}, screenGui) :: Frame

local function createChip(name: string, y: number, variant: UiTheme.ButtonVariant, iconKey: string, title: string): (Frame, TextLabel, TextLabel)
	local chip = UiTheme.Create("Frame", {
		Name = name,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.fromOffset(188, 40),
		BackgroundColor3 = UiTheme.ButtonColor(variant),
		Visible = false,
		ZIndex = 3,
		BorderSizePixel = 0,
	}, stack) :: Frame
	UiTheme.Corner(chip, UiTheme.CornerChip)
	UiTheme.Stroke(chip, UiTheme.Colors.Stroke, 3, 0)

	UiIcon.Mount(chip, {
		Key = iconKey,
		Name = "Icon",
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(32, 32),
		ImageSize = 24,
	})

	local titleLabel = UiTheme.Label({
		Name = "Title",
		Text = title,
		Parent = chip,
		Position = UDim2.fromOffset(38, 2),
		Size = UDim2.fromOffset(142, 16),
		TextSize = 12,
		Color = UiTheme.Colors.Text,
		Font = UiTheme.FontTitle,
		Outlined = true,
	})

	local timerLabel = UiTheme.Label({
		Name = "Timer",
		Text = "0:00",
		Parent = chip,
		Position = UDim2.fromOffset(38, 18),
		Size = UDim2.fromOffset(142, 18),
		TextSize = 16,
		Color = UiTheme.Colors.Text,
		Font = UiTheme.FontTitle,
		Outlined = true,
	})

	return chip, timerLabel, titleLabel
end

local luckChip, luckTimer, luckTitle = createChip("Luck", 0, "blue", "station_upgrade_luck", "Luck ×2")
local sellChip, sellTimer, sellTitle = createChip("Sell", 48, "green", "station_upgrade_value", "Sell ×2")

type Track = {
	Value: number,
	At: number,
}

local luckTrack: Track = { Value = 0, At = os.clock() }
local sellTrack: Track = { Value = 0, At = os.clock() }

local function readRemaining(attrName: string): number
	local value = localPlayer:GetAttribute(attrName)
	if typeof(value) == "number" then
		return math.max(0, value)
	end
	return 0
end

local function capture(track: Track, remaining: number)
	track.Value = remaining
	track.At = os.clock()
end

local function currentRemaining(track: Track): number
	return math.max(0, track.Value - (os.clock() - track.At))
end

local function layoutChips()
	local y = 0
	if luckChip.Visible then
		luckChip.Position = UDim2.fromOffset(0, y)
		y += 48
	end
	if sellChip.Visible then
		sellChip.Position = UDim2.fromOffset(0, y)
	end
end

local function readMult(attrName: string): number
	local value = localPlayer:GetAttribute(attrName)
	if typeof(value) == "number" and value > 0 then
		return value
	end
	return 1
end

local function refresh()
	local luckLeft = currentRemaining(luckTrack)
	local sellLeft = currentRemaining(sellTrack)
	local luckMult = readMult("PotionLuckMult")
	local sellMult = readMult("PotionSellMult")

	luckChip.Visible = luckLeft > 0.05
	sellChip.Visible = sellLeft > 0.05
	if luckChip.Visible then
		luckTitle.Text = string.format("Luck ×%.0f", luckMult)
		luckTimer.Text = PotionConfig.FormatTime(luckLeft)
	end
	if sellChip.Visible then
		sellTitle.Text = string.format("Sell ×%.0f", sellMult)
		sellTimer.Text = PotionConfig.FormatTime(sellLeft)
	end
	layoutChips()
end

capture(luckTrack, readRemaining("PotionLuckRemaining"))
capture(sellTrack, readRemaining("PotionSellRemaining"))
refresh()

localPlayer:GetAttributeChangedSignal("PotionLuckRemaining"):Connect(function()
	capture(luckTrack, readRemaining("PotionLuckRemaining"))
	refresh()
end)
localPlayer:GetAttributeChangedSignal("PotionSellRemaining"):Connect(function()
	capture(sellTrack, readRemaining("PotionSellRemaining"))
	refresh()
end)
localPlayer:GetAttributeChangedSignal("PotionLuckMult"):Connect(refresh)
localPlayer:GetAttributeChangedSignal("PotionSellMult"):Connect(refresh)

RunService.Heartbeat:Connect(refresh)
