--!strict

--[[
	Playtime gifts HUD: session luck that resets on ESC leave/rejoin.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local giftsRemote = remotes:WaitForChild("Gifts") :: RemoteEvent

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FeelSound = require(Modules:WaitForChild("FeelSound"))
local GiftConfig = require(Modules:WaitForChild("GiftConfig"))
local PlaceConfig = require(Modules:WaitForChild("PlaceConfig"))
local TutorialGate = require(Modules:WaitForChild("TutorialGate"))
local UiIcon = require(Modules:WaitForChild("UiIcon"))
local UiTheme = require(Modules:WaitForChild("UiTheme"))
local UiToast = require(Modules:WaitForChild("UiToast"))

local snapshotElapsed = 0
local snapshotServerTime = Workspace:GetServerTimeNow()
local claimedTier = 0
local giftLuck = 1
local toastedReadyTier = 0
local leaveWarningShownAt = 0

local screenGui = UiTheme.Create("ScreenGui", {
	Name = "GiftsGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = if PlaceConfig.IsAfkPlace() then 75 else 25,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui) :: ScreenGui
UiTheme.MobileScale(screenGui)

local openButton = UiTheme.Button({
	Name = "OpenGifts",
	Parent = screenGui,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -18, 0, 154),
	Size = UDim2.fromOffset(150, 40),
	Text = "Gifts",
	TextSize = 15,
	Variant = "pink",
	ZIndex = 8,
}) :: TextButton
openButton.TextXAlignment = Enum.TextXAlignment.Right
UiIcon.ApplyToButton(openButton, "hud_gifts", 22)
if PlaceConfig.IsAfkPlace() then
	openButton.Position = UDim2.new(1, -18, 0, 18)
end

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

local luckBadge = UiTheme.Create("TextLabel", {
	Name = "LuckBadge",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 6, 1, -4),
	Size = UDim2.fromOffset(64, 14),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = UiTheme.Colors.Text,
	TextSize = 11,
	Font = UiTheme.FontTitle,
	TextXAlignment = Enum.TextXAlignment.Left,
	Visible = false,
	ZIndex = 9,
}, openButton) :: TextLabel
UiTheme.TextStroke(luckBadge, 2)

local panel = UiTheme.Panel({
	Name = "Panel",
	Parent = screenGui,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -18, 0, 202),
	Size = UDim2.fromOffset(340, 460),
	Visible = false,
	ZIndex = 20,
})
if PlaceConfig.IsAfkPlace() then
	panel.Position = UDim2.new(1, -18, 0, 66)
end

UiTheme.Label({
	Name = "Title",
	Parent = panel,
	Position = UDim2.fromOffset(14, 12),
	Size = UDim2.fromOffset(220, 32),
	Text = "Gifts",
	TextSize = 24,
	Font = UiTheme.FontTitle,
	Color = UiTheme.Colors.Text,
	Outlined = true,
	ZIndex = 21,
})

local luckLabel = UiTheme.Label({
	Name = "Luck",
	Parent = panel,
	Position = UDim2.fromOffset(14, 62),
	Size = UDim2.fromOffset(312, 22),
	Text = "No gift luck yet",
	TextSize = 15,
	Font = UiTheme.FontTitle,
	Color = UiTheme.Colors.TextDark,
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

type SlotGui = {
	Row: Frame,
	NameLabel: TextLabel,
	MultLabel: TextLabel,
	StatusLabel: TextLabel,
	ClaimButton: TextButton,
}

local slots: { SlotGui } = {}

local function createSlot(index: number): SlotGui
	local y = 90 + (index - 1) * 64
	local row = UiTheme.Row({
		Name = "Gift" .. tostring(index),
		Parent = panel,
		Position = UDim2.fromOffset(12, y),
		Size = UDim2.fromOffset(316, 58),
		ZIndex = 21,
	})

	local nameLabel = UiTheme.Label({
		Name = "GiftName",
		Parent = row,
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.fromOffset(200, 22),
		Text = "",
		TextSize = 15,
		Font = UiTheme.FontTitle,
		Color = UiTheme.Colors.TextDark,
		ZIndex = 22,
	})

	local multLabel = UiTheme.Label({
		Name = "Mult",
		Parent = row,
		Position = UDim2.fromOffset(10, 28),
		Size = UDim2.fromOffset(140, 22),
		Text = "",
		TextSize = 14,
		Color = UiTheme.Colors.TextDim,
		ZIndex = 22,
	})

	local statusLabel = UiTheme.Label({
		Name = "Status",
		Parent = row,
		Position = UDim2.fromOffset(150, 16),
		Size = UDim2.fromOffset(70, 26),
		Text = "",
		TextSize = 14,
		Font = UiTheme.FontTitle,
		Color = UiTheme.Colors.TextDim,
		XAlign = Enum.TextXAlignment.Right,
		ZIndex = 22,
	})

	local claimButton = UiTheme.Button({
		Name = "Claim",
		Parent = row,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(88, 32),
		Text = "Claim",
		TextSize = 14,
		Variant = "green",
		ZIndex = 23,
	}) :: TextButton
	claimButton.Visible = false

	claimButton.MouseButton1Click:Connect(function()
		giftsRemote:FireServer({ Type = "Claim", Tier = index })
	end)

	return {
		Row = row,
		NameLabel = nameLabel,
		MultLabel = multLabel,
		StatusLabel = statusLabel,
		ClaimButton = claimButton,
	}
end

for i = 1, GiftConfig.Count() do
	slots[i] = createSlot(i)
end

UiTheme.Label({
	Name = "Footer",
	Parent = panel,
	Position = UDim2.fromOffset(14, 414),
	Size = UDim2.fromOffset(312, 36),
	Text = "Leaving the game resets these gifts.",
	TextSize = 13,
	Color = UiTheme.Colors.TextDim,
	ZIndex = 21,
})

local warningGui = UiTheme.Create("ScreenGui", {
	Name = "GiftLeaveWarningGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 120,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui) :: ScreenGui
UiTheme.MobileScale(warningGui)

local warningBanner = UiTheme.Create("TextLabel", {
	Name = "Banner",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 18),
	Size = UDim2.fromOffset(560, 64),
	BackgroundColor3 = UiTheme.Colors.AccentRed,
	Text = "Leaving or rejoining will reset your playtime gifts.",
	TextColor3 = UiTheme.Colors.Text,
	TextSize = 18,
	Font = UiTheme.FontTitle,
	TextWrapped = true,
	Visible = false,
	ZIndex = 10,
}, warningGui) :: TextLabel
UiTheme.Corner(warningBanner, UiTheme.CornerButton)
UiTheme.Stroke(warningBanner, UiTheme.Colors.Stroke, 3, 0)
UiTheme.TextStroke(warningBanner, 2.2)
UiTheme.Gradient(warningBanner, Color3.fromRGB(255, 140, 120), UiTheme.Colors.AccentRed, 90)
UiTheme.Pad(warningBanner, 8)

local function currentElapsed(): number
	local drift = Workspace:GetServerTimeNow() - snapshotServerTime
	return GiftConfig.ClampElapsed(snapshotElapsed + math.max(0, drift))
end

local function setOpen(open: boolean)
	if open and not TutorialGate.IsCompleted() then
		return
	end
	panel.Visible = open
	if open then
		UiTheme.BounceIn(panel, 0.7)
		giftsRemote:FireServer({ Type = "Ready" })
	end
end

local function refreshTutorialLock()
	local done = TutorialGate.IsCompleted()
	openButton.Visible = done
	if not done then
		panel.Visible = false
	end
end

local function refreshHudChrome(elapsed: number)
	local ready = GiftConfig.HasReady(elapsed, claimedTier)
	claimDot.Visible = ready
	if giftLuck > 1.001 then
		luckBadge.Visible = true
		luckBadge.Text = GiftConfig.FormatMult(giftLuck)
	else
		luckBadge.Visible = false
	end
end

local function maybeToastReady(elapsed: number)
	if not TutorialGate.IsCompleted() then
		return
	end
	local nextTier = claimedTier + 1
	if GiftConfig.GetState(elapsed, claimedTier, nextTier) ~= "Ready" then
		return
	end
	if toastedReadyTier >= nextTier then
		return
	end
	toastedReadyTier = nextTier
	UiToast.Show("Playtime gift ready!")
	FeelSound.Play("Buy", 0.45)
end

local function refreshSlots(elapsed: number)
	if giftLuck > 1.001 then
		luckLabel.Text = "Gift luck: " .. GiftConfig.FormatMult(giftLuck)
	else
		luckLabel.Text = "No gift luck yet"
	end

	for _, gift in ipairs(GiftConfig.Gifts) do
		local slot = slots[gift.Tier]
		if not slot then
			continue
		end
		local state = GiftConfig.GetState(elapsed, claimedTier, gift.Tier)
		slot.NameLabel.Text = gift.Name
		slot.MultLabel.Text = GiftConfig.FormatMult(gift.Mult) .. " luck"
		slot.ClaimButton.Visible = state == "Ready"
		if state == "Claimed" then
			slot.StatusLabel.Text = "Claimed"
			slot.StatusLabel.TextColor3 = UiTheme.Colors.AccentGreenHot
			slot.StatusLabel.Visible = true
		elseif state == "Ready" then
			slot.StatusLabel.Visible = false
		else
			local remaining = GiftConfig.RemainingSeconds(elapsed, claimedTier, gift.Tier)
			slot.StatusLabel.Text = GiftConfig.FormatCountdown(remaining)
			slot.StatusLabel.TextColor3 = UiTheme.Colors.TextDim
			slot.StatusLabel.Visible = true
		end
	end
end

local function applySnapshot(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	if payload.Type ~= "Snapshot" then
		return
	end

	snapshotElapsed = if typeof(payload.Elapsed) == "number" then payload.Elapsed else 0
	snapshotServerTime = if typeof(payload.ServerTime) == "number" then payload.ServerTime else Workspace:GetServerTimeNow()
	claimedTier = GiftConfig.ClampTier(payload.ClaimedTier)
	giftLuck = if typeof(payload.GiftLuck) == "number" then payload.GiftLuck else GiftConfig.GetLuckForTier(claimedTier)
	if toastedReadyTier < claimedTier then
		toastedReadyTier = claimedTier
	end

	local elapsed = currentElapsed()
	refreshSlots(elapsed)
	refreshHudChrome(elapsed)
	maybeToastReady(elapsed)

	if typeof(payload.Message) == "string" and payload.Message ~= "" then
		UiToast.Show(payload.Message)
		FeelSound.Play("Buy", 0.65)
	end
end

local function warningText(): string
	if giftLuck > 1.001 then
		return string.format(
			"Leaving or rejoining will reset your playtime gifts.\nYou will lose %s luck.",
			GiftConfig.FormatMult(giftLuck)
		)
	end
	return "Leaving or rejoining will reset your playtime gifts."
end

local function showLeaveWarning()
	leaveWarningShownAt = os.clock()
	warningBanner.Text = warningText()
	warningBanner.Visible = true
	UiTheme.BounceIn(warningBanner, 0.7)
end

local function hideLeaveWarning()
	local shownFor = os.clock() - leaveWarningShownAt
	local remain = GiftConfig.LeaveWarningSeconds - shownFor
	if remain > 0 and GuiService.MenuIsOpen then
		return
	end
	if remain > 0 then
		task.delay(remain, function()
			if GuiService.MenuIsOpen then
				return
			end
			warningBanner.Visible = false
		end)
		return
	end
	warningBanner.Visible = false
end

openButton.MouseButton1Click:Connect(function()
	if not TutorialGate.IsCompleted() then
		TutorialGate.ShowHint("Finish the guide first.")
		return
	end
	setOpen(not panel.Visible)
end)

closeButton.MouseButton1Click:Connect(function()
	setOpen(false)
end)

giftsRemote.OnClientEvent:Connect(applySnapshot)

GuiService.MenuOpened:Connect(showLeaveWarning)
GuiService.MenuClosed:Connect(hideLeaveWarning)

localPlayer:GetAttributeChangedSignal("TutorialCompleted"):Connect(refreshTutorialLock)
refreshTutorialLock()

RunService.Heartbeat:Connect(function()
	if not openButton.Visible and not panel.Visible then
		return
	end
	local elapsed = currentElapsed()
	refreshHudChrome(elapsed)
	if panel.Visible then
		refreshSlots(elapsed)
	end
	maybeToastReady(elapsed)
end)

task.defer(function()
	giftsRemote:FireServer({ Type = "Ready" })
end)
