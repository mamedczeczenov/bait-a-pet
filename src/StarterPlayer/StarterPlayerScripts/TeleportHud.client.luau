--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local TutorialGate = require(Modules:WaitForChild("TutorialGate"))
local UiIcon = require(Modules:WaitForChild("UiIcon"))
local UiTheme = require(Modules:WaitForChild("UiTheme"))
local VipPurchase = require(Modules:WaitForChild("VipPurchase"))
local PlaceConfig = require(Modules:WaitForChild("PlaceConfig"))
local AfkConfig = require(Modules:WaitForChild("AfkConfig"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestTeleportRemote = remotes:WaitForChild("RequestTeleport") :: RemoteEvent

if PlaceConfig.IsAfkPlace() then
	return
end

local function promptVipPurchase()
	VipPurchase.Prompt(function(message: string)
		TutorialGate.ShowHint(message)
	end)
end

local screenGui = UiTheme.Create("ScreenGui", {
	Name = "TeleportHud",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 8,
}, playerGui) :: ScreenGui
UiTheme.MobileScale(screenGui)

-- Transparent host — only the candy buttons, no white bar.
local buttonRow = UiTheme.Create("Frame", {
	Name = "ButtonRow",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 16),
	Size = UDim2.fromOffset(500, 52),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
}, screenGui) :: Frame

local layout = UiTheme.Create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, buttonRow) :: UIListLayout

local confirmOverlay = UiTheme.Create("Frame", {
	Name = "AfkConfirm",
	BackgroundColor3 = Color3.fromRGB(20, 28, 40),
	BackgroundTransparency = 0.35,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 40,
}, screenGui) :: Frame

local confirmDialog = UiTheme.Create("Frame", {
	Name = "Dialog",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = UiTheme.Colors.BgRaised,
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(400, 210),
	ZIndex = 41,
}, confirmOverlay) :: Frame
UiTheme.Corner(confirmDialog, UiTheme.CornerPanel)
UiTheme.Stroke(confirmDialog, UiTheme.Colors.Stroke, 4, 0)

UiTheme.Create("TextLabel", {
	Name = "Title",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 16),
	Size = UDim2.fromOffset(360, 28),
	Font = UiTheme.FontTitle,
	Text = AfkConfig.EnterTitle,
	TextColor3 = UiTheme.Colors.TextDark,
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 42,
}, confirmDialog)

UiTheme.Create("TextLabel", {
	Name = "Body",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 52),
	Size = UDim2.fromOffset(360, 78),
	Font = UiTheme.FontBody,
	Text = AfkConfig.EnterBody,
	TextColor3 = UiTheme.Colors.TextDim,
	TextSize = 16,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 42,
}, confirmDialog)

local confirmYes = UiTheme.Button({
	Name = "Yes",
	Parent = confirmDialog,
	Position = UDim2.fromOffset(20, 146),
	Size = UDim2.fromOffset(170, 42),
	Text = AfkConfig.EnterConfirm,
	TextSize = 16,
	Variant = "pink",
	ZIndex = 42,
})

local confirmCancel = UiTheme.Button({
	Name = "Cancel",
	Parent = confirmDialog,
	Position = UDim2.fromOffset(210, 146),
	Size = UDim2.fromOffset(170, 42),
	Text = "Cancel",
	TextSize = 16,
	Variant = "muted",
	ZIndex = 42,
})

type ButtonDef = {
	Id: string,
	Label: string,
	Variant: UiTheme.ButtonVariant,
	Order: number,
	TutorialTarget: string?,
	GateAction: string,
	RequiresVip: boolean?,
}

local buttons: { ButtonDef } = {
	{
		Id = "shop",
		Label = "SHOP",
		Variant = "green",
		Order = 1,
		TutorialTarget = "teleport_shop",
		GateAction = "teleport_shop",
	},
	{
		Id = "sell",
		Label = "SELL",
		Variant = "danger",
		Order = 2,
		TutorialTarget = "teleport_sell",
		GateAction = "teleport_sell",
	},
	{
		Id = "throw",
		Label = "THROW",
		Variant = "cyan",
		Order = 3,
		TutorialTarget = "teleport_throw",
		GateAction = "teleport_throw",
	},
	{
		Id = "throw_vip",
		Label = "VIP",
		Variant = "vip",
		Order = 4,
		GateAction = "teleport_throw_vip",
		RequiresVip = true,
	},
	{
		Id = "afk",
		Label = "AFK",
		Variant = "pink",
		Order = 5,
		GateAction = "teleport_afk",
	},
}

local canClick = true
local buttonRefs: { [string]: TextButton } = {}

local function hasVipAccess(): boolean
	return localPlayer:GetAttribute("VipAccess") == true
end

local function requestTeleport(destinationId: string, gateAction: string, requiresVip: boolean?)
	if not canClick then
		return
	end

	if requiresVip and not hasVipAccess() then
		promptVipPurchase()
		return
	end

	if not TutorialGate.TryAction(gateAction) then
		return
	end

	canClick = false
	requestTeleportRemote:FireServer(destinationId)
	task.delay(0.12, function()
		canClick = true
	end)
end

local TP_ICON_KEYS: { [string]: string } = {
	shop = "tp_shop",
	sell = "tp_sell",
	throw = "tp_throw",
	throw_vip = "tp_vip",
	afk = "tp_afk",
}

local function refreshVipButton()
	local button = buttonRefs.throw_vip
	if not button then
		return
	end

	if hasVipAccess() then
		button.BackgroundColor3 = UiTheme.Colors.AccentVip
		button.Text = "VIP"
		button.TextTransparency = 0
		button.BackgroundTransparency = 0
		button.TextXAlignment = Enum.TextXAlignment.Right
		UiIcon.ApplyToButton(button, "tp_vip", 22)
	else
		button.BackgroundColor3 = UiTheme.Colors.AccentVipLocked
		button.Text = "VIP"
		button.TextTransparency = 0.1
		button.BackgroundTransparency = 0.15
		button.TextXAlignment = Enum.TextXAlignment.Right
		UiIcon.ApplyToButton(button, "tp_vip_locked", 22)
	end
end

for _, def in ipairs(buttons) do
	local button = UiTheme.Button({
		Name = def.Id .. "Button",
		Text = def.Label,
		Parent = buttonRow,
		Size = UDim2.fromOffset(100, 48),
		Variant = def.Variant,
		LayoutOrder = def.Order,
		TextSize = 18,
	})

	if def.TutorialTarget then
		button:SetAttribute("TutorialTarget", def.TutorialTarget)
	end

	local iconKey = TP_ICON_KEYS[def.Id]
	if iconKey then
		button.TextXAlignment = Enum.TextXAlignment.Right
		UiIcon.ApplyToButton(button, iconKey, 22)
	end

	buttonRefs[def.Id] = button
	button.MouseButton1Click:Connect(function()
		if def.Id == "afk" then
			if not TutorialGate.TryAction(def.GateAction) then
				return
			end
			confirmOverlay.Visible = true
			screenGui.DisplayOrder = 50
			return
		end
		requestTeleport(def.Id, def.GateAction, def.RequiresVip)
	end)
end

refreshVipButton()
localPlayer:GetAttributeChangedSignal("VipAccess"):Connect(refreshVipButton)

confirmCancel.MouseButton1Click:Connect(function()
	confirmOverlay.Visible = false
	screenGui.DisplayOrder = 8
end)

confirmYes.MouseButton1Click:Connect(function()
	confirmOverlay.Visible = false
	screenGui.DisplayOrder = 8
	requestTeleport("afk", "teleport_afk")
end)

layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	buttonRow.Size = UDim2.fromOffset(math.max(500, layout.AbsoluteContentSize.X), 52)
end)
