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

local portalOverlay = UiTheme.Create("Frame", {
	Name = "PortalPicker",
	BackgroundColor3 = Color3.fromRGB(20, 28, 40),
	BackgroundTransparency = 0.35,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 40,
}, screenGui) :: Frame

local portalDialog = UiTheme.Create("Frame", {
	Name = "Dialog",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = UiTheme.Colors.BgRaised,
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(400, 236),
	ZIndex = 41,
}, portalOverlay) :: Frame
UiTheme.Corner(portalDialog, UiTheme.CornerPanel)
UiTheme.Stroke(portalDialog, UiTheme.Colors.Stroke, 4, 0)

UiTheme.Create("TextLabel", {
	Name = "Title",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 16),
	Size = UDim2.fromOffset(360, 28),
	Font = UiTheme.FontTitle,
	Text = "Go to portal",
	TextColor3 = UiTheme.Colors.TextDark,
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 42,
}, portalDialog)

UiTheme.Create("TextLabel", {
	Name = "Body",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 48),
	Size = UDim2.fromOffset(360, 36),
	Font = UiTheme.FontBody,
	Text = "Walk up to a portal, then press E. AFK lobby or another world.",
	TextColor3 = UiTheme.Colors.TextDim,
	TextSize = 15,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 42,
}, portalDialog)

local goAfkPortal = UiTheme.Button({
	Name = "AfkPortal",
	Parent = portalDialog,
	Position = UDim2.fromOffset(20, 96),
	Size = UDim2.fromOffset(360, 44),
	Text = "AFK portal",
	TextSize = 18,
	Variant = "pink",
	ZIndex = 42,
})

local goWorldsPortal = UiTheme.Button({
	Name = "WorldsPortal",
	Parent = portalDialog,
	Position = UDim2.fromOffset(20, 148),
	Size = UDim2.fromOffset(170, 42),
	Text = "Worlds",
	TextSize = 16,
	Variant = "cyan",
	ZIndex = 42,
})

local portalCancel = UiTheme.Button({
	Name = "Cancel",
	Parent = portalDialog,
	Position = UDim2.fromOffset(210, 148),
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
		Id = "portal",
		Label = "PORTAL",
		Variant = "pink",
		Order = 5,
		GateAction = "teleport_portal",
	},
}

local canClick = true
local buttonRefs: { [string]: TextButton } = {}

local function hasVipAccess(): boolean
	return localPlayer:GetAttribute("VipAccess") == true
end

local function hidePortalPicker()
	portalOverlay.Visible = false
	screenGui.DisplayOrder = 8
end

local function showPortalPicker()
	portalOverlay.Visible = true
	screenGui.DisplayOrder = 50
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
	portal = "tp_portal",
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
		Size = UDim2.fromOffset(110, 48),
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
		if def.Id == "portal" then
			if not TutorialGate.TryAction(def.GateAction) then
				return
			end
			showPortalPicker()
			return
		end
		requestTeleport(def.Id, def.GateAction, def.RequiresVip)
	end)
end

refreshVipButton()
localPlayer:GetAttributeChangedSignal("VipAccess"):Connect(refreshVipButton)

portalCancel.MouseButton1Click:Connect(hidePortalPicker)

goAfkPortal.MouseButton1Click:Connect(function()
	hidePortalPicker()
	requestTeleport("afk_portal", "teleport_portal")
end)

goWorldsPortal.MouseButton1Click:Connect(function()
	hidePortalPicker()
	requestTeleport("maps", "teleport_portal")
end)

layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	buttonRow.Size = UDim2.fromOffset(math.max(500, layout.AbsoluteContentSize.X), 52)
end)
