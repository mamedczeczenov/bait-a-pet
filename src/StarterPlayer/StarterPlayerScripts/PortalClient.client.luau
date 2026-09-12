--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlaceConfig = require(Modules:WaitForChild("PlaceConfig"))
local UiTheme = require(Modules:WaitForChild("UiTheme"))
local UiToast = require(Modules:WaitForChild("UiToast"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local petResultRemote = remotes:WaitForChild("PetResult") :: RemoteEvent
local openMapPickerRemote = remotes:WaitForChild("OpenMapPicker") :: RemoteEvent
local requestTeleportRemote = remotes:WaitForChild("RequestTeleport") :: RemoteEvent

if PlaceConfig.IsAfkPlace() then
	return
end

local PORTAL_HINTS = {
	"Teleport",
	"teleport",
	"map 2",
	"map 3",
	"Map 2",
	"Map 3",
	"Studio",
	"AFK",
	"afk lobby",
	"773",
	"miedzy mapami",
	"między mapami",
	"Index",
	"index",
}

local function isPortalMessage(message: string): boolean
	local lower = string.lower(message)
	for _, hint in ipairs(PORTAL_HINTS) do
		if string.find(lower, string.lower(hint), 1, true) then
			return true
		end
	end
	return false
end

type PickerOption = {
	Id: string,
	Label: string,
	Locked: boolean,
	LockReason: string,
}

local screenGui = UiTheme.Create("ScreenGui", {
	Name = "MapPicker",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 52,
	Enabled = true,
}, playerGui) :: ScreenGui
UiTheme.MobileScale(screenGui)

local overlay = UiTheme.Create("Frame", {
	Name = "Overlay",
	BackgroundColor3 = Color3.fromRGB(20, 28, 40),
	BackgroundTransparency = 0.35,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 40,
}, screenGui) :: Frame

local dialog = UiTheme.Create("Frame", {
	Name = "Dialog",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = UiTheme.Colors.BgRaised,
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(400, 236),
	ZIndex = 41,
}, overlay) :: Frame
UiTheme.Corner(dialog, UiTheme.CornerPanel)
UiTheme.Stroke(dialog, UiTheme.Colors.Stroke, 4, 0)

UiTheme.Create("TextLabel", {
	Name = "Title",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 16),
	Size = UDim2.fromOffset(360, 28),
	Font = UiTheme.FontTitle,
	Text = "Choose a map",
	TextColor3 = UiTheme.Colors.TextDark,
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 42,
}, dialog)

local optionButtons: { TextButton } = {}
local optionDefs: { PickerOption } = {}

local function hidePicker()
	overlay.Visible = false
end

local function requestMap(option: PickerOption)
	if option.Locked then
		local reason = option.LockReason
		if reason == "" then
			reason = "Map 3 is locked."
		end
		UiToast.Show(reason, 4)
		return
	end
	hidePicker()
	requestTeleportRemote:FireServer(option.Id)
end

for index = 1, 2 do
	local button = UiTheme.Button({
		Name = "Option" .. index,
		Parent = dialog,
		Position = UDim2.fromOffset(20, 56 + (index - 1) * 52),
		Size = UDim2.fromOffset(360, 44),
		Text = "Map",
		TextSize = 18,
		Variant = "cyan",
		ZIndex = 42,
	})
	table.insert(optionButtons, button)
	button.MouseButton1Click:Connect(function()
		local def = optionDefs[index]
		if def then
			requestMap(def)
		end
	end)
end

local cancelButton = UiTheme.Button({
	Name = "Cancel",
	Parent = dialog,
	Position = UDim2.fromOffset(20, 168),
	Size = UDim2.fromOffset(360, 42),
	Text = "Cancel",
	TextSize = 16,
	Variant = "muted",
	ZIndex = 42,
})
cancelButton.MouseButton1Click:Connect(hidePicker)

local function showPicker(options: { PickerOption })
	optionDefs = options
	for index, button in ipairs(optionButtons) do
		local def = options[index]
		if def then
			button.Visible = true
			if def.Locked then
				button.Text = def.Label .. "  (locked)"
				button.BackgroundColor3 = UiTheme.ButtonColor("muted")
			else
				button.Text = def.Label
				button.BackgroundColor3 = UiTheme.ButtonColor(if index == 1 then "cyan" else "pink")
			end
		else
			button.Visible = false
		end
	end
	overlay.Visible = true
end

openMapPickerRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local rawOptions = payload.Options
	if typeof(rawOptions) ~= "table" then
		return
	end

	local options: { PickerOption } = {}
	for _, entry in ipairs(rawOptions) do
		if typeof(entry) ~= "table" then
			continue
		end
		local id = entry.Id
		local label = entry.Label
		if typeof(id) ~= "string" or typeof(label) ~= "string" then
			continue
		end
		table.insert(options, {
			Id = id,
			Label = label,
			Locked = entry.Locked == true,
			LockReason = if typeof(entry.LockReason) == "string" then entry.LockReason else "",
		})
	end

	if #options == 0 then
		return
	end

	showPicker(options)
end)

petResultRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or payload.Type ~= "Error" then
		return
	end

	local message = payload.Message
	if typeof(message) ~= "string" or message == "" then
		return
	end

	if isPortalMessage(message) then
		UiToast.Show(message, 5)
	end
end)
