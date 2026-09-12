--!strict

--[[
	World leaderboard boards. Matches map markers loosely:
	- Attribute key or string value: "leaderboard playtime" / "leaderboard cash"
	- Instance.Name, CollectionService tag, same strings with different case/spaces
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local LeaderboardConfig = {}

export type BoardKind = "playtime" | "cash"

export type BoardTarget = {
	Part: BasePart,
	Faces: { Enum.NormalId },
	Kind: BoardKind,
	Source: string,
}

LeaderboardConfig.PlaytimeMarker = "leaderboard playtime"
LeaderboardConfig.CashMarker = "leaderboard cash"
LeaderboardConfig.TopCount = 10
LeaderboardConfig.RefreshSeconds = 45
LeaderboardConfig.FlushPlaytimeSeconds = 60
LeaderboardConfig.CashDebounceSeconds = 20
-- Economy 1D wipe — same bump as PlayerData_v3 so old cash/playtime ranks die.
LeaderboardConfig.PlaytimeStoreName = "Leaderboard_Playtime_v2"
LeaderboardConfig.CashStoreName = "Leaderboard_Cash_v2"
LeaderboardConfig.CanvasSize = Vector2.new(720, 960)
LeaderboardConfig.MaxDistance = 220
LeaderboardConfig.GuiNamePrefix = "LeaderboardGui_"

local FACE_BY_NAME: { [string]: Enum.NormalId } = {
	front = Enum.NormalId.Front,
	back = Enum.NormalId.Back,
	left = Enum.NormalId.Left,
	right = Enum.NormalId.Right,
	top = Enum.NormalId.Top,
	bottom = Enum.NormalId.Bottom,
}

function LeaderboardConfig.NormalizeMarker(value: string): string
	local lower = string.lower(value)
	lower = string.gsub(lower, "[_%-]+", " ")
	lower = string.gsub(lower, "%s+", " ")
	return (string.gsub(lower, "^%s*(.-)%s*$", "%1"))
end

function LeaderboardConfig.KindFromMarker(value: string): BoardKind?
	local key = LeaderboardConfig.NormalizeMarker(value)
	local compact = string.gsub(key, " ", "")
	if key == LeaderboardConfig.PlaytimeMarker
		or compact == "leaderboardplaytime"
		or compact == "playtimeleaderboard"
	then
		return "playtime"
	end
	if key == LeaderboardConfig.CashMarker
		or compact == "leaderboardcash"
		or compact == "cashleaderboard"
	then
		return "cash"
	end
	return nil
end

local function faceFromAttribute(instance: Instance): Enum.NormalId?
	local raw = instance:GetAttribute("LeaderboardFace") or instance:GetAttribute("Face")
	if typeof(raw) ~= "string" then
		return nil
	end
	return FACE_BY_NAME[string.lower(raw)]
end

-- Thin axis = thickness of the board; GUI goes on the two large faces.
function LeaderboardConfig.DisplayFaces(part: BasePart, preferred: Enum.NormalId?): { Enum.NormalId }
	if preferred then
		local opposite = {
			[Enum.NormalId.Front] = Enum.NormalId.Back,
			[Enum.NormalId.Back] = Enum.NormalId.Front,
			[Enum.NormalId.Left] = Enum.NormalId.Right,
			[Enum.NormalId.Right] = Enum.NormalId.Left,
			[Enum.NormalId.Top] = Enum.NormalId.Bottom,
			[Enum.NormalId.Bottom] = Enum.NormalId.Top,
		}
		return { preferred, opposite[preferred] or Enum.NormalId.Back }
	end

	local x, y, z = part.Size.X, part.Size.Y, part.Size.Z
	if z <= x and z <= y then
		return { Enum.NormalId.Front, Enum.NormalId.Back }
	end
	if x <= y and x <= z then
		return { Enum.NormalId.Right, Enum.NormalId.Left }
	end
	return { Enum.NormalId.Top, Enum.NormalId.Bottom }
end

function LeaderboardConfig.KindFromInstance(instance: Instance): BoardKind?
	local byName = LeaderboardConfig.KindFromMarker(instance.Name)
	if byName then
		return byName
	end

	local ok, attributes = pcall(function()
		return instance:GetAttributes()
	end)
	if ok and typeof(attributes) == "table" then
		for attrName, attrValue in pairs(attributes) do
			if typeof(attrName) == "string" then
				local fromKey = LeaderboardConfig.KindFromMarker(attrName)
				if fromKey then
					return fromKey
				end
			end
			if typeof(attrValue) == "string" then
				local fromValue = LeaderboardConfig.KindFromMarker(attrValue)
				if fromValue then
					return fromValue
				end
			end
		end
	end

	local tagOk, tags = pcall(function()
		return CollectionService:GetTags(instance)
	end)
	if tagOk and typeof(tags) == "table" then
		for _, tag in ipairs(tags) do
			if typeof(tag) == "string" then
				local fromTag = LeaderboardConfig.KindFromMarker(tag)
				if fromTag then
					return fromTag
				end
			end
		end
	end

	return nil
end

local function pickPartInModel(model: Model): BasePart?
	local best: BasePart? = nil
	local bestScore = -1
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local size = descendant.Size
			local area = math.max(size.X * size.Y, size.Y * size.Z, size.X * size.Z)
			local thickness = math.min(size.X, size.Y, size.Z)
			-- Prefer a flat board (large area, small thickness) over a giant rock.
			local flatBonus = if thickness > 0 and (area / thickness) > 20 then 50 else 0
			local score = area + flatBonus
			local lowerName = string.lower(descendant.Name)
			if string.find(lowerName, "board", 1, true)
				or string.find(lowerName, "screen", 1, true)
				or string.find(lowerName, "display", 1, true)
				or string.find(lowerName, "tablica", 1, true)
				or string.find(lowerName, "gui", 1, true)
			then
				score += 10000
			end
			if score > bestScore then
				bestScore = score
				best = descendant
			end
		end
	end
	return best
end

local function resolvePart(instance: Instance): BasePart?
	if instance:IsA("Texture") or instance:IsA("Decal") then
		local parent = instance.Parent
		if parent and parent:IsA("BasePart") then
			return parent
		end
	end

	if instance:IsA("BasePart") then
		return instance
	end

	if instance:IsA("Model") then
		return instance.PrimaryPart or pickPartInModel(instance)
	end

	if instance:IsA("Folder") then
		return instance:FindFirstChildWhichIsA("BasePart", true)
	end

	local ancestor = instance:FindFirstAncestorWhichIsA("BasePart")
	if ancestor then
		return ancestor
	end

	return instance:FindFirstChildWhichIsA("BasePart", true)
end

function LeaderboardConfig.FindBoards(): { BoardTarget }
	local boards: { BoardTarget } = {}
	local seen: { [BasePart]: boolean } = {}

	local function consider(instance: Instance)
		local kind = LeaderboardConfig.KindFromInstance(instance)
		if not kind then
			return
		end

		local part = resolvePart(instance)
		if not part or seen[part] then
			return
		end

		seen[part] = true
		local preferred = faceFromAttribute(instance) or faceFromAttribute(part)
		table.insert(boards, {
			Part = part,
			Faces = LeaderboardConfig.DisplayFaces(part, preferred),
			Kind = kind,
			Source = instance:GetFullName(),
		})
	end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		consider(descendant)
	end

	return boards
end

function LeaderboardConfig.DebugDump(): string
	local lines = { "[Leaderboard] Workspace scan:" }
	local found = LeaderboardConfig.FindBoards()
	table.insert(lines, string.format("  matched boards: %d", #found))
	for _, board in ipairs(found) do
		table.insert(lines, string.format(
			"  - %s -> %s (%s) size=%s",
			board.Kind,
			board.Part:GetFullName(),
			board.Source,
			tostring(board.Part.Size)
		))
	end

	if #found == 0 then
		table.insert(lines, "  candidates (name/attr contains leaderboard|playtime|cash):")
		local shown = 0
		for _, descendant in ipairs(Workspace:GetDescendants()) do
			local blob = string.lower(descendant.Name)
			local attrOk, attributes = pcall(function()
				return descendant:GetAttributes()
			end)
			if attrOk and typeof(attributes) == "table" then
				for attrName, attrValue in pairs(attributes) do
					blob ..= " " .. string.lower(tostring(attrName))
					blob ..= " " .. string.lower(tostring(attrValue))
				end
			end
			if string.find(blob, "leader", 1, true)
				or string.find(blob, "playtime", 1, true)
				or string.find(blob, "cash", 1, true)
				or string.find(blob, "tablica", 1, true)
			then
				shown += 1
				if shown <= 25 then
					table.insert(lines, string.format("    %s [%s]", descendant:GetFullName(), descendant.ClassName))
				end
			end
		end
		if shown == 0 then
			table.insert(lines, "    (none)")
		end
	end

	return table.concat(lines, "\n")
end

return LeaderboardConfig
