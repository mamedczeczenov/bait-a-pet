--!strict

--[[
	Builds the catchable pet catalog for Map 1.
	Must never block PlayerDataService.Load (that shows "Still loading...").
]]

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local PetConfig = require(Modules:WaitForChild("PetConfig"))
local PetRarityFx = require(Modules:WaitForChild("PetRarityFx"))

local PetCatalogService = {}

local PREVIEW_FOLDER_NAME = "PetPreviews"

local initDone = false
local initInProgress = false

local function getOrCreateFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function prepareStoredPetModel(model: Model)
	local staleRoot = model:FindFirstChild("PetFaceRoot")
	if staleRoot then
		staleRoot:Destroy()
	end
	model:SetAttribute("FacePivotBaked", nil)
	model:SetAttribute("FaceBakeVersion", nil)
	model:SetAttribute("FaceAimReady", nil)
	model:SetAttribute("FaceLX", nil)
	model:SetAttribute("FaceLY", nil)
	model:SetAttribute("FaceLZ", nil)
	model:SetAttribute("UpLX", nil)
	model:SetAttribute("UpLY", nil)
	model:SetAttribute("UpLZ", nil)

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
		end
	end

	if not model.PrimaryPart then
		local best: BasePart? = nil
		local bestVolume = -1
		local bestName = ""
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
				if volume > bestVolume or (volume == bestVolume and descendant.Name < bestName) then
					bestVolume = volume
					bestName = descendant.Name
					best = descendant
				end
			end
		end
		if best then
			model.PrimaryPart = best
		end
	end
end

local function writeModelTags(model: Model, definition: {
	Name: string,
	Rarity: string,
	OneIn: number,
})
	local rarityValue = model:FindFirstChild("Rarity")
	if rarityValue and not rarityValue:IsA("StringValue") then
		rarityValue:Destroy()
		rarityValue = nil
	end
	if not rarityValue then
		local created = Instance.new("StringValue")
		created.Name = "Rarity"
		created.Parent = model
		rarityValue = created
	end
	(rarityValue :: StringValue).Value = definition.Rarity

	local oneInValue = model:FindFirstChild("OneIn")
	if oneInValue and not oneInValue:IsA("NumberValue") then
		oneInValue:Destroy()
		oneInValue = nil
	end
	if not oneInValue then
		local created = Instance.new("NumberValue")
		created.Name = "OneIn"
		created.Parent = model
		oneInValue = created
	end
	(oneInValue :: NumberValue).Value = definition.OneIn

	local endgameValue = model:FindFirstChild("EndgameFx")
	if endgameValue and not endgameValue:IsA("BoolValue") then
		endgameValue:Destroy()
		endgameValue = nil
	end
	if not endgameValue then
		local created = Instance.new("BoolValue")
		created.Name = "EndgameFx"
		created.Parent = model
		endgameValue = created
	end
	(endgameValue :: BoolValue).Value = PetRarityFx.IsEndgame(definition.Rarity)
end

local function flattenNestedPetsFolder(petsFolder: Folder)
	local nestedPack = petsFolder:FindFirstChild("Pets")
	if nestedPack and nestedPack:IsA("Folder") then
		for _, child in ipairs(nestedPack:GetChildren()) do
			child.Parent = petsFolder
		end
		nestedPack:Destroy()
	end
end

local function indexModelsByName(folder: Instance): { [string]: Model }
	local byName: { [string]: Model } = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") and child.Name ~= "" then
			byName[child.Name] = child
		end
	end
	return byName
end

-- Pull only roster-named models from Workspace (never import a whole 200+ pack).
local function pullMissingRosterModelsFromWorkspace(petsFolder: Folder, roster: { string }, have: { [string]: Model })
	local want: { [string]: boolean } = {}
	local missing = 0
	for _, name in ipairs(roster) do
		want[name] = true
		if not have[name] then
			missing += 1
		end
	end
	if missing == 0 then
		return
	end

	local preferredNames = { "folder", "Folder", "Pets", "pets", "PetModels", "Models", "Zwierzaki", "Pety" }
	local sources: { Instance } = {}
	for _, name in ipairs(preferredNames) do
		local found = Workspace:FindFirstChild(name)
		if found and (found:IsA("Folder") or found:IsA("Model")) then
			table.insert(sources, found)
		end
	end

	for _, source in ipairs(sources) do
		for _, child in ipairs(source:GetChildren()) do
			if child:IsA("Model") and want[child.Name] and not have[child.Name] then
				local displayName = child.Name
				prepareStoredPetModel(child)
				child.Parent = petsFolder
				have[displayName] = child
				missing -= 1
				if missing <= 0 then
					return
				end
			end
		end
	end
end

local function syncClientPreviews(petsFolder: Folder)
	local existing = ReplicatedStorage:FindFirstChild(PREVIEW_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local previews = Instance.new("Folder")
	previews.Name = PREVIEW_FOLDER_NAME
	previews.Parent = ReplicatedStorage

	local count = 0
	for _, child in ipairs(petsFolder:GetChildren()) do
		if child:IsA("Model") then
			local clone = child:Clone()
			prepareStoredPetModel(clone)
			clone.Parent = previews
			count += 1
		end
	end

	print(string.format("[PetCatalogService] Synced %d pet previews to ReplicatedStorage.%s", count, PREVIEW_FOLDER_NAME))
end

local function buildCatalogFast()
	local roster = PetConfig.GetMap1Roster()
	local petsFolder = getOrCreateFolder(ServerStorage, "Pets")
	flattenNestedPetsFolder(petsFolder)

	local have = indexModelsByName(petsFolder)
	pullMissingRosterModelsFromWorkspace(petsFolder, roster, have)

	-- Drop non-roster models (old catalog leftovers) without touching missing ones.
	local kept: { [string]: boolean } = {}
	for _, name in ipairs(roster) do
		kept[name] = true
	end
	for _, child in ipairs(petsFolder:GetChildren()) do
		if child:IsA("Model") and not kept[child.Name] then
			child:Destroy()
		end
	end

	local modelCount = 0
	for _, name in ipairs(roster) do
		local model = petsFolder:FindFirstChild(name)
		if model and model:IsA("Model") then
			prepareStoredPetModel(model)
			modelCount += 1
		end
	end

	-- Catalog is always the 60 roster names (even if some models are missing).
	local definitions = PetConfig.AssignRarities(roster)
	PetConfig.SetPets(definitions)
	PetConfig.WriteCatalogFolder(definitions)

	for _, definition in ipairs(definitions) do
		local model = petsFolder:FindFirstChild(definition.Name)
		if model and model:IsA("Model") then
			writeModelTags(model, definition)
		end
	end

	-- Heavy preview clone off the critical path.
	task.defer(function()
		local ok, err = pcall(syncClientPreviews, petsFolder)
		if not ok then
			warn("[PetCatalogService] Preview sync failed:", err)
		end
	end)

	print(string.format(
		"[PetCatalogService] Ready: %d catalog pets, %d models in ServerStorage.Pets.",
		#definitions,
		modelCount
	))

	return definitions
end

function PetCatalogService.IsReady(): boolean
	return initDone and #PetConfig.Pets > 0
end

function PetCatalogService.Initialize()
	if initDone then
		return PetConfig.Pets
	end

	-- Re-entrant: another caller while first build runs — wait briefly, don't nest.
	if initInProgress then
		local deadline = os.clock() + 8
		while initInProgress and os.clock() < deadline do
			task.wait()
		end
		return PetConfig.Pets
	end

	initInProgress = true

	local ok, result = pcall(buildCatalogFast)
	initInProgress = false
	initDone = true

	if not ok then
		warn("[PetCatalogService] Initialize failed:", result)
		-- Emergency catalog so throws still resolve.
		local definitions = PetConfig.AssignRarities(PetConfig.GetMap1Roster())
		PetConfig.SetPets(definitions)
		pcall(function()
			PetConfig.WriteCatalogFolder(definitions)
		end)
		return PetConfig.Pets
	end

	return result
end

-- Fire-and-forget for bootstrap / PlayerAdded (never blocks Load).
function PetCatalogService.InitializeAsync()
	task.defer(function()
		PetCatalogService.Initialize()
	end)
end

return PetCatalogService
