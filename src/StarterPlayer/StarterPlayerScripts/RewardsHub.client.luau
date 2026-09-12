--!strict

--[[
	Shared Rewards HUD: one open button + tabbed Daily / Ads / Goals panel.
	DailyClient, AdRewardClient, and GoalClient mount their pages into this shell.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UiIcon = require(Modules:WaitForChild("UiIcon"))
local UiTheme = require(Modules:WaitForChild("UiTheme"))
local PlaceConfig = require(Modules:WaitForChild("PlaceConfig"))

local screenGui = UiTheme.Create("ScreenGui", {
	Name = "RewardsGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 21,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui) :: ScreenGui
UiTheme.MobileScale(screenGui)
if PlaceConfig.IsAfkPlace() then
	screenGui.Enabled = false
end

local openButton = UiTheme.Button({
	Name = "OpenRewards",
	Parent = screenGui,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -18, 0, 108),
	Size = UDim2.fromOffset(150, 40),
	Text = "Rewards",
	TextSize = 15,
	Variant = "vip",
	ZIndex = 8,
}) :: TextButton
openButton:SetAttribute("TutorialTarget", "rewards")
openButton.TextXAlignment = Enum.TextXAlignment.Right
UiIcon.ApplyToButton(openButton, "hud_rewards", 22)

local claimDot = UiTheme.Create("Frame", {
	Name = "ClaimDot",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -4, 0, 4),
	Size = UDim2.fromOffset(12, 12),
	BackgroundColor3 = UiTheme.Colors.Success,
	Visible = false,
	ZIndex = 9,
}, openButton) :: Frame
UiTheme.Corner(claimDot, UDim.new(1, 0))
UiTheme.Stroke(claimDot, UiTheme.Colors.Stroke, 2, 0)
UiTheme.Pulse(claimDot, 1.25, 0.7)

local panel = UiTheme.Panel({
	Name = "Panel",
	Parent = screenGui,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -18, 0, 156),
	Size = UDim2.fromOffset(340, 500),
	Visible = false,
	ZIndex = 20,
})

UiTheme.Label({
	Name = "Title",
	Parent = panel,
	Position = UDim2.fromOffset(14, 12),
	Size = UDim2.fromOffset(220, 32),
	Text = "Rewards",
	TextSize = 24,
	Font = UiTheme.FontTitle,
	Color = UiTheme.Colors.Text,
	Outlined = true,
	ZIndex = 21,
})

local closeButton = UiTheme.Button({
	Name = "Close",
	Parent = panel,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 10),
	Size = UDim2.fromOffset(36, 36),
	Text = "X",
	TextSize = 18,
	Variant = "danger",
	ZIndex = 22,
}) :: TextButton

local tabBar = UiTheme.Create("Frame", {
	Name = "TabBar",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(12, 56),
	Size = UDim2.fromOffset(316, 40),
	ZIndex = 21,
}, panel) :: Frame

local tabDaily = UiTheme.Button({
	Name = "TabDaily",
	Parent = tabBar,
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.fromOffset(100, 36),
	Text = "Daily",
	TextSize = 14,
	Variant = "vip",
	ZIndex = 22,
}) :: TextButton

local tabAds = UiTheme.Button({
	Name = "TabAds",
	Parent = tabBar,
	Position = UDim2.fromOffset(108, 0),
	Size = UDim2.fromOffset(100, 36),
	Text = "Ads",
	TextSize = 14,
	Variant = "muted",
	ZIndex = 22,
}) :: TextButton

local tabGoals = UiTheme.Button({
	Name = "TabGoals",
	Parent = tabBar,
	Position = UDim2.fromOffset(216, 0),
	Size = UDim2.fromOffset(100, 36),
	Text = "Goals",
	TextSize = 14,
	Variant = "muted",
	ZIndex = 22,
}) :: TextButton

local dailyPage = UiTheme.Create("Frame", {
	Name = "DailyPage",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 102),
	Size = UDim2.new(1, 0, 1, -110),
	Visible = true,
	ZIndex = 21,
}, panel) :: Frame

local adsPage = UiTheme.Create("Frame", {
	Name = "AdsPage",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 102),
	Size = UDim2.new(1, 0, 1, -110),
	Visible = false,
	ZIndex = 21,
}, panel) :: Frame

local goalsPage = UiTheme.Create("Frame", {
	Name = "GoalsPage",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 102),
	Size = UDim2.new(1, 0, 1, -110),
	Visible = false,
	ZIndex = 21,
}, panel) :: Frame

local activeTab = "Daily"

local function refreshClaimDot()
	local dailyReady = screenGui:GetAttribute("DailyClaimReady") == true
	local goalsReady = screenGui:GetAttribute("GoalsClaimReady") == true
	claimDot.Visible = dailyReady or goalsReady
	if goalsReady and not dailyReady then
		claimDot.BackgroundColor3 = UiTheme.Colors.AccentAmber
	else
		claimDot.BackgroundColor3 = UiTheme.Colors.Success
	end
end

screenGui:GetAttributeChangedSignal("DailyClaimReady"):Connect(refreshClaimDot)
screenGui:GetAttributeChangedSignal("GoalsClaimReady"):Connect(refreshClaimDot)

local function paintTab(button: TextButton, selected: boolean, selectedVariant: "vip" | "cyan" | "green")
	if selected then
		button.BackgroundColor3 = UiTheme.ButtonColor(selectedVariant)
		if selectedVariant == "vip" then
			UiTheme.Gradient(button, Color3.fromRGB(255, 240, 120), UiTheme.Colors.AccentVip, 90)
		elseif selectedVariant == "cyan" then
			UiTheme.Gradient(button, Color3.fromRGB(140, 230, 255), UiTheme.Colors.AccentCyanDim, 90)
		else
			UiTheme.Gradient(button, Color3.fromRGB(140, 255, 150), UiTheme.Colors.AccentGreenHot, 90)
		end
	else
		button.BackgroundColor3 = UiTheme.Colors.BgMuted
		UiTheme.Gradient(button, Color3.fromRGB(220, 230, 240), UiTheme.Colors.BgMuted, 90)
	end
end

local function setTab(tab: string)
	activeTab = tab
	dailyPage.Visible = tab == "Daily"
	adsPage.Visible = tab == "Ads"
	goalsPage.Visible = tab == "Goals"

	paintTab(tabDaily, tab == "Daily", "vip")
	paintTab(tabAds, tab == "Ads", "cyan")
	paintTab(tabGoals, tab == "Goals", "green")

	screenGui:SetAttribute("ActiveTab", tab)
end

local function setOpen(open: boolean, preferTab: string?)
	panel.Visible = open
	if open then
		if typeof(preferTab) == "string" and preferTab ~= "" then
			setTab(preferTab)
		end
		UiTheme.BounceIn(panel, 0.7)
		screenGui:SetAttribute("OpenRequest", os.clock())
	end
end

tabDaily.MouseButton1Click:Connect(function()
	setTab("Daily")
end)

tabAds.MouseButton1Click:Connect(function()
	setTab("Ads")
end)

tabGoals.MouseButton1Click:Connect(function()
	setTab("Goals")
end)

openButton.MouseButton1Click:Connect(function()
	setOpen(not panel.Visible)
end)

closeButton.MouseButton1Click:Connect(function()
	setOpen(false)
end)

-- Allow Daily/Goal clients to request open + tab via attributes
screenGui:GetAttributeChangedSignal("RequestOpenTab"):Connect(function()
	local tab = screenGui:GetAttribute("RequestOpenTab")
	if typeof(tab) == "string" and tab ~= "" then
		setOpen(true, tab)
		screenGui:SetAttribute("RequestOpenTab", "")
	end
end)

setTab("Daily")
refreshClaimDot()
