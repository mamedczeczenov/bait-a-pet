--!strict

local Players = game:GetService("Players")
local TutorialConfig = require(script.Parent:WaitForChild("TutorialConfig"))

local TutorialGate = {}

local hintHandler: ((string) -> ())? = nil

function TutorialGate.SetHintHandler(handler: (string) -> ())
	hintHandler = handler
end

function TutorialGate.ShowHint(message: string)
	if hintHandler then
		hintHandler(message)
	end
end

function TutorialGate.IsActive(player: Player?): boolean
	local target = player or Players.LocalPlayer
	if not target then
		return false
	end
	return target:GetAttribute("TutorialActive") == true
end

function TutorialGate.GetStep(player: Player?): number
	local target = player or Players.LocalPlayer
	if not target then
		return 0
	end
	local step = target:GetAttribute("TutorialStep")
	if typeof(step) == "number" then
		return math.floor(step)
	end
	return 0
end

function TutorialGate.IsCompleted(player: Player?): boolean
	local target = player or Players.LocalPlayer
	if not target then
		return false
	end
	return target:GetAttribute("TutorialCompleted") == true
end

function TutorialGate.IsActionAllowed(actionId: string, player: Player?): boolean
	local target = player or Players.LocalPlayer
	if not target or not TutorialGate.IsActive(target) then
		return true
	end

	local step = TutorialConfig.GetStep(TutorialGate.GetStep(target))
	if not step then
		return true
	end

	return step.AllowedActions[actionId] == true
end

-- Returns true when the action may proceed.
function TutorialGate.TryAction(actionId: string, player: Player?): boolean
	local target = player or Players.LocalPlayer
	if TutorialGate.IsActionAllowed(actionId, target) then
		return true
	end

	local step = TutorialConfig.GetStep(TutorialGate.GetStep(target))
	local hint = if step then step.SoftLockHint else "Finish the current guide step first."
	TutorialGate.ShowHint(hint)
	return false
end

return TutorialGate
