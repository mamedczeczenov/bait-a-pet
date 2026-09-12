--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PetConfig = require(Modules:WaitForChild("PetConfig"))
local PetIconUi = require(Modules:WaitForChild("PetIconUi"))
local PetRarityFx = require(Modules:WaitForChild("PetRarityFx"))
local PetWorldDisplay = require(Modules:WaitForChild("PetWorldDisplay"))

local PREVIEW_FOLDER_NAME = "PetPreviews"
local TAG = PetWorldDisplay.Tag
local mounted: { [Model]: BillboardGui } = {}

local function findPreviewModel(petName: string): Model?
	local folder = ReplicatedStorage:FindFirstChild(PREVIEW_FOLDER_NAME)
	if not folder then
		folder = ReplicatedStorage:WaitForChild(PREVIEW_FOLDER_NAME, 5)
	end
	if not folder or not folder:IsA("Folder") then
		return nil
	end
	local model = folder:FindFirstChild(petName)
	if model and model:IsA("Model") then
		return model
	end
	return nil
end

local function unmount(display: Model)
	local gui = mounted[display]
	if gui then
		gui:Destroy()
		mounted[display] = nil
	end
end

local function mount(display: Model)
	if mounted[display] then
		return
	end

	-- Real world-space clones already face the player; skip the flat billboard overlay.
	if display:GetAttribute("World3D") == true then
		return
	end

	local host = display:FindFirstChild("DisplayHost")
	if not host or not host:IsA("BasePart") then
		host = display.PrimaryPart
	end
	if not host or not host:IsA("BasePart") then
		return
	end

	local petName = display:GetAttribute("PetName")
	if typeof(petName) ~= "string" or petName == "" then
		return
	end

	local preview = findPreviewModel(petName)
	if not preview then
		-- Previews sync shortly after join; retry once.
		task.delay(0.5, function()
			if display.Parent and not mounted[display] then
				mount(display)
			end
		end)
		return
	end

	local rarityAttr = display:GetAttribute("Rarity")
	local rarity = if typeof(rarityAttr) == "string" and rarityAttr ~= "" then rarityAttr else "Common"
	local studSizeAttr = display:GetAttribute("StudSize")
	local studSize = if typeof(studSizeAttr) == "number" then studSizeAttr else 3.4
	local auraAttr = display:GetAttribute("CatchAura")
	local catchAura = if typeof(auraAttr) == "number" then auraAttr else 0
	local eventTagAttr = display:GetAttribute("EventTag")
	local eventTag = if typeof(eventTagAttr) == "string" and eventTagAttr ~= "" then eventTagAttr else nil
	local alwaysOnTop = display:GetAttribute("AlwaysOnTop") == true
	local rarityColor = PetConfig.GetRarityColor(rarity)

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PetBillboardLocal"
	billboard.Adornee = host
	billboard.AlwaysOnTop = alwaysOnTop
	billboard.LightInfluence = 0.15
	billboard.Size = UDim2.new(studSize, 0, studSize, 0)
	billboard.MaxDistance = 140
	billboard.ResetOnSpawn = false
	billboard.Parent = playerGui

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Viewport"
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Color3.fromRGB(200, 200, 210)
	viewport.LightColor = rarityColor:Lerp(Color3.fromRGB(255, 255, 255), 0.45)
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.Parent = billboard

	local ok = PetIconUi.SetupViewport(viewport, preview, rarity, catchAura, eventTag)
	if not ok then
		billboard:Destroy()
		return
	end

	mounted[display] = billboard

	display.Destroying:Connect(function()
		unmount(display)
	end)
	display.AncestryChanged:Connect(function(_, parent)
		if not parent then
			unmount(display)
		end
	end)
end

for _, instance in ipairs(CollectionService:GetTagged(TAG)) do
	if instance:IsA("Model") then
		task.spawn(mount, instance)
	end
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance)
	if instance:IsA("Model") then
		task.spawn(mount, instance)
	end
end)

CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
	if instance:IsA("Model") then
		unmount(instance)
	end
end)

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for _, instance in ipairs(CollectionService:GetTagged(PetRarityFx.EVENT_FX_TAG)) do
		if instance:IsA("Model") and instance:GetAttribute("EventTag") == "Rainbow" then
			PetRarityFx.StepRainbowFx(instance, now)
		end
	end
end)
