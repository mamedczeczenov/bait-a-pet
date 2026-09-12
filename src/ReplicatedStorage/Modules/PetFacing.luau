--!strict

--[[
	Pet pack models do not share one "front" axis:
	- AnimatedFace + Front decal is the real face (58/60 Map 1 pets)
	- Body MeshParts are sometimes yawed 90° (Marshmallow, Palm Bear hats)
	- Root can be 180° from the meshes (Teddy Bear)
	CFrame.lookAt follows PrimaryPart LookVector, so picking the largest mesh
	makes those pets come out sideways or back-first.

	Bake an invisible PetFaceRoot at the visual center, aimed along the face,
	and set it as PrimaryPart so PivotTo(lookAt) always faces the player.
]]

local PetFacing = {}

PetFacing.RootName = "PetFaceRoot"

local function flattenXZ(vector: Vector3): Vector3?
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude < 0.04 then
		return nil
	end
	return flat.Unit
end

local function normalFromFace(part: BasePart, normalId: Enum.NormalId): Vector3
	if normalId == Enum.NormalId.Front then
		return part.CFrame.LookVector
	elseif normalId == Enum.NormalId.Back then
		return -part.CFrame.LookVector
	elseif normalId == Enum.NormalId.Right then
		return part.CFrame.RightVector
	elseif normalId == Enum.NormalId.Left then
		return -part.CFrame.RightVector
	elseif normalId == Enum.NormalId.Top then
		return part.CFrame.UpVector
	end
	return -part.CFrame.UpVector
end

local function findNamedPart(model: Model, name: string): BasePart?
	local direct = model:FindFirstChild(name)
	if direct and direct:IsA("BasePart") then
		return direct
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == name then
			return descendant
		end
	end
	return nil
end

local function forwardFromDecals(part: BasePart): Vector3?
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("Decal") or child:IsA("Texture") then
			local face = (child :: any).Face
			if typeof(face) == "EnumItem" then
				local flat = flattenXZ(normalFromFace(part, face))
				if flat then
					return flat
				end
			end
		end
	end
	return nil
end

local function detectForward(model: Model): (Vector3, string)
	local animatedFace = findNamedPart(model, "AnimatedFace")
	if animatedFace then
		local fromDecal = forwardFromDecals(animatedFace)
		if fromDecal then
			return fromDecal, "AnimatedFaceDecal"
		end
		local fromLook = flattenXZ(animatedFace.CFrame.LookVector)
		if fromLook then
			return fromLook, "AnimatedFace"
		end
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= PetFacing.RootName then
			local fromDecal = forwardFromDecals(descendant)
			if fromDecal then
				return fromDecal, "Decal"
			end
		end
	end

	local rootPart = findNamedPart(model, "Root")
	if rootPart then
		local fromRoot = flattenXZ(rootPart.CFrame.LookVector)
		if fromRoot then
			return fromRoot, "Root"
		end
	end

	local pivotLook = flattenXZ(model:GetPivot().LookVector)
	if pivotLook then
		return pivotLook, "Pivot"
	end

	return Vector3.new(0, 0, -1), "Fallback"
end

local function boundingCenter(model: Model): Vector3
	local ok, boxCFrame = pcall(function()
		return select(1, model:GetBoundingBox())
	end)
	if ok and typeof(boxCFrame) == "CFrame" then
		return boxCFrame.Position
	end
	return model:GetPivot().Position
end

function PetFacing.Clear(model: Model)
	local existing = model:FindFirstChild(PetFacing.RootName)
	if existing then
		if model.PrimaryPart == existing then
			model.PrimaryPart = nil
		end
		existing:Destroy()
	end
end

function PetFacing.Bake(model: Model): boolean
	PetFacing.Clear(model)

	local forward, method = detectForward(model)
	local center = boundingCenter(model)
	local lookTarget = center + forward

	local root = Instance.new("Part")
	root.Name = PetFacing.RootName
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.CastShadow = false
	root.Transparency = 1
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.CFrame = CFrame.lookAt(center, Vector3.new(lookTarget.X, center.Y, lookTarget.Z))
	root.Parent = model

	model.PrimaryPart = root
	model:SetAttribute("FaceForward", method)

	return true
end

function PetFacing.GetForward(model: Model): Vector3
	local forward = detectForward(model)
	return forward
end

function PetFacing.GetCenter(model: Model): Vector3
	return boundingCenter(model)
end

--[[
	Puts the pet at the origin facing -Z so a viewport camera in front of it sees the face.
]]
function PetFacing.AlignForPortrait(model: Model)
	PetFacing.Bake(model)
	model:PivotTo(CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -1)))
end

return PetFacing
