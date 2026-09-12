--!strict

export type PetDefinition = {
	Name: string,
	Rarity: string,
	OneIn: number,
	Weight: number,
	Color: Color3,
	SellPrice: number,
	Icon: string,
	Description: string,
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormat = require(script.Parent:WaitForChild("NumberFormat"))

local PetConfig = {}

PetConfig.RevealDuration = 4
PetConfig.Pets = {} :: { PetDefinition }

PetConfig.RarityOrder = {
	"Common",
	"Uncommon",
	"Rare",
	"Epic",
	"Legendary",
	"Mythic",
	"Angelic",
	"Glorious",
	"Radiant",
	"Secret",
	"Eternal",
	"Divine",
}

-- Higher bias = stronger boost from luck; below LuckNeutralBias gets suppressed as luck rises.
PetConfig.RarityBias = {
	Common = 0.02,
	Uncommon = 0.05,
	Rare = 0.12,
	Epic = 0.22,
	Legendary = 0.35,
	Mythic = 0.48,
	Angelic = 0.6,
	Glorious = 0.72,
	Radiant = 0.82,
	Secret = 0.9,
	Eternal = 0.95,
	Divine = 1.0,
}

-- Luck roll tuning (see PetService.getAdjustedWeight):
-- SoftWeightPower compresses OneIn spans — LOWER = flatter (easier top tiers).
-- Economy 1D: 0.27 vs VIP 4× so Glorious is not a 15-min Map 1 clear.
-- NeutralBias ≈ Epic: tiers below shrink with luck, tiers above grow.
-- ExponentScale: slightly down so luck/VIP does not explode Epic+.
PetConfig.LuckSoftWeightPower = 0.27
PetConfig.LuckNeutralBias = 0.22
PetConfig.LuckExponentScale = 0.40

-- Candy rarity chips (Eggs Shop energy — saturated, readable on bright UI)
PetConfig.RarityColors = {
	Common = Color3.fromRGB(170, 175, 185),
	Uncommon = Color3.fromRGB(60, 230, 90),
	Rare = Color3.fromRGB(60, 150, 255),
	Epic = Color3.fromRGB(190, 70, 255),
	Legendary = Color3.fromRGB(255, 175, 30),
	Mythic = Color3.fromRGB(255, 55, 130),
	Angelic = Color3.fromRGB(255, 240, 140),
	Glorious = Color3.fromRGB(255, 210, 50),
	Radiant = Color3.fromRGB(60, 255, 230),
	Secret = Color3.fromRGB(55, 45, 70),
	Eternal = Color3.fromRGB(200, 110, 255),
	Divine = Color3.fromRGB(255, 245, 200),
}

-- How many pets per rarity when auto-assigning Map 1 roster (60).
PetConfig.RarityCounts = {
	Common = 15,
	Uncommon = 10,
	Rare = 8,
	Epic = 6,
	Legendary = 5,
	Mythic = 4,
	Angelic = 3,
	Glorious = 2,
	Radiant = 2,
	Secret = 2,
	Eternal = 2,
	Divine = 1,
}

-- Curated Map 1 catchables (order = AssignRarities: Common → Divine).
PetConfig.Map1Roster = {
	"Doggy",
	"Kitty",
	"Bunny",
	"Fox",
	"Chicken",
	"Piggy",
	"Ducky",
	"Penguin",
	"Marshmallow",
	"Teddy Bear",
	"Balloon Kitty",
	"Classic Fox",
	"Classic Mouse",
	"Blue Ducky",
	"Bear Plushie",
	"Dowodle",
	"Beach Bat",
	"Coral Kitty",
	"Ocean Kitty",
	"Palm Bear",
	"Sandy Wolf",
	"Snowy Fox",
	"Peppermint Doggy",
	"Summer Shark",
	"Blueberry Deer",
	"Amethyst Bear",
	"Crystal Bunny",
	"Emerald Doggy",
	"Chocolate Bear",
	"Gummy Shark",
	"Honey Comb Bee",
	"Magic Panda",
	"Ghost Kitty",
	"King Doggy",
	"Lunar Fox",
	"Queen Bee",
	"Water Golem",
	"Rainbow Butterfly",
	"Ghost Doggy",
	"Atlantis Guardian",
	"Manticore",
	"Void Fox",
	"Inferno Cube",
	"Radiant Protector",
	"Atlantis Pegasus",
	"Magma Hybrid",
	"Night Dweller",
	"Rainbow Shock",
	"Holy Bee",
	"Holy Shock",
	"Lunarcorn",
	"Atlantis Overlord",
	"Infernal Master",
	"Rainbow Drag",
	"King Pufferfish",
	"Night Terror",
	"King Eye",
	"Giant Robot",
	"Sylently's Pet",
	"Void Dragon",
}

function PetConfig.GetMap1Roster(): { string }
	return PetConfig.Map1Roster
end

-- Map 2 index roster — fill when Index 2 exists. Empty = Map 3 stays locked (50% of 0).
PetConfig.Map2Roster = {} :: { string }

function PetConfig.GetMap2Roster(): { string }
	return PetConfig.Map2Roster
end


-- Roblox-style huge "1 in X" ladder. Top tiers need absurd luck bait to feel reachable.
-- Economy 1C: OneIn matters again (higher SoftWeight); Mythic+ stretched further.
PetConfig.RarityOneInBase = {
	Common = 5,
	Uncommon = 80,
	Rare = 2500,
	Epic = 250000,
	Legendary = 18000000,
	Mythic = 2500000000,
	Angelic = 4e11,
	Glorious = 8e13,
	Radiant = 1.5e16,
	Secret = 3e18,
	Eternal = 6e20,
	Divine = 1.2e23,
}

PetConfig.RarityOneInStep = {
	Common = 4,
	Uncommon = 35,
	Rare = 1400,
	Epic = 180000,
	Legendary = 12000000,
	Mythic = 2e9,
	Angelic = 3e11,
	Glorious = 6e13,
	Radiant = 1.2e16,
	Secret = 2.5e18,
	Eternal = 5e20,
	Divine = 0,
}

-- Flat-ish sell bases by rarity (NOT linear with OneIn — stops money snowball).
-- Economy 1D: Common/Uncommon print slower so 15 min cannot buy Bronze;
-- Rare+ stay jackpots, Mythic+ are Map 1 long-tail not hourly wage.
PetConfig.RaritySellBase = {
	Common = 10,
	Uncommon = 28,
	Rare = 80,
	Epic = 400,
	Legendary = 2200,
	Mythic = 7000,
	Angelic = 20000,
	Glorious = 55000,
	Radiant = 140000,
	Secret = 360000,
	Eternal = 950000,
	Divine = 2800000,
}

local ICON_BY_NAME = {
	reindeer = "🦌",
	deer = "🦌",
	dog = "🐶",
	cat = "🐱",
	fox = "🦊",
	wolf = "🐺",
	bear = "🐻",
	panda = "🐼",
	tiger = "🐯",
	lion = "🦁",
	cow = "🐮",
	pig = "🐷",
	frog = "🐸",
	monkey = "🐵",
	chicken = "🐔",
	bird = "🐦",
	eagle = "🦅",
	owl = "🦉",
	duck = "🦆",
	penguin = "🐧",
	fish = "🐟",
	shark = "🦈",
	whale = "🐋",
	dolphin = "🐬",
	octopus = "🐙",
	crab = "🦀",
	turtle = "🐢",
	snake = "🐍",
	dragon = "🐉",
	unicorn = "🦄",
	horse = "🐴",
	rabbit = "🐰",
	bunny = "🐰",
	mouse = "🐭",
	rat = "🐀",
	hamster = "🐹",
	bat = "🦇",
	spider = "🕷️",
	bee = "🐝",
	butterfly = "🦋",
	snail = "🐌",
	goat = "🐐",
	sheep = "🐑",
	camel = "🐪",
	elephant = "🐘",
	giraffe = "🦒",
	zebra = "🦓",
	hippo = "🦛",
	rhino = "🦏",
	crocodile = "🐊",
	alligator = "🐊",
	dino = "🦕",
	dinosaur = "🦕",
	trex = "🦖",
	ghost = "👻",
	alien = "👽",
	robot = "🤖",
	slime = "🟢",
	axolotl = "🦎",
	lizard = "🦎",
	gecko = "🦎",
	chameleon = "🦎",
	parrot = "🦜",
	flamingo = "🦩",
	peacock = "🦚",
	swan = "🦢",
	seal = "🦭",
	otter = "🦦",
	raccoon = "🦝",
	skunk = "🦨",
	hedgehog = "🦔",
	kangaroo = "🦘",
	koala = "🐨",
	sloth = "🦥",
	beaver = "🦫",
	bison = "🦬",
	mammoth = "🦣",
	phoenix = "🔥",
	griffin = "🦅",
	kitsune = "🦊",
}

local function findIcon(petName: string): string
	local lower = string.lower(petName)
	if ICON_BY_NAME[lower] then
		return ICON_BY_NAME[lower]
	end

	for key, icon in pairs(ICON_BY_NAME) do
		if string.find(lower, key, 1, true) then
			return icon
		end
	end

	return "🐾"
end

function PetConfig.ToDisplayName(rawName: string): string
	local trimmed = string.gsub(rawName, "^%s*(.-)%s*$", "%1")
	if trimmed == "" then
		return "Pet"
	end

	-- Keep multi-word / apostrophe names as authored (e.g. "Teddy Bear", "Sylently's Pet").
	if string.find(trimmed, "[%s']") then
		return trimmed
	end

	return string.upper(string.sub(trimmed, 1, 1)) .. string.lower(string.sub(trimmed, 2))
end

function PetConfig.GetRarityColor(rarity: string): Color3
	return PetConfig.RarityColors[rarity] or Color3.fromRGB(200, 200, 200)
end

function PetConfig.FormatOneIn(oneIn: number): string
	return NumberFormat.FormatCompact(math.max(1, math.floor(oneIn)))
end

function PetConfig.ComputeSellPrice(oneIn: number, rarity: string?): number
	local tier = rarity or "Common"
	local base = PetConfig.RaritySellBase[tier] or 50
	local rarityOneIn = PetConfig.RarityOneInBase[tier] or math.max(1, oneIn)
	local ratio = oneIn / math.max(1, rarityOneIn)
	-- Small within-tier variance only — sell value must not track OneIn linearly.
	return math.max(10, math.floor(base * (0.9 + 0.25 * math.clamp(ratio, 0.5, 2))))
end

function PetConfig.ComputeWeight(oneIn: number): number
	-- Lower OneIn => higher weight. Large numerator keeps 1e18+ pets at tiny non-zero weight.
	return math.max(1e-24, 1e12 / math.max(1, oneIn))
end

function PetConfig.BuildDefinition(name: string, rarity: string, oneIn: number): PetDefinition
	local displayName = PetConfig.ToDisplayName(name)
	return {
		Name = displayName,
		Rarity = rarity,
		OneIn = oneIn,
		Weight = PetConfig.ComputeWeight(oneIn),
		Color = PetConfig.GetRarityColor(rarity),
		SellPrice = PetConfig.ComputeSellPrice(oneIn, rarity),
		Icon = findIcon(displayName),
		Description = string.format("%s pet. Chance about 1 in %s.", rarity, PetConfig.FormatOneIn(oneIn)),
	}
end

function PetConfig.AssignRarities(names: { string }): { PetDefinition }
	local defs = {}
	local index = 1
	local total = #names

	for _, rarity in ipairs(PetConfig.RarityOrder) do
		local count = PetConfig.RarityCounts[rarity] or 0
		local base = PetConfig.RarityOneInBase[rarity] or 100
		local step = PetConfig.RarityOneInStep[rarity] or 0

		for tierIndex = 1, count do
			if index > total then
				break
			end

			local oneIn = base + (tierIndex - 1) * step
			table.insert(defs, PetConfig.BuildDefinition(names[index], rarity, oneIn))
			index += 1
		end
	end

	-- Overflow pets (if more than planned counts) go into Common with rising OneIn.
	while index <= total do
		local oneIn = 10 + index * 2
		table.insert(defs, PetConfig.BuildDefinition(names[index], "Common", oneIn))
		index += 1
	end

	return defs
end

function PetConfig.SetPets(pets: { PetDefinition })
	PetConfig.Pets = pets
end

function PetConfig.GetByName(petName: string): PetDefinition?
	for _, pet in ipairs(PetConfig.Pets) do
		if pet.Name == petName then
			return pet
		end
	end

	return nil
end

function PetConfig.IsKnownPet(petName: string): boolean
	return PetConfig.GetByName(petName) ~= nil
end

local function colorFromValues(entry: Folder): Color3
	local r = entry:FindFirstChild("ColorR")
	local g = entry:FindFirstChild("ColorG")
	local b = entry:FindFirstChild("ColorB")
	if r and g and b and r:IsA("NumberValue") and g:IsA("NumberValue") and b:IsA("NumberValue") then
		return Color3.new(r.Value, g.Value, b.Value)
	end
	return Color3.fromRGB(200, 200, 200)
end

local function readNumber(entry: Folder, name: string, fallback: number): number
	local value = entry:FindFirstChild(name)
	if value and value:IsA("NumberValue") then
		return value.Value
	end
	return fallback
end

local function readString(entry: Folder, name: string, fallback: string): string
	local value = entry:FindFirstChild(name)
	if value and value:IsA("StringValue") then
		return value.Value
	end
	return fallback
end

function PetConfig.ParseCatalogFolder(catalog: Folder): { PetDefinition }
	local pets = {}

	for _, child in ipairs(catalog:GetChildren()) do
		if child:IsA("Folder") then
			local rarity = readString(child, "Rarity", "Common")
			local oneIn = math.max(1, math.floor(readNumber(child, "OneIn", 10)))
			local sellPrice = math.max(1, math.floor(readNumber(child, "SellPrice", PetConfig.ComputeSellPrice(oneIn, rarity))))
			local weight = readNumber(child, "Weight", PetConfig.ComputeWeight(oneIn))
			table.insert(pets, {
				Name = child.Name,
				Rarity = rarity,
				OneIn = oneIn,
				Weight = weight,
				Color = colorFromValues(child),
				SellPrice = sellPrice,
				Icon = readString(child, "Icon", findIcon(child.Name)),
				Description = readString(child, "Description", string.format("%s pet.", rarity)),
			})
		end
	end

	table.sort(pets, function(a, b)
		local ai = table.find(PetConfig.RarityOrder, a.Rarity) or 99
		local bi = table.find(PetConfig.RarityOrder, b.Rarity) or 99
		if ai == bi then
			return a.OneIn < b.OneIn
		end
		return ai < bi
	end)

	return pets
end

-- Fallback: preview models carry Rarity/OneIn tags after PetCatalogService sync.
function PetConfig.ParsePreviewsFolder(previews: Folder): { PetDefinition }
	local pets: { PetDefinition } = {}

	for _, child in ipairs(previews:GetChildren()) do
		if child:IsA("Model") and child.Name ~= "" then
			local rarity = "Common"
			local rarityValue = child:FindFirstChild("Rarity")
			if rarityValue and rarityValue:IsA("StringValue") and rarityValue.Value ~= "" then
				rarity = rarityValue.Value
			end

			local oneIn = 10
			local oneInValue = child:FindFirstChild("OneIn")
			if oneInValue and oneInValue:IsA("NumberValue") and oneInValue.Value > 0 then
				oneIn = math.max(1, math.floor(oneInValue.Value))
			end

			table.insert(pets, PetConfig.BuildDefinition(child.Name, rarity, oneIn))
		end
	end

	table.sort(pets, function(a, b)
		local ai = table.find(PetConfig.RarityOrder, a.Rarity) or 99
		local bi = table.find(PetConfig.RarityOrder, b.Rarity) or 99
		if ai == bi then
			return a.OneIn < b.OneIn
		end
		return ai < bi
	end)

	return pets
end

function PetConfig.ParseRemotePayload(payload: any): { PetDefinition }
	local pets: { PetDefinition } = {}
	if typeof(payload) ~= "table" then
		return pets
	end

	local function adoptEntry(entry: any)
		if typeof(entry) ~= "table" or typeof(entry.Name) ~= "string" or entry.Name == "" then
			return
		end
		local rarity = if typeof(entry.Rarity) == "string" and entry.Rarity ~= "" then entry.Rarity else "Common"
		local oneIn = if typeof(entry.OneIn) == "number" then math.max(1, math.floor(entry.OneIn)) else 10
		local def = PetConfig.BuildDefinition(entry.Name, rarity, oneIn)
		if typeof(entry.SellPrice) == "number" then
			def.SellPrice = math.max(1, math.floor(entry.SellPrice))
		end
		if typeof(entry.Weight) == "number" then
			def.Weight = entry.Weight
		end
		if typeof(entry.Icon) == "string" and entry.Icon ~= "" then
			def.Icon = entry.Icon
		end
		if typeof(entry.Description) == "string" and entry.Description ~= "" then
			def.Description = entry.Description
		end
		if typeof(entry.ColorR) == "number" and typeof(entry.ColorG) == "number" and typeof(entry.ColorB) == "number" then
			def.Color = Color3.new(entry.ColorR, entry.ColorG, entry.ColorB)
		end
		table.insert(pets, def)
	end

	-- Prefer array iteration; fall back to pairs for remote table quirks.
	local sawArray = false
	for _, entry in ipairs(payload) do
		sawArray = true
		adoptEntry(entry)
	end
	if not sawArray then
		for _, entry in pairs(payload) do
			adoptEntry(entry)
		end
	end

	table.sort(pets, function(a, b)
		local ai = table.find(PetConfig.RarityOrder, a.Rarity) or 99
		local bi = table.find(PetConfig.RarityOrder, b.Rarity) or 99
		if ai == bi then
			return a.OneIn < b.OneIn
		end
		return ai < bi
	end)

	return pets
end

local function tryAdoptLocalCatalog(): boolean
	local catalog = ReplicatedStorage:FindFirstChild("PetCatalog")
	if catalog and catalog:IsA("Folder") then
		local parsed = PetConfig.ParseCatalogFolder(catalog)
		if #parsed > 0 then
			PetConfig.Pets = parsed
			return true
		end
	end

	local previews = ReplicatedStorage:FindFirstChild("PetPreviews")
	if previews and previews:IsA("Folder") then
		local parsed = PetConfig.ParsePreviewsFolder(previews)
		if #parsed > 0 then
			PetConfig.Pets = parsed
			return true
		end
	end

	return false
end

local function tryAdoptRemoteCatalog(): boolean
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		return false
	end
	local remote = remotes:FindFirstChild("GetPetCatalog")
	if not remote or not remote:IsA("RemoteFunction") then
		return false
	end

	-- RemoteFunction without OnServerInvoke yields forever — never call it bare.
	local result: any = nil
	local done = false
	local ok = true
	local err: any = nil
	task.spawn(function()
		ok, err = pcall(function()
			result = (remote :: RemoteFunction):InvokeServer()
		end)
		done = true
	end)

	local deadline = os.clock() + 4
	while not done and os.clock() < deadline do
		task.wait()
	end
	if not done then
		warn("[PetConfig] GetPetCatalog timed out (server handler missing or stalled).")
		return false
	end
	if not ok then
		warn("[PetConfig] GetPetCatalog invoke failed:", err)
		return false
	end

	local parsed = PetConfig.ParseRemotePayload(result)
	if #parsed > 0 then
		PetConfig.Pets = parsed
		return true
	end
	return false
end

function PetConfig.WriteCatalogFolder(pets: { PetDefinition }): Folder
	local existing = ReplicatedStorage:FindFirstChild("PetCatalog")
	if existing then
		existing:Destroy()
	end

	local catalog = Instance.new("Folder")
	catalog.Name = "PetCatalog"

	for _, pet in ipairs(pets) do
		local entry = Instance.new("Folder")
		entry.Name = pet.Name
		entry.Parent = catalog

		local function addString(name: string, value: string)
			local v = Instance.new("StringValue")
			v.Name = name
			v.Value = value
			v.Parent = entry
		end

		local function addNumber(name: string, value: number)
			local v = Instance.new("NumberValue")
			v.Name = name
			v.Value = value
			v.Parent = entry
		end

		addString("Rarity", pet.Rarity)
		addString("Icon", pet.Icon)
		addString("Description", pet.Description)
		addNumber("OneIn", pet.OneIn)
		addNumber("Weight", pet.Weight)
		addNumber("SellPrice", pet.SellPrice)
		addNumber("ColorR", pet.Color.R)
		addNumber("ColorG", pet.Color.G)
		addNumber("ColorB", pet.Color.B)
	end

	catalog.Parent = ReplicatedStorage
	return catalog
end

function PetConfig.EnsureLoaded(timeoutSeconds: number?): { PetDefinition }
	if #PetConfig.Pets > 0 then
		return PetConfig.Pets
	end

	if tryAdoptLocalCatalog() then
		return PetConfig.Pets
	end

	-- Prefer a direct server snapshot over waiting on folder replication.
	if tryAdoptRemoteCatalog() then
		return PetConfig.Pets
	end

	local timeout = timeoutSeconds or 20
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		if tryAdoptLocalCatalog() then
			return PetConfig.Pets
		end
		if tryAdoptRemoteCatalog() then
			return PetConfig.Pets
		end
		task.wait(0.25)
	end

	tryAdoptRemoteCatalog()
	return PetConfig.Pets
end

return PetConfig
