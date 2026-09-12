--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local startBaitRemote = remotes:WaitForChild("StartBait") :: RemoteEvent
local submitLuckRemote = remotes:WaitForChild("SubmitLuck") :: RemoteEvent
local petResultRemote = remotes:WaitForChild("PetResult") :: RemoteEvent
local requestThrowRemote = remotes:WaitForChild("RequestThrow") :: RemoteEvent

local Modules = ReplicatedStorage:WaitForChild("Modules")
local BaitConfig = require(Modules:WaitForChild("BaitConfig"))
local CatchCinematic = require(Modules:WaitForChild("CatchCinematic"))
local CatchFeelConfig = require(Modules:WaitForChild("CatchFeelConfig"))
local CaveConfig = require(Modules:WaitForChild("CaveConfig"))
local HudLuck = require(Modules:WaitForChild("HudLuck"))
local LuckConfig = require(Modules:WaitForChild("LuckConfig"))
local PetConfig = require(Modules:WaitForChild("PetConfig"))
local PetIconUi = require(Modules:WaitForChild("PetIconUi"))
local IconAssets = require(Modules:WaitForChild("IconAssets"))
local TutorialGate = require(Modules:WaitForChild("TutorialGate"))
local UiIcon = require(Modules:WaitForChild("UiIcon"))
local UiTheme = require(Modules:WaitForChild("UiTheme"))
local UiToast = require(Modules:WaitForChild("UiToast"))
local VipConfig = require(Modules:WaitForChild("VipConfig"))
local VipPurchase = require(Modules:WaitForChild("VipPurchase"))

local JUMP_LOCK_ACTION = "BaitLockJump"
local THROW_REQUEST_COOLDOWN = 0.3

type ActiveBaitPayload = {
	Id: string,
	Name: string,
	LuckMultiplier: number,
	CatchSpeed: number?,
	Icon: string,
}

type GuiRefs = {
	ScreenGui: ScreenGui,
	Root: Frame,
	Panel: Frame,
	BaitLabel: TextLabel,
	StatusLabel: TextLabel,
	LuckLabel: TextLabel,
	BarTrack: Frame,
	BarFill: Frame,
	SubmitButton: TextButton,
	ResultFrame: Frame,
	ResultTitle: TextLabel,
	ResultSubtitle: TextLabel,
	ResultStroke: UIStroke,
	ResultPetHost: Frame,
	NewBadge: Frame,
	ThrowButton: TextButton,
	ThrowIconHost: Frame,
	ThrowName: TextLabel,
	ThrowHint: TextLabel,
	ThrowStroke: UIStroke,
}

local fillAmount = 0
local fillDirection = 1
local isBarActive = false
local hasSubmitted = false
local autoCatchClickToken = 0
local isNearCave = false
local nearCaveBlocked = false
local nearCaveLuckMult = 1
local lastThrowRequestAt = 0
local activeBait: ActiveBaitPayload = {
	Id = "basic",
	Name = "Basic Bait",
	LuckMultiplier = 1,
	CatchSpeed = 1,
	Icon = "🪱",
}

local NEAR_COLOR = UiTheme.Colors.AccentCyan
local VIP_NEAR_COLOR = UiTheme.Colors.AccentVip
local DISABLED_COLOR = UiTheme.Colors.BgMuted
local COOLDOWN_COLOR = UiTheme.Colors.AccentAmber
local VIP_BLOCKED_COLOR = UiTheme.Colors.AccentVipLocked

local stopThrowPulse: (() -> ())? = nil

local function setJumpEnabled(enabled: boolean)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled)
		if not enabled then
			humanoid.Jump = false
		end
	end

	if enabled then
		ContextActionService:UnbindAction(JUMP_LOCK_ACTION)
	else
		ContextActionService:BindAction(JUMP_LOCK_ACTION, function()
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.Space, Enum.PlayerActions.CharacterJump)
	end
end

local function create(className: string, props: { [string]: any }, parent: Instance?): Instance
	return UiTheme.Create(className, props, parent)
end

local function buildGui(): GuiRefs
	local existing = playerGui:FindFirstChild("BaitGui")
	if existing then
		existing:Destroy()
	end

	local screenGui = create("ScreenGui", {
		Name = "BaitGui",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 6,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui) :: ScreenGui
	UiTheme.MobileScale(screenGui)

	local root = create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, screenGui) :: Frame

	local throwButton = create("TextButton", {
		Name = "ThrowBaitButton",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -118),
		Size = UDim2.fromOffset(188, 92),
		BackgroundColor3 = DISABLED_COLOR,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 5,
	}, root) :: TextButton

	throwButton:SetAttribute("TutorialTarget", "throw_bait")

	UiTheme.Corner(throwButton, UiTheme.CornerPanel)
	local throwStroke = UiTheme.Stroke(throwButton, UiTheme.Colors.Stroke, 4, 0)
	UiTheme.Gradient(throwButton, Color3.fromRGB(220, 230, 240), DISABLED_COLOR, 90)
	UiTheme.WireButtonMotion(throwButton)

	local throwIconHost = create("Frame", {
		Name = "IconHost",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 38),
		ZIndex = 6,
	}, throwButton) :: Frame
	UiIcon.Mount(throwIconHost, {
		Key = IconAssets.KeyForBaitId("basic"),
		Name = "Glyph",
		Size = UDim2.fromScale(1, 1),
		ImageSize = 34,
	})

	local throwName = create("TextLabel", {
		Name = "BaitName",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 46),
		Size = UDim2.new(1, -20, 0, 20),
		Text = "Basic Bait",
		TextColor3 = UiTheme.Colors.TextDark,
		TextSize = 15,
		Font = UiTheme.FontTitle,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 6,
	}, throwButton) :: TextLabel

	local throwHint = create("TextLabel", {
		Name = "Hint",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 66),
		Size = UDim2.new(1, -20, 0, 18),
		Text = "Get closer to a cave",
		TextColor3 = UiTheme.Colors.TextDim,
		TextSize = 12,
		Font = UiTheme.FontMedium,
		ZIndex = 6,
	}, throwButton) :: TextLabel

	local panel = create("Frame", {
		Name = "LuckPanel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.92),
		Size = UDim2.fromOffset(320, 360),
		BackgroundColor3 = UiTheme.Colors.BgPanel,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 10,
	}, root) :: Frame

	UiTheme.Corner(panel, UiTheme.CornerPanel)
	UiTheme.Stroke(panel, UiTheme.Colors.Stroke, 4, 0)

	local panelHeader = create("Frame", {
		Name = "HeaderBar",
		BackgroundColor3 = UiTheme.Colors.BgHeader,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 52),
		ZIndex = 10,
	}, panel) :: Frame
	UiTheme.Corner(panelHeader, UiTheme.CornerPanel)
	UiTheme.Gradient(panelHeader, Color3.fromRGB(150, 220, 255), Color3.fromRGB(90, 180, 255), 90)
	local headerMask = create("Frame", {
		Name = "HeaderMask",
		BackgroundColor3 = UiTheme.Colors.BgHeader,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -16),
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = 10,
	}, panelHeader) :: Frame
	UiTheme.Gradient(headerMask, Color3.fromRGB(150, 220, 255), Color3.fromRGB(90, 180, 255), 90)

	local panelTitle = create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.fromOffset(180, 32),
		Text = "Bait a Pet",
		TextColor3 = UiTheme.Colors.Text,
		TextSize = 26,
		Font = UiTheme.FontTitle,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
	}, panel) :: TextLabel
	UiTheme.TextStroke(panelTitle, 2.6)

	local baitLabel = create("TextLabel", {
		Name = "BaitLabel",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(120, 14),
		Size = UDim2.fromOffset(180, 24),
		Text = "Basic Bait ∞",
		TextColor3 = UiTheme.Colors.Text,
		TextSize = 15,
		Font = UiTheme.FontMedium,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 12,
	}, panel) :: TextLabel
	UiTheme.TextStroke(baitLabel, 2)

	local statusLabel = create("TextLabel", {
		Name = "Status",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 62),
		Size = UDim2.fromOffset(280, 40),
		Text = "Press SPACE to stop when luck is high.",
		TextColor3 = UiTheme.Colors.TextDark,
		TextSize = 16,
		Font = UiTheme.FontBody,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
	}, panel) :: TextLabel

	local barTrack = create("Frame", {
		Name = "LuckBarTrack",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(160, 110),
		Size = UDim2.fromOffset(74, 180),
		BackgroundColor3 = UiTheme.Colors.BgRaised,
		BorderSizePixel = 0,
		ZIndex = 11,
	}, panel) :: Frame

	UiTheme.Corner(barTrack, UiTheme.CornerSmall)
	UiTheme.Stroke(barTrack, UiTheme.Colors.Stroke, 3, 0)

	local barFill = create("Frame", {
		Name = "LuckBarFill",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = UiTheme.Colors.AccentGreen,
		BorderSizePixel = 0,
		ZIndex = 12,
	}, barTrack) :: Frame

	UiTheme.Corner(barFill, UiTheme.CornerSmall)

	create("TextLabel", {
		Name = "MaxLabel",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 110),
		Size = UDim2.fromOffset(70, 20),
		Text = "MAX",
		TextColor3 = UiTheme.Colors.TextDark,
		TextSize = 14,
		Font = UiTheme.FontTitle,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
	}, panel)

	create("TextLabel", {
		Name = "MinLabel",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 270),
		Size = UDim2.fromOffset(70, 20),
		Text = "LOW",
		TextColor3 = UiTheme.Colors.TextDim,
		TextSize = 14,
		Font = UiTheme.FontTitle,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
	}, panel)

	local luckLabel = create("TextLabel", {
		Name = "LuckLabel",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 296),
		Size = UDim2.fromOffset(280, 24),
		Text = "Luck: 0.5x (0%)",
		TextColor3 = UiTheme.Colors.TextDark,
		TextSize = 18,
		Font = UiTheme.FontTitle,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
	}, panel) :: TextLabel

	local submitButton = create("TextButton", {
		Name = "ThrowButton",
		Position = UDim2.fromOffset(20, 324),
		Size = UDim2.fromOffset(280, 28),
		BackgroundColor3 = UiTheme.Colors.AccentCyan,
		BorderSizePixel = 0,
		Text = "SPACE to Stop",
		TextColor3 = UiTheme.Colors.Text,
		TextSize = 16,
		Font = UiTheme.FontTitle,
		AutoButtonColor = false,
		ZIndex = 11,
	}, panel) :: TextButton

	UiTheme.Corner(submitButton, UiTheme.CornerButton)
	UiTheme.Stroke(submitButton, UiTheme.Colors.Stroke, 3, 0)
	UiTheme.TextStroke(submitButton, 2.2)
	UiTheme.Gradient(submitButton, Color3.fromRGB(140, 255, 180), UiTheme.Colors.AccentCyanDim, 90)
	UiTheme.WireButtonMotion(submitButton)

	local resultFrame = create("Frame", {
		Name = "Result",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(460, 180),
		BackgroundColor3 = UiTheme.Colors.BgPanel,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 12,
	}, root) :: Frame

	UiTheme.Corner(resultFrame, UiTheme.CornerPanel)
	local resultStroke = UiTheme.Stroke(resultFrame, UiTheme.Colors.Stroke, 4, 0)

	local resultPetHost = create("Frame", {
		Name = "ResultPetHost",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.5, 0),
		Size = UDim2.fromOffset(96, 96),
		ZIndex = 13,
	}, resultFrame) :: Frame

	local newBadge = create("Frame", {
		Name = "NewBadge",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(440, 12),
		Size = UDim2.fromOffset(72, 28),
		BackgroundColor3 = UiTheme.Colors.AccentAmber,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 14,
	}, resultFrame) :: Frame

	UiTheme.Corner(newBadge, UiTheme.CornerSmall)
	UiTheme.Stroke(newBadge, UiTheme.Colors.Stroke, 3, 0)
	UiTheme.Gradient(newBadge, Color3.fromRGB(255, 240, 120), UiTheme.Colors.AccentAmber, 90)
	UiIcon.Mount(newBadge, {
		Key = "badge_new",
		Name = "Glyph",
		Size = UDim2.fromScale(1, 1),
		ImageSize = 14,
	})

	local resultTitle = create("TextLabel", {
		Name = "ResultTitle",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(24, 24),
		Size = UDim2.fromOffset(300, 56),
		Text = "You got a pet!",
		TextColor3 = UiTheme.Colors.Text,
		TextSize = 32,
		Font = UiTheme.FontTitle,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
	}, resultFrame) :: TextLabel
	UiTheme.TextStroke(resultTitle, 2.8)

	local resultSubtitle = create("TextLabel", {
		Name = "ResultSubtitle",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(24, 92),
		Size = UDim2.fromOffset(300, 60),
		Text = "Pet | Common",
		TextColor3 = UiTheme.Colors.TextDark,
		TextSize = 22,
		Font = UiTheme.FontMedium,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
	}, resultFrame) :: TextLabel

	return {
		ScreenGui = screenGui,
		Root = root,
		Panel = panel,
		BaitLabel = baitLabel,
		StatusLabel = statusLabel,
		LuckLabel = luckLabel,
		BarTrack = barTrack,
		BarFill = barFill,
		SubmitButton = submitButton,
		ResultFrame = resultFrame,
		ResultTitle = resultTitle,
		ResultSubtitle = resultSubtitle,
		ResultStroke = resultStroke,
		ResultPetHost = resultPetHost,
		NewBadge = newBadge,
		ThrowButton = throwButton,
		ThrowIconHost = throwIconHost,
		ThrowName = throwName,
		ThrowHint = throwHint,
		ThrowStroke = throwStroke,
	}
end

local gui = buildGui()

local function setThrowReadyPulse(enabled: boolean)
	if enabled then
		if stopThrowPulse == nil then
			stopThrowPulse = UiTheme.Pulse(gui.ThrowButton, 1.07, 0.95)
		end
	elseif stopThrowPulse ~= nil then
		stopThrowPulse()
		stopThrowPulse = nil
	end
end

local resultHideToken = 0
local shakeToken = 0
local BAIT_GUI_ORDER = 6
local RESULT_GUI_ORDER = 8
local soundFolder = Instance.new("Folder")
soundFolder.Name = "CatchFeelSounds"
soundFolder.Parent = SoundService

local function playFeelSound(soundKey: string, volume: number?)
	local soundId = CatchFeelConfig.GetSoundId(soundKey)
	if typeof(soundId) ~= "string" then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.55
	sound.Parent = soundFolder
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	task.delay(6, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local function showToast(message: string, durationSeconds: number?)
	UiToast.Show(message, durationSeconds)
end

local function getCelebrationMinSetting(): string
	return CatchFeelConfig.NormalizeMinRarity(localPlayer:GetAttribute("CelebrationMinRarity"))
end

local function clearResultPetIcon()
	local existing = gui.ResultPetHost:FindFirstChild("PetIconRoot")
	if existing then
		existing:Destroy()
	end
end

local function mountResultPetIcon(petName: string?, rarity: string, catchAura: number, eventTag: string?)
	clearResultPetIcon()
	if typeof(petName) ~= "string" or petName == "" then
		return
	end

	local definition = PetConfig.GetByName(petName)
	PetIconUi.Mount(gui.ResultPetHost, {
		PetName = petName,
		Rarity = rarity,
		Icon = if definition then definition.Icon else "🐾",
		Size = 96,
		Position = UDim2.fromOffset(0, 0),
		ZIndex = 14,
		CatchAura = catchAura,
		EventTag = eventTag,
	})
end

local function shakeCamera(intensity: number, durationSeconds: number)
	if intensity <= 0 then
		return
	end

	shakeToken += 1
	local token = shakeToken
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	task.spawn(function()
		local elapsed = 0
		while elapsed < durationSeconds and token == shakeToken do
			local dt = RunService.RenderStepped:Wait()
			elapsed += dt
			local falloff = 1 - (elapsed / durationSeconds)
			local ox = (math.noise(elapsed * 28, token) - 0.5) * 2 * intensity * falloff
			local oy = (math.noise(token, elapsed * 28) - 0.5) * 2 * intensity * falloff
			camera.CFrame = camera.CFrame * CFrame.new(ox, oy, 0)
		end
	end)
end

local function pulseResult(scale: number)
	gui.ResultFrame.Size = UDim2.fromOffset(460, 180)
	if scale <= 1 then
		return
	end

	local grow = TweenService:Create(
		gui.ResultFrame,
		TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(math.floor(460 * scale), math.floor(180 * scale)) }
	)
	local shrink = TweenService:Create(
		gui.ResultFrame,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = UDim2.fromOffset(460, 180) }
	)
	grow:Play()
	grow.Completed:Connect(function()
		shrink:Play()
	end)
end

local function spawnCatchParticles(color: Color3, intensity: number)
	if intensity <= 0 then
		return
	end

	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local host = Instance.new("Part")
	host.Name = "CatchFeelParticles"
	host.Anchored = true
	host.CanCollide = false
	host.CanTouch = false
	host.CanQuery = false
	host.Transparency = 1
	host.Size = Vector3.new(0.2, 0.2, 0.2)
	host.CFrame = root.CFrame * CFrame.new(0, 2.2, -2)
	host.Parent = Workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.45
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35 + intensity * 0.15),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.4, 0.85)
	emitter.Speed = NumberRange.new(3 + intensity * 5, 9 + intensity * 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-110, 110)
	emitter.Rate = 0
	emitter.Parent = host
	emitter:Emit(math.clamp(math.floor(14 + intensity * 42), 12, 64))

	local ring = Instance.new("ParticleEmitter")
	ring.Name = "CatchFlareRing"
	ring.Color = ColorSequence.new(color:Lerp(Color3.fromRGB(255, 255, 255), 0.35))
	ring.LightEmission = 0.8
	ring.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(0.35, 0.55 + intensity * 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	ring.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	ring.Lifetime = NumberRange.new(0.35, 0.55)
	ring.Speed = NumberRange.new(0.4, 1.2)
	ring.SpreadAngle = Vector2.new(180, 180)
	ring.Rate = 0
	ring.Parent = host
	ring:Emit(math.clamp(math.floor(6 + intensity * 10), 4, 18))

	task.delay(1.8, function()
		if host.Parent then
			host:Destroy()
		end
	end)
end

local function readActiveBaitFromPlayer(): ActiveBaitPayload
	local activeId = localPlayer:GetAttribute("ActiveBait")
	if typeof(activeId) == "string" then
		local definition = BaitConfig.GetById(activeId)
		if definition then
			return {
				Id = definition.Id,
				Name = definition.Name,
				LuckMultiplier = definition.LuckMultiplier,
				CatchSpeed = definition.CatchSpeed,
				Icon = definition.Icon,
			}
		end
	end

	return activeBait
end

local function getGiftLuck(): number
	local gift = localPlayer:GetAttribute("GiftLuck")
	if typeof(gift) == "number" and gift > 0 then
		return gift
	end
	return 1
end

local function getUpgradeLuckBonus(): number
	local bonus = localPlayer:GetAttribute("LuckBonus")
	if typeof(bonus) == "number" then
		return bonus
	end
	return 1
end

local function getCooldownRemaining(): number
	local untilTime = localPlayer:GetAttribute("CatchCooldownUntil")
	if typeof(untilTime) ~= "number" or untilTime <= 0 then
		return 0
	end
	return math.max(0, untilTime - Workspace:GetServerTimeNow())
end

local lastThrowVisualKey = ""
local lastThrowIconKey = ""

local function styleThrowLabel(label: TextLabel, outlined: boolean, color: Color3)
	label.TextColor3 = color
	local existing = label:FindFirstChild("CandyTextStroke")
	if outlined then
		if not existing then
			UiTheme.TextStroke(label, 2)
		end
	elseif existing then
		existing:Destroy()
	end
end

local function setThrowIconTransparency(transparency: number)
	local glyph = gui.ThrowIconHost:FindFirstChild("Glyph")
	if not glyph then
		return
	end
	if glyph:IsA("ImageLabel") then
		glyph.ImageTransparency = transparency
	elseif glyph:IsA("TextLabel") then
		glyph.TextTransparency = transparency
	end
end

local function refreshThrowIcon(baitId: string)
	local key = IconAssets.KeyForBaitId(baitId)
	if key == lastThrowIconKey and gui.ThrowIconHost:FindFirstChild("Glyph") then
		return
	end
	lastThrowIconKey = key
	UiIcon.Mount(gui.ThrowIconHost, {
		Key = key,
		Name = "Glyph",
		Size = UDim2.fromScale(1, 1),
		ImageSize = 34,
	})
end

local function updateThrowButtonVisuals()
	refreshThrowIcon(activeBait.Id)
	gui.ThrowName.Text = activeBait.Name
	gui.ThrowButton.Visible = not isBarActive

	local cooldown = getCooldownRemaining()
	local ready = false
	local visualKey: string

	if cooldown > 0 then
		visualKey = string.format("cd:%.1f", cooldown)
		gui.ThrowHint.Text = string.format("Cooldown %.1fs", cooldown)
		if lastThrowVisualKey:sub(1, 2) ~= "cd" then
			gui.ThrowButton.BackgroundColor3 = COOLDOWN_COLOR
			gui.ThrowStroke.Color = UiTheme.Colors.Stroke
			UiTheme.Gradient(gui.ThrowButton, Color3.fromRGB(255, 230, 120), UiTheme.Colors.AccentAmberDim, 90)
			styleThrowLabel(gui.ThrowName, true, UiTheme.Colors.Text)
			styleThrowLabel(gui.ThrowHint, true, UiTheme.Colors.Text)
			gui.ThrowButton.BackgroundTransparency = 0
			setThrowIconTransparency(0.1)
		end
	elseif isNearCave then
		if nearCaveBlocked then
			visualKey = "vip_blocked"
			if lastThrowVisualKey ~= visualKey then
				gui.ThrowButton.BackgroundColor3 = VIP_BLOCKED_COLOR
				gui.ThrowStroke.Color = UiTheme.Colors.Stroke
				UiTheme.Gradient(gui.ThrowButton, Color3.fromRGB(220, 200, 120), VIP_BLOCKED_COLOR, 90)
				gui.ThrowHint.Text = CaveConfig.VipNoAccessHint
				styleThrowLabel(gui.ThrowName, true, UiTheme.Colors.Text)
				styleThrowLabel(gui.ThrowHint, true, UiTheme.Colors.Warning)
				gui.ThrowButton.BackgroundTransparency = 0
				setThrowIconTransparency(0.1)
			end
		elseif nearCaveLuckMult > 1 then
			local isVipZone = nearCaveLuckMult >= CaveConfig.VipLuckMultiplier
			visualKey = if isVipZone then "vip_ready" else "map2_ready"
			ready = true
			if lastThrowVisualKey ~= visualKey then
				if isVipZone then
					gui.ThrowButton.BackgroundColor3 = VIP_NEAR_COLOR
					gui.ThrowStroke.Color = UiTheme.Colors.Stroke
					UiTheme.Gradient(gui.ThrowButton, Color3.fromRGB(255, 245, 140), UiTheme.Colors.AccentVip, 90)
					gui.ThrowHint.Text = CaveConfig.VipNearHint
				else
					gui.ThrowButton.BackgroundColor3 = NEAR_COLOR
					gui.ThrowStroke.Color = UiTheme.Colors.Stroke
					UiTheme.Gradient(
						gui.ThrowButton,
						Color3.fromRGB(140, 255, 190),
						UiTheme.Colors.AccentCyanDim,
						90
					)
					gui.ThrowHint.Text = CaveConfig.Map2NearHint
				end
				styleThrowLabel(gui.ThrowName, true, UiTheme.Colors.Text)
				styleThrowLabel(gui.ThrowHint, true, UiTheme.Colors.Text)
				gui.ThrowButton.BackgroundTransparency = 0
				setThrowIconTransparency(0)
			end
		else
			local atSpawn = false
			local character = localPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				atSpawn = CaveConfig.IsAtNormalThrowSpawn(root.Position)
					or CaveConfig.IsAtVipThrowSpawn(root.Position)
			end
			visualKey = if atSpawn then "ready_spawn" else "ready"
			ready = true
			if lastThrowVisualKey ~= visualKey then
				gui.ThrowButton.BackgroundColor3 = NEAR_COLOR
				gui.ThrowStroke.Color = UiTheme.Colors.Stroke
				UiTheme.Gradient(
					gui.ThrowButton,
					Color3.fromRGB(140, 255, 190),
					UiTheme.Colors.AccentCyanDim,
					90
				)
				gui.ThrowHint.Text = if atSpawn then "Spawn → cave" else "E or tap"
				styleThrowLabel(gui.ThrowName, true, UiTheme.Colors.Text)
				styleThrowLabel(gui.ThrowHint, true, UiTheme.Colors.Text)
				gui.ThrowButton.BackgroundTransparency = 0
				setThrowIconTransparency(0)
			end
		end
	else
		visualKey = "far"
		if lastThrowVisualKey ~= visualKey then
			gui.ThrowButton.BackgroundColor3 = DISABLED_COLOR
			gui.ThrowStroke.Color = UiTheme.Colors.Stroke
			UiTheme.Gradient(gui.ThrowButton, Color3.fromRGB(230, 238, 248), DISABLED_COLOR, 90)
			gui.ThrowHint.Text = "Spawn or cave"
			styleThrowLabel(gui.ThrowName, false, UiTheme.Colors.TextDark)
			styleThrowLabel(gui.ThrowHint, false, UiTheme.Colors.TextDim)
			gui.ThrowButton.BackgroundTransparency = 0
			setThrowIconTransparency(0.2)
		end
	end

	lastThrowVisualKey = visualKey
	setThrowReadyPulse(ready and not isBarActive)
end

local function getZoneLuckMult(): number
	if isNearCave and not nearCaveBlocked and nearCaveLuckMult > 0 then
		return nearCaveLuckMult
	end
	return 1
end

local function publishHudCaveLuck()
	local mult = getZoneLuckMult()
	if localPlayer:GetAttribute(HudLuck.CaveAttribute) ~= mult then
		localPlayer:SetAttribute(HudLuck.CaveAttribute, mult)
	end
end

local function setActiveBait(payload: ActiveBaitPayload)
	activeBait = payload
	gui.BaitLabel.Text = string.format("%s ∞", activeBait.Name)
	updateThrowButtonVisuals()
end

local function updateFillVisuals()
	local barMultiplier = LuckConfig.GetLuckMultiplier(fillAmount)
	local totalMultiplier = barMultiplier * HudLuck.GetTotal(localPlayer, activeBait.LuckMultiplier)
	local percent = LuckConfig.GetFillPercent(fillAmount)

	gui.BarFill.Size = UDim2.fromScale(1, fillAmount)
	gui.LuckLabel.Text = string.format(
		"Luck: %s (%d%%)",
		BaitConfig.FormatLuck(totalMultiplier),
		math.floor(percent + 0.5)
	)

	local color = UiTheme.Colors.Stock
	if fillAmount < 0.35 then
		color = UiTheme.Colors.AccentRed:Lerp(UiTheme.Colors.AccentAmber, fillAmount / 0.35)
	elseif fillAmount < 0.7 then
		color = UiTheme.Colors.AccentAmber:Lerp(UiTheme.Colors.Stock, (fillAmount - 0.35) / 0.35)
	else
		color = UiTheme.Colors.Stock:Lerp(UiTheme.Colors.AccentCyan, (fillAmount - 0.7) / 0.3)
	end

	gui.BarFill.BackgroundColor3 = color
	gui.SubmitButton.BackgroundColor3 = color
	local submitGradient = gui.SubmitButton:FindFirstChildOfClass("UIGradient")
	local top = color:Lerp(Color3.fromRGB(255, 255, 255), 0.35)
	if submitGradient then
		submitGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, top),
			ColorSequenceKeypoint.new(1, color),
		})
	else
		UiTheme.Gradient(gui.SubmitButton, top, color, 90)
	end
end

local function cancelAutoCatchClick()
	autoCatchClickToken += 1
end

local scheduleAutoCatchClick: () -> () = function() end

local function stopLuckBar()
	cancelAutoCatchClick()
	isBarActive = false
	hasSubmitted = false
	gui.Panel.Visible = false
	setJumpEnabled(true)
	updateThrowButtonVisuals()
end

local function showResult(
	titleText: string,
	subtitleText: string,
	titleColor: Color3,
	durationSeconds: number?,
	isNew: boolean?,
	petName: string?,
	rarity: string?,
	catchAura: number?,
	eventTag: string?,
	extras: {
		TitleScale: number?,
		PreTitle: string?,
		Jitter: boolean?,
		RaiseGui: boolean?,
	}?
)
	resultHideToken += 1
	local token = resultHideToken

	local wash = titleColor:Lerp(Color3.fromRGB(255, 255, 255), 0.42)
	gui.ScreenGui.DisplayOrder = if extras and extras.RaiseGui then RESULT_GUI_ORDER else BAIT_GUI_ORDER
	gui.ResultFrame.BackgroundColor3 = wash
	gui.ResultFrame.Position = UDim2.fromScale(0.5, 0.32)
	gui.ResultFrame.Visible = true
	gui.ResultTitle.Text = if extras and extras.PreTitle then extras.PreTitle else titleText
	gui.ResultTitle.TextColor3 = UiTheme.Colors.Text
	gui.ResultSubtitle.Text = subtitleText
	gui.ResultSubtitle.TextColor3 = UiTheme.Colors.TextDark
	gui.ResultStroke.Color = titleColor:Lerp(UiTheme.Colors.Stroke, 0.25)
	gui.ResultStroke.Thickness = 4
	gui.ResultStroke.Transparency = 0
	gui.NewBadge.Visible = isNew == true
	UiTheme.BounceIn(gui.ResultFrame, 0.62)

	local titleScale = if extras and extras.TitleScale then extras.TitleScale else 1
	local titleSlam = gui.ResultTitle:FindFirstChild("TitleSlam")
	if not (titleSlam and titleSlam:IsA("UIScale")) then
		if titleSlam then
			titleSlam:Destroy()
		end
		local created = Instance.new("UIScale")
		created.Name = "TitleSlam"
		created.Parent = gui.ResultTitle
		titleSlam = created
	end
	local slam = titleSlam :: UIScale
	slam.Scale = 0.55
	gui.ResultTitle.Position = UDim2.fromOffset(24, -4)
	gui.ResultTitle.TextTransparency = 0.15
	TweenService:Create(
		slam,
		TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = titleScale }
	):Play()
	TweenService:Create(
		gui.ResultTitle,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(24, 24), TextTransparency = 0 }
	):Play()

	if extras and extras.PreTitle then
		task.delay(0.25, function()
			if token == resultHideToken then
				gui.ResultTitle.Text = titleText
			end
		end)
	end

	if extras and extras.Jitter then
		task.spawn(function()
			local elapsed = 0
			while elapsed < 0.28 and token == resultHideToken do
				elapsed += RunService.RenderStepped:Wait()
				local ox = (math.random() - 0.5) * 12
				local oy = (math.random() - 0.5) * 8
				gui.ResultFrame.Position = UDim2.new(0.5, ox, 0.32, oy)
			end
			if token == resultHideToken then
				gui.ResultFrame.Position = UDim2.fromScale(0.5, 0.32)
			end
		end)
	end

	if typeof(petName) == "string" and typeof(rarity) == "string" then
		mountResultPetIcon(petName, rarity, catchAura or 0, eventTag)
	else
		clearResultPetIcon()
	end

	local duration = durationSeconds or CatchFeelConfig.CommonDuration
	task.delay(duration, function()
		if token == resultHideToken then
			gui.ResultFrame.Visible = false
			gui.NewBadge.Visible = false
			gui.ScreenGui.DisplayOrder = BAIT_GUI_ORDER
			clearResultPetIcon()
		end
	end)
end

local function startLuckBar(payload: ActiveBaitPayload?)
	if payload then
		setActiveBait(payload)
	else
		setActiveBait(readActiveBaitFromPlayer())
	end

	fillAmount = 0
	fillDirection = 1
	isBarActive = true
	hasSubmitted = false
	cancelAutoCatchClick()
	CatchCinematic.Stop()
	gui.ScreenGui.DisplayOrder = BAIT_GUI_ORDER
	gui.ResultFrame.Visible = false
	gui.NewBadge.Visible = false
	clearResultPetIcon()
	gui.Panel.Visible = true
	gui.StatusLabel.Text = "Luck fills up. Press SPACE when it's high."
	gui.SubmitButton.Text = "SPACE to Stop"
	gui.SubmitButton.Active = true
	gui.SubmitButton.AutoButtonColor = true
	setJumpEnabled(false)
	updateFillVisuals()
	updateThrowButtonVisuals()
	playFeelSound("Throw", 0.45)
	scheduleAutoCatchClick()
end

local function submitCurrentFill()
	if not isBarActive or hasSubmitted then
		return
	end

	hasSubmitted = true
	cancelAutoCatchClick()
	gui.StatusLabel.Text = "Locked! Catching pet..."
	gui.SubmitButton.Text = "Locked In"
	gui.SubmitButton.Active = false
	gui.SubmitButton.AutoButtonColor = false
	setJumpEnabled(true)
	playFeelSound("Lock", 0.5)

	submitLuckRemote:FireServer(fillAmount)
end

scheduleAutoCatchClick = function()
	if localPlayer:GetAttribute("AutoThrow") ~= true then
		return
	end

	autoCatchClickToken += 1
	local token = autoCatchClickToken
	local period = 2 / math.max(0.05, LuckConfig.FillSpeed)
	local delaySeconds = math.random() * period

	task.delay(delaySeconds, function()
		if token ~= autoCatchClickToken then
			return
		end
		if localPlayer:GetAttribute("AutoThrow") ~= true then
			return
		end
		submitCurrentFill()
	end)
end

local function refreshNearCave()
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		isNearCave = false
		nearCaveBlocked = false
		nearCaveLuckMult = 1
		publishHudCaveLuck()
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
		nearCaveLuckMult = CaveConfig.GetPlaceLuckMultiplier(caveType)
		local attrMult = nearest:GetAttribute("CaveLuckMult")
		if typeof(attrMult) == "number" and attrMult > 0 then
			nearCaveLuckMult = attrMult
		end
		nearCaveBlocked = CaveConfig.RequiresVip(caveType) and localPlayer:GetAttribute("VipAccess") ~= true
	else
		nearCaveLuckMult = 1
		nearCaveBlocked = false
	end
	publishHudCaveLuck()
end

local function requestThrow()
	if isBarActive or hasSubmitted then
		return
	end

	if not TutorialGate.TryAction("throw_bait") then
		return
	end

	local now = os.clock()
	if now - lastThrowRequestAt < THROW_REQUEST_COOLDOWN then
		return
	end

	if getCooldownRemaining() > 0 then
		showToast(string.format("Wait %.1fs before throwing again.", getCooldownRemaining()))
		return
	end

	if not isNearCave then
		showToast("Stand at spawn or near a cave to throw bait.")
		return
	end

	if nearCaveBlocked then
		if VipConfig.IsConfigured() then
			VipPurchase.Prompt(showToast)
		else
			showToast(CaveConfig.VipLockedToast)
		end
		return
	end

	lastThrowRequestAt = now
	requestThrowRemote:FireServer()
end

gui.SubmitButton.MouseButton1Click:Connect(submitCurrentFill)
gui.ThrowButton.MouseButton1Click:Connect(requestThrow)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.E then
		if gameProcessed then
			return
		end
		if isBarActive then
			return
		end
		requestThrow()
		return
	end

	if input.KeyCode ~= Enum.KeyCode.Space then
		return
	end

	-- Always consume Space while the luck bar is active so jump cannot trigger.
	if isBarActive and not hasSubmitted then
		submitCurrentFill()
		return
	end

	if gameProcessed then
		return
	end
end)

RunService.RenderStepped:Connect(function(deltaTime)
	refreshNearCave()
	updateThrowButtonVisuals()

	if not isBarActive or hasSubmitted then
		return
	end

	fillAmount += fillDirection * LuckConfig.FillSpeed * deltaTime

	if fillAmount >= 1 then
		fillAmount = 1
		fillDirection = -1
	elseif fillAmount <= 0 then
		fillAmount = 0
		fillDirection = 1
	end

	updateFillVisuals()
end)

local function parseActiveBait(raw: any): ActiveBaitPayload?
	if typeof(raw) ~= "table" then
		return nil
	end

	if typeof(raw.Id) ~= "string" then
		return nil
	end

	return {
		Id = raw.Id,
		Name = if typeof(raw.Name) == "string" then raw.Name else "Basic Bait",
		LuckMultiplier = if typeof(raw.LuckMultiplier) == "number" then raw.LuckMultiplier else 1,
		CatchSpeed = if typeof(raw.CatchSpeed) == "number" then raw.CatchSpeed else 1,
		Icon = if typeof(raw.Icon) == "string" then raw.Icon else "🪱",
	}
end

startBaitRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	startLuckBar(parseActiveBait(payload.ActiveBait))
end)

petResultRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local parsed = parseActiveBait(payload.ActiveBait)
	if parsed then
		setActiveBait(parsed)
	end

	local payloadType = payload.Type
	if payloadType == "Error" then
		cancelAutoCatchClick()
		gui.Panel.Visible = false
		isBarActive = false
		hasSubmitted = false
		setJumpEnabled(true)
		updateThrowButtonVisuals()
		local message = payload.Message
		if typeof(message) ~= "string" then
			message = "Something went wrong."
		end

		playFeelSound("Error", 0.4)
		showResult("TRY AGAIN", message, UiTheme.Colors.Danger, 2.2, false)
		return
	end

	if payloadType == "BagWarn" then
		local message = payload.Message
		if typeof(message) == "string" and message ~= "" then
			UiToast.Show(message, 3.2)
		end
		return
	end

	if payloadType == "Map2Unlock" then
		local message = payload.Message
		if typeof(message) == "string" and message ~= "" then
			UiToast.Show(message, 4)
		end
		return
	end

	if payloadType == "Map3Unlock" then
		local message = payload.Message
		if typeof(message) == "string" and message ~= "" then
			UiToast.Show(message, 4)
		end
		return
	end

	if payloadType == "EquipHint" then
		local message = payload.Message
		if typeof(message) == "string" and message ~= "" then
			UiToast.Show(message, 3.5)
		end
		return
	end

	if payloadType == "ThrowAccepted" then
		gui.StatusLabel.Text = "Catching pet..."
		return
	end

	if payloadType == "Result" then
		stopLuckBar()

		local petName = if typeof(payload.PetName) == "string" then payload.PetName else "Unknown Pet"
		local rarity = if typeof(payload.Rarity) == "string" then payload.Rarity else "Common"
		local multiplier = if typeof(payload.LuckMultiplier) == "number" then payload.LuckMultiplier else 1
		local eventTag = if typeof(payload.EventTag) == "string" and payload.EventTag ~= "" then payload.EventTag else nil
		local isNew = payload.IsNew == true
		local tier = CatchFeelConfig.GetTier(rarity)
		local celebrate = CatchFeelConfig.ShouldCelebrate(rarity, getCelebrationMinSetting())
		local titleColor = CatchFeelConfig.GetResultColor(rarity)
		local titleText = CatchFeelConfig.GetTitle(rarity)

		local subtitle = string.format(
			"%s  ·  %s  ·  luck %s",
			petName,
			rarity,
			BaitConfig.FormatLuck(multiplier)
		)
		if eventTag then
			subtitle ..= string.format("  ·  %s", eventTag)
		end
		if isNew then
			subtitle = "NEW DISCOVERY!\n" .. subtitle
		end

		local resultAura = 0
		if celebrate then
			-- Rare has Burst=0 (shake-only in world) but still gets a soft Result UI aura.
			resultAura = if tier.Burst > 0 then tier.Burst else 0.28
		end

		local function revealResult(cinematic: boolean)
			local cinematicProfile = CatchFeelConfig.GetCinematic(rarity)
			showResult(titleText, subtitle, titleColor, tier.Duration, isNew, petName, rarity, resultAura, eventTag, {
				TitleScale = tier.TitleScale,
				PreTitle = if cinematicProfile then cinematicProfile.PreTitle else nil,
				Jitter = cinematic and cinematicProfile ~= nil and cinematicProfile.Style == "Glitch",
				RaiseGui = cinematic,
			})
			if celebrate then
				pulseResult(tier.Pulse)
			end
		end

		if celebrate then
			spawnCatchParticles(titleColor, tier.Burst)
			playFeelSound(tier.CatchSound, 0.45 + math.min(0.4, tier.Shake))
			if CatchFeelConfig.ShouldCinematic(rarity) then
				CatchCinematic.Play({
					Rarity = rarity,
					Color = titleColor,
					Shake = tier.Shake,
					OnUiReady = function()
						revealResult(true)
					end,
				})
			else
				revealResult(false)
				shakeCamera(tier.Shake, math.clamp(0.18 + tier.Shake * 0.35, 0.2, 0.55))
			end
		else
			revealResult(false)
			playFeelSound("CatchCommon", 0.4)
		end

		if isNew then
			playFeelSound("NewDiscovery", 0.55)
		end

		updateThrowButtonVisuals()
	end
end)

setActiveBait(readActiveBaitFromPlayer())

localPlayer:GetAttributeChangedSignal("ActiveBait"):Connect(function()
	setActiveBait(readActiveBaitFromPlayer())
	if isBarActive then
		updateFillVisuals()
	end
end)

localPlayer:GetAttributeChangedSignal("LuckBonus"):Connect(function()
	if isBarActive then
		updateFillVisuals()
	end
end)

localPlayer:GetAttributeChangedSignal("GiftLuck"):Connect(function()
	updateFillVisuals()
end)

localPlayer:GetAttributeChangedSignal("CatchCooldownUntil"):Connect(function()
	updateThrowButtonVisuals()
end)

localPlayer:GetAttributeChangedSignal("VipAccess"):Connect(function()
	refreshNearCave()
	updateThrowButtonVisuals()
	if isBarActive then
		updateFillVisuals()
	end
end)

localPlayer:GetAttributeChangedSignal("AutoThrow"):Connect(function()
	if localPlayer:GetAttribute("AutoThrow") ~= true then
		cancelAutoCatchClick()
	end
end)
