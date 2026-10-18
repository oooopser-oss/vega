-- Клиент «Жизнь Города»: HUD, потребности, телефон, меню ролей, магазины,
-- банк, автосалон, задания работы, GPS, отношения и уведомления.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local CarController = require(script.Parent:WaitForChild("CarController"))
local Ambient = require(script.Parent:WaitForChild("Ambient"))
local Weather = require(script.Parent:WaitForChild("Weather"))
local MiniGames = require(script.Parent:WaitForChild("MiniGames"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ActionRemote = Remotes:WaitForChild("Action")
local EventRemote = Remotes:WaitForChild("Event")

local new, T = Ui.new, Ui.Theme

local function send(name, payload)
	ActionRemote:FireServer(name, payload or {})
end

local state = {
	Inventory = {},
	Relations = {},
	Partner = nil,
	Cars = {},
	GPS = {},
	Task = nil,
	PhoneTab = "Задания",
	Quests = {},
	Wardrobe = { Owned = {}, Outfit = {} },
	Progress = { Skills = {}, Education = { School = 0, College = 0 }, Records = {} },
	Course = nil,
	SelectedPerson = nil,
}

local gui = new("ScreenGui", {
	Name = "LifeCityUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Масштаб интерфейса под размер экрана (телефоны/планшеты).
local scaled = {}
local function currentScale()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	return math.clamp(math.min(vp.X / 1150, vp.Y / 680), 0.55, 1)
end
local function scaleIt(frame)
	local s = new("UIScale", { Scale = currentScale(), Parent = frame })
	table.insert(scaled, s)
	return frame
end
task.spawn(function()
	while true do
		task.wait(1)
		local sc = currentScale()
		for i = #scaled, 1, -1 do
			local s = scaled[i]
			if s.Parent then
				s.Scale = sc
			else
				table.remove(scaled, i)
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Уведомления
---------------------------------------------------------------------------
local notifyHolder = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.fromOffset(460, 400),
	Parent = gui,
}, { Ui.list(6) })
scaleIt(notifyHolder)

local KIND_COLORS = { good = T.Good, bad = T.Bad, warn = T.Warn, info = T.Accent }
local notifyCount = 0

local function notify(text, kind)
	notifyCount += 1
	local children = notifyHolder:GetChildren()
	local frames = {}
	for _, c in children do
		if c:IsA("Frame") then
			table.insert(frames, c)
		end
	end
	if #frames >= 5 then
		table.sort(frames, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		frames[1]:Destroy()
	end
	local f = Ui.panel({
		LayoutOrder = notifyCount,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = notifyHolder,
	})
	new("Frame", { BackgroundColor3 = KIND_COLORS[kind] or T.Accent, BorderSizePixel = 0, Size = UDim2.new(0, 5, 1, 0), Parent = f })
	Ui.label({
		Text = text,
		Size = UDim2.new(1, -20, 0, 0),
		Position = UDim2.fromOffset(14, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 15,
		Parent = f,
	}, nil)
	Ui.padding(6).Parent = f
	task.delay(6, function()
		if f.Parent then
			TweenService:Create(f, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			task.wait(0.4)
			f:Destroy()
		end
	end)
end

---------------------------------------------------------------------------
-- HUD: деньги, роль, время, потребности
---------------------------------------------------------------------------
local hud = Ui.panel({
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, -12),
	Size = UDim2.fromOffset(300, 282),
	Parent = gui,
})
scaleIt(hud)
Ui.padding(10).Parent = hud
Ui.list(4).Parent = hud

local cashLabel = Ui.label({ LayoutOrder = 1, Font = Enum.Font.GothamBold, TextSize = 20, Text = "💵 0$", TextColor3 = Color3.fromRGB(130, 230, 140), Parent = hud })
local bankLabel = Ui.label({ LayoutOrder = 2, TextSize = 15, Text = "💳 Карта: 0$", TextColor3 = T.Sub, Parent = hud })
local roleLabel = Ui.label({ LayoutOrder = 3, TextSize = 15, Font = Enum.Font.GothamBold, Text = "", Parent = hud })
local clockLabel = Ui.label({ LayoutOrder = 4, TextSize = 14, Text = "", TextColor3 = T.Sub, Parent = hud })
local weatherLabel = Ui.label({ LayoutOrder = 4, TextSize = 13, Text = "", TextColor3 = Color3.fromRGB(170, 210, 255), Parent = hud })
local questLabel = Ui.label({ LayoutOrder = 5, TextSize = 14, Text = "", TextColor3 = Color3.fromRGB(255, 215, 110), Parent = hud })

local needBars = {}
for i, need in Config.NeedOrder do
	local info = Config.Needs[need]
	local row = new("Frame", { LayoutOrder = 10 + i, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), Parent = hud })
	Ui.label({ Text = info.Name, TextSize = 13, Size = UDim2.new(1, 0, 0, 14), TextColor3 = T.Sub, Parent = row })
	local value = Ui.label({ Text = "100", TextSize = 13, Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = T.Sub, Parent = row })
	local bg, fill = Ui.bar(row, info.Color, 10)
	bg.Position = UDim2.fromOffset(0, 16)
	needBars[need] = { Fill = fill, Value = value, Color = info.Color }
end

local function refreshHud()
	cashLabel.Text = "💵 " .. Ui.money(player:GetAttribute("Cash"))
	bankLabel.Text = "💳 Карта: " .. Ui.money(player:GetAttribute("Bank"))
	local role = Config.Roles[player:GetAttribute("Role") or "Citizen"]
	local job = Config.Jobs[player:GetAttribute("Job") or ""]
	if role then
		roleLabel.Text = role.Name .. (job and (" • " .. job.Name) or " • без работы")
		roleLabel.TextColor3 = role.Color:Lerp(Color3.new(1, 1, 1), 0.4)
	end
	local qd, qt = player:GetAttribute("QuestsDone") or 0, player:GetAttribute("QuestsTotal") or 0
	questLabel.Text = qt > 0 and ("📅 Задания дня: " .. qd .. "/" .. qt .. (qd >= qt and " ✅" or " — телефон [M]")) or ""
	for need, bar in needBars do
		local v = player:GetAttribute(need) or 0
		bar.Fill.Size = UDim2.fromScale(math.clamp(v / 100, 0, 1), 1)
		bar.Value.Text = tostring(math.floor(v))
		bar.Fill.BackgroundColor3 = v < 20 and T.Bad or bar.Color
	end
end
player.AttributeChanged:Connect(refreshHud)
refreshHud()

-- Верхняя панель: задание / тюрьма / розыск.
local topBar = Ui.panel({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.fromOffset(460, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Visible = false,
	Parent = gui,
})
scaleIt(topBar)
Ui.padding(8).Parent = topBar
local topLabel = Ui.label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold, TextSize = 16, Parent = topBar })

-- Спидометр.
local speedo = Ui.panel({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -90), Size = UDim2.fromOffset(160, 50), Visible = false, Parent = gui })
scaleIt(speedo)
local speedLabel = Ui.label({ Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold, TextSize = 24, Parent = speedo })

---------------------------------------------------------------------------
-- Кнопки справа
---------------------------------------------------------------------------
local side = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 0),
	Size = UDim2.fromOffset(150, 220),
	Parent = gui,
}, { Ui.list(8) })
scaleIt(side)

local openPhone, openRoleMenu -- объявим ниже
Ui.button("📱 Телефон [M]", T.Accent, function()
	openPhone()
end, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 44), Parent = side })
Ui.button("🎭 Роль", T.Bg3, function()
	openRoleMenu(false)
end, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 38), Parent = side })
local standButton = Ui.button("⬆ Встать [Пробел]", T.Warn, function()
	send("StopActivity")
end, { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 38), Visible = false, Parent = side })

player:GetAttributeChangedSignal("Activity"):Connect(function()
	local a = player:GetAttribute("Activity") or ""
	standButton.Visible = a ~= ""
	standButton.Text = a ~= "" and ("⬆ " .. a .. ": встать") or ""
end)
UserInputService.JumpRequest:Connect(function()
	if (player:GetAttribute("Activity") or "") ~= "" then
		send("StopActivity")
	end
end)

---------------------------------------------------------------------------
-- Маркеры в мире (задание, GPS, тревоги)
---------------------------------------------------------------------------
local markers = {}

local function clearMarker(key)
	local m = markers[key]
	if not m then
		return
	end
	for _, inst in m.Instances do
		inst:Destroy()
	end
	markers[key] = nil
end

local function buildMarker(key, spec)
	local m = { Spec = spec, Instances = {} }
	markers[key] = m
	local target = spec.Target
	local att1
	if typeof(target) == "Instance" then
		if not target.Parent then
			return
		end
		att1 = new("Attachment", { Name = "LifeMarker", Parent = target })
		local hl = new("Highlight", { FillColor = spec.Color, OutlineColor = spec.Color, FillTransparency = 0.6, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Adornee = target, Parent = target })
		table.insert(m.Instances, hl)
	else
		att1 = new("Attachment", { Name = "LifeMarker", WorldPosition = target, Parent = workspace.Terrain })
	end
	table.insert(m.Instances, att1)
	local bb = new("BillboardGui", { Size = UDim2.fromOffset(200, 46), StudsOffset = Vector3.new(0, 4, 0), AlwaysOnTop = true, Adornee = att1, Parent = gui })
	local text = Ui.label({ Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = spec.Color, TextStrokeTransparency = 0.3, Text = spec.Text, Parent = bb })
	m.Text = text
	table.insert(m.Instances, bb)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		local att0 = new("Attachment", { Name = "LifeBeam", Parent = hrp })
		local beam = new("Beam", {
			Attachment0 = att0,
			Attachment1 = att1,
			Color = ColorSequence.new(spec.Color),
			Transparency = NumberSequence.new(0.3, 0.7),
			Width0 = 0.4,
			Width1 = 0.4,
			FaceCamera = true,
			Segments = 1,
			Parent = att1.Parent,
		})
		table.insert(m.Instances, att0)
		table.insert(m.Instances, beam)
	end
	m.Attachment = att1
end

local function setMarker(key, target, text, color, ttl)
	clearMarker(key)
	if not target then
		return
	end
	local spec = { Target = target, Text = text, Color = color, Expires = ttl and (os.clock() + ttl) or nil }
	buildMarker(key, spec)
end

player.CharacterAdded:Connect(function(char)
	char:WaitForChild("HumanoidRootPart", 10)
	local specs = {}
	for key, m in markers do
		specs[key] = m.Spec
	end
	for key, spec in specs do
		clearMarker(key)
		buildMarker(key, spec)
	end
end)

---------------------------------------------------------------------------
-- Модальные окна
---------------------------------------------------------------------------
local modal
local modalName

local function closeModal()
	if modal then
		modal:Destroy()
		modal = nil
		modalName = nil
	end
end

local function openWindow(name, title, w, h, canClose)
	closeModal()
	local win = Ui.panel({
		Size = UDim2.fromOffset(w, h),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 0.04,
		Parent = gui,
	})
	scaleIt(win)
	Ui.label({ Text = title, Font = Enum.Font.GothamBold, TextSize = 20, Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -70, 0, 28), Parent = win })
	if canClose ~= false then
		Ui.button("✕", T.Bad, closeModal, { Size = UDim2.fromOffset(34, 30), Position = UDim2.new(1, -44, 0, 9), Parent = win })
	end
	local body = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 48), Size = UDim2.new(1, -24, 1, -60), Parent = win })
	modal = win
	modalName = name
	return win, body
end

local function effectsText(effects)
	if not effects then
		return ""
	end
	local parts = {}
	for _, need in Config.NeedOrder do
		if effects[need] then
			table.insert(parts, Config.Needs[need].Name .. " +" .. effects[need])
		end
	end
	return table.concat(parts, ", ")
end

local function row(parent, order, height)
	local f = new("Frame", { LayoutOrder = order, BackgroundColor3 = T.Bg2, BorderSizePixel = 0, Size = UDim2.new(1, -8, 0, height or 52), Parent = parent }, { Ui.corner(8) })
	return f
end

---------------------------------------------------------------------------
-- Меню выбора роли
---------------------------------------------------------------------------
function openRoleMenu(first)
	local canClose = player:GetAttribute("RoleChosen") == true
	local _, body = openWindow("Roles", first and ("Добро пожаловать в «" .. Config.GameName .. "»! Кем вы будете?") or "Выбор роли", 800, 470, canClose)
	local grid = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = body })
	new("UIGridLayout", { CellSize = UDim2.new(0.2, -8, 1, -4), CellPadding = UDim2.fromOffset(8, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	for i, roleId in Config.RoleOrder do
		local role = Config.Roles[roleId]
		local count = 0
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("Role") == roleId then
				count += 1
			end
		end
		local card = new("Frame", { LayoutOrder = i, BackgroundColor3 = T.Bg2, BorderSizePixel = 0, Parent = grid }, { Ui.corner(10) })
		new("Frame", { BackgroundColor3 = role.Color, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 10), Parent = card }, { Ui.corner(4) })
		Ui.label({ Text = role.Name, Font = Enum.Font.GothamBold, TextSize = 17, Position = UDim2.fromOffset(8, 18), Size = UDim2.new(1, -16, 0, 40), TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
		Ui.label({ Text = role.Description, TextSize = 13, TextColor3 = T.Sub, Position = UDim2.fromOffset(8, 60), Size = UDim2.new(1, -16, 1, -150), TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
		local limit = role.MaxPlayers > 0 and ("/" .. role.MaxPlayers) or ""
		Ui.label({ Text = "Игроков: " .. count .. limit, TextSize = 13, TextColor3 = T.Sub, Position = UDim2.new(0, 8, 1, -82), Size = UDim2.new(1, -16, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
		local current = player:GetAttribute("Role") == roleId and canClose
		Ui.button(current and "Текущая" or "Выбрать", current and T.Disabled or role.Color, function()
			send("SelectRole", { Role = roleId })
		end, { Position = UDim2.new(0, 8, 1, -52), Size = UDim2.new(1, -16, 0, 40), Parent = card })
	end
end

---------------------------------------------------------------------------
-- Магазин, банк, автосалон
---------------------------------------------------------------------------
local function openShop(shopId)
	local shop = Config.Shops[shopId]
	if not shop then
		return
	end
	local _, body = openWindow("Shop", "🛒 " .. shop.Name, 470, 470)
	if shopId == "Supermarket" or shopId == "Kiosk" then
		local hasFish = false
		for itemId, n in state.Inventory do
			if Config.Items[itemId] and Config.Items[itemId].SellPrice and n > 0 then
				hasFish = true
			end
		end
		if hasFish then
			Ui.button("🎣 Продать улов", Color3.fromRGB(40, 140, 170), function()
				send("SellFish")
				closeModal()
			end, { Position = UDim2.new(1, -230, 0, -40), Size = UDim2.fromOffset(150, 30), TextSize = 13, Parent = body })
		end
	end
	local list = Ui.scroll({ Parent = body })
	Ui.list(6).Parent = list
	for i, itemId in shop.Items do
		local item = Config.Items[itemId]
		local r = row(list, i, 56)
		Ui.label({ Text = item.Name .. "  —  " .. item.Price .. "$", Font = Enum.Font.GothamBold, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -170, 0, 22), Parent = r })
		local desc = item.Effects and effectsText(item.Effects) or ""
		if item.Gift then
			desc = (desc ~= "" and (desc .. " • ") or "") .. "подарок"
		end
		if item.Passive then
			desc = item.Passive
		end
		Ui.label({ Text = desc, TextSize = 13, TextColor3 = T.Sub, Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -170, 0, 20), Parent = r })
		Ui.button("Купить", T.Good, function()
			send("BuyItem", { Shop = shopId, Item = itemId, Count = 1 })
		end, { Position = UDim2.new(1, -158, 0.5, -16), Size = UDim2.fromOffset(84, 32), Parent = r })
		Ui.button("×5", T.Bg3, function()
			send("BuyItem", { Shop = shopId, Item = itemId, Count = 5 })
		end, { Position = UDim2.new(1, -66, 0.5, -16), Size = UDim2.fromOffset(56, 32), Parent = r })
	end
end

local function openBank()
	local _, body = openWindow("Bank", "🏦 Банк", 380, 330)
	Ui.list(8).Parent = body
	local cash = Ui.label({ LayoutOrder = 1, TextSize = 17, Parent = body })
	local bank = Ui.label({ LayoutOrder = 2, TextSize = 17, Parent = body })
	local function upd()
		cash.Text = "💵 Наличные: " .. Ui.money(player:GetAttribute("Cash"))
		bank.Text = "💳 На карте: " .. Ui.money(player:GetAttribute("Bank"))
	end
	upd()
	local conn = player.AttributeChanged:Connect(upd)
	body.Destroying:Connect(function()
		conn:Disconnect()
	end)
	local box = new("TextBox", {
		LayoutOrder = 3,
		PlaceholderText = "Сумма",
		Text = "",
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = T.Bg3,
		TextColor3 = T.Text,
		Font = Enum.Font.Gotham,
		TextSize = 16,
		ClearTextOnFocus = false,
		Parent = body,
	}, { Ui.corner(6) })
	local btns = new("Frame", { LayoutOrder = 4, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), Parent = body }, { Ui.list(8, true) })
	Ui.button("Внести", T.Good, function()
		send("Bank", { Op = "deposit", Amount = tonumber(box.Text) or 0 })
	end, { Size = UDim2.new(0.5, -4, 1, 0), Parent = btns })
	Ui.button("Снять", T.Accent, function()
		send("Bank", { Op = "withdraw", Amount = tonumber(box.Text) or 0 })
	end, { Size = UDim2.new(0.5, -4, 1, 0), Parent = btns })
	Ui.button("Внести все наличные", T.Bg3, function()
		send("Bank", { Op = "deposit", Amount = player:GetAttribute("Cash") or 0 })
	end, { LayoutOrder = 5, Parent = body })
	Ui.label({ LayoutOrder = 6, TextSize = 12, TextColor3 = T.Sub, Size = UDim2.new(1, 0, 0, 34), Text = "Совет: храните деньги на карте — грабители и смерть не отнимут их.", Parent = body })
end

local function openDealer()
	local _, body = openWindow("Dealer", "🚗 Автосалон", 480, 360)
	local list = Ui.scroll({ Parent = body })
	Ui.list(6).Parent = list
	for i, carId in Config.CarOrder do
		local car = Config.Cars[carId]
		if car.Pass then
			continue
		end
		local r = row(list, i, 60)
		new("Frame", { BackgroundColor3 = car.Color, BorderSizePixel = 0, Position = UDim2.fromOffset(10, 14), Size = UDim2.fromOffset(32, 32), Parent = r }, { Ui.corner(6) })
		Ui.label({ Text = car.Name .. " — " .. Ui.money(car.Price), Font = Enum.Font.GothamBold, Position = UDim2.fromOffset(52, 8), Size = UDim2.new(1, -170, 0, 22), Parent = r })
		Ui.label({ Text = "Макс. скорость: " .. car.Speed, TextSize = 13, TextColor3 = T.Sub, Position = UDim2.fromOffset(52, 32), Size = UDim2.new(1, -170, 0, 20), Parent = r })
		local owned = state.Cars[carId]
		Ui.button(owned and "Есть" or "Купить", owned and T.Disabled or T.Good, function()
			if not owned then
				send("BuyCar", { Car = carId })
			end
		end, { Position = UDim2.new(1, -110, 0.5, -17), Size = UDim2.fromOffset(100, 34), Parent = r })
	end
end

---------------------------------------------------------------------------
-- Телефон
---------------------------------------------------------------------------
local TABS = { "Задания", "Навыки 🎓", "Работа", "Люди", "Вещи", "Одежда 👕", "Машины", "Дом", "GPS", "Магазин ⭐", "Помощь" }
local phoneContent
local renderTab

local function relationFor(userId)
	for _, r in state.Relations do
		if r.UserId == userId then
			return r
		end
	end
	return nil
end

local function section(parent, order, text)
	return Ui.label({ LayoutOrder = order, Text = text, Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = T.Accent, Parent = parent })
end

local renderers = {}

renderers["Задания"] = function(c)
	local q = state.Quests
	section(c, 1, "Задания на сегодня (обновляются каждый день)")
	for i, quest in q.List or {} do
		local r = row(c, 1 + i, 62)
		Ui.label({ Text = (quest.Done and "✅ " or "⬜ ") .. quest.Text, Font = Enum.Font.GothamBold, TextSize = 14, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -110, 0, 24), Parent = r })
		Ui.label({ Text = "+" .. Ui.money(quest.Reward), TextSize = 14, TextColor3 = Color3.fromRGB(130, 230, 140), Position = UDim2.new(1, -100, 0, 4), Size = UDim2.fromOffset(90, 24), TextXAlignment = Enum.TextXAlignment.Right, Parent = r })
		local bg, fill = Ui.bar(r, quest.Done and T.Good or T.Warn, 10)
		bg.Position = UDim2.new(0, 10, 0, 34)
		bg.Size = UDim2.new(1, -110, 0, 10)
		fill.Size = UDim2.fromScale(math.clamp(quest.Progress / math.max(quest.Goal, 1), 0, 1), 1)
		Ui.label({ Text = math.floor(quest.Progress) .. " / " .. quest.Goal, TextSize = 12, TextColor3 = T.Sub, Position = UDim2.new(1, -100, 0, 30), Size = UDim2.fromOffset(90, 18), TextXAlignment = Enum.TextXAlignment.Right, Parent = r })
	end
	Ui.label({ LayoutOrder = 20, TextSize = 13, TextColor3 = T.Sub, Size = UDim2.new(1, -8, 0, 54), Text = (q.BonusTaken and "🎉 Бонус дня получен!" or ("Выполните все задания — бонус +" .. Ui.money(q.Bonus or 0) .. ".")) .. "\nЕжедневный бонус за вход растёт с каждым днём подряд (серия: " .. (q.Streak or 0) .. ", до ×7).", Parent = c })
end

renderers["Магазин ⭐"] = function(c)
	local M = Config.Monetization
	section(c, 1, "Пассы (покупаются один раз навсегда)")
	for i, key in M.PassOrder do
		local pass = M.GamePasses[key]
		local owned = player:GetAttribute("Pass_" .. key) == true
		local r = row(c, 1 + i, 60)
		Ui.label({ Text = pass.Name, Font = Enum.Font.GothamBold, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -140, 0, 22), Parent = r })
		Ui.label({ Text = pass.Description, TextSize = 12, TextColor3 = T.Sub, Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -140, 0, 30), TextYAlignment = Enum.TextYAlignment.Top, Parent = r })
		Ui.button(owned and "Куплено" or ("R$ " .. pass.Robux), owned and T.Disabled or Color3.fromRGB(0, 160, 90), function()
			if not owned then
				send("BuyPass", { Key = key })
			end
		end, { Position = UDim2.new(1, -124, 0.5, -16), Size = UDim2.fromOffset(114, 32), Parent = r })
	end
	section(c, 10, "Игровые деньги и праздники")
	for i, key in M.ProductOrder do
		local product = M.Products[key]
		local r = row(c, 10 + i, 46)
		Ui.label({ Text = product.Name, Font = Enum.Font.GothamBold, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -140, 1, 0), Parent = r })
		Ui.button("R$ " .. product.Robux, Color3.fromRGB(0, 160, 90), function()
			send("BuyProduct", { Key = key })
		end, { Position = UDim2.new(1, -124, 0.5, -15), Size = UDim2.fromOffset(114, 30), Parent = r })
	end
	Ui.label({ LayoutOrder = 30, TextSize = 12, TextColor3 = T.Sub, Size = UDim2.new(1, -8, 0, 40), Text = "Покупки помогают развивать игру. Всё важное можно заработать в игре бесплатно.", Parent = c })
end

renderers["Работа"] = function(c)
	local role = Config.Roles[player:GetAttribute("Role") or "Citizen"]
	local current = player:GetAttribute("Job") or ""
	section(c, 1, "Профессии для роли «" .. role.Name .. "»")
	for i, jobId in role.Jobs do
		local job = Config.Jobs[jobId]
		local r = row(c, 1 + i, 56)
		Ui.label({ Text = job.Name, Font = Enum.Font.GothamBold, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -140, 0, 22), Parent = r })
		Ui.label({ Text = "≈" .. job.Pay .. "$ за задание", TextSize = 13, TextColor3 = T.Sub, Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -140, 0, 20), Parent = r })
		local isCurrent = current == jobId
		Ui.button(isCurrent and "Работаю" or "Устроиться", isCurrent and T.Disabled or T.Good, function()
			if not isCurrent then
				send("SelectJob", { Job = jobId })
			end
		end, { Position = UDim2.new(1, -124, 0.5, -16), Size = UDim2.fromOffset(114, 32), Parent = r })
	end
	if current ~= "" then
		Ui.button("Уволиться", T.Bad, function()
			send("QuitJob")
		end, { LayoutOrder = 50, Size = UDim2.new(1, -8, 0, 34), Parent = c })
	end
	Ui.label({ LayoutOrder = 60, TextSize = 13, TextColor3 = T.Sub, Size = UDim2.new(1, -8, 0, 76), Text = "После устройства появится жёлтая метка — идите к ней и удерживайте E. Между заданиями есть пауза, после " .. Config.Work.ShiftTasks .. " заданий — перерыв " .. math.floor(Config.Work.ShiftRest / 60) .. " мин. В сутки по полной ставке можно заработать " .. Config.Work.DailyCap .. "$, дальше оплата 25%. Работа тратит энергию.", Parent = c })
end

local function personActions(c, order, userId, name, online)
	local rel = relationFor(userId) or { Points = 0, Status = "none" }
	local box = row(c, order, 0)
	box.AutomaticSize = Enum.AutomaticSize.Y
	Ui.padding(8).Parent = box
	Ui.list(6).Parent = box
	Ui.label({ LayoutOrder = 1, Text = name .. (online and "" or " (не в сети)"), Font = Enum.Font.GothamBold, TextSize = 17, Parent = box })
	Ui.label({ LayoutOrder = 2, Text = (Config.Social.StatusNames[rel.Status] or "Знакомые") .. " • Симпатия: " .. math.floor(rel.Points) .. "/100", TextSize = 14, TextColor3 = T.Pink, Parent = box })
	local barRow = new("Frame", { LayoutOrder = 3, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 10), Parent = box })
	local _, fill = Ui.bar(barRow, T.Pink, 10)
	fill.Size = UDim2.fromScale(math.clamp(rel.Points / 100, 0, 1), 1)
	local grid = new("Frame", { LayoutOrder = 4, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = box })
	new("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 32), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	for i, actId in Config.Social.ActionOrder do
		local act = Config.Social.Actions[actId]
		local statusOk = not act.RequiresStatus or table.find(act.RequiresStatus, rel.Status) ~= nil
		local offlineOk = online or actId == "breakup" or actId == "divorce"
		if statusOk and offlineOk then
			local enough = rel.Points >= act.MinPoints
			local color = enough and T.Bg3 or T.Disabled
			if actId == "breakup" or actId == "divorce" then
				color = T.Bad
			elseif act.NeedsAccept and enough then
				color = T.Pink
			end
			Ui.button(act.Name .. (enough and "" or (" 🔒" .. act.MinPoints)), color, function()
				send("Social", { Target = userId, Act = actId })
			end, { LayoutOrder = i, TextSize = 12, TextWrapped = true, Parent = grid })
		end
	end
end

renderers["Люди"] = function(c)
	local myPos = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local order = 1
	if state.SelectedPerson then
		local sel = state.SelectedPerson
		local p = Players:GetPlayerByUserId(sel.UserId)
		personActions(c, order, sel.UserId, sel.Name, p ~= nil)
		order += 1
		Ui.button("← Назад к списку", T.Bg3, function()
			state.SelectedPerson = nil
			renderTab()
		end, { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 30), Parent = c })
		return
	end
	section(c, order, "Рядом с вами (подойдите к человеку, чтобы общаться)")
	local any = false
	for _, p in Players:GetPlayers() do
		local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if p ~= player and hrp and myPos and (hrp.Position - myPos.Position).Magnitude <= 30 then
			any = true
			order += 1
			local rel = relationFor(p.UserId)
			local role = Config.Roles[p:GetAttribute("Role") or "Citizen"]
			Ui.button(p.DisplayName .. " • " .. (role and role.Name or "") .. (rel and (" • ❤ " .. math.floor(rel.Points)) or ""), T.Bg3, function()
				state.SelectedPerson = { UserId = p.UserId, Name = p.DisplayName }
				renderTab()
			end, { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 36), Parent = c })
		end
	end
	if not any then
		order += 1
		Ui.label({ LayoutOrder = order, Text = "Никого рядом нет.", TextColor3 = T.Sub, TextSize = 14, Parent = c })
	end
	order += 1
	section(c, order, "Знакомые и отношения")
	if #state.Relations == 0 then
		order += 1
		Ui.label({ LayoutOrder = order, Text = "Пока ни с кем не знакомы. Подойдите к игроку и поговорите!", TextColor3 = T.Sub, TextSize = 14, Size = UDim2.new(1, -8, 0, 40), Parent = c })
	end
	for _, r in state.Relations do
		order += 1
		local online = Players:GetPlayerByUserId(r.UserId) ~= nil
		local status = Config.Social.StatusNames[r.Status] or ""
		local icon = r.Status == "married" and "💍 " or r.Status == "engaged" and "💎 " or r.Status == "dating" and "❤ " or ""
		Ui.button(icon .. r.Name .. (online and " 🟢" or " ⚪") .. " • " .. status .. " • " .. math.floor(r.Points) .. "/100", r.Status ~= "none" and T.Pink or T.Bg2, function()
			state.SelectedPerson = { UserId = r.UserId, Name = r.Name }
			renderTab()
		end, { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 36), TextSize = 14, Parent = c })
	end
end

renderers["Вещи"] = function(c)
	section(c, 1, "Инвентарь")
	local order = 1
	local ids = {}
	for itemId, count in state.Inventory do
		if count > 0 and Config.Items[itemId] then
			table.insert(ids, itemId)
		end
	end
	table.sort(ids)
	for _, itemId in ids do
		local item = Config.Items[itemId]
		order += 1
		local r = row(c, order, 52)
		Ui.label({ Text = item.Name .. " ×" .. state.Inventory[itemId], Font = Enum.Font.GothamBold, Position = UDim2.fromOffset(10, 5), Size = UDim2.new(1, -130, 0, 22), Parent = r })
		Ui.label({ Text = item.Effects and effectsText(item.Effects) or item.Passive or "Подарок — дарите в разделе «Люди»", TextSize = 13, TextColor3 = T.Sub, Position = UDim2.fromOffset(10, 27), Size = UDim2.new(1, -130, 0, 20), Parent = r })
		if item.Effects then
			Ui.button("Использовать", T.Good, function()
				send("UseItem", { Item = itemId })
			end, { Position = UDim2.new(1, -120, 0.5, -15), Size = UDim2.fromOffset(110, 30), TextSize = 13, Parent = r })
		end
	end
	if #ids == 0 then
		Ui.label({ LayoutOrder = 2, Text = "Пусто. Купите еду в супермаркете или кафе.", TextColor3 = T.Sub, Parent = c })
	end
end

renderers["Навыки 🎓"] = function(c)
	local P = state.Progress
	local S = Config.Skills
	section(c, 1, "Уровень " .. (player:GetAttribute("Level") or 1) .. " — прокачивайте навыки в секциях")
	for i, key in S.Order do
		local info = S.List[key]
		local xp = (P.Skills and P.Skills[key]) or 0
		local lvl = player:GetAttribute("Skill_" .. key) or 0
		local nextXp = S.Levels[lvl + 1]
		local prevXp = lvl > 0 and S.Levels[lvl] or 0
		local r = row(c, 1 + i, 74)
		Ui.label({ Text = info.Icon .. " " .. info.Name .. " — ур. " .. lvl .. "/5", Font = Enum.Font.GothamBold, TextSize = 15, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -120, 0, 20), Parent = r })
		Ui.label({ Text = nextXp and (xp .. " / " .. nextXp .. " опыта") or "Максимум!", TextSize = 12, TextColor3 = T.Sub, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -120, 0, 4), Size = UDim2.fromOffset(110, 20), Parent = r })
		local bg, fill = Ui.bar(r, T.Accent, 8)
		bg.Position = UDim2.fromOffset(10, 26)
		bg.Size = UDim2.new(1, -20, 0, 8)
		fill.Size = UDim2.fromScale(nextXp and math.clamp((xp - prevXp) / (nextXp - prevXp), 0, 1) or 1, 1)
		Ui.label({ Text = "Где: " .. info.Where .. "\nБонус: " .. info.Perk, TextSize = 11, TextColor3 = T.Sub, Position = UDim2.fromOffset(10, 38), Size = UDim2.new(1, -20, 0, 32), TextYAlignment = Enum.TextYAlignment.Top, Parent = r })
	end
	local E = P.Education or { School = 0, College = 0 }
	section(c, 20, "Образование и документы")
	local ed = Config.Education
	local lines = {
		(E.School >= ed.SchoolLessons and "✅" or "📘") .. " Аттестат (Лицей №21): " .. E.School .. "/" .. ed.SchoolLessons .. " уроков — открывает работу в офисе",
		(E.College >= ed.CollegeLessons and "✅" or "📗") .. " Диплом колледжа: " .. E.College .. "/" .. ed.CollegeLessons .. " лекций — +15% к зарплате",
		(P.License and "✅ Водительские права" or ((P.TheoryPassed and "🚗 Теория сдана, осталась практика" or "🚗 Права: сдайте теорию и вождение") .. " в автошколе")),
		"🏃 Лучший забег: " .. ((P.Records and P.Records.Run) and (P.Records.Run .. " с") or "—"),
	}
	for i, text in lines do
		Ui.label({ LayoutOrder = 20 + i, Text = text, TextSize = 13, Size = UDim2.new(1, -8, 0, 22), Parent = c })
	end
	Ui.label({ LayoutOrder = 40, TextSize = 12, TextColor3 = T.Sub, Size = UDim2.new(1, -8, 0, 54), Text = "Также: футбол на стадионе (забивайте голы), рыбалка на пруду (нужна удочка), тир в парке, игра на гитаре на улице за чаевые. Для спецслужб нужны «Сила» 2 и «Выносливость» 2.", Parent = c })
end

renderers["Одежда 👕"] = function(c)
	local C = Config.Clothing
	local w = state.Wardrobe
	Ui.button("Вернуть свой аватар Roblox", T.Bg3, function()
		send("Clothing", { Op = "avatar" })
	end, { LayoutOrder = 1, Size = UDim2.new(1, -8, 0, 32), Parent = c })
	local order = 1
	for _, slot in C.SlotOrder do
		order += 1
		local worn = w.Outfit and w.Outfit[slot]
		local head = new("Frame", { LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 26), Parent = c })
		Ui.label({ Text = C.SlotNames[slot], Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = T.Accent, Size = UDim2.new(1, -100, 1, 0), Parent = head })
		if worn then
			Ui.button("Снять", T.Bad, function()
				send("Clothing", { Op = "remove", Slot = slot })
			end, { Position = UDim2.new(1, -90, 0, 0), Size = UDim2.fromOffset(90, 24), TextSize = 13, Parent = head })
		end
		for _, id in C.Order do
			local item = C.Items[id]
			if item.Slot == slot then
				order += 1
				local r = row(c, order, 44)
				new("Frame", { BackgroundColor3 = item.Color, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(28, 28), Parent = r }, { Ui.corner(6) })
				local tag = item.Robux and "  ⭐ премиум" or ""
				Ui.label({ Text = item.Name .. tag, Font = Enum.Font.GothamBold, TextSize = 14, Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -170, 1, 0), Parent = r })
				local owned = w.Owned and w.Owned[id]
				local text, color, action
				if worn == id then
					text, color = "Надето ✓", T.Disabled
				elseif owned then
					text, color, action = "Надеть", T.Accent, function()
						send("Clothing", { Op = "wear", Item = id })
					end
				elseif item.Robux then
					text, color, action = "R$ " .. item.Robux, Color3.fromRGB(0, 160, 90), function()
						send("BuyProduct", { Key = "Cloth_" .. id })
					end
				else
					text, color, action = "Купить " .. item.Price .. "$", T.Good, function()
						send("Clothing", { Op = "buy", Item = id })
					end
				end
				Ui.button(text, color, action, { Position = UDim2.new(1, -118, 0.5, -15), Size = UDim2.fromOffset(110, 30), TextSize = 13, Parent = r })
			end
		end
	end
	Ui.label({ LayoutOrder = 999, TextSize = 12, TextColor3 = T.Sub, Size = UDim2.new(1, -8, 0, 40), Text = "Премиум-вещи можно купить по одной за Robux или все сразу с пассом «Модный гардероб» (вкладка «Магазин ⭐»). Одежда сохраняется между входами.", Parent = c })
end

renderers["Машины"] = function(c)
	section(c, 1, "Мои машины")
	local order = 1
	for _, carId in Config.CarOrder do
		local def = Config.Cars[carId]
		if state.Cars[carId] or (def.Pass and player:GetAttribute("Pass_" .. def.Pass)) then
			order += 1
			local car = Config.Cars[carId]
			local r = row(c, order, 48)
			Ui.label({ Text = car.Name, Font = Enum.Font.GothamBold, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -130, 1, 0), Parent = r })
			Ui.button("Вызвать", T.Good, function()
				send("SpawnCar", { Car = carId })
				closeModal()
			end, { Position = UDim2.new(1, -110, 0.5, -15), Size = UDim2.fromOffset(100, 30), Parent = r })
		end
	end
	if order == 1 then
		Ui.label({ LayoutOrder = 2, Text = "У вас пока нет машин. Купите в автосалоне (см. GPS).", TextColor3 = T.Sub, Size = UDim2.new(1, -8, 0, 40), Parent = c })
	end
	Ui.button("Убрать мою машину", T.Bg3, function()
		send("DespawnCar")
	end, { LayoutOrder = 50, Size = UDim2.new(1, -8, 0, 34), Parent = c })
	Ui.label({ LayoutOrder = 60, TextSize = 13, TextColor3 = T.Sub, Size = UDim2.new(1, -8, 0, 40), Text = "Управление: W/S — газ и тормоз, A/D — поворот, пробел — выйти. Супруг(а) тоже может водить вашу машину.", Parent = c })
end

renderers["Дом"] = function(c)
	local houseId = player:GetAttribute("HouseId") or 0
	local owns = player:GetAttribute("HasHouse") == true
	section(c, 1, "Недвижимость")
	if houseId > 0 then
		Ui.label({ LayoutOrder = 2, Text = "Ваш дом: №" .. houseId .. (owns and "" or " (дом супруга/супруги)"), Font = Enum.Font.GothamBold, Parent = c })
		Ui.label({ LayoutOrder = 3, TextSize = 13, TextColor3 = T.Sub, Size = UDim2.new(1, -8, 0, 40), Text = "Дома можно спать, принимать душ, смотреть ТВ и перекусить из холодильника. Вы появляетесь дома после входа.", Parent = c })
		Ui.button("📍 Показать дорогу домой", T.Accent, function()
			send("GoHome")
			closeModal()
		end, { LayoutOrder = 4, Size = UDim2.new(1, -8, 0, 34), Parent = c })
	elseif owns then
		Ui.label({ LayoutOrder = 2, Text = "У вас есть дом, но на этом сервере нет свободного участка.", TextColor3 = T.Warn, Size = UDim2.new(1, -8, 0, 40), Parent = c })
	else
		Ui.label({ LayoutOrder = 2, Text = "У вас нет дома. Цена: " .. Ui.money(Config.HousePrice), Font = Enum.Font.GothamBold, Parent = c })
		Ui.label({ LayoutOrder = 3, TextSize = 13, TextColor3 = T.Sub, Size = UDim2.new(1, -8, 0, 40), Text = "Купить дом можно в агентстве недвижимости в мэрии. После свадьбы супруги живут в одном доме.", Parent = c })
		Ui.button("Купить дом (нужно быть в мэрии)", T.Good, function()
			send("BuyHouse")
		end, { LayoutOrder = 4, Size = UDim2.new(1, -8, 0, 34), Parent = c })
	end
	if owns then
		Ui.button("Продать дом (вернётся " .. Ui.money(Config.HousePrice * Config.HouseSellRefund) .. ")", T.Bad, function()
			send("SellHouse")
		end, { LayoutOrder = 10, Size = UDim2.new(1, -8, 0, 34), Parent = c })
	end
end

renderers["GPS"] = function(c)
	section(c, 1, "Куда поехать? Метка с линией маршрута или такси 🚕")
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if (player:GetAttribute("HouseId") or 0) > 0 then
		Ui.button("🏠 Такси домой", Color3.fromRGB(230, 180, 30), function()
			send("Taxi", { Home = true })
			closeModal()
		end, { LayoutOrder = 1, Size = UDim2.new(1, -8, 0, 34), TextColor3 = Color3.new(0, 0, 0), Parent = c })
	end
	for i, place in state.GPS do
		local r = new("Frame", { LayoutOrder = 1 + i, BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 32), Parent = c })
		Ui.button(place.Name, T.Bg3, function()
			setMarker("gps", place.Position, "📍 " .. place.Name, Color3.fromRGB(80, 220, 255))
			closeModal()
		end, { Size = UDim2.new(1, -96, 1, 0), Parent = r })
		local price = hrp and Config.TaxiPrice((hrp.Position - place.Position).Magnitude) or Config.Taxi.Base
		Ui.button("🚕 " .. price .. "$", Color3.fromRGB(230, 180, 30), function()
			send("Taxi", { Name = place.Name })
			closeModal()
		end, { Position = UDim2.new(1, -90, 0, 0), Size = UDim2.new(0, 90, 1, 0), TextColor3 = Color3.new(0, 0, 0), Parent = r })
	end
	Ui.button("Убрать метку", T.Bad, function()
		clearMarker("gps")
	end, { LayoutOrder = 100, Size = UDim2.new(1, -8, 0, 32), Parent = c })
end

renderers["Помощь"] = function(c)
	local text = table.concat({
		"🏙 «" .. Config.GameName .. "» — живите своей жизнью в настоящем Первоуральске: реальные улицы, дома, пруд, администрация, ОМВД, больница, ЗАГС.",
		"🎓 Учёба и секции: Лицей №21 (аттестат), колледж (диплом), спорткомплекс «КОСМОС» (сила, бокс), стадион (забег, футбол), Дом культуры (гитара, шахматы), автошкола (права), рыбалка на пруду, тир в парке. Прогресс — во вкладке «Навыки».",
		"📅 Каждый день — 3 новых задания с наградами и бонус за вход (серия до ×7). Новичкам — 10 000$ за регистрацию.",
		"",
		"💼 Работа: выберите профессию в телефоне и выполняйте задания (жёлтая метка, клавиша E).",
		"🍔 Потребности: следите за сытостью, энергией, гигиеной и настроением. Ешьте (Вещи), спите (кровать), мойтесь (душ), отдыхайте в парке.",
		"🏦 Деньги: зарплата выдаётся наличными. Внесите их на карту в банкомате — так безопаснее.",
		"🏠 Дом: купите в мэрии. Дома есть кровать, душ, ТВ и холодильник.",
		"🚗 Машины: покупайте в автосалоне и вызывайте через телефон.",
		"❤ Отношения: общайтесь (Люди) → свидания → «встречаться» → кольцо из цветочного магазина → предложение → роспись в ЗАГСе → общий дом.",
		"👮 Полиция и спецслужбы: арестовывайте разыскиваемых наручниками, обездвиживайте шокером.",
		"🩺 Медики: лечите людей аптечкой и принимайте пациентов в больнице.",
		"🦹 Преступники: грабежи магазинов и банка дают деньги, но и звёзды розыска. Арест = тюрьма.",
	}, "\n")
	Ui.label({ LayoutOrder = 1, Text = text, TextSize = 14, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextYAlignment = Enum.TextYAlignment.Top, Parent = c })
end

function renderTab()
	if not phoneContent or not phoneContent.Parent then
		return
	end
	Ui.clear(phoneContent)
	local fn = renderers[state.PhoneTab]
	if fn then
		fn(phoneContent)
	end
end

function openPhone(tab)
	if tab then
		state.PhoneTab = tab
	end
	if modalName == "Phone" and not tab then
		closeModal()
		return
	end
	send("GetState")
	send("GetQuests")
	send("GetProgress")
	local _, body = openWindow("Phone", "📱 Телефон", 700, 520)
	local tabs = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 130, 1, 0), Parent = body }, { Ui.list(6) })
	for i, name in TABS do
		Ui.button(name, name == state.PhoneTab and T.Accent or T.Bg3, function()
			state.PhoneTab = name
			state.SelectedPerson = nil
			openPhone(name)
		end, { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 34), TextSize = 14, Parent = tabs })
	end
	phoneContent = Ui.scroll({ Position = UDim2.fromOffset(140, 0), Size = UDim2.new(1, -140, 1, 0), Parent = body })
	Ui.list(6).Parent = phoneContent
	renderTab()
end

local function rerenderPhone(tab)
	if modalName == "Phone" and (not tab or state.PhoneTab == tab) then
		renderTab()
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.M then
		openPhone()
	end
end)

---------------------------------------------------------------------------
-- Запросы (свидание, предложение и т.д.)
---------------------------------------------------------------------------
local function showRequest(p)
	local f = Ui.panel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(420, 130),
		BackgroundColor3 = Color3.fromRGB(60, 30, 50),
		Parent = gui,
	})
	scaleIt(f)
	Ui.label({ Text = p.Text, Font = Enum.Font.GothamBold, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 60), Parent = f })
	local function answer(yes)
		send("Respond", { Id = p.Id, Accept = yes })
		f:Destroy()
	end
	Ui.button("Да ❤", T.Good, function()
		answer(true)
	end, { Position = UDim2.new(0, 10, 1, -46), Size = UDim2.new(0.5, -15, 0, 36), Parent = f })
	Ui.button("Нет", T.Bad, function()
		answer(false)
	end, { Position = UDim2.new(0.5, 5, 1, -46), Size = UDim2.new(0.5, -15, 0, 36), Parent = f })
	task.delay(30, function()
		if f.Parent then
			f:Destroy()
		end
	end)
end

local function toast(title, text)
	local f = Ui.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(520, 110), BackgroundColor3 = Color3.fromRGB(70, 40, 80), Parent = gui })
	scaleIt(f)
	Ui.label({ Text = title, Font = Enum.Font.GothamBold, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 40), Parent = f })
	Ui.label({ Text = text, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(10, 56), Size = UDim2.new(1, -20, 0, 40), Parent = f })
	task.delay(6, function()
		f:Destroy()
	end)
end

local function floatMoney(amount)
	local l = Ui.label({
		Text = "+" .. Ui.money(amount),
		Font = Enum.Font.GothamBold,
		TextSize = 26,
		TextColor3 = Color3.fromRGB(130, 240, 140),
		TextStrokeTransparency = 0.4,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(240, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = gui,
	})
	TweenService:Create(l, TweenInfo.new(1.6), { Position = UDim2.fromScale(0.5, 0.52), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.7, function()
		l:Destroy()
	end)
end

---------------------------------------------------------------------------
-- Задания работы
---------------------------------------------------------------------------
local jobPrompt

local function setTask(p)
	if jobPrompt then
		jobPrompt:Destroy()
		jobPrompt = nil
	end
	clearMarker("job")
	state.Wait = nil
	if p.Waiting then
		state.Task = nil
		state.Wait = { Until = os.clock() + p.Waiting, Reason = p.Reason or "Ожидайте" }
		return
	end
	if not p.Id then
		state.Task = nil
		return
	end
	if not p.Target then
		-- Деталь ещё не загружена (StreamingEnabled) — показываем точку на карте.
		state.Task = nil
		setMarker("job", p.Position, "▼ " .. p.Label .. " (подойдите ближе)", Color3.fromRGB(255, 220, 60))
		task.delay(2, function()
			send("GetState")
		end)
		return
	end
	state.Task = p
	local job = Config.Jobs[p.Job]
	jobPrompt = new("ProximityPrompt", {
		ActionText = p.Label,
		ObjectText = job and job.Name or "Работа",
		HoldDuration = p.Hold or 1,
		MaxActivationDistance = 12,
		RequiresLineOfSight = false,
		Parent = p.Target,
	})
	local id = p.Id
	jobPrompt.Triggered:Connect(function()
		send("JobTask", { Id = id })
	end)
	setMarker("job", p.Target, "▼ " .. p.Label, Color3.fromRGB(255, 220, 60))
end

---------------------------------------------------------------------------
-- События от сервера
---------------------------------------------------------------------------
local alertCount = 0
local handlers = {
	Notify = function(p)
		notify(p.Text, p.Kind)
	end,
	Inventory = function(p)
		state.Inventory = p.Items or {}
		rerenderPhone("Вещи")
	end,
	Cars = function(p)
		state.Cars = p.Owned or {}
		rerenderPhone("Машины")
		if modalName == "Dealer" then
			openDealer()
		end
	end,
	Relations = function(p)
		state.Relations = p.List or {}
		state.Partner = p.Partner
		rerenderPhone("Люди")
	end,
	MiniGame = function(p)
		closeModal()
		MiniGames.Play(gui, Ui, p, function(score, answers)
			send("MiniGameResult", { Id = p.Id, Score = score, Answers = answers })
		end, scaleIt)
	end,
	Course = function(p)
		if p.Active then
			state.Course = { Label = p.Label, Index = p.Index, Total = p.Total, Limit = p.Limit, Started = os.clock() - (p.Elapsed or 0) }
			setMarker("course", p.Point, "🏁 " .. p.Label .. " " .. p.Index .. "/" .. p.Total, Color3.fromRGB(255, 120, 40))
		else
			state.Course = nil
			clearMarker("course")
		end
	end,
	Progress = function(p)
		state.Progress = p
		rerenderPhone("Навыки 🎓")
	end,
	Wardrobe = function(p)
		state.Wardrobe = { Owned = p.Owned or {}, Outfit = p.Outfit or {} }
		rerenderPhone("Одежда 👕")
	end,
	Quests = function(p)
		state.Quests = p
		rerenderPhone("Задания")
	end,
	GPS = function(p)
		state.GPS = p.List or {}
		rerenderPhone("GPS")
	end,
	JobTask = setTask,
	OpenShop = function(p)
		openShop(p.Shop)
	end,
	OpenBank = openBank,
	OpenDealer = openDealer,
	OpenPhone = function(p)
		openPhone(p.Tab)
	end,
	OpenRoleMenu = function(p)
		openRoleMenu(p.First)
	end,
	CloseMenus = closeModal,
	Request = showRequest,
	Toast = function(p)
		toast(p.Title, p.Text)
	end,
	Earned = function(p)
		floatMoney(p.Amount)
		notify("+" .. Ui.money(p.Amount) .. " — " .. (p.Text or ""), "good")
	end,
	Waypoint = function(p)
		setMarker("gps", p.Position, "📍 " .. p.Name, Color3.fromRGB(80, 220, 255))
	end,
	Alert = function(p)
		notify(p.Text, "bad")
		if p.Position then
			alertCount += 1
			setMarker("alert" .. alertCount, p.Position, "🚨 Вызов", Color3.fromRGB(255, 70, 70), 40)
		end
	end,
	DoorBell = function(p)
		notify("🔔 " .. p.From .. " звонит в дверь вашего дома №" .. p.House, "info")
	end,
	Bubble = function(p)
		local char = p.Character
		local head = char and char:FindFirstChild("Head")
		if head then
			pcall(function()
				TextChatService:DisplayBubble(head, p.Text)
			end)
		end
	end,
}

EventRemote.OnClientEvent:Connect(function(name, payload)
	local h = handlers[name]
	if h then
		local ok, err = pcall(h, payload or {})
		if not ok then
			warn("[LifeCity UI] " .. name .. ": " .. tostring(err))
		end
	end
end)

---------------------------------------------------------------------------
-- Обновление каждый кадр: часы, задание, спидометр, маркеры
---------------------------------------------------------------------------
local acc = 0
RunService.RenderStepped:Connect(function(dt)
	acc += dt
	if acc < 0.15 then
		return
	end
	acc = 0
	local t = Lighting.ClockTime
	local h = math.floor(t)
	local m = math.floor((t - h) * 60)
	local period = (h >= 6 and h < 12) and "утро" or (h >= 12 and h < 18) and "день" or (h >= 18 and h < 23) and "вечер" or "ночь"
	clockLabel.Text = string.format("🕒 %02d:%02d (%s)", h, m, period)
	local wtext = Weather.Describe()
	if player:GetAttribute("Wet") then
		wtext ..= " • 💧 вы промокли"
	elseif player:GetAttribute("Cold") then
		wtext ..= " • 🥶 холодно"
	end
	weatherLabel.Text = wtext

	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local myPos = hrp and hrp.Position

	-- Удаляем устаревшие/достигнутые метки.
	for key, mk in markers do
		local spec = mk.Spec
		if spec.Expires and os.clock() > spec.Expires then
			clearMarker(key)
		elseif mk.Attachment and myPos then
			local d = (mk.Attachment.WorldPosition - myPos).Magnitude
			if mk.Text then
				mk.Text.Text = spec.Text .. "\n" .. math.floor(d) .. " м"
			end
			if key == "gps" and d < 15 then
				clearMarker(key)
				notify("Вы прибыли: " .. spec.Text, "good")
			end
		end
	end

	local lines = {}
	local jailed = player:GetAttribute("Jailed") or 0
	local wanted = player:GetAttribute("Wanted") or 0
	if jailed > 0 then
		table.insert(lines, "⛓ Тюрьма: осталось " .. jailed .. " сек.")
	elseif wanted > 0 then
		table.insert(lines, "🚨 Розыск: " .. string.rep("★", wanted) .. string.rep("☆", 5 - wanted))
	end
	if state.Wait then
		local left = math.ceil(state.Wait.Until - os.clock())
		if left > 0 then
			table.insert(lines, "⏳ " .. state.Wait.Reason .. ": " .. (left >= 60 and (math.floor(left / 60) .. " мин " .. (left % 60) .. " сек") or (left .. " сек")))
		end
	end
	if state.Course then
		local cr = state.Course
		table.insert(lines, string.format("🏁 %s: точка %d/%d • %.1f с из %d", cr.Label, cr.Index, cr.Total, os.clock() - cr.Started, cr.Limit))
	end
	if state.Task and state.Task.Target and myPos then
		local d = (state.Task.Target.Position - myPos).Magnitude
		table.insert(lines, "📋 " .. state.Task.Label .. " — " .. math.floor(d) .. " м")
	end
	topBar.Visible = #lines > 0
	topLabel.Text = table.concat(lines, "\n")
	if wanted > 0 or jailed > 0 then
		topBar.BackgroundColor3 = Color3.fromRGB(90, 25, 30)
	else
		topBar.BackgroundColor3 = T.Bg
	end

	speedo.Visible = CarController.Driving
	if CarController.Driving then
		speedLabel.Text = math.floor(CarController.Speed * 1.6) .. " км/ч"
	end
end)

CarController.Start()
Weather.Start()
Ambient.Start(function()
	send("TalkNPC")
end)
send("GetState")
