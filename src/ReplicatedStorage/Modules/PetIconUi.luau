--!strict

--[[
	Pet icon helper for UI rows.
	ViewportFrame from ReplicatedStorage.PetPreviews; emoji fallback.
	Candy rarity wash + pulse for endgame tiers.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PetConfig = require(script.Parent:WaitForChild("PetConfig"))
local PetFacing = require(script.Parent:WaitForChild("PetFacing"))
local PetRarityFx = require(script.Parent:WaitForChild("PetRarityFx"))
local IconAssets = require(script.Parent:WaitForChild("IconAssets"))
local UiIcon = require(script.Parent:WaitForChild("UiIcon"))
local UiTheme = require(script.Parent:WaitForChild("UiTheme"))

local PetIconUi = {}

local PREVIEW_FOLDER_NAME = "PetPreviews"

local function create(className: string, props: { [string]: any }, parent: Instance?): Instance
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function findPreviewModel(petName: string): Model?
	local folder = ReplicatedStorage:FindFirstChild(PREVIEW_FOLDER_NAME)
	if not folder or not folder:IsA("Folder") then
		return nil
	end
	local model = folder:FindFirstChild(petName)
	if model and model:IsA("Model") then
		return model
	end
	return nil
end

local function applyCatchAura(model: Model, rarity: string, intensity: number)
	if intensity <= 0 then
		return
	end

	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not primary then
		return
	end

	local color = PetConfig.GetRarityColor(rarity)
	local rate = math.clamp(8 + intensity * 18, 8, 28)
	local size = math.clamp(0.18 + intensity * 0.12, 0.18, 0.4)

	local light = Instance.new("PointLight")
	light.Name = "CatchAuraLight"
	light.Color = color
	light.Brightness = math.clamp(0.7 + intensity * 0.7, 0.7, 1.6)
	light.Range = math.clamp(5 + intensity * 4, 5, 12)
	light.Shadows = false
	light.Parent = primary

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "CatchAuraParticles"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.7
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.45, 0.95)
	emitter.Speed = NumberRange.new(0.2, 0.75)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-70, 70)
	emitter.Rate = rate
	emitter.Drag = 1.2
	emitter.Parent = primary

	local highlight = Instance.new("Highlight")
	highlight.Name = "CatchAuraHighlight"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = color
	highlight.FillTransparency = math.clamp(0.82 - intensity * 0.12, 0.55, 0.85)
	highlight.OutlineColor = color
	highlight.OutlineTransparency = math.clamp(0.35 - intensity * 0.2, 0.05, 0.4)
	highlight.Parent = model
end

function PetIconUi.SetupViewport(viewport: ViewportFrame, source: Model, rarity: string?, catchAura: number?, eventTag: string?): boolean
	local world = Instance.new("WorldModel")
	world.Parent = viewport

	local clone = source:Clone()
	clone.Parent = world

	local hasPart = clone:FindFirstChildWhichIsA("BasePart", true)
	if not hasPart then
		return false
	end

	PetFacing.AlignForPortrait(clone)

	local extents = clone:GetExtentsSize()
	local maxDim = math.max(extents.X, extents.Y, extents.Z, 1)
	local distance = maxDim * 1.7
	-- Face looks at -Z after AlignForPortrait; sit the camera in front, slightly above and aside.
	local camPos = Vector3.new(distance * 0.18, distance * 0.34, -distance * 1.08)
	local lookAt = Vector3.new(0, maxDim * 0.08, -maxDim * 0.1)

	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	camera.CFrame = CFrame.lookAt(camPos, lookAt)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.LightDirection = Vector3.new(0.2, -0.55, 1)
	if eventTag == "Rainbow" then
		viewport.LightColor = Color3.fromRGB(255, 200, 240)
		viewport.Ambient = Color3.fromRGB(255, 230, 245)
	end

	if typeof(catchAura) == "number" and catchAura > 0 and typeof(rarity) == "string" then
		applyCatchAura(clone, rarity, catchAura)
	end
	-- World event aura (Highlight/particles) does not render inside ViewportFrames.

	return true
end

export type MountProps = {
	PetName: string?,
	Rarity: string?,
	Icon: string?,
	Size: number?,
	Position: UDim2?,
	Locked: boolean?,
	ZIndex: number?,
	CatchAura: number?,
	EventTag: string?,
	Pulse: boolean?,
}

function PetIconUi.Mount(parent: GuiObject, props: MountProps): Frame
	local existing = parent:FindFirstChild("PetIconRoot")
	if existing then
		existing:Destroy()
	end

	local size = props.Size or 44
	local rarity = props.Rarity or "Common"
	local rarityColor = PetConfig.GetRarityColor(rarity)
	local uiFx = if props.Locked ~= true then PetRarityFx.GetUiTier(rarity) else nil
	local iconText = props.Icon or "🐾"
	if props.Locked == true then
		iconText = "❓"
	end

	-- Candy rarity wash behind the model
	local wash = rarityColor:Lerp(Color3.fromRGB(255, 255, 255), 0.28)
	local root = create("Frame", {
		Name = "PetIconRoot",
		BackgroundColor3 = wash,
		BackgroundTransparency = if props.Locked == true then 0.45 else 0.05,
		BorderSizePixel = 0,
		Position = props.Position or UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(size, size),
		ZIndex = props.ZIndex or 1,
		ClipsDescendants = true,
	}, parent) :: Frame

	create("UICorner", { CornerRadius = UDim.new(0, 12) }, root)

	local eventTag = if typeof(props.EventTag) == "string" and props.EventTag ~= "" then props.EventTag else nil
	local isRainbow = eventTag == "Rainbow"
	local strokeThickness = if uiFx then uiFx.StrokeThickness else 2.5
	local strokeTransparency = if uiFx then uiFx.StrokeTransparency else 0
	if isRainbow then
		strokeThickness = math.max(strokeThickness, 3.4)
		strokeTransparency = 0
	end
	create("UIStroke", {
		Name = "RarityStroke",
		Color = if isRainbow
			then Color3.fromRGB(255, 140, 220)
			else rarityColor:Lerp(Color3.fromRGB(20, 20, 30), 0.15),
		Thickness = strokeThickness,
		Transparency = strokeTransparency,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, root)

	-- Soft radial candy glow
	local glow = create("Frame", {
		Name = "RarityGlow",
		BackgroundColor3 = if isRainbow then Color3.fromRGB(255, 170, 90) else rarityColor,
		BackgroundTransparency = if isRainbow then 0.35 else 0.55,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.85, 0.7),
		ZIndex = (props.ZIndex or 1),
	}, root) :: Frame
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, glow)
	if isRainbow then
		create("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 130)),
				ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 210, 70)),
				ColorSequenceKeypoint.new(0.65, Color3.fromRGB(80, 220, 160)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 120, 255)),
			}),
			Rotation = 55,
		}, glow)
	end

	local petName = props.PetName
	local preview = if typeof(petName) == "string" and props.Locked ~= true then findPreviewModel(petName) else nil

	if preview then
		local viewport = create("ViewportFrame", {
			Name = "Viewport",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = (props.ZIndex or 1) + 1,
			Ambient = Color3.fromRGB(230, 230, 240),
			LightColor = if isRainbow
				then Color3.fromRGB(255, 200, 240)
				else rarityColor:Lerp(Color3.fromRGB(255, 255, 255), 0.35),
			LightDirection = Vector3.new(-0.8, -1, -0.6),
		}, root) :: ViewportFrame
		PetIconUi.SetupViewport(viewport, preview, rarity, props.CatchAura, eventTag)
	else
		local emoji = create("TextLabel", {
			Name = "Emoji",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = iconText,
			TextSize = math.floor(size * 0.55),
			Font = UiTheme.FontTitle,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			ZIndex = (props.ZIndex or 1) + 1,
		}, root) :: TextLabel
		UiTheme.TextStroke(emoji, 2)
	end

	if uiFx and uiFx.Badge and props.Locked ~= true then
		local badgeSize = math.max(14, math.floor(size * 0.32))
		local badgeKey = IconAssets.KeyForRarityBadge(rarity)
		if badgeKey and IconAssets.HasImage(badgeKey) then
			UiIcon.Mount(root, {
				Key = badgeKey,
				Name = "EndgameBadge",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -2, 0, 0),
				Size = UDim2.fromOffset(badgeSize, badgeSize),
				ZIndex = (props.ZIndex or 1) + 3,
				ImageSize = math.max(10, math.floor(size * 0.28)),
			})
		else
			local badge = create("TextLabel", {
				Name = "EndgameBadge",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -2, 0, 0),
				Size = UDim2.fromOffset(badgeSize, badgeSize),
				Text = uiFx.Badge,
				TextSize = math.max(10, math.floor(size * 0.28)),
				Font = UiTheme.FontTitle,
				TextColor3 = Color3.fromRGB(255, 250, 230),
				ZIndex = (props.ZIndex or 1) + 3,
			}, root) :: TextLabel
			UiTheme.TextStroke(badge, 1.8)
		end
	end

	if isRainbow and props.Locked ~= true then
		local badgeSize = math.max(13, math.floor(size * 0.3))
		local rainbowBadge = create("TextLabel", {
			Name = "RainbowBadge",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 1, 1, -1),
			Size = UDim2.fromOffset(badgeSize, badgeSize),
			Text = "🌈",
			TextSize = math.max(10, math.floor(size * 0.26)),
			Font = UiTheme.FontTitle,
			ZIndex = (props.ZIndex or 1) + 3,
		}, root) :: TextLabel
		UiTheme.TextStroke(rainbowBadge, 1.4)
	end

	local shouldPulse = props.Pulse == true or (uiFx ~= nil and props.Locked ~= true) or isRainbow

	-- Tiny pop when mounted, then optional rarity pulse
	local scale = Instance.new("UIScale")
	scale.Scale = 0.75
	scale.Parent = root
	local pop = TweenService:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	pop:Play()
	if shouldPulse then
		pop.Completed:Once(function()
			if root.Parent then
				UiTheme.Pulse(root, if uiFx then 1.07 else 1.04, if uiFx then 0.75 else 1.1)
			end
		end)
	end

	return root
end

return PetIconUi
