--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CompanionConfig = require(Modules:WaitForChild("CompanionConfig"))
local PetIconUi = require(Modules:WaitForChild("PetIconUi"))
local PetConfig = require(Modules:WaitForChild("PetConfig"))
local UiTheme = require(Modules:WaitForChild("UiTheme"))
local UiToast = require(Modules:WaitForChild("UiToast"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local openRemote = remotes:WaitForChild("OpenSodaMachine") :: RemoteEvent
local fuseRemote = remotes:WaitForChild("FuseCompanion") :: RemoteEvent
local resultRemote = remotes:WaitForChild("SodaMachineResult") :: RemoteEvent

local selectedPetName: string? = nil
local fuseCount = CompanionConfig.FuseCount

local screenGui = UiTheme.Create("ScreenGui", {
	Name = "SodaMachineGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 9,
}, playerGui) :: ScreenGui
UiTheme.MobileScale(screenGui)

local panel = UiTheme.Panel({
	Name = "SodaMachinePanel",
	Size = UDim2.fromOffset(560, 460),
	Parent = screenGui,
	Visible = false,
})

local _, _close = UiTheme.Header(panel, CompanionConfig.StationDisplayName, function()
	panel.Visible = false
end)

local statusLabel = UiTheme.Label({
	Name = "Status",
	Text = string.format("Feed %d identical unlocked pets to create a companion.", fuseCount),
	Parent = panel,
	Position = UDim2.fromOffset(20, 58),
	Size = UDim2.new(1, -40, 0, 36),
	TextSize = 14,
	Color = UiTheme.Colors.TextDim,
})
statusLabel.TextWrapped = true

local companionLabel = UiTheme.Label({
	Name = "Companion",
	Text = "Companion: none",
	Parent = panel,
	Position = UDim2.fromOffset(20, 96),
	Size = UDim2.new(1, -40, 0, 22),
	TextSize = 15,
	Color = UiTheme.Colors.AccentAmber,
	Font = UiTheme.FontMedium,
})

local listFrame = UiTheme.Create("ScrollingFrame", {
	Name = "PetList",
	BackgroundColor3 = UiTheme.Colors.BgRaised,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(20, 128),
	Size = UDim2.fromOffset(520, 246),
	CanvasSize = UDim2.fromOffset(0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.None,
	ZIndex = 2,
}, panel) :: ScrollingFrame
UiTheme.StyleScrollingFrame(listFrame)
UiTheme.Corner(listFrame, UiTheme.CornerSmall)
UiTheme.Stroke(listFrame, UiTheme.Colors.Stroke, 3, 0)

local listLayout = UiTheme.Create("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, listFrame) :: UIListLayout

UiTheme.EnsureScrollPadding(listFrame)
local refreshCompanionCanvas = UiTheme.BindScrollCanvas(listFrame, listLayout)

local fuseButton = UiTheme.Button({
	Name = "Fuse",
	Text = "Create Companion",
	Parent = panel,
	Size = UDim2.fromOffset(220, 44),
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -18),
	Variant = "green",
	TextSize = 17,
	ZIndex = 3,
})

local rowButtons: { [TextButton]: string } = {}
local stopFusePulse: (() -> ())? = nil

local function clearRows()
	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name == "PetRow" then
			child:Destroy()
		elseif child:IsA("TextLabel") and child.Name == "Empty" then
			child:Destroy()
		end
	end
	table.clear(rowButtons)
end

local function setSelected(petName: string?)
	selectedPetName = petName
	for button, name in pairs(rowButtons) do
		if button.AutoButtonColor then
			button.Text = if name == petName then "Selected" else "Select"
		end
	end

	if stopFusePulse then
		stopFusePulse()
		stopFusePulse = nil
	end

	if typeof(petName) == "string" then
		fuseButton.Text = string.format("Fuse 3× %s", petName)
		fuseButton.AutoButtonColor = true
		fuseButton.BackgroundColor3 = UiTheme.ButtonColor("green")
		stopFusePulse = UiTheme.Pulse(fuseButton, 1.05, 0.9)
	else
		fuseButton.Text = "Select a pet"
		fuseButton.AutoButtonColor = false
		fuseButton.BackgroundColor3 = UiTheme.Colors.BgMuted
	end
end

local function rarityColor(rarity: string): Color3
	return PetConfig.GetRarityColor(rarity)
end

local function applyPayload(payload: any, openPanel: boolean?)
	if typeof(payload) ~= "table" then
		return
	end

	if openPanel then
		panel.Visible = true
		UiTheme.BounceIn(panel, 0.7)
	end

	if typeof(payload.FuseCount) == "number" then
		fuseCount = payload.FuseCount
	end

	local companionName = if typeof(payload.CompanionPetName) == "string" then payload.CompanionPetName else ""
	local companionRarity = if typeof(payload.CompanionRarity) == "string" then payload.CompanionRarity else ""
	local luckMult = if typeof(payload.CompanionLuckMult) == "number" then payload.CompanionLuckMult else 1
	local sellMult = if typeof(payload.CompanionSellMult) == "number" then payload.CompanionSellMult else 1

	if companionName ~= "" then
		companionLabel.Text = string.format(
			"Companion: %s (%s)  ·  luck %.2fx  ·  sell %.2fx",
			companionName,
			companionRarity,
			luckMult,
			sellMult
		)
	else
		companionLabel.Text = "Companion: none"
	end

	statusLabel.Text = string.format(
		"Select a pet with %d+ unlocked copies, then create a companion. Replaces the current one.",
		fuseCount
	)

	clearRows()
	local options = payload.Options
	local layoutOrder = 0
	local firstFuseable: string? = nil

	if typeof(options) == "table" then
		for _, option in ipairs(options) do
			if typeof(option) ~= "table" then
				continue
			end
			local petName = option.PetName
			if typeof(petName) ~= "string" then
				continue
			end

			layoutOrder += 1
			local canFuse = option.CanFuse == true
			local rarity = if typeof(option.Rarity) == "string" then option.Rarity else "Common"
			local icon = if typeof(option.Icon) == "string" then option.Icon else "🐾"
			local unlocked = if typeof(option.UnlockedCount) == "number" then option.UnlockedCount else 0
			local total = if typeof(option.Count) == "number" then option.Count else unlocked
			local optLuck = if typeof(option.LuckMult) == "number" then option.LuckMult else 1
			local optSell = if typeof(option.SellMult) == "number" then option.SellMult else 1

			if canFuse and not firstFuseable then
				firstFuseable = petName
			end

			local row = UiTheme.Row({
				Name = "PetRow",
				Parent = listFrame,
				Size = UDim2.new(1, -8, 0, 72),
				LayoutOrder = layoutOrder,
				ZIndex = 3,
				RarityColor = rarityColor(rarity),
			})

			PetIconUi.Mount(row, {
				PetName = petName,
				Rarity = rarity,
				Icon = icon,
				Size = 56,
				Position = UDim2.fromOffset(8, 8),
				ZIndex = 4,
			})

			UiTheme.Label({
				Name = "Name",
				Text = petName,
				Parent = row,
				Position = UDim2.fromOffset(76, 8),
				Size = UDim2.fromOffset(280, 22),
				TextSize = 18,
				Font = UiTheme.FontTitle,
				Color = UiTheme.Colors.TextDark,
				ZIndex = 4,
			})

			UiTheme.Label({
				Name = "Meta",
				Text = string.format(
					"%s  ·  %d/%d unlocked  ·  buff %.2fx / %.2fx",
					rarity,
					unlocked,
					total,
					optLuck,
					optSell
				),
				Parent = row,
				Position = UDim2.fromOffset(76, 34),
				Size = UDim2.fromOffset(300, 20),
				TextSize = 13,
				Color = UiTheme.Colors.TextDim,
				ZIndex = 4,
			})

			local pick = UiTheme.Button({
				Name = "Pick",
				Text = if canFuse then "Select" else "Need 3",
				Parent = row,
				Size = UDim2.fromOffset(100, 36),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Variant = if canFuse then "blue" else "muted",
				TextSize = 14,
				ZIndex = 5,
			})
			pick.AutoButtonColor = canFuse
			rowButtons[pick] = petName

			if canFuse then
				pick.MouseButton1Click:Connect(function()
					setSelected(petName)
				end)
			end
		end
	end

	if layoutOrder == 0 then
		UiTheme.Label({
			Name = "Empty",
			Text = "No pets in inventory yet.",
			Parent = listFrame,
			Size = UDim2.new(1, -16, 0, 40),
			Position = UDim2.fromOffset(8, 8),
			TextSize = 15,
			Color = UiTheme.Colors.TextDim,
			ZIndex = 3,
		})
	end

	if selectedPetName then
		local stillValid = false
		for _, name in pairs(rowButtons) do
			if name == selectedPetName then
				stillValid = true
				break
			end
		end
		if stillValid then
			setSelected(selectedPetName)
		else
			setSelected(firstFuseable)
		end
	else
		setSelected(firstFuseable)
	end

	refreshCompanionCanvas()
end

fuseButton.MouseButton1Click:Connect(function()
	if typeof(selectedPetName) ~= "string" then
		UiToast.Show("Select a pet with 3 unlocked copies.")
		return
	end
	fuseRemote:FireServer(selectedPetName)
end)

openRemote.OnClientEvent:Connect(function(payload)
	applyPayload(payload, true)
end)

resultRemote.OnClientEvent:Connect(function(payload)
	applyPayload(payload, false)
	if typeof(payload) == "table" and typeof(payload.Message) == "string" and payload.Message ~= "" then
		statusLabel.Text = payload.Message
		UiToast.Show(payload.Message)
	end
end)
