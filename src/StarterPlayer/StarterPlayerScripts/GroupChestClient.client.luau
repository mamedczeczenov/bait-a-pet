--!strict

--[[
	Group VIP chest prompt: Join / Claim, no purchase language.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local groupChestRemote = remotes:WaitForChild("GroupChest") :: RemoteEvent

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FeelSound = require(Modules:WaitForChild("FeelSound"))
local GroupChestConfig = require(Modules:WaitForChild("GroupChestConfig"))
local NumberFormat = require(Modules:WaitForChild("NumberFormat"))
local UiTheme = require(Modules:WaitForChild("UiTheme"))
local UiToast = require(Modules:WaitForChild("UiToast"))

local claiming = false
local claimed = false
local inGroup = false

local screenGui = UiTheme.Create("ScreenGui", {
	Name = "GroupChestGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 88,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui) :: ScreenGui
UiTheme.MobileScale(screenGui)

local overlay = UiTheme.Create("Frame", {
	Name = "Overlay",
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.45,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 10,
}, screenGui) :: Frame

local card = UiTheme.Create("Frame", {
	Name = "Card",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(460, 312),
	ZIndex = 11,
}, overlay) :: Frame
UiTheme.Corner(card, UiTheme.CornerPanel)
UiTheme.Stroke(card, UiTheme.Colors.Stroke, 4, 0)

local title = UiTheme.Create("TextLabel", {
	Name = "Title",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(22, 16),
	Size = UDim2.fromOffset(360, 28),
	Font = UiTheme.FontTitle,
	Text = GroupChestConfig.PromptTitle,
	TextColor3 = UiTheme.Colors.TextDark,
	TextSize = 24,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 12,
}, card) :: TextLabel

local closeButton = UiTheme.Create("TextButton", {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0),
	AutoButtonColor = true,
	BackgroundColor3 = UiTheme.Colors.AccentRed,
	Font = UiTheme.FontTitle,
	Position = UDim2.new(1, -16, 0, 12),
	Size = UDim2.fromOffset(36, 36),
	Text = "X",
	TextColor3 = UiTheme.Colors.Text,
	TextSize = 20,
	ZIndex = 13,
}, card) :: TextButton
UiTheme.Corner(closeButton, UiTheme.CornerSmall)
UiTheme.Stroke(closeButton, UiTheme.Colors.Stroke, 3, 0)
UiTheme.TextStroke(closeButton, 2)
UiTheme.Gradient(closeButton, Color3.fromRGB(255, 110, 110), Color3.fromRGB(230, 40, 50), 90)
UiTheme.WireButtonMotion(closeButton)

local thumb = UiTheme.Create("ImageLabel", {
	Name = "Thumb",
	BackgroundColor3 = Color3.fromRGB(240, 242, 246),
	BorderSizePixel = 0,
	Image = GroupChestConfig.GroupIcon,
	Position = UDim2.fromOffset(22, 60),
	ScaleType = Enum.ScaleType.Fit,
	Size = UDim2.fromOffset(88, 88),
	ZIndex = 12,
}, card) :: ImageLabel
UiTheme.Corner(thumb, UiTheme.CornerSmall)
UiTheme.Stroke(thumb, UiTheme.Colors.Stroke, 3, 0)

local itemName = UiTheme.Create("TextLabel", {
	Name = "ItemName",
	BackgroundTransparency = 1,
	Font = UiTheme.FontTitle,
	Position = UDim2.fromOffset(124, 62),
	Size = UDim2.fromOffset(310, 28),
	Text = GroupChestConfig.ItemName,
	TextColor3 = UiTheme.Colors.TextDark,
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 12,
}, card) :: TextLabel

local seller = UiTheme.Create("TextLabel", {
	Name = "Seller",
	BackgroundTransparency = 1,
	Font = UiTheme.FontBody,
	Position = UDim2.fromOffset(124, 90),
	Size = UDim2.fromOffset(310, 20),
	Text = "By Group",
	TextColor3 = UiTheme.Colors.TextDim,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 12,
}, card) :: TextLabel

local priceRow = UiTheme.Create("Frame", {
	Name = "RewardRow",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(124, 116),
	Size = UDim2.fromOffset(310, 28),
	ZIndex = 12,
}, card) :: Frame

local priceLabel = UiTheme.Create("TextLabel", {
	Name = "Reward",
	BackgroundTransparency = 1,
	Font = UiTheme.FontTitle,
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.fromOffset(310, 28),
	Text = "",
	TextColor3 = Color3.fromRGB(40, 170, 70),
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 13,
}, priceRow) :: TextLabel

local body = UiTheme.Create("TextLabel", {
	Name = "Body",
	BackgroundTransparency = 1,
	Font = UiTheme.FontBody,
	Position = UDim2.fromOffset(22, 164),
	Size = UDim2.fromOffset(416, 52),
	Text = "",
	TextColor3 = UiTheme.Colors.TextDark,
	TextSize = 15,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 12,
}, card) :: TextLabel

local status = UiTheme.Create("TextLabel", {
	Name = "Status",
	BackgroundTransparency = 1,
	Font = UiTheme.FontBody,
	Position = UDim2.fromOffset(22, 214),
	Size = UDim2.fromOffset(416, 22),
	Text = "",
	TextColor3 = UiTheme.Colors.AccentRed,
	TextSize = 13,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 12,
}, card) :: TextLabel

local cancelButton = UiTheme.Button({
	Name = "Cancel",
	Parent = card,
	Position = UDim2.fromOffset(22, 246),
	Size = UDim2.fromOffset(196, 46),
	Text = GroupChestConfig.CancelButtonText,
	TextSize = 18,
	Variant = "muted",
	ZIndex = 13,
})

local actionButton = UiTheme.Button({
	Name = "Action",
	Parent = card,
	Position = UDim2.fromOffset(242, 246),
	Size = UDim2.fromOffset(196, 46),
	Text = GroupChestConfig.JoinButtonText,
	TextSize = 18,
	Variant = "green",
	ZIndex = 13,
})

local function hidePrompt()
	overlay.Visible = false
	claiming = false
end

local function setActionEnabled(enabled: boolean, label: string)
	actionButton.Text = label
	actionButton.AutoButtonColor = false
	actionButton.Active = enabled
	if enabled then
		actionButton.BackgroundColor3 = UiTheme.ButtonColor("green")
	else
		actionButton.BackgroundColor3 = UiTheme.ButtonColor("muted")
	end
end

local function applySnapshot(payload: { [string]: any })
	claimed = payload.Claimed == true
	inGroup = payload.InGroup == true

	local name = payload.ItemName
	itemName.Text = if typeof(name) == "string" and name ~= "" then name else GroupChestConfig.ItemName

	local groupName = payload.GroupName
	seller.Text = if typeof(groupName) == "string" and groupName ~= "" then groupName else "Group"

	local icon = payload.GroupIcon
	if typeof(icon) == "string" and icon ~= "" then
		thumb.Image = icon
	end

	local coins = payload.RewardCoins
	local coinText = NumberFormat.FormatCoins(if typeof(coins) == "number" then coins else GroupChestConfig.RewardCoins)
	priceLabel.Text = string.format("+%s coins", coinText)
	if claimed then
		title.Text = GroupChestConfig.PromptTitle
		body.Text = GroupChestConfig.AlreadyClaimedMessage
		setActionEnabled(false, GroupChestConfig.ClaimedButtonText)
		status.Text = ""
	elseif inGroup then
		title.Text = GroupChestConfig.PromptTitle
		body.Text = string.format("Claim +%s coins for being in the group.", coinText)
		setActionEnabled(true, GroupChestConfig.ClaimButtonText)
		status.Text = ""
	else
		title.Text = GroupChestConfig.JoinPromptTitle
		body.Text = string.format("Join the group to get +%s coins.", coinText)
		setActionEnabled(true, GroupChestConfig.JoinButtonText)
		status.Text = GroupChestConfig.NeedGroupMessage
		status.TextColor3 = UiTheme.Colors.AccentRed
	end
end

local function showPrompt(payload: { [string]: any })
	applySnapshot(payload)
	claiming = false
	overlay.Visible = true
	UiTheme.BounceIn(card, 0.86)
end

closeButton.MouseButton1Click:Connect(hidePrompt)
cancelButton.MouseButton1Click:Connect(hidePrompt)

actionButton.MouseButton1Click:Connect(function()
	if not overlay.Visible or claiming or claimed then
		return
	end
	claiming = true
	FeelSound.Play("Click")
	groupChestRemote:FireServer("Claim")
end)

groupChestRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local kind = payload.Type
	local message = payload.Message

	if kind == "Open" then
		showPrompt(payload)
		return
	end

	if kind == "Claimed" then
		claiming = false
		hidePrompt()
		FeelSound.Play("Buy")
		if typeof(message) == "string" and message ~= "" then
			UiToast.Show(message, 3.2)
		end
		return
	end

	if kind == "NeedGroup" or kind == "AlreadyClaimed" or kind == "Error" then
		claiming = false
		if overlay.Visible then
			applySnapshot(payload)
			status.Text = if typeof(message) == "string" then message else ""
			status.TextColor3 = if kind == "AlreadyClaimed" then UiTheme.Colors.TextDim else UiTheme.Colors.AccentRed
		elseif typeof(message) == "string" and message ~= "" then
			FeelSound.Play("Error")
			UiToast.Show(message, 3.4)
		end
		if kind ~= "AlreadyClaimed" then
			FeelSound.Play("Error")
		end
		return
	end
end)
