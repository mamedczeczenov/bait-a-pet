--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GoalConfig = require(Modules:WaitForChild("GoalConfig"))
local NumberFormat = require(Modules:WaitForChild("NumberFormat"))
local PetConfig = require(Modules:WaitForChild("PetConfig"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local GoalService = {}

local remote: RemoteEvent? = nil

local function getRemote(): RemoteEvent
	if remote and remote.Parent then
		return remote
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local existing = remotes:FindFirstChild("Goals")
	if existing and existing:IsA("RemoteEvent") then
		remote = existing
		return existing
	end

	local created = Instance.new("RemoteEvent")
	created.Name = "Goals"
	created.Parent = remotes
	remote = created
	return created
end

local function rarityMeetsOrBeats(caughtRarity: string, requiredRarity: string): boolean
	local caughtIndex = table.find(PetConfig.RarityOrder, caughtRarity)
	local requiredIndex = table.find(PetConfig.RarityOrder, requiredRarity)
	if typeof(caughtIndex) ~= "number" or typeof(requiredIndex) ~= "number" then
		return caughtRarity == requiredRarity
	end
	return caughtIndex >= requiredIndex
end

local function cloneGoals(goals: { GoalConfig.GoalInstance }): { GoalConfig.GoalInstance }
	local copy = {}
	for _, goal in ipairs(goals) do
		table.insert(copy, {
			Uid = goal.Uid,
			TemplateId = goal.TemplateId,
			Progress = goal.Progress,
			ReadyToClaim = goal.ReadyToClaim,
		})
	end
	return copy
end

local function fireSnapshot(player: Player, message: string?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end

	local payloadGoals = {}
	for _, goal in ipairs(data.Goals) do
		local template = GoalConfig.GetTemplate(goal.TemplateId)
		if template then
			table.insert(payloadGoals, {
				Uid = goal.Uid,
				TemplateId = goal.TemplateId,
				Kind = template.Kind,
				Title = template.Title,
				Description = template.Description,
				Progress = goal.Progress,
				Target = template.Target,
				TargetRarity = template.TargetRarity,
				ReadyToClaim = goal.ReadyToClaim,
				RewardCoins = template.RewardCoins,
				BuffCatches = template.BuffCatches,
				BuffMult = template.BuffMult,
				Difficulty = template.Difficulty,
			})
		end
	end

	getRemote():FireClient(player, {
		Type = "Snapshot",
		Message = message,
		Goals = payloadGoals,
		LuckBuffCatches = data.LuckBuffCatches,
		LuckBuffMult = data.LuckBuffMult,
		IntroHint = false,
	})
end

function GoalService.EnsureRemote(): RemoteEvent
	return getRemote()
end

function GoalService.SyncAttributes(player: Player)
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end
	player:SetAttribute("LuckBuffCatches", data.LuckBuffCatches)
	player:SetAttribute("LuckBuffMult", data.LuckBuffMult)
end

local function usedTemplateIds(goals: { GoalConfig.GoalInstance }): { [string]: boolean }
	local used = {}
	for _, goal in ipairs(goals) do
		used[goal.TemplateId] = true
	end
	return used
end

local function pickTemplate(used: { [string]: boolean }, preferredDifficulty: string?): GoalConfig.GoalTemplate?
	local function pickFrom(list: { GoalConfig.GoalTemplate }): GoalConfig.GoalTemplate?
		local candidates = {}
		for _, template in ipairs(list) do
			if not used[template.Id] then
				table.insert(candidates, template)
			end
		end
		if #candidates == 0 then
			return nil
		end
		return candidates[math.random(1, #candidates)]
	end

	if preferredDifficulty then
		local preferred = pickFrom(GoalConfig.GetTemplatesByDifficulty(preferredDifficulty))
		if preferred then
			return preferred
		end
	end

	local all = pickFrom(GoalConfig.Templates)
	if all then
		return all
	end

	-- All templates already used; allow repeats.
	return GoalConfig.Templates[math.random(1, #GoalConfig.Templates)]
end

local function makeGoal(template: GoalConfig.GoalTemplate): GoalConfig.GoalInstance
	return {
		Uid = HttpService:GenerateGUID(false),
		TemplateId = template.Id,
		Progress = 0,
		ReadyToClaim = false,
	}
end

function GoalService.EnsureGoals(player: Player): boolean
	local data = PlayerDataService.GetData(player)
	if not data then
		return false
	end

	local changed = false
	while #data.Goals < GoalConfig.ActiveSlots do
		local used = usedTemplateIds(data.Goals)
		local difficulty = if #data.Goals < 2 then "easy" else "hard"
		-- Slot mix: 2 easier-ish, 1 harder for a fresh set.
		if #data.Goals == 0 then
			difficulty = "easy"
		elseif #data.Goals == 1 then
			difficulty = if math.random() < 0.55 then "easy" else "medium"
		else
			difficulty = if math.random() < 0.55 then "hard" else "medium"
		end

		local template = pickTemplate(used, difficulty)
		if not template then
			break
		end
		table.insert(data.Goals, makeGoal(template))
		changed = true
	end

	if changed then
		PlayerDataService.MarkDirty(player)
	end
	return changed
end

local function bumpGoal(goal: GoalConfig.GoalInstance, amount: number, template: GoalConfig.GoalTemplate): boolean
	if goal.ReadyToClaim then
		return false
	end

	local before = goal.Progress
	goal.Progress = math.min(template.Target, goal.Progress + amount)
	if goal.Progress >= template.Target then
		goal.ReadyToClaim = true
	end
	return goal.Progress ~= before
end

function GoalService.PushSnapshot(player: Player, message: string?)
	GoalService.EnsureGoals(player)
	GoalService.SyncAttributes(player)
	fireSnapshot(player, message)
end

function GoalService.SendIntroHint(player: Player)
	local data = PlayerDataService.GetData(player)
	if not data or data.GoalsIntroShown then
		return
	end

	GoalService.EnsureGoals(player)
	data.GoalsIntroShown = true
	PlayerDataService.MarkDirty(player)
	GoalService.SyncAttributes(player)

	local payloadGoals = {}
	for _, goal in ipairs(data.Goals) do
		local template = GoalConfig.GetTemplate(goal.TemplateId)
		if template then
			table.insert(payloadGoals, {
				Uid = goal.Uid,
				TemplateId = goal.TemplateId,
				Kind = template.Kind,
				Title = template.Title,
				Description = template.Description,
				Progress = goal.Progress,
				Target = template.Target,
				TargetRarity = template.TargetRarity,
				ReadyToClaim = goal.ReadyToClaim,
				RewardCoins = template.RewardCoins,
				BuffCatches = template.BuffCatches,
				BuffMult = template.BuffMult,
				Difficulty = template.Difficulty,
			})
		end
	end

	getRemote():FireClient(player, {
		Type = "Snapshot",
		Goals = payloadGoals,
		LuckBuffCatches = data.LuckBuffCatches,
		LuckBuffMult = data.LuckBuffMult,
		IntroHint = true,
		Message = "New goals unlocked! Open Rewards → Goals to claim.",
	})
end

function GoalService.OnTutorialFinished(player: Player)
	GoalService.EnsureGoals(player)
	GoalService.SendIntroHint(player)
end

function GoalService.OnPetCaught(player: Player, rarity: string)
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end

	GoalService.EnsureGoals(player)
	local changed = false

	for _, goal in ipairs(data.Goals) do
		local template = GoalConfig.GetTemplate(goal.TemplateId)
		if template then
			if template.Kind == "CatchCount" then
				if bumpGoal(goal, 1, template) then
					changed = true
				end
			elseif template.Kind == "DiscoverRarity" then
				local required = template.TargetRarity or "Uncommon"
				if rarityMeetsOrBeats(rarity, required) then
					if bumpGoal(goal, 1, template) then
						changed = true
					end
				end
			end
		end
	end

	if changed then
		PlayerDataService.MarkDirty(player)
		GoalService.PushSnapshot(player, nil)
	end
end

function GoalService.OnCoinsEarned(player: Player, amount: number)
	if amount <= 0 then
		return
	end

	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end

	GoalService.EnsureGoals(player)
	local changed = false
	local add = math.floor(amount)

	for _, goal in ipairs(data.Goals) do
		local template = GoalConfig.GetTemplate(goal.TemplateId)
		if template and template.Kind == "EarnCoins" then
			if bumpGoal(goal, add, template) then
				changed = true
			end
		end
	end

	if changed then
		PlayerDataService.MarkDirty(player)
		GoalService.PushSnapshot(player, nil)
	end
end

function GoalService.GetLuckBuffMultiplier(player: Player): number
	local data = PlayerDataService.GetData(player)
	if not data then
		return 1
	end
	if data.LuckBuffCatches <= 0 then
		return 1
	end
	return math.max(1, data.LuckBuffMult)
end

function GoalService.ConsumeLuckBuffCatch(player: Player)
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end
	if data.LuckBuffCatches <= 0 then
		return
	end

	data.LuckBuffCatches -= 1
	if data.LuckBuffCatches <= 0 then
		data.LuckBuffCatches = 0
		data.LuckBuffMult = 1
	end
	PlayerDataService.MarkDirty(player)
	GoalService.SyncAttributes(player)
end

function GoalService.Claim(player: Player, goalUid: string): (boolean, string?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "Still loading..."
	end

	GoalService.EnsureGoals(player)

	local index: number? = nil
	local goal: GoalConfig.GoalInstance? = nil
	for i, entry in ipairs(data.Goals) do
		if entry.Uid == goalUid then
			index = i
			goal = entry
			break
		end
	end

	if not goal or not index then
		return false, "Goal not found."
	end
	if not goal.ReadyToClaim then
		return false, "Goal is not ready to claim."
	end

	local template = GoalConfig.GetTemplate(goal.TemplateId)
	if not template then
		return false, "Unknown goal."
	end

	PlayerDataService.AddCoins(player, template.RewardCoins)
	-- Don't count goal reward toward EarnCoins goals (avoid feedback loops) — AddCoins hooks separately; we'll skip via flag or call internal.

	if template.BuffCatches > 0 then
		-- Refresh / stack remaining catches; keep the stronger mult.
		data.LuckBuffCatches += template.BuffCatches
		data.LuckBuffMult = math.max(data.LuckBuffMult, template.BuffMult)
	end

	local used = usedTemplateIds(data.Goals)
	used[goal.TemplateId] = true
	local replacement = pickTemplate(used, template.Difficulty)
	if not replacement then
		replacement = GoalConfig.Templates[math.random(1, #GoalConfig.Templates)]
	end

	data.Goals[index] = makeGoal(replacement)
	PlayerDataService.MarkDirty(player)
	GoalService.SyncAttributes(player)
	GoalService.PushSnapshot(
		player,
		string.format("Claimed +%s coins%s", NumberFormat.FormatCoins(template.RewardCoins), if template.BuffCatches > 0 then string.format(" and %.0f%% luck for %d catches!", (template.BuffMult - 1) * 100, template.BuffCatches) else "!")
	)
	return true, nil
end

function GoalService.ClaimAll(player: Player): (boolean, string?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "Still loading..."
	end

	GoalService.EnsureGoals(player)

	local readyIndices: { number } = {}
	for i, goal in ipairs(data.Goals) do
		if goal.ReadyToClaim then
			table.insert(readyIndices, i)
		end
	end

	if #readyIndices <= 0 then
		return false, "Nothing to claim."
	end

	local totalCoins = 0
	local claimedCount = 0
	local buffParts: { string } = {}

	-- Process high→low so earlier indices stay valid while replacing slots.
	table.sort(readyIndices, function(a, b)
		return a > b
	end)

	for _, index in ipairs(readyIndices) do
		local goal = data.Goals[index]
		if not goal or not goal.ReadyToClaim then
			continue
		end

		local template = GoalConfig.GetTemplate(goal.TemplateId)
		if not template then
			continue
		end

		PlayerDataService.AddCoins(player, template.RewardCoins)
		totalCoins += template.RewardCoins
		claimedCount += 1

		if template.BuffCatches > 0 then
			data.LuckBuffCatches += template.BuffCatches
			data.LuckBuffMult = math.max(data.LuckBuffMult, template.BuffMult)
			table.insert(
				buffParts,
				string.format("%.0f%%×%d", (template.BuffMult - 1) * 100, template.BuffCatches)
			)
		end

		local used = usedTemplateIds(data.Goals)
		used[goal.TemplateId] = true
		local replacement = pickTemplate(used, template.Difficulty)
		if not replacement then
			replacement = GoalConfig.Templates[math.random(1, #GoalConfig.Templates)]
		end
		data.Goals[index] = makeGoal(replacement)
	end

	if claimedCount <= 0 then
		return false, "Nothing to claim."
	end

	PlayerDataService.MarkDirty(player)
	GoalService.SyncAttributes(player)

	local message = string.format("Claimed %d goals! +%s$", claimedCount, NumberFormat.FormatCoins(totalCoins))
	if #buffParts > 0 then
		message ..= " + luck buff"
	end
	GoalService.PushSnapshot(player, message)
	return true, nil
end

-- Sanitize helpers used by PlayerDataService
function GoalService.SanitizeGoals(raw: any): { GoalConfig.GoalInstance }
	local goals = {}
	if typeof(raw) ~= "table" then
		return goals
	end

	for _, entry in ipairs(raw) do
		if typeof(entry) == "table" and typeof(entry.TemplateId) == "string" and GoalConfig.GetTemplate(entry.TemplateId) then
			local template = GoalConfig.GetTemplate(entry.TemplateId) :: GoalConfig.GoalTemplate
			local progress = if typeof(entry.Progress) == "number" then math.max(0, math.floor(entry.Progress)) else 0
			progress = math.min(template.Target, progress)
			local ready = entry.ReadyToClaim == true or progress >= template.Target
			table.insert(goals, {
				Uid = if typeof(entry.Uid) == "string" and entry.Uid ~= "" then entry.Uid else HttpService:GenerateGUID(false),
				TemplateId = entry.TemplateId,
				Progress = progress,
				ReadyToClaim = ready,
			})
		end
		if #goals >= GoalConfig.ActiveSlots then
			break
		end
	end

	return goals
end

function GoalService.CloneGoalsForSave(goals: { GoalConfig.GoalInstance }): { GoalConfig.GoalInstance }
	return cloneGoals(goals)
end

return GoalService
