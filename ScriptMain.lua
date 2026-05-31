local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local existingGui = PlayerGui:FindFirstChild("ScriptDisabledOverlay")
if existingGui then
	existingGui:Destroy()
end

local existingBlur = Lighting:FindFirstChild("ScriptDisabledBlur")
if existingBlur then
	existingBlur:Destroy()
end

local blur = Instance.new("BlurEffect")
blur.Name = "ScriptDisabledBlur"
blur.Size = 0
blur.Parent = Lighting

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ScriptDisabledOverlay"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 2147483647
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui

local function tween(target, time, style, direction, properties, repeats, reverses, delayTime)
	local info = TweenInfo.new(time, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out, repeats or 0, reverses or false, delayTime or 0)
	local created = TweenService:Create(target, info, properties)
	created:Play()
	return created
end

local function corner(parent, radius)
	local item = Instance.new("UICorner")
	item.CornerRadius = radius
	item.Parent = parent
	return item
end

local function stroke(parent, color, transparency, thickness)
	local item = Instance.new("UIStroke")
	item.Color = color
	item.Transparency = transparency
	item.Thickness = thickness
	item.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	item.Parent = parent
	return item
end

local function solidFrame(name, parent, size, position, color, transparency, zIndex)
	local item = Instance.new("Frame")
	item.Name = name
	item.Size = size
	item.Position = position
	item.BackgroundColor3 = color
	item.BackgroundTransparency = transparency or 0
	item.BorderSizePixel = 0
	item.ZIndex = zIndex or 1
	item.Parent = parent
	return item
end

local root = solidFrame("Root", screenGui, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.fromRGB(2, 3, 7), 0, 1)
root.Active = true

local backgroundGradient = Instance.new("UIGradient")
backgroundGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 13, 21)),
	ColorSequenceKeypoint.new(0.42, Color3.fromRGB(2, 3, 7)),
	ColorSequenceKeypoint.new(0.72, Color3.fromRGB(13, 4, 10)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(54, 0, 12))
})
backgroundGradient.Rotation = 132
backgroundGradient.Parent = root

local leftGlow = solidFrame("LeftGlow", root, UDim2.fromOffset(520, 520), UDim2.new(0, -260, 0.5, -260), Color3.fromRGB(185, 11, 32), 0.82, 1)
corner(leftGlow, UDim.new(1, 0))

local rightGlow = solidFrame("RightGlow", root, UDim2.fromOffset(620, 620), UDim2.new(1, -250, 0.16, -310), Color3.fromRGB(255, 30, 50), 0.9, 1)
corner(rightGlow, UDim.new(1, 0))

local bottomShade = solidFrame("BottomShade", root, UDim2.new(1, 0, 0.34, 0), UDim2.new(0, 0, 0.66, 0), Color3.fromRGB(0, 0, 0), 0.18, 2)
local bottomGradient = Instance.new("UIGradient")
bottomGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(1, 0.08)
})
bottomGradient.Rotation = 90
bottomGradient.Parent = bottomShade

local particles = Instance.new("Frame")
particles.Name = "Particles"
particles.Size = UDim2.fromScale(1, 1)
particles.BackgroundTransparency = 1
particles.BorderSizePixel = 0
particles.ZIndex = 3
particles.Parent = root

for i = 1, 18 do
	local particle = solidFrame("Particle" .. i, particles, UDim2.fromOffset(2 + (i % 3), 20 + (i % 5) * 6), UDim2.fromScale((i * 0.071) % 1, (i * 0.137) % 1), Color3.fromRGB(255, 34, 57), 0.82, 3)
	particle.Rotation = -24 + (i % 8) * 7
	corner(particle, UDim.new(1, 0))
	tween(particle, 4.8 + (i % 5) * 0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, {
		Position = UDim2.fromScale(((i * 0.071) + 0.035) % 1, ((i * 0.137) + 0.08) % 1),
		BackgroundTransparency = 0.93,
		Rotation = particle.Rotation + 22
	}, -1, true, i * 0.07)
end

local panel = solidFrame("Panel", root, UDim2.new(0.82, 0, 0.64, 0), UDim2.fromScale(0.5, 0.47), Color3.fromRGB(255, 255, 255), 1, 10)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
corner(panel, UDim.new(0, 32))
local panelStroke = stroke(panel, Color3.fromRGB(255, 87, 105), 1, 1.4)
local panelScale = Instance.new("UIScale")
panelScale.Scale = 0.92
panelScale.Parent = panel

local panelGradient = Instance.new("UIGradient")
panelGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 135, 145))
})
panelGradient.Rotation = 110
panelGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.91),
	NumberSequenceKeypoint.new(1, 0.985)
})
panelGradient.Parent = panel

local content = Instance.new("Frame")
content.Name = "Content"
content.AnchorPoint = Vector2.new(0.5, 0.5)
content.Position = UDim2.fromScale(0.5, 0.49)
content.Size = UDim2.new(0.9, 0, 0.86, 0)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ZIndex = 12
content.Parent = panel

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 10)
layout.Parent = content

local iconWrap = Instance.new("Frame")
iconWrap.Name = "SkullIcon"
iconWrap.LayoutOrder = 1
iconWrap.Size = UDim2.fromOffset(142, 134)
iconWrap.BackgroundTransparency = 1
iconWrap.BorderSizePixel = 0
iconWrap.ZIndex = 20
iconWrap.Parent = content

local iconScale = Instance.new("UIScale")
iconScale.Scale = 0.64
iconScale.Parent = iconWrap

local aura = solidFrame("Aura", iconWrap, UDim2.fromOffset(128, 128), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(255, 33, 55), 1, 20)
aura.AnchorPoint = Vector2.new(0.5, 0.5)
corner(aura, UDim.new(1, 0))

local ringA = solidFrame("RingA", iconWrap, UDim2.fromOffset(116, 116), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(255, 255, 255), 1, 19)
ringA.AnchorPoint = Vector2.new(0.5, 0.5)
corner(ringA, UDim.new(1, 0))
local ringAStroke = stroke(ringA, Color3.fromRGB(255, 255, 255), 0.8, 1.4)

local ringB = solidFrame("RingB", iconWrap, UDim2.fromOffset(88, 88), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(255, 255, 255), 1, 19)
ringB.AnchorPoint = Vector2.new(0.5, 0.5)
corner(ringB, UDim.new(1, 0))
local ringBStroke = stroke(ringB, Color3.fromRGB(255, 66, 82), 0.9, 1.1)

local skullParts = {}

local function skullPiece(name, size, position, radius, zIndex)
	local piece = solidFrame(name, iconWrap, size, position, Color3.fromRGB(236, 244, 252), 0, zIndex or 24)
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	corner(piece, radius)
	table.insert(skullParts, piece)
	return piece
end

local head = skullPiece("Head", UDim2.fromOffset(90, 82), UDim2.fromOffset(71, 54), UDim.new(0, 38), 24)
local jaw = skullPiece("Jaw", UDim2.fromOffset(66, 42), UDim2.fromOffset(71, 89), UDim.new(0, 16), 23)
local leftCheek = skullPiece("LeftCheek", UDim2.fromOffset(28, 36), UDim2.fromOffset(50, 78), UDim.new(0, 13), 24)
local rightCheek = skullPiece("RightCheek", UDim2.fromOffset(28, 36), UDim2.fromOffset(92, 78), UDim.new(0, 13), 24)

local leftEye = solidFrame("LeftEye", iconWrap, UDim2.fromOffset(27, 27), UDim2.fromOffset(55, 48), Color3.fromRGB(9, 13, 18), 0, 26)
leftEye.AnchorPoint = Vector2.new(0.5, 0.5)
corner(leftEye, UDim.new(1, 0))

local rightEye = solidFrame("RightEye", iconWrap, UDim2.fromOffset(27, 27), UDim2.fromOffset(87, 48), Color3.fromRGB(9, 13, 18), 0, 26)
rightEye.AnchorPoint = Vector2.new(0.5, 0.5)
corner(rightEye, UDim.new(1, 0))

local nose = solidFrame("Nose", iconWrap, UDim2.fromOffset(17, 17), UDim2.fromOffset(71, 70), Color3.fromRGB(9, 13, 18), 0, 26)
nose.AnchorPoint = Vector2.new(0.5, 0.5)
nose.Rotation = 45
corner(nose, UDim.new(0, 5))

for i, x in ipairs({54, 66, 78, 90}) do
	local tooth = skullPiece("Tooth" .. i, UDim2.fromOffset(11, 31), UDim2.fromOffset(x, 99), UDim.new(0, 7), 25)
	tooth.BackgroundColor3 = Color3.fromRGB(246, 251, 255)
end

local warning = Instance.new("TextLabel")
warning.Name = "Warning"
warning.LayoutOrder = 2
warning.Size = UDim2.new(1, 0, 0, 24)
warning.BackgroundTransparency = 1
warning.Text = "ACCESO SUSPENDIDO"
warning.TextColor3 = Color3.fromRGB(255, 75, 92)
warning.TextTransparency = 1
warning.TextScaled = true
warning.Font = Enum.Font.Code
warning.ZIndex = 16
warning.Parent = content

local warningLimit = Instance.new("UITextSizeConstraint")
warningLimit.MaxTextSize = 17
warningLimit.MinTextSize = 11
warningLimit.Parent = warning

local title = Instance.new("TextLabel")
title.Name = "Title"
title.LayoutOrder = 3
title.Size = UDim2.new(1, 0, 0, 58)
title.BackgroundTransparency = 1
title.Text = "Script Desactivado Temporalmente"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextTransparency = 1
title.TextScaled = true
title.Font = Enum.Font.GothamBlack
title.ZIndex = 16
title.Parent = content

local titleLimit = Instance.new("UITextSizeConstraint")
titleLimit.MaxTextSize = 42
titleLimit.MinTextSize = 20
titleLimit.Parent = title

local titleGradient = Instance.new("UIGradient")
titleGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.62, Color3.fromRGB(245, 246, 252)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 112, 124))
})
titleGradient.Rotation = 0
titleGradient.Parent = title

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.LayoutOrder = 4
subtitle.Size = UDim2.new(1, 0, 0, 34)
subtitle.BackgroundTransparency = 1
subtitle.Text = "TheRealBanHammer - Desarrrollador de este script"
subtitle.TextColor3 = Color3.fromRGB(255, 196, 203)
subtitle.TextTransparency = 1
subtitle.TextScaled = true
subtitle.Font = Enum.Font.Garamond
subtitle.ZIndex = 16
subtitle.Parent = content

local subtitleLimit = Instance.new("UITextSizeConstraint")
subtitleLimit.MaxTextSize = 27
subtitleLimit.MinTextSize = 14
subtitleLimit.Parent = subtitle

local divider = solidFrame("Divider", content, UDim2.new(0.2, 0, 0, 2), UDim2.fromScale(0, 0), Color3.fromRGB(255, 57, 76), 1, 16)
divider.LayoutOrder = 5
corner(divider, UDim.new(1, 0))

local message = Instance.new("TextLabel")
message.Name = "Message"
message.LayoutOrder = 6
message.Size = UDim2.new(0.9, 0, 0, 82)
message.BackgroundTransparency = 1
message.Text = "Este script ha sido desactivado temporalmente debido a la falta del pago correspondiente por parte del dueño."
message.TextColor3 = Color3.fromRGB(227, 230, 238)
message.TextTransparency = 1
message.TextScaled = true
message.TextWrapped = true
message.Font = Enum.Font.Gotham
message.LineHeight = 1.12
message.ZIndex = 16
message.Parent = content

local messageLimit = Instance.new("UITextSizeConstraint")
messageLimit.MaxTextSize = 24
messageLimit.MinTextSize = 14
messageLimit.Parent = message

local motto = Instance.new("TextLabel")
motto.Name = "Motto"
motto.LayoutOrder = 7
motto.Size = UDim2.new(1, 0, 0, 32)
motto.BackgroundTransparency = 1
motto.Text = "That's not cool"
motto.TextColor3 = Color3.fromRGB(255, 255, 255)
motto.TextTransparency = 1
motto.TextScaled = true
motto.Font = Enum.Font.Code
motto.ZIndex = 16
motto.Parent = content

local mottoLimit = Instance.new("UITextSizeConstraint")
mottoLimit.MaxTextSize = 18
mottoLimit.MinTextSize = 12
mottoLimit.Parent = motto

local okButton = Instance.new("TextButton")
okButton.Name = "OkButton"
okButton.AnchorPoint = Vector2.new(0.5, 1)
okButton.Position = UDim2.new(0.5, 0, 1, -34)
okButton.Size = UDim2.new(0, 242, 0, 58)
okButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
okButton.BackgroundTransparency = 1
okButton.BorderSizePixel = 0
okButton.AutoButtonColor = false
okButton.Text = "OK"
okButton.TextColor3 = Color3.fromRGB(18, 20, 27)
okButton.TextTransparency = 1
okButton.TextSize = 21
okButton.Font = Enum.Font.GothamBlack
okButton.ZIndex = 40
okButton.Parent = root
corner(okButton, UDim.new(0, 21))

local buttonStroke = stroke(okButton, Color3.fromRGB(255, 68, 86), 1, 1.5)
local buttonScale = Instance.new("UIScale")
buttonScale.Scale = 0.88
buttonScale.Parent = okButton

local buttonGradient = Instance.new("UIGradient")
buttonGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 220, 224))
})
buttonGradient.Rotation = 90
buttonGradient.Parent = okButton

local function kickPlayer()
	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
	LocalPlayer:Kick("No se completó el pago para este script - Deuda Loky\nBan Expiration: Permanent")
end

local red = Color3.fromRGB(255, 31, 51)
local deepRed = Color3.fromRGB(190, 0, 25)
local skullIntroDelay = 0.34

tween(blur, 0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Size = 22 })
tween(backgroundGradient, 9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, { Rotation = 150 }, -1, true)
tween(leftGlow, 3.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, { BackgroundTransparency = 0.72, Size = UDim2.fromOffset(590, 590) }, -1, true)
tween(rightGlow, 3.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, { BackgroundTransparency = 0.78, Size = UDim2.fromOffset(690, 690) }, -1, true)
tween(panel, 0.72, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { BackgroundTransparency = 0.88 })
tween(panelStroke, 0.72, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Transparency = 0.5 })
tween(panelScale, 0.86, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
tween(iconScale, 0.9, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
tween(aura, 0.92, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { BackgroundTransparency = 0.86, Size = UDim2.fromOffset(152, 152) })
tween(ringAStroke, 0.9, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Transparency = 0.54 })
tween(ringBStroke, 1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Transparency = 0.66 })
tween(warning, 0.52, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { TextTransparency = 0.18 }, 0, false, 0.16)
tween(title, 0.62, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { TextTransparency = 0 }, 0, false, 0.25)
tween(subtitle, 0.62, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { TextTransparency = 0.04 }, 0, false, 0.33)
tween(divider, 0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { BackgroundTransparency = 0.18, Size = UDim2.new(0.28, 0, 0, 2) }, 0, false, 0.39)
tween(message, 0.64, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { TextTransparency = 0.06 }, 0, false, 0.45)
tween(motto, 0.64, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { TextTransparency = 0.68 }, 0, false, 0.55)
tween(okButton, 0.62, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { BackgroundTransparency = 0.04, TextTransparency = 0 }, 0, false, 0.62)
tween(buttonStroke, 0.62, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Transparency = 0.34 }, 0, false, 0.62)
tween(buttonScale, 0.72, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 }, 0, false, 0.62)
tween(titleGradient, 3.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, { Rotation = 8 }, -1, true)
tween(iconWrap, 1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, { Rotation = 2 }, -1, true, 0.4)
tween(ringA, 2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, { Size = UDim2.fromOffset(130, 130) }, -1, true)
tween(ringB, 2.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, { Size = UDim2.fromOffset(102, 102) }, -1, true, 0.22)

task.delay(skullIntroDelay, function()
	for _, piece in ipairs(skullParts) do
		tween(piece, 1.2, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut, { BackgroundColor3 = red })
	end
	tween(head, 1.2, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut, { BackgroundColor3 = Color3.fromRGB(255, 43, 62) })
	tween(jaw, 1.2, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut, { BackgroundColor3 = deepRed })
	tween(aura, 1.3, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut, { BackgroundTransparency = 0.73, BackgroundColor3 = red })
	tween(ringAStroke, 1.2, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut, { Color = red, Transparency = 0.2 })
	tween(ringBStroke, 1.2, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut, { Color = Color3.fromRGB(255, 110, 121), Transparency = 0.38 })
end)

okButton.MouseEnter:Connect(function()
	tween(okButton, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { BackgroundColor3 = red, TextColor3 = Color3.fromRGB(255, 255, 255) })
	tween(buttonStroke, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Transparency = 0.06, Color = Color3.fromRGB(255, 255, 255) })
	tween(buttonScale, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1.045 })
end)

okButton.MouseLeave:Connect(function()
	tween(okButton, 0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { BackgroundColor3 = Color3.fromRGB(255, 255, 255), TextColor3 = Color3.fromRGB(18, 20, 27) })
	tween(buttonStroke, 0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Transparency = 0.34, Color = Color3.fromRGB(255, 68, 86) })
	tween(buttonScale, 0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
end)

okButton.Activated:Connect(function()
	okButton.Active = false
	okButton.AutoButtonColor = false
	tween(okButton, 0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { BackgroundColor3 = Color3.fromRGB(120, 0, 18), TextColor3 = Color3.fromRGB(255, 255, 255) })
	tween(buttonScale, 0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Scale = 0.94 })
	task.wait(0.13)
	kickPlayer()
end)
