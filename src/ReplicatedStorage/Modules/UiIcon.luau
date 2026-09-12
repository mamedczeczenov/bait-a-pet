--!strict

--[[
	Mount candy UI icons: ImageLabel when rbxassetid is set, else emoji TextLabel.
]]

local IconAssets = require(script.Parent:WaitForChild("IconAssets"))
local UiTheme = require(script.Parent:WaitForChild("UiTheme"))

local UiIcon = {}

export type MountProps = {
	Key: string,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	ZIndex: number?,
	LayoutOrder: number?,
	Name: string?,
	ImageSize: number?, -- emoji TextSize when falling back
	ScaleType: Enum.ScaleType?,
}

local function clearNamed(parent: Instance, name: string)
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
end

function UiIcon.Mount(parent: Instance, props: MountProps): GuiObject
	local name = props.Name or "Icon"
	clearNamed(parent, name)

	local size = props.Size or UDim2.fromOffset(48, 48)
	local z = props.ZIndex or 1
	local imageUri = IconAssets.GetImage(props.Key)

	if imageUri then
		local image = UiTheme.Create("ImageLabel", {
			Name = name,
			BackgroundTransparency = 1,
			Size = size,
			Position = props.Position,
			AnchorPoint = props.AnchorPoint,
			Image = imageUri,
			ScaleType = props.ScaleType or Enum.ScaleType.Fit,
			ZIndex = z,
			LayoutOrder = props.LayoutOrder or 0,
		}, parent) :: ImageLabel
		return image
	end

	local emoji = IconAssets.GetEmoji(props.Key)
	local textSize = props.ImageSize or math.floor(math.min(size.X.Offset, size.Y.Offset) * 0.7)
	if textSize < 12 then
		textSize = 22
	end

	local label = UiTheme.Create("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Size = size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Text = emoji,
		TextSize = textSize,
		Font = UiTheme.FontTitle,
		TextColor3 = UiTheme.Colors.Text,
		ZIndex = z,
		LayoutOrder = props.LayoutOrder or 0,
	}, parent) :: TextLabel

	-- Short word badges (NEW / BUY) get outline; emoji usually don't need it
	if string.len(emoji) <= 4 and string.match(emoji, "^[%w%p%s]+$") ~= nil then
		UiTheme.TextStroke(label, 2)
	end

	return label
end

function UiIcon.Set(target: GuiObject, key: string, emojiTextSize: number?)
	local imageUri = IconAssets.GetImage(key)
	if target:IsA("ImageLabel") then
		if imageUri then
			target.Image = imageUri
			target.ImageTransparency = 0
		else
			target.Image = ""
			target.ImageTransparency = 1
		end
		return
	end

	if target:IsA("TextLabel") or target:IsA("TextButton") then
		if imageUri then
			-- Promote text icon host to image by replacing in-place sibling.
			local parent = target.Parent
			if parent then
				local props: MountProps = {
					Key = key,
					Name = target.Name,
					Size = target.Size,
					Position = target.Position,
					AnchorPoint = target.AnchorPoint,
					ZIndex = target.ZIndex,
					LayoutOrder = target.LayoutOrder,
					ImageSize = emojiTextSize,
				}
				target:Destroy()
				UiIcon.Mount(parent, props)
			end
		else
			(target :: TextLabel).Text = IconAssets.GetEmoji(key)
			if emojiTextSize then
				(target :: TextLabel).TextSize = emojiTextSize
			end
		end
	end
end

function UiIcon.ApplyToButton(button: TextButton, key: string, iconSize: number?)
	local size = iconSize or 28
	local existing = button:FindFirstChild("UiIconGlyph")
	if existing then
		existing:Destroy()
	end

	-- Close button: icon replaces the "X" caption.
	if key == "btn_close" then
		button.Text = ""
		UiIcon.Mount(button, {
			Key = key,
			Name = "UiIconGlyph",
			Size = UDim2.fromOffset(size, size),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = button.ZIndex + 1,
			ImageSize = size - 2,
		})
		return
	end

	local hasText = button.Text ~= "" and button.Text ~= " "
	if hasText then
		local pad = button:FindFirstChild("UiIconPad")
		if not pad then
			pad = Instance.new("UIPadding")
			pad.Name = "UiIconPad"
			pad.Parent = button
		end
		local h = button.Size.Y.Offset
		if h <= 0 then
			h = size + 12
		end
		(pad :: UIPadding).PaddingLeft = UDim.new(0, size + 10)

		UiIcon.Mount(button, {
			Key = key,
			Name = "UiIconGlyph",
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.fromOffset(6, math.max(0, math.floor((h - size) / 2))),
			ZIndex = button.ZIndex + 1,
			ImageSize = size - 4,
		})
	else
		UiIcon.Mount(button, {
			Key = key,
			Name = "UiIconGlyph",
			Size = UDim2.fromOffset(size, size),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = button.ZIndex + 1,
			ImageSize = size - 4,
		})
	end
end

return UiIcon
