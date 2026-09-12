--!strict

--[[
	Live player luck (same product as a throw, without the skill bar).
	Sources: upgrade, bait, goals buff, companion, cave/VIP/map zone, world event, potion, gifts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaitConfig = require(script.Parent:WaitForChild("BaitConfig"))

local HudLuck = {}

HudLuck.CaveAttribute = "HudCaveLuckMult"

local function readMult(player: Player, attrName: string): number
	local value = player:GetAttribute(attrName)
	if typeof(value) == "number" and value > 0 then
		return value
	end
	return 1
end

function HudLuck.GetBaitLuck(player: Player, override: number?): number
	if typeof(override) == "number" and override > 0 then
		return override
	end
	local baitId = player:GetAttribute("ActiveBait")
	if typeof(baitId) == "string" then
		local luck = BaitConfig.GetLuckMultiplier(baitId)
		if luck > 0 then
			return luck
		end
	end
	return 1
end

function HudLuck.GetGoalsBuffLuck(player: Player): number
	local catches = player:GetAttribute("LuckBuffCatches")
	if typeof(catches) ~= "number" or catches <= 0 then
		return 1
	end
	return math.max(1, readMult(player, "LuckBuffMult"))
end

function HudLuck.GetEventLuck(): number
	local folder = ReplicatedStorage:FindFirstChild("WorldEventState")
	if not folder or not folder:IsA("Folder") then
		return 1
	end
	local active = folder:FindFirstChild("Active")
	local luck = folder:FindFirstChild("LuckMult")
	if active and active:IsA("BoolValue") and active.Value and luck and luck:IsA("NumberValue") then
		return math.max(1, luck.Value)
	end
	return 1
end

function HudLuck.GetTotal(player: Player, baitLuckOverride: number?): number
	return readMult(player, "LuckBonus")
		* HudLuck.GetBaitLuck(player, baitLuckOverride)
		* HudLuck.GetGoalsBuffLuck(player)
		* readMult(player, "CompanionLuckMult")
		* readMult(player, HudLuck.CaveAttribute)
		* HudLuck.GetEventLuck()
		* readMult(player, "PotionLuckMult")
		* readMult(player, "GiftLuck")
end

function HudLuck.Connect(player: Player, onChanged: () -> ())
	local attrs = {
		"LuckBonus",
		"ActiveBait",
		"LuckBuffCatches",
		"LuckBuffMult",
		"CompanionLuckMult",
		HudLuck.CaveAttribute,
		"PotionLuckMult",
		"GiftLuck",
		"VipAccess",
	}
	for _, name in ipairs(attrs) do
		player:GetAttributeChangedSignal(name):Connect(onChanged)
	end

	local function bindFolder(folder: Folder)
		local function bindValue(child: Instance)
			if child:IsA("ValueBase") and (child.Name == "Active" or child.Name == "LuckMult") then
				child:GetPropertyChangedSignal("Value"):Connect(onChanged)
			end
		end
		folder.ChildAdded:Connect(bindValue)
		for _, child in ipairs(folder:GetChildren()) do
			bindValue(child)
		end
		onChanged()
	end

	local existing = ReplicatedStorage:FindFirstChild("WorldEventState")
	if existing and existing:IsA("Folder") then
		bindFolder(existing)
	end
	ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == "WorldEventState" and child:IsA("Folder") then
			bindFolder(child)
		end
	end)
end

return HudLuck
