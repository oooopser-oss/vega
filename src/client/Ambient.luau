-- Городская жизнь вокруг игрока (только на клиенте, сервер не нагружает):
-- поток машин по правой полосе со светофорами, прохожие на тротуарах,
-- переключение огней светофоров. С прохожими можно поговорить.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Roads = require(Shared:WaitForChild("Roads"))
local Rig = require(Shared:WaitForChild("Rig"))
local TrafficCar = require(Shared:WaitForChild("TrafficCar"))

local Ambient = {}

local MAX_CARS = 24
local MAX_PEDS = 32
local CAR_SPAWN_MIN, CAR_SPAWN_MAX, CAR_DESPAWN = 120, 450, 560
local PED_SPAWN_MIN, PED_SPAWN_MAX, PED_DESPAWN = 35, 240, 320

local PHRASES = {
	"Добрый день! Хорошая погода в Первоуральске.",
	"Говорят, на трубном заводе снова набирают людей.",
	"В «Пельменной» сегодня отличные пельмени!",
	"Видели Нижнешайтанский пруд? Летом там красиво.",
	"Не забудьте вечером заглянуть в парк культуры.",
	"Банкомат есть у супермаркета и у Сбербанка.",
	"Мой сосед недавно расписался в ЗАГСе. Вот это свадьба была!",
	"Осторожно на дорогах — переходите на зелёный.",
	"Работа кассира — неплохое начало карьеры.",
	"Купите цветы любимому человеку, это помогает!",
	"Полиция сегодня патрулирует центр, слышали?",
	"Такси можно вызвать прямо с телефона.",
}

local folder
local cars, peds = {}, {}
local onTalk -- колбэк: игрок поговорил с жителем
local rng = Random.new()

local function now()
	local ok, t = pcall(function()
		return workspace:GetServerTimeNow()
	end)
	return ok and t or os.clock()
end

local function myPosition()
	local char = Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		return hrp.Position, hrp
	end
	local cam = workspace.CurrentCamera
	return cam and cam.CFrame.Position or Vector3.zero, nil
end

-- Случайное ребро рядом с точкой на расстоянии [minD, maxD].
local function randomEdgeNear(pos, minD, maxD, filter)
	for _ = 1, 40 do
		local id = rng:NextInteger(1, #Roads.Edges)
		local e = Roads.Edges[id]
		if not filter or filter(e) then
			local a, b = Roads.Nodes[e.A], Roads.Nodes[e.B]
			local mid = (a + b) / 2
			local d = (Vector3.new(mid.X, pos.Y, mid.Z) - pos).Magnitude
			if d >= minD and d <= maxD then
				return id, e
			end
		end
	end
	return nil
end

local function nextNode(from, at)
	local options = Roads.Adj[at]
	if not options or #options == 0 then
		return from, nil
	end
	if #options == 1 then
		return options[1].To, options[1].Edge
	end
	for _ = 1, 6 do
		local o = options[rng:NextInteger(1, #options)]
		if o.To ~= from then
			return o.To, o.Edge
		end
	end
	return options[1].To, options[1].Edge
end

---------------------------------------------------------------------------
-- Машины
---------------------------------------------------------------------------
local function laneCFrame(c)
	local a, b = Roads.Nodes[c.From], Roads.Nodes[c.To]
	local dir = (b - a).Unit
	local pos = a + dir * c.T + Roads.Right(dir) * (c.Width / 4)
	return CFrame.lookAt(pos, pos + dir), dir
end

local function spawnCar(pos)
	local id, e = randomEdgeNear(pos, CAR_SPAWN_MIN, CAR_SPAWN_MAX)
	if not id then
		return
	end
	local forward = rng:NextNumber() < 0.5
	local car = TrafficCar.Build(rng:NextInteger(1, 1e6))
	local c = {
		Car = car,
		From = forward and e.A or e.B,
		To = forward and e.B or e.A,
		Width = e.Width,
		Class = e.Class,
		T = 0,
		Speed = 0,
	}
	c.Len = (Roads.Nodes[c.To] - Roads.Nodes[c.From]).Magnitude
	c.T = rng:NextNumber() * c.Len
	c.CF = laneCFrame(c)
	car.Model.Parent = folder
	table.insert(cars, c)
end

local function weatherKey()
	return workspace:GetAttribute("Weather") or "Clear"
end

local function carTargetSpeed(c, myPos, myHrp)
	-- В дождь, туман и снег машины едут осторожнее.
	local slow = Config.Weather.TrafficSpeed[weatherKey()] or 1
	local maxSpeed = (Roads.Speed[c.Class] or 30) * c.Car.Speed * slow
	local remaining = c.Len - c.T
	local target = maxSpeed
	-- Светофор.
	if Roads.Lights[c.To] and remaining < 40 then
		local dir = (Roads.Nodes[c.To] - Roads.Nodes[c.From]).Unit
		local state = Roads.LightState(c.To, Roads.Group(dir), now())
		local stopAt = (Roads.NodeWidth[c.To] or c.Width) / 2 + 8
		if state ~= "green" and remaining > stopAt - 2 then
			target = math.min(target, math.max(0, (remaining - stopAt) * 1.5))
		end
	end
	local fwd = c.CF.LookVector
	-- Машина впереди.
	for _, o in cars do
		if o ~= c then
			local off = o.CF.Position - c.CF.Position
			local ahead = off:Dot(fwd)
			if ahead > 0 and ahead < 22 and math.abs(off:Dot(c.CF.RightVector)) < 3.5 then
				target = math.min(target, math.max(0, (ahead - 13) * 2))
			end
		end
	end
	-- Игрок или его машина на дороге.
	if myHrp then
		local off = myPos - c.CF.Position
		local ahead = off:Dot(fwd)
		if ahead > 0 and ahead < 24 and math.abs(off:Dot(c.CF.RightVector)) < 5 then
			target = math.min(target, math.max(0, (ahead - 10) * 2))
		end
	end
	return target
end

local function updateCars(dt, myPos, myHrp)
	local parts, cfs = {}, {}
	for i = #cars, 1, -1 do
		local c = cars[i]
		local dist = (c.CF.Position - myPos).Magnitude
		if dist > CAR_DESPAWN then
			c.Car.Model:Destroy()
			table.remove(cars, i)
			continue
		end
		local target = carTargetSpeed(c, myPos, myHrp)
		local accel = target > c.Speed and 18 or 45
		c.Speed = c.Speed + math.clamp(target - c.Speed, -accel * dt, accel * dt)
		c.T += c.Speed * dt
		if c.T >= c.Len then
			local nextTo, edgeId = nextNode(c.From, c.To)
			if not edgeId then
				nextTo = c.From
			end
			local e = edgeId and Roads.Edges[edgeId]
			c.From, c.To = c.To, nextTo
			if e then
				c.Width, c.Class = e.Width, e.Class
			end
			c.T -= c.Len
			c.Len = (Roads.Nodes[c.To] - Roads.Nodes[c.From]).Magnitude
		end
		local targetCF = laneCFrame(c)
		-- Плавный поворот на перекрёстках.
		c.CF = c.CF:Lerp(targetCF, math.clamp(dt * 7, 0, 1))
		if dist < 400 then
			for j, cf in TrafficCar.CFrames(c.Car, c.CF) do
				table.insert(parts, c.Car.List[j])
				table.insert(cfs, cf)
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

---------------------------------------------------------------------------
-- Прохожие
---------------------------------------------------------------------------
local function walkPoint(p)
	local a, b = Roads.Nodes[p.From], Roads.Nodes[p.To]
	local dir = (b - a).Unit
	return a + dir * p.T + Roads.Right(dir) * p.Side * (p.Width / 2 + 2.5), dir
end

local function talk(p)
	if p.TalkUntil and os.clock() < p.TalkUntil then
		return
	end
	p.TalkUntil = os.clock() + 5
	local text = PHRASES[rng:NextInteger(1, #PHRASES)]
	pcall(function()
		TextChatService:DisplayBubble(p.Rig.Parts.Head, text)
	end)
	if onTalk then
		onTalk()
	end
end

local function spawnPed(pos)
	local id, e = randomEdgeNear(pos, PED_SPAWN_MIN, PED_SPAWN_MAX)
	if not id then
		return
	end
	local rig = Rig.Build({ Seed = rng:NextInteger(1, 1e6) })
	local forward = rng:NextNumber() < 0.5
	local p = {
		Rig = rig,
		From = forward and e.A or e.B,
		To = forward and e.B or e.A,
		Width = e.Width,
		Side = rng:NextNumber() < 0.5 and 1 or -1,
		Speed = rng:NextNumber(4.5, 7),
	}
	p.Len = (Roads.Nodes[p.To] - Roads.Nodes[p.From]).Magnitude
	p.T = rng:NextNumber() * p.Len
	local point, dir = walkPoint(p)
	p.CF = CFrame.lookAt(point, point + dir)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Поговорить"
	prompt.ObjectText = "Житель"
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = rig.Parts.Torso
	prompt.Triggered:Connect(function()
		talk(p)
	end)
	rig.Model.Parent = folder
	table.insert(peds, p)
end

local function updatePeds(dt, myPos)
	local parts, cfs = {}, {}
	for i = #peds, 1, -1 do
		local p = peds[i]
		local dist = (p.CF.Position - myPos).Magnitude
		if dist > PED_DESPAWN then
			p.Rig.Model:Destroy()
			table.remove(peds, i)
			continue
		end
		local talking = p.TalkUntil and os.clock() < p.TalkUntil
		local swing = 0
		if talking then
			-- Остановился и повернулся к игроку.
			local look = Vector3.new(myPos.X, p.CF.Position.Y, myPos.Z)
			if (look - p.CF.Position).Magnitude > 0.5 then
				p.CF = p.CF:Lerp(CFrame.lookAt(p.CF.Position, look), math.clamp(dt * 6, 0, 1))
			end
		else
			p.T += p.Speed * dt
			if p.T >= p.Len then
				local nextTo, edgeId = nextNode(p.From, p.To)
				local e = edgeId and Roads.Edges[edgeId]
				p.From, p.To = p.To, nextTo
				if e then
					p.Width = e.Width
				end
				p.T -= p.Len
				p.Len = math.max(1, (Roads.Nodes[p.To] - Roads.Nodes[p.From]).Magnitude)
			end
			local point, dir = walkPoint(p)
			local target = CFrame.lookAt(point, point + dir)
			p.CF = p.CF:Lerp(target, math.clamp(dt * 5, 0, 1))
			p.Rig.Phase += dt * p.Speed * 1.4
			swing = math.sin(p.Rig.Phase) * 0.55
		end
		if dist < 260 then
			local pose = Rig.Pose(p.Rig, p.CF + Vector3.new(0, 0.2, 0), swing)
			for j, part in p.Rig.List do
				table.insert(parts, part)
				table.insert(cfs, pose[j])
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

---------------------------------------------------------------------------
-- Огни светофоров (головы светофоров ставит сервер с тегом TrafficLight)
---------------------------------------------------------------------------
local LIGHT_COLORS = {
	Red = Color3.fromRGB(255, 40, 30),
	Yellow = Color3.fromRGB(255, 200, 30),
	Green = Color3.fromRGB(40, 230, 80),
}
local OFF = Color3.fromRGB(40, 40, 40)

local function updateLights()
	local t = now()
	for _, head in CollectionService:GetTagged("TrafficLight") do
		local node, group = head:GetAttribute("Node"), head:GetAttribute("Group")
		if node and group then
			local state = Roads.LightState(node, group, t)
			local on = state == "green" and "Green" or state == "yellow" and "Yellow" or "Red"
			for name, color in LIGHT_COLORS do
				local bulb = head:FindFirstChild(name)
				if bulb then
					local lit = name == on
					bulb.Color = lit and color or OFF
					bulb.Material = lit and Enum.Material.Neon or Enum.Material.SmoothPlastic
				end
			end
		end
	end
end

---------------------------------------------------------------------------

-- Снимок для превью (тесты): ставит машины и прохожих вокруг точки без анимации.
function Ambient.Snapshot(parent, pos, nCars, nPeds)
	folder = parent
	for _ = 1, nCars do
		spawnCar(pos)
	end
	for _ = 1, nPeds do
		spawnPed(pos)
	end
	for _, c in cars do
		for j, cf in TrafficCar.CFrames(c.Car, c.CF) do
			c.Car.List[j].CFrame = cf
		end
	end
	for _, p in peds do
		Rig.Place(p.Rig, p.CF + Vector3.new(0, 0.2, 0), 0.3)
	end
	return #cars, #peds
end

function Ambient.Start(talkCallback)
	onTalk = talkCallback
	folder = Instance.new("Folder")
	folder.Name = "AmbientLife"
	folder.Parent = workspace
	if #Roads.Edges == 0 then
		return
	end
	local lightAcc, spawnAcc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		local myPos, myHrp = myPosition()
		spawnAcc += dt
		if spawnAcc > 0.25 then
			spawnAcc = 0
			if #cars < MAX_CARS then
				spawnCar(myPos)
			end
			-- В непогоду прохожих меньше.
			if #peds < math.floor(MAX_PEDS * (Config.Weather.PedestrianShare[weatherKey()] or 1)) then
				spawnPed(myPos)
			end
		end
		updateCars(dt, myPos, myHrp)
		updatePeds(dt, myPos)
		lightAcc += dt
		if lightAcc > 0.3 then
			lightAcc = 0
			updateLights()
		end
	end)
end

return Ambient
