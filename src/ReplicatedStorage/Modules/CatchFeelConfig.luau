--!strict

local PetConfig = require(script.Parent:WaitForChild("PetConfig"))

export type CelebrationTier = {
	Shake: number,
	Pulse: number,
	Duration: number,
	CatchSound: string,
	TitleScale: number,
	-- World burst around player (0 = shake-only, e.g. Rare).
	Burst: number,
	-- Legacy zoom fields; cinematic profiles own the real camera now.
	Zoom: number,
	ZoomDuration: number,
}

export type CinematicStyle =
	"Punch"
	| "Hero"
	| "Orbit"
	| "Ascend"
	| "Sunburst"
	| "Overexpose"
	| "Glitch"
	| "SlowOrbit"
	| "Ceremony"

export type CinematicOverlay = "None" | "Rays" | "Flare" | "Streaks" | "Glitch" | "Vignette" | "Ceremony"

export type CinematicGrade = {
	Tint: Color3,
	Saturation: number,
	Contrast: number,
	Brightness: number,
}

export type CinematicProfile = {
	Style: CinematicStyle,
	Impact: number,
	Hero: number,
	UiDelay: number,
	Restore: number,
	FovDrop: number,
	Letterbox: number,
	Blur: number,
	Bloom: number,
	Grade: CinematicGrade,
	Flash: number,
	OrbitDegrees: number,
	DollyEnd: number,
	HeroSide: number,
	LowAngle: number,
	WideStart: number,
	CatchAura: number,
	FlyInScale: number,
	Vignette: number,
	Overlay: CinematicOverlay,
	AudioDuck: boolean,
	PreTitle: string?,
	SnapRestore: boolean,
}

local CatchFeelConfig = {}

CatchFeelConfig.CommonDuration = 2.0
CatchFeelConfig.DefaultMinRarity = "Rare"
CatchFeelConfig.ZoomMinRarity = "Epic"
CatchFeelConfig.CinematicMinRarity = "Epic"
CatchFeelConfig.RevealTag = "CatchReveal"
CatchFeelConfig.RevealWait = 0.12

-- Settings options shown in UI (first = off).
CatchFeelConfig.MinRarityOptions = {
	"Off",
	"Rare",
	"Epic",
	"Legendary",
	"Mythic",
}

CatchFeelConfig.Sounds = {
	Throw = "rbxassetid://9113822143",
	Lock = "rbxassetid://9114221306",
	CatchCommon = "rbxassetid://4612375232",
	CatchRare = "rbxassetid://5852460266",
	CatchEpic = "rbxassetid://9120662925",
	CatchLegendary = "rbxassetid://1846529521",
	CatchMythic = "rbxassetid://9125632918",
	CatchAngelic = "rbxassetid://1846529521",
	CatchGlorious = "rbxassetid://1839942914",
	CatchRadiant = "rbxassetid://9120662925",
	CatchSecret = "rbxassetid://9114221306",
	CatchEternal = "rbxassetid://9125632918",
	-- Distinct from NewDiscovery / Lock; swap in Studio if asset unavailable.
	CatchDivine = "rbxassetid://1839942914",
	NewDiscovery = "rbxassetid://9125632439",
	Error = "rbxassetid://9114227569",
	-- Sell/Buy use FeelSound module (rbxasset:// engine sounds) — not these IDs.
}

-- Intensity grows with rarity. Rare = shake only (no burst / no cinematic).
CatchFeelConfig.Tiers = {
	Common = {
		Shake = 0,
		Pulse = 1,
		Duration = 2.0,
		CatchSound = "CatchCommon",
		TitleScale = 1,
		Burst = 0,
		Zoom = 0,
		ZoomDuration = 0,
	},
	Uncommon = {
		Shake = 0,
		Pulse = 1,
		Duration = 2.2,
		CatchSound = "CatchCommon",
		TitleScale = 1,
		Burst = 0,
		Zoom = 0,
		ZoomDuration = 0,
	},
	Rare = {
		Shake = 0.14,
		Pulse = 1.05,
		Duration = 3.2,
		CatchSound = "CatchRare",
		TitleScale = 1.05,
		Burst = 0,
		Zoom = 0,
		ZoomDuration = 0,
	},
	Epic = {
		Shake = 0.22,
		Pulse = 1.08,
		Duration = 3.5,
		CatchSound = "CatchEpic",
		TitleScale = 1.08,
		Burst = 0.35,
		Zoom = 0.22,
		ZoomDuration = 1.6,
	},
	Legendary = {
		Shake = 0.4,
		Pulse = 1.12,
		Duration = 4.0,
		CatchSound = "CatchLegendary",
		TitleScale = 1.14,
		Burst = 0.55,
		Zoom = 0.32,
		ZoomDuration = 2.4,
	},
	Mythic = {
		Shake = 0.5,
		Pulse = 1.14,
		Duration = 4.1,
		CatchSound = "CatchMythic",
		TitleScale = 1.16,
		Burst = 0.7,
		Zoom = 0.38,
		ZoomDuration = 2.8,
	},
	Angelic = {
		Shake = 0.18,
		Pulse = 1.15,
		Duration = 4.2,
		CatchSound = "CatchAngelic",
		TitleScale = 1.17,
		Burst = 0.78,
		Zoom = 0.4,
		ZoomDuration = 3.0,
	},
	Glorious = {
		Shake = 0.35,
		Pulse = 1.16,
		Duration = 4.25,
		CatchSound = "CatchGlorious",
		TitleScale = 1.18,
		Burst = 0.85,
		Zoom = 0.42,
		ZoomDuration = 3.1,
	},
	Radiant = {
		Shake = 0.32,
		Pulse = 1.17,
		Duration = 4.3,
		CatchSound = "CatchRadiant",
		TitleScale = 1.18,
		Burst = 0.9,
		Zoom = 0.44,
		ZoomDuration = 3.2,
	},
	Secret = {
		Shake = 0.55,
		Pulse = 1.18,
		Duration = 4.35,
		CatchSound = "CatchSecret",
		TitleScale = 1.2,
		Burst = 0.95,
		Zoom = 0.45,
		ZoomDuration = 3.4,
	},
	Eternal = {
		Shake = 0.08,
		Pulse = 1.19,
		Duration = 4.4,
		CatchSound = "CatchEternal",
		TitleScale = 1.2,
		Burst = 1.0,
		Zoom = 0.48,
		ZoomDuration = 3.6,
	},
	Divine = {
		Shake = 0.12,
		Pulse = 1.22,
		Duration = 4.5,
		CatchSound = "CatchDivine",
		TitleScale = 1.24,
		Burst = 1.15,
		Zoom = 0.52,
		ZoomDuration = 4.2,
	},
} :: { [string]: CelebrationTier }

local TITLE_BY_RARITY: { [string]: string } = {
	Common = "You got a pet!",
	Uncommon = "Nice catch!",
	Rare = "RARE!",
	Epic = "EPIC!",
	Legendary = "LEGENDARY!",
	Mythic = "MYTHIC!",
	Angelic = "ANGELIC!",
	Glorious = "GLORIOUS!",
	Radiant = "RADIANT!",
	Secret = "SECRET!",
	Eternal = "ETERNAL!",
	Divine = "DIVINE!",
}

CatchFeelConfig.Cinematics = {
	Epic = {
		Style = "Punch",
		Impact = 0.25,
		Hero = 0.55,
		UiDelay = 0.55,
		Restore = 0.8,
		FovDrop = 8,
		Letterbox = 0,
		Blur = 0,
		Bloom = 0,
		Grade = {
			Tint = Color3.fromRGB(210, 180, 255),
			Saturation = 0.12,
			Contrast = 0.06,
			Brightness = 0.02,
		},
		Flash = 0.16,
		OrbitDegrees = 0,
		DollyEnd = 5.5,
		HeroSide = 0,
		LowAngle = 0,
		WideStart = 0,
		CatchAura = 0.35,
		FlyInScale = 1,
		Vignette = 0,
		Overlay = "None",
		AudioDuck = false,
		SnapRestore = false,
	},
	Legendary = {
		Style = "Hero",
		Impact = 0.35,
		Hero = 1.1,
		UiDelay = 1.45,
		Restore = 0.95,
		FovDrop = 18,
		Letterbox = 0.08,
		Blur = 6,
		Bloom = 0.35,
		Grade = {
			Tint = Color3.fromRGB(255, 220, 140),
			Saturation = 0.18,
			Contrast = 0.1,
			Brightness = 0.06,
		},
		Flash = 0.45,
		OrbitDegrees = 0,
		DollyEnd = 4.4,
		HeroSide = 1.8,
		LowAngle = 0,
		WideStart = 0,
		CatchAura = 0.55,
		FlyInScale = 1,
		Vignette = 0.12,
		Overlay = "None",
		AudioDuck = false,
		SnapRestore = false,
	},
	Mythic = {
		Style = "Orbit",
		Impact = 0.35,
		Hero = 1.4,
		UiDelay = 1.75,
		Restore = 1.05,
		FovDrop = 22,
		Letterbox = 0.09,
		Blur = 10,
		Bloom = 0.45,
		Grade = {
			Tint = Color3.fromRGB(255, 150, 220),
			Saturation = 0.28,
			Contrast = 0.12,
			Brightness = 0.04,
		},
		Flash = 0.55,
		OrbitDegrees = 25,
		DollyEnd = 4,
		HeroSide = 0.4,
		LowAngle = 0,
		WideStart = 0,
		CatchAura = 0.7,
		FlyInScale = 1.05,
		Vignette = 0.18,
		Overlay = "None",
		AudioDuck = false,
		SnapRestore = false,
	},
	Angelic = {
		Style = "Ascend",
		Impact = 0.4,
		Hero = 1.5,
		UiDelay = 1.9,
		Restore = 1.1,
		FovDrop = 18,
		Letterbox = 0.09,
		Blur = 8,
		Bloom = 0.7,
		Grade = {
			Tint = Color3.fromRGB(255, 236, 210),
			Saturation = 0.1,
			Contrast = 0.16,
			Brightness = 0.1,
		},
		Flash = 0.35,
		OrbitDegrees = 0,
		DollyEnd = 4.6,
		HeroSide = 0.2,
		LowAngle = 1.8,
		WideStart = 0,
		CatchAura = 0.78,
		FlyInScale = 1.08,
		Vignette = 0.1,
		Overlay = "Rays",
		AudioDuck = false,
		SnapRestore = false,
	},
	Glorious = {
		Style = "Sunburst",
		Impact = 0.4,
		Hero = 1.55,
		UiDelay = 1.95,
		Restore = 1.15,
		FovDrop = 19,
		Letterbox = 0.09,
		Blur = 7,
		Bloom = 0.85,
		Grade = {
			Tint = Color3.fromRGB(255, 230, 120),
			Saturation = 0.22,
			Contrast = 0.14,
			Brightness = 0.12,
		},
		Flash = 0.7,
		OrbitDegrees = 0,
		DollyEnd = 4.3,
		HeroSide = 0,
		LowAngle = 0.6,
		WideStart = 0,
		CatchAura = 0.85,
		FlyInScale = 1.08,
		Vignette = 0.08,
		Overlay = "Flare",
		AudioDuck = false,
		SnapRestore = false,
	},
	Radiant = {
		Style = "Overexpose",
		Impact = 0.4,
		Hero = 1.6,
		UiDelay = 2.0,
		Restore = 1.2,
		FovDrop = 20,
		Letterbox = 0.1,
		Blur = 8,
		Bloom = 1.15,
		Grade = {
			Tint = Color3.fromRGB(190, 245, 255),
			Saturation = 0.16,
			Contrast = 0.18,
			Brightness = 0.16,
		},
		Flash = 0.85,
		OrbitDegrees = 0,
		DollyEnd = 4.1,
		HeroSide = 0.15,
		LowAngle = 0.2,
		WideStart = 0,
		CatchAura = 0.9,
		FlyInScale = 1.1,
		Vignette = 0,
		Overlay = "Streaks",
		AudioDuck = false,
		SnapRestore = false,
	},
	Secret = {
		Style = "Glitch",
		Impact = 0.45,
		Hero = 1.7,
		UiDelay = 2.15,
		Restore = 1.25,
		FovDrop = 16,
		Letterbox = 0.06,
		Blur = 4,
		Bloom = 0.15,
		Grade = {
			Tint = Color3.fromRGB(90, 70, 130),
			Saturation = -0.8,
			Contrast = 0.22,
			Brightness = -0.12,
		},
		Flash = 0.2,
		OrbitDegrees = 0,
		DollyEnd = 3.2,
		HeroSide = 0.8,
		LowAngle = 0,
		WideStart = 0,
		CatchAura = 0.95,
		FlyInScale = 1.05,
		Vignette = 0.35,
		Overlay = "Glitch",
		AudioDuck = false,
		PreTitle = "?????",
		SnapRestore = true,
	},
	Eternal = {
		Style = "SlowOrbit",
		Impact = 0.55,
		Hero = 1.85,
		UiDelay = 2.4,
		Restore = 1.2,
		FovDrop = 20,
		Letterbox = 0.1,
		Blur = 12,
		Bloom = 0.55,
		Grade = {
			Tint = Color3.fromRGB(150, 110, 220),
			Saturation = 0.2,
			Contrast = 0.14,
			Brightness = -0.04,
		},
		Flash = 0.25,
		OrbitDegrees = 40,
		DollyEnd = 4.2,
		HeroSide = 0.5,
		LowAngle = 0.3,
		WideStart = 0,
		CatchAura = 1,
		FlyInScale = 1.25,
		Vignette = 0.55,
		Overlay = "Vignette",
		AudioDuck = false,
		SnapRestore = false,
	},
	Divine = {
		Style = "Ceremony",
		Impact = 0.5,
		Hero = 2.0,
		UiDelay = 2.65,
		Restore = 1.7,
		FovDrop = 26,
		Letterbox = 0.12,
		Blur = 14,
		Bloom = 1.35,
		Grade = {
			Tint = Color3.fromRGB(255, 248, 230),
			Saturation = 0.08,
			Contrast = 0.2,
			Brightness = 0.14,
		},
		Flash = 1,
		OrbitDegrees = 0,
		DollyEnd = 3.6,
		HeroSide = 0.25,
		LowAngle = 0.4,
		WideStart = 12,
		CatchAura = 1.15,
		FlyInScale = 1.35,
		Vignette = 0.28,
		Overlay = "Ceremony",
		AudioDuck = true,
		SnapRestore = false,
	},
} :: { [string]: CinematicProfile }

function CatchFeelConfig.GetRarityIndex(rarity: string): number
	local index = table.find(PetConfig.RarityOrder, rarity)
	return if typeof(index) == "number" then index else 1
end

function CatchFeelConfig.NormalizeMinRarity(raw: any): string
	if typeof(raw) ~= "string" then
		return CatchFeelConfig.DefaultMinRarity
	end
	for _, option in ipairs(CatchFeelConfig.MinRarityOptions) do
		if option == raw then
			return raw
		end
	end
	return CatchFeelConfig.DefaultMinRarity
end

function CatchFeelConfig.GetTier(rarity: string): CelebrationTier
	local tier = CatchFeelConfig.Tiers[rarity]
	if tier then
		return tier
	end
	return CatchFeelConfig.Tiers.Common
end

function CatchFeelConfig.GetCinematic(rarity: string): CinematicProfile?
	return CatchFeelConfig.Cinematics[rarity]
end

function CatchFeelConfig.GetRevealAura(rarity: string): number
	local cinematic = CatchFeelConfig.GetCinematic(rarity)
	if cinematic then
		return cinematic.CatchAura
	end
	return 0.4
end

function CatchFeelConfig.GetFlyInScale(rarity: string): number
	local cinematic = CatchFeelConfig.GetCinematic(rarity)
	if cinematic then
		return cinematic.FlyInScale
	end
	return 1
end

function CatchFeelConfig.ShouldCelebrate(rarity: string, minRaritySetting: string): boolean
	local minSetting = CatchFeelConfig.NormalizeMinRarity(minRaritySetting)
	if minSetting == "Off" then
		return false
	end

	local rarityIndex = CatchFeelConfig.GetRarityIndex(rarity)
	local minIndex = CatchFeelConfig.GetRarityIndex(minSetting)
	-- Only Rare+ tiers celebrate; Common/Uncommon never get juice even if misconfigured.
	if rarityIndex < CatchFeelConfig.GetRarityIndex("Rare") then
		return false
	end

	return rarityIndex >= minIndex
end

function CatchFeelConfig.ShouldCinematic(rarity: string): boolean
	return CatchFeelConfig.GetCinematic(rarity) ~= nil
		and CatchFeelConfig.GetRarityIndex(rarity)
			>= CatchFeelConfig.GetRarityIndex(CatchFeelConfig.CinematicMinRarity)
end

function CatchFeelConfig.ShouldZoom(rarity: string): boolean
	return CatchFeelConfig.ShouldCinematic(rarity)
end

function CatchFeelConfig.GetTitle(rarity: string): string
	return TITLE_BY_RARITY[rarity] or "You got a pet!"
end

function CatchFeelConfig.GetResultColor(rarity: string): Color3
	return PetConfig.GetRarityColor(rarity)
end

function CatchFeelConfig.GetSoundId(soundKey: string): string?
	return CatchFeelConfig.Sounds[soundKey]
end

return CatchFeelConfig
