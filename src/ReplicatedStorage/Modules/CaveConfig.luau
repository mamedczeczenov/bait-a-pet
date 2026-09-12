--!strict

export type CaveType = "normal" | "vip"

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local PlaceConfig = require(script.Parent:WaitForChild("PlaceConfig"))

local CaveConfig = {}

CaveConfig.Normal = "normal" :: CaveType
CaveConfig.Vip = "vip" :: CaveType

CaveConfig.VipLuckMultiplier = 4 -- Economy 1D: keep 4×; SoftWeight 0.27 + Lucky 1.8× carry the F2P gate.
CaveConfig.NormalLuckMultiplier = 1
CaveConfig.Map2LuckMultiplier = 1.35
-- How far in front of the throw pad to stand (away from cave interior).
CaveConfig.NormalThrowStandGap = 6
CaveConfig.VipFrontStandGap = 8
CaveConfig.VipTeleportStandGap = 8
CaveConfig.VipCatchFrontGap = 10
CaveConfig.VipMaxDropBelowCave = 12
-- Map markers (Attribute "name" / "Name", or Instance.Name):
CaveConfig.ThrowSpawnMarker = "ThrowSpawn"
CaveConfig.VipSpawnMarker = "VipSpawn"
CaveConfig.VipCatchMarker = "VipCatch"
CaveConfig.Map2SpawnMarker = "Map2Spawn"
CaveConfig.Map3SpawnMarker = "Map3Spawn"
CaveConfig.AfkSpawnMarker = "AfkSpawn"
-- Standing on spawn / ThrowSpawn still throws into the normal cave.
CaveConfig.ThrowSpawnRadius = 36

CaveConfig.VipLockedMessage = "VIP cave requires VIP access (paid)."
CaveConfig.VipLockedToast = "VIP only — buy VIP to catch here."
CaveConfig.VipNearHint = "VIP · 4x luck"
CaveConfig.VipNoAccessHint = "VIP required"
CaveConfig.Map2NearHint = "Map 2 · 1.35x luck"

-- Exact / strict names only (case-insensitive). Do not match random "vip..." folders.
local VIP_NAMES: { [string]: boolean } = {
	vipcave = true,
	cavevip = true,
	cave_vip = true,
	vip_cave = true,
}

function CaveConfig.NormalizeType(raw: any): CaveType
	if typeof(raw) == "string" and string.lower(raw) == "vip" then
		return CaveConfig.Vip
	end
	return CaveConfig.Normal
end

function CaveConfig.IsVipName(name: string): boolean
	local lower = string.lower(name)
	lower = string.gsub(lower, "[%s%-]+", "_")
	return VIP_NAMES[lower] == true
end

function CaveConfig.IsNormalCaveName(name: string): boolean
	if CaveConfig.IsVipName(name) then
		return false
	end
	local lowerName = string.lower(name)
	return lowerName == "cave"
		or string.match(lowerName, "^cave%d+$") ~= nil
		or string.match(lowerName, "^cave[_%-%s]%w+") ~= nil
end

function CaveConfig.GetLuckMultiplier(caveType: CaveType): number
	if caveType == CaveConfig.Vip then
		return CaveConfig.VipLuckMultiplier
	end
	return CaveConfig.NormalLuckMultiplier
end

function CaveConfig.GetPlaceLuckMultiplier(caveType: CaveType): number
	if caveType == CaveConfig.Vip then
		return CaveConfig.VipLuckMultiplier
	end
	if PlaceConfig.IsMap2Place() then
		return CaveConfig.Map2LuckMultiplier
	end
	return CaveConfig.NormalLuckMultiplier
end

function CaveConfig.RequiresVip(caveType: CaveType): boolean
	return caveType == CaveConfig.Vip
end

function CaveConfig.GetBounds(target: Instance): (CFrame?, Vector3?)
	if target:IsA("Model") then
		return target:GetBoundingBox()
	end
	if target:IsA("BasePart") then
		return target.CFrame, target.Size
	end
	local nested = target:FindFirstChildWhichIsA("BasePart", true)
	if nested then
		return nested.CFrame, nested.Size
	end
	return nil, nil
end

local function isApproachLikeName(name: string): boolean
	local lower = string.lower(name)
	if string.find(lower, "bridge", 1, true)
		or string.find(lower, "walkway", 1, true)
		or string.find(lower, "plank", 1, true)
		or string.find(lower, "pier", 1, true)
		or string.find(lower, "dock", 1, true)
		or string.find(lower, "ramp", 1, true)
		or string.find(lower, "path", 1, true)
		or string.find(lower, "road", 1, true)
	then
		return true
	end
	-- Polish "most" (bridge) — avoid matching random substrings like "almost".
	if lower == "most"
		or string.find(lower, "most_", 1, true)
		or string.find(lower, "_most", 1, true)
		or string.find(lower, "most%-", 1, true)
	then
		return true
	end
	return false
end

local function isPadOrZonePart(part: BasePart): boolean
	local name = part.Name
	return name == "CatchZone"
		or name == "ThrowPoint"
		or name == "ThrowPointVip"
		or string.match(name, "^ThrowPoint%d+$") ~= nil
		or string.find(name, "Interaction", 1, true) ~= nil
end

--[[
	Bounds of the actual VIP cave rock, excluding bridge / approach pieces and invisible pads.
	Stops ThrowPointVip from spawning on the bridge when VipCave's full bbox includes it.
]]
function CaveConfig.GetVipCoreBounds(cave: Instance): (CFrame?, Vector3?)
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	local count = 0

	local function consider(part: BasePart)
		if isPadOrZonePart(part) then
			return
		end
		if part.Transparency >= 1 and part.CanCollide == false then
			return
		end
		local current: Instance? = part
		while current and current ~= cave do
			if isApproachLikeName(current.Name) then
				return
			end
			current = current.Parent
		end
		if isApproachLikeName(part.Name) then
			return
		end

		local cf = part.CFrame
		local half = part.Size * 0.5
		local corners = {
			cf * Vector3.new(half.X, half.Y, half.Z),
			cf * Vector3.new(half.X, half.Y, -half.Z),
			cf * Vector3.new(half.X, -half.Y, half.Z),
			cf * Vector3.new(half.X, -half.Y, -half.Z),
			cf * Vector3.new(-half.X, half.Y, half.Z),
			cf * Vector3.new(-half.X, half.Y, -half.Z),
			cf * Vector3.new(-half.X, -half.Y, half.Z),
			cf * Vector3.new(-half.X, -half.Y, -half.Z),
		}
		for _, corner in ipairs(corners) do
			minX = math.min(minX, corner.X)
			minY = math.min(minY, corner.Y)
			minZ = math.min(minZ, corner.Z)
			maxX = math.max(maxX, corner.X)
			maxY = math.max(maxY, corner.Y)
			maxZ = math.max(maxZ, corner.Z)
		end
		count += 1
	end

	if cave:IsA("BasePart") then
		consider(cave)
	end
	for _, descendant in ipairs(cave:GetDescendants()) do
		if descendant:IsA("BasePart") then
			consider(descendant)
		end
	end

	if count == 0 then
		return CaveConfig.GetBounds(cave)
	end

	local center = Vector3.new((minX + maxX) * 0.5, (minY + maxY) * 0.5, (minZ + maxZ) * 0.5)
	local size = Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
	return CFrame.new(center), size
end

function CaveConfig.GetMarkerAttribute(instance: Instance): string?
	local lowerKey = instance:GetAttribute("name")
	if typeof(lowerKey) == "string" and lowerKey ~= "" then
		return lowerKey
	end
	local upperKey = instance:GetAttribute("Name")
	if typeof(upperKey) == "string" and upperKey ~= "" then
		return upperKey
	end
	return nil
end

function CaveConfig.HasMarker(instance: Instance, marker: string): boolean
	local want = string.lower(marker)
	if string.lower(instance.Name) == want then
		return true
	end
	local attr = CaveConfig.GetMarkerAttribute(instance)
	return typeof(attr) == "string" and string.lower(attr) == want
end

--[[
	Finds a BasePart marked VipSpawn / VipCatch.
	Supports: Attribute name/Name, Instance.Name, or Texture/Decal with that attribute on a BasePart.
]]
function CaveConfig.FindPartByMarker(marker: string): BasePart?
	local want = string.lower(marker)
	local nameFallback: BasePart? = nil

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		local attr = CaveConfig.GetMarkerAttribute(descendant)
		local attrMatch = typeof(attr) == "string" and string.lower(attr) == want
		local nameMatch = string.lower(descendant.Name) == want

		if attrMatch then
			if descendant:IsA("BasePart") then
				return descendant
			end
			if (descendant:IsA("Texture") or descendant:IsA("Decal")) and descendant.Parent and descendant.Parent:IsA("BasePart") then
				return descendant.Parent
			end
		elseif nameMatch and descendant:IsA("BasePart") and not nameFallback then
			nameFallback = descendant
		end
	end

	return nameFallback
end

function CaveConfig.FindVipSpawnPart(): BasePart?
	return CaveConfig.FindPartByMarker(CaveConfig.VipSpawnMarker)
end

function CaveConfig.FindVipCatchPart(): BasePart?
	return CaveConfig.FindPartByMarker(CaveConfig.VipCatchMarker)
end

function CaveConfig.FindThrowSpawnPart(): BasePart?
	return CaveConfig.FindPartByMarker(CaveConfig.ThrowSpawnMarker)
end

function CaveConfig.FindMap2SpawnPart(): BasePart?
	return CaveConfig.ResolveMap2SpawnPart()
end

-- Map 2 area names (Cave2 is a bait cave on map 1 — do not use it here).
local MAP2_AREA_NAMES = {
	"Map2",
	"Map 2",
	"Map_2",
	"Mapa2",
	"Mapa 2",
	"World2",
	"World 2",
	"Island2",
	"Biome2",
	"SecondMap",
}

local function normalizeMapKey(value: string): string
	local lower = string.lower(value)
	lower = string.gsub(lower, "[%s_%-]+", "")
	lower = string.gsub(lower, "ó", "o")
	return lower
end

local function isMap2AreaName(name: string): boolean
	local key = normalizeMapKey(name)
	if key == "map2" or key == "mapa2" or key == "world2" or key == "island2" or key == "biome2" then
		return true
	end
	if key == "secondmap" or key == "map02" then
		return true
	end
	for _, candidate in ipairs(MAP2_AREA_NAMES) do
		if normalizeMapKey(candidate) == key then
			return true
		end
	end
	return false
end

local function isLegacyAutoMap2Artifact(instance: Instance): boolean
	if instance.Name == "Map2Floor" then
		return true
	end

	if instance.Name ~= "Map2Spawn" or not instance:IsA("BasePart") then
		return false
	end

	local parent = instance.Parent
	if not parent then
		return false
	end

	-- Old fallback: Workspace/Map2 with only Map2Floor + Map2Spawn.
	if parent.Name == "Map2" and (parent:IsA("Folder") or parent:IsA("Model")) then
		local hasFloor = parent:FindFirstChild("Map2Floor") ~= nil
		local partCount = 0
		for _, child in ipairs(parent:GetChildren()) do
			if child:IsA("BasePart") then
				partCount += 1
			end
		end
		if hasFloor or partCount <= 1 then
			return true
		end
	end

	return false
end

local function countBaseParts(root: Instance): number
	local count = 0
	if root:IsA("BasePart") then
		count += 1
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") and not isLegacyAutoMap2Artifact(descendant) then
			count += 1
		end
	end
	return count
end

local function isInsideMap2Area(part: BasePart, map2Area: Instance?): boolean
	if not map2Area then
		return false
	end
	return part:IsDescendantOf(map2Area) or part == map2Area
end

local function collectMap2SpawnCandidates(): { BasePart }
	local marker = string.lower(CaveConfig.Map2SpawnMarker)
	local byAttr: { BasePart } = {}
	local byName: { BasePart } = {}

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if isLegacyAutoMap2Artifact(descendant) then
			continue
		end

		local attr = CaveConfig.GetMarkerAttribute(descendant)
		local attrMatch = typeof(attr) == "string" and string.lower(attr) == marker
		local nameMatch = string.lower(descendant.Name) == marker

		if attrMatch then
			if descendant:IsA("BasePart") then
				table.insert(byAttr, descendant)
			elseif (descendant:IsA("Texture") or descendant:IsA("Decal")) and descendant.Parent and descendant.Parent:IsA("BasePart") then
				table.insert(byAttr, descendant.Parent)
			end
		elseif nameMatch and descendant:IsA("BasePart") then
			table.insert(byName, descendant)
		end
	end

	if #byAttr > 0 then
		return byAttr
	end
	return byName
end

local function getInstanceReferenceCFrame(container: Instance): CFrame?
	if container:IsA("Model") then
		local ok, pivot = pcall(function()
			return container:GetPivot()
		end)
		if ok then
			return pivot
		end
	end

	if container:IsA("BasePart") then
		return container.CFrame
	end

	local nestedPart = container:FindFirstChildWhichIsA("BasePart", true)
	if nestedPart then
		return nestedPart.CFrame
	end

	return nil
end

function CaveConfig.FindMap2Area(): Instance?
	local tagged: { Instance } = {}
	for _, instance in ipairs(CollectionService:GetTagged("Map2")) do
		if instance:IsA("Model") or instance:IsA("Folder") or instance:IsA("BasePart") then
			if not isLegacyAutoMap2Artifact(instance) then
				table.insert(tagged, instance)
			end
		end
	end
	if #tagged == 1 then
		return tagged[1]
	end
	if #tagged > 1 then
		table.sort(tagged, function(a, b)
			return countBaseParts(a) > countBaseParts(b)
		end)
		return tagged[1]
	end

	local named: { Instance } = {}
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if isMap2AreaName(descendant.Name)
			and (descendant:IsA("Model") or descendant:IsA("Folder") or descendant:IsA("BasePart"))
			and not isLegacyAutoMap2Artifact(descendant)
		then
			table.insert(named, descendant)
		end
	end

	if #named == 0 then
		return nil
	end

	table.sort(named, function(a, b)
		return countBaseParts(a) > countBaseParts(b)
	end)
	return named[1]
end

function CaveConfig.ResolveMap2SpawnPart(): BasePart?
	local map2Area = CaveConfig.FindMap2Area()
	local candidates = collectMap2SpawnCandidates()
	if #candidates == 0 then
		return nil
	end
	if #candidates == 1 then
		return candidates[1]
	end

	local throwSpawn = CaveConfig.FindThrowSpawnPart()
	local throwPos = if throwSpawn then throwSpawn.Position else nil

	table.sort(candidates, function(a, b)
		local aInside = if isInsideMap2Area(a, map2Area) then 1 else 0
		local bInside = if isInsideMap2Area(b, map2Area) then 1 else 0
		if aInside ~= bInside then
			return aInside > bInside
		end

		if throwPos then
			local aDist = (a.Position - throwPos).Magnitude
			local bDist = (b.Position - throwPos).Magnitude
			if math.abs(aDist - bDist) > 4 then
				return aDist > bDist
			end
		end

		return countBaseParts(a:FindFirstAncestorWhichIsA("Model") or a.Parent or a)
			> countBaseParts(b:FindFirstAncestorWhichIsA("Model") or b.Parent or b)
	end)

	return candidates[1]
end

function CaveConfig.CleanupLegacyAutoMap2(): number
	local removed = 0

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if isLegacyAutoMap2Artifact(descendant) then
			descendant:Destroy()
			removed += 1
		end
	end

	local legacyFolder = Workspace:FindFirstChild("Map2")
	if legacyFolder and legacyFolder:IsA("Folder") and #legacyFolder:GetChildren() == 0 then
		legacyFolder:Destroy()
		removed += 1
	end

	return removed
end

--[[
	Stand on top of a marked ground part, optionally facing a look target.
]]
function CaveConfig.GetMarkerStandCFrame(spawnPart: BasePart, rootHeight: number, lookAt: Vector3?): CFrame
	local standPos = (spawnPart.CFrame * CFrame.new(0, spawnPart.Size.Y * 0.5 + rootHeight, 0)).Position
	if lookAt then
		local flatLook = Vector3.new(lookAt.X, standPos.Y, lookAt.Z)
		if (flatLook - standPos).Magnitude > 0.5 then
			return CFrame.lookAt(standPos, flatLook)
		end
	end
	return CFrame.new(standPos) * (spawnPart.CFrame - spawnPart.CFrame.Position)
end

function CaveConfig.GetThrowSpawnCFrame(rootHeight: number): CFrame?
	local spawnPart = CaveConfig.FindThrowSpawnPart()
	if not spawnPart then
		return nil
	end

	local lookAt: Vector3? = nil
	local throwPad = CaveConfig.FindNormalThrowPad()
	if throwPad then
		lookAt = throwPad.Position
	else
		local normalCave = CaveConfig.FindNormalCave()
		if normalCave then
			local bounds = select(1, CaveConfig.GetBounds(normalCave))
			if bounds then
				lookAt = bounds.Position
			end
		end
	end

	return CaveConfig.GetMarkerStandCFrame(spawnPart, rootHeight, lookAt)
end

function CaveConfig.GetVipSpawnCFrame(rootHeight: number): CFrame?
	local spawnPart = CaveConfig.FindVipSpawnPart()
	if not spawnPart then
		return nil
	end

	local lookAt: Vector3? = nil
	local catchPart = CaveConfig.FindVipCatchPart()
	if catchPart then
		lookAt = catchPart.Position
	else
		local vipCave = CaveConfig.FindVipCave()
		if vipCave then
			local bounds = select(1, CaveConfig.GetBounds(vipCave))
			if bounds then
				lookAt = bounds.Position
			end
		end
	end

	return CaveConfig.GetMarkerStandCFrame(spawnPart, rootHeight, lookAt)
end

function CaveConfig.FindMap3SpawnPart(): BasePart?
	return CaveConfig.FindPartByMarker(CaveConfig.Map3SpawnMarker)
end

function CaveConfig.GetMap3SpawnCFrame(rootHeight: number): CFrame?
	local spawnPart = CaveConfig.FindMap3SpawnPart()
	if spawnPart then
		return CaveConfig.GetMarkerStandCFrame(spawnPart, rootHeight, nil)
	end

	local spawnLocation = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLocation then
		return spawnLocation.CFrame + Vector3.new(0, rootHeight, 0)
	end

	return nil
end

function CaveConfig.GetMap2SpawnCFrame(rootHeight: number): CFrame?
	local spawnPart = CaveConfig.ResolveMap2SpawnPart()
	if spawnPart then
		return CaveConfig.GetMarkerStandCFrame(spawnPart, rootHeight, nil)
	end

	local map2 = CaveConfig.FindMap2Area()
	if map2 then
		local boundsCFrame = select(1, CaveConfig.GetBounds(map2))
		if boundsCFrame then
			return CFrame.new(boundsCFrame.Position + Vector3.new(0, rootHeight, 0))
		end

		local reference = getInstanceReferenceCFrame(map2)
		if reference then
			return CFrame.new(reference.Position + Vector3.new(0, rootHeight, 0))
		end
	end

	return nil
end

function CaveConfig.FindAfkSpawnPart(): BasePart?
	return CaveConfig.FindPartByMarker(CaveConfig.AfkSpawnMarker)
end

function CaveConfig.GetAfkSpawnCFrame(rootHeight: number): CFrame?
	local spawnPart = CaveConfig.FindAfkSpawnPart()
	if spawnPart then
		return CaveConfig.GetMarkerStandCFrame(spawnPart, rootHeight, nil)
	end

	local spawnLocation = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLocation then
		return spawnLocation.CFrame + Vector3.new(0, rootHeight, 0)
	end

	return nil
end

--[[
	True when HumanoidRootPart is above the platform footprint (standing on it).
]]
function CaveConfig.IsStandingOnPart(rootPosition: Vector3, part: BasePart): boolean
	local localPos = part.CFrame:PointToObjectSpace(rootPosition)
	local half = part.Size * 0.5
	local xzPad = 1.5
	if math.abs(localPos.X) > half.X + xzPad then
		return false
	end
	if math.abs(localPos.Z) > half.Z + xzPad then
		return false
	end
	-- HRP sits above feet; allow a tall window so jumps/slopes still count.
	local aboveTop = localPos.Y - half.Y
	return aboveTop >= -2 and aboveTop <= 12
end

function CaveConfig.GetCatchRadius(zone: BasePart): number
	local attr = zone:GetAttribute("CatchRadius")
	if typeof(attr) == "number" and attr > 0 then
		return attr
	end
	if CaveConfig.ResolveTypeFromZone(zone) == CaveConfig.Vip then
		-- VIP uses stand-on check; radius is only a loose broad-phase fallback.
		return math.max(zone.Size.X, zone.Size.Z) * 0.5 + 4
	end
	return 50
end

function CaveConfig.IsInsideCatchZone(rootPosition: Vector3, zone: BasePart): boolean
	if CaveConfig.ResolveTypeFromZone(zone) == CaveConfig.Vip then
		-- VIP: must stand on the VipCatch platform (zone itself or its host).
		local platform = zone
		if zone.Name == "CatchZone" and zone.Parent and zone.Parent:IsA("BasePart") then
			platform = zone.Parent
		end
		return CaveConfig.IsStandingOnPart(rootPosition, platform)
	end

	return (zone.Position - rootPosition).Magnitude <= CaveConfig.GetCatchRadius(zone)
end

--[[
	If player is in both VIP and normal catch areas, prefer VIP.
]]
local function pickZoneOfType(zones: { BasePart }, caveType: CaveType, origin: Vector3): BasePart?
	local best: BasePart? = nil
	local bestDist = math.huge
	for _, zone in ipairs(zones) do
		if zone.Parent and CaveConfig.ResolveTypeFromZone(zone) == caveType then
			local dist = (zone.Position - origin).Magnitude
			if dist < bestDist then
				bestDist = dist
				best = zone
			end
		end
	end
	return best
end

function CaveConfig.IsNearPart(rootPosition: Vector3, part: BasePart, radius: number): boolean
	if CaveConfig.IsStandingOnPart(rootPosition, part) then
		return true
	end
	return (part.Position - rootPosition).Magnitude <= radius
end

function CaveConfig.IsAtNormalThrowSpawn(rootPosition: Vector3): boolean
	local radius = CaveConfig.ThrowSpawnRadius
	local throwSpawn = CaveConfig.FindThrowSpawnPart()
	if throwSpawn and CaveConfig.IsNearPart(rootPosition, throwSpawn, radius) then
		return true
	end

	local spawnLocation = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLocation and spawnLocation:IsA("BasePart") and CaveConfig.IsNearPart(rootPosition, spawnLocation, radius) then
		return true
	end

	return false
end

function CaveConfig.IsAtVipThrowSpawn(rootPosition: Vector3): boolean
	local vipSpawn = CaveConfig.FindVipSpawnPart()
	if not vipSpawn then
		return false
	end
	return CaveConfig.IsNearPart(rootPosition, vipSpawn, CaveConfig.ThrowSpawnRadius)
end

--[[
	Throw target: catch pad when close, otherwise spawn → cave (normal or VIP spawn).
]]
function CaveConfig.ChooseThrowZone(rootPosition: Vector3, zones: { BasePart }): (BasePart?, number)
	if CaveConfig.IsAtVipThrowSpawn(rootPosition) then
		local vipZone = pickZoneOfType(zones, CaveConfig.Vip, rootPosition)
		if vipZone then
			return vipZone, (vipZone.Position - rootPosition).Magnitude
		end
	end

	if CaveConfig.IsAtNormalThrowSpawn(rootPosition) then
		local normalZone = pickZoneOfType(zones, CaveConfig.Normal, rootPosition)
		if normalZone then
			return normalZone, (normalZone.Position - rootPosition).Magnitude
		end
	end

	return CaveConfig.ChooseCatchZone(rootPosition, zones)
end

function CaveConfig.ChooseCatchZone(rootPosition: Vector3, zones: { BasePart }): (BasePart?, number)
	local bestVip: BasePart? = nil
	local bestVipDist = math.huge
	local bestNormal: BasePart? = nil
	local bestNormalDist = math.huge

	for _, zone in ipairs(zones) do
		if zone.Parent and CaveConfig.IsInsideCatchZone(rootPosition, zone) then
			local dist = (zone.Position - rootPosition).Magnitude
			if CaveConfig.ResolveTypeFromZone(zone) == CaveConfig.Vip then
				if dist < bestVipDist then
					bestVipDist = dist
					bestVip = zone
				end
			elseif dist < bestNormalDist then
				bestNormalDist = dist
				bestNormal = zone
			end
		end
	end

	if bestVip then
		return bestVip, bestVipDist
	end
	return bestNormal, bestNormalDist
end

local function flatten(vector: Vector3): Vector3
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude < 0.05 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

local function aabbExitDistance(half: Vector3, dir: Vector3): number
	local tx = if math.abs(dir.X) > 1e-4 then half.X / math.abs(dir.X) else math.huge
	local tz = if math.abs(dir.Z) > 1e-4 then half.Z / math.abs(dir.Z) else math.huge
	return math.min(tx, tz)
end

local function getApproachOutward(cave: Instance, coreCenter: Vector3): Vector3?
	local sum = Vector3.zero
	local count = 0

	local function consider(part: BasePart)
		local isApproach = isApproachLikeName(part.Name)
		local current: Instance? = part.Parent
		while current and current ~= cave do
			if isApproachLikeName(current.Name) then
				isApproach = true
				break
			end
			current = current.Parent
		end
		if isApproach then
			sum += part.Position
			count += 1
		end
	end

	for _, descendant in ipairs(cave:GetDescendants()) do
		if descendant:IsA("BasePart") then
			consider(descendant)
		end
	end

	if count == 0 then
		return nil
	end

	return flatten((sum / count) - coreCenter)
end

function CaveConfig.IsPointInsideBounds(worldPos: Vector3, boundsCFrame: CFrame, size: Vector3, pad: number?): boolean
	local padding = pad or 2
	local localPos = boundsCFrame:PointToObjectSpace(worldPos)
	local half = size * 0.5
	return math.abs(localPos.X) <= half.X + padding
		and math.abs(localPos.Y) <= half.Y + padding
		and math.abs(localPos.Z) <= half.Z + padding
end

local FRONT_MARKER_NAMES = {
	"TeleportFront",
	"VipPad",
	"VipSpawn",
	"VipEntrance",
	"FrontPad",
	"CatchFront",
}

function CaveConfig.FindFrontMarker(cave: Instance): BasePart?
	for _, name in ipairs(FRONT_MARKER_NAMES) do
		local found = cave:FindFirstChild(name, true)
		if found and found:IsA("BasePart") then
			return found
		end
	end
	return nil
end

function CaveConfig.FindVipThrowPad(cave: Instance): BasePart?
	local vipPad = cave:FindFirstChild("ThrowPointVip", true)
	if vipPad and vipPad:IsA("BasePart") then
		return vipPad
	end
	local throw = cave:FindFirstChild("ThrowPoint", true)
	if throw and throw:IsA("BasePart") then
		return throw
	end
	return nil
end

local function isWaterHit(result: RaycastResult): boolean
	if result.Material == Enum.Material.Water then
		return true
	end
	if result.Instance:IsA("BasePart") and result.Instance.Name:lower():find("water", 1, true) then
		return true
	end
	return false
end

local function snapToGround(
	xz: Vector3,
	referenceY: number,
	rootHeight: number,
	exclude: { Instance }
): (Vector3?, RaycastResult?)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = false
	raycastParams.FilterDescendantsInstances = exclude

	local startY = math.max(referenceY + 40, xz.Y + 40)
	local origin = Vector3.new(xz.X, startY, xz.Z)
	local result = Workspace:Raycast(origin, Vector3.new(0, -(startY - (referenceY - 80)), 0), raycastParams)
	if not result then
		return nil, nil
	end
	if isWaterHit(result) then
		return nil, result
	end
	-- Sea floor / deep drop relative to the cave island.
	if result.Position.Y < referenceY - CaveConfig.VipMaxDropBelowCave then
		return nil, result
	end

	return Vector3.new(result.Position.X, result.Position.Y + rootHeight, result.Position.Z), result
end

--[[
	Stand in front of a throw pad, facing the cave.
	outDir = from cave interior toward the pad / open area (never into the cave).
]]
function CaveConfig.GetPadFrontStandCFrame(
	pad: BasePart,
	caveCenter: Vector3,
	standGap: number,
	rootHeight: number,
	excludeExtra: { Instance }?,
	boundsCFrame: CFrame?,
	boundsSize: Vector3?
): CFrame?
	local exclude: { Instance } = { pad }
	if excludeExtra then
		for _, item in ipairs(excludeExtra) do
			table.insert(exclude, item)
		end
	end

	local outDir = flatten(pad.Position - caveCenter)
	if outDir.Magnitude < 0.05 then
		outDir = flatten(pad.CFrame.LookVector)
	end

	-- Prefer just outside the pad; keep pushing out until clear of cave volume.
	local gaps = {
		standGap,
		standGap + 4,
		standGap + 8,
		standGap + 12,
		standGap + 18,
		math.max(4, standGap - 2),
	}
	local bestOutside: CFrame? = nil
	local bestOutsideScore = -math.huge
	local bestAny: CFrame? = nil
	local bestAnyScore = -math.huge

	for _, gap in ipairs(gaps) do
		local candidate = pad.Position + outDir * gap
		local standPos = snapToGround(candidate, math.max(caveCenter.Y, pad.Position.Y), rootHeight, exclude)
		if not standPos then
			continue
		end

		local inside = boundsCFrame
			and boundsSize
			and CaveConfig.IsPointInsideBounds(standPos, boundsCFrame, boundsSize, 2)
		local score = 100 - math.abs(gap - standGap)

		if inside then
			score -= 500
		else
			score += 200
		end

		if score > bestAnyScore then
			bestAnyScore = score
			bestAny = CFrame.lookAt(standPos, Vector3.new(pad.Position.X, standPos.Y, pad.Position.Z))
		end
		if not inside and score > bestOutsideScore then
			bestOutsideScore = score
			bestOutside = CFrame.lookAt(standPos, Vector3.new(pad.Position.X, standPos.Y, pad.Position.Z))
		end
	end

	if bestOutside then
		return bestOutside
	end
	if bestAny then
		return bestAny
	end

	local fallback = pad.Position + outDir * math.max(standGap, 4) + Vector3.new(0, rootHeight, 0)
	return CFrame.lookAt(fallback, Vector3.new(pad.Position.X, fallback.Y, pad.Position.Z))
end

function CaveConfig.GetVipTeleportCFrame(_cave: Instance?, standGap: number?, rootHeight: number): CFrame?
	local height = rootHeight
	local spawnCFrame = CaveConfig.GetVipSpawnCFrame(height)
	if spawnCFrame then
		return spawnCFrame
	end
	-- Legacy fallback if VipSpawn marker is missing.
	warn("[CaveConfig] VipSpawn marker not found — VIP teleport unavailable.")
	return nil
end

function CaveConfig.GetOutsideStandCFrame(cave: Instance, standGap: number, rootHeight: number): CFrame?
	return CaveConfig.GetVipTeleportCFrame(cave, standGap, rootHeight)
end

function CaveConfig.GetVipCatchPadCFrame(_cave: Instance): CFrame?
	local catchPart = CaveConfig.FindVipCatchPart()
	if catchPart then
		return catchPart.CFrame
	end
	return nil
end

function CaveConfig.FindNormalCave(): Instance?
	for _, child in ipairs(Workspace:GetChildren()) do
		if CaveConfig.IsNormalCaveName(child.Name)
			and (child:IsA("Model") or child:IsA("Folder") or child:IsA("BasePart"))
		then
			return child
		end
	end
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if CaveConfig.IsNormalCaveName(descendant.Name)
			and (descendant:IsA("Model") or descendant:IsA("Folder") or descendant:IsA("BasePart"))
		then
			return descendant
		end
	end
	return nil
end

function CaveConfig.FindNormalThrowPad(): BasePart?
	local normalCave = CaveConfig.FindNormalCave()
	if normalCave then
		local pad = normalCave:FindFirstChild("ThrowPoint", true)
		if pad and pad:IsA("BasePart") then
			return pad
		end
	end

	-- Workspace-level ThrowPoint not under VipCave.
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "ThrowPoint" then
			local underVip = false
			local current: Instance? = descendant
			while current and current ~= Workspace do
				if CaveConfig.IsVipName(current.Name) then
					underVip = true
					break
				end
				current = current.Parent
			end
			if not underVip then
				return descendant
			end
		end
	end
	return nil
end

function CaveConfig.FindVipCave(): Instance?
	for _, child in ipairs(Workspace:GetChildren()) do
		if CaveConfig.IsVipName(child.Name)
			and (child:IsA("Model") or child:IsA("Folder") or child:IsA("BasePart"))
		then
			return child
		end
	end
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if CaveConfig.IsVipName(descendant.Name)
			and (descendant:IsA("Model") or descendant:IsA("Folder") or descendant:IsA("BasePart"))
		then
			return descendant
		end
	end
	return nil
end

function CaveConfig.ResolveTypeFromZone(zone: Instance?): CaveType
	if not zone then
		return CaveConfig.Normal
	end
	if CaveConfig.NormalizeType(zone:GetAttribute("CaveType")) == CaveConfig.Vip then
		return CaveConfig.Vip
	end
	if zone:GetAttribute("RequiresVip") == true then
		return CaveConfig.Vip
	end
	if CaveConfig.HasMarker(zone, CaveConfig.VipCatchMarker) then
		return CaveConfig.Vip
	end
	local current: Instance? = zone
	while current and current ~= Workspace do
		if CaveConfig.IsVipName(current.Name) then
			return CaveConfig.Vip
		end
		if CaveConfig.HasMarker(current, CaveConfig.VipCatchMarker) then
			return CaveConfig.Vip
		end
		current = current.Parent
	end
	return CaveConfig.Normal
end

return CaveConfig
