--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local EventConfig = require(Modules:WaitForChild("EventConfig"))

local EventService = require(script.Parent:WaitForChild("EventService"))

local eventRemote = EventService.EnsureRemote()
local schedulerRunning = false

local function onPlayerReady(player: Player)
	EventService.PushSnapshot(player, nil)
end

eventRemote.OnServerEvent:Connect(function(player, payload)
	if typeof(payload) ~= "table" then
		return
	end
	if payload.Type == "Ready" then
		EventService.PushSnapshot(player, nil)
	end
end)

Players.PlayerAdded:Connect(function(player)
	task.defer(onPlayerReady, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(onPlayerReady, player)
end

local function waitUntil(serverTime: number): boolean
	while Workspace:GetServerTimeNow() < serverTime do
		-- Debug force-start abandons the idle countdown.
		if EventService.IsActive() then
			return false
		end
		task.wait(0.25)
	end
	return true
end

local function scheduleUpcomingAfterCurrent(): (EventConfig.EventDefinition, number)
	local pending = EventService.PickNext()
	local startsAt = Workspace:GetServerTimeNow() + EventConfig.RandomIdleSeconds()
	EventService.SetUpcoming(pending.Id, startsAt, false)
	return pending, startsAt
end

local function waitForActiveEventToEnd()
	while true do
		local active = EventService.GetActive()
		if not active then
			return
		end
		if Workspace:GetServerTimeNow() >= active.EndsAt then
			scheduleUpcomingAfterCurrent()
			EventService.Stop()
			return
		end
		task.wait(0.5)
	end
end

local function runScheduler()
	if schedulerRunning then
		return
	end
	schedulerRunning = true

	local pending = EventService.PickNext()
	local startsAt = Workspace:GetServerTimeNow() + EventConfig.FirstDelaySeconds
	EventService.SetUpcoming(pending.Id, startsAt, false)

	while true do
		local reached = waitUntil(startsAt)
		if reached and not EventService.IsActive() then
			EventService.Start(pending.Id)
		end

		waitForActiveEventToEnd()

		-- If Stop already scheduled upcoming, reuse it; otherwise create one.
		local upcoming = EventService.GetUpcoming()
		if upcoming then
			pending = EventConfig.GetById(upcoming.Id) or EventService.PickNext()
			startsAt = upcoming.StartsAt
		else
			pending, startsAt = scheduleUpcomingAfterCurrent()
			EventService.PushSnapshot(nil, nil)
		end
	end
end

task.spawn(runScheduler)

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if remotes then
	EventService.EnsureRemote()
end
