--!strict

--[[
	Endgame visual distinction for Legendary+ pets.
	World FX (light + particles + highlight) on equipped models;
	UI stroke intensity for icons / hotbar / index.
	Event tags (Rainbow / Storm) add a separate aura that does not depend on pet name.
]]

local CollectionService = game:GetService("CollectionService")

local PetConfig = require(script.Parent:WaitForChild("PetConfig"))

export type WorldFxTier = {
	LightBrightness: number,
	LightRange: number,
	ParticleRate: number,
	ParticleSize: number,
	HighlightFill: number,
	HighlightOutline: number,
	HeldHeightBonus: number,
}

export type UiFxTier = {
	StrokeThickness: number,
	StrokeTransparency: number,
	Badge: string?,
}

local PetRarityFx = {}

PetRarityFx.MinRarity = "Legendary"
PetRarityFx.FX_FOLDER_NAME = "RarityFx"

local WORLD_TIERS: { [string]: WorldFxTier } = {
	Legendary = {
		LightBrightness = 0.55,
		LightRange = 6,
		ParticleRate = 6,
		ParticleSize = 0.22,
		HighlightFill = 0.88,
		HighlightOutline = 0.25,
		HeldHeightBonus = 0.08,
	},
	Mythic = {
		LightBrightness = 0.7,
		LightRange = 7,
		ParticleRate = 9,
		ParticleSize = 0.26,
		HighlightFill = 0.82,
		HighlightOutline = 0.15,
		HeldHeightBonus = 0.12,
	},
	Angelic = {
		LightBrightness = 0.85,
		LightRange = 8,
		ParticleRate = 11,
		ParticleSize = 0.28,
		HighlightFill = 0.78,
		HighlightOutline = 0.1,
		HeldHeightBonus = 0.14,
	},
	Glorious = {
		LightBrightness = 0.95,
		LightRange = 9,
		ParticleRate = 13,
		ParticleSize = 0.3,
		HighlightFill = 0.75,
		HighlightOutline = 0.08,
		HeldHeightBonus = 0.16,
	},
	Radiant = {
		LightBrightness = 1.05,
		LightRange = 10,
		ParticleRate = 15,
		ParticleSize = 0.32,
		HighlightFill = 0.72,
		HighlightOutline = 0.05,
		HeldHeightBonus = 0.18,
	},
	Secret = {
		LightBrightness = 0.45,
		LightRange = 8,
		ParticleRate = 10,
		ParticleSize = 0.28,
		HighlightFill = 0.7,
		HighlightOutline = 0.05,
		HeldHeightBonus = 0.18,
	},
	Eternal = {
		LightBrightness = 1.15,
		LightRange = 11,
		ParticleRate = 16,
		ParticleSize = 0.34,
		HighlightFill = 0.68,
		HighlightOutline = 0,
		HeldHeightBonus = 0.2,
	},
	Divine = {
		LightBrightness = 1.35,
		LightRange = 12,
		ParticleRate = 20,
		ParticleSize = 0.38,
		HighlightFill = 0.62,
		HighlightOutline = 0,
		HeldHeightBonus = 0.25,
	},
}

local UI_TIERS: { [string]: UiFxTier } = {
	Legendary = { StrokeThickness = 3.2, StrokeTransparency = 0, Badge = "★" },
	Mythic = { StrokeThickness = 3.4, StrokeTransparency = 0, Badge = "★" },
	Angelic = { StrokeThickness = 3.5, StrokeTransparency = 0, Badge = "✦" },
	Glorious = { StrokeThickness = 3.6, StrokeTransparency = 0, Badge = "✦" },
	Radiant = { StrokeThickness = 3.7, StrokeTransparency = 0, Badge = "✧" },
	Secret = { StrokeThickness = 3.7, StrokeTransparency = 0, Badge = "?" },
	Eternal = { StrokeThickness = 3.9, StrokeTransparency = 0, Badge = "∞" },
	Divine = { StrokeThickness = 4.2, StrokeTransparency = 0, Badge = "◆" },
}

function PetRarityFx.IsEndgame(rarity: string): boolean
	local minIndex = table.find(PetConfig.RarityOrder, PetRarityFx.MinRarity)
	local rarityIndex = table.find(PetConfig.RarityOrder, rarity)
	if typeof(minIndex) ~= "number" or typeof(rarityIndex) ~= "number" then
		return false
	end
	return rarityIndex >= minIndex
end

function PetRarityFx.GetWorldTier(rarity: string): WorldFxTier?
	if not PetRarityFx.IsEndgame(rarity) then
		return nil
	end
	return WORLD_TIERS[rarity] or WORLD_TIERS.Legendary
end

function PetRarityFx.GetUiTier(rarity: string): UiFxTier?
	if not PetRarityFx.IsEndgame(rarity) then
		return nil
	end
	return UI_TIERS[rarity] or UI_TIERS.Legendary
end

function PetRarityFx.GetHeldHeight(rarity: string, baseHeight: number): number
	local tier = PetRarityFx.GetWorldTier(rarity)
	if not tier then
		return baseHeight
	end
	return baseHeight + tier.HeldHeightBonus
end

local function clearFolder(parent: Instance)
	local existing = parent:FindFirstChild(PetRarityFx.FX_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
end

function PetRarityFx.ClearWorldFx(model: Model)
	clearFolder(model)
	local highlight = model:FindFirstChild("RarityHighlight")
	if highlight then
		highlight:Destroy()
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant.Name == "AuraLight" or descendant.Name == "AuraParticles" then
			descendant:Destroy()
		end
	end
end

function PetRarityFx.ApplyWorldFx(model: Model, rarity: string)
	PetRarityFx.ClearWorldFx(model)

	local tier = PetRarityFx.GetWorldTier(rarity)
	if not tier then
		return
	end

	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not primary then
		return
	end

	local color = PetConfig.GetRarityColor(rarity)
	local folder = Instance.new("Folder")
	folder.Name = PetRarityFx.FX_FOLDER_NAME
	folder.Parent = model

	local rarityTag = Instance.new("StringValue")
	rarityTag.Name = "AppliedRarity"
	rarityTag.Value = rarity
	rarityTag.Parent = folder

	local light = Instance.new("PointLight")
	light.Name = "AuraLight"
	light.Color = color
	light.Brightness = tier.LightBrightness
	light.Range = tier.LightRange
	light.Shadows = false
	light.Parent = primary

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "AuraParticles"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.55
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, tier.ParticleSize),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.5, 1.1)
	emitter.Speed = NumberRange.new(0.15, 0.55)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Rate = tier.ParticleRate
	emitter.Drag = 1.5
	emitter.Parent = primary

	local highlight = Instance.new("Highlight")
	highlight.Name = "RarityHighlight"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = color
	highlight.FillTransparency = tier.HighlightFill
	highlight.OutlineColor = color
	highlight.OutlineTransparency = tier.HighlightOutline
	highlight.Parent = model
end

local EVENT_FX_FOLDER = "EventFx"
PetRarityFx.EVENT_FX_TAG = "PetEventFx"

local RAINBOW_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 90)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 50)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(70, 230, 110)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 170, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(180, 90, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 90, 200)),
})

local function getModelBounds(model: Model): (CFrame, Vector3)
	local ok, cf, size = pcall(function()
		return model:GetBoundingBox()
	end)
	if ok and typeof(cf) == "CFrame" and typeof(size) == "Vector3" then
		return cf, size
	end

	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if primary then
		return primary.CFrame, primary.Size
	end

	return CFrame.new(), Vector3.new(1, 1, 1)
end

local function setRarityHighlightEnabled(model: Model, enabled: boolean)
	local rarityHighlight = model:FindFirstChild("RarityHighlight")
	if rarityHighlight and rarityHighlight:IsA("Highlight") then
		rarityHighlight.Enabled = enabled
	end
end

function PetRarityFx.RainbowColor(clock: number): Color3
	return Color3.fromHSV((clock * 0.38) % 1, 0.72, 1)
end

function PetRarityFx.StepRainbowFx(model: Model, clock: number)
	if model:GetAttribute("EventTag") ~= "Rainbow" then
		return
	end

	local fill = PetRarityFx.RainbowColor(clock)
	local outline = Color3.fromHSV((clock * 0.38 + 0.18) % 1, 0.62, 1)
	local highlight = model:FindFirstChild("EventHighlight")
	if highlight and highlight:IsA("Highlight") then
		highlight.FillColor = fill
		highlight.OutlineColor = outline
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant.Name == "EventLight" and descendant:IsA("PointLight") then
			descendant.Color = fill
		end
	end
end

function PetRarityFx.ClearEventFx(model: Model)
	CollectionService:RemoveTag(model, PetRarityFx.EVENT_FX_TAG)
	if model:GetAttribute("EventTag") ~= nil then
		model:SetAttribute("EventTag", nil)
	end

	local existing = model:FindFirstChild(EVENT_FX_FOLDER)
	if existing then
		existing:Destroy()
	end
	local highlight = model:FindFirstChild("EventHighlight")
	if highlight then
		highlight:Destroy()
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant.Name == "EventFxHost" then
			descendant:Destroy()
		end
	end
	setRarityHighlightEnabled(model, true)
end

function PetRarityFx.ApplyEventFx(model: Model, eventTag: string?)
	PetRarityFx.ClearEventFx(model)
	if typeof(eventTag) ~= "string" or eventTag == "" then
		return
	end

	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not primary then
		return
	end

	local boundsCf, boundsSize = getModelBounds(model)
	local span = math.max(boundsSize.X, boundsSize.Y, boundsSize.Z, 0.4)
	local particleSize = math.clamp(span * 0.28, 0.24, 0.85)
	local lightRange = math.clamp(span * 3.2, 6, 14)

	-- Attachment at the visual center so new pets with a tiny Root still glow around the body.
	local host = Instance.new("Attachment")
	host.Name = "EventFxHost"
	host.CFrame = primary.CFrame:ToObjectSpace(boundsCf)
	host.Parent = primary

	local folder = Instance.new("Folder")
	folder.Name = EVENT_FX_FOLDER
	folder.Parent = model

	local tagValue = Instance.new("StringValue")
	tagValue.Name = "EventTag"
	tagValue.Value = eventTag
	tagValue.Parent = folder

	model:SetAttribute("EventTag", eventTag)
	-- Only one Highlight renders per instance; event outline wins over rarity.
	setRarityHighlightEnabled(model, false)

	local function makeEmitter(name: string): ParticleEmitter
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = name
		emitter.LightEmission = 0.85
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-70, 70)
		emitter.Drag = 1.15
		emitter.LockedToPart = false
		emitter.Parent = host
		return emitter
	end

	local halo = makeEmitter("EventParticles")
	local spark = makeEmitter("EventSparkles")
	spark.Lifetime = NumberRange.new(0.35, 0.75)
	spark.Speed = NumberRange.new(0.6, 1.6)
	spark.Rate = 10
	spark.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, particleSize * 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	spark.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})

	local light = Instance.new("PointLight")
	light.Name = "EventLight"
	light.Shadows = false
	light.Range = lightRange
	light.Parent = host

	local highlight = Instance.new("Highlight")
	highlight.Name = "EventHighlight"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model

	if eventTag == "Rainbow" then
		halo.Color = RAINBOW_SEQUENCE
		halo.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, particleSize),
			NumberSequenceKeypoint.new(1, 0),
		})
		halo.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(1, 1),
		})
		halo.Lifetime = NumberRange.new(0.7, 1.35)
		halo.Speed = NumberRange.new(0.25, 0.85)
		halo.Rate = 22
		halo.LockedToPart = true
		spark.Color = RAINBOW_SEQUENCE
		spark.Rate = 16
		light.Color = Color3.fromRGB(255, 170, 230)
		light.Brightness = 1.55
		highlight.FillColor = Color3.fromRGB(255, 140, 220)
		highlight.FillTransparency = 0.72
		highlight.OutlineColor = Color3.fromRGB(255, 230, 120)
		highlight.OutlineTransparency = 0.05
	elseif eventTag == "Storm" then
		local stormColor = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(160, 140, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 120, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 240, 255)),
		})
		halo.Color = stormColor
		halo.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, particleSize * 0.75),
			NumberSequenceKeypoint.new(1, 0),
		})
		halo.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		halo.Lifetime = NumberRange.new(0.55, 1.1)
		halo.Speed = NumberRange.new(0.45, 1.5)
		halo.Rate = 18
		spark.Color = stormColor
		spark.Rate = 14
		light.Color = Color3.fromRGB(140, 130, 255)
		light.Brightness = 1.35
		highlight.FillColor = Color3.fromRGB(120, 110, 255)
		highlight.FillTransparency = 0.78
		highlight.OutlineColor = Color3.fromRGB(200, 220, 255)
		highlight.OutlineTransparency = 0.08
	else
		halo.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120))
		halo.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, particleSize * 0.7),
			NumberSequenceKeypoint.new(1, 0),
		})
		halo.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.28),
			NumberSequenceKeypoint.new(1, 1),
		})
		halo.Lifetime = NumberRange.new(0.55, 1.1)
		halo.Speed = NumberRange.new(0.2, 0.7)
		halo.Rate = 12
		spark.Color = ColorSequence.new(Color3.fromRGB(255, 240, 180))
		light.Color = Color3.fromRGB(255, 220, 120)
		light.Brightness = 0.9
		highlight.FillColor = Color3.fromRGB(255, 220, 120)
		highlight.FillTransparency = 0.85
		highlight.OutlineColor = Color3.fromRGB(255, 240, 180)
		highlight.OutlineTransparency = 0.22
	end

	CollectionService:AddTag(model, PetRarityFx.EVENT_FX_TAG)
end

return PetRarityFx
