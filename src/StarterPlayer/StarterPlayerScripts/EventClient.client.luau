--!strict

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local IconAssets = require(Modules:WaitForChild("IconAssets"))
local UiIcon = require(Modules:WaitForChild("UiIcon"))
local UiTheme = require(Modules:WaitForChild("UiTheme"))
local UiToast = require(Modules:WaitForChild("UiToast"))
local PlaceConfig = require(Modules:WaitForChild("PlaceConfig"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local worldEventRemote = remotes:WaitForChild("WorldEvent") :: RemoteEvent

local screenGui = UiTheme.Create("ScreenGui", {
	Name = "WorldEventGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 25,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui) :: ScreenGui
UiTheme.MobileScale(screenGui)
if PlaceConfig.IsAfkPlace() then
	screenGui.Enabled = false
end

-- Sit just under TeleportHud button row (y=16, h=68) with a small gap.
local banner = UiTheme.Create("Frame", {
	Name = "Banner",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 94),
	Size = UDim2.fromOffset(460, 72),
	BackgroundColor3 = UiTheme.Colors.BgRaised,
	Visible = false,
	ZIndex = 5,
	BorderSizePixel = 0,
}, screenGui) :: Frame
UiTheme.Corner(banner, UiTheme.CornerPanel)
local bannerStroke = UiTheme.Stroke(banner, UiTheme.Colors.Stroke, 4, 0)

local iconHost = UiTheme.Create("Frame", {
	Name = "IconHost",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, 12),
	Size = UDim2.fromOffset(44, 48),
	ZIndex = 6,
}, banner) :: Frame

local function setBannerIcon(eventId: string)
	UiIcon.Mount(iconHost, {
		Key = IconAssets.KeyForEventId(eventId),
		Name = "Glyph",
		Size = UDim2.fromScale(1, 1),
		ImageSize = 30,
	})
end
setBannerIcon("rain")

local titleLabel = UiTheme.Create("TextLabel", {
	Name = "Title",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(62, 10),
	Size = UDim2.fromOffset(300, 26),
	Text = "Event",
	TextColor3 = UiTheme.Colors.Text,
	TextSize = 20,
	Font = UiTheme.FontTitle,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 6,
}, banner) :: TextLabel
UiTheme.TextStroke(titleLabel, 2.6)

local descLabel = UiTheme.Create("TextLabel", {
	Name = "Desc",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(62, 38),
	Size = UDim2.fromOffset(270, 22),
	Text = "",
	TextColor3 = UiTheme.Colors.TextDark,
	TextSize = 13,
	Font = UiTheme.FontBody,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 6,
}, banner) :: TextLabel

local timerLabel = UiTheme.Create("TextLabel", {
	Name = "Timer",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -16, 0.5, 0),
	Size = UDim2.fromOffset(82, 30),
	Text = "0:00",
	TextColor3 = UiTheme.Colors.Text,
	TextSize = 20,
	Font = UiTheme.FontTitle,
	TextXAlignment = Enum.TextXAlignment.Right,
	ZIndex = 6,
}, banner) :: TextLabel
UiTheme.TextStroke(timerLabel, 2.2)

type EventView = {
	Id: string,
	Name: string,
	Description: string,
	Icon: string,
	EndsAt: number,
	LuckMult: number,
	SellMult: number,
	TagId: string?,
}

type UpcomingView = {
	Id: string,
	Name: string,
	Description: string,
	Icon: string,
	StartsAt: number,
	LuckMult: number,
	SellMult: number,
	TagId: string?,
}

local current: EventView? = nil
local upcoming: UpcomingView? = nil
local colorCorrection: ColorCorrectionEffect? = nil
local atmosphereConn: RBXScriptConnection? = nil
local rainFolder: Folder? = nil
local bannerWasVisible = false

local function eventCandyColors(eventId: string): (Color3, Color3, Color3)
	if eventId == "rain" then
		return Color3.fromRGB(140, 190, 255), Color3.fromRGB(70, 130, 210), Color3.fromRGB(40, 90, 180)
	elseif eventId == "storm" then
		return Color3.fromRGB(180, 150, 255), Color3.fromRGB(110, 80, 200), Color3.fromRGB(70, 50, 160)
	elseif eventId == "rainbow" then
		return Color3.fromRGB(255, 150, 220), Color3.fromRGB(255, 110, 180), Color3.fromRGB(200, 60, 200)
	elseif eventId == "lucky" then
		return Color3.fromRGB(140, 255, 160), Color3.fromRGB(60, 210, 90), Color3.fromRGB(30, 160, 60)
	elseif eventId == "market" then
		return Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 190, 50), Color3.fromRGB(220, 150, 20)
	end
	return Color3.fromRGB(150, 220, 255), UiTheme.Colors.BgHeader, Color3.fromRGB(70, 150, 220)
end

local function formatRemaining(seconds: number): string
	local remaining = math.max(0, math.floor(seconds + 0.5))
	local mins = math.floor(remaining / 60)
	local secs = remaining % 60
	return string.format("%d:%02d", mins, secs)
end

local function effectBits(luckMult: number, sellMult: number, tagId: string?): { string }
	local bits = {}
	if luckMult > 1.01 then
		table.insert(bits, string.format("Luck x%.2g", luckMult))
	end
	if sellMult > 1.01 then
		table.insert(bits, string.format("Sell x%.2g", sellMult))
	end
	if typeof(tagId) == "string" and tagId ~= "" then
		table.insert(bits, tagId .. " pets")
	end
	return bits
end

local function ensureColorCorrection(): ColorCorrectionEffect
	if colorCorrection and colorCorrection.Parent then
		return colorCorrection
	end
	local existing = Lighting:FindFirstChild("WorldEventColorCorrection")
	if existing and existing:IsA("ColorCorrectionEffect") then
		colorCorrection = existing
		return existing
	end
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "WorldEventColorCorrection"
	effect.Enabled = false
	effect.Parent = Lighting
	colorCorrection = effect
	return effect
end

local function clearRainFx()
	if rainFolder then
		rainFolder:Destroy()
		rainFolder = nil
	end
end

local function applyAtmosphere(eventId: string?)
	local effect = ensureColorCorrection()
	clearRainFx()

	if atmosphereConn then
		atmosphereConn:Disconnect()
		atmosphereConn = nil
	end

	if not eventId or eventId == "" then
		effect.Enabled = false
		return
	end

	effect.Enabled = true
	if eventId == "rain" or eventId == "storm" then
		effect.Brightness = -0.04
		effect.Contrast = 0.05
		effect.Saturation = if eventId == "storm" then -0.08 else -0.12
		effect.TintColor = if eventId == "storm"
			then Color3.fromRGB(190, 185, 230)
			else Color3.fromRGB(170, 190, 220)

		local folder = Instance.new("Folder")
		folder.Name = "WorldEventRainFx"
		folder.Parent = screenGui
		rainFolder = folder

		for i = 1, 18 do
			local drop = Instance.new("Frame")
			drop.Name = "Drop" .. i
			drop.BackgroundColor3 = Color3.fromRGB(180, 210, 255)
			drop.BackgroundTransparency = 0.45
			drop.BorderSizePixel = 0
			drop.Size = UDim2.fromOffset(2, math.random(10, 22))
			drop.Position = UDim2.new(math.random(), 0, -0.1, 0)
			drop.ZIndex = 1
			drop.Parent = folder
		end

		local drops = folder:GetChildren()
		atmosphereConn = RunService.RenderStepped:Connect(function(dt)
			for _, child in ipairs(drops) do
				if child:IsA("Frame") then
					local y = child.Position.Y.Scale + dt * (0.55 + (child.AbsoluteSize.Y / 40))
					local x = child.Position.X.Scale
					if y > 1.1 then
						y = -0.08
						x = math.random()
					end
					child.Position = UDim2.new(x, 0, y, 0)
				end
			end
		end)
	elseif eventId == "rainbow" then
		effect.Brightness = 0.03
		effect.Contrast = 0.06
		effect.Saturation = 0.22
		effect.TintColor = Color3.fromRGB(255, 230, 245)
	elseif eventId == "lucky" then
		effect.Brightness = 0.04
		effect.Contrast = 0.04
		effect.Saturation = 0.18
		effect.TintColor = Color3.fromRGB(210, 255, 220)
	elseif eventId == "market" then
		effect.Brightness = 0.05
		effect.Contrast = 0.08
		effect.Saturation = 0.12
		effect.TintColor = Color3.fromRGB(255, 240, 200)
	else
		effect.Enabled = false
	end
end

local function renderBanner()
	if current then
		local top, mid, strokeColor = eventCandyColors(current.Id)
		banner.Visible = true
		banner.BackgroundColor3 = mid
		bannerStroke.Color = strokeColor:Lerp(UiTheme.Colors.Stroke, 0.35)
		UiTheme.Gradient(banner, top, mid, 90)
		setBannerIcon(current.Id)
		titleLabel.Text = current.Name
		titleLabel.TextColor3 = UiTheme.Colors.Text
		local bits = { current.Description }
		for _, bit in ipairs(effectBits(current.LuckMult, current.SellMult, current.TagId)) do
			table.insert(bits, bit)
		end
		descLabel.Text = table.concat(bits, " · ")
		descLabel.TextColor3 = UiTheme.Colors.TextDark:Lerp(Color3.fromRGB(255, 255, 255), 0.35)
		timerLabel.TextColor3 = UiTheme.Colors.Text
		applyAtmosphere(current.Id)
		if not bannerWasVisible then
			UiTheme.BounceIn(banner, 0.75)
		end
		bannerWasVisible = true
		return
	end

	if upcoming then
		local top, mid, strokeColor = eventCandyColors(upcoming.Id)
		banner.Visible = true
		banner.BackgroundColor3 = mid:Lerp(UiTheme.Colors.BgMuted, 0.45)
		bannerStroke.Color = strokeColor:Lerp(UiTheme.Colors.Stroke, 0.5)
		UiTheme.Gradient(banner, top:Lerp(Color3.fromRGB(255, 255, 255), 0.35), mid:Lerp(UiTheme.Colors.BgMuted, 0.4), 90)
		setBannerIcon(upcoming.Id)
		titleLabel.Text = string.format("Next: %s", upcoming.Name)
		titleLabel.TextColor3 = UiTheme.Colors.Text
		local bits = { "Starts soon" }
		for _, bit in ipairs(effectBits(upcoming.LuckMult, upcoming.SellMult, upcoming.TagId)) do
			table.insert(bits, bit)
		end
		if upcoming.Description ~= "" then
			table.insert(bits, 1, upcoming.Description)
		end
		descLabel.Text = table.concat(bits, " · ")
		descLabel.TextColor3 = UiTheme.Colors.TextDark
		timerLabel.TextColor3 = UiTheme.Colors.AccentCyan
		applyAtmosphere(nil)
		if not bannerWasVisible then
			UiTheme.BounceIn(banner, 0.75)
		end
		bannerWasVisible = true
		return
	end

	banner.Visible = false
	bannerWasVisible = false
	applyAtmosphere(nil)
end

local function clearActive()
	current = nil
end

local function parseActive(payload: { [string]: any }): EventView?
	if payload.Active ~= true then
		return nil
	end
	if typeof(payload.Id) ~= "string" or typeof(payload.EndsAt) ~= "number" then
		return nil
	end
	return {
		Id = payload.Id,
		Name = if typeof(payload.Name) == "string" then payload.Name else "Event",
		Description = if typeof(payload.Description) == "string" then payload.Description else "",
		Icon = if typeof(payload.Icon) == "string" then payload.Icon else "✨",
		EndsAt = payload.EndsAt,
		LuckMult = if typeof(payload.LuckMult) == "number" then payload.LuckMult else 1,
		SellMult = if typeof(payload.SellMult) == "number" then payload.SellMult else 1,
		TagId = if typeof(payload.TagId) == "string" and payload.TagId ~= "" then payload.TagId else nil,
	}
end

local function parseUpcoming(payload: { [string]: any }): UpcomingView?
	if typeof(payload.NextId) ~= "string" or payload.NextId == "" then
		return nil
	end
	if typeof(payload.NextStartsAt) ~= "number" or payload.NextStartsAt <= 0 then
		return nil
	end
	return {
		Id = payload.NextId,
		Name = if typeof(payload.NextName) == "string" then payload.NextName else "Event",
		Description = if typeof(payload.NextDescription) == "string" then payload.NextDescription else "",
		Icon = if typeof(payload.NextIcon) == "string" then payload.NextIcon else "✨",
		StartsAt = payload.NextStartsAt,
		LuckMult = if typeof(payload.NextLuckMult) == "number" then payload.NextLuckMult else 1,
		SellMult = if typeof(payload.NextSellMult) == "number" then payload.NextSellMult else 1,
		TagId = if typeof(payload.NextTagId) == "string" and payload.NextTagId ~= "" then payload.NextTagId else nil,
	}
end

local function applyPayload(payload: { [string]: any }, announceStart: boolean)
	local activeView = parseActive(payload)
	local upcomingView = parseUpcoming(payload)

	if activeView then
		current = activeView
		if announceStart then
			UiToast.Show(string.format("%s %s started!", activeView.Icon, activeView.Name), 3)
		end
	else
		clearActive()
	end

	upcoming = upcomingView
	renderBanner()
end

local function applyFromStateFolder()
	local folder = ReplicatedStorage:FindFirstChild("WorldEventState")
	if not folder or not folder:IsA("Folder") then
		return
	end

	local function readString(name: string): string
		local child = folder:FindFirstChild(name)
		if child and child:IsA("StringValue") then
			return child.Value
		end
		return ""
	end

	local function readNumber(name: string, fallback: number): number
		local child = folder:FindFirstChild(name)
		if child and child:IsA("NumberValue") then
			return child.Value
		end
		return fallback
	end

	local activeValue = folder:FindFirstChild("Active")
	local isActive = activeValue and activeValue:IsA("BoolValue") and activeValue.Value
	local id = readString("Id")

	applyPayload({
		Active = isActive == true and id ~= "",
		Id = id,
		Name = readString("Name"),
		Description = readString("Description"),
		Icon = readString("Icon"),
		EndsAt = readNumber("EndsAt", 0),
		LuckMult = readNumber("LuckMult", 1),
		SellMult = readNumber("SellMult", 1),
		TagId = readString("TagId"),
		NextId = readString("NextId"),
		NextName = readString("NextName"),
		NextDescription = readString("NextDescription"),
		NextIcon = readString("NextIcon"),
		NextStartsAt = readNumber("NextStartsAt", 0),
		NextLuckMult = readNumber("NextLuckMult", 1),
		NextSellMult = readNumber("NextSellMult", 1),
		NextTagId = readString("NextTagId"),
	}, false)
end

worldEventRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local payloadType = payload.Type
	if payloadType == "Ended" then
		if typeof(payload.Message) == "string" and payload.Message ~= "" then
			UiToast.Show(payload.Message, 2.2)
		end
		clearActive()
		upcoming = parseUpcoming(payload)
		renderBanner()
		return
	end

	if payloadType == "Upcoming" then
		upcoming = parseUpcoming(payload)
		if payload.Active == true then
			local activeView = parseActive(payload)
			if activeView then
				current = activeView
			end
		else
			clearActive()
		end
		renderBanner()
		return
	end

	applyPayload(payload, payloadType == "Started")
end)

RunService.Heartbeat:Connect(function()
	if current then
		local remaining = current.EndsAt - Workspace:GetServerTimeNow()
		if remaining <= 0 then
			clearActive()
			renderBanner()
			return
		end
		timerLabel.Text = formatRemaining(remaining)
		return
	end

	if upcoming then
		local remaining = upcoming.StartsAt - Workspace:GetServerTimeNow()
		if remaining <= 0 then
			timerLabel.Text = "Soon"
			return
		end
		timerLabel.Text = formatRemaining(remaining)
	end
end)

local stateFolder = ReplicatedStorage:FindFirstChild("WorldEventState")
if stateFolder then
	applyFromStateFolder()
	stateFolder.ChildAdded:Connect(function()
		task.defer(applyFromStateFolder)
	end)
	for _, child in ipairs(stateFolder:GetChildren()) do
		if child:IsA("StringValue") or child:IsA("NumberValue") or child:IsA("BoolValue") then
			child:GetPropertyChangedSignal("Value"):Connect(function()
				task.defer(applyFromStateFolder)
			end)
		end
	end
end

ReplicatedStorage.ChildAdded:Connect(function(child)
	if child.Name == "WorldEventState" then
		task.defer(applyFromStateFolder)
	end
end)

task.defer(function()
	worldEventRemote:FireServer({ Type = "Ready" })
	task.wait(0.5)
	applyFromStateFolder()
end)
