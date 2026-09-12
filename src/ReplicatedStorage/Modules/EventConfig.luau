--!strict

--[[
	Timed world events. Effects stack as multipliers on catch luck / sell,
	and some events permanently tag pets caught during them.
]]

export type EventDefinition = {
	Id: string,
	Name: string,
	Description: string,
	Icon: string,
	DurationSeconds: number,
	LuckMult: number,
	SellMult: number,
	-- If set, pets caught during the event get this permanent tag.
	TagId: string?,
	TagSellMult: number,
	Color: Color3,
	Weight: number,
}

local EventConfig = {}

EventConfig.FirstDelaySeconds = 75
EventConfig.IdleBetweenMinSeconds = 150
EventConfig.IdleBetweenMaxSeconds = 240

-- Permanent sell bonus for event-tagged pets (after event ends).
EventConfig.TagSellMult = {
	Rainbow = 2,
	Storm = 1.6,
}

EventConfig.Events = {
	{
		Id = "rain",
		Name = "Rain",
		Description = "Soft rain — slightly better luck while it lasts.",
		Icon = "🌧️",
		DurationSeconds = 80,
		LuckMult = 1.5,
		SellMult = 1,
		TagId = nil,
		TagSellMult = 1,
		Color = Color3.fromRGB(110, 150, 200),
		Weight = 1,
	},
	{
		Id = "rainbow",
		Name = "Rainbow",
		Description = "Catch pets with a Rainbow aura — worth more forever.",
		Icon = "🌈",
		DurationSeconds = 70,
		LuckMult = 1,
		SellMult = 1,
		TagId = "Rainbow",
		TagSellMult = 2,
		Color = Color3.fromRGB(255, 140, 200),
		Weight = 1,
	},
	{
		Id = "lucky",
		Name = "Lucky Surge",
		Description = "Huge luck boost — rare rolls are much more likely.",
		Icon = "🍀",
		DurationSeconds = 60,
		LuckMult = 1.8,
		SellMult = 1,
		TagId = nil,
		TagSellMult = 1,
		Color = Color3.fromRGB(80, 200, 110),
		Weight = 1,
	},
	{
		Id = "market",
		Name = "Market Boom",
		Description = "Shop pays more for every pet you sell right now.",
		Icon = "💰",
		DurationSeconds = 75,
		LuckMult = 1,
		SellMult = 2,
		TagId = nil,
		TagSellMult = 1,
		Color = Color3.fromRGB(255, 200, 70),
		Weight = 1,
	},
	{
		Id = "storm",
		Name = "Thunderstorm",
		Description = "Storm luck + Storm-touched pets with a special flare.",
		Icon = "⚡",
		DurationSeconds = 70,
		LuckMult = 1.35,
		SellMult = 1,
		TagId = "Storm",
		TagSellMult = 1.6,
		Color = Color3.fromRGB(140, 110, 255),
		Weight = 1,
	},
} :: { EventDefinition }

local byId: { [string]: EventDefinition } = {}
for _, event in ipairs(EventConfig.Events) do
	byId[event.Id] = event
end

function EventConfig.GetById(eventId: string): EventDefinition?
	return byId[eventId]
end

function EventConfig.GetTagSellMultiplier(tagId: string?): number
	if typeof(tagId) ~= "string" or tagId == "" then
		return 1
	end
	local mult = EventConfig.TagSellMult[tagId]
	if typeof(mult) == "number" and mult > 0 then
		return mult
	end
	return 1
end

function EventConfig.PickWeighted(excludeId: string?): EventDefinition
	local total = 0
	local candidates = {}
	for _, event in ipairs(EventConfig.Events) do
		if event.Id ~= excludeId then
			total += math.max(0, event.Weight)
			table.insert(candidates, event)
		end
	end

	if #candidates == 0 then
		return EventConfig.Events[1]
	end

	if total <= 0 then
		return candidates[math.random(1, #candidates)]
	end

	local roll = math.random() * total
	local acc = 0
	for _, event in ipairs(candidates) do
		acc += math.max(0, event.Weight)
		if roll <= acc then
			return event
		end
	end

	return candidates[#candidates]
end

function EventConfig.RandomIdleSeconds(): number
	local minS = EventConfig.IdleBetweenMinSeconds
	local maxS = EventConfig.IdleBetweenMaxSeconds
	if maxS < minS then
		maxS = minS
	end
	return math.random(minS, maxS)
end

return EventConfig
