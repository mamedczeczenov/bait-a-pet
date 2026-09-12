--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local NumberFormat = require(Modules:WaitForChild("NumberFormat"))
local UiTheme = require(Modules:WaitForChild("UiTheme"))
local UiToast = require(Modules:WaitForChild("UiToast"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local goalsRemote = remotes:WaitForChild("Goals") :: RemoteEvent

type GoalPayload = {
	Uid: string,
	TemplateId: string,
	Kind: string,
	Title: string,
	Description: string,
	Progress: number,
	Target: number,
	TargetRarity: string?,
	ReadyToClaim: boolean,
	RewardCoins: number,
	BuffCatches: number,
	BuffMult: number,
	Difficulty: string,
}

local rewardsGui = playerGui:WaitForChild("RewardsGui", 15) :: ScreenGui?
if not rewardsGui then
	warn("[GoalClient] RewardsGui missing")
	return
end

local panel = rewardsGui:WaitForChild("Panel") :: Frame
local goalsPage = panel:WaitForChild("GoalsPage") :: Frame

local buffLabel = UiTheme.Create("TextLabel", {
	Name = "Buff",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, 40),
	Size = UDim2.fromOffset(200, 32),
	Text = "No luck buff active.",
	TextColor3 = UiTheme.Colors.TextDim,
	TextSize = 13,
	Font = UiTheme.FontBody,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 22,
}, goalsPage) :: TextLabel

local claimAllButton = UiTheme.Button({
	Name = "ClaimAll",
	Parent = goalsPage,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 6),
	Size = UDim2.fromOffset(110, 32),
	Text = "Claim All",
	TextSize = 13,
	Variant = "green",
	ZIndex = 23,
}) :: TextButton

local statusLabel = UiTheme.Create("TextLabel", {
	Name = "Status",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, 74),
	Size = UDim2.fromOffset(312, 20),
	Text = "",
	TextColor3 = UiTheme.Colors.Warning,
	TextSize = 13,
	Font = UiTheme.FontMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 22,
}, goalsPage) :: TextLabel

local list = UiTheme.Create("ScrollingFrame", {
	Name = "List",
	BackgroundColor3 = UiTheme.Colors.BgRaised,
	Position = UDim2.fromOffset(12, 98),
	Size = UDim2.fromOffset(316, 250),
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromOffset(0, 0),
	ZIndex = 22,
}, goalsPage) :: ScrollingFrame
UiTheme.StyleScrollingFrame(list)
UiTheme.Corner(list, UiTheme.CornerSmall)
UiTheme.Stroke(list, UiTheme.Colors.Stroke, 3, 0)

local listLayout = UiTheme.Create("UIListLayout", {
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, list) :: UIListLayout

UiTheme.EnsureScrollPadding(list)

local currentGoals: { GoalPayload } = {}

local function showToast(message: string)
	UiToast.Show(message, 3.2)
end

local function clearList()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function progressText(goal: GoalPayload): string
	if goal.Kind == "DiscoverRarity" then
		return if goal.ReadyToClaim or goal.Progress >= goal.Target then "Done" else "Not yet"
	end
	return string.format("%d / %d", goal.Progress, goal.Target)
end

local function renderGoals()
	clearList()
	local hasClaim = false

	for order, goal in ipairs(currentGoals) do
		if goal.ReadyToClaim then
			hasClaim = true
		end

		local row = UiTheme.Row({
			Name = goal.Uid,
			Parent = list,
			Size = UDim2.new(1, -8, 0, 112),
			LayoutOrder = order,
			ZIndex = 23,
			RarityColor = if goal.ReadyToClaim then UiTheme.Colors.AccentGreen else nil,
		})

		UiTheme.Label({
			Name = "Title",
			Parent = row,
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.fromOffset(200, 22),
			Text = goal.Title,
			TextSize = 15,
			Font = UiTheme.FontTitle,
			Color = UiTheme.Colors.TextDark,
			ZIndex = 24,
		})

		UiTheme.Create("TextLabel", {
			Name = "Progress",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromOffset(292, 8),
			Size = UDim2.fromOffset(80, 22),
			Text = progressText(goal),
			TextColor3 = if goal.ReadyToClaim then UiTheme.Colors.AccentGreenHot else UiTheme.Colors.TextDim,
			TextSize = 13,
			Font = UiTheme.FontTitle,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 24,
		}, row)

		local desc = UiTheme.Label({
			Name = "Desc",
			Parent = row,
			Position = UDim2.fromOffset(12, 32),
			Size = UDim2.fromOffset(280, 36),
			Text = goal.Description,
			Color = UiTheme.Colors.TextDim,
			TextSize = 12,
			ZIndex = 24,
		})
		desc.TextWrapped = true

		UiTheme.Label({
			Name = "Reward",
			Parent = row,
			Position = UDim2.fromOffset(12, 70),
			Size = UDim2.fromOffset(170, 32),
			Text = string.format(
				"+%s$ · +%.0f%% luck x%d",
				NumberFormat.FormatCoins(goal.RewardCoins),
				(goal.BuffMult - 1) * 100,
				goal.BuffCatches
			),
			Color = UiTheme.Colors.AccentAmber,
			TextSize = 12,
			Font = UiTheme.FontMedium,
			ZIndex = 24,
		})

		local claimButton = UiTheme.Button({
			Name = "Claim",
			Parent = row,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromOffset(292, 100),
			Size = UDim2.fromOffset(96, 32),
			Text = if goal.ReadyToClaim then "Claim" else "In progress",
			TextSize = 12,
			Variant = if goal.ReadyToClaim then "green" else "muted",
			ZIndex = 25,
		}) :: TextButton
		claimButton.AutoButtonColor = goal.ReadyToClaim
		claimButton.Active = goal.ReadyToClaim

		if goal.ReadyToClaim then
			UiTheme.Pulse(claimButton, 1.06, 0.85)
			local uid = goal.Uid
			claimButton.MouseButton1Click:Connect(function()
				goalsRemote:FireServer({ Type = "Claim", Uid = uid })
			end)
		end
	end

	rewardsGui:SetAttribute("GoalsClaimReady", hasClaim)
	claimAllButton.Active = hasClaim
	claimAllButton.AutoButtonColor = hasClaim
	claimAllButton.TextTransparency = if hasClaim then 0 else 0.4
	claimAllButton.BackgroundTransparency = if hasClaim then 0 else 0.25
	UiTheme.SetScrollCanvas(list, listLayout.AbsoluteContentSize.Y)
end

listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	UiTheme.SetScrollCanvas(list, listLayout.AbsoluteContentSize.Y)
end)

claimAllButton.MouseButton1Click:Connect(function()
	local anyReady = false
	for _, goal in ipairs(currentGoals) do
		if goal.ReadyToClaim then
			anyReady = true
			break
		end
	end
	if not anyReady then
		return
	end
	goalsRemote:FireServer({ Type = "ClaimAll" })
end)

local function applyPayload(payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	if typeof(payload.Goals) == "table" then
		currentGoals = payload.Goals
		renderGoals()
	end

	local catches = if typeof(payload.LuckBuffCatches) == "number" then payload.LuckBuffCatches else 0
	local mult = if typeof(payload.LuckBuffMult) == "number" then payload.LuckBuffMult else 1
	if catches > 0 and mult > 1 then
		buffLabel.Text = string.format("Luck buff: +%.0f%% for %d more catches.", (mult - 1) * 100, catches)
		buffLabel.TextColor3 = UiTheme.Colors.Success
	else
		buffLabel.Text = "No luck buff active."
		buffLabel.TextColor3 = UiTheme.Colors.TextDim
	end

	if typeof(payload.Message) == "string" and payload.Message ~= "" then
		statusLabel.Text = payload.Message
		if payload.IntroHint == true then
			showToast(payload.Message)
			rewardsGui:SetAttribute("RequestOpenTab", "Goals")
		end
	end
end

local function maybeReady()
	if panel.Visible and goalsPage.Visible then
		goalsRemote:FireServer({ Type = "Ready" })
	end
end

panel:GetPropertyChangedSignal("Visible"):Connect(maybeReady)
goalsPage:GetPropertyChangedSignal("Visible"):Connect(maybeReady)
rewardsGui:GetAttributeChangedSignal("OpenRequest"):Connect(maybeReady)

goalsRemote.OnClientEvent:Connect(applyPayload)

task.defer(function()
	goalsRemote:FireServer({ Type = "Ready" })
end)

localPlayer:GetAttributeChangedSignal("LuckBuffCatches"):Connect(function()
	local catches = localPlayer:GetAttribute("LuckBuffCatches")
	local mult = localPlayer:GetAttribute("LuckBuffMult")
	if typeof(catches) == "number" and catches > 0 and typeof(mult) == "number" and mult > 1 then
		buffLabel.Text = string.format("Luck buff: +%.0f%% for %d more catches.", (mult - 1) * 100, catches)
		buffLabel.TextColor3 = UiTheme.Colors.Success
	else
		buffLabel.Text = "No luck buff active."
		buffLabel.TextColor3 = UiTheme.Colors.TextDim
	end
end)
