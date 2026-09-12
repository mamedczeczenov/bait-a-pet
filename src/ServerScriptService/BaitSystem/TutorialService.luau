--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local NumberFormat = require(Modules:WaitForChild("NumberFormat"))
local TutorialConfig = require(Modules:WaitForChild("TutorialConfig"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local GoalService = require(script.Parent:WaitForChild("GoalService"))

local TutorialService = {}

export type TutorialSession = {
	Active: boolean,
	Step: number,
	IsReplay: boolean,
	StartToken: number,
}

local sessions: { [Player]: TutorialSession } = {}
local remote: RemoteEvent? = nil

local function getRemote(): RemoteEvent
	if remote and remote.Parent then
		return remote
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local existing = remotes:FindFirstChild("Tutorial")
	if existing and existing:IsA("RemoteEvent") then
		remote = existing
		return existing
	end

	local created = Instance.new("RemoteEvent")
	created.Name = "Tutorial"
	created.Parent = remotes
	remote = created
	return created
end

local function getSession(player: Player): TutorialSession
	local session = sessions[player]
	if session then
		return session
	end

	session = {
		Active = false,
		Step = 0,
		IsReplay = false,
		StartToken = 0,
	}
	sessions[player] = session
	return session
end

local function syncAttributes(player: Player, session: TutorialSession)
	player:SetAttribute("TutorialActive", session.Active)
	player:SetAttribute("TutorialStep", if session.Active then session.Step else 0)
	player:SetAttribute("TutorialCompleted", PlayerDataService.IsTutorialCompleted(player))
end

local function fireClient(player: Player, payload: { [string]: any })
	getRemote():FireClient(player, payload)
end

local function buildStepPayload(stepIndex: number): { [string]: any }?
	local step = TutorialConfig.GetStep(stepIndex)
	if not step then
		return nil
	end

	return {
		Type = "Step",
		Step = stepIndex,
		StepCount = TutorialConfig.StepCount,
		Id = step.Id,
		Title = step.Title,
		Body = step.Body,
		Highlight = step.Highlight,
		StuckHint = TutorialConfig.StuckHints[stepIndex],
		StuckHintSeconds = TutorialConfig.StepStuckHintSeconds,
	}
end

local function completeTutorial(player: Player, session: TutorialSession, skipped: boolean)
	session.Active = false
	session.Step = 0
	syncAttributes(player, session)

	local rewardGiven = 0
	if not skipped and not session.IsReplay and not PlayerDataService.HasTutorialRewardClaimed(player) then
		rewardGiven = TutorialConfig.RewardCoins
		PlayerDataService.AddCoins(player, rewardGiven)
		PlayerDataService.MarkTutorialRewardClaimed(player)
	end

	PlayerDataService.SetTutorialCompleted(player, true)
	syncAttributes(player, session)

	fireClient(player, {
		Type = "Complete",
		Skipped = skipped,
		Reward = rewardGiven,
		Message = if skipped then "Guide skipped."
			elseif rewardGiven > 0 then string.format("Guide complete! +%s coins.", NumberFormat.FormatCoins(rewardGiven))
			else "Guide complete.",
	})

	if not skipped then
		GoalService.OnTutorialFinished(player)
	elseif PlayerDataService.IsTutorialCompleted(player) then
		GoalService.EnsureGoals(player)
		GoalService.SendIntroHint(player)
	end
end

function TutorialService.EnsureRemote(): RemoteEvent
	return getRemote()
end

function TutorialService.SyncPlayer(player: Player)
	local session = getSession(player)
	syncAttributes(player, session)
end

function TutorialService.IsActive(player: Player): boolean
	return getSession(player).Active
end

function TutorialService.GetStep(player: Player): number
	return getSession(player).Step
end

function TutorialService.Start(player: Player, isReplay: boolean?)
	if not PlayerDataService.IsLoaded(player) then
		return
	end

	local session = getSession(player)
	session.Active = true
	session.Step = 1
	session.IsReplay = isReplay == true
	session.StartToken += 1
	syncAttributes(player, session)

	local payload = buildStepPayload(1)
	if payload then
		payload.Type = "Start"
		payload.IsReplay = session.IsReplay
		fireClient(player, payload)
	end
end

function TutorialService.Skip(player: Player)
	local session = getSession(player)
	if not session.Active then
		-- Still mark completed so it won't auto-start again.
		PlayerDataService.SetTutorialCompleted(player, true)
		syncAttributes(player, session)
		fireClient(player, {
			Type = "Complete",
			Skipped = true,
			Reward = 0,
			Message = "Guide skipped.",
		})
		GoalService.EnsureGoals(player)
		GoalService.SendIntroHint(player)
		return
	end

	completeTutorial(player, session, true)
end

function TutorialService.Replay(player: Player)
	if not PlayerDataService.IsLoaded(player) then
		return
	end

	TutorialService.Start(player, true)
end

function TutorialService.Reset(player: Player)
	local session = getSession(player)
	session.Active = false
	session.Step = 0
	session.IsReplay = false
	session.StartToken += 1
	PlayerDataService.ResetTutorialProgress(player)
	syncAttributes(player, session)
	fireClient(player, {
		Type = "Reset",
		Message = "Guide progress reset.",
	})
end

function TutorialService.NotifyAction(player: Player, actionId: string)
	local session = getSession(player)
	if not session.Active then
		return
	end

	local step = TutorialConfig.GetStep(session.Step)
	if not step then
		return
	end

	if step.CompleteOn[actionId] ~= true then
		return
	end

	if session.Step >= TutorialConfig.StepCount then
		completeTutorial(player, session, false)
		return
	end

	session.Step += 1
	syncAttributes(player, session)

	if session.Step > TutorialConfig.StepCount then
		completeTutorial(player, session, false)
		return
	end

	local payload = buildStepPayload(session.Step)
	if payload then
		fireClient(player, payload)
	end
end

function TutorialService.ScheduleAutoStart(player: Player)
	if not PlayerDataService.IsLoaded(player) then
		return
	end
	if PlayerDataService.IsTutorialCompleted(player) then
		TutorialService.SyncPlayer(player)
		return
	end

	local session = getSession(player)
	session.StartToken += 1
	local token = session.StartToken

	task.delay(TutorialConfig.StartDelaySeconds, function()
		if not player.Parent then
			return
		end
		if session.StartToken ~= token then
			return
		end
		if session.Active then
			return
		end
		if PlayerDataService.IsTutorialCompleted(player) then
			return
		end
		TutorialService.Start(player, false)
	end)
end

function TutorialService.Cleanup(player: Player)
	sessions[player] = nil
end

function TutorialService.PushState(player: Player)
	local session = getSession(player)
	syncAttributes(player, session)

	if session.Active then
		local payload = buildStepPayload(session.Step)
		if payload then
			payload.Type = "Step"
			payload.IsReplay = session.IsReplay
			fireClient(player, payload)
		end
		return
	end

	fireClient(player, {
		Type = "Idle",
		Completed = PlayerDataService.IsTutorialCompleted(player),
	})
end

return TutorialService
