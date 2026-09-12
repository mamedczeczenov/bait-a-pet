--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local dailyRemote = remotes:WaitForChild("Daily") :: RemoteEvent

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FeelSound = require(Modules:WaitForChild("FeelSound"))
local NumberFormat = require(Modules:WaitForChild("NumberFormat"))
local UiTheme = require(Modules:WaitForChild("UiTheme"))

local rewardsGui = playerGui:WaitForChild("RewardsGui", 15) :: ScreenGui?
if not rewardsGui then
	warn("[DailyClient] RewardsGui missing")
	return
end

local panel = rewardsGui:WaitForChild("Panel") :: Frame
local dailyPage = panel:WaitForChild("DailyPage") :: Frame

local streakLabel = UiTheme.Create("TextLabel", {
	Name = "Streak",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 8),
	Size = UDim2.fromOffset(308, 22),
	Text = "Streak: 0 / 7",
	TextColor3 = UiTheme.Colors.AccentAmber,
	TextSize = 16,
	Font = UiTheme.FontTitle,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 22,
}, dailyPage) :: TextLabel

local rewardLabel = UiTheme.Create("TextLabel", {
	Name = "Reward",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 40),
	Size = UDim2.fromOffset(308, 72),
	Text = "Claim for coins + luck buff",
	TextColor3 = UiTheme.Colors.TextDark,
	TextSize = 14,
	Font = UiTheme.FontBody,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextWrapped = true,
	ZIndex = 22,
}, dailyPage) :: TextLabel

local statusLabel = UiTheme.Create("TextLabel", {
	Name = "Status",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 120),
	Size = UDim2.fromOffset(308, 48),
	Text = "",
	TextColor3 = UiTheme.Colors.TextDim,
	TextSize = 13,
	Font = UiTheme.FontBody,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = true,
	ZIndex = 22,
}, dailyPage) :: TextLabel

local claimButton = UiTheme.Button({
	Name = "Claim",
	Parent = dailyPage,
	Position = UDim2.fromOffset(16, 190),
	Size = UDim2.fromOffset(308, 44),
	Text = "Claim",
	TextSize = 16,
	Variant = "green",
	ZIndex = 22,
}) :: TextButton

local canClaim = false

local function applySnapshot(payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	canClaim = payload.CanClaim == true
	rewardsGui:SetAttribute("DailyClaimReady", canClaim)

	local streak = if typeof(payload.Streak) == "number" then payload.Streak else 0
	local maxStreak = if typeof(payload.MaxStreak) == "number" then payload.MaxStreak else 7
	local previewStreak = if typeof(payload.PreviewStreak) == "number" then payload.PreviewStreak else math.max(1, streak)
	local previewCoins = if typeof(payload.PreviewCoins) == "number" then payload.PreviewCoins else 150
	local buffCatches = if typeof(payload.BuffCatches) == "number" then payload.BuffCatches else 5
	local buffMult = if typeof(payload.BuffMult) == "number" then payload.BuffMult else 1.15

	streakLabel.Text = string.format("Streak: %d / %d", streak, maxStreak)
	rewardLabel.Text = string.format(
		"Reward: +%s coins\n+%.0f%% luck for %d catches (streak %d)",
		NumberFormat.FormatCoins(previewCoins),
		(buffMult - 1) * 100,
		buffCatches,
		previewStreak
	)

	if typeof(payload.Message) == "string" and payload.Message ~= "" then
		statusLabel.Text = payload.Message
	elseif canClaim then
		statusLabel.Text = "Ready to claim (resets UTC midnight)."
	else
		statusLabel.Text = "Already claimed today. Come back tomorrow."
	end

	claimButton.Active = canClaim
	claimButton.AutoButtonColor = canClaim
	claimButton.BackgroundColor3 = if canClaim then UiTheme.Colors.AccentGreen else UiTheme.Colors.BgMuted
	claimButton.Text = if canClaim then "Claim" else "Claimed"
end

claimButton.MouseButton1Click:Connect(function()
	if not canClaim then
		return
	end
	dailyRemote:FireServer({ Type = "Claim" })
end)

-- Refresh when hub opens or Daily tab is selected
local function maybeReady()
	if panel.Visible and dailyPage.Visible then
		dailyRemote:FireServer({ Type = "Ready" })
	end
end

panel:GetPropertyChangedSignal("Visible"):Connect(maybeReady)
dailyPage:GetPropertyChangedSignal("Visible"):Connect(maybeReady)
rewardsGui:GetAttributeChangedSignal("OpenRequest"):Connect(maybeReady)

dailyRemote.OnClientEvent:Connect(function(payload)
	applySnapshot(payload)
	if typeof(payload) == "table"
		and typeof(payload.Message) == "string"
		and string.find(payload.Message, "claimed", 1, true)
	then
		FeelSound.Play("Buy", 0.65)
	end
end)

task.defer(function()
	dailyRemote:FireServer({ Type = "Ready" })
end)
