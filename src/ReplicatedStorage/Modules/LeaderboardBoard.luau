--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local LeaderboardConfig = require(Modules:WaitForChild("LeaderboardConfig"))
local NumberFormat = require(Modules:WaitForChild("NumberFormat"))
local UiTheme = require(Modules:WaitForChild("UiTheme"))

local LeaderboardBoard = {}

export type Entry = {
	Rank: number,
	UserId: number,
	Name: string,
	DisplayName: string,
	Value: number,
}

local RANK_COLORS = {
	Color3.fromRGB(255, 210, 50),
	Color3.fromRGB(210, 220, 235),
	Color3.fromRGB(230, 150, 70),
}

local KIND_TITLE = {
	playtime = "PLAYTIME",
	cash = "CASH",
}

local KIND_HEADER = {
	playtime = Color3.fromRGB(90, 200, 255),
	cash = Color3.fromRGB(255, 200, 50),
}

local function formatValue(kind: LeaderboardConfig.BoardKind, value: number): string
	if kind == "playtime" then
		return NumberFormat.FormatDuration(value)
	end
	return NumberFormat.FormatCoins(value) .. "$"
end

local function makeRow(parent: Frame, order: number): Frame
	local row = UiTheme.Create("Frame", {
		Name = string.format("Row%d", order),
		BackgroundColor3 = UiTheme.Colors.BgRow,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0.092, 0),
		LayoutOrder = order,
		ZIndex = 3,
	}, parent) :: Frame
	UiTheme.Corner(row, UDim.new(0, 10))
	UiTheme.Stroke(row, UiTheme.Colors.Stroke, 2.4, 0)

	local rank = UiTheme.Create("TextLabel", {
		Name = "Rank",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.02, 0),
		Size = UDim2.fromScale(0.1, 1),
		Text = tostring(order),
		TextColor3 = UiTheme.Colors.TextDark,
		TextScaled = true,
		Font = UiTheme.FontTitle,
		ZIndex = 4,
	}, row) :: TextLabel
	local rankConstraint = Instance.new("UITextSizeConstraint")
	rankConstraint.MaxTextSize = 28
	rankConstraint.Parent = rank

	local avatar = UiTheme.Create("ImageLabel", {
		Name = "Avatar",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.14, 0.12),
		Size = UDim2.fromScale(0.12, 0.76),
		Image = "",
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 4,
	}, row) :: ImageLabel
	UiTheme.Corner(avatar, UDim.new(1, 0))
	UiTheme.Stroke(avatar, UiTheme.Colors.Stroke, 2, 0)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = avatar

	local nameLabel = UiTheme.Create("TextLabel", {
		Name = "PlayerName",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.3, 0.08),
		Size = UDim2.fromScale(0.38, 0.84),
		Text = "---",
		TextColor3 = UiTheme.Colors.TextDark,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = UiTheme.FontTitle,
		ZIndex = 4,
	}, row) :: TextLabel
	local nameConstraint = Instance.new("UITextSizeConstraint")
	nameConstraint.MaxTextSize = 22
	nameConstraint.Parent = nameLabel

	local valueLabel = UiTheme.Create("TextLabel", {
		Name = "Value",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.68, 0.08),
		Size = UDim2.fromScale(0.3, 0.84),
		Text = "---",
		TextColor3 = UiTheme.Colors.TextDark,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = UiTheme.FontBody,
		ZIndex = 4,
	}, row) :: TextLabel
	local valueConstraint = Instance.new("UITextSizeConstraint")
	valueConstraint.MaxTextSize = 22
	valueConstraint.Parent = valueLabel

	return row
end

local function buildGui(part: BasePart, face: Enum.NormalId, kind: LeaderboardConfig.BoardKind): SurfaceGui
	local guiName = LeaderboardConfig.GuiNamePrefix .. tostring(face)
	local existing = part:FindFirstChild(guiName)
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("SurfaceGui")
	gui.Name = guiName
	gui.Face = face
	gui.ResetOnSpawn = false
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.MaxDistance = LeaderboardConfig.MaxDistance
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = LeaderboardConfig.CanvasSize
	gui.PixelsPerStud = 50
	gui.ZOffset = 0.05
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ClipsDescendants = true
	gui.Active = false
	gui.Parent = part

	local root = UiTheme.Create("Frame", {
		Name = "Root",
		BackgroundColor3 = UiTheme.Colors.BgPanel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, gui) :: Frame
	UiTheme.Corner(root, UDim.new(0, 18))
	UiTheme.Stroke(root, UiTheme.Colors.Stroke, 5, 0)
	UiTheme.Pad(root, 12)

	local header = UiTheme.Create("Frame", {
		Name = "Header",
		BackgroundColor3 = KIND_HEADER[kind],
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0.13, 0),
		ZIndex = 2,
	}, root) :: Frame
	UiTheme.Corner(header, UDim.new(0, 14))
	UiTheme.Stroke(header, UiTheme.Colors.Stroke, 3, 0)
	UiTheme.Gradient(
		header,
		KIND_HEADER[kind],
		KIND_HEADER[kind]:Lerp(Color3.fromRGB(40, 90, 160), 0.35),
		90
	)

	local title = UiTheme.Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.04, 0.08),
		Size = UDim2.fromScale(0.92, 0.55),
		Text = KIND_TITLE[kind],
		TextColor3 = UiTheme.Colors.Text,
		TextScaled = true,
		Font = UiTheme.FontTitle,
		ZIndex = 3,
	}, header) :: TextLabel
	UiTheme.TextStroke(title, 3)
	local titleConstraint = Instance.new("UITextSizeConstraint")
	titleConstraint.MaxTextSize = 42
	titleConstraint.Parent = title

	local subtitle = UiTheme.Create("TextLabel", {
		Name = "Subtitle",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.04, 0.62),
		Size = UDim2.fromScale(0.92, 0.3),
		Text = "TOP 10",
		TextColor3 = UiTheme.Colors.Text,
		TextScaled = true,
		Font = UiTheme.FontBody,
		ZIndex = 3,
	}, header) :: TextLabel
	UiTheme.TextStroke(subtitle, 2)
	local subtitleConstraint = Instance.new("UITextSizeConstraint")
	subtitleConstraint.MaxTextSize = 20
	subtitleConstraint.Parent = subtitle

	local list = UiTheme.Create("Frame", {
		Name = "List",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.145),
		Size = UDim2.fromScale(1, 0.855),
		ZIndex = 2,
	}, root) :: Frame
	list:SetAttribute("BoardKind", kind)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0.008, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for index = 1, LeaderboardConfig.TopCount do
		makeRow(list, index)
	end

	return gui
end

function LeaderboardBoard.Paint(gui: SurfaceGui, kind: LeaderboardConfig.BoardKind, entries: { Entry })
	local root = gui:FindFirstChild("Root")
	if not root then
		return
	end
	local list = root:FindFirstChild("List")
	if not list then
		return
	end

	for index = 1, LeaderboardConfig.TopCount do
		local row = list:FindFirstChild(string.format("Row%d", index))
		if row and row:IsA("Frame") then
			local entry = entries[index]
			local rankLabel = row:FindFirstChild("Rank") :: TextLabel?
			local avatar = row:FindFirstChild("Avatar") :: ImageLabel?
			local nameLabel = row:FindFirstChild("PlayerName") :: TextLabel?
			local valueLabel = row:FindFirstChild("Value") :: TextLabel?
			local stroke = row:FindFirstChildOfClass("UIStroke")
			local medal = if entry then RANK_COLORS[entry.Rank] else nil

			if medal then
				row.BackgroundColor3 = medal:Lerp(Color3.fromRGB(255, 255, 255), 0.45)
			else
				row.BackgroundColor3 = UiTheme.Colors.BgRow
			end
			if stroke then
				stroke.Color = if medal then medal:Lerp(UiTheme.Colors.Stroke, 0.25) else UiTheme.Colors.Stroke
			end

			if entry then
				if rankLabel then
					rankLabel.Text = tostring(entry.Rank)
					rankLabel.TextColor3 = medal or UiTheme.Colors.TextDark
				end
				if nameLabel then
					nameLabel.Text = if entry.DisplayName ~= "" then entry.DisplayName else entry.Name
				end
				if valueLabel then
					valueLabel.Text = formatValue(kind, entry.Value)
				end
				if avatar then
					avatar.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", entry.UserId)
					avatar.ImageTransparency = 0
				end
			else
				if rankLabel then
					rankLabel.Text = tostring(index)
					rankLabel.TextColor3 = UiTheme.Colors.TextMuted
				end
				if nameLabel then
					nameLabel.Text = "---"
				end
				if valueLabel then
					valueLabel.Text = "---"
				end
				if avatar then
					avatar.Image = ""
					avatar.ImageTransparency = 0.35
				end
			end
		end
	end
end

function LeaderboardBoard.Mount(target: LeaderboardConfig.BoardTarget): { SurfaceGui }
	local guis: { SurfaceGui } = {}
	for _, face in ipairs(target.Faces) do
		local gui = buildGui(target.Part, face, target.Kind)
		gui:SetAttribute("BoardKind", target.Kind)
		table.insert(guis, gui)
	end
	return guis
end

function LeaderboardBoard.PaintPart(part: BasePart, kind: LeaderboardConfig.BoardKind, entries: { Entry })
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("SurfaceGui") and string.find(child.Name, LeaderboardConfig.GuiNamePrefix, 1, true) == 1 then
			LeaderboardBoard.Paint(child, kind, entries)
		end
	end
end

return LeaderboardBoard
