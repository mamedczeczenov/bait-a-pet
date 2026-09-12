--!strict

--[[
	Candy "Eggs Shop" UI language — bright panels, thick strokes, dopamine accents.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UiTheme = {}

UiTheme.FontTitle = Enum.Font.FredokaOne
UiTheme.FontBody = Enum.Font.GothamBold
UiTheme.FontMedium = Enum.Font.GothamBold

UiTheme.CornerPanel = UDim.new(0, 18)
UiTheme.CornerButton = UDim.new(0, 14)
UiTheme.CornerSmall = UDim.new(0, 10)
UiTheme.CornerChip = UDim.new(0, 12)

-- Shared ScrollingFrame look (Index-style black bar + room to reach the end).
UiTheme.ScrollBarThickness = 10
UiTheme.ScrollBarColor = Color3.fromRGB(20, 20, 28)
UiTheme.ScrollBottomPad = 96
UiTheme.ScrollPaddingBottom = 64
UiTheme.ScrollPaddingSide = 8
UiTheme.ScrollPaddingRight = 14
UiTheme.ScrollSpacerHeight = 28

UiTheme.Colors = {
	-- Soft sky / cream surfaces (child-friendly, high energy)
	BgDeep = Color3.fromRGB(210, 235, 255),
	BgPanel = Color3.fromRGB(255, 250, 240),
	BgRaised = Color3.fromRGB(255, 255, 255),
	BgRow = Color3.fromRGB(255, 245, 230),
	BgMuted = Color3.fromRGB(190, 210, 230),
	BgHeader = Color3.fromRGB(120, 200, 255),
	BgSlot = Color3.fromRGB(255, 255, 255),

	Stroke = Color3.fromRGB(30, 30, 40),
	StrokeSoft = Color3.fromRGB(80, 100, 130),
	StrokeText = Color3.fromRGB(20, 20, 28),

	Text = Color3.fromRGB(255, 255, 255),
	TextDark = Color3.fromRGB(35, 40, 55),
	TextDim = Color3.fromRGB(90, 105, 130),
	TextMuted = Color3.fromRGB(130, 145, 165),

	AccentAmber = Color3.fromRGB(255, 200, 40),
	AccentAmberDim = Color3.fromRGB(220, 150, 20),
	AccentCyan = Color3.fromRGB(70, 210, 255),
	AccentCyanDim = Color3.fromRGB(40, 160, 220),
	AccentGreen = Color3.fromRGB(80, 230, 90),
	AccentGreenHot = Color3.fromRGB(40, 200, 60),
	AccentRed = Color3.fromRGB(255, 70, 80),
	AccentPink = Color3.fromRGB(255, 90, 180),
	AccentPinkHot = Color3.fromRGB(230, 50, 200),
	AccentBlue = Color3.fromRGB(80, 160, 255),
	AccentPurple = Color3.fromRGB(180, 100, 255),
	AccentVip = Color3.fromRGB(255, 210, 50),
	AccentVipLocked = Color3.fromRGB(170, 150, 90),

	Success = Color3.fromRGB(60, 230, 100),
	Warning = Color3.fromRGB(255, 200, 60),
	Danger = Color3.fromRGB(255, 70, 80),
	Stock = Color3.fromRGB(80, 255, 100),
}

function UiTheme.Create(className: string, props: { [string]: any }, parent: Instance?): Instance
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UiTheme.Corner(parent: Instance, radius: UDim?): UICorner
	return UiTheme.Create("UICorner", {
		CornerRadius = radius or UiTheme.CornerPanel,
	}, parent) :: UICorner
end

function UiTheme.Stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	return UiTheme.Create("UIStroke", {
		Color = color or UiTheme.Colors.Stroke,
		Thickness = thickness or 3,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent) :: UIStroke
end

function UiTheme.TextStroke(label: TextLabel | TextButton, thickness: number?)
	label.TextStrokeColor3 = UiTheme.Colors.StrokeText
	label.TextStrokeTransparency = 0
	-- TextStrokeThickness is not a property; use UIStroke on text for modern look
	local existing = label:FindFirstChild("CandyTextStroke")
	if existing then
		existing:Destroy()
	end
	local stroke = Instance.new("UIStroke")
	stroke.Name = "CandyTextStroke"
	stroke.Color = UiTheme.Colors.StrokeText
	stroke.Thickness = thickness or 2.4
	stroke.Transparency = 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label
	return stroke
end

function UiTheme.Pad(parent: Instance, px: number): UIPadding
	return UiTheme.Create("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	}, parent) :: UIPadding
end

function UiTheme.Gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?): UIGradient
	local existing = parent:FindFirstChildOfClass("UIGradient")
	if existing then
		existing:Destroy()
	end
	return UiTheme.Create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, top),
			ColorSequenceKeypoint.new(1, bottom),
		}),
		Rotation = rotation or 90,
	}, parent) :: UIGradient
end

function UiTheme.MobileScale(screenGui: ScreenGui, desktopScale: number?): UIScale
	local scale = UiTheme.Create("UIScale", {
		Name = "UiThemeScale",
		Scale = desktopScale or 1,
	}, screenGui) :: UIScale

	local function refresh()
		local camera = workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local shortest = math.min(viewport.X, viewport.Y)
		local base = desktopScale or 1
		if shortest < 700 then
			scale.Scale = base * 0.82
		elseif shortest < 900 then
			scale.Scale = base * 0.9
		else
			scale.Scale = base
		end
	end

	refresh()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local cam = workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
			refresh()
		end
	end)

	return scale
end

function UiTheme.Panel(props: {
	Name: string,
	Size: UDim2,
	Parent: Instance,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Visible: boolean?,
	ZIndex: number?,
}): Frame
	local frame = UiTheme.Create("Frame", {
		Name = props.Name,
		Size = props.Size,
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		BackgroundColor3 = UiTheme.Colors.BgPanel,
		Visible = if props.Visible == nil then true else props.Visible,
		ZIndex = props.ZIndex or 1,
		BorderSizePixel = 0,
	}, props.Parent) :: Frame
	UiTheme.Corner(frame, UiTheme.CornerPanel)
	UiTheme.Stroke(frame, UiTheme.Colors.Stroke, 4, 0)

	-- Candy header stripe
	local headerBar = UiTheme.Create("Frame", {
		Name = "HeaderBar",
		BackgroundColor3 = UiTheme.Colors.BgHeader,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 56),
		ZIndex = frame.ZIndex,
		Active = false,
	}, frame) :: Frame
	UiTheme.Corner(headerBar, UiTheme.CornerPanel)
	UiTheme.Gradient(headerBar, Color3.fromRGB(150, 220, 255), Color3.fromRGB(90, 180, 255), 90)

	-- Mask bottom of header bar corners so only top is rounded visually
	local headerMask = UiTheme.Create("Frame", {
		Name = "HeaderMask",
		BackgroundColor3 = UiTheme.Colors.BgHeader,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -18),
		Size = UDim2.new(1, 0, 0, 18),
		ZIndex = frame.ZIndex,
		Active = false,
	}, headerBar) :: Frame
	UiTheme.Gradient(headerMask, Color3.fromRGB(150, 220, 255), Color3.fromRGB(90, 180, 255), 90)

	return frame
end

function UiTheme.Header(parent: Frame, title: string, onClose: (() -> ())?): (TextLabel, TextButton?)
	local titleLabel = UiTheme.Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 12),
		Size = UDim2.new(1, -80, 0, 34),
		Text = title,
		TextColor3 = UiTheme.Colors.Text,
		TextSize = 28,
		Font = UiTheme.FontTitle,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = parent.ZIndex + 2,
	}, parent) :: TextLabel
	UiTheme.TextStroke(titleLabel, 2.8)

	local closeButton: TextButton? = nil
	if onClose then
		local button = UiTheme.Create("TextButton", {
			Name = "Close",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 10),
			Size = UDim2.fromOffset(40, 40),
			BackgroundColor3 = UiTheme.Colors.AccentRed,
			Text = "X",
			TextColor3 = UiTheme.Colors.Text,
			TextSize = 22,
			Font = UiTheme.FontTitle,
			AutoButtonColor = true,
			ZIndex = parent.ZIndex + 2,
		}, parent) :: TextButton
		UiTheme.Corner(button, UiTheme.CornerSmall)
		UiTheme.Stroke(button, UiTheme.Colors.Stroke, 3, 0)
		UiTheme.TextStroke(button, 2)
		UiTheme.Gradient(button, Color3.fromRGB(255, 110, 110), Color3.fromRGB(230, 40, 50), 90)
		button.MouseButton1Click:Connect(onClose)
		UiTheme.WireButtonMotion(button)
		closeButton = button
	end

	return titleLabel, closeButton
end

export type ButtonVariant = "primary" | "danger" | "vip" | "cyan" | "muted" | "green" | "blue" | "pink"

function UiTheme.ButtonColor(variant: ButtonVariant): Color3
	local c = UiTheme.Colors
	if variant == "danger" then
		return c.AccentRed
	elseif variant == "vip" then
		return c.AccentVip
	elseif variant == "cyan" then
		return c.AccentCyan
	elseif variant == "muted" then
		return c.BgMuted
	elseif variant == "green" then
		return c.AccentGreen
	elseif variant == "blue" then
		return c.AccentBlue
	elseif variant == "pink" then
		return c.AccentPink
	end
	return c.AccentCyan
end

local function buttonGradientColors(variant: ButtonVariant): (Color3, Color3)
	local c = UiTheme.Colors
	if variant == "danger" then
		return Color3.fromRGB(255, 120, 120), c.AccentRed
	elseif variant == "vip" then
		return Color3.fromRGB(255, 240, 120), c.AccentVip
	elseif variant == "cyan" or variant == "primary" then
		return Color3.fromRGB(140, 230, 255), c.AccentCyanDim
	elseif variant == "muted" then
		return Color3.fromRGB(220, 230, 240), c.BgMuted
	elseif variant == "green" then
		return Color3.fromRGB(140, 255, 150), c.AccentGreenHot
	elseif variant == "blue" then
		return Color3.fromRGB(140, 190, 255), Color3.fromRGB(50, 120, 240)
	elseif variant == "pink" then
		return Color3.fromRGB(255, 150, 220), c.AccentPinkHot
	end
	return Color3.fromRGB(140, 230, 255), c.AccentCyanDim
end

function UiTheme.WireButtonMotion(button: GuiButton)
	if button:GetAttribute("CandyMotionWired") == true then
		return
	end
	button:SetAttribute("CandyMotionWired", true)

	local scale = button:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Scale = 1
		scale.Parent = button
	end

	local hover = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local press = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	button.MouseEnter:Connect(function()
		TweenService:Create(scale, hover, { Scale = 1.06 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, hover, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, press, { Scale = 0.94 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, hover, { Scale = 1.06 }):Play()
	end)
end

function UiTheme.Pulse(instance: GuiObject, peakScale: number?, period: number?): () -> ()
	local scale = instance:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Scale = 1
		scale.Parent = instance
	end

	local peak = peakScale or 1.08
	local half = (period or 0.9) / 2
	local alive = true
	task.spawn(function()
		while alive and instance.Parent and scale.Parent do
			local up = TweenService:Create(scale, TweenInfo.new(half, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Scale = peak })
			up:Play()
			up.Completed:Wait()
			if not alive then
				break
			end
			local down = TweenService:Create(scale, TweenInfo.new(half, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Scale = 1 })
			down:Play()
			down.Completed:Wait()
		end
	end)

	return function()
		alive = false
		if scale.Parent then
			scale.Scale = 1
		end
	end
end

function UiTheme.BounceIn(instance: GuiObject, fromScale: number?)
	local scale = instance:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = instance
	end
	scale.Scale = fromScale or 0.6
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function UiTheme.Button(props: {
	Name: string,
	Text: string,
	Parent: Instance,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Variant: ButtonVariant?,
	LayoutOrder: number?,
	TextSize: number?,
	ZIndex: number?,
}): TextButton
	local variant = props.Variant or "primary"
	local color = UiTheme.ButtonColor(variant)
	local top, bottom = buttonGradientColors(variant)
	local button = UiTheme.Create("TextButton", {
		Name = props.Name,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = color,
		Text = props.Text,
		TextColor3 = UiTheme.Colors.Text,
		TextSize = props.TextSize or 18,
		Font = UiTheme.FontTitle,
		AutoButtonColor = false,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		BorderSizePixel = 0,
	}, props.Parent) :: TextButton
	UiTheme.Corner(button, UiTheme.CornerButton)
	UiTheme.Stroke(button, UiTheme.Colors.Stroke, 3, 0)
	UiTheme.TextStroke(button, 2.2)
	UiTheme.Gradient(button, top, bottom, 90)
	UiTheme.WireButtonMotion(button)
	return button
end

function UiTheme.Row(props: {
	Name: string,
	Parent: Instance,
	Size: UDim2,
	Position: UDim2?,
	LayoutOrder: number?,
	ZIndex: number?,
	RarityColor: Color3?,
}): Frame
	local fill = props.RarityColor or UiTheme.Colors.BgRow
	local row = UiTheme.Create("Frame", {
		Name = props.Name,
		Size = props.Size,
		Position = props.Position,
		BackgroundColor3 = fill,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		BorderSizePixel = 0,
	}, props.Parent) :: Frame
	UiTheme.Corner(row, UiTheme.CornerSmall)
	local strokeColor = if props.RarityColor then props.RarityColor:Lerp(UiTheme.Colors.Stroke, 0.35) else UiTheme.Colors.Stroke
	UiTheme.Stroke(row, strokeColor, 3, 0)
	if props.RarityColor then
		-- Soft candy wash so text stays readable
		row.BackgroundColor3 = props.RarityColor:Lerp(Color3.fromRGB(255, 255, 255), 0.45)
	end
	return row
end

function UiTheme.Label(props: {
	Name: string,
	Text: string,
	Parent: Instance,
	Size: UDim2,
	Position: UDim2?,
	TextSize: number?,
	Color: Color3?,
	Font: Enum.Font?,
	XAlign: Enum.TextXAlignment?,
	YAlign: Enum.TextYAlignment?,
	ZIndex: number?,
	RichText: boolean?,
	Outlined: boolean?,
}): TextLabel
	local color = props.Color or UiTheme.Colors.TextDark
	local label = UiTheme.Create("TextLabel", {
		Name = props.Name,
		BackgroundTransparency = 1,
		Size = props.Size,
		Position = props.Position,
		Text = props.Text,
		TextColor3 = color,
		TextSize = props.TextSize or 16,
		Font = props.Font or UiTheme.FontBody,
		TextXAlignment = props.XAlign or Enum.TextXAlignment.Left,
		TextYAlignment = props.YAlign or Enum.TextYAlignment.Center,
		ZIndex = props.ZIndex or 1,
		RichText = props.RichText == true,
	}, props.Parent) :: TextLabel
	-- Candy outline: white/light titles on colored chrome, or when explicitly requested
	if props.Outlined == true or color == UiTheme.Colors.Text then
		UiTheme.TextStroke(label, 2.2)
	end
	return label
end

function UiTheme.InsetTop(): number
	local ok, inset = pcall(function()
		return GuiService:GetGuiInset()
	end)
	if ok and typeof(inset) == "Vector2" then
		return inset.Y
	end
	return 36
end

function UiTheme.LocalPlayerGui(): PlayerGui?
	local player = Players.LocalPlayer
	if not player then
		return nil
	end
	return player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 5) :: PlayerGui?
end

function UiTheme.StyleScrollingFrame(frame: ScrollingFrame)
	frame.ScrollBarThickness = UiTheme.ScrollBarThickness
	frame.ScrollBarImageColor3 = UiTheme.ScrollBarColor
	frame.ScrollBarImageTransparency = 0
	frame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	frame.ScrollingEnabled = true
	frame.BorderSizePixel = 0
	frame.AutomaticCanvasSize = Enum.AutomaticSize.None
end

function UiTheme.EnsureScrollPadding(frame: ScrollingFrame, paddingBottom: number?)
	local pad = frame:FindFirstChildOfClass("UIPadding")
	if not pad then
		pad = UiTheme.Create("UIPadding", {}, frame) :: UIPadding
	end
	pad.PaddingTop = UDim.new(0, UiTheme.ScrollPaddingSide)
	pad.PaddingBottom = UDim.new(0, paddingBottom or UiTheme.ScrollPaddingBottom)
	pad.PaddingLeft = UDim.new(0, UiTheme.ScrollPaddingSide)
	pad.PaddingRight = UDim.new(0, UiTheme.ScrollPaddingRight)
	return pad
end

function UiTheme.MeasureScrollContentHeight(frame: ScrollingFrame, layout: UIListLayout?): number
	local gap = if layout then layout.Padding.Offset else 0
	local height = 0
	local items = 0
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("GuiObject")
			and not child:IsA("UIListLayout")
			and not child:IsA("UIGridLayout")
			and not child:IsA("UIPadding")
			and not child:IsA("UICorner")
			and not child:IsA("UIStroke")
			and not child:IsA("UIScale")
		then
			local h = child.Size.Y.Offset
			if h <= 0 then
				h = child.AbsoluteSize.Y
			end
			height += math.max(0, h)
			items += 1
		end
	end
	if items > 1 then
		height += gap * (items - 1)
	end
	return height
end

function UiTheme.AddScrollSpacer(frame: ScrollingFrame, layoutOrder: number?): Frame
	local existing = frame:FindFirstChild("ScrollEndSpacer")
	if existing and existing:IsA("Frame") then
		existing.LayoutOrder = layoutOrder or 100000
		existing.Size = UDim2.new(1, 0, 0, UiTheme.ScrollSpacerHeight)
		return existing
	end
	return UiTheme.Create("Frame", {
		Name = "ScrollEndSpacer",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, UiTheme.ScrollSpacerHeight),
		LayoutOrder = layoutOrder or 100000,
		ZIndex = 1,
	}, frame) :: Frame
end

function UiTheme.SetScrollCanvas(frame: ScrollingFrame, layoutContentHeight: number?)
	local layout = frame:FindFirstChildOfClass("UIListLayout")
	local measured = UiTheme.MeasureScrollContentHeight(frame, layout)
	local content = measured
	if typeof(layoutContentHeight) == "number" and layoutContentHeight > 0 then
		content = math.max(measured, layoutContentHeight)
	end
	if layout and layout.AbsoluteContentSize.Y > 0 then
		content = math.max(content, layout.AbsoluteContentSize.Y)
	end

	local pad = frame:FindFirstChildOfClass("UIPadding")
	local padY = if pad then pad.PaddingTop.Offset + pad.PaddingBottom.Offset else 0
	frame.CanvasSize = UDim2.fromOffset(0, content + padY + UiTheme.ScrollBottomPad)
end

function UiTheme.QueueScrollCanvas(frame: ScrollingFrame, layoutContentHeight: number?)
	task.defer(function()
		local RunService = game:GetService("RunService")
		RunService.Heartbeat:Wait()
		UiTheme.SetScrollCanvas(frame, layoutContentHeight)
		RunService.Heartbeat:Wait()
		UiTheme.SetScrollCanvas(frame, layoutContentHeight)
	end)
end

function UiTheme.BindScrollCanvas(frame: ScrollingFrame, layout: UIListLayout): () -> ()
	local function refresh()
		UiTheme.SetScrollCanvas(frame, layout.AbsoluteContentSize.Y)
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refresh)
	task.defer(refresh)
	return refresh
end

return UiTheme
