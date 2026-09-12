--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local TutorialGate = require(Modules:WaitForChild("TutorialGate"))
local UiTheme = require(Modules:WaitForChild("UiTheme"))
local UiToast = require(Modules:WaitForChild("UiToast"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local tutorialRemote = remotes:WaitForChild("Tutorial") :: RemoteEvent

local screenGui = UiTheme.Create("ScreenGui", {
	Name = "TutorialGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 20,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui) :: ScreenGui
UiTheme.MobileScale(screenGui)

local panel = UiTheme.Panel({
	Name = "Panel",
	Parent = screenGui,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 18, 1, -24),
	Size = UDim2.fromOffset(360, 156),
	Visible = false,
	ZIndex = 10,
})
-- Candy pink accent stripe under header for guide energy
local accentStripe = UiTheme.Create("Frame", {
	Name = "AccentStripe",
	BackgroundColor3 = UiTheme.Colors.AccentPink,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(0, 54),
	Size = UDim2.new(1, 0, 0, 4),
	ZIndex = 11,
}, panel) :: Frame
UiTheme.Gradient(accentStripe, UiTheme.Colors.AccentCyan, UiTheme.Colors.AccentPink, 0)

local stepLabel = UiTheme.Create("TextLabel", {
	Name = "Step",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 12),
	Size = UDim2.fromOffset(200, 20),
	Text = "1/4",
	TextColor3 = UiTheme.Colors.Text,
	TextSize = 14,
	Font = UiTheme.FontTitle,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 12,
}, panel) :: TextLabel
UiTheme.TextStroke(stepLabel, 2)

local titleLabel = UiTheme.Create("TextLabel", {
	Name = "Title",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 32),
	Size = UDim2.fromOffset(250, 24),
	Text = "Guide",
	TextColor3 = UiTheme.Colors.Text,
	TextSize = 22,
	Font = UiTheme.FontTitle,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 12,
}, panel) :: TextLabel
UiTheme.TextStroke(titleLabel, 2.6)

local bodyLabel = UiTheme.Create("TextLabel", {
	Name = "Body",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 68),
	Size = UDim2.fromOffset(328, 72),
	Text = "",
	TextColor3 = UiTheme.Colors.TextDark,
	TextSize = 15,
	Font = UiTheme.FontBody,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 12,
}, panel) :: TextLabel

local skipButton = UiTheme.Button({
	Name = "Skip",
	Parent = panel,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 10),
	Size = UDim2.fromOffset(72, 32),
	Text = "Skip",
	TextSize = 14,
	Variant = "pink",
	ZIndex = 13,
}) :: TextButton

local replayButton = UiTheme.Button({
	Name = "ReplayGuide",
	Parent = screenGui,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -18, 0, 18),
	Size = UDim2.fromOffset(150, 40),
	Text = "Show guide",
	TextSize = 14,
	Variant = "cyan",
	ZIndex = 8,
}) :: TextButton
replayButton.Visible = false

local highlightStroke: UIStroke? = nil
local highlightedTarget: GuiObject? = nil
local pulseConn: RBXScriptConnection? = nil
local arrowLabel: TextLabel? = nil
local stuckToken = 0
local currentStep = 0
local currentHighlightId: string? = nil
local tutorialVisible = false

local HIGHLIGHT_ATTR = "TutorialTarget"

local function clearHighlight()
	if pulseConn then
		pulseConn:Disconnect()
		pulseConn = nil
	end
	if highlightStroke then
		highlightStroke:Destroy()
		highlightStroke = nil
	end
	if arrowLabel then
		arrowLabel:Destroy()
		arrowLabel = nil
	end
	highlightedTarget = nil
end

local function findHighlightTarget(targetId: string?): GuiObject?
	if typeof(targetId) ~= "string" or targetId == "" then
		return nil
	end

	for _, gui in ipairs(playerGui:GetDescendants()) do
		if gui:IsA("GuiObject") and gui:GetAttribute(HIGHLIGHT_ATTR) == targetId then
			return gui
		end
	end

	return nil
end

local function applyHighlight(targetId: string?)
	clearHighlight()
	currentHighlightId = targetId
	local target = findHighlightTarget(targetId)
	if not target then
		return
	end

	highlightedTarget = target
	local stroke = UiTheme.Create("UIStroke", {
		Name = "TutorialHighlight",
		Color = UiTheme.Colors.AccentCyan,
		Thickness = 4,
		Transparency = 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, target) :: UIStroke
	highlightStroke = stroke

	local arrow = UiTheme.Create("TextLabel", {
		Name = "TutorialArrow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -4),
		Size = UDim2.fromOffset(36, 28),
		Text = "▼",
		TextColor3 = UiTheme.Colors.AccentPink,
		TextSize = 28,
		Font = UiTheme.FontTitle,
		ZIndex = target.ZIndex + 5,
	}, target) :: TextLabel
	UiTheme.TextStroke(arrow, 2.2)
	arrowLabel = arrow

	local t0 = os.clock()
	pulseConn = RunService.RenderStepped:Connect(function()
		if not stroke.Parent then
			return
		end
		local wave = (math.sin((os.clock() - t0) * 5) + 1) * 0.5
		stroke.Thickness = 3 + wave * 2.5
		stroke.Color = UiTheme.Colors.AccentCyan:Lerp(UiTheme.Colors.AccentPink, wave)
		stroke.Transparency = 0
		if arrow.Parent then
			arrow.TextColor3 = UiTheme.Colors.AccentPink:Lerp(UiTheme.Colors.AccentCyan, wave)
			arrow.Position = UDim2.new(0.5, 0, 0, -4 - math.floor(wave * 10))
		end
	end)
end

local function ensureHighlight()
	if not tutorialVisible or typeof(currentHighlightId) ~= "string" then
		return
	end
	if highlightStroke and highlightStroke.Parent then
		return
	end
	applyHighlight(currentHighlightId)
end

local function showToast(message: string, durationSeconds: number?)
	UiToast.Show(message, durationSeconds)
end

TutorialGate.SetHintHandler(function(message)
	showToast(message, 2.6)
end)

local function scheduleStuckHint(stepIndex: number, seconds: number?, hint: string?)
	stuckToken += 1
	local token = stuckToken
	local waitSeconds = seconds or 60
	local text = hint
	if typeof(text) ~= "string" or text == "" then
		return
	end

	task.delay(waitSeconds, function()
		if token ~= stuckToken then
			return
		end
		if not tutorialVisible or currentStep ~= stepIndex then
			return
		end
		showToast(text, 4)
	end)
end

local function showStep(payload: any)
	currentStep = if typeof(payload.Step) == "number" then payload.Step else 1
	local stepCount = if typeof(payload.StepCount) == "number" then payload.StepCount else 4
	stepLabel.Text = string.format("%d/%d", currentStep, stepCount)
	titleLabel.Text = if typeof(payload.Title) == "string" then payload.Title else "Guide"
	bodyLabel.Text = if typeof(payload.Body) == "string" then payload.Body else ""
	panel.Visible = true
	tutorialVisible = true
	replayButton.Visible = false
	UiTheme.BounceIn(panel, 0.72)
	applyHighlight(if typeof(payload.Highlight) == "string" then payload.Highlight else nil)
	scheduleStuckHint(
		currentStep,
		if typeof(payload.StuckHintSeconds) == "number" then payload.StuckHintSeconds else 60,
		if typeof(payload.StuckHint) == "string" then payload.StuckHint else nil
	)
end

local function hideTutorial(showReplay: boolean)
	stuckToken += 1
	panel.Visible = false
	tutorialVisible = false
	currentHighlightId = nil
	clearHighlight()
	replayButton.Visible = showReplay
end

skipButton.MouseButton1Click:Connect(function()
	tutorialRemote:FireServer({ Type = "Skip" })
end)

replayButton.MouseButton1Click:Connect(function()
	tutorialRemote:FireServer({ Type = "Replay" })
end)

tutorialRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local payloadType = payload.Type
	if payloadType == "Start" or payloadType == "Step" then
		showStep(payload)
		return
	end

	if payloadType == "Complete" then
		hideTutorial(true)
		if typeof(payload.Message) == "string" and payload.Message ~= "" then
			showToast(payload.Message, 3.2)
		end
		return
	end

	if payloadType == "Reset" then
		hideTutorial(false)
		if typeof(payload.Message) == "string" then
			showToast(payload.Message, 2.5)
		end
		return
	end

	if payloadType == "Idle" then
		local completed = payload.Completed == true or localPlayer:GetAttribute("TutorialCompleted") == true
		hideTutorial(completed)
		return
	end
end)

task.defer(function()
	tutorialRemote:FireServer({ Type = "Ready" })
end)

task.spawn(function()
	while screenGui.Parent do
		task.wait(0.4)
		ensureHighlight()
	end
end)

localPlayer:GetAttributeChangedSignal("TutorialCompleted"):Connect(function()
	if localPlayer:GetAttribute("TutorialCompleted") == true and not tutorialVisible then
		replayButton.Visible = true
	end
end)
