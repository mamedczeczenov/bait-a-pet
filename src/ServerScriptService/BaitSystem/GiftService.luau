--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GiftConfig = require(Modules:WaitForChild("GiftConfig"))

export type GiftSnapshot = {
	Type: string,
	ServerTime: number,
	Elapsed: number,
	ClaimedTier: number,
	GiftLuck: number,
	HasReady: boolean,
	Gifts: { { [string]: any } },
	Message: string?,
}

type Session = {
	OriginServerTime: number,
	ClaimedTier: number,
}

local GiftService = {}

local sessions: { [Player]: Session } = {}
local remote: RemoteEvent? = nil

local function getRemote(): RemoteEvent
	if remote and remote.Parent then
		return remote
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local existing = remotes:FindFirstChild("Gifts")
	if existing and existing:IsA("RemoteEvent") then
		remote = existing
		return existing
	end

	local created = Instance.new("RemoteEvent")
	created.Name = "Gifts"
	created.Parent = remotes
	remote = created
	return created
end

function GiftService.EnsureRemote(): RemoteEvent
	return getRemote()
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function getElapsed(session: Session): number
	return GiftConfig.ClampElapsed(now() - session.OriginServerTime)
end

local function sanitizeClaimed(elapsed: number, claimedTier: number): number
	local claimed = GiftConfig.ClampTier(claimedTier)
	while claimed > 0 do
		local gift = GiftConfig.Get(claimed)
		if gift and elapsed + 1 >= gift.Seconds then
			break
		end
		claimed -= 1
	end
	return claimed
end

local function readJoinGiftData(player: Player): (number, number)
	local joinData = player:GetJoinData()
	local teleportData = joinData.TeleportData
	if typeof(teleportData) ~= "table" then
		return 0, 0
	end

	local elapsed = GiftConfig.ClampElapsed(teleportData.GiftElapsed)
	local claimed = sanitizeClaimed(elapsed, teleportData.GiftClaimedTier)
	return elapsed, claimed
end

local function ensureSession(player: Player): Session
	local existing = sessions[player]
	if existing then
		return existing
	end

	local elapsed, claimed = readJoinGiftData(player)
	local session: Session = {
		OriginServerTime = now() - elapsed,
		ClaimedTier = claimed,
	}
	sessions[player] = session
	return session
end

function GiftService.GetElapsed(player: Player): number
	return getElapsed(ensureSession(player))
end

function GiftService.GetClaimedTier(player: Player): number
	return ensureSession(player).ClaimedTier
end

function GiftService.GetLuckMultiplier(player: Player): number
	local attr = player:GetAttribute("GiftLuck")
	if typeof(attr) == "number" and attr > 0 then
		return attr
	end
	return GiftConfig.GetLuckForTier(GiftService.GetClaimedTier(player))
end

function GiftService.SyncAttributes(player: Player)
	local session = ensureSession(player)
	local luck = GiftConfig.GetLuckForTier(session.ClaimedTier)
	player:SetAttribute("GiftLuck", luck)
	player:SetAttribute("GiftClaimedTier", session.ClaimedTier)
	player:SetAttribute("GiftHasReady", GiftConfig.HasReady(getElapsed(session), session.ClaimedTier))
end

function GiftService.AttachTeleportData(player: Player, teleportData: { [string]: any })
	local session = ensureSession(player)
	teleportData.GiftElapsed = getElapsed(session)
	teleportData.GiftClaimedTier = session.ClaimedTier
end

function GiftService.StartForPlayer(player: Player)
	ensureSession(player)
	GiftService.SyncAttributes(player)
end

local function buildGifts(elapsed: number, claimedTier: number): { { [string]: any } }
	local list = {}
	for _, gift in ipairs(GiftConfig.Gifts) do
		table.insert(list, {
			Tier = gift.Tier,
			Name = gift.Name,
			Seconds = gift.Seconds,
			Mult = gift.Mult,
			State = GiftConfig.GetState(elapsed, claimedTier, gift.Tier),
			Remaining = GiftConfig.RemainingSeconds(elapsed, claimedTier, gift.Tier),
		})
	end
	return list
end

function GiftService.BuildSnapshot(player: Player, message: string?): GiftSnapshot
	local session = ensureSession(player)
	local elapsed = getElapsed(session)
	local luck = GiftConfig.GetLuckForTier(session.ClaimedTier)
	return {
		Type = "Snapshot",
		ServerTime = now(),
		Elapsed = elapsed,
		ClaimedTier = session.ClaimedTier,
		GiftLuck = luck,
		HasReady = GiftConfig.HasReady(elapsed, session.ClaimedTier),
		Gifts = buildGifts(elapsed, session.ClaimedTier),
		Message = message,
	}
end

function GiftService.PushSnapshot(player: Player, message: string?)
	if not player.Parent then
		return
	end
	GiftService.SyncAttributes(player)
	getRemote():FireClient(player, GiftService.BuildSnapshot(player, message))
end

function GiftService.Claim(player: Player, tier: number): (boolean, string?)
	if typeof(tier) ~= "number" then
		return false, nil
	end

	local session = ensureSession(player)
	local nextTier = session.ClaimedTier + 1
	local want = math.floor(tier)
	if want ~= nextTier then
		return false, nil
	end

	local gift = GiftConfig.Get(nextTier)
	if not gift then
		return false, nil
	end

	local elapsed = getElapsed(session)
	if elapsed < gift.Seconds then
		return false, nil
	end

	session.ClaimedTier = nextTier
	GiftService.SyncAttributes(player)
	GiftService.PushSnapshot(player, string.format("Gift luck %s", GiftConfig.FormatMult(gift.Mult)))
	return true, nil
end

function GiftService.DebugSetElapsed(player: Player, elapsedSeconds: number)
	local session = ensureSession(player)
	session.OriginServerTime = now() - GiftConfig.ClampElapsed(elapsedSeconds)
	session.ClaimedTier = sanitizeClaimed(getElapsed(session), session.ClaimedTier)
	GiftService.PushSnapshot(player)
end

function GiftService.Clear(player: Player)
	sessions[player] = nil
	if player.Parent then
		player:SetAttribute("GiftLuck", 1)
		player:SetAttribute("GiftClaimedTier", 0)
		player:SetAttribute("GiftHasReady", false)
	end
end

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)

return GiftService
