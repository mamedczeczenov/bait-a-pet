--!strict

--[[
	Session auto-throw from spawn or cave.
	Throws on cooldown, then randomly clicks the luck bar (same catch as manual).
	Cannot be turned on while a manual throw is already in progress.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local BaitConfig = require(Modules:WaitForChild("BaitConfig"))
local CaveConfig = require(Modules:WaitForChild("CaveConfig"))
local PlaceConfig = require(Modules:WaitForChild("PlaceConfig"))
local TutorialGate = require(Modules:WaitForChild("TutorialGate"))
local UiIcon = require(Modules:WaitForChild("UiIcon"))
local UiTheme = require(Modules:WaitForChild("UiTheme"))

local existingGui = playerGui:FindFirstChild("AutoThrowGui")
if existingGui then
	existingGui:Destroy()
end

localPlayer:SetAttribute("AutoThrow", false)

if PlaceConfig.IsAfkPlace() then
	return
end

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local startBaitRemote = remotes:WaitForChild("StartBait") :: RemoteEvent
local petResultRemote = remotes:WaitForChild("PetResult") :: RemoteEvent
local requestThrowRemote = remotes:WaitForChild("RequestThrow") :: RemoteEvent

local THROW_REQUEST_COOLDOWN = 0.35

local autoEnabled = false
local awaitingLuck = false
local lastThrowRequestAt = 0
local isNearCave = false
local nearCaveBlocked = false
local lastVisualKey = ""

local screenGui = UiTheme.Create("ScreenGui", {
	Name = "AutoThrowGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 7,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui) :: ScreenGui
UiTheme.MobileScale(screenGui)

-- Sits just to the right of BaitClient ThrowBaitButton (188 wide, centered, y=-118).
local autoButton = UiTheme.Create("TextButton", {
	Name = "AutoThrowButton",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0.5, 104, 1, -118),
	Size = UDim2.fromOffset(72, 72),
	BackgroundColor3 = UiTheme.Colors.BgMuted,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 5,
}, screenGui) :: TextButton

UiTheme.Corner(autoButton, UiTheme.CornerPanel)
local autoStroke = UiTheme.Stroke(autoButton, UiTheme.Colors.Stroke, 4, 0)
UiTheme.Gradient(autoButton, Color3.fromRGB(220, 230, 240), UiTheme.Colors.BgMuted, 90)
UiTheme.WireButtonMotion(autoButton)

local iconHost = UiTheme.Create("Frame", {
	Name = "IconHost",
	BackgroundTransparency = 1,
	Active = false,
	Position = UDim2.fromOffset(0, 8),
	Size = UDim2.new(1, 0, 0, 32),
	ZIndex = 6,
}, autoButton) :: Frame
UiIcon.Mount(iconHost, {
	Key = "action_auto_throw",
	Name = "Glyph",
	Size = UDim2.fromScale(1, 1),
	ImageSize = 28,
})

local stateLabel = UiTheme.Create("TextLabel", {
	Name = "StateLabel",
	BackgroundTransparency = 1,
	Active = false,
	Position = UDim2.fromOffset(4, 42),
	Size = UDim2.new(1, -8, 0, 22),
	Text = "AUTO",
	TextColor3 = UiTheme.Colors.TextDark,
	TextSize = 14,
	Font = UiTheme.FontTitle,
	ZIndex = 6,
}, autoButton) :: TextLabel

local function styleLabel(outlined: boolean, color: Color3)
	stateLabel.TextColor3 = color
	local existing = stateLabel:FindFirstChild("CandyTextStroke")
	if outlined then
		if not existing then
			UiTheme.TextStroke(stateLabel, 2)
		end
	elseif existing then
		existing:Destroy()
	end
end

local function setIconTransparency(transparency: number)
	local glyph = iconHost:FindFirstChild("Glyph")
	if not glyph then
		return
	end
	if glyph:IsA("ImageLabel") then
		glyph.ImageTransparency = transparency
	elseif glyph:IsA("TextLabel") then
		glyph.TextTransparency = transparency
	end
end

local function isManualThrowBusy(): boolean
	return awaitingLuck and not autoEnabled
end

local function updateVisuals()
	local busyManualCatch = isManualThrowBusy()
	autoButton.Active = not busyManualCatch
	autoButton.AutoButtonColor = not busyManualCatch

	local visualKey: string
	if busyManualCatch then
		visualKey = "busy"
	elseif not autoEnabled then
		visualKey = "off"
	elseif isNearCave and not nearCaveBlocked then
		visualKey = "on"
	else
		visualKey = "paused"
	end

	if visualKey == lastVisualKey then
		return
	end
	lastVisualKey = visualKey

	if visualKey == "on" then
		autoButton.BackgroundColor3 = UiTheme.Colors.AccentGreen
		autoStroke.Color = UiTheme.Colors.Stroke
		UiTheme.Gradient(autoButton, Color3.fromRGB(160, 255, 170), UiTheme.Colors.AccentGreenHot, 90)
		stateLabel.Text = "AUTO"
		styleLabel(true, UiTheme.Colors.Text)
		setIconTransparency(0)
	elseif visualKey == "paused" then
		autoButton.BackgroundColor3 = UiTheme.Colors.AccentAmber
		autoStroke.Color = UiTheme.Colors.Stroke
		UiTheme.Gradient(autoButton, Color3.fromRGB(255, 230, 120), UiTheme.Colors.AccentAmberDim, 90)
		stateLabel.Text = "AUTO"
		styleLabel(true, UiTheme.Colors.Text)
		setIconTransparency(0.05)
	elseif visualKey == "busy" then
		autoButton.BackgroundColor3 = UiTheme.Colors.BgMuted
		autoStroke.Color = UiTheme.Colors.Stroke
		UiTheme.Gradient(autoButton, Color3.fromRGB(200, 210, 220), UiTheme.Colors.BgMuted, 90)
		stateLabel.Text = "WAIT"
		styleLabel(false, UiTheme.Colors.TextDim)
		setIconTransparency(0.35)
	else
		autoButton.BackgroundColor3 = UiTheme.Colors.BgMuted
		autoStroke.Color = UiTheme.Colors.Stroke
		UiTheme.Gradient(autoButton, Color3.fromRGB(230, 238, 248), UiTheme.Colors.BgMuted, 90)
		stateLabel.Text = "AUTO"
		styleLabel(false, UiTheme.Colors.TextDark)
		setIconTransparency(0.15)
	end
end

local function getCooldownRemaining(): number
	local untilTime = localPlayer:GetAttribute("CatchCooldownUntil")
	if typeof(untilTime) ~= "number" or untilTime <= 0 then
		return 0
	end
	return math.max(0, untilTime - Workspace:GetServerTimeNow())
end

local function isBagFull(): boolean
	local petCount = localPlayer:GetAttribute("PetCount")
	local bagCapacity = localPlayer:GetAttribute("BagCapacity")
	if typeof(petCount) ~= "number" or typeof(bagCapacity) ~= "number" then
		return false
	end
	return petCount >= bagCapacity
end

local function refreshNearCave()
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		isNearCave = false
		nearCaveBlocked = false
		return
	end

	local zones: { BasePart } = {}
	for _, zone in ipairs(CollectionService:GetTagged(BaitConfig.CatchZoneTag)) do
		if zone:IsA("BasePart") and zone.Parent then
			table.insert(zones, zone)
		end
	end

	local nearest = CaveConfig.ChooseThrowZone(root.Position, zones)
	isNearCave = nearest ~= nil
	if isNearCave and nearest then
		local caveType = CaveConfig.ResolveTypeFromZone(nearest)
		nearCaveBlocked = CaveConfig.RequiresVip(caveType) and localPlayer:GetAttribute("VipAccess") ~= true
	else
		nearCaveBlocked = false
	end
end

local function tryRequestThrow()
	if not autoEnabled or awaitingLuck then
		return
	end
	if localPlayer:GetAttribute("IsThrowing") == true then
		return
	end
	if not isNearCave or nearCaveBlocked then
		return
	end
	if isBagFull() then
		return
	end
	if getCooldownRemaining() > 0 then
		return
	end
	if not TutorialGate.IsActionAllowed("throw_bait") then
		return
	end

	local now = os.clock()
	if now - lastThrowRequestAt < THROW_REQUEST_COOLDOWN then
		return
	end

	lastThrowRequestAt = now
	requestThrowRemote:FireServer()
end

local function setAutoEnabled(enabled: boolean)
	if enabled and isManualThrowBusy() then
		return
	end

	if autoEnabled == enabled then
		lastVisualKey = ""
		updateVisuals()
		return
	end

	autoEnabled = enabled
	localPlayer:SetAttribute("AutoThrow", enabled == true)
	lastVisualKey = ""
	updateVisuals()

	if enabled then
		tryRequestThrow()
	end
end

autoButton.MouseButton1Click:Connect(function()
	if isManualThrowBusy() then
		return
	end
	if not autoEnabled and not TutorialGate.TryAction("throw_bait") then
		return
	end
	setAutoEnabled(not autoEnabled)
end)

startBaitRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	awaitingLuck = true
	lastVisualKey = ""
	updateVisuals()
end)

petResultRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local payloadType = payload.Type
	if payloadType == "Error" or payloadType == "Result" then
		awaitingLuck = false
		lastVisualKey = ""
		updateVisuals()
	end
end)

RunService.Heartbeat:Connect(function()
	refreshNearCave()
	updateVisuals()
	if autoEnabled then
		tryRequestThrow()
	end
end)

localPlayer:GetAttributeChangedSignal("VipAccess"):Connect(function()
	refreshNearCave()
	lastVisualKey = ""
	updateVisuals()
end)

updateVisuals()
