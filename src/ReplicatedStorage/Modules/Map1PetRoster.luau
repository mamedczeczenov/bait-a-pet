--!strict

-- Thin alias — canonical roster lives in PetConfig.Map1Roster.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PetConfig"))

local Map1PetRoster = {}

Map1PetRoster.Names = PetConfig.Map1Roster

function Map1PetRoster.GetNames(): { string }
	return PetConfig.GetMap1Roster()
end

function Map1PetRoster.IsEnabled(): boolean
	return #PetConfig.Map1Roster > 0
end

return Map1PetRoster
