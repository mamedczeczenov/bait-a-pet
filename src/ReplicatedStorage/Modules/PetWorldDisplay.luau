--!strict

--[[
	Cave reveal: clones the real 3D pet into the world (not a flat BillboardGui).
	Falls back to an invisible host + client ViewportFrame if the clone has no parts.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetConfig = require(script.Parent:WaitForChild("PetConfig"))
local PetFacing = require(script.Parent:WaitForChild("PetFacing"))
local PetRarityFx = require(script.Parent:WaitForChild("PetRarityFx"))

local PetWorldDisplay = {}

PetWorldDisplay.Tag = "PetWorldDisplay"

export type CreateOptions = {
	Name: string?,
	PetName: string?,
	StudSize: number?,
	Rarity: string?,
	CatchAura: number?,
	EventTag: string?,
	AlwaysOnTop: boolean?,
	Parent: Instance?,
}

local function ensurePrimaryPart(model: Model): BasePart?
	local primary = model.PrimaryPart
	if primary and primary:IsA("BasePart") then
		return primary
	end

	local best: BasePart? = nil
	local bestVolume = -1
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
			if volume > bestVolume then
				bestVolume = volume
				best = descendant
			end
		end
	end

	if best then
		model.PrimaryPart = best
	end
	return best
end

local function prepareWorldParts(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Humanoid")
			or descendant:IsA("Animator")
			or descendant:IsA("AnimationController")
		then
			descendant:Destroy()
		elseif descendant:IsA("BaseScript") or descendant:IsA("LocalScript") then
			descendant.Disabled = true
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			descendant.CastShadow = true
		end
	end
end

local function scaleModelUniform(model: Model, targetHeight: number)
	local okBox, _cf, size = pcall(function()
		return model:GetBoundingBox()
	end)
	if not okBox or typeof(size) ~= "Vector3" then
		local okExtents, extents = pcall(function()
			return model:GetExtentsSize()
		end)
		if not okExtents or typeof(extents) ~= "Vector3" then
			return
		end
		size = extents
	end

	local height = math.max(size.Y, size.X * 0.85, size.Z * 0.85, 0.05)
	local ratio = math.clamp(targetHeight / height, 0.12, 1.6)
	local currentScale = 1
	local okScale, scaleValue = pcall(function()
		return model:GetScale()
	end)
	if okScale and typeof(scaleValue) == "number" then
		currentScale = scaleValue
	end

	local scaleOk = pcall(function()
		model:ScaleTo(currentScale * ratio)
	end)
	if scaleOk then
		return
	end

	local pivot = model:GetPivot()
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local relative = pivot:ToObjectSpace(descendant.CFrame)
			descendant.Size = descendant.Size * ratio
			descendant.CFrame = pivot * CFrame.new(relative.Position * ratio) * (relative - relative.Position)
		elseif descendant:IsA("DataModelMesh") then
			descendant.Scale = descendant.Scale * ratio
			descendant.Offset = descendant.Offset * ratio
		end
	end
end

local function applyCatchLight(model: Model, rarity: string, intensity: number)
	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not primary then
		return
	end

	local color = PetConfig.GetRarityColor(rarity)
	local light = Instance.new("PointLight")
	light.Name = "RevealLight"
	light.Color = color
	light.Brightness = math.clamp(0.55 + intensity * 0.8, 0.55, 1.6)
	light.Range = math.clamp(7 + intensity * 5, 7, 14)
	light.Shadows = false
	light.Parent = primary

	if intensity <= 0 then
		return
	end

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "RevealParticles"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.65
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, math.clamp(0.16 + intensity * 0.12, 0.16, 0.36)),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.28),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.4, 0.9)
	emitter.Speed = NumberRange.new(0.15, 0.6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-50, 50)
	emitter.Rate = math.clamp(6 + intensity * 14, 6, 22)
	emitter.Drag = 1.3
	emitter.Parent = primary
end

local function createBillboardHost(name: string): Model
	local model = Instance.new("Model")
	model.Name = name

	local host = Instance.new("Part")
	host.Name = "DisplayHost"
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.Massless = true
	host.CastShadow = false
	host.Transparency = 1
	host.Size = Vector3.new(0.5, 0.5, 0.5)
	host.CFrame = CFrame.new()
	host.Parent = model
	model.PrimaryPart = host

	return model
end

function PetWorldDisplay.Create(sourceModel: Model, options: CreateOptions): Model?
	if not sourceModel or not sourceModel:IsA("Model") then
		return nil
	end

	local petName = options.PetName or sourceModel.Name
	if typeof(petName) ~= "string" or petName == "" then
		return nil
	end

	local rarity = options.Rarity or "Common"
	local studSize = options.StudSize or 2.8
	local catchAura = options.CatchAura or 0
	local displayName = options.Name or "PetWorldDisplay"

	local clone = sourceModel:Clone()
	clone.Name = displayName
	local primary = ensurePrimaryPart(clone)
	local world3d = primary ~= nil

	local model: Model
	if world3d then
		model = clone
	else
		clone:Destroy()
		model = createBillboardHost(displayName)
	end

	model:SetAttribute("PetName", petName)
	model:SetAttribute("Rarity", rarity)
	model:SetAttribute("StudSize", studSize)
	model:SetAttribute("CatchAura", catchAura)
	model:SetAttribute("AlwaysOnTop", options.AlwaysOnTop == true)
	model:SetAttribute("World3D", world3d)
	if typeof(options.EventTag) == "string" and options.EventTag ~= "" then
		model:SetAttribute("EventTag", options.EventTag)
	end

	if options.Parent then
		model.Parent = options.Parent
	end

	if world3d then
		scaleModelUniform(model, studSize)
		prepareWorldParts(model)
		PetFacing.Bake(model)
		primary = model.PrimaryPart or ensurePrimaryPart(model)
		if primary then
			model.PrimaryPart = primary
		end
		PetRarityFx.ApplyWorldFx(model, rarity)
		applyCatchLight(model, rarity, catchAura)
		PetRarityFx.ApplyEventFx(model, options.EventTag)
	end

	CollectionService:AddTag(model, PetWorldDisplay.Tag)

	return model
end

function PetWorldDisplay.SetPosition(display: Model, position: Vector3)
	local current = display:GetPivot()
	display:PivotTo(CFrame.new(position) * (current - current.Position))
end

--[[
	Upright facing: yaw toward the player, with a light pitch so the head looks at them.
]]
function PetWorldDisplay.SetLookingAt(display: Model, position: Vector3, lookAt: Vector3)
	local flat = Vector3.new(lookAt.X, position.Y, lookAt.Z)
	if (flat - position).Magnitude < 0.15 then
		PetWorldDisplay.SetPosition(display, position)
		return
	end

	local pitchY = position.Y + (lookAt.Y - position.Y) * 0.55
	local aimed = Vector3.new(lookAt.X, pitchY, lookAt.Z)
	display:PivotTo(CFrame.lookAt(position, aimed))
end

return PetWorldDisplay
