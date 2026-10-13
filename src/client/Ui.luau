-- Маленькая библиотека для построения интерфейса из кода.

local Ui = {}

Ui.Theme = {
	Bg = Color3.fromRGB(22, 24, 32),
	Bg2 = Color3.fromRGB(34, 37, 50),
	Bg3 = Color3.fromRGB(48, 52, 70),
	Accent = Color3.fromRGB(90, 160, 255),
	Good = Color3.fromRGB(70, 190, 110),
	Bad = Color3.fromRGB(220, 75, 75),
	Warn = Color3.fromRGB(235, 170, 50),
	Pink = Color3.fromRGB(240, 100, 160),
	Text = Color3.fromRGB(245, 245, 250),
	Sub = Color3.fromRGB(170, 175, 195),
	Disabled = Color3.fromRGB(80, 82, 95),
}
local T = Ui.Theme

function Ui.new(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in props or {} do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, c in children or {} do
		c.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
local new = Ui.new

function Ui.corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 8) })
end

function Ui.padding(p)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, p),
		PaddingRight = UDim.new(0, p),
		PaddingTop = UDim.new(0, p),
		PaddingBottom = UDim.new(0, p),
	})
end

function Ui.list(spacing, horizontal)
	return new("UIListLayout", {
		Padding = UDim.new(0, spacing or 6),
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Ui.label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextColor3 = T.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 22),
	}
	for k, v in props do
		defaults[k] = v
	end
	return new("TextLabel", defaults)
end

function Ui.button(text, color, onClick, props)
	local defaults = {
		Text = text,
		BackgroundColor3 = color or T.Accent,
		Font = Enum.Font.GothamBold,
		TextColor3 = T.Text,
		TextSize = 15,
		AutoButtonColor = true,
		Size = UDim2.new(1, 0, 0, 34),
	}
	for k, v in props or {} do
		defaults[k] = v
	end
	local b = new("TextButton", defaults, { Ui.corner(6) })
	if onClick then
		b.MouseButton1Click:Connect(onClick)
	end
	return b
end

function Ui.panel(props, children)
	local defaults = {
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}
	for k, v in props or {} do
		defaults[k] = v
	end
	local f = new("Frame", defaults, children)
	Ui.corner(10).Parent = f
	return f
end

function Ui.scroll(props)
	local defaults = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Size = UDim2.fromScale(1, 1),
	}
	for k, v in props or {} do
		defaults[k] = v
	end
	return new("ScrollingFrame", defaults)
end

-- Полоска прогресса (0..1).
function Ui.bar(parent, color, height)
	local bg = new("Frame", { BackgroundColor3 = T.Bg3, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, height or 10), Parent = parent }, { Ui.corner(5) })
	local fill = new("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.fromScale(0.5, 1), Parent = bg }, { Ui.corner(5) })
	return bg, fill
end

function Ui.clear(container)
	for _, c in container:GetChildren() do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") and not c:IsA("UIGridLayout") then
			c:Destroy()
		end
	end
end

function Ui.money(n)
	local s = tostring(math.floor(n or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (out:gsub("^ ", "")) .. "$"
end

return Ui
