--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local IndexRewardConfig = require(Modules:WaitForChild("IndexRewardConfig"))
local NumberFormat = require(Modules:WaitForChild("NumberFormat"))
local PetConfig = require(Modules:WaitForChild("PetConfig"))
local PlaceConfig = require(Modules:WaitForChild("PlaceConfig"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local IndexService = {}

local remote: RemoteEvent? = nil

local function getRemote(): RemoteEvent
	if remote and remote.Parent then
		return remote
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local existing = remotes:FindFirstChild("Index")
	if existing and existing:IsA("RemoteEvent") then
		remote = existing
		return existing
	end

	local created = Instance.new("RemoteEvent")
	created.Name = "Index"
	created.Parent = remotes
	remote = created
	return created
end

local function listContains(list: { string }, value: string): boolean
	for _, entry in ipairs(list) do
		if entry == value then
			return true
		end
	end
	return false
end

local function buildPetPayload(data: any, pet: any): { [string]: any }
	local discovered = listContains(data.DiscoveredPets, pet.Name)
	local claimed = listContains(data.ClaimedIndexPets, pet.Name)
	return {
		Name = pet.Name,
		Rarity = pet.Rarity,
		OneIn = pet.OneIn,
		Icon = pet.Icon,
		Discovered = discovered,
		Claimed = claimed,
		RewardCoins = IndexRewardConfig.GetReward(pet.Rarity),
		CanClaim = discovered and not claimed,
	}
end

local function getRarityProgress(data: any, rarity: string): (number, number)
	local total = 0
	local discovered = 0
	for _, pet in ipairs(PetConfig.Pets) do
		if pet.Rarity == rarity then
			total += 1
			if listContains(data.DiscoveredPets, pet.Name) then
				discovered += 1
			end
		end
	end
	return discovered, total
end

local function buildMilestonePayload(data: any, percent: number): { { [string]: any } }
	local claimed = data.ClaimedIndexMilestones
	if typeof(claimed) ~= "table" then
		claimed = {}
	end

	local milestones = {}

	for _, def in ipairs(IndexRewardConfig.GetPercentMilestones()) do
		local target = if typeof(def.Target) == "number" then def.Target else 0
		local ready = percent >= target
		local isClaimed = listContains(claimed, def.Id)
		table.insert(milestones, {
			Id = def.Id,
			Kind = def.Kind,
			Label = def.Label,
			RewardCoins = def.RewardCoins,
			Progress = math.min(percent, target),
			Target = target,
			Ready = ready,
			Claimed = isClaimed,
			CanClaim = ready and not isClaimed,
		})
	end

	for _, def in ipairs(IndexRewardConfig.GetRarityMilestones()) do
		local rarity = if typeof(def.Target) == "string" then def.Target else ""
		local progress, target = getRarityProgress(data, rarity)
		if target <= 0 then
			continue
		end
		local ready = progress >= target
		local isClaimed = listContains(claimed, def.Id)
		table.insert(milestones, {
			Id = def.Id,
			Kind = def.Kind,
			Label = def.Label,
			RewardCoins = def.RewardCoins,
			Progress = progress,
			Target = target,
			Ready = ready,
			Claimed = isClaimed,
			CanClaim = ready and not isClaimed,
		})
	end

	return milestones
end

local function hasUnclaimedMilestone(data: any, percent: number): boolean
	local claimed = data.ClaimedIndexMilestones
	if typeof(claimed) ~= "table" then
		claimed = {}
	end

	for _, def in ipairs(IndexRewardConfig.GetPercentMilestones()) do
		local target = if typeof(def.Target) == "number" then def.Target else 0
		if percent >= target and not listContains(claimed, def.Id) then
			return true
		end
	end

	for _, def in ipairs(IndexRewardConfig.GetRarityMilestones()) do
		local rarity = if typeof(def.Target) == "string" then def.Target else ""
		local progress, target = getRarityProgress(data, rarity)
		if target > 0 and progress >= target and not listContains(claimed, def.Id) then
			return true
		end
	end

	return false
end

function IndexService.EnsureRemote(): RemoteEvent
	return getRemote()
end

function IndexService.GetCompletionPercent(data: any): number
	local total = #PetConfig.Pets
	if total <= 0 then
		return 0
	end

	local discovered = 0
	for _, pet in ipairs(PetConfig.Pets) do
		if listContains(data.DiscoveredPets, pet.Name) then
			discovered += 1
		end
	end

	return math.floor((discovered / total) * 100 + 0.5)
end

function IndexService.GetMap2CompletionPercent(data: any): number
	local roster = PetConfig.GetMap2Roster()
	local total = #roster
	if total <= 0 then
		return 0
	end

	local discovered = 0
	for _, name in ipairs(roster) do
		if listContains(data.DiscoveredPets, name) then
			discovered += 1
		end
	end

	return math.floor((discovered / total) * 100 + 0.5)
end

function IndexService.MeetsMap3IndexRequirement(player: Player): (boolean, string)
	local need = PlaceConfig.Map3IndexUnlockPercent
	local roster = PetConfig.GetMap2Roster()
	if #roster <= 0 then
		return false, string.format("Map 3 unlocks at %d%% of Map 2 Index (coming soon).", need)
	end

	local data = PlayerDataService.GetData(player)
	if not data then
		return false, string.format("Need %d%% of Map 2 Index to unlock Map 3.", need)
	end

	local percent = IndexService.GetMap2CompletionPercent(data)
	if percent >= need then
		return true, ""
	end

	return false, string.format("Need %d%% of Map 2 Index (%d%% / %d%%).", need, percent, need)
end

function IndexService.TryGrantMap3FromIndex(player: Player): boolean
	local met = select(1, IndexService.MeetsMap3IndexRequirement(player))
	if not met then
		return false
	end
	local newly = PlayerDataService.UnlockMap3(player)
	if newly then
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local petResult = remotes and remotes:FindFirstChild("PetResult")
		if petResult and petResult:IsA("RemoteEvent") then
			petResult:FireClient(player, {
				Type = "Map3Unlock",
				Message = "Map 3 unlocked — Carry 3 pets in hands!",
			})
		end
	end
	return newly
end

function IndexService.HasUnclaimedRewards(player: Player): boolean
	local data = PlayerDataService.GetData(player)
	if not data then
		return false
	end

	for _, pet in ipairs(PetConfig.Pets) do
		if listContains(data.DiscoveredPets, pet.Name) and not listContains(data.ClaimedIndexPets, pet.Name) then
			return true
		end
	end

	local percent = IndexService.GetCompletionPercent(data)
	return hasUnclaimedMilestone(data, percent)
end

function IndexService.PushSnapshot(player: Player, message: string?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end

	PetConfig.EnsureLoaded(10)
	if #PetConfig.Pets == 0 then
		return
	end

	local pets = {}
	local discoveredCount = 0
	for _, pet in ipairs(PetConfig.Pets) do
		local payload = buildPetPayload(data, pet)
		table.insert(pets, payload)
		if payload.Discovered then
			discoveredCount += 1
		end
	end

	local total = math.max(#PetConfig.Pets, 1)
	local percent = math.floor((discoveredCount / total) * 100 + 0.5)
	local milestones = buildMilestonePayload(data, percent)

	IndexService.TryGrantMap3FromIndex(player)

	getRemote():FireClient(player, {
		Type = "Snapshot",
		Message = message,
		TotalPets = total,
		DiscoveredCount = discoveredCount,
		Percent = percent,
		HasUnclaimed = IndexService.HasUnclaimedRewards(player),
		Pets = pets,
		Milestones = milestones,
	})
end

function IndexService.Claim(player: Player, petName: string): (boolean, string?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "Player data not loaded."
	end

	if typeof(petName) ~= "string" or petName == "" then
		return false, "Invalid pet."
	end

	local pet = PetConfig.GetByName(petName)
	if not pet then
		return false, "Unknown pet."
	end

	if not listContains(data.DiscoveredPets, petName) then
		return false, "Pet not discovered yet."
	end

	if listContains(data.ClaimedIndexPets, petName) then
		return false, "Reward already claimed."
	end

	local reward = IndexRewardConfig.GetReward(pet.Rarity)
	table.insert(data.ClaimedIndexPets, petName)
	PlayerDataService.SyncClaimedIndexPets(player, data.ClaimedIndexPets)
	PlayerDataService.AddCoins(player, reward)
	PlayerDataService.MarkDirty(player)

	IndexService.PushSnapshot(
		player,
		string.format("Claimed %s! +%s$", petName, NumberFormat.FormatCoins(reward))
	)
	return true, nil
end

function IndexService.ClaimMilestone(player: Player, milestoneId: string): (boolean, string?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "Player data not loaded."
	end

	if typeof(milestoneId) ~= "string" or milestoneId == "" then
		return false, "Invalid milestone."
	end

	local def = IndexRewardConfig.GetMilestone(milestoneId)
	if not def then
		return false, "Unknown milestone."
	end

	if typeof(data.ClaimedIndexMilestones) ~= "table" then
		data.ClaimedIndexMilestones = {}
	end

	if listContains(data.ClaimedIndexMilestones, milestoneId) then
		return false, "Milestone already claimed."
	end

	PetConfig.EnsureLoaded(10)
	local percent = IndexService.GetCompletionPercent(data)
	local ready = false

	if def.Kind == "percent" then
		local target = if typeof(def.Target) == "number" then def.Target else 0
		ready = percent >= target
	elseif def.Kind == "rarity" then
		local rarity = if typeof(def.Target) == "string" then def.Target else ""
		local progress, target = getRarityProgress(data, rarity)
		ready = target > 0 and progress >= target
	end

	if not ready then
		return false, "Milestone not reached yet."
	end

	local reward = IndexRewardConfig.GetMilestoneReward(milestoneId)
	table.insert(data.ClaimedIndexMilestones, milestoneId)
	PlayerDataService.SyncClaimedIndexMilestones(player, data.ClaimedIndexMilestones)
	PlayerDataService.AddCoins(player, reward)
	PlayerDataService.MarkDirty(player)

	IndexService.PushSnapshot(
		player,
		string.format("%s! +%s$", def.Label, NumberFormat.FormatCoins(reward))
	)
	return true, nil
end

function IndexService.ClaimAll(player: Player): (boolean, string?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "Player data not loaded."
	end

	PetConfig.EnsureLoaded(10)
	if typeof(data.ClaimedIndexMilestones) ~= "table" then
		data.ClaimedIndexMilestones = {}
	end

	local totalReward = 0
	local claimedCount = 0

	for _, pet in ipairs(PetConfig.Pets) do
		if listContains(data.DiscoveredPets, pet.Name) and not listContains(data.ClaimedIndexPets, pet.Name) then
			local reward = IndexRewardConfig.GetReward(pet.Rarity)
			table.insert(data.ClaimedIndexPets, pet.Name)
			totalReward += reward
			claimedCount += 1
		end
	end

	local percent = IndexService.GetCompletionPercent(data)
	for _, def in ipairs(IndexRewardConfig.GetAllMilestones()) do
		if listContains(data.ClaimedIndexMilestones, def.Id) then
			continue
		end

		local ready = false
		if def.Kind == "percent" then
			local target = if typeof(def.Target) == "number" then def.Target else 0
			ready = percent >= target
		elseif def.Kind == "rarity" then
			local rarity = if typeof(def.Target) == "string" then def.Target else ""
			local progress, target = getRarityProgress(data, rarity)
			ready = target > 0 and progress >= target
		end

		if ready then
			local reward = IndexRewardConfig.GetMilestoneReward(def.Id)
			table.insert(data.ClaimedIndexMilestones, def.Id)
			totalReward += reward
			claimedCount += 1
		end
	end

	if claimedCount <= 0 then
		return false, "Nothing to claim."
	end

	PlayerDataService.SyncClaimedIndexPets(player, data.ClaimedIndexPets)
	PlayerDataService.SyncClaimedIndexMilestones(player, data.ClaimedIndexMilestones)
	PlayerDataService.AddCoins(player, totalReward)
	PlayerDataService.MarkDirty(player)

	IndexService.PushSnapshot(
		player,
		string.format("Claimed %d rewards! +%s$", claimedCount, NumberFormat.FormatCoins(totalReward))
	)
	return true, nil
end

return IndexService
