--!strict

--[[
	AFK place loop: virtual cave sell → coins, independent potion rolls, AFK pets.
	Idle rejoin keeps the player on this place until they leave.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local AfkConfig = require(Modules:WaitForChild("AfkConfig"))
local AfkPetConfig = require(Modules:WaitForChild("AfkPetConfig"))
local BaitConfig = require(Modules:WaitForChild("BaitConfig"))
local PlaceConfig = require(Modules:WaitForChild("PlaceConfig"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local PetService = require(script.Parent:WaitForChild("PetService"))
local PetCatalogService = require(script.Parent:WaitForChild("PetCatalogService"))
local PotionService = require(script.Parent:WaitForChild("PotionService"))
local GoalService = require(script.Parent:WaitForChild("GoalService"))
local GiftService = require(script.Parent:WaitForChild("GiftService"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local afkTickRemote = remotes:WaitForChild("AfkTick") :: RemoteEvent
local petResultRemote = remotes:WaitForChild("PetResult") :: RemoteEvent

type Drop = {
	Type: string,
	Text: string,
	Amount: number?,
}

local running: { [Player]: boolean } = {}
local sessionCoins: { [Player]: number } = {}
local nextRollAt: { [Player]: number } = {}
local rejoinStarted: { [Player]: boolean } = {}

local function getAfkLuck(player: Player): number
	local baitId = PlayerDataService.GetActiveBaitId(player)
	local bait = BaitConfig.GetById(baitId)
	local baitLuck = if bait then bait.LuckMultiplier else 1
	return AfkConfig.GetLuck(baitLuck, PlayerDataService.GetLuckBonus(player), GiftService.GetLuckMultiplier(player))
end

local function getCoins(player: Player): number
	local coins = player:GetAttribute("Coins")
	if typeof(coins) == "number" then
		return math.max(0, math.floor(coins))
	end
	local data = PlayerDataService.GetData(player)
	if data then
		return data.Coins
	end
	return 0
end

local function bagCount(player: Player): number
	local data = PlayerDataService.GetData(player)
	if not data then
		return 0
	end
	return #(data.AfkPets or {})
end

local function buildPayload(player: Player, kind: string, drops: { Drop }?): { [string]: any }
	local luck = getAfkLuck(player)
	return {
		Kind = kind,
		Coins = getCoins(player),
		SessionCoins = sessionCoins[player] or 0,
		NextRollAt = nextRollAt[player] or (Workspace:GetServerTimeNow() + AfkConfig.ThrowInterval),
		Interval = AfkConfig.ThrowInterval,
		AfkLuck = luck,
		PetChance = AfkConfig.GetPetDropChance(luck),
		TrophyChance = AfkConfig.GetTrophyChance(luck),
		PotionLuckChance = AfkConfig.PotionLuckChance,
		PotionSellChance = AfkConfig.PotionSellChance,
		BagCount = bagCount(player),
		BagCapacity = AfkConfig.BagCapacity,
		Drops = drops,
	}
end

local function fireState(player: Player, kind: string, drops: { Drop }?)
	if not player.Parent then
		return
	end
	afkTickRemote:FireClient(player, buildPayload(player, kind, drops))
end

local function freezeCharacter(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
end

local function addAfkPet(player: Player, petId: string): (boolean, string?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "Still loading..."
	end
	if not data.AfkPets then
		data.AfkPets = {}
	end
	if not data.AfkDiscovered then
		data.AfkDiscovered = {}
	end
	if #data.AfkPets >= AfkConfig.BagCapacity then
		return false, AfkConfig.BagFullMessage
	end
	table.insert(data.AfkPets, petId)
	local known = false
	for _, id in ipairs(data.AfkDiscovered) do
		if id == petId then
			known = true
			break
		end
	end
	if not known then
		table.insert(data.AfkDiscovered, petId)
	end
	PlayerDataService.MarkDirty(player)
	return true, nil
end

local function resolveTick(player: Player)
	if not PlayerDataService.IsLoaded(player) then
		return
	end

	PetCatalogService.Initialize()

	local luck = getAfkLuck(player)
	local okRoll, pet = pcall(function()
		return PetService.RollPet(luck, 1)
	end)
	if not okRoll or typeof(pet) ~= "table" then
		warn("[AfkServer] Virtual roll failed:", pet)
		return
	end
	local sellPrice = math.max(1, math.floor((pet :: any).SellPrice or 1))
	PlayerDataService.AddCoins(player, sellPrice)
	GoalService.OnCoinsEarned(player, sellPrice)
	sessionCoins[player] = (sessionCoins[player] or 0) + sellPrice

	local drops: { Drop } = {
		{
			Type = "Coins",
			Text = string.format("+%d coins", sellPrice),
			Amount = sellPrice,
		},
	}

	if math.random() <= AfkConfig.PotionLuckChance then
		local ok = PotionService.AddOwned(player, "luck", 1)
		if ok then
			table.insert(drops, {
				Type = "Potion",
				Text = "Luck Potion +1",
			})
		end
	end
	if math.random() <= AfkConfig.PotionSellChance then
		local ok = PotionService.AddOwned(player, "sell", 1)
		if ok then
			table.insert(drops, {
				Type = "Potion",
				Text = "Sell Potion +1",
			})
		end
	end

	if math.random() <= AfkConfig.GetPetDropChance(luck) then
		local afkPet = AfkPetConfig.RollWeighted()
		local ok, err = addAfkPet(player, afkPet.Id)
		if ok then
			table.insert(drops, {
				Type = "Pet",
				Text = string.format("%s (%s)", afkPet.Name, afkPet.Rarity),
			})
		else
			table.insert(drops, {
				Type = "Skip",
				Text = err or AfkConfig.BagFullMessage,
			})
		end
	end

	nextRollAt[player] = Workspace:GetServerTimeNow() + AfkConfig.ThrowInterval
	fireState(player, "Tick", drops)
end

local function stopLoop(player: Player)
	running[player] = nil
end

local function startLoop(player: Player)
	if not PlaceConfig.IsAfkPlace() then
		return
	end
	if running[player] then
		fireState(player, "State")
		return
	end

	running[player] = true
	sessionCoins[player] = sessionCoins[player] or 0
	nextRollAt[player] = Workspace:GetServerTimeNow() + AfkConfig.ThrowInterval
	PlayerDataService.SetAfkThrow(player, true)
	PetCatalogService.Initialize()
	fireState(player, "State")

	task.spawn(function()
		while running[player] and player.Parent and PlaceConfig.IsAfkPlace() do
			local remaining = (nextRollAt[player] or 0) - Workspace:GetServerTimeNow()
			if remaining > 0 then
				task.wait(math.min(remaining, 0.5))
				continue
			end
			if not running[player] or not player.Parent then
				break
			end
			resolveTick(player)
			if (nextRollAt[player] or 0) <= Workspace:GetServerTimeNow() then
				nextRollAt[player] = Workspace:GetServerTimeNow() + AfkConfig.ThrowInterval
			end
		end
		running[player] = nil
	end)
end

local function copyJoinTeleportData(player: Player): { [string]: any }
	local merged: { [string]: any } = {}
	local joinData = player:GetJoinData()
	local previous = joinData.TeleportData
	if typeof(previous) == "table" then
		for key, value in pairs(previous) do
			if typeof(key) == "string" then
				merged[key] = value
			end
		end
	end
	merged.Destination = "afk"
	merged.FromPlaceId = game.PlaceId
	merged.AfkRejoin = true
	GiftService.AttachTeleportData(player, merged)
	return merged
end

local function startRejoinWatch(player: Player)
	if rejoinStarted[player] then
		return
	end
	rejoinStarted[player] = true

	task.spawn(function()
		local startedAt = os.clock()
		while player.Parent and PlaceConfig.IsAfkPlace() do
			if os.clock() - startedAt >= AfkConfig.ReconnectAfter then
				break
			end
			task.wait(5)
		end

		if not player.Parent or not PlaceConfig.IsAfkPlace() then
			return
		end

		if RunService:IsStudio() then
			petResultRemote:FireClient(player, {
				Type = "Error",
				Message = "Studio: AFK rejoin does not run. Test idle reconnect in the Roblox app.",
			})
			return
		end

		PlayerDataService.SetAfkThrow(player, true)
		PlayerDataService.Save(player)

		petResultRemote:FireClient(player, {
			Type = "Error",
			Message = AfkConfig.RejoinMessage,
		})

		local teleportData = copyJoinTeleportData(player)
		local options = Instance.new("TeleportOptions")
		options.ShouldReserveServer = false
		options:SetTeleportData(teleportData)
		pcall(function()
			TeleportService:TeleportAsync(PlaceConfig.AfkPlaceId, { player }, options)
		end)
	end)
end

local function waitLoaded(player: Player): boolean
	local deadline = os.clock() + 25
	while player.Parent and not PlayerDataService.IsLoaded(player) do
		if os.clock() >= deadline then
			return false
		end
		task.wait(0.1)
	end
	return player.Parent ~= nil and PlayerDataService.IsLoaded(player)
end

local function onPlayer(player: Player)
	task.spawn(function()
		if not waitLoaded(player) then
			return
		end

		if PlaceConfig.IsAfkPlace() then
			PlayerDataService.SetAfkThrow(player, true)
			startLoop(player)
			startRejoinWatch(player)
			if player.Character then
				freezeCharacter(player.Character)
			end
			player.CharacterAdded:Connect(function(character)
				task.defer(function()
					freezeCharacter(character)
				end)
			end)
			return
		end

		local data = PlayerDataService.GetData(player)
		if data and data.AfkThrow == true then
			if RunService:IsStudio() then
				return
			end
			PlayerDataService.Save(player)
			local options = Instance.new("TeleportOptions")
			options.ShouldReserveServer = false
			local teleportData = {
				Destination = "afk",
				FromPlaceId = game.PlaceId,
			}
			GiftService.AttachTeleportData(player, teleportData)
			options:SetTeleportData(teleportData)
			pcall(function()
				TeleportService:TeleportAsync(PlaceConfig.AfkPlaceId, { player }, options)
			end)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	stopLoop(player)
	sessionCoins[player] = nil
	nextRollAt[player] = nil
	rejoinStarted[player] = nil
end)
