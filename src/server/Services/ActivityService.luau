-- Занятия и мини-игры: секции (тренажёры, бокс, гитара, шахматы), уроки
-- в лицее и колледже, экзамены автошколы, забег на стадионе, рыбалка, тир,
-- игра на гитаре на улице. Мини-игра идёт на клиенте, сервер выдаёт её,
-- проверяет результат (время, максимум очков, ответы) и даёт награды.

local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Roads = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Roads"))
local Questions = require(script.Parent.Parent:WaitForChild("Questions"))
local Util = require(script.Parent.Util)

local ActivityService = {}
local ctx

local A = Config.Activities
local sessions = {} -- [Player] = { Id, Key, Started, MinTime, Max, Answers }
local cooldowns = {} -- [Player] = { [key] = time }
local courses = {} -- [Player] = { Kind, Points, Index, Started, Limit, Radius, Car }
local busking = {} -- [Player] = { Start = Vector3 }
local nextId = 0
local runRecord -- { Name, Time }

local function onCooldown(player, key, seconds)
	cooldowns[player] = cooldowns[player] or {}
	local last = cooldowns[player][key]
	if last and os.clock() - last < seconds then
		return math.ceil(seconds - (os.clock() - last))
	end
	return nil
end

local function markUsed(player, key)
	cooldowns[player] = cooldowns[player] or {}
	cooldowns[player][key] = os.clock()
end

local function shuffle(list, n)
	local copy = table.clone(list)
	local out = {}
	for _ = 1, math.min(n, #copy) do
		table.insert(out, table.remove(copy, math.random(1, #copy)))
	end
	return out
end

---------------------------------------------------------------------------
-- Мини-игры
---------------------------------------------------------------------------
local function startMiniGame(player, key)
	local act = A[key]
	local Net = ctx.Net
	if sessions[player] then
		Net.Notify(player, "Сначала закончите текущее занятие.", "info")
		return
	end
	local wait = onCooldown(player, key, act.Cooldown or 10)
	if wait then
		Net.Notify(player, "Передохните " .. wait .. " сек. перед следующим занятием.", "info")
		return
	end
	local data = ctx.Data.Get(player)
	if not data then
		return
	end
	if act.Requires and not ctx.Progression.Meets(player, act.Requires) then
		Net.Notify(player, "Сначала получите аттестат: 5 уроков в Лицее №21.", "bad")
		return
	end
	if key == "lesson" and ctx.Progression.HasSchool(player) then
		Net.Notify(player, "Аттестат уже получен! Продолжайте в колледже (правый класс).", "info")
		return
	end
	if key == "college" and ctx.Progression.HasDiploma(player) then
		Net.Notify(player, "Диплом уже получен. Поздравляем!", "info")
		return
	end
	if key == "theory" and (data.License or data.TheoryPassed) then
		Net.Notify(player, data.License and "У вас уже есть права." or "Теория сдана. Подойдите к стойке «Практический экзамен».", "info")
		return
	end
	if act.Item and not ctx.Data.HasItem(player, act.Item) then
		Net.Notify(player, "Нужен предмет «" .. Config.Items[act.Item].Name .. "». Купите в спорткомплексе «КОСМОС».", "bad")
		return
	end
	if act.Skill and act.Needs and (act.Needs.Energy or 0) < 0 and (player:GetAttribute("Energy") or 0) < 10 then
		Net.Notify(player, "Слишком мало энергии для тренировки. Отдохните или выпейте кофе.", "bad")
		return
	end
	if (act.Cost or 0) > 0 and not ctx.Data.Spend(player, act.Cost) then
		Net.Notify(player, "Нужно " .. act.Cost .. "$.", "bad")
		return
	end
	markUsed(player, key)
	nextId += 1
	local s = { Id = nextId, Key = key, Started = os.clock() }
	local params = { Title = act.Name }
	if act.Type == "timing" then
		params.Rounds = act.Rounds
		params.Speed = act.Wait and 2.4 or (1.1 + math.random() * 0.5)
		params.Zone = act.Wait and 0.12 or 0.18
		if act.Wait then
			params.Wait = math.random(20, 50) / 10
		end
		s.Max, s.MinTime = act.Rounds, act.Rounds * 0.5 + (params.Wait or 0)
	elseif act.Type == "targets" then
		params.Duration = act.Duration
		s.Max, s.MinTime = math.floor(act.Duration * 2.2), act.Duration * 0.9
	elseif act.Type == "sequence" then
		s.Max, s.MinTime = 10, 2
	elseif act.Type == "rhythm" then
		params.Duration = act.Duration
		params.Seed = math.random(1, 1e6)
		s.Max, s.MinTime = act.Duration * 2, act.Duration * 0.9
	elseif act.Type == "quiz" then
		local picked = shuffle(Questions[act.Bank], act.Questions)
		params.Questions = {}
		s.Answers = {}
		for i, q in picked do
			params.Questions[i] = { Q = q.Q, O = q.O }
			s.Answers[i] = q.A
		end
		s.Max, s.MinTime = act.Questions, act.Questions * 1.2
	end
	sessions[player] = s
	if s.MinTime then
		s.MinTime = math.max(0, s.MinTime - 0.5)
	end
	Net.Send(player, "MiniGame", { Id = s.Id, Type = act.Type, Params = params })
end

local function catchFish(player)
	local lvl = ctx.Progression.Level(player, "Fishing")
	local total = 0
	for _, f in Config.Fish do
		total += f.Weight + (f.PerLevel or 0) * lvl
	end
	local roll = math.random() * total
	for _, f in Config.Fish do
		roll -= f.Weight + (f.PerLevel or 0) * lvl
		if roll <= 0 then
			return f.Item
		end
	end
	return Config.Fish[1].Item
end

local function finishMiniGame(player, p)
	local s = sessions[player]
	if not s or s.Id ~= p.Id then
		return
	end
	sessions[player] = nil
	local act = A[s.Key]
	local Net = ctx.Net
	local elapsed = os.clock() - s.Started
	local score
	if act.Type == "quiz" then
		score = 0
		local answers = type(p.Answers) == "table" and p.Answers or {}
		for i, correct in s.Answers do
			if tonumber(answers[i]) == correct then
				score += 1
			end
		end
	else
		score = math.clamp(math.floor(tonumber(p.Score) or 0), 0, s.Max)
	end
	if elapsed < (s.MinTime or 0) then
		Net.Notify(player, "Слишком быстро — результат не засчитан.", "bad")
		return
	end
	local data = ctx.Data.Get(player)
	if not data then
		return
	end
	ctx.Needs.ApplyEffects(player, act.Needs)
	if act.Skill and score > 0 and act.Type ~= "quiz" and s.Key ~= "fishing" then
		ctx.Progression.AddXP(player, act.Skill, score * act.XP)
	end
	if s.Key == "gym" or s.Key == "boxing" then
		ctx.Quests.Progress(player, "train", 1)
	end

	if s.Key == "fishing" then
		if score >= 1 then
			local fish = catchFish(player)
			ctx.Data.AddItem(player, fish, 1)
			ctx.Economy.SendInventory(player)
			Net.Notify(player, "🎣 Поймали: " .. Config.Items[fish].Name .. "!", "good")
			ctx.Progression.AddXP(player, "Fishing", act.XP)
			ctx.Quests.Progress(player, "fish", 1)
		else
			Net.Notify(player, "Сорвалась! Попробуйте ещё раз.", "info")
		end
	elseif s.Key == "shooting" then
		for _, prize in act.Prizes do
			if score >= prize[1] then
				ctx.Data.AddCash(player, prize[2])
				Net.Send(player, "Earned", { Amount = prize[2], Text = "Приз тира: " .. score .. " попаданий" })
				break
			end
		end
	elseif act.Type == "quiz" then
		local passed = score >= act.Pass
		local xp = score * act.XP
		if xp > 0 then
			ctx.Progression.AddXP(player, act.Skill, xp)
		end
		local edu = data.Education
		if s.Key == "lesson" then
			ctx.Quests.Progress(player, "study", 1)
			if passed then
				edu.School = math.min(Config.Education.SchoolLessons, edu.School + 1)
				if edu.School >= Config.Education.SchoolLessons then
					Net.Send(player, "Toast", { Title = "🎓 Аттестат получен!", Text = "Теперь доступна работа в офисе и колледж." })
				else
					Net.Notify(player, "Урок сдан (" .. score .. "/" .. #s.Answers .. "). До аттестата: " .. edu.School .. "/" .. Config.Education.SchoolLessons, "good")
				end
			else
				Net.Notify(player, "Урок не сдан: " .. score .. "/" .. #s.Answers .. " (нужно " .. act.Pass .. "). Попробуйте ещё!", "bad")
			end
		elseif s.Key == "college" then
			ctx.Quests.Progress(player, "study", 1)
			if passed then
				edu.College = math.min(Config.Education.CollegeLessons, edu.College + 1)
				if edu.College >= Config.Education.CollegeLessons then
					Net.Send(player, "Toast", { Title = "🎓 Диплом колледжа!", Text = "+15% к зарплате на любой работе." })
				else
					Net.Notify(player, "Лекция зачтена. До диплома: " .. edu.College .. "/" .. Config.Education.CollegeLessons, "good")
				end
			else
				Net.Notify(player, "Лекция не зачтена: " .. score .. "/" .. #s.Answers .. " (нужно " .. act.Pass .. ").", "bad")
			end
		elseif s.Key == "theory" then
			if passed then
				data.TheoryPassed = true
				Net.Send(player, "Toast", { Title = "Теория ПДД сдана!", Text = "Теперь практический экзамен: стойка у площадки автошколы." })
			else
				Net.Notify(player, "Экзамен не сдан: " .. score .. "/" .. #s.Answers .. " (нужно " .. act.Pass .. "). Повторите правила!", "bad")
			end
		end
		ctx.Progression.Sync(player)
	else
		Net.Notify(player, act.Name .. ": результат " .. score, "good")
	end
end

---------------------------------------------------------------------------
-- Маршруты: забег на стадионе и практический экзамен по вождению
---------------------------------------------------------------------------
local function sendCourse(player)
	local c = courses[player]
	if not c then
		ctx.Net.Send(player, "Course", { Active = false })
		return
	end
	ctx.Net.Send(player, "Course", {
		Active = true,
		Label = c.Label,
		Point = c.Points[c.Index],
		Index = c.Index,
		Total = #c.Points,
		Limit = c.Limit,
		Elapsed = os.clock() - c.Started,
	})
end

local function endCourse(player, ok)
	local c = courses[player]
	if not c then
		return
	end
	courses[player] = nil
	sendCourse(player)
	local Net = ctx.Net
	local time = os.clock() - c.Started
	if c.Kind == "run" then
		if not ok then
			Net.Notify(player, "Время вышло! Попробуйте ещё раз.", "bad")
			return
		end
		local data = ctx.Data.Get(player)
		local best = data and data.Records.Run
		local t = math.floor(time * 10) / 10
		if data and (not best or t < best) then
			data.Records.Run = t
		end
		ctx.Progression.AddXP(player, "Stamina", math.clamp(math.floor(220 - time * 4), 20, 130))
		ctx.Needs.Change(player, "Energy", -8)
		ctx.Needs.Change(player, "Fun", 6)
		ctx.Quests.Progress(player, "train", 1)
		if not runRecord or t < runRecord.Time then
			runRecord = { Name = player.DisplayName, Time = t }
			if ctx.World.RunBoard then
				ctx.World.RunBoard.Text = string.format("Рекорд забега: %s — %.1f с", runRecord.Name, runRecord.Time)
			end
			Net.NotifyAll("🏃 Новый рекорд стадиона: " .. player.DisplayName .. " — " .. t .. " с!", "good")
		else
			Net.Notify(player, "🏁 Финиш! Время: " .. t .. " с", "good")
		end
		ctx.Progression.Sync(player)
	elseif c.Kind == "drive" then
		task.delay(3, function()
			if c.Car and c.Car.Parent then
				c.Car:Destroy()
			end
		end)
		if ok then
			local data = ctx.Data.Get(player)
			if data then
				data.License = true
			end
			ctx.Progression.AddXP(player, "Driving", 120)
			Net.Send(player, "Toast", { Title = "🚗 Права получены!", Text = "Теперь можно купить машину в автосалоне." })
			ctx.Progression.Sync(player)
		else
			Net.Notify(player, "Экзамен не сдан: не уложились во время. Попробуйте снова.", "bad")
		end
	end
end

local function startRun(player)
	if courses[player] then
		return
	end
	local pts = ctx.World.TrackPoints
	if not pts or #pts == 0 then
		return
	end
	if not Util.Near(player, pts[1], 25) then
		ctx.Net.Notify(player, "Встаньте на линию старта.", "info")
		return
	end
	courses[player] = { Kind = "run", Label = "Забег", Points = table.clone(pts), Index = 2, Started = os.clock(), Limit = 120, Radius = 11 }
	ctx.Net.Notify(player, "Марш! Бегите по дорожке через отмеченные точки.", "info")
	sendCourse(player)
end

-- Маршрут экзамена: случайная прогулка по графу улиц от автошколы.
local function drivingRoute(startPos)
	local best, bestD = nil, math.huge
	for i, n in Roads.Nodes do
		local d = (n - startPos).Magnitude
		if d < bestD and Roads.Adj[i] and #Roads.Adj[i] > 0 then
			best, bestD = i, d
		end
	end
	if not best then
		return nil
	end
	local route, prev, cur = { Roads.Nodes[best] + Vector3.new(0, 3, 0) }, nil, best
	for _ = 1, 7 do
		local options = {}
		for _, o in Roads.Adj[cur] do
			if o.To ~= prev then
				table.insert(options, o.To)
			end
		end
		if #options == 0 then
			break
		end
		prev, cur = cur, options[math.random(1, #options)]
		table.insert(route, Roads.Nodes[cur] + Vector3.new(0, 3, 0))
	end
	return route
end

local function startDriveExam(player)
	if courses[player] then
		return
	end
	local data = ctx.Data.Get(player)
	if not data then
		return
	end
	if data.License then
		ctx.Net.Notify(player, "У вас уже есть права.", "info")
		return
	end
	if not data.TheoryPassed then
		ctx.Net.Notify(player, "Сначала сдайте теорию ПДД в классе автошколы.", "bad")
		return
	end
	local wait = onCooldown(player, "drive", 30)
	if wait then
		ctx.Net.Notify(player, "Следующая попытка через " .. wait .. " сек.", "info")
		return
	end
	markUsed(player, "drive")
	local pad = ctx.World.DrivingPad
	local route = drivingRoute(pad.Position)
	if not route then
		return
	end
	local car = ctx.Vehicles.SpawnSpecial(player, "school", pad)
	local length = 0
	for i = 2, #route do
		length += (route[i] - route[i - 1]).Magnitude
	end
	courses[player] = { Kind = "drive", Label = "Экзамен по вождению", Points = route, Index = 1, Started = os.clock(), Limit = 60 + length / 18, Radius = 22, Car = car }
	ctx.Net.Notify(player, "Садитесь в учебную машину и проезжайте по отмеченным точкам.", "info")
	sendCourse(player)
end

local function tickCourses()
	for player, c in courses do
		if not player.Parent then
			courses[player] = nil
			continue
		end
		if os.clock() - c.Started > c.Limit then
			endCourse(player, false)
			continue
		end
		local pos = Util.Position(player)
		if pos then
			if c.Kind == "drive" then
				-- Засчитывается только за рулём учебной машины.
				local hum = Util.Humanoid(player)
				local seat = hum and hum.SeatPart
				if not (seat and c.Car and seat:IsDescendantOf(c.Car)) then
					pos = nil
				end
			end
		end
		if pos then
			local target = c.Points[c.Index]
			local flat = Vector3.new(pos.X - target.X, 0, pos.Z - target.Z)
			if flat.Magnitude <= c.Radius then
				c.Index += 1
				if c.Index > #c.Points then
					endCourse(player, true)
				else
					sendCourse(player)
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Игра на гитаре на улице
---------------------------------------------------------------------------
local function notes(player, on)
	local hrp = Util.HRP(player)
	if not hrp then
		return
	end
	local old = hrp:FindFirstChild("MusicNotes")
	if on and not old then
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "MusicNotes"
		pe.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(120, 200, 255))
		pe.Rate = 3
		pe.Lifetime = NumberRange.new(1.5, 2)
		pe.Speed = NumberRange.new(2, 4)
		pe.SpreadAngle = Vector2.new(40, 40)
		pe.Size = NumberSequence.new(0.6, 0)
		pe.LightEmission = 0.5
		pe.Parent = hrp
	elseif not on and old then
		old:Destroy()
	end
end

function ActivityService.ToggleBusking(player)
	if busking[player] then
		busking[player] = nil
		notes(player, false)
		ctx.Net.Notify(player, "Вы закончили играть.", "info")
		return
	end
	local pos = Util.Position(player)
	if not pos then
		return
	end
	if ctx.Progression.Level(player, "Music") < 1 then
		ctx.Net.Notify(player, "Сначала научитесь играть: уроки гитары в Доме культуры (навык «Музыка» 1).", "bad")
		return
	end
	busking[player] = { Start = pos }
	notes(player, true)
	ctx.Net.Notify(player, "🎸 Вы играете на гитаре. Стойте на месте — прохожие оставят чаевые.", "info")
end

local function tickBusking()
	local B = Config.Busking
	for player, b in busking do
		local pos = Util.Position(player)
		local hum = Util.Humanoid(player)
		if not pos or not hum or hum.Health <= 0 or hum.SeatPart or (pos - b.Start).Magnitude > 6 then
			busking[player] = nil
			notes(player, false)
			continue
		end
		local data = ctx.Data.Get(player)
		if data then
			local day = math.floor(os.time() / 86400)
			if not data.BuskToday or data.BuskToday.Day ~= day then
				data.BuskToday = { Day = day, Earned = 0 }
			end
			if data.BuskToday.Earned < B.DailyCap then
				local lvl = ctx.Progression.Level(player, "Music")
				local tip = math.floor(math.random(B.MinTip, B.MaxTip) * (1 + 0.4 * lvl))
				data.BuskToday.Earned += tip
				ctx.Data.AddCash(player, tip)
				ctx.Net.Send(player, "Earned", { Amount = tip, Text = "Чаевые за музыку" })
			end
		end
		ctx.Needs.Change(player, "Fun", 2)
		for _, other in Players:GetPlayers() do
			if other ~= player and Util.Distance(other, player) < 30 then
				ctx.Needs.Change(other, "Fun", 1)
			end
		end
	end
end

---------------------------------------------------------------------------

function ActivityService.Init(c)
	ctx = c
	local MakePrompt = ctx.WorldBuilder.MakePrompt
	for _, spot in ctx.World.Activities do
		local act = A[spot.Activity]
		local pp = MakePrompt(spot.Part, spot.Text, act and act.Name or "", spot.Hold, 9)
		pp.Triggered:Connect(function(player)
			if (player:GetAttribute("Jailed") or 0) > 0 then
				return
			end
			if spot.Activity == "run" then
				startRun(player)
			elseif spot.Activity == "drive" then
				startDriveExam(player)
			elseif act then
				startMiniGame(player, spot.Activity)
			end
		end)
	end

	ctx.Net.On("MiniGameResult", finishMiniGame)
	ctx.Net.On("CancelCourse", function(player)
		if courses[player] then
			endCourse(player, false)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		cooldowns[player] = nil
		busking[player] = nil
		local course = courses[player]
		if course and course.Car then
			course.Car:Destroy()
		end
		courses[player] = nil
	end)

	task.spawn(function()
		local acc = 0
		while true do
			local dt = task.wait(0.2)
			tickCourses()
			acc += dt
			if acc >= Config.Busking.Interval then
				acc = 0
				tickBusking()
			end
		end
	end)
end

return ActivityService
