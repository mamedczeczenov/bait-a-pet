--!strict

--[[
	Client-only UI SFX helper.
	Uses rbxasset:// engine sounds so playback does not depend on Creator Store permissions.
]]

local SoundService = game:GetService("SoundService")

local FeelSound = {}

-- Built-in engine assets — always playable without inventory grants.
local BUILTIN: { [string]: string } = {
	Sell = "rbxasset://sounds/electronicpingshort.wav",
	Buy = "rbxasset://sounds/button.wav",
	Error = "rbxasset://sounds/switch.wav",
	Click = "rbxasset://sounds/switch.wav",
}

local folder: Folder? = nil

local function getFolder(): Folder
	local existing = folder
	if existing and existing.Parent then
		return existing
	end

	local created = Instance.new("Folder")
	created.Name = "FeelSounds"
	created.Parent = SoundService
	folder = created
	return created
end

function FeelSound.Play(soundKey: string, volume: number?)
	local soundId = BUILTIN[soundKey]
	if typeof(soundId) ~= "string" then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = soundKey
	sound.SoundId = soundId
	sound.Volume = volume or 0.6
	sound.PlaybackSpeed = 1
	sound.Parent = getFolder()

	-- PlayLocalSound is reliable for UI feedback on the client.
	SoundService:PlayLocalSound(sound)

	task.delay(4, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

return FeelSound
