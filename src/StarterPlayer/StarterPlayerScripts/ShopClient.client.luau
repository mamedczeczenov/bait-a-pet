--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local BaitConfig = require(Modules:WaitForChild("BaitConfig"))
local EventConfig = require(Modules:WaitForChild("EventConfig"))
local FeelSound = require(Modules:WaitForChild("FeelSound"))
local InventoryUi = require(Modules:WaitForChild("InventoryUi"))
local NumberFormat = require(Modules:WaitForChild("NumberFormat"))
local PetConfig = require(Modules:WaitForChild("PetConfig"))
local PotionConfig = require(Modules:WaitForChild("PotionConfig"))
local IconAssets = require(Modules:WaitForChild("IconAssets"))
local PetIconUi = require(Modules:WaitForChild("PetIconUi"))
local UiIcon = require(Modules:WaitForChild("UiIcon"))
local UiTheme = require(Modules:WaitForChild("UiTheme"))
local UiToast = require(Modules:WaitForChild("UiToast"))
local PlaceConfig = require(Modules:WaitForChild("PlaceConfig"))
local HudLuck = require(Modules:WaitForChild("HudLuck"))
local RobuxPurchase = require(Modules:WaitForChild("RobuxPurchase"))
PetConfig.EnsureLoaded(30)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local openShopRemote = remotes:WaitForChild("OpenShop") :: RemoteEvent
local buyItemRemote = remotes:WaitForChild("BuyItem") :: RemoteEvent
local sellPetRemote = remotes:WaitForChild("SellPet") :: RemoteEvent
local sellAllPetsRemote = remotes:WaitForChild("SellAllPets") :: RemoteEvent
local sellBulkPetsRemote = remotes:WaitForChild("SellBulkPets") :: RemoteEvent
local togglePetLockRemote = remotes:WaitForChild("TogglePetLock") :: RemoteEvent
local toggleHotbarPinRemote = remotes:WaitForChild("ToggleHotbarPin") :: RemoteEvent
local equipPetRemote = remotes:WaitForChild("EquipPet") :: RemoteEvent
local shopResultRemote = remotes:WaitForChild("ShopResult") :: RemoteEvent
local setCompanionRemote = remotes:WaitForChild("SetCompanion") :: RemoteEvent
local companionResultRemote = remotes:WaitForChild("CompanionResult") :: RemoteEvent
local usePotionRemote = remotes:WaitForChild("UsePotion") :: RemoteEvent

type ShopItemPayload = {
	Id: string,
	Name: string,
	Kind: string,
	Price: number,
	RobuxPrice: number?,
	ProductId: number?,
	BaitId: string,
	LuckMultiplier: number,
	CatchSpeed: number?,
	Icon: string,
	Description: string,
	Owned: boolean?,
	Color: any,
}

type ActiveBaitPayload = {
	Id: string,
	Name: string,
	LuckMultiplier: number,
	CatchSpeed: number?,
	Icon: string,
}

type PetPayload = {
	Index: number,
	Name: string,
	Rarity: string,
	OneIn: number?,
	SellPrice: number,
	Icon: string,
	Description: string,
	Locked: boolean?,
	HotbarSlot: number?,
	EventTag: string?,
}

local currentTab = "Buy"
local currentItems: { ShopItemPayload } = {}
local currentPets: { PetPayload } = {}
local currentActiveBait: ActiveBaitPayload = {
	Id = "basic",
	Name = "Basic Bait",
	LuckMultiplier = 1,
	CatchSpeed = 1,
	Icon = "🪱",
}

local currentSortMode = InventoryUi.SortModes[1]
local currentBulkRarity = InventoryUi.BulkRarities[1]
local lastPotionUseAt = 0

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

local function create(className: string, props: { [string]: any }, parent: Instance?): Instance
	return UiTheme.Create(className, props, parent)
end

local function cycleSortMode(): string
	local modes = InventoryUi.SortModes
	local index = table.find(modes, currentSortMode) or 1
	currentSortMode = modes[(index % #modes) + 1]
	return currentSortMode
end

local function cycleBulkRarity(): string
	local rarities = InventoryUi.BulkRarities
	local index = table.find(rarities, currentBulkRarity) or 1
	currentBulkRarity = rarities[(index % #rarities) + 1]
	return currentBulkRarity
end

local function getSortedPets(): { PetPayload }
	return InventoryUi.SortPets(currentPets, currentSortMode)
end

local function petLabel(pet: PetPayload): string
	local tagBit = if typeof(pet.EventTag) == "string" and pet.EventTag ~= ""
		then string.format(" · %s", pet.EventTag)
		else ""
	return string.format(
		"%s  [%s%s%s]",
		pet.Name,
		pet.Rarity,
		if typeof(pet.OneIn) == "number" and pet.OneIn > 0 then string.format(" · 1/%d", pet.OneIn) else "",
		tagBit
	)
end

local function getWorldSellMult(): number
	local folder = ReplicatedStorage:FindFirstChild("WorldEventState")
	if folder and folder:IsA("Folder") then
		local active = folder:FindFirstChild("Active")
		local sell = folder:FindFirstChild("SellMult")
		if active and active:IsA("BoolValue") and active.Value and sell and sell:IsA("NumberValue") then
			return math.max(1, sell.Value)
		end
	end
	return 1
end

local function isPetLocked(pet: PetPayload): boolean
	return pet.Locked == true
end

local function createLockButton(parent: Frame, pet: PetPayload, position: UDim2, size: UDim2): TextButton
	local locked = isPetLocked(pet)
	local button = create("TextButton", {
		Name = "Lock",
		Position = position,
		Size = size,
		BackgroundColor3 = if locked then UiTheme.Colors.AccentAmberDim else UiTheme.Colors.BgMuted,
		BorderSizePixel = 0,
		Text = "",
		TextColor3 = UiTheme.Colors.Text,
		TextSize = 16,
		Font = UiTheme.FontTitle,
		ZIndex = 2,
	}, parent) :: TextButton
	UiTheme.Corner(button, UiTheme.CornerSmall)
	UiTheme.Stroke(button, UiTheme.Colors.Stroke, 3, 0)
	UiTheme.WireButtonMotion(button)
	UiIcon.ApplyToButton(button, if locked then "inv_lock" else "inv_unlock", 18)

	local petIndex = pet.Index
	button.MouseButton1Click:Connect(function()
		togglePetLockRemote:FireServer(petIndex)
	end)

	return button
end

local function createPinButton(parent: Frame, pet: PetPayload, position: UDim2, size: UDim2): TextButton
	local slot = pet.HotbarSlot
	local pinned = typeof(slot) == "number" and slot > 0
	local button = create("TextButton", {
		Name = "Pin",
		Position = position,
		Size = size,
		BackgroundColor3 = if pinned then UiTheme.Colors.AccentCyanDim else UiTheme.Colors.BgMuted,
		BorderSizePixel = 0,
		Text = if pinned then tostring(slot) else "",
		TextColor3 = UiTheme.Colors.Text,
		TextSize = 14,
		Font = UiTheme.FontTitle,
		ZIndex = 2,
	}, parent) :: TextButton
	UiTheme.Corner(button, UiTheme.CornerSmall)
	UiTheme.Stroke(button, UiTheme.Colors.Stroke, 3, 0)
	if pinned then
		UiTheme.TextStroke(button, 2)
	else
		UiIcon.ApplyToButton(button, "inv_pin", 16)
	end
	UiTheme.WireButtonMotion(button)

	local petIndex = pet.Index
	button.MouseButton1Click:Connect(function()
		toggleHotbarPinRemote:FireServer(petIndex)
	end)

	return button
end

local function isInventoryPetHeld(pet: PetPayload): boolean
	local packed = localPlayer:GetAttribute("EquippedPetSlots")
	local hotbarSlot = pet.HotbarSlot
	if typeof(hotbarSlot) ~= "number" or hotbarSlot < 1 then
		-- Fallback mapping: no pins → hotbar slot == inventory index.
		hotbarSlot = pet.Index
	end
	if typeof(packed) == "string" and packed ~= "" then
		for piece in string.gmatch(packed, "[^,]+") do
			if tonumber(piece) == hotbarSlot then
				return true
			end
		end
	end
	local slot1 = localPlayer:GetAttribute("EquippedPetSlot")
	local slot2 = localPlayer:GetAttribute("EquippedPetSlot2")
	local slot3 = localPlayer:GetAttribute("EquippedPetSlot3")
	return slot1 == hotbarSlot or slot2 == hotbarSlot or slot3 == hotbarSlot
end

local function createHoldButton(parent: Frame, pet: PetPayload, position: UDim2, size: UDim2): TextButton
	local held = isInventoryPetHeld(pet)
	local button = create("TextButton", {
		Name = "Hold",
		Position = position,
		Size = size,
		BackgroundColor3 = if held then UiTheme.Colors.AccentGreen else UiTheme.Colors.BgMuted,
		BorderSizePixel = 0,
		-- Carry = pets in hands (max 2 after Map 2, max 3 after Map 3). Walk = companion follower.
		Text = if held then "ON" else "Carry",
		TextColor3 = UiTheme.Colors.Text,
		TextSize = 12,
		Font = UiTheme.FontTitle,
		ZIndex = 2,
	}, parent) :: TextButton
	UiTheme.Corner(button, UiTheme.CornerSmall)
	UiTheme.Stroke(button, UiTheme.Colors.Stroke, 3, 0)
	if held then
		UiTheme.TextStroke(button, 2)
	end
	UiTheme.WireButtonMotion(button)

	local petIndex = pet.Index
	button.MouseButton1Click:Connect(function()
		equipPetRemote:FireServer({ InventoryIndex = petIndex })
	end)

	return button
end

local screenGui = create("ScreenGui", {
	Name = "ShopGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 20,
}, playerGui) :: ScreenGui
UiTheme.MobileScale(screenGui)
if PlaceConfig.IsAfkPlace() then
	screenGui.Enabled = false
end

local root = create("Frame", {
	Name = "Root",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Active = false,
	ZIndex = 1,
}, screenGui) :: Frame

-- Left-middle candy HUD chips.
local hudStack = create("Frame", {
	Name = "HudStack",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 18, 0.5, 0),
	Size = UDim2.fromOffset(158, 266),
	BackgroundTransparency = 1,
	Active = false,
	ZIndex = 2,
}, root) :: Frame

local HUD_CHIP_WIDTH = 158
local HUD_CHIP_HEIGHT = 56
local HUD_CHIP_GAP = 14
local HUD_ROW = HUD_CHIP_HEIGHT + HUD_CHIP_GAP

local luckHud = create("Frame", {
	Name = "LuckHud",
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.fromOffset(HUD_CHIP_WIDTH, HUD_CHIP_HEIGHT),
	BackgroundColor3 = UiTheme.Colors.AccentAmber,
	BorderSizePixel = 0,
}, hudStack) :: Frame
UiTheme.Corner(luckHud, UiTheme.CornerChip)
UiTheme.Stroke(luckHud, UiTheme.Colors.Stroke, 4, 0)
UiTheme.Gradient(luckHud, Color3.fromRGB(255, 230, 120), UiTheme.Colors.AccentAmberDim, 90)

UiIcon.Mount(luckHud, {
	Key = "station_upgrade_luck",
	Name = "Icon",
	Position = UDim2.fromOffset(4, 4),
	Size = UDim2.fromOffset(48, 48),
	ImageSize = 34,
})

local luckAmount = create("TextLabel", {
	Name = "Amount",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(52, 10),
	Size = UDim2.fromOffset(100, 36),
	Text = "1x",
	TextColor3 = UiTheme.Colors.Text,
	TextSize = 22,
	Font = UiTheme.FontTitle,
	TextXAlignment = Enum.TextXAlignment.Left,
}, luckHud) :: TextLabel
UiTheme.TextStroke(luckAmount, 2.6)

local moneyHud = create("Frame", {
	Name = "MoneyHud",
	Position = UDim2.fromOffset(0, HUD_ROW),
	Size = UDim2.fromOffset(HUD_CHIP_WIDTH, HUD_CHIP_HEIGHT),
	BackgroundColor3 = UiTheme.Colors.AccentGreen,
	BorderSizePixel = 0,
}, hudStack) :: Frame
UiTheme.Corner(moneyHud, UiTheme.CornerChip)
UiTheme.Stroke(moneyHud, UiTheme.Colors.Stroke, 4, 0)
UiTheme.Gradient(moneyHud, Color3.fromRGB(160, 255, 170), UiTheme.Colors.AccentGreenHot, 90)

UiIcon.Mount(moneyHud, {
	Key = "hud_coins",
	Name = "Icon",
	Position = UDim2.fromOffset(4, 4),
	Size = UDim2.fromOffset(48, 48),
	ImageSize = 34,
})

local moneyAmount = create("TextLabel", {
	Name = "Amount",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(52, 10),
	Size = UDim2.fromOffset(100, 36),
	Text = "0",
	TextColor3 = UiTheme.Colors.Text,
	TextSize = 26,
	Font = UiTheme.FontTitle,
	TextXAlignment = Enum.TextXAlignment.Left,
}, moneyHud) :: TextLabel
UiTheme.TextStroke(moneyAmount, 2.6)

local petsHudButton = create("TextButton", {
	Name = "PetsHud",
	Position = UDim2.fromOffset(0, HUD_ROW * 2),
	Size = UDim2.fromOffset(HUD_CHIP_WIDTH, HUD_CHIP_HEIGHT),
	BackgroundColor3 = UiTheme.Colors.AccentPink,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
}, hudStack) :: TextButton
UiTheme.Corner(petsHudButton, UiTheme.CornerChip)
UiTheme.Stroke(petsHudButton, UiTheme.Colors.Stroke, 4, 0)
UiTheme.Gradient(petsHudButton, Color3.fromRGB(255, 160, 220), UiTheme.Colors.AccentPinkHot, 90)
UiTheme.WireButtonMotion(petsHudButton)

UiIcon.Mount(petsHudButton, {
	Key = "hud_pets",
	Name = "Icon",
	Position = UDim2.fromOffset(4, 4),
	Size = UDim2.fromOffset(48, 48),
	ImageSize = 34,
})

local petsCountLabel = create("TextLabel", {
	Name = "Count",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(52, 10),
	Size = UDim2.fromOffset(100, 36),
	Text = "0/30",
	TextColor3 = UiTheme.Colors.Text,
	TextSize = 22,
	Font = UiTheme.FontTitle,
	TextXAlignment = Enum.TextXAlignment.Left,
}, petsHudButton) :: TextLabel
UiTheme.TextStroke(petsCountLabel, 2.6)

local inventoryPanel = UiTheme.Panel({
	Name = "InventoryPanel",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 190, 0.5, 0),
	Size = UDim2.fromOffset(400, 460),
	Parent = root,
	Visible = false,
	ZIndex = 5,
})

local inventoryTitleLabel = UiTheme.Label({
	Name = "Title",
	Parent = inventoryPanel,
	Position = UDim2.fromOffset(16, 12),
	Size = UDim2.fromOffset(280, 32),
	Text = "Backpack 0/30",
	TextSize = 22,
	Font = UiTheme.FontTitle,
	Color = UiTheme.Colors.Text,
	Outlined = true,
	ZIndex = 6,
})

local inventoryClose = UiTheme.Button({
	Name = "Close",
	Parent = inventoryPanel,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromOffset(384, 10),
	Size = UDim2.fromOffset(36, 36),
	Text = "",
	TextSize = 18,
	Variant = "danger",
	ZIndex = 6,
}) :: TextButton
UiIcon.ApplyToButton(inventoryClose, "btn_close", 22)

local companionStatusLabel = create("TextLabel", {
	Name = "CompanionStatus",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 58),
	Size = UDim2.fromOffset(368, 18),
	Text = "Companion: none (fuse at Maszyna do petów)",
	TextColor3 = UiTheme.Colors.TextDark,
	TextSize = 13,
	Font = UiTheme.FontMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 6,
}, inventoryPanel) :: TextLabel

local inventoryToolbar = create("Frame", {
	Name = "Toolbar",
	Position = UDim2.fromOffset(12, 82),
	Size = UDim2.fromOffset(376, 36),
	BackgroundTransparency = 1,
	ZIndex = 6,
}, inventoryPanel) :: Frame

local inventorySortButton = UiTheme.Button({
	Name = "Sort",
	Parent = inventoryToolbar,
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.fromOffset(160, 36),
	Text = string.format("Sort: %s", currentSortMode),
	TextSize = 14,
	Variant = "blue",
	ZIndex = 6,
}) :: TextButton

local inventoryList = create("ScrollingFrame", {
	Name = "List",
	Position = UDim2.fromOffset(12, 126),
	Size = UDim2.fromOffset(376, 318),
	BackgroundColor3 = UiTheme.Colors.BgDeep,
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromOffset(0, 0),
	ZIndex = 6,
}, inventoryPanel) :: ScrollingFrame

UiTheme.StyleScrollingFrame(inventoryList)
UiTheme.Corner(inventoryList, UiTheme.CornerSmall)
UiTheme.Stroke(inventoryList, UiTheme.Colors.StrokeSoft, 2, 0.35)

local inventoryLayout = create("UIListLayout", {
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, inventoryList) :: UIListLayout

UiTheme.EnsureScrollPadding(inventoryList, 72)

local panel = UiTheme.Panel({
	Name = "ShopPanel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(720, 460),
	Parent = root,
	Visible = false,
	ZIndex = 10,
})

local title = UiTheme.Label({
	Name = "Title",
	Parent = panel,
	Position = UDim2.fromOffset(20, 12),
	Size = UDim2.fromOffset(200, 34),
	Text = "Pet Shop",
	TextSize = 28,
	Font = UiTheme.FontTitle,
	Color = UiTheme.Colors.Text,
	Outlined = true,
	ZIndex = 11,
}) :: TextLabel

local balanceLabel = create("TextLabel", {
	Name = "Balance",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(220, 16),
	Size = UDim2.fromOffset(390, 26),
	Text = "Coins: 0 | Basic Bait ∞",
	TextColor3 = UiTheme.Colors.Text,
	TextSize = 16,
	Font = UiTheme.FontTitle,
	TextXAlignment = Enum.TextXAlignment.Right,
	ZIndex = 11,
}, panel) :: TextLabel
UiTheme.TextStroke(balanceLabel, 2.2)

local closeButton = UiTheme.Button({
	Name = "Close",
	Parent = panel,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromOffset(700, 10),
	Size = UDim2.fromOffset(40, 40),
	Text = "",
	TextSize = 20,
	Variant = "danger",
	ZIndex = 11,
}) :: TextButton
UiIcon.ApplyToButton(closeButton, "btn_close", 24)

local buyTab = UiTheme.Button({
	Name = "BuyTab",
	Parent = panel,
	Position = UDim2.fromOffset(20, 62),
	Size = UDim2.fromOffset(110, 34),
	Text = "Buy",
	TextSize = 16,
	Variant = "green",
	ZIndex = 11,
}) :: TextButton

local sellTab = UiTheme.Button({
	Name = "SellTab",
	Parent = panel,
	Position = UDim2.fromOffset(140, 62),
	Size = UDim2.fromOffset(110, 34),
	Text = "Sell",
	TextSize = 16,
	Variant = "pink",
	ZIndex = 11,
}) :: TextButton

local statusLabel = create("TextLabel", {
	Name = "Status",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 104),
	Size = UDim2.fromOffset(680, 22),
	Text = "Unlock better bait once — coins or Robux.",
	TextColor3 = UiTheme.Colors.TextDark,
	TextSize = 15,
	Font = UiTheme.FontBody,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 11,
}, panel) :: TextLabel

local listFrame = create("ScrollingFrame", {
	Name = "List",
	Position = UDim2.fromOffset(20, 132),
	Size = UDim2.fromOffset(680, 308),
	BackgroundColor3 = UiTheme.Colors.BgDeep,
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromOffset(0, 0),
	ZIndex = 11,
}, panel) :: ScrollingFrame

UiTheme.StyleScrollingFrame(listFrame)
UiTheme.Corner(listFrame, UiTheme.CornerButton)
UiTheme.Stroke(listFrame, UiTheme.Colors.StrokeSoft, 2, 0.35)

local listLayout = create("UIListLayout", {
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, listFrame) :: UIListLayout

UiTheme.EnsureScrollPadding(listFrame, 72)

-- Confirm sell-all modal (above shop panel content).
local confirmOverlay = create("Frame", {
	Name = "ConfirmOverlay",
	BackgroundColor3 = Color3.fromRGB(40, 50, 70),
	BackgroundTransparency = 0.35,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 100,
}, root) :: Frame

local confirmDialog = create("Frame", {
	Name = "ConfirmDialog",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(380, 190),
	BackgroundColor3 = UiTheme.Colors.BgRaised,
	BorderSizePixel = 0,
	ZIndex = 101,
}, confirmOverlay) :: Frame

UiTheme.Corner(confirmDialog, UiTheme.CornerPanel)
UiTheme.Stroke(confirmDialog, UiTheme.Colors.Stroke, 4, 0)

create("TextLabel", {
	Name = "Title",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 18),
	Size = UDim2.fromOffset(340, 28),
	Text = "Sell all unlocked pets?",
	TextColor3 = UiTheme.Colors.TextDark,
	TextSize = 22,
	Font = UiTheme.FontTitle,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 102,
}, confirmDialog)

local confirmBody = create("TextLabel", {
	Name = "Body",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 56),
	Size = UDim2.fromOffset(340, 56),
	Text = "",
	TextColor3 = UiTheme.Colors.TextDim,
	TextSize = 16,
	Font = UiTheme.FontBody,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 102,
}, confirmDialog) :: TextLabel

local confirmYes = UiTheme.Button({
	Name = "Yes",
	Parent = confirmDialog,
	Position = UDim2.fromOffset(20, 130),
	Size = UDim2.fromOffset(160, 40),
	Text = "Yes",
	TextSize = 16,
	Variant = "green",
	ZIndex = 102,
}) :: TextButton

local confirmCancel = UiTheme.Button({
	Name = "Cancel",
	Parent = confirmDialog,
	Position = UDim2.fromOffset(200, 130),
	Size = UDim2.fromOffset(160, 40),
	Text = "Cancel",
	TextSize = 16,
	Variant = "muted",
	ZIndex = 102,
}) :: TextButton

local function hideConfirmDialog()
	confirmOverlay.Visible = false
end

local function showConfirmDialog()
	local count, value = InventoryUi.CountSellable(currentPets)
	if count <= 0 then
		statusLabel.Text = "No unlocked pets to sell."
		return
	end

	confirmBody.Text = string.format(
		"This will sell %d unlocked pet%s for %s coins. Locked pets are kept.",
		count,
		if count == 1 then "" else "s",
		NumberFormat.FormatCoins(value)
	)
	confirmOverlay.Visible = true
	UiTheme.BounceIn(confirmDialog, 0.7)
end

confirmYes.MouseButton1Click:Connect(function()
	hideConfirmDialog()
	sellAllPetsRemote:FireServer(true)
end)

confirmCancel.MouseButton1Click:Connect(function()
	hideConfirmDialog()
end)

local function getTotalSellValue(): number
	local _, value = InventoryUi.CountSellable(currentPets)
	return value
end

local function setBalances(coins: number, activeBait: ActiveBaitPayload?)
	moneyAmount.Text = NumberFormat.FormatCoins(math.floor(coins))
	local bait = activeBait or currentActiveBait
	luckAmount.Text = NumberFormat.FormatLuck(HudLuck.GetTotal(localPlayer, bait.LuckMultiplier))
	balanceLabel.Text = string.format("Coins: %s | %s ∞", NumberFormat.FormatCoins(coins), bait.Name)
end

local function clearInventoryList()
	for _, child in ipairs(inventoryList:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
end

local function updateSortButtons()
	inventorySortButton.Text = string.format("Sort: %s", currentSortMode)
end

local function readUnlockedCompanions(): { string }
	local names = {}
	local folder = localPlayer:FindFirstChild("UnlockedCompanions")
	if folder and folder:IsA("Folder") then
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("BoolValue") and child.Value == true then
				table.insert(names, child.Name)
			end
		end
	end
	table.sort(names, function(a, b)
		local defA = PetConfig.GetByName(a)
		local defB = PetConfig.GetByName(b)
		local ai = table.find(PetConfig.RarityOrder, if defA then defA.Rarity else "Common") or 0
		local bi = table.find(PetConfig.RarityOrder, if defB then defB.Rarity else "Common") or 0
		if ai ~= bi then
			return ai > bi
		end
		return a < b
	end)
	return names
end

local function getActiveCompanionNames(): { string }
	local names: { string } = {}
	local packed = localPlayer:GetAttribute("CompanionPetNames")
	if typeof(packed) == "string" and packed ~= "" then
		for piece in string.gmatch(packed, "[^,]+") do
			local trimmed = string.gsub(piece, "^%s*(.-)%s*$", "%1")
			if trimmed ~= "" then
				table.insert(names, trimmed)
			end
		end
		if #names > 0 then
			return names
		end
	end

	local primary = localPlayer:GetAttribute("CompanionPetName")
	local secondary = localPlayer:GetAttribute("CompanionPetName2")
	if typeof(primary) == "string" and primary ~= "" then
		table.insert(names, primary)
	end
	if typeof(secondary) == "string" and secondary ~= "" then
		table.insert(names, secondary)
	end
	return names
end

local function getActiveCompanionName(): string
	return getActiveCompanionNames()[1] or ""
end

local function isCompanionWalking(petName: string): boolean
	for _, name in ipairs(getActiveCompanionNames()) do
		if name == petName then
			return true
		end
	end
	return false
end

local function getCompanionWalkMax(): number
	local maxAttr = localPlayer:GetAttribute("CompanionWalkMax")
	if typeof(maxAttr) == "number" and maxAttr >= 2 then
		return 2
	end
	if localPlayer:GetAttribute("Map2Unlocked") == true then
		return 2
	end
	local maxEquip = localPlayer:GetAttribute("MaxEquippedPets")
	if typeof(maxEquip) == "number" and maxEquip >= 2 then
		return 2
	end
	return 1
end

local function updateCompanionStatusLabel()
	local activeNames = getActiveCompanionNames()
	local luck = localPlayer:GetAttribute("CompanionLuckMult")
	local sell = localPlayer:GetAttribute("CompanionSellMult")
	local maxWalk = getCompanionWalkMax()
	if #activeNames > 0 then
		local luckN = if typeof(luck) == "number" then luck else 1
		local sellN = if typeof(sell) == "number" then sell else 1
		companionStatusLabel.Text = string.format(
			"Walking %d/%d: %s  ·  luck %.2fx  ·  sell %.2fx",
			#activeNames,
			maxWalk,
			table.concat(activeNames, " + "),
			luckN,
			sellN
		)
	else
		companionStatusLabel.Text = string.format(
			"Companion: none (Walk max %d%s)",
			maxWalk,
			if maxWalk < 2 then " — unlock Map 2 for 2" else ""
		)
	end
end

local function createWalkButton(parent: Frame, petName: string, position: UDim2, size: UDim2, isActive: boolean): TextButton
	local button = create("TextButton", {
		Name = "Walk",
		Position = position,
		Size = size,
		BackgroundColor3 = if isActive then UiTheme.Colors.AccentGreen else UiTheme.Colors.AccentBlue,
		BorderSizePixel = 0,
		Text = "",
		TextColor3 = UiTheme.Colors.Text,
		TextSize = 12,
		Font = UiTheme.FontTitle,
		ZIndex = 2,
		AutoButtonColor = true,
	}, parent) :: TextButton
	UiTheme.Corner(button, UiTheme.CornerSmall)
	UiTheme.Stroke(button, UiTheme.Colors.Stroke, 3, 0)
	if isActive then
		UiTheme.Gradient(button, Color3.fromRGB(140, 255, 150), UiTheme.Colors.AccentGreenHot, 90)
		UiIcon.ApplyToButton(button, "ui_check", 18)
	else
		UiTheme.Gradient(button, Color3.fromRGB(140, 190, 255), Color3.fromRGB(50, 120, 240), 90)
		UiIcon.ApplyToButton(button, "inv_walk", 18)
	end
	UiTheme.WireButtonMotion(button)

	button.MouseButton1Click:Connect(function()
		setCompanionRemote:FireServer(petName)
	end)

	return button
end

local function getBagCapacity(): number
	local capacity = localPlayer:GetAttribute("BagCapacity")
	if typeof(capacity) == "number" and capacity > 0 then
		return math.floor(capacity)
	end
	return 30
end

local function updateBagCapacityLabels()
	local count = #currentPets
	local capacity = getBagCapacity()
	petsCountLabel.Text = string.format("%d/%d", count, capacity)
	inventoryTitleLabel.Text = string.format("Backpack %d/%d", count, capacity)
end

local function appendPotionInventoryRows(layoutOrder: number): number
	local totalOwned = 0
	for _, def in ipairs(PotionConfig.Potions) do
		totalOwned += PotionConfig.GetOwnedFromPlayer(localPlayer, def.Id)
	end

	layoutOrder += 1
	create("TextLabel", {
		Name = "PotionsHeader",
		Size = UDim2.new(1, -8, 0, 22),
		BackgroundTransparency = 1,
		Text = string.format("Potions %d", totalOwned),
		TextColor3 = UiTheme.Colors.TextDark,
		TextSize = 13,
		Font = UiTheme.FontMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = layoutOrder,
	}, inventoryList)

	if totalOwned <= 0 then
		layoutOrder += 1
		create("TextLabel", {
			Name = "PotionsEmpty",
			Size = UDim2.new(1, -8, 0, 36),
			BackgroundTransparency = 1,
			Text = "No potions yet — buy them at Upgrades, then use from here or the hotbar.",
			TextColor3 = UiTheme.Colors.TextDim,
			TextSize = 13,
			Font = UiTheme.FontBody,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			LayoutOrder = layoutOrder,
		}, inventoryList)
		return layoutOrder
	end

	for _, def in ipairs(PotionConfig.Potions) do
		local owned = PotionConfig.GetOwnedFromPlayer(localPlayer, def.Id)
		if owned <= 0 then
			continue
		end

		layoutOrder += 1
		local variant = PotionConfig.GetButtonVariant(def)
		local row = UiTheme.Row({
			Name = "Potion_" .. def.Id,
			Parent = inventoryList,
			Size = UDim2.new(1, -8, 0, 56),
			LayoutOrder = layoutOrder,
			RarityColor = UiTheme.ButtonColor(variant :: UiTheme.ButtonVariant),
		})

		UiIcon.Mount(row, {
			Key = def.IconKey,
			Name = "Icon",
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(40, 40),
			ImageSize = 28,
		})

		create("TextLabel", {
			Name = "Name",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(52, 6),
			Size = UDim2.fromOffset(196, 44),
			Text = string.format("%s  x%d\n%s", def.Name, owned, def.Description),
			TextColor3 = UiTheme.Colors.TextDark,
			TextSize = 13,
			Font = UiTheme.FontTitle,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
		}, row)

		local useButton = UiTheme.Button({
			Name = "Use",
			Parent = row,
			Position = UDim2.fromOffset(256, 12),
			Size = UDim2.fromOffset(96, 32),
			Text = "Use",
			TextSize = 14,
			Variant = "primary",
			ZIndex = 2,
		}) :: TextButton

		local potionId = def.Id
		useButton.MouseButton1Click:Connect(function()
			requestUsePotion(potionId)
		end)
	end

	return layoutOrder
end

local function renderInventoryPanel()
	clearInventoryList()
	updateBagCapacityLabels()
	updateSortButtons()
	updateCompanionStatusLabel()

	local layoutOrder = appendPotionInventoryRows(0)
	local unlockedCompanions = readUnlockedCompanions()
	local unlockedSet: { [string]: boolean } = {}
	for _, name in ipairs(unlockedCompanions) do
		unlockedSet[name] = true
	end
	local walkMax = getCompanionWalkMax()

	if #unlockedCompanions > 0 then
		layoutOrder += 1
		create("TextLabel", {
			Name = "CompanionsHeader",
			Size = UDim2.new(1, -8, 0, 22),
			BackgroundTransparency = 1,
			Text = string.format("Companions (Walk followers, max %d)", walkMax),
			TextColor3 = UiTheme.Colors.TextDark,
			TextSize = 13,
			Font = UiTheme.FontMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = layoutOrder,
		}, inventoryList)

		for _, petName in ipairs(unlockedCompanions) do
			layoutOrder += 1
			local definition = PetConfig.GetByName(petName)
			local rarity = if definition then definition.Rarity else "Common"
			local icon = if definition then definition.Icon else "🐾"
			local isActive = isCompanionWalking(petName)
			local rarityWash = PetConfig.GetRarityColor(rarity)

			local row = UiTheme.Row({
				Name = "Companion_" .. petName,
				Parent = inventoryList,
				Size = UDim2.new(1, -8, 0, 52),
				LayoutOrder = layoutOrder,
				RarityColor = if isActive then UiTheme.Colors.AccentGreen else rarityWash,
			})

			local iconHost = create("Frame", {
				Name = "IconHost",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(8, 6),
				Size = UDim2.fromOffset(40, 40),
			}, row) :: Frame

			PetIconUi.Mount(iconHost, {
				PetName = petName,
				Rarity = rarity,
				Icon = icon,
				Size = 40,
			})

			create("TextLabel", {
				Name = "Name",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(56, 6),
				Size = UDim2.fromOffset(220, 40),
				Text = string.format("%s\n%s", petName, rarity),
				TextColor3 = UiTheme.Colors.TextDark,
				TextSize = 14,
				Font = UiTheme.FontTitle,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}, row)

			createWalkButton(row, petName, UDim2.fromOffset(288, 10), UDim2.fromOffset(64, 32), isActive)
		end

		layoutOrder += 1
		create("TextLabel", {
			Name = "PetsHeader",
			Size = UDim2.new(1, -8, 0, 22),
			BackgroundTransparency = 1,
			Text = string.format("Inventory %d/%d", #currentPets, getBagCapacity()),
			TextColor3 = UiTheme.Colors.TextDark,
			TextSize = 13,
			Font = UiTheme.FontMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = layoutOrder,
		}, inventoryList)
	end

	if #currentPets == 0 then
		UiTheme.AddScrollSpacer(inventoryList, layoutOrder + 1)
		UiTheme.QueueScrollCanvas(inventoryList)
		return
	end

	for _, pet in ipairs(getSortedPets()) do
		layoutOrder += 1
		local canWalk = unlockedSet[pet.Name] == true
		local isActive = isCompanionWalking(pet.Name)

		local row = UiTheme.Row({
			Name = string.format("Inv_%d", pet.Index),
			Parent = inventoryList,
			Size = UDim2.new(1, -8, 0, 56),
			LayoutOrder = layoutOrder,
			RarityColor = PetConfig.GetRarityColor(pet.Rarity),
		})

		local iconHost = create("Frame", {
			Name = "IconHost",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(40, 40),
		}, row) :: Frame

			PetIconUi.Mount(iconHost, {
				PetName = pet.Name,
				Rarity = pet.Rarity,
				Icon = pet.Icon,
				Size = 40,
				EventTag = pet.EventTag,
			})

		create("TextLabel", {
			Name = "Name",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(52, 6),
			Size = UDim2.fromOffset(if canWalk then 150 else 200, 44),
			Text = petLabel(pet),
			TextColor3 = UiTheme.Colors.TextDark,
			TextSize = 15,
			Font = UiTheme.FontTitle,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
		}, row)

		if canWalk then
			createWalkButton(row, pet.Name, UDim2.fromOffset(168, 12), UDim2.fromOffset(44, 32), isActive)
			createHoldButton(row, pet, UDim2.fromOffset(216, 12), UDim2.fromOffset(44, 32))
			createLockButton(row, pet, UDim2.fromOffset(264, 12), UDim2.fromOffset(36, 32))
			createPinButton(row, pet, UDim2.fromOffset(304, 12), UDim2.fromOffset(36, 32))
		else
			createHoldButton(row, pet, UDim2.fromOffset(216, 12), UDim2.fromOffset(48, 32))
			createLockButton(row, pet, UDim2.fromOffset(268, 12), UDim2.fromOffset(36, 32))
			createPinButton(row, pet, UDim2.fromOffset(308, 12), UDim2.fromOffset(36, 32))
		end
	end

	UiTheme.AddScrollSpacer(inventoryList, layoutOrder + 1)
	UiTheme.QueueScrollCanvas(inventoryList)
end

local function getValueMult(): number
	local mult = localPlayer:GetAttribute("ValueMult")
	if typeof(mult) == "number" then
		return mult
	end
	return 1
end

local function getCompanionSellMult(): number
	local mult = localPlayer:GetAttribute("CompanionSellMult")
	if typeof(mult) == "number" and mult > 0 then
		return mult
	end
	return 1
end

local function getPotionSellMult(): number
	local remaining = localPlayer:GetAttribute("PotionSellRemaining")
	if typeof(remaining) ~= "number" or remaining <= 0 then
		return 1
	end
	local mult = localPlayer:GetAttribute("PotionSellMult")
	if typeof(mult) == "number" and mult > 1 then
		return mult
	end
	return 1
end

local function readLockedSet(): { [number]: boolean }
	local lockedSet: { [number]: boolean } = {}
	local lockedFolder = localPlayer:FindFirstChild("LockedPets")
	if lockedFolder and lockedFolder:IsA("Folder") then
		for _, child in ipairs(lockedFolder:GetChildren()) do
			if child:IsA("BoolValue") then
				local index = tonumber(child.Name)
				if typeof(index) == "number" and child.Value == true then
					lockedSet[math.floor(index)] = true
				end
			end
		end
	end
	return lockedSet
end

local function readHotbarSlotByIndex(): { [number]: number }
	local pinSlotByIndex: { [number]: number } = {}
	local pinsFolder = localPlayer:FindFirstChild("HotbarPins")
	if pinsFolder and pinsFolder:IsA("Folder") then
		for _, child in ipairs(pinsFolder:GetChildren()) do
			if child:IsA("IntValue") then
				local slot = tonumber(child.Name)
				local invIndex = child.Value
				if typeof(slot) == "number" and invIndex > 0 then
					pinSlotByIndex[math.floor(invIndex)] = math.floor(slot)
				end
			end
		end
	end
	return pinSlotByIndex
end

local function normalizePetPayload(pet: any): PetPayload?
	if typeof(pet) ~= "table" then
		return nil
	end
	if typeof(pet.Index) ~= "number" or typeof(pet.Name) ~= "string" then
		return nil
	end

	local hotbarSlot: number? = nil
	if typeof(pet.HotbarSlot) == "number" and pet.HotbarSlot > 0 then
		hotbarSlot = math.floor(pet.HotbarSlot)
	end

	return {
		Index = math.floor(pet.Index),
		Name = pet.Name,
		Rarity = if typeof(pet.Rarity) == "string" then pet.Rarity else "Unknown",
		OneIn = if typeof(pet.OneIn) == "number" then pet.OneIn else 0,
		SellPrice = if typeof(pet.SellPrice) == "number" then pet.SellPrice else 0,
		Icon = if typeof(pet.Icon) == "string" then pet.Icon else "🐾",
		Description = if typeof(pet.Description) == "string" then pet.Description else "Unknown pet.",
		Locked = pet.Locked == true,
		HotbarSlot = hotbarSlot,
		EventTag = if typeof(pet.EventTag) == "string" and pet.EventTag ~= "" then pet.EventTag else nil,
	}
end

local function syncPetsFromFolder()
	local petsFolder = localPlayer:FindFirstChild("Pets")
	local entries: { PetPayload } = {}
	local valueMult = getValueMult()
	local worldSell = getWorldSellMult()
	local companionSell = getCompanionSellMult()
	local potionSell = getPotionSellMult()
	local lockedSet = readLockedSet()
	local pinSlotByIndex = readHotbarSlotByIndex()

	if petsFolder and petsFolder:IsA("Folder") then
		local index = 1
		for _, child in ipairs(petsFolder:GetChildren()) do
			if child:IsA("StringValue") then
				local definition = PetConfig.GetByName(child.Value)
				local basePrice = if definition then definition.SellPrice else 50
				local eventTagAttr = child:GetAttribute("EventTag")
				local eventTag = if typeof(eventTagAttr) == "string" and eventTagAttr ~= "" then eventTagAttr else nil
				local tagSell = EventConfig.GetTagSellMultiplier(eventTag)
				table.insert(entries, {
					Index = index,
					Name = child.Value,
					Rarity = if definition then definition.Rarity else "Unknown",
					OneIn = if definition then definition.OneIn else 0,
					SellPrice = math.max(0, math.floor(basePrice * valueMult * worldSell * tagSell * companionSell * potionSell)),
					Icon = if definition then definition.Icon else "🐾",
					Description = if definition then definition.Description else "Unknown pet.",
					Locked = lockedSet[index] == true,
					HotbarSlot = pinSlotByIndex[index],
					EventTag = eventTag,
				})
				index += 1
			end
		end
	end

	currentPets = entries
	updateBagCapacityLabels()

	-- Avoid rebuilding ViewportFrame-heavy rows when the panel is closed.
	-- Shop sell list is refreshed from shop snapshots, not every folder mutation.
	if inventoryPanel.Visible then
		renderInventoryPanel()
	end
end

local petsSyncQueued = false
local function scheduleSyncPetsFromFolder()
	if petsSyncQueued then
		return
	end
	petsSyncQueued = true
	task.defer(function()
		petsSyncQueued = false
		syncPetsFromFolder()
	end)
end

inventoryLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	UiTheme.QueueScrollCanvas(inventoryList)
end)

petsHudButton.MouseButton1Click:Connect(function()
	inventoryPanel.Visible = not inventoryPanel.Visible
	if inventoryPanel.Visible then
		syncPetsFromFolder()
		UiTheme.BounceIn(inventoryPanel, 0.65)
	end
end)

inventoryClose.MouseButton1Click:Connect(function()
	inventoryPanel.Visible = false
end)

local function clearList()
	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") or child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function refreshCanvas()
	UiTheme.QueueScrollCanvas(listFrame)
end

listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	UiTheme.SetScrollCanvas(listFrame)
end)

local function setModeChrome()
	if currentTab == "Buy" then
		title.Text = "Shop"
		buyTab.BackgroundColor3 = UiTheme.ButtonColor("green")
		UiTheme.Gradient(buyTab, Color3.fromRGB(140, 255, 150), UiTheme.Colors.AccentGreenHot, 90)
		sellTab.BackgroundColor3 = UiTheme.Colors.BgMuted
		UiTheme.Gradient(sellTab, Color3.fromRGB(220, 230, 240), UiTheme.Colors.BgMuted, 90)
		if statusLabel.Text == "" or string.find(statusLabel.Text, "Sold", 1, true) or string.find(statusLabel.Text, "pets", 1, true) then
			statusLabel.Text = "Unlock bait once for unlimited throws — coins or Robux."
		end
	else
		title.Text = "Sell"
		buyTab.BackgroundColor3 = UiTheme.Colors.BgMuted
		UiTheme.Gradient(buyTab, Color3.fromRGB(220, 230, 240), UiTheme.Colors.BgMuted, 90)
		sellTab.BackgroundColor3 = UiTheme.ButtonColor("pink")
		UiTheme.Gradient(sellTab, Color3.fromRGB(255, 150, 220), UiTheme.Colors.AccentPinkHot, 90)
		if statusLabel.Text == "" or string.find(statusLabel.Text, "Unlock bait", 1, true) then
			statusLabel.Text = "Sell your caught pets for coins."
		end
	end
end

setModeChrome()

local function toColor3(value: any): Color3
	if typeof(value) == "Color3" then
		return value
	end

	if typeof(value) == "table" and typeof(value.R) == "number" and typeof(value.G) == "number" and typeof(value.B) == "number" then
		return Color3.new(value.R, value.G, value.B)
	end

	return UiTheme.Colors.AccentBlue
end

local function renderBuyList()
	clearList()

	local activeId = currentActiveBait.Id

	for order, item in ipairs(currentItems) do
		local owned = item.Owned == true
		local equipped = owned and item.BaitId == activeId
		local row = UiTheme.Row({
			Name = item.Id,
			Parent = listFrame,
			Size = UDim2.new(1, -8, 0, 84),
			LayoutOrder = order,
		})

		local iconHost = create("Frame", {
			Name = "IconHost",
			BackgroundColor3 = toColor3(item.Color),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(10, 12),
			Size = UDim2.fromOffset(60, 60),
		}, row) :: Frame
		UiTheme.Corner(iconHost, UiTheme.CornerSmall)
		UiTheme.Stroke(iconHost, UiTheme.Colors.Stroke, 3, 0)
		UiIcon.Mount(iconHost, {
			Key = IconAssets.KeyForBaitId(item.BaitId),
			Name = "Glyph",
			Size = UDim2.fromScale(1, 1),
			ImageSize = 28,
		})

		local speed = if typeof(item.CatchSpeed) == "number" then item.CatchSpeed else 1
		local speedText = BaitConfig.FormatSpeed(speed)
		local meta = if speedText ~= ""
			then string.format("%s luck · %s", BaitConfig.FormatLuck(item.LuckMultiplier), speedText)
			else string.format("%s luck", BaitConfig.FormatLuck(item.LuckMultiplier))

		create("TextLabel", {
			Name = "Name",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(84, 10),
			Size = UDim2.fromOffset(280, 24),
			Text = item.Name,
			TextColor3 = UiTheme.Colors.TextDark,
			TextSize = 18,
			Font = UiTheme.FontTitle,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)

		create("TextLabel", {
			Name = "Stock",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(84, 34),
			Size = UDim2.fromOffset(280, 18),
			Text = string.format("%s · ∞", meta),
			TextColor3 = UiTheme.Colors.Stock,
			TextSize = 13,
			Font = UiTheme.FontMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)

		create("TextLabel", {
			Name = "Desc",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(84, 52),
			Size = UDim2.fromOffset(280, 26),
			Text = item.Description,
			TextColor3 = UiTheme.Colors.TextDim,
			TextSize = 13,
			Font = UiTheme.FontBody,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}, row)

		local actionText: string
		local actionVariant: UiTheme.ButtonVariant
		local canClick = true
		if equipped then
			actionText = "Equipped"
			actionVariant = "muted"
			canClick = false
		elseif owned then
			actionText = "Equip"
			actionVariant = "green"
		else
			actionText = if item.Price > 0 then NumberFormat.FormatCoins(item.Price) .. "$" else "Free"
			actionVariant = "green"
		end

		local robuxPrice = if typeof(item.RobuxPrice) == "number" then item.RobuxPrice else 0
		local productId = if typeof(item.ProductId) == "number" then item.ProductId else 0
		local showRobux = not owned and robuxPrice > 0

		local buyButton = UiTheme.Button({
			Name = "Buy",
			Parent = row,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = if showRobux then UDim2.new(1, -118, 0.5, 0) else UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(100, 38),
			Text = actionText,
			TextSize = 15,
			Variant = actionVariant,
		})
		buyButton.AutoButtonColor = canClick
		buyButton.Active = canClick

		if showRobux then
			local robuxButton = UiTheme.Button({
				Name = "Robux",
				Parent = row,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(100, 38),
				Text = string.format("%d R$", robuxPrice),
				TextSize = 15,
				Variant = "vip",
			})
			local baitName = item.Name
			robuxButton.MouseButton1Click:Connect(function()
				RobuxPurchase.Prompt(productId, baitName, robuxPrice, function(message)
					statusLabel.Text = message
					UiToast.Show(message)
				end)
			end)
		end

		if canClick then
			local itemId = item.Id
			buyButton.MouseButton1Click:Connect(function()
				-- Purchase or equip (server treats owned baits as equip).
				buyItemRemote:FireServer(itemId)
			end)
		end
	end

	UiTheme.AddScrollSpacer(listFrame, 100000)
	refreshCanvas()
end

local function renderSellList()
	clearList()

	local sellableCount = InventoryUi.CountSellable(currentPets)
	local sellableValue = getTotalSellValue()

	local toolbar = UiTheme.Row({
		Name = "SellToolbar",
		Parent = listFrame,
		Size = UDim2.new(1, -8, 0, 92),
		LayoutOrder = 0,
	})

	local sortButton = UiTheme.Button({
		Name = "Sort",
		Parent = toolbar,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(130, 32),
		Text = string.format("Sort: %s", currentSortMode),
		TextSize = 13,
		Variant = "blue",
	})

	local sellCommonsButton = UiTheme.Button({
		Name = "SellCommons",
		Parent = toolbar,
		Position = UDim2.fromOffset(148, 10),
		Size = UDim2.fromOffset(150, 32),
		Text = "Sell All Commons",
		TextSize = 12,
		Variant = "pink",
	})

	local sellBelowButton = UiTheme.Button({
		Name = "SellBelow",
		Parent = toolbar,
		Position = UDim2.fromOffset(306, 10),
		Size = UDim2.fromOffset(150, 32),
		Text = string.format("Sell ≤ %s", currentBulkRarity),
		TextSize = 12,
		Variant = "pink",
	})
	sellBelowButton.BackgroundColor3 = UiTheme.Colors.AccentPurple
	UiTheme.Gradient(sellBelowButton, Color3.fromRGB(210, 160, 255), UiTheme.Colors.AccentPurple, 90)

	local sellAllButton = UiTheme.Button({
		Name = "SellAll",
		Parent = toolbar,
		Position = UDim2.fromOffset(10, 50),
		Size = UDim2.fromOffset(560, 34),
		Text = string.format("Sell All (%d unlocked) +%s$", sellableCount, NumberFormat.FormatCoins(sellableValue)),
		TextSize = 14,
		Variant = if sellableCount > 0 then "green" else "muted",
	})
	sellAllButton.AutoButtonColor = sellableCount > 0
	sellAllButton.Active = sellableCount > 0

	create("TextLabel", {
		Name = "StockHint",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(468, 14),
		Size = UDim2.fromOffset(100, 24),
		Text = string.format("%d ready", sellableCount),
		TextColor3 = UiTheme.Colors.Stock,
		TextSize = 13,
		Font = UiTheme.FontTitle,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, toolbar)

	sortButton.MouseButton1Click:Connect(function()
		cycleSortMode()
		updateSortButtons()
		renderInventoryPanel()
		renderSellList()
	end)

	sellCommonsButton.MouseButton1Click:Connect(function()
		sellBulkPetsRemote:FireServer({ Mode = "Commons" })
	end)

	sellBelowButton.MouseButton1Click:Connect(function()
		local rarity = currentBulkRarity
		sellBulkPetsRemote:FireServer({
			Mode = "BelowOrEqualRarity",
			Rarity = rarity,
		})
		cycleBulkRarity()
		sellBelowButton.Text = string.format("Sell ≤ %s", currentBulkRarity)
	end)

	if sellableCount > 0 then
		sellAllButton.MouseButton1Click:Connect(function()
			showConfirmDialog()
		end)
	end

	if #currentPets == 0 then
		return
	end

	for order, pet in ipairs(getSortedPets()) do
		local locked = isPetLocked(pet)
		local row = UiTheme.Row({
			Name = string.format("Pet_%d", pet.Index),
			Parent = listFrame,
			Size = UDim2.new(1, -8, 0, 84),
			LayoutOrder = order,
			RarityColor = PetConfig.GetRarityColor(pet.Rarity),
		})
		if locked then
			row.BackgroundColor3 = UiTheme.Colors.BgMuted:Lerp(Color3.fromRGB(255, 255, 255), 0.2)
		end

		local iconHost = create("Frame", {
			Name = "IconHost",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(10, 12),
			Size = UDim2.fromOffset(60, 60),
		}, row) :: Frame

		PetIconUi.Mount(iconHost, {
			PetName = pet.Name,
			Rarity = pet.Rarity,
			Icon = pet.Icon,
			Size = 60,
			EventTag = pet.EventTag,
		})

		create("TextLabel", {
			Name = "Name",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(84, 10),
			Size = UDim2.fromOffset(280, 24),
			Text = petLabel(pet),
			TextColor3 = UiTheme.Colors.TextDark,
			TextSize = 18,
			Font = UiTheme.FontTitle,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)

		create("TextLabel", {
			Name = "Desc",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(84, 36),
			Size = UDim2.fromOffset(280, 38),
			Text = pet.Description,
			TextColor3 = UiTheme.Colors.TextDim,
			TextSize = 14,
			Font = UiTheme.FontBody,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}, row)

		createLockButton(row, pet, UDim2.fromOffset(370, 12), UDim2.fromOffset(40, 28))
		createPinButton(row, pet, UDim2.fromOffset(416, 12), UDim2.fromOffset(40, 28))

		local sellButton = UiTheme.Button({
			Name = "Sell",
			Parent = row,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromOffset(580, 42),
			Size = UDim2.fromOffset(110, 40),
			Text = if locked then "LOCKED" else string.format("+%s$", NumberFormat.FormatCoins(pet.SellPrice)),
			TextSize = 16,
			Variant = if locked then "muted" else "green",
		})
		sellButton.AutoButtonColor = not locked
		sellButton.Active = not locked

		if not locked then
			create("TextLabel", {
				Name = "PriceHint",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromOffset(580, 8),
				Size = UDim2.fromOffset(110, 16),
				Text = NumberFormat.FormatCoins(pet.SellPrice) .. "$",
				TextColor3 = UiTheme.Colors.AccentAmber,
				TextSize = 12,
				Font = UiTheme.FontTitle,
				TextXAlignment = Enum.TextXAlignment.Right,
			}, row)

			local petIndex = pet.Index
			sellButton.MouseButton1Click:Connect(function()
				if isPetLocked(pet) then
					return
				end
				sellPetRemote:FireServer(petIndex)
			end)
		end
	end

	UiTheme.AddScrollSpacer(listFrame, 100000)
	refreshCanvas()
end

local function renderCurrentTab()
	setModeChrome()
	if currentTab == "Buy" then
		renderBuyList()
	else
		renderSellList()
	end
end

buyTab.MouseButton1Click:Connect(function()
	currentTab = "Buy"
	renderCurrentTab()
end)

sellTab.MouseButton1Click:Connect(function()
	currentTab = "Sell"
	syncPetsFromFolder()
	renderCurrentTab()
end)

inventorySortButton.MouseButton1Click:Connect(function()
	cycleSortMode()
	updateSortButtons()
	renderInventoryPanel()
	if panel.Visible and currentTab == "Sell" then
		renderSellList()
	end
end)

local function applyPayload(payload: any, openPanel: boolean?)
	if typeof(payload) ~= "table" then
		return
	end

	if typeof(payload.Mode) == "string" and (payload.Mode == "Buy" or payload.Mode == "Sell") then
		currentTab = payload.Mode
	end

	if typeof(payload.ActiveBait) == "table" then
		local bait = payload.ActiveBait
		currentActiveBait = {
			Id = if typeof(bait.Id) == "string" then bait.Id else currentActiveBait.Id,
			Name = if typeof(bait.Name) == "string" then bait.Name else currentActiveBait.Name,
			LuckMultiplier = if typeof(bait.LuckMultiplier) == "number" then bait.LuckMultiplier else currentActiveBait.LuckMultiplier,
			CatchSpeed = if typeof(bait.CatchSpeed) == "number" then bait.CatchSpeed else currentActiveBait.CatchSpeed,
			Icon = if typeof(bait.Icon) == "string" then bait.Icon else currentActiveBait.Icon,
		}
	end

	local coins = if typeof(payload.Coins) == "number" then payload.Coins else 0
	setBalances(coins, currentActiveBait)

	if typeof(payload.Items) == "table" then
		currentItems = payload.Items
	end

	if typeof(payload.Pets) == "table" then
		local entries: { PetPayload } = {}
		for _, pet in ipairs(payload.Pets) do
			local normalized = normalizePetPayload(pet)
			if normalized then
				table.insert(entries, normalized)
			end
		end
		currentPets = entries
		petsCountLabel.Text = tostring(#currentPets)
		if inventoryPanel.Visible then
			renderInventoryPanel()
		end
	end

	if openPanel then
		panel.Visible = true
		hideConfirmDialog()
		UiTheme.BounceIn(panel, 0.65)
		-- Fresh open: reset status to the mode default instead of leftover messages.
		if currentTab == "Buy" then
			statusLabel.Text = "Unlock bait once for unlimited throws — coins or Robux."
		else
			statusLabel.Text = "Sell your caught pets for coins."
		end
	end

	if panel.Visible then
		renderCurrentTab()
	end

	if typeof(payload.Message) == "string" and payload.Message ~= "" then
		statusLabel.Text = payload.Message
		UiToast.Show(payload.Message)
	end
end

closeButton.MouseButton1Click:Connect(function()
	hideConfirmDialog()
	panel.Visible = false
end)

openShopRemote.OnClientEvent:Connect(function(payload)
	applyPayload(payload, true)
end)

shopResultRemote.OnClientEvent:Connect(function(payload)
	applyPayload(payload, false)

	if typeof(payload) ~= "table" then
		return
	end
	if payload.Type == "Error" then
		FeelSound.Play("Error", 0.4)
		return
	end
	if typeof(payload.Message) ~= "string" or payload.Message == "" then
		return
	end

	if payload.Mode == "Sell" then
		FeelSound.Play("Sell", 0.65)
	elseif payload.Mode == "Buy" then
		FeelSound.Play("Buy", 0.7)
	end
end)

local function syncHudFromAttributes()
	local coins = localPlayer:GetAttribute("Coins")
	local activeId = localPlayer:GetAttribute("ActiveBait")
	if typeof(activeId) == "string" then
		local definition = BaitConfig.GetById(activeId)
		if definition then
			currentActiveBait = {
				Id = definition.Id,
				Name = definition.Name,
				LuckMultiplier = definition.LuckMultiplier,
				CatchSpeed = definition.CatchSpeed,
				Icon = definition.Icon,
			}
		end
	end

	setBalances(
		if typeof(coins) == "number" then coins else 0,
		currentActiveBait
	)
end

local function bindValueListener(child: Instance)
	if child:IsA("ValueBase") then
		child:GetPropertyChangedSignal("Value"):Connect(function()
			scheduleSyncPetsFromFolder()
		end)
	end
end

local function bindFolderSync(folder: Folder)
	folder.ChildAdded:Connect(function(child)
		bindValueListener(child)
		scheduleSyncPetsFromFolder()
	end)
	folder.ChildRemoved:Connect(function()
		scheduleSyncPetsFromFolder()
	end)
	for _, child in ipairs(folder:GetChildren()) do
		bindValueListener(child)
	end
end

local function bindPetsFolder(folder: Folder)
	bindFolderSync(folder)
	syncPetsFromFolder()
end

local function tryBindNamedFolder(name: string)
	local existing = localPlayer:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		bindFolderSync(existing)
	end
end

local existingPetsFolder = localPlayer:FindFirstChild("Pets")
if existingPetsFolder and existingPetsFolder:IsA("Folder") then
	bindPetsFolder(existingPetsFolder)
end

tryBindNamedFolder("LockedPets")
tryBindNamedFolder("HotbarPins")

localPlayer.ChildAdded:Connect(function(child)
	if not child:IsA("Folder") then
		return
	end
	if child.Name == "Pets" then
		bindPetsFolder(child)
	elseif child.Name == "LockedPets" or child.Name == "HotbarPins" then
		bindFolderSync(child)
		scheduleSyncPetsFromFolder()
	end
end)

syncHudFromAttributes()
renderInventoryPanel()
HudLuck.Connect(localPlayer, syncHudFromAttributes)
localPlayer:GetAttributeChangedSignal("Coins"):Connect(syncHudFromAttributes)
localPlayer:GetAttributeChangedSignal("BagCapacity"):Connect(updateBagCapacityLabels)
localPlayer:GetAttributeChangedSignal("PetCount"):Connect(function()
	-- Server PetCount can race ahead of folder sync; refresh labels from local pets + capacity.
	updateBagCapacityLabels()
end)
localPlayer:GetAttributeChangedSignal("EquippedPetSlots"):Connect(function()
	if inventoryPanel.Visible then
		renderInventoryPanel()
	end
end)
localPlayer:GetAttributeChangedSignal("EquippedPetSlot"):Connect(function()
	if inventoryPanel.Visible then
		renderInventoryPanel()
	end
end)
localPlayer:GetAttributeChangedSignal("EquippedPetSlot2"):Connect(function()
	if inventoryPanel.Visible then
		renderInventoryPanel()
	end
end)
localPlayer:GetAttributeChangedSignal("EquippedPetSlot3"):Connect(function()
	if inventoryPanel.Visible then
		renderInventoryPanel()
	end
end)
localPlayer:GetAttributeChangedSignal("Map2Unlocked"):Connect(function()
	if inventoryPanel.Visible then
		renderInventoryPanel()
	end
end)
localPlayer:GetAttributeChangedSignal("Map3Unlocked"):Connect(function()
	if inventoryPanel.Visible then
		renderInventoryPanel()
	end
end)
localPlayer:GetAttributeChangedSignal("MaxEquippedPets"):Connect(function()
	if inventoryPanel.Visible then
		renderInventoryPanel()
	end
end)
localPlayer:GetAttributeChangedSignal("ActiveBait"):Connect(function()
	syncHudFromAttributes()
	if panel.Visible and currentTab == "Buy" then
		renderBuyList()
	end
end)
localPlayer:GetAttributeChangedSignal("ValueMult"):Connect(function()
	syncPetsFromFolder()
	if panel.Visible and currentTab == "Sell" then
		renderSellList()
	end
end)
localPlayer:GetAttributeChangedSignal("CompanionSellMult"):Connect(function()
	syncPetsFromFolder()
	if panel.Visible and currentTab == "Sell" then
		renderSellList()
	end
	updateCompanionStatusLabel()
end)
localPlayer:GetAttributeChangedSignal("PotionSellMult"):Connect(function()
	syncPetsFromFolder()
	if panel.Visible and currentTab == "Sell" then
		renderSellList()
	end
end)
localPlayer:GetAttributeChangedSignal("PotionSellRemaining"):Connect(function()
	syncPetsFromFolder()
	if panel.Visible and currentTab == "Sell" then
		renderSellList()
	end
end)
localPlayer:GetAttributeChangedSignal("CompanionPetName"):Connect(function()
	updateCompanionStatusLabel()
	renderInventoryPanel()
end)
localPlayer:GetAttributeChangedSignal("CompanionPetName2"):Connect(function()
	updateCompanionStatusLabel()
	renderInventoryPanel()
end)
localPlayer:GetAttributeChangedSignal("CompanionPetNames"):Connect(function()
	updateCompanionStatusLabel()
	renderInventoryPanel()
end)
localPlayer:GetAttributeChangedSignal("CompanionWalkMax"):Connect(function()
	updateCompanionStatusLabel()
	renderInventoryPanel()
end)
localPlayer:GetAttributeChangedSignal("CompanionLuckMult"):Connect(function()
	updateCompanionStatusLabel()
end)

for _, attrName in PotionConfig.CountAttributes do
	localPlayer:GetAttributeChangedSignal(attrName):Connect(function()
		if inventoryPanel.Visible then
			renderInventoryPanel()
		end
	end)
end

local unlockedCompanionsFolder = localPlayer:FindFirstChild("UnlockedCompanions")
local function bindUnlockedCompanionsFolder(folder: Instance)
	folder.ChildAdded:Connect(function()
		renderInventoryPanel()
	end)
	folder.ChildRemoved:Connect(function()
		renderInventoryPanel()
	end)
end
if unlockedCompanionsFolder then
	bindUnlockedCompanionsFolder(unlockedCompanionsFolder)
end
localPlayer.ChildAdded:Connect(function(child)
	if child.Name == "UnlockedCompanions" then
		bindUnlockedCompanionsFolder(child)
		renderInventoryPanel()
	end
end)

companionResultRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	if inventoryPanel.Visible then
		renderInventoryPanel()
	else
		updateCompanionStatusLabel()
	end
	if typeof(payload.Message) == "string" and payload.Message ~= "" then
		UiToast.Show(payload.Message)
	end
end)

updateCompanionStatusLabel()
updateBagCapacityLabels()
