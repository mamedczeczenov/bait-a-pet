--!strict

--[[
	Cross-place teleport IDs for this experience (BAIT A PET!).
	Main: BAIT A PET!  |  Map 2: map 2  |  Map 3: map 3  |  AFK: afk lobby
]]

local PlaceConfig = {}

PlaceConfig.MainPlaceId = 108768626273502
PlaceConfig.Map2PlaceId = 138543380274421
PlaceConfig.Map3PlaceId = 132324141175445
PlaceConfig.AfkPlaceId = 89818308891412
-- Map 3 portal unlock: 50% of Map 2 index (roster may still be empty).
PlaceConfig.Map3IndexUnlockPercent = 50

local MAP_LABELS: { [string]: string } = {
	map1 = "Map 1",
	map2 = "Map 2",
	map3 = "Map 3",
	afk = "AFK",
}

function PlaceConfig.GetCurrentPlaceId(): number
	return game.PlaceId
end

function PlaceConfig.IsMainPlace(): boolean
	return game.PlaceId == PlaceConfig.MainPlaceId
end

function PlaceConfig.IsMap2Place(): boolean
	return game.PlaceId == PlaceConfig.Map2PlaceId
end

function PlaceConfig.IsMap3Place(): boolean
	return PlaceConfig.Map3PlaceId > 0 and game.PlaceId == PlaceConfig.Map3PlaceId
end

function PlaceConfig.IsAfkPlace(): boolean
	return PlaceConfig.AfkPlaceId > 0 and game.PlaceId == PlaceConfig.AfkPlaceId
end

-- Map 1 hub (shop / cave / VIP). AFK / Map 2 / Map 3 are other places.
function PlaceConfig.IsHubPlace(): boolean
	return PlaceConfig.IsMainPlace()
end

function PlaceConfig.GetMapKey(): string
	if PlaceConfig.IsAfkPlace() then
		return "afk"
	end
	if PlaceConfig.IsMap3Place() then
		return "map3"
	end
	if PlaceConfig.IsMap2Place() then
		return "map2"
	end
	return "map1"
end

function PlaceConfig.GetMapLabel(mapKey: string): string
	return MAP_LABELS[string.lower(mapKey)] or mapKey
end

-- Portal on each playable map offers the other two maps.
function PlaceConfig.GetPortalChoices(): { string }
	local map = PlaceConfig.GetMapKey()
	if map == "map1" then
		return { "map2", "map3" }
	end
	if map == "map2" then
		return { "map1", "map3" }
	end
	if map == "map3" then
		return { "map1", "map2" }
	end
	return {}
end

function PlaceConfig.GetPlaceIdForDestination(destinationId: string): number?
	local id = string.lower(destinationId)
	if id == "map1" then
		return PlaceConfig.MainPlaceId
	end
	if id == "map2" then
		return PlaceConfig.Map2PlaceId
	end
	if id == "map3" then
		return PlaceConfig.Map3PlaceId
	end
	if id == "afk" then
		return PlaceConfig.AfkPlaceId
	end
	return nil
end

function PlaceConfig.IsConfigured(): boolean
	return PlaceConfig.Map2PlaceId > 0
		and PlaceConfig.MainPlaceId > 0
		and PlaceConfig.Map3PlaceId > 0
		and PlaceConfig.AfkPlaceId > 0
end

return PlaceConfig
