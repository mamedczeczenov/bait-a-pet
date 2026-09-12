--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CatchFeelConfig = require(Modules:WaitForChild("CatchFeelConfig"))
local PlaceConfig = require(Modules:WaitForChild("PlaceConfig"))
local UiIcon = require(Modules:WaitForChild("UiIcon"))
local UiTheme = require(Modules:WaitForChild("UiTheme"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local updateSettingsRemote = remotes:WaitForChild("UpdateSettings") :: RemoteEvent

local screenGui = UiTheme.Create("ScreenGui", {
	Name = "SettingsGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 22,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui) :: ScreenGui
UiTheme.MobileScale(screenGui)
if PlaceConfig.IsAfkPlace() then
	screenGui.Enabled = false
end

local openButton = UiTheme.Button({
	Name = "OpenSettings",
	Parent = screenGui,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -18, 0, 66),
	Size = UDim2.fromOffset(150, 36),
	Text = "Settings",
	TextSize = 14,
	Variant = "muted",
	ZIndex = 8,
}) :: TextButton
openButton.TextXAlignment = Enum.TextXAlignment.Right
UiIcon.ApplyToButton(openButton, "hud_settings", 20)

local panel = UiTheme.Panel({
	Name = "Panel",
	Parent = screenGui,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -18, 0, 110),
	Size = UDim2.fromOffset(280, 250),
	Visible = false,
	ZIndex = 20,
})

UiTheme.Label({
	Name = "Title",
	Parent = panel,
	Position = UDim2.fromOffset(14, 12),
	Size = UDim2.fromOffset(200, 24),
	Text = "Celebrations",
	TextSize = 20,
	Font = UiTheme.FontTitle,
	Color = UiTheme.Colors.Text,
	Outlined = true,
	ZIndex = 21,
})

local closeButton = UiTheme.Button({
	Name = "Close",
	Parent = panel,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromOffset(266, 10),
	Size = UDim2.fromOffset(32, 32),
	Text = "X",
	TextSize = 16,
	Variant = "danger",
	ZIndex = 22,
}) :: TextButton

UiTheme.Create("TextLabel", {
	Name = "Hint",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, 42),
	Size = UDim2.fromOffset(252, 36),
	Text = "Minimum rarity for shake and stronger catch effects.",
	TextColor3 = UiTheme.Colors.TextDim,
	TextSize = 13,
	Font = UiTheme.FontBody,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 21,
}, panel)

local list = UiTheme.Create("Frame", {
	Name = "Options",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, 86),
	Size = UDim2.fromOffset(252, 150),
	ZIndex = 21,
}, panel) :: Frame

UiTheme.Create("UIListLayout", {
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, list)

local optionButtons: { [string]: TextButton } = {}

local LABELS: { [string]: string } = {
	Off = "Off",
	Rare = "Rare+",
	Epic = "Epic+",
	Legendary = "Legendary+",
	Mythic = "Mythic+",
}

local function optionLabel(option: string): string
	return LABELS[option] or option
end

local function getCurrentMin(): string
	return CatchFeelConfig.NormalizeMinRarity(localPlayer:GetAttribute("CelebrationMinRarity"))
end

local function refreshSelection()
	local current = getCurrentMin()
	for name, button in pairs(optionButtons) do
		local selected = name == current
		button.BackgroundColor3 = if selected then UiTheme.Colors.AccentCyan else UiTheme.Colors.BgRow
		button.TextColor3 = if selected then UiTheme.Colors.Text else UiTheme.Colors.TextDark
		button.Text = if selected then string.format("• %s", optionLabel(name)) else optionLabel(name)
		if selected then
			UiTheme.TextStroke(button, 2)
		else
			local stroke = button:FindFirstChild("CandyTextStroke")
			if stroke then
				stroke:Destroy()
			end
		end
	end
end

for order, option in ipairs(CatchFeelConfig.MinRarityOptions) do
	local button = UiTheme.Create("TextButton", {
		Name = option,
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = UiTheme.Colors.BgRow,
		Text = optionLabel(option),
		TextColor3 = UiTheme.Colors.TextDark,
		TextSize = 14,
		Font = UiTheme.FontMedium,
		AutoButtonColor = true,
		LayoutOrder = order,
		ZIndex = 22,
	}, list) :: TextButton

	UiTheme.Corner(button, UiTheme.CornerSmall)
	UiTheme.Stroke(button, UiTheme.Colors.Stroke, 2.5, 0)
	UiTheme.WireButtonMotion(button)
	optionButtons[option] = button

	button.MouseButton1Click:Connect(function()
		updateSettingsRemote:FireServer({
			Type = "CelebrationMinRarity",
			Value = option,
		})
		localPlayer:SetAttribute("CelebrationMinRarity", option)
		refreshSelection()
	end)
end

openButton.MouseButton1Click:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then
		refreshSelection()
	end
end)

closeButton.MouseButton1Click:Connect(function()
	panel.Visible = false
end)

localPlayer:GetAttributeChangedSignal("CelebrationMinRarity"):Connect(refreshSelection)
refreshSelection()
