--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local BaitConfig = require(Modules:WaitForChild("BaitConfig"))
local PetConfig = require(Modules:WaitForChild("PetConfig"))
local ShopConfig = require(Modules:WaitForChild("ShopConfig"))
local UpgradeConfig = require(Modules:WaitForChild("UpgradeConfig"))
local PotionConfig = require(Modules:WaitForChild("PotionConfig"))
local CatchFeelConfig = require(Modules:WaitForChild("CatchFeelConfig"))
local PityConfig = require(Modules:WaitForChild("PityConfig"))
local CaveConfig = require(Modules:WaitForChild("CaveConfig"))
local VipConfig = require(Modules:WaitForChild("VipConfig"))
local PlaceConfig = require(Modules:WaitForChild("PlaceConfig"))
local IndexRewardConfig = require(Modules:WaitForChild("IndexRewardConfig"))

local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local PetCatalogService = require(script.Parent:WaitForChild("PetCatalogService"))
local InventoryMetaService = require(script.Parent:WaitForChild("InventoryMetaService"))

export type GoalSave = {
	Uid: string,
	TemplateId: string,
	Progress: number,
	ReadyToClaim: boolean,
}

export type PlayerData = {
	Coins: number,
	UnlockedBaits: { string },
	ActiveBait: string,
	LuckLevel: number,
	ValueLevel: number,
	SpeedLevel: number,
	BagLevel: number,
	Pets: { string },
	PetTags: { string },
	DiscoveredPets: { string },
	ClaimedIndexPets: { string },
	ClaimedIndexMilestones: { string },
	TutorialCompleted: boolean,
	TutorialRewardClaimed: boolean,
	GroupChestClaimed: boolean,
	CelebrationMinRarity: string,
	Goals: { GoalSave },
	GoalsIntroShown: boolean,
	LuckBuffCatches: number,
	LuckBuffMult: number,
	LockedPetIndices: { number },
	HotbarPins: { number },
	EpicPityFails: number,
	DailyStreak: number,
	LastDailyClaimDay: string,
	AdsWatchedToday: number,
	LastAdRewardDay: string,
	VipAccess: boolean,
	Map2Unlocked: boolean,
	Map3Unlocked: boolean,
	CompanionPetName: string,
	CompanionPetNames: { string },
	UnlockedCompanions: { string },
	AfkThrow: boolean,
	AfkPets: { string },
	AfkDiscovered: { string },
	PotionLuckCount: number,
	PotionSellCount: number,
	PotionSuperLuckCount: number,
	PotionSuperSellCount: number,
	PotionSuperBundleCount: number,
	PotionLuckRemaining: number,
	PotionSellRemaining: number,
	PotionLuckActiveMult: number,
	PotionSellActiveMult: number,
	ProcessedDevPurchases: { string },
	PlaytimeSeconds: number,
	-- Unknown DataStore keys from newer/older places — written back on save.
	ExtraSave: { [string]: any },
}

local PlayerDataService = {}

function PlayerDataService.GetMaxEquippedPetsFromFlags(map2Unlocked: boolean, map3Unlocked: boolean): number
	if map3Unlocked then
		return 3
	end
	if map2Unlocked then
		return 2
	end
	return 1
end

-- Economy 1D wipe: v2 abandoned (old coins/baits/index). New joins start fresh.
local STORE_NAME = "PlayerData_v3"
local SAVE_DEBOUNCE = 4

local dataStore: DataStore? = nil
local storeInitFailed = false

local sessionData: { [Player]: PlayerData } = {}
local loadedPlayers: { [Player]: boolean } = {}
local loadingPlayers: { [Player]: boolean } = {}
local dirtyPlayers: { [Player]: boolean } = {}
local saveQueued: { [Player]: boolean } = {}
local saving: { [Player]: boolean } = {}
-- GetAsync timeout/error: play with defaults this session, but never overwrite the real DataStore.
local blockPersistentSave: { [Player]: boolean } = {}
-- os.time() when the current playtime slice started (session or last flush).
local sessionPlaytimeAnchor: { [Player]: number } = {}

local function getStore(): DataStore?
	if dataStore then
		return dataStore
	end
	if storeInitFailed then
		return nil
	end

	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)

	if ok and result then
		dataStore = result
		return dataStore
	end

	storeInitFailed = true
	warn("[PlayerDataService] DataStore unavailable:", result)
	return nil
end

local function listContains(list: { string }, value: string): boolean
	for _, entry in ipairs(list) do
		if entry == value then
			return true
		end
	end
	return false
end

local KNOWN_SAVE_KEYS: { [string]: boolean } = {
	Coins = true,
	UnlockedBaits = true,
	ActiveBait = true,
	LuckLevel = true,
	ValueLevel = true,
	SpeedLevel = true,
	BagLevel = true,
	Pets = true,
	PetTags = true,
	DiscoveredPets = true,
	ClaimedIndexPets = true,
	ClaimedIndexMilestones = true,
	TutorialCompleted = true,
	TutorialRewardClaimed = true,
	GroupChestClaimed = true,
	CelebrationMinRarity = true,
	Goals = true,
	GoalsIntroShown = true,
	LuckBuffCatches = true,
	LuckBuffMult = true,
	LockedPetIndices = true,
	HotbarPins = true,
	EpicPityFails = true,
	DailyStreak = true,
	LastDailyClaimDay = true,
	AdsWatchedToday = true,
	LastAdRewardDay = true,
	VipAccess = true,
	Map2Unlocked = true,
	Map3Unlocked = true,
	CompanionPetName = true,
	CompanionPetNames = true,
	CompanionPetName2 = true,
	UnlockedCompanions = true,
	AfkThrow = true,
	AfkPets = true,
	AfkDiscovered = true,
	PotionLuckCount = true,
	PotionSellCount = true,
	PotionSuperLuckCount = true,
	PotionSuperSellCount = true,
	PotionSuperBundleCount = true,
	PotionLuckRemaining = true,
	PotionSellRemaining = true,
	PotionLuckActiveMult = true,
	PotionSellActiveMult = true,
	ProcessedDevPurchases = true,
	PlaytimeSeconds = true,
	ExtraSave = true,
}

local function asNonNegativeInt(raw: any): number
	if typeof(raw) ~= "number" then
		return 0
	end
	return math.max(0, math.floor(raw))
end

-- Arrays OR dictionary-style tables (DataStore / older saves).
local function collectUniqueStrings(raw: any): { string }
	local result: { string } = {}
	local seen: { [string]: boolean } = {}
	if typeof(raw) ~= "table" then
		return result
	end

	local function add(value: any)
		if typeof(value) == "string" and value ~= "" and not seen[value] then
			seen[value] = true
			table.insert(result, value)
		end
	end

	for _, value in ipairs(raw) do
		add(value)
	end
	for key, value in pairs(raw) do
		if typeof(key) == "string" then
			add(key)
		end
		if typeof(value) == "string" then
			add(value)
		end
	end

	return result
end

local function unionStringLists(left: any, right: any): { string }
	local result = collectUniqueStrings(left)
	for _, value in ipairs(collectUniqueStrings(right)) do
		if not listContains(result, value) then
			table.insert(result, value)
		end
	end
	return result
end

-- Pets can stack (multiple Fox). Restore copies this place's catalog would have stripped.
local function restoreCatalogGapPets(oldPets: any, newPets: { string }): { string }
	local result = table.clone(newPets)
	if typeof(oldPets) ~= "table" then
		return result
	end

	local newCounts: { [string]: number } = {}
	for _, name in ipairs(result) do
		newCounts[name] = (newCounts[name] or 0) + 1
	end

	local oldCounts: { [string]: number } = {}
	for _, value in ipairs(oldPets) do
		if typeof(value) == "string" and value ~= "" then
			oldCounts[value] = (oldCounts[value] or 0) + 1
		end
	end

	for name, oldCount in pairs(oldCounts) do
		local newCount = newCounts[name] or 0
		if oldCount > newCount and not PetConfig.IsKnownPet(name) then
			for _ = 1, oldCount - newCount do
				table.insert(result, name)
			end
		end
	end

	return result
end

local function captureExtraSave(raw: any): { [string]: any }
	local extra: { [string]: any } = {}
	if typeof(raw) ~= "table" then
		return extra
	end
	for key, value in pairs(raw) do
		if typeof(key) == "string" and not KNOWN_SAVE_KEYS[key] then
			extra[key] = value
		end
	end
	return extra
end

local function sanitizeUnlockedBaits(raw: any): { string }
	local unlocked = BaitConfig.GetStartingUnlocked()

	-- Keep unknown bait IDs too — map 2 with an older BaitConfig must not
	-- wipe baits unlocked on map 1.
	for _, value in ipairs(collectUniqueStrings(raw)) do
		if not listContains(unlocked, value) then
			table.insert(unlocked, value)
		end
	end

	-- Always keep starter baits.
	for _, baitId in ipairs(BaitConfig.GetStartingUnlocked()) do
		if not listContains(unlocked, baitId) then
			table.insert(unlocked, baitId)
		end
	end

	return unlocked
end

local function sanitizeActiveBait(raw: any, unlocked: { string }): string
	if typeof(raw) == "string" and raw ~= "" and listContains(unlocked, raw) then
		return raw
	end

	if listContains(unlocked, BaitConfig.DefaultBaitId) then
		return BaitConfig.DefaultBaitId
	end

	return unlocked[1] or BaitConfig.DefaultBaitId
end

local function defaultData(): PlayerData
	local unlocked = BaitConfig.GetStartingUnlocked()
	return {
		Coins = ShopConfig.StartingCoins,
		UnlockedBaits = unlocked,
		ActiveBait = BaitConfig.DefaultBaitId,
		LuckLevel = 0,
		ValueLevel = 0,
		SpeedLevel = 0,
		BagLevel = 0,
		Pets = {},
		PetTags = {},
		DiscoveredPets = {},
		ClaimedIndexPets = {},
		ClaimedIndexMilestones = {},
		TutorialCompleted = false,
		TutorialRewardClaimed = false,
		GroupChestClaimed = false,
		CelebrationMinRarity = CatchFeelConfig.DefaultMinRarity,
		Goals = {},
		GoalsIntroShown = false,
		LuckBuffCatches = 0,
		LuckBuffMult = 1,
		LockedPetIndices = {},
		HotbarPins = table.create(9, 0),
		EpicPityFails = 0,
		DailyStreak = 0,
		LastDailyClaimDay = "",
		AdsWatchedToday = 0,
		LastAdRewardDay = "",
		VipAccess = false,
		Map2Unlocked = false,
		Map3Unlocked = false,
		CompanionPetName = "",
		CompanionPetNames = {},
		UnlockedCompanions = {},
		AfkThrow = false,
		AfkPets = {},
		AfkDiscovered = {},
		PotionLuckCount = 0,
		PotionSellCount = 0,
		PotionSuperLuckCount = 0,
		PotionSuperSellCount = 0,
		PotionSuperBundleCount = 0,
		PotionLuckRemaining = 0,
		PotionSellRemaining = 0,
		PotionLuckActiveMult = 1,
		PotionSellActiveMult = 1,
		ProcessedDevPurchases = {},
		PlaytimeSeconds = 0,
		ExtraSave = {},
	}
end

local function sanitizePets(raw: any): { string }
	local pets = {}
	if typeof(raw) ~= "table" then
		return pets
	end

	-- Keep owned names even when this place's catalog is incomplete/different
	-- (map 2 often lacks the full pet roster). Stripping "unknown" pets here
	-- wiped backpack + index progress on cross-place teleport while coins/baits
	-- survived. Only drop legacy placeholders that are not real catalog pets.
	local function consider(value: any)
		if typeof(value) ~= "string" or value == "" then
			return
		end
		local known = PetConfig.IsKnownPet(value)
		local isLegacyPlaceholder = (value == "Mouse" or value == "Fox" or value == "Dragon") and not known
		if not isLegacyPlaceholder then
			table.insert(pets, value)
		end
	end

	for _, value in ipairs(raw) do
		consider(value)
	end
	-- Dictionary-shaped saves have no sequential keys; ipairs would drop the backpack.
	if #pets == 0 then
		for _, value in pairs(raw) do
			consider(value)
		end
	end

	return pets
end

local function sanitizePetTags(raw: any, petCount: number): { string }
	local tags: { string } = table.create(petCount, "")
	if typeof(raw) ~= "table" then
		return tags
	end

	for index = 1, petCount do
		local value = raw[index]
		if typeof(value) == "string" and value ~= "" then
			tags[index] = value
		end
	end

	return tags
end

local function sanitizeDiscoveredPets(raw: any, ownedPets: { string }): { string }
	-- collectUniqueStrings keeps both array and dictionary DataStore shapes.
	-- ipairs-only used to drop the whole index when the save was a { [name]=true } set.
	local discovered = collectUniqueStrings(raw)

	for _, petName in ipairs(ownedPets) do
		if typeof(petName) == "string" and petName ~= "" and not listContains(discovered, petName) then
			table.insert(discovered, petName)
		end
	end

	return discovered
end

local function sanitizeClaimedIndexPets(raw: any, discoveredPets: { string }): { string }
	if typeof(raw) ~= "table" or typeof(raw.ClaimedIndexPets) ~= "table" then
		-- Migration: existing discoveries count as claimed without retroactive payout.
		return table.clone(discoveredPets)
	end

	local claimed: { string } = {}
	for _, value in ipairs(collectUniqueStrings(raw.ClaimedIndexPets)) do
		if listContains(discoveredPets, value) and not listContains(claimed, value) then
			table.insert(claimed, value)
		end
	end

	return claimed
end

local function sanitizeClaimedIndexMilestones(raw: any): { string }
	if typeof(raw) ~= "table" or typeof(raw.ClaimedIndexMilestones) ~= "table" then
		return {}
	end

	local claimed: { string } = {}
	for _, value in ipairs(raw.ClaimedIndexMilestones) do
		if typeof(value) == "string"
			and value ~= ""
			and IndexRewardConfig.IsValidMilestoneId(value)
			and not listContains(claimed, value)
		then
			table.insert(claimed, value)
		end
	end

	return claimed
end

local function sanitizeData(raw: any): PlayerData
	local data = defaultData()
	if typeof(raw) ~= "table" then
		return data
	end

	if typeof(raw.Coins) == "number" then
		data.Coins = math.max(0, math.floor(raw.Coins))
	end
	if typeof(raw.LuckLevel) == "number" then
		data.LuckLevel = UpgradeConfig.ClampLevel(raw.LuckLevel)
	end
	if typeof(raw.ValueLevel) == "number" then
		data.ValueLevel = UpgradeConfig.ClampLevel(raw.ValueLevel)
	end
	if typeof(raw.SpeedLevel) == "number" then
		data.SpeedLevel = UpgradeConfig.ClampLevel(raw.SpeedLevel)
	end
	if typeof(raw.BagLevel) == "number" then
		data.BagLevel = UpgradeConfig.ClampBagLevel(raw.BagLevel)
	end
	data.Pets = restoreCatalogGapPets(raw.Pets, sanitizePets(raw.Pets))
	data.PetTags = sanitizePetTags(raw.PetTags, #data.Pets)
	data.DiscoveredPets = sanitizeDiscoveredPets(raw.DiscoveredPets, data.Pets)
	data.ClaimedIndexPets = sanitizeClaimedIndexPets(raw, data.DiscoveredPets)
	data.ClaimedIndexMilestones = sanitizeClaimedIndexMilestones(raw)
	data.UnlockedBaits = sanitizeUnlockedBaits(raw.UnlockedBaits)
	data.ActiveBait = sanitizeActiveBait(raw.ActiveBait, data.UnlockedBaits)
	data.TutorialCompleted = raw.TutorialCompleted == true
	data.TutorialRewardClaimed = raw.TutorialRewardClaimed == true
	data.GroupChestClaimed = raw.GroupChestClaimed == true
	data.CelebrationMinRarity = CatchFeelConfig.NormalizeMinRarity(raw.CelebrationMinRarity)
	-- Older saves that somehow claimed a reward without the completed flag.
	if data.TutorialRewardClaimed then
		data.TutorialCompleted = true
	end

	local GoalService = require(script.Parent.GoalService)
	local goalsOk, goals = pcall(function()
		return GoalService.SanitizeGoals(raw.Goals)
	end)
	if goalsOk and typeof(goals) == "table" then
		data.Goals = goals
	else
		data.Goals = {}
		if not goalsOk then
			warn("[PlayerDataService] SanitizeGoals failed:", goals)
		end
	end
	data.GoalsIntroShown = raw.GoalsIntroShown == true
	if typeof(raw.LuckBuffCatches) == "number" then
		data.LuckBuffCatches = math.max(0, math.floor(raw.LuckBuffCatches))
	end
	if typeof(raw.LuckBuffMult) == "number" then
		data.LuckBuffMult = math.max(1, raw.LuckBuffMult)
	end
	if data.LuckBuffCatches <= 0 then
		data.LuckBuffMult = 1
	end

	data.LockedPetIndices = InventoryMetaService.SanitizeLockedIndices(raw.LockedPetIndices, #data.Pets)
	data.HotbarPins = InventoryMetaService.SanitizeHotbarPins(raw.HotbarPins, #data.Pets)
	if typeof(raw.EpicPityFails) == "number" then
		data.EpicPityFails = math.max(0, math.floor(raw.EpicPityFails))
	end
	if typeof(raw.DailyStreak) == "number" then
		data.DailyStreak = math.max(0, math.floor(raw.DailyStreak))
	end
	if typeof(raw.LastDailyClaimDay) == "string" then
		data.LastDailyClaimDay = raw.LastDailyClaimDay
	end
	if typeof(raw.AdsWatchedToday) == "number" then
		data.AdsWatchedToday = math.max(0, math.floor(raw.AdsWatchedToday))
	end
	if typeof(raw.LastAdRewardDay) == "string" then
		data.LastAdRewardDay = raw.LastAdRewardDay
	end
	data.VipAccess = raw.VipAccess == true
	data.Map2Unlocked = raw.Map2Unlocked == true
	data.Map3Unlocked = raw.Map3Unlocked == true
	if data.Map3Unlocked then
		data.Map2Unlocked = true
	end

	local unlockedCompanions: { string } = {}
	if typeof(raw.UnlockedCompanions) == "table" then
		for _, value in ipairs(raw.UnlockedCompanions) do
			if typeof(value) == "string" and value ~= "" and not listContains(unlockedCompanions, value) then
				table.insert(unlockedCompanions, value)
			end
		end
	end

	local companionNames: { string } = {}
	if typeof(raw.CompanionPetNames) == "table" then
		for _, value in ipairs(raw.CompanionPetNames) do
			if typeof(value) == "string" and value ~= "" and not listContains(companionNames, value) then
				table.insert(companionNames, value)
			end
			if #companionNames >= 2 then
				break
			end
		end
	end
	if #companionNames == 0 and typeof(raw.CompanionPetName) == "string" and raw.CompanionPetName ~= "" then
		table.insert(companionNames, raw.CompanionPetName)
	end
	if typeof(raw.CompanionPetName2) == "string"
		and raw.CompanionPetName2 ~= ""
		and not listContains(companionNames, raw.CompanionPetName2)
	then
		table.insert(companionNames, raw.CompanionPetName2)
	end
	while #companionNames > 2 do
		table.remove(companionNames)
	end

	for _, name in ipairs(companionNames) do
		if not listContains(unlockedCompanions, name) then
			table.insert(unlockedCompanions, name)
		end
	end

	data.CompanionPetNames = companionNames
	data.CompanionPetName = companionNames[1] or ""
	data.UnlockedCompanions = unlockedCompanions
	data.AfkThrow = raw.AfkThrow == true
	local afkPets: { string } = {}
	if typeof(raw.AfkPets) == "table" then
		for _, value in ipairs(raw.AfkPets) do
			if typeof(value) == "string" and value ~= "" then
				table.insert(afkPets, value)
				if #afkPets >= 30 then
					break
				end
			end
		end
	end
	data.AfkPets = afkPets
	data.AfkDiscovered = collectUniqueStrings(raw.AfkDiscovered)
	if typeof(raw.PotionLuckCount) == "number" then
		data.PotionLuckCount = PotionConfig.ClampOwned(raw.PotionLuckCount)
	end
	if typeof(raw.PotionSellCount) == "number" then
		data.PotionSellCount = PotionConfig.ClampOwned(raw.PotionSellCount)
	end
	if typeof(raw.PotionSuperLuckCount) == "number" then
		data.PotionSuperLuckCount = PotionConfig.ClampOwned(raw.PotionSuperLuckCount)
	end
	if typeof(raw.PotionSuperSellCount) == "number" then
		data.PotionSuperSellCount = PotionConfig.ClampOwned(raw.PotionSuperSellCount)
	end
	if typeof(raw.PotionSuperBundleCount) == "number" then
		data.PotionSuperBundleCount = PotionConfig.ClampOwned(raw.PotionSuperBundleCount)
	end
	if typeof(raw.PotionLuckRemaining) == "number" then
		data.PotionLuckRemaining = PotionConfig.ClampRemaining(raw.PotionLuckRemaining)
	end
	if typeof(raw.PotionSellRemaining) == "number" then
		data.PotionSellRemaining = PotionConfig.ClampRemaining(raw.PotionSellRemaining)
	end
	if typeof(raw.PotionLuckActiveMult) == "number" then
		data.PotionLuckActiveMult = PotionConfig.ClampActiveMult(raw.PotionLuckActiveMult)
	end
	if typeof(raw.PotionSellActiveMult) == "number" then
		data.PotionSellActiveMult = PotionConfig.ClampActiveMult(raw.PotionSellActiveMult)
	end
	if data.PotionLuckRemaining <= 0 then
		data.PotionLuckActiveMult = 1
	end
	if data.PotionSellRemaining <= 0 then
		data.PotionSellActiveMult = 1
	end
	local processed: { string } = {}
	if typeof(raw.ProcessedDevPurchases) == "table" then
		for _, value in ipairs(raw.ProcessedDevPurchases) do
			if typeof(value) == "string" and value ~= "" then
				table.insert(processed, value)
				if #processed >= 40 then
					break
				end
			end
		end
	end
	data.ProcessedDevPurchases = processed
	if typeof(raw.PlaytimeSeconds) == "number" then
		data.PlaytimeSeconds = math.max(0, math.floor(raw.PlaytimeSeconds))
	end
	data.ExtraSave = captureExtraSave(raw)

	return data
end

local function syncNamedBoolFolder(player: Player, folderName: string, names: { string })
	local folder = player:FindFirstChild(folderName)
	if not folder or not folder:IsA("Folder") then
		if folder then
			folder:Destroy()
		end
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = player
	end

	local keep: { [string]: boolean } = {}
	for _, entryName in ipairs(names) do
		keep[entryName] = true
		local existing = folder:FindFirstChild(entryName)
		if not existing then
			local marker = Instance.new("BoolValue")
			marker.Name = entryName
			marker.Value = true
			marker.Parent = folder
		end
	end

	for _, child in ipairs(folder:GetChildren()) do
		if not keep[child.Name] then
			child:Destroy()
		end
	end
end

local function applyAttributes(player: Player, data: PlayerData)
	player:SetAttribute("Coins", data.Coins)
	player:SetAttribute("ActiveBait", data.ActiveBait)
	player:SetAttribute("LuckLevel", data.LuckLevel)
	player:SetAttribute("ValueLevel", data.ValueLevel)
	player:SetAttribute("SpeedLevel", data.SpeedLevel)
	player:SetAttribute("CatchSpeedBonus", UpgradeConfig.GetCatchSpeedBonus(data.SpeedLevel))
	player:SetAttribute("BagLevel", data.BagLevel)
	player:SetAttribute("BagCapacity", UpgradeConfig.GetBagCapacity(data.BagLevel))
	player:SetAttribute("LuckBonus", UpgradeConfig.GetLuckBonus(data.LuckLevel))
	player:SetAttribute("ValueMult", UpgradeConfig.GetValueMultiplier(data.ValueLevel))
	player:SetAttribute("TutorialCompleted", data.TutorialCompleted)
	player:SetAttribute("TutorialRewardClaimed", data.TutorialRewardClaimed)
	player:SetAttribute("GroupChestClaimed", data.GroupChestClaimed == true)
	player:SetAttribute("CelebrationMinRarity", data.CelebrationMinRarity)
	player:SetAttribute("LuckBuffCatches", data.LuckBuffCatches)
	player:SetAttribute("LuckBuffMult", data.LuckBuffMult)
	player:SetAttribute("EpicPityFails", data.EpicPityFails)
	player:SetAttribute("DailyStreak", data.DailyStreak)
	player:SetAttribute("LastDailyClaimDay", data.LastDailyClaimDay)
	player:SetAttribute("AdsWatchedToday", data.AdsWatchedToday)
	player:SetAttribute("LastAdRewardDay", data.LastAdRewardDay)
	player:SetAttribute("VipAccess", data.VipAccess == true)
	player:SetAttribute("Map2Unlocked", data.Map2Unlocked == true)
	player:SetAttribute("Map3Unlocked", data.Map3Unlocked == true)
	player:SetAttribute("MaxEquippedPets", PlayerDataService.GetMaxEquippedPetsFromFlags(data.Map2Unlocked, data.Map3Unlocked))
	player:SetAttribute("AfkThrow", data.AfkThrow == true)
	player:SetAttribute("PotionLuckCount", data.PotionLuckCount)
	player:SetAttribute("PotionSellCount", data.PotionSellCount)
	player:SetAttribute("PotionSuperLuckCount", data.PotionSuperLuckCount)
	player:SetAttribute("PotionSuperSellCount", data.PotionSuperSellCount)
	player:SetAttribute("PotionSuperBundleCount", data.PotionSuperBundleCount)
	player:SetAttribute("PotionLuckRemaining", data.PotionLuckRemaining)
	player:SetAttribute("PotionSellRemaining", data.PotionSellRemaining)
	player:SetAttribute("PotionLuckMult", PotionConfig.GetChannelMultiplier(data.PotionLuckRemaining, data.PotionLuckActiveMult))
	player:SetAttribute("PotionSellMult", PotionConfig.GetChannelMultiplier(data.PotionSellRemaining, data.PotionSellActiveMult))
	local companionNames = if typeof(data.CompanionPetNames) == "table" then data.CompanionPetNames else {}
	if #companionNames == 0 and data.CompanionPetName ~= "" then
		companionNames = { data.CompanionPetName }
	end
	local primary = companionNames[1] or ""
	local secondary = companionNames[2] or ""
	player:SetAttribute("CompanionPetName", primary)
	player:SetAttribute("CompanionPetName2", secondary)
	if #companionNames == 0 then
		player:SetAttribute("CompanionPetNames", "")
	elseif #companionNames == 1 then
		player:SetAttribute("CompanionPetNames", primary)
	else
		player:SetAttribute("CompanionPetNames", string.format("%s,%s", primary, secondary))
	end
	player:SetAttribute("CompanionWalkCount", #companionNames)
	player:SetAttribute("CompanionWalkMax", if data.Map2Unlocked then 2 else 1)
	if primary ~= "" then
		local CompanionConfig = require(Modules:WaitForChild("CompanionConfig"))
		local bestLuck = 1
		local bestSell = 1
		local rarity = ""
		for _, name in ipairs(companionNames) do
			local buff, resolvedRarity = CompanionConfig.GetBuffForPet(name)
			if buff.LuckMult > bestLuck then
				bestLuck = buff.LuckMult
			end
			if buff.SellMult > bestSell then
				bestSell = buff.SellMult
			end
			if rarity == "" then
				rarity = resolvedRarity
			end
		end
		player:SetAttribute("CompanionRarity", rarity)
		player:SetAttribute("CompanionLuckMult", bestLuck)
		player:SetAttribute("CompanionSellMult", bestSell)
	else
		player:SetAttribute("CompanionRarity", "")
		player:SetAttribute("CompanionLuckMult", 1)
		player:SetAttribute("CompanionSellMult", 1)
	end
	InventoryMetaService.SyncPlayer(player, data.LockedPetIndices, data.HotbarPins)
	-- TutorialActive / TutorialStep are owned by TutorialService during a run.
	if player:GetAttribute("TutorialActive") == nil then
		player:SetAttribute("TutorialActive", false)
	end
	if player:GetAttribute("TutorialStep") == nil then
		player:SetAttribute("TutorialStep", 0)
	end
	-- Clear legacy consumable bait attribute if present.
	player:SetAttribute("Bait", nil)
	player:SetAttribute("PlaytimeSeconds", data.PlaytimeSeconds)
	syncNamedBoolFolder(player, "UnlockedBaits", data.UnlockedBaits)
	syncNamedBoolFolder(player, "DiscoveredPets", data.DiscoveredPets)
	syncNamedBoolFolder(player, "ClaimedIndexPets", data.ClaimedIndexPets)
	syncNamedBoolFolder(player, "ClaimedIndexMilestones", data.ClaimedIndexMilestones)
	syncNamedBoolFolder(player, "UnlockedCompanions", data.UnlockedCompanions)
end

local function getLivePlaytimeSeconds(player: Player): number
	local data = sessionData[player]
	local stored = if data then data.PlaytimeSeconds else 0
	local anchor = sessionPlaytimeAnchor[player]
	if typeof(anchor) ~= "number" then
		return stored
	end
	return stored + math.max(0, os.time() - anchor)
end

local function flushPlaytime(player: Player)
	local data = sessionData[player]
	if not data then
		return
	end
	data.PlaytimeSeconds = getLivePlaytimeSeconds(player)
	sessionPlaytimeAnchor[player] = os.time()
	player:SetAttribute("PlaytimeSeconds", data.PlaytimeSeconds)
end

local function syncPetsToInventory(player: Player, pets: { string }, tags: { string }?)
	InventoryService.InitPlayer(player, pets, tags)
end

local function captureFromPlayer(player: Player): PlayerData?
	local existing = sessionData[player]
	if not existing then
		return nil
	end

	flushPlaytime(player)

	local coins = player:GetAttribute("Coins")
	local activeBait = player:GetAttribute("ActiveBait")
	local luckLevel = player:GetAttribute("LuckLevel")
	local valueLevel = player:GetAttribute("ValueLevel")
	local speedLevel = player:GetAttribute("SpeedLevel")
	local bagLevel = player:GetAttribute("BagLevel")

	existing.Coins = if typeof(coins) == "number" then math.max(0, math.floor(coins)) else existing.Coins
	existing.LuckLevel = if typeof(luckLevel) == "number" then UpgradeConfig.ClampLevel(luckLevel) else existing.LuckLevel
	existing.ValueLevel = if typeof(valueLevel) == "number" then UpgradeConfig.ClampLevel(valueLevel) else existing.ValueLevel
	existing.SpeedLevel = if typeof(speedLevel) == "number" then UpgradeConfig.ClampLevel(speedLevel) else existing.SpeedLevel
	existing.BagLevel = if typeof(bagLevel) == "number" then UpgradeConfig.ClampBagLevel(bagLevel) else existing.BagLevel

	-- Live inventory is source of truth while the session exists — including
	-- empty after a real sell. Skipping {} used to restore sold pets on rejoin.
	-- PlayerRemoving race is handled by HasSession: Cleanup saves first, then
	-- InventoryService.CleanupPlayer clears the session.
	if InventoryService.HasSession(player) then
		existing.Pets = InventoryService.GetPets(player)
		existing.PetTags = InventoryService.GetPetTags(player)
	end

	existing.ActiveBait = sanitizeActiveBait(activeBait, existing.UnlockedBaits)

	return existing
end

local function keyFor(player: Player): string
	return tostring(player.UserId)
end

function PlayerDataService.IsLoaded(player: Player): boolean
	return loadedPlayers[player] == true
end

function PlayerDataService.CanPersist(player: Player): boolean
	return loadedPlayers[player] == true and blockPersistentSave[player] ~= true
end

function PlayerDataService.GetPlaytimeSeconds(player: Player): number
	return getLivePlaytimeSeconds(player)
end

function PlayerDataService.FlushPlaytime(player: Player)
	flushPlaytime(player)
end

function PlayerDataService.GetData(player: Player): PlayerData?
	return sessionData[player]
end

function PlayerDataService.GetLuckBonus(player: Player): number
	local bonus = player:GetAttribute("LuckBonus")
	if typeof(bonus) == "number" then
		return bonus
	end
	return 1
end

function PlayerDataService.GetValueMultiplier(player: Player): number
	local mult = player:GetAttribute("ValueMult")
	if typeof(mult) == "number" then
		return mult
	end
	return 1
end

function PlayerDataService.SetAfkThrow(player: Player, enabled: boolean)
	local data = sessionData[player]
	if not data then
		return
	end
	data.AfkThrow = enabled == true
	player:SetAttribute("AfkThrow", data.AfkThrow)
	PlayerDataService.MarkDirty(player)
end

function PlayerDataService.GetActiveBaitId(player: Player): string
	local data = sessionData[player]
	if data then
		return data.ActiveBait
	end

	local active = player:GetAttribute("ActiveBait")
	if typeof(active) == "string" and BaitConfig.IsValidId(active) then
		return active
	end

	return BaitConfig.DefaultBaitId
end

function PlayerDataService.HasBaitUnlocked(player: Player, baitId: string): boolean
	local data = sessionData[player]
	if not data then
		return false
	end
	return listContains(data.UnlockedBaits, baitId)
end

function PlayerDataService.GetUnlockedBaits(player: Player): { string }
	local data = sessionData[player]
	if not data then
		return BaitConfig.GetStartingUnlocked()
	end
	return table.clone(data.UnlockedBaits)
end

function PlayerDataService.UnlockBait(player: Player, baitId: string): boolean
	local data = sessionData[player]
	if not data then
		return false
	end
	if not BaitConfig.IsValidId(baitId) then
		return false
	end
	if listContains(data.UnlockedBaits, baitId) then
		return false
	end

	table.insert(data.UnlockedBaits, baitId)
	syncNamedBoolFolder(player, "UnlockedBaits", data.UnlockedBaits)
	PlayerDataService.MarkDirty(player)
	return true
end

local PROCESSED_PURCHASE_CAP = 80

function PlayerDataService.HasProcessedPurchase(player: Player, purchaseId: string): boolean
	local data = sessionData[player]
	if not data or purchaseId == "" then
		return false
	end
	for _, id in ipairs(data.ProcessedDevPurchases) do
		if id == purchaseId then
			return true
		end
	end
	return false
end

function PlayerDataService.MarkProcessedPurchase(player: Player, purchaseId: string)
	local data = sessionData[player]
	if not data or purchaseId == "" then
		return
	end
	if PlayerDataService.HasProcessedPurchase(player, purchaseId) then
		return
	end
	table.insert(data.ProcessedDevPurchases, purchaseId)
	while #data.ProcessedDevPurchases > PROCESSED_PURCHASE_CAP do
		table.remove(data.ProcessedDevPurchases, 1)
	end
	PlayerDataService.MarkDirty(player)
end

function PlayerDataService.SetActiveBait(player: Player, baitId: string): (boolean, string?)
	local data = sessionData[player]
	if not data then
		return false, "Player data not loaded."
	end
	if not BaitConfig.IsValidId(baitId) then
		return false, "Unknown bait."
	end
	if not listContains(data.UnlockedBaits, baitId) then
		return false, "You don't own that bait."
	end

	data.ActiveBait = baitId
	player:SetAttribute("ActiveBait", baitId)
	PlayerDataService.MarkDirty(player)
	return true, nil
end

function PlayerDataService.SyncClaimedIndexPets(player: Player, claimed: { string })
	local data = sessionData[player]
	if data then
		data.ClaimedIndexPets = table.clone(claimed)
	end
	syncNamedBoolFolder(player, "ClaimedIndexPets", claimed)
end

function PlayerDataService.SyncClaimedIndexMilestones(player: Player, claimed: { string })
	local data = sessionData[player]
	if data then
		data.ClaimedIndexMilestones = table.clone(claimed)
	end
	syncNamedBoolFolder(player, "ClaimedIndexMilestones", claimed)
end

function PlayerDataService.MarkPetDiscovered(player: Player, petName: string): boolean
	local data = sessionData[player]
	if not data then
		return false
	end
	if typeof(petName) ~= "string" or petName == "" then
		return false
	end
	if listContains(data.DiscoveredPets, petName) then
		return false
	end

	table.insert(data.DiscoveredPets, petName)
	syncNamedBoolFolder(player, "DiscoveredPets", data.DiscoveredPets)
	PlayerDataService.MarkDirty(player)
	return true
end

function PlayerDataService.MarkDirty(player: Player)
	if not loadedPlayers[player] then
		return
	end
	dirtyPlayers[player] = true
	PlayerDataService.QueueSave(player)
end

function PlayerDataService.Save(player: Player): boolean
	if not loadedPlayers[player] then
		return false
	end
	if blockPersistentSave[player] then
		warn(string.format(
			"[PlayerDataService] Skip save for %s — DataStore load did not succeed; refusing to overwrite.",
			player.Name
		))
		return false
	end

	-- Wait out an in-flight save so leave / BindToClose / teleport don't skip.
	local waitDeadline = os.clock() + 6
	while saving[player] and os.clock() < waitDeadline do
		task.wait(0.05)
	end

	local data = captureFromPlayer(player)
	if not data then
		return false
	end

	local store = getStore()
	if not store then
		-- Keep dirty so a later leave / retry can still flush.
		return false
	end

	if saving[player] then
		warn(string.format("[PlayerDataService] Save still busy for %s; deferring.", player.Name))
		dirtyPlayers[player] = true
		return false
	end

	saving[player] = true
	local payload: { [string]: any } = {
		Coins = data.Coins,
		UnlockedBaits = table.clone(data.UnlockedBaits),
		ActiveBait = data.ActiveBait,
		LuckLevel = data.LuckLevel,
		ValueLevel = data.ValueLevel,
		SpeedLevel = data.SpeedLevel,
		BagLevel = data.BagLevel,
		Pets = table.clone(data.Pets),
		PetTags = table.clone(data.PetTags),
		DiscoveredPets = table.clone(data.DiscoveredPets),
		ClaimedIndexPets = table.clone(data.ClaimedIndexPets),
		ClaimedIndexMilestones = table.clone(data.ClaimedIndexMilestones),
		TutorialCompleted = data.TutorialCompleted,
		TutorialRewardClaimed = data.TutorialRewardClaimed,
		GroupChestClaimed = data.GroupChestClaimed == true,
		CelebrationMinRarity = data.CelebrationMinRarity,
		Goals = require(script.Parent.GoalService).CloneGoalsForSave(data.Goals),
		GoalsIntroShown = data.GoalsIntroShown,
		LuckBuffCatches = data.LuckBuffCatches,
		LuckBuffMult = data.LuckBuffMult,
		LockedPetIndices = table.clone(data.LockedPetIndices),
		HotbarPins = table.clone(data.HotbarPins),
		EpicPityFails = data.EpicPityFails,
		DailyStreak = data.DailyStreak,
		LastDailyClaimDay = data.LastDailyClaimDay,
		AdsWatchedToday = data.AdsWatchedToday,
		LastAdRewardDay = data.LastAdRewardDay,
		VipAccess = data.VipAccess == true,
		Map2Unlocked = data.Map2Unlocked == true,
		Map3Unlocked = data.Map3Unlocked == true,
		CompanionPetName = data.CompanionPetName,
		CompanionPetNames = table.clone(data.CompanionPetNames or {}),
		CompanionPetName2 = if data.CompanionPetNames then (data.CompanionPetNames[2] or "") else "",
		UnlockedCompanions = table.clone(data.UnlockedCompanions),
		AfkThrow = data.AfkThrow == true,
		AfkPets = table.clone(data.AfkPets or {}),
		AfkDiscovered = table.clone(data.AfkDiscovered or {}),
		PotionLuckCount = data.PotionLuckCount,
		PotionSellCount = data.PotionSellCount,
		PotionSuperLuckCount = data.PotionSuperLuckCount,
		PotionSuperSellCount = data.PotionSuperSellCount,
		PotionSuperBundleCount = data.PotionSuperBundleCount,
		PotionLuckRemaining = data.PotionLuckRemaining,
		PotionSellRemaining = data.PotionSellRemaining,
		PotionLuckActiveMult = data.PotionLuckActiveMult,
		PotionSellActiveMult = data.PotionSellActiveMult,
		ProcessedDevPurchases = table.clone(data.ProcessedDevPurchases or {}),
		PlaytimeSeconds = data.PlaytimeSeconds,
	}
	if typeof(data.ExtraSave) == "table" then
		for key, value in pairs(data.ExtraSave) do
			if typeof(key) == "string" and not KNOWN_SAVE_KEYS[key] and payload[key] == nil then
				payload[key] = value
			end
		end
	end

	local MAX_ATTEMPTS = 3
	local ok = false
	local err: any = nil
	for attempt = 1, MAX_ATTEMPTS do
		ok, err = pcall(function()
			store:SetAsync(keyFor(player), payload)
		end)
		if ok then
			break
		end
		warn(string.format(
			"[PlayerDataService] Save attempt %d/%d failed for %s: %s",
			attempt,
			MAX_ATTEMPTS,
			player.Name,
			tostring(err)
		))
		if attempt < MAX_ATTEMPTS then
			task.wait(0.4 * attempt)
		end
	end

	saving[player] = nil

	if not ok then
		warn(string.format("[PlayerDataService] Save failed for %s after %d attempts: %s", player.Name, MAX_ATTEMPTS, tostring(err)))
		dirtyPlayers[player] = true
		return false
	end

	dirtyPlayers[player] = false
	return true
end

function PlayerDataService.QueueSave(player: Player)
	if saveQueued[player] or not loadedPlayers[player] then
		return
	end

	saveQueued[player] = true
	task.delay(SAVE_DEBOUNCE, function()
		saveQueued[player] = nil
		if player.Parent and dirtyPlayers[player] then
			PlayerDataService.Save(player)
		end
	end)
end

function PlayerDataService.ForceLoadDefaults(player: Player): PlayerData
	local data = defaultData()
	sessionData[player] = data
	loadedPlayers[player] = true
	dirtyPlayers[player] = false
	blockPersistentSave[player] = true
	sessionPlaytimeAnchor[player] = os.time()
	player:SetAttribute("DataLoaded", true)
	player:SetAttribute("LeaderboardCanPersist", false)
	pcall(function()
		applyAttributes(player, data)
		syncPetsToInventory(player, data.Pets, data.PetTags)
		PlayerDataService.SyncBagAttributes(player)
	end)
	warn(string.format("[PlayerDataService] ForceLoadDefaults for %s (save blocked until a real DataStore load)", player.Name))
	return data
end

local function readStoreRecord(store: DataStore, player: Player): (boolean, any)
	local lastErr: any = nil
	for attempt = 1, 3 do
		local done = false
		local storeOk = false
		local result: any = nil
		task.spawn(function()
			storeOk, result = pcall(function()
				return store:GetAsync(keyFor(player))
			end)
			done = true
		end)

		local deadline = os.clock() + 8
		while not done and os.clock() < deadline do
			task.wait()
		end

		if done and storeOk then
			return true, result
		end

		if not done then
			lastErr = "GetAsync timed out"
			warn(string.format(
				"[PlayerDataService] DataStore GetAsync timed out for %s (attempt %d/3).",
				player.Name,
				attempt
			))
		else
			lastErr = result
			warn(string.format(
				"[PlayerDataService] Load failed for %s (attempt %d/3): %s",
				player.Name,
				attempt,
				tostring(result)
			))
		end

		if attempt < 3 then
			task.wait(0.4 * attempt)
		end
	end

	return false, lastErr
end

function PlayerDataService.Load(player: Player): PlayerData
	-- Catalog init must not block load ("Still loading...").
	pcall(function()
		PetCatalogService.InitializeAsync()
	end)

	if loadedPlayers[player] then
		local existing = sessionData[player]
		if existing then
			return existing
		end
	end

	local waitDeadline = os.clock() + 8
	while loadingPlayers[player] and os.clock() < waitDeadline do
		task.wait()
		if loadedPlayers[player] then
			local existing = sessionData[player]
			if existing then
				return existing
			end
		end
	end

	if loadedPlayers[player] then
		local existing = sessionData[player]
		if existing then
			return existing
		end
	end

	loadingPlayers[player] = true

	local ok, err = pcall(function()
		local store = getStore()
		local data = defaultData()
		local trustedLoad = store == nil

		if store then
			local storeOk, result = readStoreRecord(store, player)
			if storeOk then
				trustedLoad = true
				if result ~= nil then
					local sanitizeOk, sanitized = pcall(sanitizeData, result)
					if sanitizeOk and sanitized then
						data = sanitized
					else
						trustedLoad = false
						warn(string.format("[PlayerDataService] sanitizeData failed for %s: %s", player.Name, tostring(sanitized)))
					end
				end
			else
				trustedLoad = false
				warn(string.format(
					"[PlayerDataService] Using session defaults for %s without overwriting DataStore (%s).",
					player.Name,
					tostring(result)
				))
			end
		end

		if VipConfig.IsConfigured() then
			data.VipAccess = false
		end

		if PlaceConfig.IsMap2Place() then
			data.Map2Unlocked = true
		end

		sessionData[player] = data
		loadedPlayers[player] = true
		dirtyPlayers[player] = false
		blockPersistentSave[player] = not trustedLoad
		sessionPlaytimeAnchor[player] = os.time()
		player:SetAttribute("DataLoaded", true)
		player:SetAttribute("LeaderboardCanPersist", trustedLoad)

		applyAttributes(player, data)
		syncPetsToInventory(player, data.Pets, data.PetTags)
		PlayerDataService.SyncBagAttributes(player)

		if PlaceConfig.IsMap2Place() and trustedLoad then
			PlayerDataService.MarkDirty(player)
			PlayerDataService.QueueSave(player)
		end
	end)

	loadingPlayers[player] = nil

	if not ok then
		warn(string.format("[PlayerDataService] Load crashed for %s: %s", player.Name, tostring(err)))
	end

	if not loadedPlayers[player] then
		return PlayerDataService.ForceLoadDefaults(player)
	end

	return sessionData[player] :: PlayerData
end

local function applyMapUnlockAttributes(player: Player, data: PlayerData?)
	local map2 = false
	local map3 = false
	if data then
		map2 = data.Map2Unlocked == true
		map3 = data.Map3Unlocked == true
	else
		map2 = player:GetAttribute("Map2Unlocked") == true
		map3 = player:GetAttribute("Map3Unlocked") == true
	end
	player:SetAttribute("Map2Unlocked", map2)
	player:SetAttribute("Map3Unlocked", map3)
	player:SetAttribute("MaxEquippedPets", PlayerDataService.GetMaxEquippedPetsFromFlags(map2, map3))
	if map2 then
		player:SetAttribute("CompanionWalkMax", 2)
	end
end

function PlayerDataService.GetMaxEquippedPets(player: Player): number
	local data = sessionData[player]
	if data then
		return PlayerDataService.GetMaxEquippedPetsFromFlags(data.Map2Unlocked, data.Map3Unlocked)
	end
	local maxAttr = player:GetAttribute("MaxEquippedPets")
	if typeof(maxAttr) == "number" and maxAttr >= 1 then
		return math.clamp(math.floor(maxAttr), 1, 3)
	end
	return PlayerDataService.GetMaxEquippedPetsFromFlags(
		player:GetAttribute("Map2Unlocked") == true,
		player:GetAttribute("Map3Unlocked") == true
	)
end

function PlayerDataService.HasMap2Unlocked(player: Player): boolean
	local data = sessionData[player]
	if data and data.Map2Unlocked == true then
		return true
	end
	local attr = player:GetAttribute("Map2Unlocked")
	if attr == true or attr == 1 then
		return true
	end
	local maxAttr = player:GetAttribute("MaxEquippedPets")
	return typeof(maxAttr) == "number" and maxAttr >= 2
end

function PlayerDataService.HasMap3Unlocked(player: Player): boolean
	local data = sessionData[player]
	if data and data.Map3Unlocked == true then
		return true
	end
	local attr = player:GetAttribute("Map3Unlocked")
	return attr == true or attr == 1
end

function PlayerDataService.UnlockMap2(player: Player): boolean
	local data = sessionData[player]
	if not data then
		player:SetAttribute("Map2Unlocked", true)
		applyMapUnlockAttributes(player, nil)
		return false
	end
	if data.Map2Unlocked then
		applyMapUnlockAttributes(player, data)
		return false
	end

	data.Map2Unlocked = true
	applyMapUnlockAttributes(player, data)
	PlayerDataService.MarkDirty(player)
	PlayerDataService.QueueSave(player)
	return true
end

function PlayerDataService.UnlockMap3(player: Player): boolean
	local data = sessionData[player]
	if not data then
		player:SetAttribute("Map2Unlocked", true)
		player:SetAttribute("Map3Unlocked", true)
		applyMapUnlockAttributes(player, nil)
		return false
	end
	if data.Map3Unlocked then
		if not data.Map2Unlocked then
			data.Map2Unlocked = true
			PlayerDataService.MarkDirty(player)
		end
		applyMapUnlockAttributes(player, data)
		return false
	end

	data.Map2Unlocked = true
	data.Map3Unlocked = true
	applyMapUnlockAttributes(player, data)
	PlayerDataService.MarkDirty(player)
	PlayerDataService.QueueSave(player)
	return true
end

function PlayerDataService.HasVipAccess(player: Player): boolean
	-- Attribute only — never fall back to DataStore flag (stale VIP leak).
	return player:GetAttribute("VipAccess") == true
end

function PlayerDataService.SetVipAccess(player: Player, enabled: boolean, persist: boolean?)
	local shouldPersist = if persist == nil then true else persist
	local data = sessionData[player]
	if data and shouldPersist then
		data.VipAccess = enabled == true
		PlayerDataService.MarkDirty(player)
	end
	player:SetAttribute("VipAccess", enabled == true)
end

function PlayerDataService.GetCaveLuckMultiplier(player: Player, zone: BasePart?): number
	if not zone then
		return CaveConfig.GetPlaceLuckMultiplier(CaveConfig.Normal)
	end
	local caveType = CaveConfig.ResolveTypeFromZone(zone)
	if CaveConfig.RequiresVip(caveType) and not PlayerDataService.HasVipAccess(player) then
		return CaveConfig.NormalLuckMultiplier
	end
	local attrMult = zone:GetAttribute("CaveLuckMult")
	if typeof(attrMult) == "number" and attrMult > 0 then
		return attrMult
	end
	return CaveConfig.GetPlaceLuckMultiplier(caveType)
end

function PlayerDataService.ApplyUpgradeLevels(player: Player, luckLevel: number, valueLevel: number)
	local data = sessionData[player]
	if not data then
		return
	end

	data.LuckLevel = UpgradeConfig.ClampLevel(luckLevel)
	data.ValueLevel = UpgradeConfig.ClampLevel(valueLevel)
	player:SetAttribute("LuckLevel", data.LuckLevel)
	player:SetAttribute("ValueLevel", data.ValueLevel)
	player:SetAttribute("LuckBonus", UpgradeConfig.GetLuckBonus(data.LuckLevel))
	player:SetAttribute("ValueMult", UpgradeConfig.GetValueMultiplier(data.ValueLevel))
	PlayerDataService.MarkDirty(player)
end

function PlayerDataService.GetSpeedLevel(player: Player): number
	local data = sessionData[player]
	if data then
		return data.SpeedLevel
	end
	local attr = player:GetAttribute("SpeedLevel")
	if typeof(attr) == "number" then
		return UpgradeConfig.ClampLevel(attr)
	end
	return 0
end

function PlayerDataService.GetCatchSpeedBonus(player: Player): number
	return UpgradeConfig.GetCatchSpeedBonus(PlayerDataService.GetSpeedLevel(player))
end

function PlayerDataService.ApplySpeedLevel(player: Player, speedLevel: number)
	local data = sessionData[player]
	if not data then
		return
	end

	data.SpeedLevel = UpgradeConfig.ClampLevel(speedLevel)
	player:SetAttribute("SpeedLevel", data.SpeedLevel)
	player:SetAttribute("CatchSpeedBonus", UpgradeConfig.GetCatchSpeedBonus(data.SpeedLevel))
	PlayerDataService.MarkDirty(player)
end

function PlayerDataService.GetBagLevel(player: Player): number
	local data = sessionData[player]
	if data then
		return data.BagLevel
	end
	local attr = player:GetAttribute("BagLevel")
	if typeof(attr) == "number" then
		return UpgradeConfig.ClampBagLevel(attr)
	end
	return 0
end

function PlayerDataService.GetBagCapacity(player: Player): number
	return UpgradeConfig.GetBagCapacity(PlayerDataService.GetBagLevel(player))
end

function PlayerDataService.IsBagFull(player: Player): boolean
	return InventoryService.GetCount(player) >= PlayerDataService.GetBagCapacity(player)
end

function PlayerDataService.IsBagAlmostFull(player: Player): boolean
	local capacity = PlayerDataService.GetBagCapacity(player)
	if capacity <= 0 then
		return false
	end
	return InventoryService.GetCount(player) / capacity >= UpgradeConfig.BagAlmostFullRatio
end

function PlayerDataService.SyncBagAttributes(player: Player)
	local data = sessionData[player]
	if data and InventoryService.HasSession(player) then
		data.Pets = InventoryService.GetPets(player)
		data.PetTags = InventoryService.GetPetTags(player)
	end

	local bagLevel = PlayerDataService.GetBagLevel(player)
	local capacity = UpgradeConfig.GetBagCapacity(bagLevel)
	local petCount = InventoryService.GetCount(player)
	player:SetAttribute("BagLevel", bagLevel)
	player:SetAttribute("BagCapacity", capacity)
	player:SetAttribute("PetCount", petCount)
	if capacity > 0 and petCount / capacity < UpgradeConfig.BagAlmostFullRatio then
		player:SetAttribute("BagWarnArmed", false)
	end
end

function PlayerDataService.ApplyBagLevel(player: Player, bagLevel: number)
	local data = sessionData[player]
	if not data then
		return
	end

	data.BagLevel = UpgradeConfig.ClampBagLevel(bagLevel)
	PlayerDataService.SyncBagAttributes(player)
	PlayerDataService.MarkDirty(player)
end

function PlayerDataService.GetEpicPityFails(player: Player): number
	local data = sessionData[player]
	if data then
		return data.EpicPityFails
	end
	local attr = player:GetAttribute("EpicPityFails")
	if typeof(attr) == "number" then
		return math.max(0, math.floor(attr))
	end
	return 0
end

function PlayerDataService.RegisterCatchForPity(player: Player, rarity: string)
	local data = sessionData[player]
	if not data then
		return
	end

	if PityConfig.IsPityRarity(rarity) then
		data.EpicPityFails = 0
	else
		data.EpicPityFails = math.min(data.EpicPityFails + 1, 9999)
	end

	player:SetAttribute("EpicPityFails", data.EpicPityFails)
	PlayerDataService.MarkDirty(player)
end

function PlayerDataService.IsTutorialCompleted(player: Player): boolean
	local data = sessionData[player]
	if data then
		return data.TutorialCompleted
	end
	return player:GetAttribute("TutorialCompleted") == true
end

function PlayerDataService.SetTutorialCompleted(player: Player, completed: boolean)
	local data = sessionData[player]
	if not data then
		return
	end

	data.TutorialCompleted = completed
	player:SetAttribute("TutorialCompleted", completed)
	PlayerDataService.MarkDirty(player)
end

function PlayerDataService.HasTutorialRewardClaimed(player: Player): boolean
	local data = sessionData[player]
	if data then
		return data.TutorialRewardClaimed
	end
	return player:GetAttribute("TutorialRewardClaimed") == true
end

function PlayerDataService.MarkTutorialRewardClaimed(player: Player)
	local data = sessionData[player]
	if not data then
		return
	end

	data.TutorialRewardClaimed = true
	player:SetAttribute("TutorialRewardClaimed", true)
	PlayerDataService.MarkDirty(player)
end

function PlayerDataService.HasGroupChestClaimed(player: Player): boolean
	local data = sessionData[player]
	if data then
		return data.GroupChestClaimed == true
	end
	return player:GetAttribute("GroupChestClaimed") == true
end

function PlayerDataService.MarkGroupChestClaimed(player: Player)
	local data = sessionData[player]
	if not data then
		return
	end

	data.GroupChestClaimed = true
	player:SetAttribute("GroupChestClaimed", true)
	PlayerDataService.MarkDirty(player)
end

function PlayerDataService.ResetTutorialProgress(player: Player)
	local data = sessionData[player]
	if not data then
		return
	end

	data.TutorialCompleted = false
	data.TutorialRewardClaimed = false
	player:SetAttribute("TutorialCompleted", false)
	player:SetAttribute("TutorialRewardClaimed", false)
	PlayerDataService.MarkDirty(player)
end

function PlayerDataService.AddCoins(player: Player, amount: number): number
	local data = sessionData[player]
	if not data then
		return 0
	end

	local add = math.max(0, math.floor(amount))
	local coinsAttr = player:GetAttribute("Coins")
	local current = if typeof(coinsAttr) == "number" then coinsAttr else data.Coins
	local nextCoins = math.max(0, math.floor(current) + add)
	data.Coins = nextCoins
	player:SetAttribute("Coins", nextCoins)
	PlayerDataService.MarkDirty(player)
	return nextCoins
end

function PlayerDataService.GetCelebrationMinRarity(player: Player): string
	local data = sessionData[player]
	if data then
		return CatchFeelConfig.NormalizeMinRarity(data.CelebrationMinRarity)
	end
	return CatchFeelConfig.NormalizeMinRarity(player:GetAttribute("CelebrationMinRarity"))
end

function PlayerDataService.SetCelebrationMinRarity(player: Player, rarity: string): boolean
	local data = sessionData[player]
	if not data then
		return false
	end

	local normalized = CatchFeelConfig.NormalizeMinRarity(rarity)
	data.CelebrationMinRarity = normalized
	player:SetAttribute("CelebrationMinRarity", normalized)
	PlayerDataService.MarkDirty(player)
	return true
end

function PlayerDataService.GetLockedPetIndices(player: Player): { number }
	local data = sessionData[player]
	if not data then
		return {}
	end
	return table.clone(data.LockedPetIndices)
end

function PlayerDataService.GetHotbarPins(player: Player): { number }
	local data = sessionData[player]
	if not data then
		return table.create(9, 0)
	end
	return table.clone(data.HotbarPins)
end

function PlayerDataService.IsPetLocked(player: Player, index: number): boolean
	local data = sessionData[player]
	if not data then
		return false
	end
	return InventoryMetaService.IsLocked(data.LockedPetIndices, index)
end

function PlayerDataService.ToggleLockPet(player: Player, index: number): boolean
	local data = sessionData[player]
	if not data then
		return false
	end
	local petCount = #InventoryService.GetPets(player)
	data.LockedPetIndices = InventoryMetaService.ToggleLock(data.LockedPetIndices, index, petCount)
	InventoryMetaService.SyncPlayer(player, data.LockedPetIndices, data.HotbarPins)
	PlayerDataService.MarkDirty(player)
	return true
end

function PlayerDataService.ToggleHotbarPin(player: Player, inventoryIndex: number): boolean
	local data = sessionData[player]
	if not data then
		return false
	end
	local petCount = #InventoryService.GetPets(player)
	data.HotbarPins = InventoryMetaService.TogglePin(data.HotbarPins, inventoryIndex, petCount)
	InventoryMetaService.SyncPlayer(player, data.LockedPetIndices, data.HotbarPins)
	PlayerDataService.MarkDirty(player)
	return true
end

function PlayerDataService.OnInventoryPetRemoved(player: Player, removedIndex: number)
	PlayerDataService.OnInventoryPetsRemoved(player, { removedIndex })
end

function PlayerDataService.OnInventoryPetsRemoved(player: Player, removedIndices: { number })
	local data = sessionData[player]
	if not data or #removedIndices == 0 then
		return
	end
	local locked, pins = InventoryMetaService.RemapAfterRemoves(data.LockedPetIndices, data.HotbarPins, removedIndices)
	data.LockedPetIndices = locked
	data.HotbarPins = pins
	InventoryMetaService.SyncPlayer(player, data.LockedPetIndices, data.HotbarPins)
	PlayerDataService.SyncBagAttributes(player)
	PlayerDataService.MarkDirty(player)
end

function PlayerDataService.OnInventoryCleared(player: Player)
	local data = sessionData[player]
	if not data then
		return
	end
	data.LockedPetIndices, data.HotbarPins = InventoryMetaService.ClearAll()
	InventoryMetaService.SyncPlayer(player, data.LockedPetIndices, data.HotbarPins)
	PlayerDataService.SyncBagAttributes(player)
	PlayerDataService.MarkDirty(player)
end

function PlayerDataService.Cleanup(player: Player)
	if loadedPlayers[player] then
		flushPlaytime(player)
		PlayerDataService.Save(player)
	end

	sessionData[player] = nil
	loadedPlayers[player] = nil
	loadingPlayers[player] = nil
	dirtyPlayers[player] = nil
	saveQueued[player] = nil
	saving[player] = nil
	blockPersistentSave[player] = nil
	sessionPlaytimeAnchor[player] = nil
end

function PlayerDataService.BindToClose()
	local players = Players:GetPlayers()
	local remaining = #players
	if remaining == 0 then
		return
	end

	local done = Instance.new("BindableEvent")
	for _, player in ipairs(players) do
		task.spawn(function()
			PlayerDataService.Save(player)
			remaining -= 1
			if remaining <= 0 then
				done:Fire()
			end
		end)
	end

	-- Roblox BindToClose budget is short; don't hang forever on DataStore outages.
	local finished = false
	task.delay(8, function()
		if not finished then
			warn("[PlayerDataService] BindToClose timed out waiting for saves.")
			done:Fire()
		end
	end)

	done.Event:Wait()
	finished = true
	done:Destroy()
end

return PlayerDataService
