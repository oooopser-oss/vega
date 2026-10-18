-- Мини-игры занятий (клиент). Типы:
--   timing   — маркер бегает по шкале, нажмите, когда он в зелёной зоне;
--   targets  — кликайте по появляющимся мишеням;
--   sequence — запомните и повторите последовательность цветов;
--   rhythm   — ноты падают в 4 дорожки, жмите D/F/J/K (или по дорожке);
--   quiz     — вопросы с 4 вариантами ответа.
-- Результат отправляется на сервер; сервер проверяет и выдаёт награды.

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local MiniGames = {}

local Ui
local T
local new
local active

local function frameFor(gui, title, scaleIt)
	local win = Ui.panel({
		Size = UDim2.fromOffset(580, 420),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 0.02,
		ZIndex = 20,
		Parent = gui,
	})
	if scaleIt then
		scaleIt(win)
	end
	Ui.label({ Text = title, Font = Enum.Font.GothamBold, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 30), ZIndex = 21, Parent = win })
	local info = Ui.label({ Text = "", TextSize = 15, TextColor3 = T.Sub, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(10, 40), Size = UDim2.new(1, -20, 0, 22), ZIndex = 21, Parent = win })
	local body = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 70), Size = UDim2.new(1, -40, 1, -90), ZIndex = 21, Parent = win })
	return win, body, info
end

local function pressed(callback)
	-- Пробел, Enter или клик по кнопке.
	local conn = UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.E then
			callback()
		end
	end)
	return conn
end

---------------------------------------------------------------------------
local function playTiming(body, info, params, finish)
	local rounds, round, hits = params.Rounds or 5, 0, 0
	local barW = 480
	local bar = new("Frame", { BackgroundColor3 = T.Bg3, BorderSizePixel = 0, Position = UDim2.fromOffset(10, 90), Size = UDim2.fromOffset(barW, 36), ZIndex = 22, Parent = body }, { Ui.corner(8) })
	local zone = new("Frame", { BackgroundColor3 = T.Good, BorderSizePixel = 0, Size = UDim2.new(params.Zone or 0.18, 0, 1, 0), ZIndex = 23, Parent = bar }, { Ui.corner(6) })
	local marker = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.new(0, 6, 1, 10), Position = UDim2.new(0, 0, 0, -5), ZIndex = 24, Parent = bar })
	local btn = Ui.button(params.Wait and "ПОДСЕЧЬ!" or "ЖМИ! (пробел)", T.Accent, nil, { Position = UDim2.fromOffset(150, 170), Size = UDim2.fromOffset(200, 50), TextSize = 20, ZIndex = 22, Parent = body })
	local pos, dir, waiting = 0, 1, params.Wait ~= nil
	local roundStart = os.clock()
	local function newRound()
		round += 1
		local z = params.Zone or 0.18
		zone.Position = UDim2.fromScale(math.random() * (1 - z), 0)
		info.Text = string.format("Раунд %d/%d • попаданий: %d", round, rounds, hits)
		roundStart = os.clock()
	end
	if waiting then
		bar.Visible = false
		btn.Visible = false
		info.Text = "🎣 Ждём поклёвку..."
		task.delay(params.Wait, function()
			waiting = false
			bar.Visible = true
			btn.Visible = true
			newRound()
			info.Text = "Клюёт! Подсекайте, когда маркер в зелёной зоне!"
		end)
	else
		newRound()
	end
	local done = false
	local function hit()
		if done or waiting then
			return
		end
		local z0 = zone.Position.X.Scale
		local z1 = z0 + zone.Size.X.Scale
		if pos >= z0 and pos <= z1 then
			hits += 1
			zone.BackgroundColor3 = Color3.fromRGB(120, 255, 140)
		else
			zone.BackgroundColor3 = T.Bad
		end
		task.delay(0.15, function()
			zone.BackgroundColor3 = T.Good
		end)
		if round >= rounds then
			done = true
			finish(hits)
		else
			newRound()
		end
	end
	btn.MouseButton1Click:Connect(hit)
	local conn = pressed(hit)
	local step = RunService.RenderStepped:Connect(function(dt)
		if waiting or done then
			return
		end
		pos += dir * (params.Speed or 1.2) * dt
		if pos > 1 then
			pos, dir = 1, -1
		elseif pos < 0 then
			pos, dir = 0, 1
		end
		marker.Position = UDim2.new(pos, -3, 0, -5)
		-- На рыбалке на подсечку мало времени.
		if params.Wait and os.clock() - roundStart > 3 then
			done = true
			finish(hits)
		end
	end)
	return function()
		conn:Disconnect()
		step:Disconnect()
	end
end

---------------------------------------------------------------------------
local function playTargets(body, info, params, finish)
	local duration = params.Duration or 15
	local hits = 0
	local area = new("Frame", { BackgroundColor3 = T.Bg2, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0), ZIndex = 22, Parent = body }, { Ui.corner(8) })
	local started = os.clock()
	local done = false
	local function spawnTarget()
		if done then
			return
		end
		local size = math.random(44, 60)
		local t = Ui.button("🎯", Color3.fromRGB(220, 50, 50), nil, {
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.new(math.random() * 0.85, 0, math.random() * 0.8, 0),
			TextSize = 26,
			ZIndex = 23,
			Parent = area,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = t })
		t.MouseButton1Click:Connect(function()
			if not done then
				hits += 1
				t:Destroy()
			end
		end)
		task.delay(0.95, function()
			if t.Parent then
				t:Destroy()
			end
		end)
	end
	local acc = 0
	local step = RunService.RenderStepped:Connect(function(dt)
		if done then
			return
		end
		local left = duration - (os.clock() - started)
		info.Text = string.format("Попаданий: %d • осталось %.0f с", hits, math.max(0, left))
		acc += dt
		if acc > 0.45 then
			acc = 0
			spawnTarget()
		end
		if left <= 0 then
			done = true
			finish(hits)
		end
	end)
	return function()
		step:Disconnect()
	end
end

---------------------------------------------------------------------------
local function playSequence(body, info, params, finish)
	local colors = { Color3.fromRGB(220, 60, 60), Color3.fromRGB(60, 160, 230), Color3.fromRGB(80, 200, 100), Color3.fromRGB(240, 200, 50) }
	local buttons = {}
	local seq, input, showing, done = {}, {}, true, false
	for i = 1, 4 do
		local b = Ui.button("", colors[i], nil, {
			Position = UDim2.fromOffset(60 + ((i - 1) % 2) * 220, 10 + math.floor((i - 1) / 2) * 140),
			Size = UDim2.fromOffset(180, 120),
			ZIndex = 22,
			Parent = body,
		})
		b.AutoButtonColor = false
		buttons[i] = b
	end
	local function flash(i, t)
		buttons[i].BackgroundColor3 = Color3.new(1, 1, 1)
		task.wait(t)
		buttons[i].BackgroundColor3 = colors[i]
	end
	local function play()
		showing = true
		info.Text = "Запоминайте... (длина " .. #seq .. ")"
		task.wait(0.6)
		for _, i in seq do
			flash(i, 0.45)
			task.wait(0.2)
		end
		input = {}
		showing = false
		info.Text = "Повторите последовательность!"
	end
	local function nextLevel()
		table.insert(seq, math.random(1, 4))
		if #seq < 3 then
			table.insert(seq, math.random(1, 4))
			table.insert(seq, math.random(1, 4))
		end
		task.spawn(play)
	end
	for i, b in buttons do
		b.MouseButton1Click:Connect(function()
			if showing or done then
				return
			end
			task.spawn(flash, i, 0.12)
			table.insert(input, i)
			if seq[#input] ~= i then
				done = true
				finish(math.max(0, #seq - 3))
				return
			end
			if #input == #seq then
				if #seq >= 12 then
					done = true
					finish(10)
				else
					info.Text = "Верно! Дальше..."
					nextLevel()
				end
			end
		end)
	end
	nextLevel()
	return function() end
end

---------------------------------------------------------------------------
local LANE_KEYS = { Enum.KeyCode.D, Enum.KeyCode.F, Enum.KeyCode.J, Enum.KeyCode.K }
local LANE_COLORS = { Color3.fromRGB(230, 70, 70), Color3.fromRGB(70, 170, 240), Color3.fromRGB(90, 210, 110), Color3.fromRGB(240, 200, 60) }

local function playRhythm(body, info, params, finish)
	local duration = params.Duration or 20
	local rng = Random.new(params.Seed or 1)
	local fall = 1.6 -- секунд от появления до линии
	local notes = {}
	local t = 1.2
	while t < duration - 0.5 do
		table.insert(notes, { Time = t, Lane = rng:NextInteger(1, 4) })
		t += 0.5
	end
	local laneW, height = 110, 300
	local lanes = {}
	for i = 1, 4 do
		local lane = Ui.button("", T.Bg2, nil, { Position = UDim2.fromOffset(10 + (i - 1) * (laneW + 8), 0), Size = UDim2.fromOffset(laneW, height), ZIndex = 22, Parent = body })
		lane.AutoButtonColor = false
		lane.ClipsDescendants = true
		Ui.label({ Text = ({ "D", "F", "J", "K" })[i], Font = Enum.Font.GothamBold, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 1, -28), Size = UDim2.new(1, 0, 0, 26), ZIndex = 24, Parent = lane })
		new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -40), Size = UDim2.new(1, 0, 0, 4), ZIndex = 23, Parent = lane })
		lanes[i] = lane
	end
	local started = os.clock()
	local hits, done = 0, false
	local hitY = height - 40
	local function tryHit(lane)
		local now = os.clock() - started
		for _, n in notes do
			if not n.Done and n.Lane == lane and math.abs(n.Time - now) < 0.2 then
				n.Done = true
				hits += 1
				if n.Gui then
					n.Gui.BackgroundColor3 = Color3.new(1, 1, 1)
				end
				return
			end
		end
	end
	for i, lane in lanes do
		lane.MouseButton1Click:Connect(function()
			tryHit(i)
		end)
	end
	local conn = UserInputService.InputBegan:Connect(function(input)
		for i, key in LANE_KEYS do
			if input.KeyCode == key then
				tryHit(i)
			end
		end
	end)
	local step = RunService.RenderStepped:Connect(function()
		if done then
			return
		end
		local now = os.clock() - started
		for _, n in notes do
			local y = hitY - (n.Time - now) / fall * hitY
			if y > -30 and y < height + 30 then
				if not n.Gui then
					n.Gui = new("Frame", { BackgroundColor3 = LANE_COLORS[n.Lane], BorderSizePixel = 0, Size = UDim2.new(1, -16, 0, 22), ZIndex = 25, Parent = lanes[n.Lane] }, { Ui.corner(6) })
				end
				n.Gui.Position = UDim2.new(0, 8, 0, y - 11)
			elseif n.Gui then
				n.Gui:Destroy()
				n.Gui = nil
			end
		end
		info.Text = string.format("🎸 Нот поймано: %d из %d", hits, #notes)
		if now > duration then
			done = true
			finish(hits)
		end
	end)
	return function()
		conn:Disconnect()
		step:Disconnect()
	end
end

---------------------------------------------------------------------------
local function playQuiz(body, info, params, finish)
	local qs = params.Questions or {}
	local answers = {}
	local idx = 0
	local qLabel = Ui.label({ Text = "", Font = Enum.Font.GothamBold, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 70), ZIndex = 22, Parent = body })
	local opts = {}
	for i = 1, 4 do
		opts[i] = Ui.button("", T.Bg3, nil, { Position = UDim2.fromOffset(((i - 1) % 2) * 265, 90 + math.floor((i - 1) / 2) * 75), Size = UDim2.fromOffset(255, 64), TextSize = 16, TextWrapped = true, ZIndex = 22, Parent = body })
	end
	local function show()
		idx += 1
		if idx > #qs then
			finish(0, answers)
			return
		end
		local q = qs[idx]
		info.Text = "Вопрос " .. idx .. " из " .. #qs
		qLabel.Text = q.Q
		for i, b in opts do
			b.Text = q.O[i] or ""
			b.BackgroundColor3 = T.Bg3
		end
	end
	for i, b in opts do
		b.MouseButton1Click:Connect(function()
			if idx <= #qs and answers[idx] == nil then
				answers[idx] = i
				b.BackgroundColor3 = T.Accent
				task.delay(0.25, show)
			end
		end)
	end
	show()
	return function() end
end

local PLAYERS = { timing = playTiming, targets = playTargets, sequence = playSequence, rhythm = playRhythm, quiz = playQuiz }

function MiniGames.IsActive()
	return active ~= nil
end

-- payload: { Id, Type, Params }; onDone(score, answers)
function MiniGames.Play(gui, ui, payload, onDone, scaleIt)
	Ui, T, new = ui, ui.Theme, ui.new
	if active then
		active.Close()
	end
	local play = PLAYERS[payload.Type]
	if not play then
		return
	end
	local params = payload.Params or {}
	local win, body, info = frameFor(gui, params.Title or "Занятие", scaleIt)
	local cleanup
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		if cleanup then
			cleanup()
		end
		win:Destroy()
		active = nil
	end
	active = { Close = close }
	local function finish(score, answers)
		if closed then
			return
		end
		onDone(score, answers)
		if cleanup then
			cleanup()
			cleanup = nil
		end
		Ui.clear(body)
		local text = payload.Type == "quiz" and "Ответы отправлены — результат придёт уведомлением." or ("Результат: " .. tostring(score))
		Ui.label({ Text = text, Font = Enum.Font.GothamBold, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 80), Position = UDim2.fromOffset(0, 80), ZIndex = 22, Parent = body })
		task.delay(1.8, close)
	end
	Ui.button("✕", T.Bad, function()
		finish(0, {})
	end, { Size = UDim2.fromOffset(34, 30), Position = UDim2.new(1, -44, 0, 9), ZIndex = 23, Parent = win })
	cleanup = play(body, info, params, finish)
end

return MiniGames
