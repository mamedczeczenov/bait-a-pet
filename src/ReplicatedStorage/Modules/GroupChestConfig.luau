--!strict

--[[
	One-time group join chest.
	Workspace marker: Attribute name/Name = "skrzynia vip" (or Instance.Name).
]]

local GroupChestConfig = {}

GroupChestConfig.GroupId = 924927243
GroupChestConfig.MarkerName = "skrzynia vip"
GroupChestConfig.StationTag = "GroupChestStation"
-- Economy 1D: helps first upgrade (~2k), does not skip Bronze (16k).
GroupChestConfig.RewardCoins = 500
GroupChestConfig.ActionText = "Join"
GroupChestConfig.ObjectText = "VIP Chest"
GroupChestConfig.ItemName = "VIP Chest"
GroupChestConfig.PromptTitle = "VIP Chest"
GroupChestConfig.JoinPromptTitle = "Join Group"
GroupChestConfig.JoinButtonText = "Join"
GroupChestConfig.ClaimButtonText = "Claim"
GroupChestConfig.ClaimedButtonText = "Claimed"
GroupChestConfig.CancelButtonText = "Cancel"
GroupChestConfig.NeedGroupMessage = "Join the group first. If you just joined, rejoin the game."
GroupChestConfig.AlreadyClaimedMessage = "You already claimed this chest."
GroupChestConfig.ClaimedMessage = "VIP chest claimed! +%s coins."
GroupChestConfig.CheckFailedMessage = "Could not check group membership. Try again."
GroupChestConfig.LoadingMessage = "Still loading..."
GroupChestConfig.GroupIcon = string.format("rbxthumb://type=GroupIcon&id=%d&w=150&h=150", GroupChestConfig.GroupId)

function GroupChestConfig.NormalizeMarker(value: string): string
	local lower = string.lower(value)
	lower = string.gsub(lower, "%s+", " ")
	return (string.gsub(lower, "^%s*(.-)%s*$", "%1"))
end

function GroupChestConfig.IsMarker(value: string): boolean
	return GroupChestConfig.NormalizeMarker(value) == GroupChestConfig.NormalizeMarker(GroupChestConfig.MarkerName)
end

return GroupChestConfig
