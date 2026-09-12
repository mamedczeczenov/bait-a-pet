--!strict

local DailyConfig = {}

-- Economy 1D: login reason (~1–2 bag sells), not a Bronze skip.
DailyConfig.BaseCoins = 120
DailyConfig.CoinsPerStreak = 25
DailyConfig.MaxStreak = 7
DailyConfig.BuffCatches = 5
DailyConfig.BuffMult = 1.12

function DailyConfig.GetUtcDayKey(unixTime: number?): string
	local t = if typeof(unixTime) == "number" then unixTime else os.time()
	return os.date("!%Y-%m-%d", t) :: string
end

function DailyConfig.GetYesterdayKey(unixTime: number?): string
	local t = (if typeof(unixTime) == "number" then unixTime else os.time()) - 86400
	return os.date("!%Y-%m-%d", t) :: string
end

function DailyConfig.GetCoinReward(streak: number): number
	local clamped = math.clamp(math.floor(streak), 1, DailyConfig.MaxStreak)
	return DailyConfig.BaseCoins + DailyConfig.CoinsPerStreak * clamped
end

function DailyConfig.IsClaimable(lastClaimDay: string, nowUnix: number?): boolean
	local today = DailyConfig.GetUtcDayKey(nowUnix)
	return lastClaimDay ~= today
end

-- Returns next streak if claiming now (does not mutate).
function DailyConfig.NextStreak(currentStreak: number, lastClaimDay: string, nowUnix: number?): number
	local yesterday = DailyConfig.GetYesterdayKey(nowUnix)
	local streak = math.max(0, math.floor(currentStreak))

	if lastClaimDay == yesterday then
		return math.clamp(streak + 1, 1, DailyConfig.MaxStreak)
	end

	-- Missed a day (or first claim): restart at 1.
	return 1
end

return DailyConfig
