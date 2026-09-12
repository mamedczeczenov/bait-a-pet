--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FeelSound = require(Modules:WaitForChild("FeelSound"))
local PetConfig = require(Modules:WaitForChild("PetConfig"))
local PetIconUi = require(Modules:WaitForChild("PetIconUi"))
local PlaceConfig = require(Modules:WaitForChild("PlaceConfig"))
local PotionConfig = require(Modules:WaitForChild("PotionConfig"))
local UiIcon = require(Modules:WaitForChild("UiIcon"))
local UiTheme = require(Modules:WaitForChild("UiTheme"))
PetConfig.EnsureLoaded(30)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local equipPetRemote = remotes:WaitForChild("EquipPet") :: RemoteEvent
local usePotionRemote = remotes:WaitForChild("UsePotion") :: RemoteEvent

local SLOT_SIZE = 64
local SLOT_GAP = 8
local MAX_SLOTS = 9

local screenGui = UiTheme.Create("ScreenGui", {
	Name = "PetHotbarGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 5,
}, playerGui) :: ScreenGui
UiTheme.MobileScale(screenGui)
if PlaceConfig.IsAfkPlace() then
	screenGui.Enabled = false
end

local equipment = UiTheme.Create("Frame", {
	Name = "Equipment",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -18),
	Size = UDim2.fromOffset(0, 0),
	BackgroundTransparency = 1,
	Visible = false,
}, screenGui) :: Frame

UiTheme.Create("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	Padding = UDim.new(0, SLOT_GAP),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, equipment)

local potionBar = UiTheme.Create("Frame", {
	Name = "PotionBar",
	Size = UDim2.fromOffset(0, SLOT_SIZE),
	BackgroundTransparency = 1,
	Visible = false,
	LayoutOrder = 1,
}, equipment) :: Frame

UiTheme.Create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, SLOT_GAP),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, potionBar)

local hotbar = UiTheme.Create("Frame", {
	Name = "Hotbar",
	Size = UDim2.fromOffset(0, SLOT_SIZE),
	BackgroundTransparency = 1,
	Visible = false,
	LayoutOrder = 2,
}, equipment) :: Frame

UiTheme.Create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, SLOT_GAP),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, hotbar)

type SlotRefs = {
	Button: TextButton,
	IconHost: Frame,
	NameLabel: TextLabel,
	KeyLabel: TextLabel,
	Stroke: UIStroke,
}

type PotionSlotRefs = {
	Button: TextButton,
}

type HotbarPet = {
	Name: string,
	EventTag: string?,
}

local slots: { SlotRefs } = {}
local potionSlots: { PotionSlotRefs } = {}
local hotbarPets: { HotbarPet } = {}
local selectedSlots: { [number]: boolean } = {}
local lastPotionUseAt = 0

local SHORT_POTION_NAME: { [string]: string } = {
	luck = "Luck",
	sell = "Sell",
	super_luck = "S.Luck",
	super_sell = "S.Sell",
	super_bundle = "Bundle",
}

local SELECTED_COLOR = UiTheme.Colors.AccentCyan
local SELECTED_WASH = UiTheme.Colors.AccentPink
local NORMAL_STROKE = UiTheme.Colors.Stroke
local SELECTED_STROKE = UiTheme.Colors.AccentPink

local function readSelectedSlots(): { [number]: boolean }
	local selected: { [number]: boolean } = {}

	local packed = localPlayer:GetAttribute("EquippedPetSlots")
	if typeof(packed) == "string" and packed ~= "" then
		for piece in string.gmatch(packed, "[^,]+") do
			local slot = tonumber(piece)
			if typeof(slot) == "number" and slot >= 1 then
				selected[math.floor(slot)] = true
			end
		end
		return selected
	end

	local slot1 = localPlayer:GetAttribute("EquippedPetSlot")
	local slot2 = localPlayer:GetAttribute("EquippedPetSlot2")
	if typeof(slot1) == "number" and slot1 >= 1 then
		selected[math.floor(slot1)] = true
	end
	if typeof(slot2) == "number" and slot2 >= 1 then
		selected[math.floor(slot2)] = true
	end
	local slot3 = localPlayer:GetAttribute("EquippedPetSlot3")
	if typeof(slot3) == "number" and slot3 >= 1 then
		selected[math.floor(slot3)] = true
	end
	return selected
end

local function readPetsFromFolder(): { HotbarPet }
	local petsFolder = localPlayer:FindFirstChild("Pets")
	local pets = {}
	if petsFolder and petsFolder:IsA("Folder") then
		for _, child in ipairs(petsFolder:GetChildren()) do
			if child:IsA("StringValue") then
				local tagAttr = child:GetAttribute("EventTag")
				table.insert(pets, {
					Name = child.Value,
					EventTag = if typeof(tagAttr) == "string" and tagAttr ~= "" then tagAttr else nil,
				})
			end
		end
	end
	return pets
end

local function readPinnedInventoryIndices(): { number }
	local pinsFolder = localPlayer:FindFirstChild("HotbarPins")
	local pins = table.create(MAX_SLOTS, 0)
	local hasPin = false
	if pinsFolder and pinsFolder:IsA("Folder") then
		for _, child in ipairs(pinsFolder:GetChildren()) do
			if child:IsA("IntValue") then
				local slot = tonumber(child.Name)
				if typeof(slot) == "number" and slot >= 1 and slot <= MAX_SLOTS and child.Value > 0 then
					pins[slot] = child.Value
					hasPin = true
				end
			end
		end
	end
	return if hasPin then pins else {}
end

local function resolveHotbarPets(): { HotbarPet }
	local allPets = readPetsFromFolder()
	local pins = readPinnedInventoryIndices()
	local resolved: { HotbarPet } = {}

	if #pins > 0 then
		for slot = 1, MAX_SLOTS do
			local invIndex = pins[slot] or 0
			if invIndex >= 1 and invIndex <= #allPets then
				resolved[slot] = allPets[invIndex]
			end
		end
		return resolved
	end

	for index = 1, math.min(#allPets, MAX_SLOTS) do
		resolved[index] = allPets[index]
	end
	return resolved
end

local function requestEquip(slot: number)
	if slot < 1 or slot > MAX_SLOTS then
		return
	end
	if typeof(hotbarPets[slot]) ~= "table" or typeof(hotbarPets[slot].Name) ~= "string" then
		return
	end
	equipPetRemote:FireServer(slot)
end

local function requestUsePotion(potionId: string)
	if os.clock() - lastPotionUseAt < 0.35 then
		return
	end
	if PotionConfig.GetOwnedFromPlayer(localPlayer, potionId) <= 0 then
		return
	end
	lastPotionUseAt = os.clock()
	FeelSound.Play("Click", 0.45)
	usePotionRemote:FireServer(potionId)
end

local function isPotionChannelActive(def: PotionConfig.PotionDefinition): boolean
	for _, channel in ipairs(PotionConfig.GetChannels(def)) do
		local attrName = if channel == "luck" then "PotionLuckRemaining" else "PotionSellRemaining"
		local remaining = localPlayer:GetAttribute(attrName)
		if typeof(remaining) == "number" and remaining > 0.05 then
			return true
		end
	end
	return false
end

local function clearSlots()
	for _, refs in ipairs(slots) do
		refs.Button:Destroy()
	end
	table.clear(slots)
end

local function clearPotionSlots()
	for _, refs in ipairs(potionSlots) do
		refs.Button:Destroy()
	end
	table.clear(potionSlots)
end

local function createSlot(index: number, pet: HotbarPet): SlotRefs
	local petName = pet.Name
	local isSelected = selectedSlots[index] == true
	local definition = PetConfig.GetByName(petName)
	local rarity = if definition then definition.Rarity else "Common"
	local rarityColor = PetConfig.GetRarityColor(rarity)
	local wash = rarityColor:Lerp(Color3.fromRGB(255, 255, 255), 0.55)
	local fillColor = if isSelected
		then SELECTED_COLOR:Lerp(SELECTED_WASH, 0.35):Lerp(Color3.fromRGB(255, 255, 255), 0.25)
		else wash

	local button = UiTheme.Create("TextButton", {
		Name = string.format("Slot_%d", index),
		Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE),
		BackgroundColor3 = fillColor,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = index,
	}, hotbar) :: TextButton

	UiTheme.Corner(button, UiTheme.CornerButton)
	if isSelected then
		UiTheme.Gradient(button, Color3.fromRGB(180, 245, 255), SELECTED_WASH:Lerp(Color3.fromRGB(255, 255, 255), 0.35), 90)
	else
		UiTheme.Gradient(button, Color3.fromRGB(255, 255, 255), wash, 90)
	end

	local stroke = UiTheme.Stroke(
		button,
		if isSelected then SELECTED_STROKE else NORMAL_STROKE,
		if isSelected then 4 else 3,
		0
	)
	UiTheme.WireButtonMotion(button)

	local keyLabel = UiTheme.Label({
		Name = "Key",
		Parent = button,
		Position = UDim2.fromOffset(6, 2),
		Size = UDim2.fromOffset(20, 16),
		Text = tostring(index),
		Color = if isSelected then UiTheme.Colors.Text else UiTheme.Colors.TextDark,
		TextSize = 14,
		Font = UiTheme.FontTitle,
		XAlign = Enum.TextXAlignment.Left,
		Outlined = isSelected,
	}) :: TextLabel

	local iconHost = UiTheme.Create("Frame", {
		Name = "IconHost",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.42, 0),
		Size = UDim2.fromOffset(36, 36),
	}, button) :: Frame

	PetIconUi.Mount(iconHost, {
		PetName = petName,
		Rarity = rarity,
		Icon = if definition then definition.Icon else "🐾",
		Size = 36,
		EventTag = pet.EventTag,
	})

	local nameLabel = UiTheme.Create("TextLabel", {
		Name = "PetName",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, -8, 0, 14),
		Text = petName,
		TextColor3 = UiTheme.Colors.TextDark,
		TextSize = 11,
		Font = UiTheme.FontMedium,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, button) :: TextLabel
	if isSelected then
		nameLabel.TextColor3 = UiTheme.Colors.Text
		UiTheme.TextStroke(nameLabel, 1.8)
	end

	button.MouseButton1Click:Connect(function()
		requestEquip(index)
	end)

	return {
		Button = button,
		IconHost = iconHost,
		NameLabel = nameLabel,
		KeyLabel = keyLabel,
		Stroke = stroke,
	}
end

local function createPotionSlot(order: number, def: PotionConfig.PotionDefinition, owned: number): PotionSlotRefs
	local isActive = isPotionChannelActive(def)
	local variant = PotionConfig.GetButtonVariant(def)
	local fill = UiTheme.ButtonColor(variant :: UiTheme.ButtonVariant)
	local wash = fill:Lerp(Color3.fromRGB(255, 255, 255), 0.45)

	local button = UiTheme.Create("TextButton", {
		Name = "Potion_" .. def.Id,
		Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE),
		BackgroundColor3 = wash,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order,
	}, potionBar) :: TextButton

	UiTheme.Corner(button, UiTheme.CornerButton)
	if isActive then
		UiTheme.Gradient(button, Color3.fromRGB(180, 245, 255), SELECTED_WASH:Lerp(Color3.fromRGB(255, 255, 255), 0.35), 90)
	else
		UiTheme.Gradient(button, Color3.fromRGB(255, 255, 255), wash, 90)
	end
	UiTheme.Stroke(button, if isActive then SELECTED_STROKE else NORMAL_STROKE, if isActive then 4 else 3, 0)
	UiTheme.WireButtonMotion(button)

	UiIcon.Mount(button, {
		Key = def.IconKey,
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.42, 0),
		Size = UDim2.fromOffset(32, 32),
		ImageSize = 24,
	})

	local nameLabel = UiTheme.Create("TextLabel", {
		Name = "PotionName",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, -6, 0, 14),
		Text = SHORT_POTION_NAME[def.Id] or def.Name,
		TextColor3 = if isActive then UiTheme.Colors.Text else UiTheme.Colors.TextDark,
		TextSize = 11,
		Font = UiTheme.FontMedium,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, button) :: TextLabel
	if isActive then
		UiTheme.TextStroke(nameLabel, 1.8)
	end

	local countLabel = UiTheme.Create("TextLabel", {
		Name = "Count",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 2),
		Size = UDim2.fromOffset(28, 16),
		Text = tostring(owned),
		TextColor3 = UiTheme.Colors.Text,
		TextSize = 13,
		Font = UiTheme.FontTitle,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, button) :: TextLabel
	UiTheme.TextStroke(countLabel, 1.8)

	local potionId = def.Id
	button.MouseButton1Click:Connect(function()
		requestUsePotion(potionId)
	end)

	return {
		Button = button,
	}
end

local function refreshPotionBar(): number
	clearPotionSlots()

	local visibleCount = 0
	for _, def in ipairs(PotionConfig.Potions) do
		local owned = PotionConfig.GetOwnedFromPlayer(localPlayer, def.Id)
		if owned > 0 then
			visibleCount += 1
			table.insert(potionSlots, createPotionSlot(visibleCount, def, owned))
		end
	end

	if visibleCount == 0 then
		potionBar.Visible = false
		potionBar.Size = UDim2.fromOffset(0, SLOT_SIZE)
		return 0
	end

	local width = (SLOT_SIZE * visibleCount) + (SLOT_GAP * math.max(0, visibleCount - 1))
	potionBar.Size = UDim2.fromOffset(width, SLOT_SIZE)
	potionBar.Visible = true
	return visibleCount
end

local function refreshHotbar()
	hotbarPets = resolveHotbarPets()
	selectedSlots = readSelectedSlots()

	clearSlots()

	local visibleCount = 0
	for index = 1, MAX_SLOTS do
		local pet = hotbarPets[index]
		if pet and typeof(pet.Name) == "string" then
			visibleCount += 1
			slots[index] = createSlot(index, pet)
		end
	end

	if visibleCount == 0 then
		hotbar.Visible = false
		hotbar.Size = UDim2.fromOffset(0, SLOT_SIZE)
	else
		local width = (SLOT_SIZE * visibleCount) + (SLOT_GAP * math.max(0, visibleCount - 1))
		hotbar.Size = UDim2.fromOffset(width, SLOT_SIZE)
		hotbar.Visible = true
	end

	local potionCount = refreshPotionBar()
	local eqWidth = math.max(hotbar.Size.X.Offset, potionBar.Size.X.Offset)
	local eqHeight = 0
	if potionCount > 0 then
		eqHeight += SLOT_SIZE
	end
	if visibleCount > 0 then
		if eqHeight > 0 then
			eqHeight += SLOT_GAP
		end
		eqHeight += SLOT_SIZE
	end
	equipment.Size = UDim2.fromOffset(eqWidth, eqHeight)
	equipment.Visible = visibleCount > 0 or potionCount > 0
end

local KEY_TO_SLOT = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	local slot = KEY_TO_SLOT[input.KeyCode]
	if slot then
		requestEquip(slot)
	end
end)

local hotbarRefreshQueued = false
local function scheduleRefreshHotbar()
	if hotbarRefreshQueued then
		return
	end
	hotbarRefreshQueued = true
	task.defer(function()
		hotbarRefreshQueued = false
		refreshHotbar()
	end)
end

local function bindFolder(folder: Folder)
	folder.ChildAdded:Connect(function(child)
		if child:IsA("IntValue") then
			child:GetPropertyChangedSignal("Value"):Connect(function()
				scheduleRefreshHotbar()
			end)
		elseif child:IsA("StringValue") then
			child:GetAttributeChangedSignal("EventTag"):Connect(function()
				scheduleRefreshHotbar()
			end)
		end
		scheduleRefreshHotbar()
	end)
	folder.ChildRemoved:Connect(function()
		scheduleRefreshHotbar()
	end)
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("IntValue") then
			child:GetPropertyChangedSignal("Value"):Connect(function()
				scheduleRefreshHotbar()
			end)
		elseif child:IsA("StringValue") then
			child:GetAttributeChangedSignal("EventTag"):Connect(function()
				scheduleRefreshHotbar()
			end)
		end
	end
	refreshHotbar()
end

local function watchPlayerFolder(name: string)
	local existing = localPlayer:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		bindFolder(existing)
	end
end

watchPlayerFolder("Pets")
watchPlayerFolder("HotbarPins")

localPlayer.ChildAdded:Connect(function(child)
	if (child.Name == "Pets" or child.Name == "HotbarPins") and child:IsA("Folder") then
		bindFolder(child)
	end
end)

localPlayer:GetAttributeChangedSignal("EquippedPetSlot"):Connect(refreshHotbar)
localPlayer:GetAttributeChangedSignal("EquippedPetSlot2"):Connect(refreshHotbar)
localPlayer:GetAttributeChangedSignal("EquippedPetSlot3"):Connect(refreshHotbar)
localPlayer:GetAttributeChangedSignal("EquippedPetSlots"):Connect(refreshHotbar)
localPlayer:GetAttributeChangedSignal("EquippedPetCount"):Connect(refreshHotbar)
localPlayer:GetAttributeChangedSignal("Map2Unlocked"):Connect(refreshHotbar)
localPlayer:GetAttributeChangedSignal("Map3Unlocked"):Connect(refreshHotbar)

for _, attrName in PotionConfig.CountAttributes do
	localPlayer:GetAttributeChangedSignal(attrName):Connect(scheduleRefreshHotbar)
end
localPlayer:GetAttributeChangedSignal("PotionLuckRemaining"):Connect(scheduleRefreshHotbar)
localPlayer:GetAttributeChangedSignal("PotionSellRemaining"):Connect(scheduleRefreshHotbar)

refreshHotbar()
