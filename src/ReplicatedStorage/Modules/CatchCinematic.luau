--!strict

--[[
	Epic+ catch cinematic: impact on the player, hero shot on the flying pet, then UI.
	Client-only. Server uses CatchFeelConfig for aura / fly-in timing.
]]

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CatchFeelConfig = require(script.Parent:WaitForChild("CatchFeelConfig"))

export type PlayRequest = {
	Rarity: string,
	Color: Color3,
	Shake: number,
	OnUiReady: () -> (),
}

local CatchCinematic = {}

local SKIP_ACTION = "CatchCinematicSkip"
local COLOR_NAME = "CatchCinematicColor"
local BLUR_NAME = "CatchCinematicBlur"
local DOF_NAME = "CatchCinematicDof"
local BLOOM_NAME = "CatchCinematicBloom"

local playToken = 0
local activeRestore: (() -> ())? = nil
local uiFired = false

local function smoothstep(alpha: number): number
	local a = math.clamp(alpha, 0, 1)
	return a * a * (3 - 2 * a)
end

local function easeOutCubic(alpha: number): number
	local t = 1 - math.clamp(alpha, 0, 1)
	return 1 - t * t * t
end

local function flatten(vector: Vector3): Vector3
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude < 0.05 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

local function getLocalPlayer(): Player?
	return Players.LocalPlayer
end

local function getPlayerLook(): Vector3?
	local player = getLocalPlayer()
	local character = player and player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position + Vector3.new(0, 1.4, 0)
	end
	return nil
end

local function getHumanoid(): Humanoid?
	local player = getLocalPlayer()
	local character = player and player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function findReveal(): Model?
	local player = getLocalPlayer()
	if not player then
		return nil
	end
	for _, instance in ipairs(CollectionService:GetTagged(CatchFeelConfig.RevealTag)) do
		if instance:IsA("Model") and instance:GetAttribute("OwnerUserId") == player.UserId and instance.Parent then
			return instance
		end
	end
	return nil
end

local function waitForReveal(token: number, timeout: number): Model?
	local found = findReveal()
	if found then
		return found
	end

	local deadline = os.clock() + timeout
	local added: RBXScriptConnection? = nil
	local resolved: Model? = nil
	added = CollectionService:GetInstanceAddedSignal(CatchFeelConfig.RevealTag):Connect(function(instance)
		if token ~= playToken then
			return
		end
		local player = getLocalPlayer()
		if player and instance:IsA("Model") and instance:GetAttribute("OwnerUserId") == player.UserId then
			resolved = instance
		end
	end)

	while token == playToken and os.clock() < deadline and resolved == nil do
		RunService.Heartbeat:Wait()
		local live = findReveal()
		if live then
			resolved = live
			break
		end
	end

	if added then
		added:Disconnect()
	end
	return resolved or findReveal()
end

local function getLookTarget(reveal: Model?): Vector3
	if reveal and reveal.Parent then
		return reveal:GetPivot().Position + Vector3.new(0, 0.25, 0)
	end
	return getPlayerLook() or Vector3.zero
end

local function wipeEffect(name: string)
	local existing = Lighting:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
end

local function ensureColor(): ColorCorrectionEffect
	wipeEffect(COLOR_NAME)
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = COLOR_NAME
	effect.Parent = Lighting
	return effect
end

local function ensureBlur(): BlurEffect
	wipeEffect(BLUR_NAME)
	local effect = Instance.new("BlurEffect")
	effect.Name = BLUR_NAME
	effect.Size = 0
	effect.Parent = Lighting
	return effect
end

local function ensureDof(): DepthOfFieldEffect
	wipeEffect(DOF_NAME)
	local effect = Instance.new("DepthOfFieldEffect")
	effect.Name = DOF_NAME
	effect.FarIntensity = 0
	effect.NearIntensity = 0
	effect.FocusDistance = 8
	effect.InFocusRadius = 10
	effect.Parent = Lighting
	return effect
end

local function ensureBloom(intensity: number): BloomEffect?
	wipeEffect(BLOOM_NAME)
	if intensity <= 0 then
		return nil
	end
	local effect = Instance.new("BloomEffect")
	effect.Name = BLOOM_NAME
	effect.Intensity = intensity
	effect.Size = 22 + intensity * 10
	effect.Threshold = math.clamp(0.92 - intensity * 0.08, 0.72, 0.95)
	effect.Parent = Lighting
	return effect
end

local function destroyFx()
	wipeEffect(COLOR_NAME)
	wipeEffect(BLUR_NAME)
	wipeEffect(DOF_NAME)
	wipeEffect(BLOOM_NAME)
end

local function ensureGui(): ScreenGui
	local player = getLocalPlayer()
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		local gui = Instance.new("ScreenGui")
		gui.Name = "CatchCinematicGui"
		return gui
	end

	local existing = playerGui:FindFirstChild("CatchCinematicGui")
	if existing and existing:IsA("ScreenGui") then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "CatchCinematicGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 7
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	return gui
end

local function createFrame(name: string, parent: Instance, props: { [string]: any }): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BorderSizePixel = 0
	for key, value in pairs(props) do
		(frame :: any)[key] = value
	end
	frame.Parent = parent
	return frame
end

local function bindSkip(onSkip: () -> ())
	ContextActionService:BindActionAtPriority(SKIP_ACTION, function(_action, state)
		if state == Enum.UserInputState.Begin then
			onSkip()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, 3400, Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
end

local function unbindSkip()
	ContextActionService:UnbindAction(SKIP_ACTION)
end

local function setLocalTransparency(model: Model?, value: number)
	if not model then
		return
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = value
		end
	end
end

local function mountOverlays(gui: ScreenGui, profile: CatchFeelConfig.CinematicProfile, color: Color3): Frame
	local root = createFrame("OverlayRoot", gui, {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
	})

	local overlay = profile.Overlay
	if overlay == "Rays" or overlay == "Ceremony" then
		for index = 1, 7 do
			local ray = createFrame("Ray" .. index, root, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 0.62),
				Size = UDim2.fromOffset(5, 520),
				BackgroundColor3 = color:Lerp(Color3.fromRGB(255, 248, 220), 0.45),
				BackgroundTransparency = 0.62,
				Rotation = -54 + index * 15,
				ZIndex = 2,
			})
			local gradient = Instance.new("UIGradient")
			gradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.35, 0.25),
				NumberSequenceKeypoint.new(1, 1),
			})
			gradient.Rotation = 90
			gradient.Parent = ray
		end
	end

	if overlay == "Flare" or overlay == "Ceremony" then
		local flare = createFrame("Flare", root, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.46),
			Size = UDim2.fromOffset(40, 40),
			BackgroundColor3 = Color3.fromRGB(255, 245, 200),
			BackgroundTransparency = 0.82,
			ZIndex = 3,
		})
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = flare
		TweenService:Create(
			flare,
			TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromOffset(280, 280), BackgroundTransparency = 0.9 }
		):Play()
	end

	if overlay == "Streaks" then
		local rotations = { -11, 7, -3 }
		for index, rotation in ipairs(rotations) do
			local streak = createFrame("Streak" .. index, root, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.32 + index * 0.12),
				Size = UDim2.new(1.2, 0, 0, 3 + index),
				BackgroundColor3 = color:Lerp(Color3.fromRGB(255, 255, 255), 0.4),
				BackgroundTransparency = 0.35,
				Rotation = rotation,
				ZIndex = 3,
			})
			local gradient = Instance.new("UIGradient")
			gradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.15),
				NumberSequenceKeypoint.new(1, 1),
			})
			gradient.Parent = streak
		end
	end

	if overlay == "Glitch" then
		createFrame("SplitRed", root, {
			BackgroundColor3 = Color3.fromRGB(255, 40, 90),
			BackgroundTransparency = 0.88,
			Position = UDim2.fromOffset(5, 0),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
		})
		createFrame("SplitCyan", root, {
			BackgroundColor3 = Color3.fromRGB(40, 240, 255),
			BackgroundTransparency = 0.9,
			Position = UDim2.fromOffset(-5, 0),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
		})
	end

	if profile.Vignette > 0 or overlay == "Vignette" or overlay == "Ceremony" then
		local strength = math.clamp(if profile.Vignette > 0 then profile.Vignette else 0.28, 0.08, 0.7)
		local edges = {
			{ Name = "VigTop", Anchor = Vector2.new(0, 0), Pos = UDim2.fromScale(0, 0), Size = UDim2.new(1, 0, 0.22, 0), Rot = 90 },
			{ Name = "VigBottom", Anchor = Vector2.new(0, 1), Pos = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0.22, 0), Rot = 270 },
			{ Name = "VigLeft", Anchor = Vector2.new(0, 0), Pos = UDim2.fromScale(0, 0), Size = UDim2.new(0.16, 0, 1, 0), Rot = 0 },
			{ Name = "VigRight", Anchor = Vector2.new(1, 0), Pos = UDim2.fromScale(1, 0), Size = UDim2.new(0.16, 0, 1, 0), Rot = 180 },
		}
		for _, edge in ipairs(edges) do
			local bar = createFrame(edge.Name, root, {
				AnchorPoint = edge.Anchor,
				Position = edge.Pos,
				Size = edge.Size,
				BackgroundColor3 = Color3.fromRGB(8, 6, 16),
				BackgroundTransparency = 1 - strength,
				ZIndex = 1,
			})
			local gradient = Instance.new("UIGradient")
			gradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			})
			gradient.Rotation = edge.Rot
			gradient.Parent = bar
		end
	end

	return root
end

local function setLetterbox(top: Frame, bottom: Frame, amount: number)
	top.Size = UDim2.new(1, 0, amount, 0)
	bottom.Size = UDim2.new(1, 0, amount, 0)
end

local function applyShake(base: CFrame, intensity: number, clock: number, token: number): CFrame
	if intensity <= 0 then
		return base
	end
	local ox = (math.noise(clock * 28, token) - 0.5) * 2 * intensity
	local oy = (math.noise(token, clock * 28) - 0.5) * 2 * intensity
	return base * CFrame.new(ox, oy, 0)
end

local function heroCameraCFrame(
	profile: CatchFeelConfig.CinematicProfile,
	petPos: Vector3,
	fromPos: Vector3,
	alpha: number,
	orbitAlpha: number
): CFrame
	local style = profile.Style
	local away = flatten(fromPos - petPos)
	local distance: number
	local height = 1.15

	if style == "Ceremony" and profile.WideStart > profile.DollyEnd then
		if alpha < 0.16 then
			local windup = smoothstep(alpha / 0.16)
			local currentDistance = math.max((fromPos - petPos).Magnitude, profile.DollyEnd)
			distance = currentDistance + (profile.WideStart - currentDistance) * windup
			height = 2.2
		else
			local dolly = smoothstep((alpha - 0.16) / 0.84)
			distance = profile.WideStart + (profile.DollyEnd - profile.WideStart) * dolly
			height = 2.2 - 0.9 * dolly
		end
	elseif style == "Glitch" then
		if alpha < 0.4 then
			distance = 6.2
		else
			distance = profile.DollyEnd
		end
	else
		local startDistance = math.max((fromPos - petPos).Magnitude, profile.DollyEnd + 1)
		local eased = if style == "SlowOrbit" then alpha * alpha * (3 - 2 * alpha) else easeOutCubic(alpha)
		if style == "Punch" then
			eased = easeOutCubic(alpha)
		end
		distance = startDistance + (profile.DollyEnd - startDistance) * eased
	end

	if style == "Ascend" then
		height = -profile.LowAngle + (1.5 + profile.LowAngle) * smoothstep(alpha)
		height += math.sin(alpha * math.pi * 2) * 0.08
	elseif style == "Sunburst" then
		height = 0.55 + 0.9 * smoothstep(alpha)
	elseif profile.LowAngle > 0 then
		height = 1.15 - profile.LowAngle * (1 - alpha) * 0.35
	end

	local side = profile.HeroSide
	local yaw = 0
	if (style == "Orbit" or style == "SlowOrbit") and profile.OrbitDegrees > 0 then
		yaw = math.rad(profile.OrbitDegrees) * orbitAlpha
	end

	local rotated = CFrame.fromAxisAngle(Vector3.yAxis, yaw):VectorToWorldSpace(away * distance)
	local right = flatten(Vector3.new(-away.Z, 0, away.X))
	local camPos = petPos + rotated + right * side + Vector3.new(0, height, 0)
	return CFrame.lookAt(camPos, petPos + Vector3.new(0, 0.2, 0))
end

function CatchCinematic.IsActive(): boolean
	return activeRestore ~= nil
end

function CatchCinematic.GetUiDelay(rarity: string): number
	local profile = CatchFeelConfig.GetCinematic(rarity)
	return if profile then profile.UiDelay else 0
end

function CatchCinematic.Stop()
	playToken += 1
	unbindSkip()
	local restore = activeRestore
	activeRestore = nil
	if restore then
		restore()
	end
end

function CatchCinematic.Play(request: PlayRequest)
	if not RunService:IsClient() then
		return
	end

	local profile = CatchFeelConfig.GetCinematic(request.Rarity)
	if not profile then
		request.OnUiReady()
		return
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		request.OnUiReady()
		return
	end

	CatchCinematic.Stop()
	playToken += 1
	local token = playToken
	uiFired = false
	local skipped = false

	local startCFrame = camera.CFrame
	local startFov = camera.FieldOfView
	local prevType = camera.CameraType
	local prevSubject = camera.CameraSubject
	local humanoid = getHumanoid()
	local previousVolume = SoundService.Volume

	local colorFx = ensureColor()
	local blurFx = ensureBlur()
	local dofFx = ensureDof()
	local bloomFx = ensureBloom(profile.Bloom)
	local gui = ensureGui()

	local letterTop = createFrame("LetterboxTop", gui, {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0,
		Size = UDim2.fromScale(1, 0),
		ZIndex = 8,
	})
	local letterBottom = createFrame("LetterboxBottom", gui, {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0,
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		ZIndex = 8,
	})
	local flash = createFrame("Flash", gui, {
		BackgroundColor3 = request.Color:Lerp(Color3.fromRGB(255, 255, 255), 0.55),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
	})
	if request.Rarity == "Divine" then
		flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	end

	mountOverlays(gui, profile, request.Color)

	local reveal = waitForReveal(token, CatchFeelConfig.RevealWait)
	local heroFrom = camera.CFrame.Position
	local style = profile.Style
	local impactShake = request.Shake
	if style == "Ascend" or style == "SlowOrbit" or style == "Ceremony" then
		impactShake *= 0.12
	elseif style == "Glitch" then
		impactShake *= 1.15
	end

	local function fireUi()
		if uiFired or token ~= playToken then
			return
		end
		uiFired = true
		request.OnUiReady()
	end

	local restored = false
	local function restore()
		if restored then
			return
		end
		restored = true
		unbindSkip()
		setLocalTransparency(reveal, 0)
		if profile.AudioDuck then
			SoundService.Volume = previousVolume
		end
		if camera.Parent then
			camera.FieldOfView = startFov
			camera.CameraType = prevType
			if humanoid then
				camera.CameraSubject = prevSubject or humanoid
			end
		end
		destroyFx()
		if gui.Parent then
			gui:Destroy()
		end
	end

	activeRestore = restore

	local function requestSkip()
		if token ~= playToken or skipped then
			return
		end
		skipped = true
	end

	bindSkip(requestSkip)
	camera.CameraType = Enum.CameraType.Scriptable

	if profile.AudioDuck then
		SoundService.Volume = previousVolume * 0.42
	end

	task.spawn(function()
		local uiElapsed = 0
		while token == playToken and not skipped and uiElapsed < profile.UiDelay do
			uiElapsed += RunService.RenderStepped:Wait()
		end
		if token == playToken then
			fireUi()
		end
	end)

	task.spawn(function()
		if token ~= playToken then
			return
		end

		-- Flash
		if profile.Flash > 0 then
			flash.BackgroundTransparency = math.clamp(1 - profile.Flash, 0, 0.85)
			TweenService:Create(
				flash,
				TweenInfo.new(if style == "Glitch" then 0.08 else 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundTransparency = 1 }
			):Play()
		end

		-- Act 1: impact (grade / letterbox fade in on the same clock)
		colorFx.TintColor = profile.Grade.Tint
		local playerLook = getPlayerLook() or startCFrame.Position + startCFrame.LookVector * 8
		local toward = startCFrame.Position:Lerp(playerLook, 0.2)
		local impactGoal = CFrame.lookAt(toward, playerLook)
		local impactFov = math.clamp(startFov - profile.FovDrop * 0.35, 40, startFov - 2)
		local impactElapsed = 0
		local glitchBeats = { 0.18, 0.34, 0.48 }

		while impactElapsed < profile.Impact and token == playToken and not skipped do
			local dt = RunService.RenderStepped:Wait()
			impactElapsed += dt
			local alpha = math.clamp(impactElapsed / profile.Impact, 0, 1)
			local gradeAlpha = smoothstep(math.clamp(impactElapsed / math.min(profile.Impact, 0.28), 0, 1))
			colorFx.Saturation = profile.Grade.Saturation * gradeAlpha
			colorFx.Contrast = profile.Grade.Contrast * gradeAlpha
			colorFx.Brightness = profile.Grade.Brightness * gradeAlpha
			blurFx.Size = profile.Blur * gradeAlpha
			dofFx.FarIntensity = math.clamp(profile.Blur / 28, 0, 0.55) * gradeAlpha
			dofFx.NearIntensity = 0.12 * gradeAlpha
			setLetterbox(letterTop, letterBottom, profile.Letterbox * gradeAlpha)
			local liveLook = getPlayerLook() or playerLook
			if style == "Glitch" then
				local beatIndex = 1
				for index, beat in ipairs(glitchBeats) do
					if alpha >= beat then
						beatIndex = index
					end
				end
				local jump = startCFrame:Lerp(impactGoal, 0.25 + beatIndex * 0.22)
				local jitter = CFrame.new((math.random() - 0.5) * 0.18, (math.random() - 0.5) * 0.14, 0)
				camera.CFrame = jump * jitter
				camera.FieldOfView = startFov - beatIndex * 3
			else
				local eased = smoothstep(alpha)
				local base = startCFrame:Lerp(CFrame.lookAt(toward, liveLook), eased)
				local falloff = 1 - alpha
				camera.CFrame = applyShake(base, impactShake * 0.7 * falloff, impactElapsed, token)
				camera.FieldOfView = startFov + (impactFov - startFov) * eased
			end
		end

		if token ~= playToken then
			return
		end
		if skipped then
			fireUi()
			restore()
			if token == playToken then
				activeRestore = nil
			end
			return
		end

		-- Act 2: hero
		heroFrom = camera.CFrame.Position
		local heroElapsed = 0
		local peakFov = math.clamp(startFov - profile.FovDrop, 40, startFov - 4)
		local lockFlashed = false
		local overexposed = false

		while heroElapsed < profile.Hero and token == playToken and not skipped do
			local dt = RunService.RenderStepped:Wait()
			heroElapsed += dt
			local alpha = math.clamp(heroElapsed / profile.Hero, 0, 1)
			if reveal == nil or reveal.Parent == nil then
				reveal = findReveal()
			end
			local petPos = getLookTarget(reveal)
			local orbitAlpha = 0
			if style == "Orbit" then
				orbitAlpha = math.clamp((alpha - 0.4) / 0.6, 0, 1)
			elseif style == "SlowOrbit" then
				orbitAlpha = smoothstep(math.clamp((alpha - 0.28) / 0.72, 0, 1))
			end

			local goal = heroCameraCFrame(profile, petPos, heroFrom, alpha, orbitAlpha)
			if style == "Glitch" then
				if alpha < 0.12 or (alpha > 0.38 and alpha < 0.46) or (alpha > 0.7 and alpha < 0.76) then
					goal = goal * CFrame.new((math.random() - 0.5) * 0.35, (math.random() - 0.5) * 0.28, 0)
					setLocalTransparency(reveal, if math.random() > 0.45 then 0.55 else 0)
					local overlayRoot = gui:FindFirstChild("OverlayRoot")
					local splitRed = if overlayRoot then overlayRoot:FindFirstChild("SplitRed") else nil
					if splitRed and splitRed:IsA("Frame") then
						splitRed.Position = UDim2.fromOffset((math.random() - 0.5) * 14, (math.random() - 0.5) * 8)
					end
				else
					setLocalTransparency(reveal, 0)
				end
				camera.CFrame = goal
			else
				local holdShake = 0
				if style ~= "Ascend" and style ~= "SlowOrbit" and style ~= "Ceremony" then
					holdShake = request.Shake * 0.12 * (1 - alpha)
				end
				camera.CFrame = applyShake(goal, holdShake, heroElapsed, token)
			end

			local fovAlpha = if style == "Ceremony" then smoothstep(alpha) else easeOutCubic(alpha)
			camera.FieldOfView = impactFov + (peakFov - impactFov) * fovAlpha
			dofFx.FocusDistance = (camera.CFrame.Position - petPos).Magnitude

			if (style == "Sunburst" or style == "Overexpose") and alpha >= 0.68 and not lockFlashed then
				lockFlashed = true
				flash.BackgroundTransparency = 0.15
				TweenService:Create(
					flash,
					TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ BackgroundTransparency = 1 }
				):Play()
			end

			if style == "Overexpose" then
				if alpha >= 0.62 and alpha <= 0.82 then
					if not overexposed then
						overexposed = true
					end
					colorFx.Brightness = profile.Grade.Brightness + 0.55
					if bloomFx then
						bloomFx.Intensity = profile.Bloom + 0.8
					end
				elseif overexposed then
					colorFx.Brightness = profile.Grade.Brightness
					if bloomFx then
						bloomFx.Intensity = profile.Bloom
					end
					overexposed = false
				end
			end
		end

		setLocalTransparency(reveal, 0)

		if token ~= playToken then
			return
		end
		if skipped then
			fireUi()
		end

		-- Act 3: restore (letterbox down, grade out, camera back)
		fireUi()

		local restoreElapsed = 0
		local restoreFrom = camera.CFrame
		local restoreFov = camera.FieldOfView
		local restoreDuration = if skipped then math.min(profile.Restore, 0.45) else profile.Restore

		if profile.SnapRestore then
			colorFx.Saturation = 0
			colorFx.Contrast = 0
			colorFx.Brightness = 0
			colorFx.TintColor = Color3.new(1, 1, 1)
			blurFx.Size = 0
			setLetterbox(letterTop, letterBottom, 0)
		end

		while restoreElapsed < restoreDuration and token == playToken do
			local dt = RunService.RenderStepped:Wait()
			restoreElapsed += dt
			local alpha = smoothstep(restoreElapsed / restoreDuration)
			if not profile.SnapRestore then
				colorFx.Saturation = profile.Grade.Saturation * (1 - alpha)
				colorFx.Contrast = profile.Grade.Contrast * (1 - alpha)
				colorFx.Brightness = profile.Grade.Brightness * (1 - alpha)
				blurFx.Size = profile.Blur * (1 - alpha)
				dofFx.FarIntensity = math.clamp(profile.Blur / 28, 0, 0.55) * (1 - alpha)
				setLetterbox(letterTop, letterBottom, profile.Letterbox * (1 - alpha))
			end
			camera.CFrame = restoreFrom:Lerp(startCFrame, alpha)
			camera.FieldOfView = restoreFov + (startFov - restoreFov) * alpha
			if bloomFx then
				bloomFx.Intensity = profile.Bloom * (1 - alpha)
			end
		end

		if token ~= playToken then
			return
		end

		restore()
		if token == playToken then
			activeRestore = nil
		end
	end)
end

return CatchCinematic
