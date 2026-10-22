-- Режим обустройства дома (как в Sims): каталог мебели внизу экрана,
-- «призрак» вещи следует за курсором и подсвечивается зелёным/красным,
-- R — повернуть, ЛКМ — поставить, клик по своей мебели — переставить,
-- Delete — продать выбранную вещь, Esc — выйти. На телефоне — кнопки.
-- Сервер повторно проверяет каждое действие (Furniture.Check).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Furniture = require(Shared:WaitForChild("Furniture"))

local HomeEditor = {}

local H = Config.Home

local active = nil -- состояние текущей сессии

local function baseCFrame(home)
	return CFrame.new(home.Base.X, 0, home.Base.Z) * CFrame.Angles(0, math.rad(home.Base.Yaw), 0)
end

local function houseModel(home)
	for _, m in workspace:GetDescendants() do
		if m:IsA("Model") and m.Name == "Furniture" and m.Parent and m.Parent.Name == "House" .. home.HouseId then
			return m
		end
	end
	return nil
end

local function makeGhost(id)
	local model = Furniture.Build(id, CFrame.new())
	if not model then
		return nil
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			if p.Name ~= "Hitbox" then
				p.Transparency = math.max(p.Transparency, 0.35)
			end
		elseif p:IsA("PointLight") then
			p.Enabled = false
		end
	end
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 0.6
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = model
	model.Parent = workspace
	return model, hl
end

local function setHidden(model, hidden)
	if not model then
		return
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

local function clearHolding()
	local a = active
	if a.Ghost then
		a.Ghost:Destroy()
	end
	setHidden(a.MovingModel, false)
	a.Ghost, a.Highlight, a.HoldId, a.MoveIndex, a.MovingModel = nil, nil, nil, nil, nil
	a.Refresh()
end

local function hold(id, moveIndex, movingModel)
	local a = active
	if a.Ghost then
		clearHolding()
	end
	a.HoldId = id
	a.MoveIndex = moveIndex
	a.MovingModel = movingModel
	a.Ghost, a.Highlight = makeGhost(id)
	if moveIndex then
		local e = a.Home.Items[moveIndex]
		a.Rotation = e and e.R or 0
		setHidden(movingModel, true)
	end
	a.Refresh()
end

-- Точка на полу участка под курсором (в координатах участка).
local function pointerLocal()
	local a = active
	local cam = workspace.CurrentCamera
	if not cam then
		return nil
	end
	local pos = UserInputService:GetMouseLocation()
	local ray = cam:ViewportPointToRay(pos.X, pos.Y)
	local item = H.Items[a.HoldId]
	local y = H.FloorY[item and item.Zone == "out" and "Out" or "In"]
	if math.abs(ray.Direction.Y) < 1e-4 then
		return nil
	end
	local t = (y - ray.Origin.Y) / ray.Direction.Y
	if t <= 0 or t > 400 then
		return nil
	end
	local world = ray.Origin + ray.Direction * t
	local l = a.Base:PointToObjectSpace(world)
	return Furniture.Snap(l.X), Furniture.Snap(l.Z)
end

local function update()
	local a = active
	if not a or not a.Ghost then
		return
	end
	local x, z = pointerLocal()
	if not x then
		return
	end
	a.X, a.Z = x, z
	local entry = { Id = a.HoldId, X = x, Z = z, R = a.Rotation }
	a.Ghost:PivotTo(Furniture.ItemCFrame(a.Base, entry))
	local ok, reason = Furniture.Check(a.Home.Items, a.HoldId, x, z, a.Rotation, a.MoveIndex)
	a.Valid, a.Reason = ok, reason
	a.Highlight.FillColor = ok and Color3.fromRGB(80, 220, 110) or Color3.fromRGB(235, 70, 70)
	a.Highlight.OutlineColor = a.Highlight.FillColor
	a.Hint.Text = ok and a.HintText or ("⛔ " .. tostring(reason))
end

local function confirm()
	local a = active
	if not a.Ghost then
		return
	end
	update()
	if not a.Valid then
		a.Notify(a.Reason or "Сюда нельзя.", "bad")
		return
	end
	if a.MoveIndex then
		a.Send("HomeMove", { Index = a.MoveIndex, X = a.X, Z = a.Z, R = a.Rotation })
		-- Модель вернётся видимой после перерисовки сервером.
		a.MovingModel = nil
		clearHolding()
	else
		a.Send("HomePlace", { Item = a.HoldId, X = a.X, Z = a.Z, R = a.Rotation })
		-- Призрак остаётся — удобно ставить несколько одинаковых вещей.
	end
end

local function rotate()
	local a = active
	a.Rotation = (a.Rotation + 1) % 4
	update()
end

local function sellSelected()
	local a = active
	if a.MoveIndex then
		local index = a.MoveIndex
		a.MovingModel = nil
		clearHolding()
		a.Send("HomeSell", { Index = index })
	end
end

-- Клик по своей мебели: взять её для перестановки.
local function pick()
	local a = active
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local pos = UserInputService:GetMouseLocation()
	local ray = cam:ViewportPointToRay(pos.X, pos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local folder = houseModel(a.Home)
	if not folder then
		return
	end
	params.FilterDescendantsInstances = { folder }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	local model = hit and hit.Instance:FindFirstAncestorWhichIsA("Model")
	while model and model.Parent ~= folder do
		model = model.Parent and model.Parent:FindFirstAncestorWhichIsA("Model")
	end
	local index = model and model:GetAttribute("FurnIndex")
	local entry = index and a.Home.Items[index]
	if entry then
		hold(entry.Id, index, model)
	end
end

function HomeEditor.Active()
	return active ~= nil
end

-- Новые данные дома от сервера (после каждой покупки/перестановки).
function HomeEditor.Update(home)
	if active then
		active.Home = home
		active.Base = baseCFrame(home)
		active.Refresh()
		update()
	end
end

function HomeEditor.Stop()
	local a = active
	if not a then
		return
	end
	if a.Ghost then
		a.Ghost:Destroy()
	end
	setHidden(a.MovingModel, false)
	for _, c in a.Connections do
		c:Disconnect()
	end
	a.Gui:Destroy()
	active = nil
end

-- env: { Gui, Ui, Send, Notify, Home, Scale }
function HomeEditor.Start(env)
	if active then
		HomeEditor.Stop()
	end
	local Ui, home = env.Ui, env.Home
	if not home or (home.HouseId or 0) == 0 then
		env.Notify("Сначала купите дом в агентстве недвижимости (мэрия).", "bad")
		return
	end
	local T, new = Ui.Theme, Ui.new
	local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	local root = new("Frame", { Name = "HomeEditor", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = env.Gui })
	local a = {
		Home = home,
		Base = baseCFrame(home),
		Rotation = 0,
		Category = H.Categories[1],
		Send = env.Send,
		Notify = env.Notify,
		Gui = root,
		Connections = {},
		HintText = isTouch and "Наведите и нажмите ✓, ⟳ — повернуть" or "ЛКМ — поставить • R — повернуть • ПКМ — отмена",
	}
	active = a

	local top = Ui.panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(640, 64), Parent = root })
	if env.Scale then
		env.Scale(top)
	end
	local title = Ui.label({ Font = Enum.Font.GothamBold, TextSize = 17, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -140, 0, 24), Parent = top })
	a.Hint = Ui.label({ TextSize = 14, TextColor3 = T.Sub, Position = UDim2.fromOffset(14, 32), Size = UDim2.new(1, -140, 0, 24), Parent = top })
	Ui.button("✕ Готово", T.Bad, HomeEditor.Stop, { Position = UDim2.new(1, -120, 0.5, -17), Size = UDim2.fromOffset(110, 34), Parent = top })

	local bottom = Ui.panel({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(900, 210), Parent = root })
	if env.Scale then
		env.Scale(bottom)
	end
	local cats = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 30), Parent = bottom }, { Ui.list(6, true) })
	local list = Ui.scroll({ Position = UDim2.fromOffset(10, 44), Size = UDim2.new(1, -20, 1, -98), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X, Parent = bottom })
	Ui.list(8, true).Parent = list
	local actions = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 10, 1, -48), Size = UDim2.new(1, -20, 0, 40), Parent = bottom }, { Ui.list(8, true) })

	function a.Refresh()
		if not active or active ~= a then
			return
		end
		local count = #a.Home.Items
		title.Text = "🏠 Обустройство дома №" .. a.Home.HouseId .. "   •   Уют: " .. (a.Home.Comfort or 0) .. "/100   •   Вещей: " .. count .. "/" .. H.MaxItems
		if not a.Ghost then
			a.Hint.Text = isTouch and "Выберите вещь в каталоге или нажмите на свою мебель, чтобы переставить её." or "Выберите вещь в каталоге или кликните по своей мебели, чтобы переставить. Esc — выйти."
		end
		Ui.clear(cats)
		for i, cat in H.Categories do
			Ui.button(cat, cat == a.Category and T.Accent or T.Bg3, function()
				a.Category = cat
				a.Refresh()
			end, { LayoutOrder = i, Size = UDim2.fromOffset(math.max(90, #cat * 6 + 30), 30), TextSize = 13, Parent = cats })
		end
		Ui.clear(list)
		local ids = {}
		for id, item in H.Items do
			if item.Cat == a.Category then
				table.insert(ids, id)
			end
		end
		table.sort(ids, function(x, y)
			local ix, iy = H.Items[x], H.Items[y]
			return (ix.Price or ix.Robux * 100) < (iy.Price or iy.Robux * 100)
		end)
		for i, id in ids do
			local item = H.Items[id]
			local card = new("TextButton", { LayoutOrder = i, Text = "", AutoButtonColor = true, BackgroundColor3 = a.HoldId == id and not a.MoveIndex and T.Accent or T.Bg2, Size = UDim2.fromOffset(150, 100), Parent = list }, { Ui.corner(8) })
			Ui.label({ Text = item.Name, Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 36), Parent = card })
			local useText = item.Use and ("✨ " .. (item.Use.Text or "")) or ("Уют +" .. (item.Comfort or 0))
			Ui.label({ Text = useText, TextSize = 11, TextColor3 = T.Sub, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(6, 44), Size = UDim2.new(1, -12, 0, 28), Parent = card })
			local price
			if item.Robux then
				price = (a.Home.Unlocked and a.Home.Unlocked[id]) and "⭐ Ваше" or ("R$ " .. item.Robux)
			else
				price = Ui.money(item.Price)
			end
			Ui.label({ Text = price, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = item.Robux and Color3.fromRGB(120, 230, 160) or T.Warn, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 6, 1, -24), Size = UDim2.new(1, -12, 0, 20), Parent = card })
			card.MouseButton1Click:Connect(function()
				if item.Robux and not (a.Home.Unlocked and a.Home.Unlocked[id]) then
					a.Send("BuyProduct", { Key = "Furn_" .. id })
					return
				end
				hold(id)
			end)
		end
		Ui.clear(actions)
		if a.Ghost then
			if isTouch then
				Ui.button("✓ Поставить", T.Good, confirm, { LayoutOrder = 1, Size = UDim2.fromOffset(140, 40), Parent = actions })
			end
			Ui.button("⟳ Повернуть [R]", T.Bg3, rotate, { LayoutOrder = 2, Size = UDim2.fromOffset(150, 40), Parent = actions })
			if a.MoveIndex then
				local item = H.Items[a.HoldId]
				local refund = item.Price and ("+" .. Ui.money(item.Price * H.SellRefund)) or "на склад"
				Ui.button("Продать (" .. refund .. ") [Del]", T.Bad, sellSelected, { LayoutOrder = 3, Size = UDim2.fromOffset(220, 40), Parent = actions })
			end
			Ui.button("Отмена", T.Bg3, clearHolding, { LayoutOrder = 4, Size = UDim2.fromOffset(110, 40), Parent = actions })
		else
			Ui.label({ Text = "💡 Уют дома ускоряет сон, душ и отдых (до ×2). Вещи с ✨ приносят пользу: еда, навыки, настроение.", TextSize = 13, TextColor3 = T.Sub, Size = UDim2.fromOffset(760, 40), Parent = actions })
		end
	end

	table.insert(a.Connections, RunService.RenderStepped:Connect(update))
	table.insert(a.Connections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed or active ~= a then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			rotate()
		elseif input.KeyCode == Enum.KeyCode.Escape then
			if a.Ghost then
				clearHolding()
			else
				HomeEditor.Stop()
			end
		elseif input.KeyCode == Enum.KeyCode.Delete or input.KeyCode == Enum.KeyCode.X then
			sellSelected()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			if a.Ghost then
				clearHolding()
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if a.Ghost then
				if not isTouch then
					confirm()
				end
			else
				pick()
			end
		end
	end))
	a.Refresh()
end

return HomeEditor
