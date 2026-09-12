--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local IndexRewardConfig = require(Modules:WaitForChild("IndexRewardConfig"))
local NumberFormat = require(Modules:WaitForChild("NumberFormat"))
local PetConfig = require(Modules:WaitForChild("PetConfig"))
local PetIconUi = require(Modules:WaitForChild("PetIconUi"))
local UiIcon = require(Modules:WaitForChild("UiIcon"))
local UiTheme = require(Modules:WaitForChild("UiTheme"))
local UiToast = require(Modules:WaitForChild("UiToast"))
local PlaceConfig = require(Modules:WaitForChild("PlaceConfig"))
PetConfig.EnsureLoaded(30)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local indexRemote = remotes:WaitForChild("Index") :: RemoteEvent

local INDEX_BLUE = Color3.fromRGB(80, 160, 255)
local INDEX_BLUE_HOT = Color3.fromRGB(50, 130, 240)
local HUD_CHIP_HEIGHT = 56
local HUD_CHIP_GAP = 14
local GRID_CELL_W = 168
local GRID_CELL_H = 74
local GRID_GAP = 8
local GRID_COLS = 2

type PetEntry = {
	Name: string,
	Rarity: string,
	OneIn: number,
	Icon: string,
	Discovered: boolean,
	Claimed: boolean,
	RewardCoins: number,
	CanClaim: boolean,
}

type MilestoneEntry = {
	Id: string,
	Kind: string,
	Label: string,
	RewardCoins: number,
	Progress: number,
	Target: number,
	Ready: boolean,
	Claimed: boolean,
	CanClaim: boolean,
}

local discoveredSet: { [string]: boolean } = {}
local claimedSet: { [string]: boolean } = {}
local claimedMilestoneSet: { [string]: boolean } = {}
local serverPets: { PetEntry }? = nil
local serverMilestones: { MilestoneEntry }? = nil
local hasUnclaimed = false
local completionPercent = 0
local discoveredCount = 0
local totalPets = 0

local function create(className: string, props: { [string]: any }, parent: Instance?): Instance
	return UiTheme.Create(className, props, parent)
end

local function rebuildFolderSets()
	discoveredSet = {}
	claimedSet = {}
	claimedMilestoneSet = {}

	local discoveredFolder = localPlayer:FindFirstChild("DiscoveredPets")
	if discoveredFolder and discoveredFolder:IsA("Folder") then
		for _, child in ipairs(discoveredFolder:GetChildren()) do
			if child:IsA("BoolValue") then
				discoveredSet[child.Name] = true
			end
		end
	end

	local claimedFolder = localPlayer:FindFirstChild("ClaimedIndexPets")
	if claimedFolder and claimedFolder:IsA("Folder") then
		for _, child in ipairs(claimedFolder:GetChildren()) do
			if child:IsA("BoolValue") then
				claimedSet[child.Name] = true
			end
		end
	end

	local milestoneFolder = localPlayer:FindFirstChild("ClaimedIndexMilestones")
	if milestoneFolder and milestoneFolder:IsA("Folder") then
		for _, child in ipairs(milestoneFolder:GetChildren()) do
			if child:IsA("BoolValue") then
				claimedMilestoneSet[child.Name] = true
			end
		end
	end

	if serverPets then
		for _, entry in ipairs(serverPets) do
			if typeof(entry.Name) == "string" and entry.Name ~= "" then
				if entry.Discovered == true then
					discoveredSet[entry.Name] = true
				end
				if entry.Claimed == true then
					claimedSet[entry.Name] = true
				end
			end
		end
	end

	if serverMilestones then
		for _, entry in ipairs(serverMilestones) do
			if typeof(entry.Id) == "string" and entry.Id ~= "" and entry.Claimed == true then
				claimedMilestoneSet[entry.Id] = true
			end
		end
	end
end

local function computeStats()
	totalPets = #PetConfig.Pets
	discoveredCount = 0
	hasUnclaimed = false

	for _, pet in ipairs(PetConfig.Pets) do
		if discoveredSet[pet.Name] then
			discoveredCount += 1
			if not claimedSet[pet.Name] then
				hasUnclaimed = true
			end
		end
	end

	if totalPets > 0 then
		completionPercent = math.floor((discoveredCount / totalPets) * 100 + 0.5)
	else
		completionPercent = 0
	end

	if not hasUnclaimed then
		for _, def in ipairs(IndexRewardConfig.GetPercentMilestones()) do
			local target = if typeof(def.Target) == "number" then def.Target else 0
			if completionPercent >= target and not claimedMilestoneSet[def.Id] then
				hasUnclaimed = true
				break
			end
		end
	end

	if not hasUnclaimed then
		for _, def in ipairs(IndexRewardConfig.GetRarityMilestones()) do
			local rarity = if typeof(def.Target) == "string" then def.Target else ""
			local progress = 0
			local target = 0
			for _, pet in ipairs(PetConfig.Pets) do
				if pet.Rarity == rarity then
					target += 1
					if discoveredSet[pet.Name] then
						progress += 1
					end
				end
			end
			if target > 0 and progress >= target and not claimedMilestoneSet[def.Id] then
				hasUnclaimed = true
				break
			end
		end
	end
end

local function getLocalMilestones(): { MilestoneEntry }
	if serverMilestones then
		return serverMilestones
	end

	local milestones: { MilestoneEntry } = {}
	for _, def in ipairs(IndexRewardConfig.GetPercentMilestones()) do
		local target = if typeof(def.Target) == "number" then def.Target else 0
		local ready = completionPercent >= target
		local claimed = claimedMilestoneSet[def.Id] == true
		table.insert(milestones, {
			Id = def.Id,
			Kind = def.Kind,
			Label = def.Label,
			RewardCoins = def.RewardCoins,
			Progress = math.min(completionPercent, target),
			Target = target,
			Ready = ready,
			Claimed = claimed,
			CanClaim = ready and not claimed,
		})
	end

	for _, def in ipairs(IndexRewardConfig.GetRarityMilestones()) do
		local rarity = if typeof(def.Target) == "string" then def.Target else ""
		local progress = 0
		local target = 0
		for _, pet in ipairs(PetConfig.Pets) do
			if pet.Rarity == rarity then
				target += 1
				if discoveredSet[pet.Name] then
					progress += 1
				end
			end
		end
		if target <= 0 then
			continue
		end
		local ready = progress >= target
		local claimed = claimedMilestoneSet[def.Id] == true
		table.insert(milestones, {
			Id = def.Id,
			Kind = def.Kind,
			Label = def.Label,
			RewardCoins = def.RewardCoins,
			Progress = progress,
			Target = target,
			Ready = ready,
			Claimed = claimed,
			CanClaim = ready and not claimed,
		})
	end

	return milestones
end

local screenGui = create("ScreenGui", {
	Name = "IndexGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 20,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui) :: ScreenGui
UiTheme.MobileScale(screenGui)
if PlaceConfig.IsAfkPlace() then
	screenGui.Enabled = false
end

local indexHudButton = create("TextButton", {
	Name = "IndexHud",
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.fromOffset(0, 140 + HUD_CHIP_HEIGHT + HUD_CHIP_GAP),
	Size = UDim2.fromOffset(158, HUD_CHIP_HEIGHT),
	BackgroundColor3 = INDEX_BLUE,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 2,
}, screenGui) :: TextButton
UiTheme.Corner(indexHudButton, UiTheme.CornerChip)
UiTheme.Stroke(indexHudButton, UiTheme.Colors.Stroke, 4, 0)
UiTheme.Gradient(indexHudButton, Color3.fromRGB(140, 200, 255), INDEX_BLUE_HOT, 90)
UiTheme.WireButtonMotion(indexHudButton)

UiIcon.Mount(indexHudButton, {
	Key = "hud_index",
	Name = "Icon",
	Position = UDim2.fromOffset(4, 4),
	Size = UDim2.fromOffset(48, 48),
	ImageSize = 34,
})

local percentLabel = create("TextLabel", {
	Name = "Percent",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(52, 10),
	Size = UDim2.fromOffset(100, 36),
	Text = "0%",
	TextColor3 = UiTheme.Colors.Text,
	TextSize = 26,
	Font = UiTheme.FontTitle,
	TextXAlignment = Enum.TextXAlignment.Left,
}, indexHudButton) :: TextLabel
UiTheme.TextStroke(percentLabel, 2.6)

local claimDot = create("Frame", {
	Name = "ClaimDot",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -4, 0, 4),
	Size = UDim2.fromOffset(12, 12),
	BackgroundColor3 = UiTheme.Colors.Success,
	Visible = false,
	ZIndex = 3,
}, indexHudButton) :: Frame
UiTheme.Corner(claimDot, UDim.new(1, 0))
UiTheme.Stroke(claimDot, UiTheme.Colors.Stroke, 2, 0)
UiTheme.Pulse(claimDot, 1.25, 0.7)

local function mountHudButton()
	local shopGui = playerGui:WaitForChild("ShopGui", 15)
	if not shopGui then
		indexHudButton.AnchorPoint = Vector2.new(0, 0.5)
		indexHudButton.Position = UDim2.new(0, 18, 0.5, 63)
		return
	end

	local root = shopGui:WaitForChild("Root")
	local hudStack = root:WaitForChild("HudStack") :: Frame
	indexHudButton.Parent = hudStack
	indexHudButton.AnchorPoint = Vector2.new(0, 0)
	indexHudButton.Position = UDim2.fromOffset(0, 140 + HUD_CHIP_HEIGHT + HUD_CHIP_GAP)
	hudStack.Size = UDim2.fromOffset(158, 140 + HUD_CHIP_HEIGHT + HUD_CHIP_GAP + HUD_CHIP_HEIGHT)
end

task.defer(mountHudButton)

local panel = UiTheme.Panel({
	Name = "Panel",
	Parent = screenGui,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 190, 0.5, 0),
	Size = UDim2.fromOffset(420, 520),
	Visible = false,
	ZIndex = 10,
})

local headerBar = panel:FindFirstChild("HeaderBar")
if headerBar and headerBar:IsA("Frame") then
	headerBar.BackgroundColor3 = INDEX_BLUE
	UiTheme.Gradient(headerBar, Color3.fromRGB(140, 200, 255), INDEX_BLUE_HOT, 90)
end

UiTheme.Label({
	Name = "Title",
	Parent = panel,
	Position = UDim2.fromOffset(16, 12),
	Size = UDim2.fromOffset(180, 32),
	Text = "Pet Index",
	TextSize = 22,
	Font = UiTheme.FontTitle,
	Color = UiTheme.Colors.Text,
	Outlined = true,
	ZIndex = 11,
})

local claimAllButton = UiTheme.Button({
	Name = "ClaimAll",
	Parent = panel,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -56, 0, 10),
	Size = UDim2.fromOffset(96, 36),
	Text = "Claim All",
	TextSize = 13,
	Variant = "green",
	ZIndex = 11,
}) :: TextButton

local closeButton = UiTheme.Button({
	Name = "Close",
	Parent = panel,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 10),
	Size = UDim2.fromOffset(36, 36),
	Text = "",
	TextSize = 18,
	Variant = "danger",
	ZIndex = 11,
}) :: TextButton
UiIcon.ApplyToButton(closeButton, "btn_close", 22)

local progressTrack = create("Frame", {
	Name = "ProgressTrack",
	Position = UDim2.fromOffset(16, 64),
	Size = UDim2.fromOffset(388, 18),
	BackgroundColor3 = UiTheme.Colors.BgRaised,
	BorderSizePixel = 0,
	ZIndex = 11,
}, panel) :: Frame
UiTheme.Corner(progressTrack, UiTheme.CornerSmall)
UiTheme.Stroke(progressTrack, UiTheme.Colors.Stroke, 3, 0)

local progressFill = create("Frame", {
	Name = "ProgressFill",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 0, 0.5, 0),
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = INDEX_BLUE,
	BorderSizePixel = 0,
	ZIndex = 12,
}, progressTrack) :: Frame
UiTheme.Corner(progressFill, UiTheme.CornerSmall)
UiTheme.Gradient(progressFill, Color3.fromRGB(140, 200, 255), INDEX_BLUE_HOT, 0)

local progressText = create("TextLabel", {
	Name = "ProgressText",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 86),
	Size = UDim2.fromOffset(260, 20),
	Text = "0 / 0 discovered",
	TextColor3 = UiTheme.Colors.TextDark,
	TextSize = 13,
	Font = UiTheme.FontMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 11,
}, panel) :: TextLabel

local progressPercent = create("TextLabel", {
	Name = "ProgressPercent",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 86),
	Size = UDim2.fromOffset(80, 20),
	Text = "0%",
	TextColor3 = INDEX_BLUE_HOT,
	TextSize = 13,
	Font = UiTheme.FontTitle,
	TextXAlignment = Enum.TextXAlignment.Right,
	ZIndex = 11,
}, panel) :: TextLabel

local statusLabel = create("TextLabel", {
	Name = "Status",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 108),
	Size = UDim2.fromOffset(388, 18),
	Text = "",
	TextColor3 = UiTheme.Colors.AccentAmber,
	TextSize = 12,
	Font = UiTheme.FontMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 11,
}, panel) :: TextLabel

local list = create("ScrollingFrame", {
	Name = "List",
	BackgroundColor3 = UiTheme.Colors.BgRaised,
	Position = UDim2.fromOffset(12, 132),
	Size = UDim2.fromOffset(396, 376),
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromOffset(0, 0),
	ZIndex = 11,
}, panel) :: ScrollingFrame
UiTheme.StyleScrollingFrame(list)
UiTheme.Corner(list, UiTheme.CornerSmall)
UiTheme.Stroke(list, UiTheme.Colors.Stroke, 3, 0)

local listLayout = create("UIListLayout", {
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, list) :: UIListLayout

UiTheme.EnsureScrollPadding(list)

local function gridHeightForCount(count: number): number
	if count <= 0 then
		return 0
	end
	local rows = math.ceil(count / GRID_COLS)
	return rows * GRID_CELL_H + math.max(0, rows - 1) * GRID_GAP
end

local function computeListContentHeight(): number
	local gap = listLayout.Padding.Offset
	local frames: { Frame } = {}
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(frames, child)
		end
	end
	table.sort(frames, function(a: Frame, b: Frame)
		return a.LayoutOrder < b.LayoutOrder
	end)

	local height = 0
	for index, frame in ipairs(frames) do
		local sectionHeight = frame.Size.Y.Offset
		if string.sub(frame.Name, 1, 5) == "Grid_" then
			local petCount = frame:GetAttribute("PetCount")
			if typeof(petCount) == "number" then
				sectionHeight = gridHeightForCount(petCount)
			end
		elseif string.sub(frame.Name, 1, 7) == "Header_" then
			sectionHeight = 30
		elseif string.sub(frame.Name, 1, 10) == "Milestone_" then
			sectionHeight = 52
		end
		height += sectionHeight
		if index < #frames then
			height += gap
		end
	end

	return height
end

local canvasGeneration = 0

local function refreshCanvasSize()
	canvasGeneration += 1
	local generation = canvasGeneration
	task.defer(function()
		if generation ~= canvasGeneration then
			return
		end
		RunService.Heartbeat:Wait()
		if generation ~= canvasGeneration then
			return
		end
		UiTheme.SetScrollCanvas(list, computeListContentHeight())
	end)
end

local renderQueued = false

local function getPetEntry(pet: PetConfig.PetDefinition): PetEntry
	local discovered = discoveredSet[pet.Name] == true
	local claimed = claimedSet[pet.Name] == true
	local reward = IndexRewardConfig.GetReward(pet.Rarity)
	local icon = pet.Icon
	local oneIn = pet.OneIn
	local rarity = pet.Rarity

	if serverPets then
		for _, entry in ipairs(serverPets) do
			if entry.Name == pet.Name then
				if entry.Discovered == true then
					discovered = true
				end
				if entry.Claimed == true then
					claimed = true
				end
				if typeof(entry.RewardCoins) == "number" then
					reward = entry.RewardCoins
				end
				if typeof(entry.Icon) == "string" and entry.Icon ~= "" then
					icon = entry.Icon
				end
				if typeof(entry.OneIn) == "number" then
					oneIn = entry.OneIn
				end
				if typeof(entry.Rarity) == "string" and entry.Rarity ~= "" then
					rarity = entry.Rarity
				end
				break
			end
		end
	end

	return {
		Name = pet.Name,
		Rarity = rarity,
		OneIn = oneIn,
		Icon = icon,
		Discovered = discovered,
		Claimed = claimed,
		RewardCoins = reward,
		CanClaim = discovered and not claimed,
	}
end

local function clearList()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function updateHudStats()
	percentLabel.Text = string.format("%d%%", completionPercent)
	claimDot.Visible = hasUnclaimed
	progressFill.Size = UDim2.new(completionPercent / 100, 0, 1, 0)
	progressText.Text = string.format("%d / %d discovered", discoveredCount, math.max(totalPets, 0))
	progressPercent.Text = string.format("%d%%", completionPercent)
	claimAllButton.Active = hasUnclaimed
	claimAllButton.AutoButtonColor = hasUnclaimed
	claimAllButton.TextTransparency = if hasUnclaimed then 0 else 0.4
	claimAllButton.BackgroundTransparency = if hasUnclaimed then 0 else 0.25
end

local function renderIndex()
	clearList()
	local layoutOrder = 0

	for _, rarity in ipairs(PetConfig.RarityOrder) do
		local rarityPets: { PetConfig.PetDefinition } = {}
		for _, pet in ipairs(PetConfig.Pets) do
			if pet.Rarity == rarity then
				table.insert(rarityPets, pet)
			end
		end
		if #rarityPets == 0 then
			continue
		end

		local rarityDiscovered = 0
		for _, pet in ipairs(rarityPets) do
			if discoveredSet[pet.Name] then
				rarityDiscovered += 1
			end
		end

		layoutOrder += 1
		local rarityColor = PetConfig.GetRarityColor(rarity)
		local header = UiTheme.Row({
			Name = string.format("Header_%s", rarity),
			Parent = list,
			Size = UDim2.new(1, -16, 0, 30),
			LayoutOrder = layoutOrder,
			ZIndex = 12,
			RarityColor = rarityColor,
		})

		create("TextLabel", {
			Name = "Label",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.fromOffset(340, 22),
			Text = string.format("%s  %d / %d", string.upper(rarity), rarityDiscovered, #rarityPets),
			TextColor3 = UiTheme.Colors.TextDark,
			TextSize = 14,
			Font = UiTheme.FontTitle,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 13,
		}, header)

		layoutOrder += 1
		local gridHeight = gridHeightForCount(#rarityPets)
		local gridHost = create("Frame", {
			Name = string.format("Grid_%s", rarity),
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -16, 0, gridHeight),
			ClipsDescendants = true,
			LayoutOrder = layoutOrder,
			ZIndex = 12,
		}, list) :: Frame
		gridHost:SetAttribute("PetCount", #rarityPets)

		create("UIGridLayout", {
			CellPadding = UDim2.fromOffset(GRID_GAP, GRID_GAP),
			CellSize = UDim2.fromOffset(GRID_CELL_W, GRID_CELL_H),
			FillDirection = Enum.FillDirection.Horizontal,
			FillDirectionMaxCells = GRID_COLS,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, gridHost)

		for petOrder, pet in ipairs(rarityPets) do
			local entry = getPetEntry(pet)
			local card = UiTheme.Row({
				Name = pet.Name,
				Parent = gridHost,
				Size = UDim2.fromOffset(GRID_CELL_W, GRID_CELL_H),
				LayoutOrder = petOrder,
				ZIndex = 12,
				RarityColor = if entry.Discovered then rarityColor else nil,
			})
			card.ClipsDescendants = true

			if not entry.Discovered then
				card.BackgroundColor3 = UiTheme.Colors.BgMuted
			end

			local iconHost = create("Frame", {
				Name = "IconHost",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(6, 8),
				Size = UDim2.fromOffset(44, 44),
				ZIndex = 13,
			}, card) :: Frame

			PetIconUi.Mount(iconHost, {
				PetName = pet.Name,
				Rarity = pet.Rarity,
				Icon = pet.Icon,
				Size = 44,
				Locked = not entry.Discovered,
				Pulse = false,
				ZIndex = 13,
			})

			local nameText = if entry.Discovered then pet.Name else "???"
			local subText = if entry.Discovered
				then string.format("1/%s", PetConfig.FormatOneIn(pet.OneIn))
				else "Not found"

			create("TextLabel", {
				Name = "Name",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(54, 8),
				Size = UDim2.fromOffset(120, 18),
				Text = nameText,
				TextColor3 = UiTheme.Colors.TextDark,
				TextSize = 13,
				Font = UiTheme.FontTitle,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 13,
			}, card)

			create("TextLabel", {
				Name = "Sub",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(54, 26),
				Size = UDim2.fromOffset(120, 16),
				Text = subText,
				TextColor3 = UiTheme.Colors.TextDim,
				TextSize = 11,
				Font = UiTheme.FontMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 13,
			}, card)

			if entry.Discovered then
				if entry.CanClaim then
					local claimButton = UiTheme.Button({
						Name = "Claim",
						Parent = card,
						AnchorPoint = Vector2.new(1, 1),
						Position = UDim2.new(1, -6, 1, -6),
						Size = UDim2.fromOffset(72, 24),
						Text = string.format("+%s$", NumberFormat.FormatCoins(entry.RewardCoins)),
						TextSize = 10,
						Variant = "green",
						ZIndex = 14,
					}) :: TextButton
					UiTheme.Pulse(claimButton, 1.05, 0.85)
					local petName = pet.Name
					claimButton.MouseButton1Click:Connect(function()
						indexRemote:FireServer({ Type = "Claim", PetName = petName })
					end)
				elseif entry.Claimed then
					create("TextLabel", {
						Name = "Claimed",
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(1, 1),
						Position = UDim2.new(1, -6, 1, -6),
						Size = UDim2.fromOffset(72, 24),
						Text = "Claimed",
						TextColor3 = UiTheme.Colors.TextMuted,
						TextSize = 11,
						Font = UiTheme.FontMedium,
						TextXAlignment = Enum.TextXAlignment.Right,
						ZIndex = 14,
					}, card)
				end
			end
		end
	end

	local milestones = getLocalMilestones()
	if #milestones > 0 then
		layoutOrder += 1
		local milestoneHeader = UiTheme.Row({
			Name = "Header_Milestones",
			Parent = list,
			Size = UDim2.new(1, -16, 0, 30),
			LayoutOrder = layoutOrder,
			ZIndex = 12,
			RarityColor = INDEX_BLUE,
		})

		create("TextLabel", {
			Name = "Label",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.fromOffset(340, 22),
			Text = "MILESTONES",
			TextColor3 = UiTheme.Colors.TextDark,
			TextSize = 14,
			Font = UiTheme.FontTitle,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 13,
		}, milestoneHeader)

		for _, milestone in ipairs(milestones) do
			layoutOrder += 1
			local row = UiTheme.Row({
				Name = "Milestone_" .. milestone.Id,
				Parent = list,
				Size = UDim2.new(1, -16, 0, 52),
				LayoutOrder = layoutOrder,
				ZIndex = 12,
			})

			local progressLabel = if milestone.Kind == "percent"
				then string.format("%d%% / %d%%", milestone.Progress, milestone.Target)
				else string.format("%d / %d", milestone.Progress, milestone.Target)

			create("TextLabel", {
				Name = "Label",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(10, 6),
				Size = UDim2.fromOffset(220, 20),
				Text = milestone.Label,
				TextColor3 = UiTheme.Colors.TextDark,
				TextSize = 13,
				Font = UiTheme.FontTitle,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 13,
			}, row)

			create("TextLabel", {
				Name = "Progress",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(10, 28),
				Size = UDim2.fromOffset(220, 16),
				Text = progressLabel,
				TextColor3 = UiTheme.Colors.TextDim,
				TextSize = 11,
				Font = UiTheme.FontMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 13,
			}, row)

			if milestone.CanClaim then
				local claimButton = UiTheme.Button({
					Name = "Claim",
					Parent = row,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.fromOffset(88, 28),
					Text = string.format("+%s$", NumberFormat.FormatCoins(milestone.RewardCoins)),
					TextSize = 11,
					Variant = "green",
					ZIndex = 14,
				}) :: TextButton
				UiTheme.Pulse(claimButton, 1.05, 0.85)
				local milestoneId = milestone.Id
				claimButton.MouseButton1Click:Connect(function()
					indexRemote:FireServer({ Type = "ClaimMilestone", MilestoneId = milestoneId })
				end)
			elseif milestone.Claimed then
				create("TextLabel", {
					Name = "Claimed",
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.fromOffset(88, 28),
					Text = "Claimed",
					TextColor3 = UiTheme.Colors.TextMuted,
					TextSize = 12,
					Font = UiTheme.FontMedium,
					TextXAlignment = Enum.TextXAlignment.Right,
					ZIndex = 14,
				}, row)
			else
				create("TextLabel", {
					Name = "Locked",
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.fromOffset(88, 28),
					Text = string.format("+%s$", NumberFormat.FormatCoins(milestone.RewardCoins)),
					TextColor3 = UiTheme.Colors.TextMuted,
					TextSize = 11,
					Font = UiTheme.FontMedium,
					TextXAlignment = Enum.TextXAlignment.Right,
					ZIndex = 14,
				}, row)
			end
		end
	end

	UiTheme.SetScrollCanvas(list, computeListContentHeight())
	refreshCanvasSize()
end

local function scheduleRender()
	if renderQueued then
		return
	end
	renderQueued = true
	task.defer(function()
		renderQueued = false
		rebuildFolderSets()
		computeStats()
		updateHudStats()
		if panel.Visible then
			renderIndex()
		end
	end)
end

local function setOpen(open: boolean)
	panel.Visible = open
	if open then
		scheduleRender()
		UiTheme.BounceIn(panel, 0.65)
		indexRemote:FireServer({ Type = "Ready" })
	end
end

local function applySnapshot(payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	local petsPayload = payload.Pets
	local snapshotHasPets = typeof(petsPayload) == "table" and #petsPayload > 0
	if typeof(petsPayload) == "table" then
		if snapshotHasPets or #PetConfig.Pets == 0 then
			serverPets = petsPayload
		end
	end
	if typeof(payload.Milestones) == "table" and #(payload.Milestones :: { any }) > 0 then
		serverMilestones = payload.Milestones
	end

	if typeof(payload.Message) == "string" and payload.Message ~= "" then
		statusLabel.Text = payload.Message
		UiToast.Show(payload.Message, 3)
	end

	scheduleRender()
end

indexHudButton.MouseButton1Click:Connect(function()
	setOpen(not panel.Visible)
end)

claimAllButton.MouseButton1Click:Connect(function()
	if not hasUnclaimed then
		return
	end
	indexRemote:FireServer({ Type = "ClaimAll" })
end)

closeButton.MouseButton1Click:Connect(function()
	setOpen(false)
end)

indexRemote.OnClientEvent:Connect(applySnapshot)

local function bindFolder(folder: Instance?)
	if not folder or not folder:IsA("Folder") then
		return
	end
	folder.ChildAdded:Connect(scheduleRender)
	folder.ChildRemoved:Connect(scheduleRender)
end

local function onPlayerChildAdded(child: Instance)
	if child.Name == "DiscoveredPets"
		or child.Name == "ClaimedIndexPets"
		or child.Name == "ClaimedIndexMilestones"
	then
		bindFolder(child)
		scheduleRender()
	end
end

localPlayer.ChildAdded:Connect(onPlayerChildAdded)
bindFolder(localPlayer:FindFirstChild("DiscoveredPets") :: Folder?)
bindFolder(localPlayer:FindFirstChild("ClaimedIndexPets") :: Folder?)
bindFolder(localPlayer:FindFirstChild("ClaimedIndexMilestones") :: Folder?)

scheduleRender()

task.defer(function()
	indexRemote:FireServer({ Type = "Ready" })
end)
