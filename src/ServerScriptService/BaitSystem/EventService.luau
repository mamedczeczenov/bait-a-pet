--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local EventConfig = require(Modules:WaitForChild("EventConfig"))

local EventService = {}

export type ActiveEvent = {
	Id: string,
	Name: string,
	Description: string,
	Icon: string,
	EndsAt: number,
	LuckMult: number,
	SellMult: number,
	TagId: string?,
	Color: { R: number, G: number, B: number },
}

export type UpcomingEvent = {
	Id: string,
	Name: string,
	Description: string,
	Icon: string,
	StartsAt: number,
	LuckMult: number,
	SellMult: number,
	TagId: string?,
}

local remote: RemoteEvent? = nil
local active: ActiveEvent? = nil
local upcoming: UpcomingEvent? = nil
local lastEventId: string? = nil
local stateFolder: Folder? = nil

local function getRemote(): RemoteEvent
	if remote and remote.Parent then
		return remote
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local existing = remotes:FindFirstChild("WorldEvent")
	if existing and existing:IsA("RemoteEvent") then
		remote = existing
		return existing
	end

	local created = Instance.new("RemoteEvent")
	created.Name = "WorldEvent"
	created.Parent = remotes
	remote = created
	return created
end

local function ensureStateFolder(): Folder
	if stateFolder and stateFolder.Parent then
		return stateFolder
	end

	local existing = ReplicatedStorage:FindFirstChild("WorldEventState")
	if existing and existing:IsA("Folder") then
		stateFolder = existing
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = "WorldEventState"
	folder.Parent = ReplicatedStorage
	stateFolder = folder
	return folder
end

local function setValue(parent: Instance, className: string, name: string, value: any)
	local child = parent:FindFirstChild(name)
	if not child or child.ClassName ~= className then
		if child then
			child:Destroy()
		end
		child = Instance.new(className)
		child.Name = name
		child.Parent = parent
	end
	(child :: any).Value = value
end

local function colorPayload(color: Color3): { R: number, G: number, B: number }
	return {
		R = color.R,
		G = color.G,
		B = color.B,
	}
end

local function upcomingFromDefinition(def: EventConfig.EventDefinition, startsAt: number): UpcomingEvent
	return {
		Id = def.Id,
		Name = def.Name,
		Description = def.Description,
		Icon = def.Icon,
		StartsAt = startsAt,
		LuckMult = def.LuckMult,
		SellMult = def.SellMult,
		TagId = def.TagId,
	}
end

local function upcomingPayloadFields(): { [string]: any }
	local nextEvent = upcoming
	if not nextEvent then
		return {
			NextId = "",
			NextName = "",
			NextDescription = "",
			NextIcon = "",
			NextStartsAt = 0,
			NextLuckMult = 1,
			NextSellMult = 1,
			NextTagId = "",
		}
	end

	return {
		NextId = nextEvent.Id,
		NextName = nextEvent.Name,
		NextDescription = nextEvent.Description,
		NextIcon = nextEvent.Icon,
		NextStartsAt = nextEvent.StartsAt,
		NextLuckMult = nextEvent.LuckMult,
		NextSellMult = nextEvent.SellMult,
		NextTagId = nextEvent.TagId or "",
	}
end

local function syncStateFolder()
	local folder = ensureStateFolder()
	local current = active
	if not current then
		setValue(folder, "BoolValue", "Active", false)
		setValue(folder, "StringValue", "Id", "")
		setValue(folder, "StringValue", "Name", "")
		setValue(folder, "StringValue", "Description", "")
		setValue(folder, "StringValue", "Icon", "")
		setValue(folder, "StringValue", "TagId", "")
		setValue(folder, "NumberValue", "EndsAt", 0)
		setValue(folder, "NumberValue", "LuckMult", 1)
		setValue(folder, "NumberValue", "SellMult", 1)
	else
		setValue(folder, "BoolValue", "Active", true)
		setValue(folder, "StringValue", "Id", current.Id)
		setValue(folder, "StringValue", "Name", current.Name)
		setValue(folder, "StringValue", "Description", current.Description)
		setValue(folder, "StringValue", "Icon", current.Icon)
		setValue(folder, "StringValue", "TagId", current.TagId or "")
		setValue(folder, "NumberValue", "EndsAt", current.EndsAt)
		setValue(folder, "NumberValue", "LuckMult", current.LuckMult)
		setValue(folder, "NumberValue", "SellMult", current.SellMult)
	end

	local nextEvent = upcoming
	if not nextEvent then
		setValue(folder, "StringValue", "NextId", "")
		setValue(folder, "StringValue", "NextName", "")
		setValue(folder, "StringValue", "NextDescription", "")
		setValue(folder, "StringValue", "NextIcon", "")
		setValue(folder, "StringValue", "NextTagId", "")
		setValue(folder, "NumberValue", "NextStartsAt", 0)
		setValue(folder, "NumberValue", "NextLuckMult", 1)
		setValue(folder, "NumberValue", "NextSellMult", 1)
	else
		setValue(folder, "StringValue", "NextId", nextEvent.Id)
		setValue(folder, "StringValue", "NextName", nextEvent.Name)
		setValue(folder, "StringValue", "NextDescription", nextEvent.Description)
		setValue(folder, "StringValue", "NextIcon", nextEvent.Icon)
		setValue(folder, "StringValue", "NextTagId", nextEvent.TagId or "")
		setValue(folder, "NumberValue", "NextStartsAt", nextEvent.StartsAt)
		setValue(folder, "NumberValue", "NextLuckMult", nextEvent.LuckMult)
		setValue(folder, "NumberValue", "NextSellMult", nextEvent.SellMult)
	end
end

local function mergePayload(base: { [string]: any }): { [string]: any }
	for key, value in pairs(upcomingPayloadFields()) do
		base[key] = value
	end
	return base
end

local function buildPayload(message: string?): { [string]: any }
	local current = active
	if not current then
		return mergePayload({
			Type = "Snapshot",
			Active = false,
			Message = message,
		})
	end

	return mergePayload({
		Type = "Snapshot",
		Active = true,
		Message = message,
		Id = current.Id,
		Name = current.Name,
		Description = current.Description,
		Icon = current.Icon,
		EndsAt = current.EndsAt,
		LuckMult = current.LuckMult,
		SellMult = current.SellMult,
		TagId = current.TagId,
		Color = current.Color,
	})
end

function EventService.EnsureRemote(): RemoteEvent
	return getRemote()
end

function EventService.GetActive(): ActiveEvent?
	local current = active
	if not current then
		return nil
	end
	if Workspace:GetServerTimeNow() >= current.EndsAt then
		return nil
	end
	return current
end

function EventService.GetUpcoming(): UpcomingEvent?
	return upcoming
end

function EventService.IsActive(): boolean
	return EventService.GetActive() ~= nil
end

function EventService.GetLuckMultiplier(): number
	local current = EventService.GetActive()
	if not current then
		return 1
	end
	return math.max(1, current.LuckMult)
end

function EventService.GetSellMultiplier(): number
	local current = EventService.GetActive()
	if not current then
		return 1
	end
	return math.max(1, current.SellMult)
end

function EventService.GetCatchTag(): string?
	local current = EventService.GetActive()
	if not current then
		return nil
	end
	if typeof(current.TagId) == "string" and current.TagId ~= "" then
		return current.TagId
	end
	return nil
end

function EventService.GetTagSellMultiplier(tagId: string?): number
	return EventConfig.GetTagSellMultiplier(tagId)
end

function EventService.PushSnapshot(player: Player?, message: string?)
	local payload = buildPayload(message)
	local eventRemote = getRemote()
	if player then
		eventRemote:FireClient(player, payload)
	else
		eventRemote:FireAllClients(payload)
	end
end

function EventService.SetUpcoming(eventId: string, startsAt: number, announce: boolean?): boolean
	local def = EventConfig.GetById(eventId)
	if not def then
		return false
	end

	upcoming = upcomingFromDefinition(def, startsAt)
	syncStateFolder()

	local payload = mergePayload({
		Type = "Upcoming",
		Active = EventService.IsActive(),
		Message = if announce == false
			then nil
			else string.format("Next: %s %s", def.Icon, def.Name),
	})

	-- Keep active event fields if one is running.
	local current = active
	if current then
		payload.Active = true
		payload.Id = current.Id
		payload.Name = current.Name
		payload.Description = current.Description
		payload.Icon = current.Icon
		payload.EndsAt = current.EndsAt
		payload.LuckMult = current.LuckMult
		payload.SellMult = current.SellMult
		payload.TagId = current.TagId
		payload.Color = current.Color
	end

	getRemote():FireAllClients(payload)
	return true
end

function EventService.ClearUpcoming()
	upcoming = nil
	syncStateFolder()
end

function EventService.Start(eventId: string): boolean
	local def = EventConfig.GetById(eventId)
	if not def then
		return false
	end

	upcoming = nil
	local endsAt = Workspace:GetServerTimeNow() + def.DurationSeconds
	active = {
		Id = def.Id,
		Name = def.Name,
		Description = def.Description,
		Icon = def.Icon,
		EndsAt = endsAt,
		LuckMult = def.LuckMult,
		SellMult = def.SellMult,
		TagId = def.TagId,
		Color = colorPayload(def.Color),
	}
	lastEventId = def.Id
	syncStateFolder()

	local announce = string.format("%s %s — %s", def.Icon, def.Name, def.Description)
	getRemote():FireAllClients(mergePayload({
		Type = "Started",
		Active = true,
		Message = announce,
		Id = def.Id,
		Name = def.Name,
		Description = def.Description,
		Icon = def.Icon,
		EndsAt = endsAt,
		LuckMult = def.LuckMult,
		SellMult = def.SellMult,
		TagId = def.TagId,
		Color = colorPayload(def.Color),
	}))

	return true
end

function EventService.Stop(message: string?)
	local endedName = if active then active.Name else nil
	active = nil
	syncStateFolder()

	getRemote():FireAllClients(mergePayload({
		Type = "Ended",
		Active = false,
		Message = message or (if endedName then string.format("%s ended.", endedName) else nil),
	}))
end

function EventService.GetLastEventId(): string?
	return lastEventId
end

function EventService.PickNext(): EventConfig.EventDefinition
	return EventConfig.PickWeighted(lastEventId)
end

-- Initialize empty replicated state for late joiners.
ensureStateFolder()
syncStateFolder()

return EventService
