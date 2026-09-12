--!strict

local AdService = game:GetService("AdService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local adRemote = remotes:WaitForChild("AdReward") :: RemoteEvent

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FeelSound = require(Modules:WaitForChild("FeelSound"))
local NumberFormat = require(Modules:WaitForChild("NumberFormat"))
local UiIcon = require(Modules:WaitForChild("UiIcon"))
local UiTheme = require(Modules:WaitForChild("UiTheme"))
local UiToast = require(Modules:WaitForChild("UiToast"))

local rewardsGui = playerGui:WaitForChild("RewardsGui", 15) :: ScreenGui?
if not rewardsGui then
	warn("[AdRewardClient] RewardsGui missing")
	return
end

local panel = rewardsGui:WaitForChild("Panel") :: Frame
local adsPage = panel:WaitForChild("AdsPage") :: Frame

type MilestonePayload = {
	At: number,
	PotionId: string,
	Name: string,
	Description: string,
	Claimed: boolean,
}

local progressLabel = UiTheme.Create("TextLabel", {
	Name = "Progress",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 6),
	Size = UDim2.fromOffset(308, 22),
	Text = "Today: 0 / 10",
	TextColor3 = UiTheme.Colors.AccentAmber,
	TextSize = 16,
	Font = UiTheme.FontTitle,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 22,
}, adsPage) :: TextLabel

local barBg = UiTheme.Create("Frame", {
	Name = "BarBg",
	BackgroundColor3 = UiTheme.Colors.BgMuted,
	Position = UDim2.fromOffset(16, 32),
	Size = UDim2.fromOffset(308, 12),
	ZIndex = 22,
}, adsPage) :: Frame
UiTheme.Corner(barBg, UDim.new(1, 0))
UiTheme.Stroke(barBg, UiTheme.Colors.Stroke, 2, 0)

local barFill = UiTheme.Create("Frame", {
	Name = "Fill",
	BackgroundColor3 = UiTheme.Colors.AccentCyan,
	Size = UDim2.fromScale(0, 1),
	ZIndex = 23,
}, barBg) :: Frame
UiTheme.Corner(barFill, UDim.new(1, 0))
UiTheme.Gradient(barFill, Color3.fromRGB(140, 230, 255), UiTheme.Colors.AccentCyanDim, 90)

local coinRow = UiTheme.Row({
	Name = "EveryAd",
	Parent = adsPage,
	Position = UDim2.fromOffset(16, 52),
	Size = UDim2.fromOffset(308, 40),
	ZIndex = 22,
	RarityColor = Color3.fromRGB(255, 210, 80),
})
UiIcon.Mount(coinRow, {
	Key = "hud_coins",
	Size = UDim2.fromOffset(22, 22),
	Position = UDim2.fromOffset(10, 9),
	ZIndex = 23,
})
local coinLabel = UiTheme.Create("TextLabel", {
	Name = "Label",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(40, 4),
	Size = UDim2.fromOffset(256, 32),
	Text = "Every ad: +150 coins",
	TextColor3 = UiTheme.Colors.TextDark,
	TextSize = 14,
	Font = UiTheme.FontMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 23,
}, coinRow) :: TextLabel

local milestoneHolders: { Frame } = {}

local function clearMilestones()
	for _, holder in ipairs(milestoneHolders) do
		holder:Destroy()
	end
	table.clear(milestoneHolders)
end

local function milestoneIconKey(potionId: string): string
	if potionId == "luck" then
		return "station_upgrade_luck"
	end
	if potionId == "super_bundle" or potionId == "super_luck" then
		return "vip_crown"
	end
	if potionId == "sell" or potionId == "super_sell" then
		return "station_upgrade_value"
	end
	return "event_lucky"
end

local watchButton = UiTheme.Button({
	Name = "Watch",
	Parent = adsPage,
	Position = UDim2.fromOffset(16, 214),
	Size = UDim2.fromOffset(308, 44),
	Text = "Watch Ad",
	TextSize = 16,
	Variant = "cyan",
	ZIndex = 22,
}) :: TextButton

local statusLabel = UiTheme.Create("TextLabel", {
	Name = "Status",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 264),
	Size = UDim2.fromOffset(308, 80),
	Text = "Resets at UTC midnight.",
	TextColor3 = UiTheme.Colors.TextDim,
	TextSize = 13,
	Font = UiTheme.FontBody,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextWrapped = true,
	ZIndex = 22,
}, adsPage) :: TextLabel

local function renderMilestones(milestones: { MilestonePayload })
	clearMilestones()
	for index, milestone in ipairs(milestones) do
		local y = 98 + (index - 1) * 56
		local row = UiTheme.Row({
			Name = "Milestone" .. tostring(index),
			Parent = adsPage,
			Position = UDim2.fromOffset(16, y),
			Size = UDim2.fromOffset(308, 50),
			ZIndex = 22,
			RarityColor = if milestone.Claimed then Color3.fromRGB(80, 230, 90) else Color3.fromRGB(140, 200, 255),
		})
		UiIcon.Mount(row, {
			Key = milestoneIconKey(milestone.PotionId),
			Size = UDim2.fromOffset(22, 22),
			Position = UDim2.fromOffset(10, 14),
			ZIndex = 23,
		})
		UiTheme.Create("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(40, 4),
			Size = UDim2.fromOffset(210, 20),
			Text = string.format("%d ads — %s", milestone.At, milestone.Name),
			TextColor3 = UiTheme.Colors.TextDark,
			TextSize = 13,
			Font = UiTheme.FontTitle,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 23,
		}, row)
		UiTheme.Create("TextLabel", {
			Name = "Desc",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(40, 24),
			Size = UDim2.fromOffset(210, 22),
			Text = milestone.Description,
			TextColor3 = UiTheme.Colors.TextDim,
			TextSize = 11,
			Font = UiTheme.FontBody,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			ZIndex = 23,
		}, row)
		UiTheme.Create("TextLabel", {
			Name = "State",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(52, 20),
			Text = if milestone.Claimed then "DONE" else "—",
			TextColor3 = if milestone.Claimed then UiTheme.Colors.Success else UiTheme.Colors.TextMuted,
			TextSize = 12,
			Font = UiTheme.FontTitle,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 23,
		}, row)
		table.insert(milestoneHolders, row)
	end
	local y = 98 + #milestones * 56 + 4
	watchButton.Position = UDim2.fromOffset(16, y)
	statusLabel.Position = UDim2.fromOffset(16, y + 50)
end

local INELIGIBLE: { any } = {}
pcall(function()
	table.insert(INELIGIBLE, Enum.AdAvailabilityResult.PlayerIneligible)
	table.insert(INELIGIBLE, Enum.AdAvailabilityResult.DeviceIneligible)
	table.insert(INELIGIBLE, Enum.AdAvailabilityResult.PublisherIneligible)
	table.insert(INELIGIBLE, Enum.AdAvailabilityResult.ExperienceIneligible)
end)

local function isIneligible(result: any): boolean
	for _, entry in ipairs(INELIGIBLE) do
		if result == entry then
			return true
		end
	end
	return false
end

local serverCanWatch = false
local serverConfigured = false
local studioSimulate = false
local adAvailable = false
local adIneligible = false
local watching = false
local remaining = 0
local opportunityRegistered = false

local function combinedCanWatch(): boolean
	if watching then
		return false
	end
	if remaining <= 0 or not serverCanWatch then
		return false
	end
	if studioSimulate then
		return true
	end
	if not serverConfigured then
		return false
	end
	return adAvailable
end

local function applyWatchButton()
	local canWatch = combinedCanWatch()
	watchButton.Active = canWatch
	watchButton.AutoButtonColor = canWatch
	if watching then
		watchButton.Text = "Watching..."
		watchButton.BackgroundColor3 = UiTheme.Colors.BgMuted
	elseif remaining <= 0 then
		watchButton.Text = "Done today"
		watchButton.BackgroundColor3 = UiTheme.Colors.BgMuted
	elseif canWatch then
		watchButton.Text = "Watch Ad"
		watchButton.BackgroundColor3 = UiTheme.ButtonColor("cyan")
	else
		watchButton.Text = "Unavailable"
		watchButton.BackgroundColor3 = UiTheme.Colors.BgMuted
	end
end

local function defaultStatus(): string
	if remaining <= 0 then
		return "Daily ads complete. Come back tomorrow (UTC midnight)."
	end
	if studioSimulate then
		return "Studio: watching simulates a completed ad (no live video)."
	end
	if not serverConfigured then
		return "Create a Developer Product in Creator Dashboard and paste its ID into AdRewardConfig."
	end
	if adIneligible then
		return "Ads aren't available on this account or device."
	end
	if not adAvailable then
		return "No ad ready right now. Open this tab again in a moment."
	end
	return "Watch the whole video to get the reward. Resets at UTC midnight."
end

local function checkAdAvailability()
	if studioSimulate or not serverConfigured then
		adAvailable = studioSimulate
		adIneligible = false
		applyWatchButton()
		return
	end

	local ok, result = pcall(function()
		return AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)
	end)
	if ok and result ~= nil and (result :: any).AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable then
		adAvailable = true
		adIneligible = false
	else
		adAvailable = false
		local availability = if ok and result ~= nil then (result :: any).AdAvailabilityResult else nil
		adIneligible = typeof(availability) == "EnumItem" and isIneligible(availability)
	end
	applyWatchButton()
	if adsPage.Visible and not string.find(statusLabel.Text, "Ad ", 1, true) then
		statusLabel.Text = defaultStatus()
	end
end

local function registerOpportunity()
	if opportunityRegistered then
		return
	end
	local ok, err = pcall(function()
		AdService:RegisterAdOpportunityAsync(watchButton)
	end)
	if ok then
		opportunityRegistered = true
	else
		warn("[AdRewardClient] RegisterAdOpportunityAsync:", err)
	end
end

local function applySnapshot(payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	local watched = if typeof(payload.AdsWatched) == "number" then payload.AdsWatched else 0
	local dailyMax = if typeof(payload.DailyMax) == "number" then payload.DailyMax else 10
	local coins = if typeof(payload.CoinsPerAd) == "number" then payload.CoinsPerAd else 150
	remaining = if typeof(payload.Remaining) == "number" then payload.Remaining else math.max(0, dailyMax - watched)
	serverCanWatch = payload.CanWatch == true
	serverConfigured = payload.Configured == true
	studioSimulate = payload.StudioSimulate == true

	progressLabel.Text = string.format("Today: %d / %d", watched, dailyMax)
	barFill.Size = UDim2.fromScale(if dailyMax > 0 then watched / dailyMax else 0, 1)
	coinLabel.Text = string.format("Every ad: +%s coins", NumberFormat.FormatCoins(coins))

	local milestones: { MilestonePayload } = {}
	if typeof(payload.Milestones) == "table" then
		for _, entry in ipairs(payload.Milestones) do
			if typeof(entry) == "table" then
				table.insert(milestones, {
					At = if typeof(entry.At) == "number" then entry.At else 0,
					PotionId = if typeof(entry.PotionId) == "string" then entry.PotionId else "",
					Name = if typeof(entry.Name) == "string" then entry.Name else "Potion",
					Description = if typeof(entry.Description) == "string" then entry.Description else "",
					Claimed = entry.Claimed == true,
				})
			end
		end
	end
	renderMilestones(milestones)

	local message = if typeof(payload.Message) == "string" then payload.Message else ""
	if message ~= "" then
		statusLabel.Text = message
	else
		statusLabel.Text = defaultStatus()
	end

	applyWatchButton()
end

watchButton.MouseButton1Click:Connect(function()
	if not combinedCanWatch() then
		return
	end
	watching = true
	applyWatchButton()
	statusLabel.Text = "Playing ad..."
	adRemote:FireServer({ Type = "Watch" })
end)

local function maybeReady()
	if panel.Visible and adsPage.Visible then
		registerOpportunity()
		adRemote:FireServer({ Type = "Ready" })
		checkAdAvailability()
	end
end

panel:GetPropertyChangedSignal("Visible"):Connect(maybeReady)
adsPage:GetPropertyChangedSignal("Visible"):Connect(maybeReady)
rewardsGui:GetAttributeChangedSignal("OpenRequest"):Connect(maybeReady)

adRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	if payload.Type == "ShowResult" then
		watching = false
		applyWatchButton()
		checkAdAvailability()
		return
	end
	applySnapshot(payload)
	if typeof(payload.Message) == "string" and string.find(payload.Message, "coins", 1, true) then
		FeelSound.Play("Buy", 0.65)
		UiToast.Show(payload.Message, 3.2)
		watching = false
		applyWatchButton()
	end
end)

task.defer(function()
	adRemote:FireServer({ Type = "Ready" })
end)
