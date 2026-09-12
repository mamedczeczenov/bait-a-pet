--!strict

--[[
	Single shared toast look/position for all clients.
]]

local TweenService = game:GetService("TweenService")

local UiTheme = require(script.Parent:WaitForChild("UiTheme"))

local UiToast = {}

local hostGui: ScreenGui? = nil
local toastLabel: TextLabel? = nil
local hideToken = 0

local function ensureHost(): (ScreenGui, TextLabel)
	if hostGui and hostGui.Parent and toastLabel then
		return hostGui, toastLabel
	end

	local playerGui = UiTheme.LocalPlayerGui()
	assert(playerGui, "PlayerGui missing for UiToast")

	local existing = playerGui:FindFirstChild("UiToastGui")
	if existing and existing:IsA("ScreenGui") then
		hostGui = existing
		local label = existing:FindFirstChild("Toast")
		if label and label:IsA("TextLabel") then
			toastLabel = label
			return hostGui, toastLabel
		end
	end

	hostGui = UiTheme.Create("ScreenGui", {
		Name = "UiToastGui",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 80,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui) :: ScreenGui
	UiTheme.MobileScale(hostGui)

	toastLabel = UiTheme.Create("TextLabel", {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 92),
		Size = UDim2.fromOffset(480, 44),
		BackgroundColor3 = UiTheme.Colors.AccentAmber,
		Text = "",
		TextColor3 = UiTheme.Colors.Text,
		TextSize = 18,
		Font = UiTheme.FontTitle,
		Visible = false,
		ZIndex = 10,
	}, hostGui) :: TextLabel
	UiTheme.Corner(toastLabel, UiTheme.CornerButton)
	UiTheme.Stroke(toastLabel, UiTheme.Colors.Stroke, 3, 0)
	UiTheme.TextStroke(toastLabel, 2.2)
	UiTheme.Gradient(toastLabel, Color3.fromRGB(255, 230, 100), Color3.fromRGB(255, 170, 40), 90)
	UiTheme.Pad(toastLabel, 8)

	return hostGui, toastLabel
end

function UiToast.Show(message: string, durationSeconds: number?)
	local _, label = ensureHost()
	hideToken += 1
	local token = hideToken

	label.Text = message
	label.TextTransparency = 0
	label.BackgroundTransparency = 0
	label.Visible = true
	UiTheme.BounceIn(label, 0.7)

	local duration = durationSeconds or 2.4
	task.delay(duration, function()
		if token ~= hideToken or not label.Parent then
			return
		end
		local tween = TweenService:Create(label, TweenInfo.new(0.35), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		})
		tween:Play()
		tween.Completed:Wait()
		if token == hideToken then
			label.Visible = false
			label.TextTransparency = 0
			label.BackgroundTransparency = 0
		end
	end)
end

return UiToast
