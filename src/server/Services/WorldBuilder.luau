-- Строит город Первоуральск при запуске сервера: реальные улицы и здания
-- из открытых данных OpenStreetMap (src/server/Map, генерирует
-- tools/pervouralsk/convert.py) + игровые здания с интерьерами
-- (мэрия, ОМВД, больница, банк, офис, супермаркет, кафе, автосалон, завод,
-- ЗАГС, парк, тюрьма, дома игроков) на местах реальных объектов.
-- Возвращает реестр важных точек (World), который используют остальные сервисы.

local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldBuilder = {}

local World = {
	Spawns = {},
	Shops = {},
	ATMs = {},
	Beds = {},
	Showers = {},
	FunSpots = {},
	JobPoints = {},
	Houses = {},
	Robbery = {},
	GPS = {},
	CarSpawns = {},
	Desks = {},
	Workers = {}, -- сотрудники-NPC: { CFrame, Role, Name, Lines }
	Activities = {}, -- точки занятий: { Part, Activity, Text, Hold }
	ShopPoints = {}, -- магазины с несколькими точками (киоски): [shopId] = { Part, ... }
}
WorldBuilder.World = World

local City

local function part(props)
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	local parent = props.Parent
	props.Parent = nil
	if typeof(props.Position) == "CFrame" then
		props.CFrame = props.Position
		props.Position = nil
	end
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent or City
	return p
end
WorldBuilder.Part = part

function WorldBuilder.MakePrompt(parent, action, object, hold, dist)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object or ""
	pp.HoldDuration = hold or 0
	pp.MaxActivationDistance = dist or 10
	pp.RequiresLineOfSight = false
	pp.Parent = parent
	return pp
end

local function surfaceText(target, face, text, bg, fg)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 25
	sg.Parent = target
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundColor3 = bg or Color3.fromRGB(30, 30, 40)
	tl.TextColor3 = fg or Color3.new(1, 1, 1)
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold
	tl.Text = text
	tl.Parent = sg
	return tl
end
WorldBuilder.SurfaceText = surfaceText

local function floatLabel(target, text, offsetY, color)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(200, 40)
	bb.StudsOffset = Vector3.new(0, offsetY or 3, 0)
	bb.MaxDistance = 45
	bb.AlwaysOnTop = false
	bb.Parent = target
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.TextColor3 = color or Color3.new(1, 1, 1)
	tl.TextStrokeTransparency = 0.3
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold
	tl.Text = text
	tl.Parent = bb
	return tl
end
WorldBuilder.FloatLabel = floatLabel

local function addGPS(name, pos)
	if typeof(pos) == "CFrame" then
		pos = pos.Position
	end
	table.insert(World.GPS, { Name = name, Position = pos })
end

-- Строит коробку здания с дверным проёмом спереди.
-- s = +1 — фасад смотрит в сторону +Z, s = -1 — в сторону -Z.
-- Возвращает модель и функцию at(lx, ly, lz) для локальных координат
-- (lz > 0 — ближе к фасаду).
local function building(o)
	local m = Instance.new("Model")
	m.Name = o.Name
	m.Parent = City
	local cx, cz, w, d, h = o.X, o.Z, o.W, o.D, o.H
	local color = o.Color or Color3.fromRGB(200, 200, 200)
	local mat = o.Material or Enum.Material.Concrete
	local t = 1
	local doorW = o.DoorW or 10
	local doorH = 12

	-- Локальная система здания: +Z — фасад (дверь), поворот Yaw в градусах.
	local base = CFrame.new(cx, 0, cz) * CFrame.Angles(0, math.rad(o.Yaw or 0), 0)
	local function at(lx, ly, lz)
		return base * CFrame.new(lx, ly, lz)
	end

	part({ Parent = m, Name = "Floor", Size = Vector3.new(w, 0.4, d), Position = at(0, 0.2, 0), Color = o.FloorColor or Color3.fromRGB(170, 160, 150), Material = Enum.Material.WoodPlanks })
	part({ Parent = m, Name = "Back", Size = Vector3.new(w, h, t), Position = at(0, h / 2, -d / 2 + t / 2), Color = color, Material = mat })
	part({ Parent = m, Name = "Left", Size = Vector3.new(t, h, d), Position = at(-w / 2 + t / 2, h / 2, 0), Color = color, Material = mat })
	part({ Parent = m, Name = "Right", Size = Vector3.new(t, h, d), Position = at(w / 2 - t / 2, h / 2, 0), Color = color, Material = mat })
	local sideW = (w - doorW) / 2
	part({ Parent = m, Name = "FrontL", Size = Vector3.new(sideW, h, t), Position = at(-(doorW / 2 + sideW / 2), h / 2, d / 2 - t / 2), Color = color, Material = mat })
	part({ Parent = m, Name = "FrontR", Size = Vector3.new(sideW, h, t), Position = at(doorW / 2 + sideW / 2, h / 2, d / 2 - t / 2), Color = color, Material = mat })
	if h > doorH then
		part({ Parent = m, Name = "Lintel", Size = Vector3.new(doorW, h - doorH, t), Position = at(0, doorH + (h - doorH) / 2, d / 2 - t / 2), Color = color, Material = mat })
	end
	part({ Parent = m, Name = "Roof", Size = Vector3.new(w + 2, 1, d + 2), Position = at(0, h + 0.5, 0), Color = o.RoofColor or Color3.fromRGB(70, 70, 80), Material = Enum.Material.Slate })

	-- Окна на фасаде и сзади.
	local glass = Color3.fromRGB(150, 200, 240)
	local winY = math.min(h * 0.55, h - 3)
	for _, side in { -1, 1 } do
		local wx = side * (doorW / 2 + sideW / 2)
		if sideW > 6 then
			part({ Parent = m, Name = "Window", Size = Vector3.new(math.min(sideW - 4, 12), 5, 0.3), Position = at(wx, winY, d / 2 + 0.2), Color = glass, Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false })
		end
		part({ Parent = m, Name = "Window", Size = Vector3.new(math.min(w / 3, 14), 5, 0.3), Position = at(side * w / 4, winY, -d / 2 - 0.2), Color = glass, Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false })
	end
	-- Многоэтажные окна для высоких зданий.
	if h >= 30 then
		for y = 8, h - 6, 8 do
			for _, side in { -1, 1 } do
				part({ Parent = m, Name = "SideWindow", Size = Vector3.new(0.3, 4, d - 8), Position = at(side * (w / 2 + 0.2), y, 0), Color = glass, Material = Enum.Material.Glass, Transparency = 0.2, CanCollide = false })
			end
		end
	end

	-- Вывеска.
	if o.Sign then
		local signPart = part({ Parent = m, Name = "Sign", Size = Vector3.new(math.min(w * 0.7, 40), 4, 0.5), Position = at(0, h - 2.5, d / 2 + 0.6), Color = Color3.fromRGB(30, 30, 40), CanCollide = false })
		surfaceText(signPart, Enum.NormalId.Back, o.Sign, o.SignColor or Color3.fromRGB(30, 30, 40), Color3.new(1, 1, 1))
	end

	-- Освещение внутри.
	local lamp = part({ Parent = m, Name = "Lamp", Size = Vector3.new(4, 0.4, 4), Position = at(0, h - 0.3, 0), Color = Color3.fromRGB(255, 250, 220), Material = Enum.Material.Neon, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Range = math.max(w, d) * 0.7
	light.Brightness = 1.2
	light.Parent = lamp

	-- Козырёк над входом и фонари по бокам двери.
	part({ Parent = m, Name = "EntranceCanopy", Size = Vector3.new(doorW + 4, 0.5, 4), CFrame = at(0, doorH + 0.6, d / 2 + 2), Color = o.RoofColor or Color3.fromRGB(70, 70, 80), Material = Enum.Material.Metal })
	for _, side in { -1, 1 } do
		local wl = part({ Parent = m, Name = "WallLamp", Size = Vector3.new(0.8, 1.4, 0.6), CFrame = at(side * (doorW / 2 + 1.5), doorH - 2, d / 2 + 0.4), Color = Color3.fromRGB(255, 235, 190), Material = Enum.Material.Neon, CanCollide = false })
		local pl = Instance.new("PointLight")
		pl.Range = 14
		pl.Brightness = 0.8
		pl.Color = Color3.fromRGB(255, 220, 170)
		pl.Parent = wl
	end

	-- Дорожка от двери к дороге.
	if o.Path then
		part({ Parent = m, Name = "Path", Size = Vector3.new(doorW, 0.3, o.Path), Position = at(0, 0.15, d / 2 + o.Path / 2), Color = Color3.fromRGB(180, 180, 175), Material = Enum.Material.Concrete })
	end

	addGPS(o.GPSName or o.Name, at(0, 3, d / 2 + 6))
	return m, at
end

local function worker(cf, role, name, lines)
	table.insert(World.Workers, { CFrame = cf, Role = role, Name = name, Lines = lines })
end
-- Сотрудник за стойкой: стоит в точке (lx, lz) здания лицом к входу (+Z).
local function staff(at, lx, lz, role, name, lines)
	worker(at(lx, 0.4, lz) * CFrame.Angles(0, math.rad(180), 0), role, name, lines)
end

local function counter(parent, pos, size, color)
	return part({ Parent = parent, Name = "Counter", Size = size or Vector3.new(10, 3.5, 3), Position = pos, Color = color or Color3.fromRGB(120, 80, 50), Material = Enum.Material.Wood })
end

local function interactable(parent, name, pos, size, color, label, material)
	local p = part({ Parent = parent, Name = name, Size = size or Vector3.new(3, 3, 3), Position = pos, Color = color or Color3.fromRGB(200, 200, 200), Material = material or Enum.Material.SmoothPlastic })
	if label then
		floatLabel(p, label, 3, Color3.fromRGB(255, 255, 200))
	end
	return p
end

-- Деревья трёх видов, как на Урале: лиственные, ели и берёзы.
local function tree(pos)
	local kind = (math.floor(pos.X * 7 + pos.Z * 13) % 3)
	if kind == 0 then
		-- Ель: ствол и три яруса хвои.
		part({ Name = "Trunk", Size = Vector3.new(1.4, 6, 1.4), Position = pos + Vector3.new(0, 3, 0), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood })
		local green = Color3.fromRGB(35, 85 + math.random(0, 25), 45)
		for i, r in { 10, 7.5, 4.5 } do
			local l = part({ Name = "Leaves", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4.5, r, r), CFrame = CFrame.new(pos + Vector3.new(0, 4 + i * 3.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = green, Material = Enum.Material.Grass })
			l.CanCollide = false
		end
		local tip = part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.6, 2.6), Position = pos + Vector3.new(0, 17.5, 0), Color = green, Material = Enum.Material.Grass })
		tip.CanCollide = false
	elseif kind == 1 then
		-- Берёза: белый ствол, светлая крона.
		part({ Name = "Trunk", Size = Vector3.new(1.2, 12, 1.2), Position = pos + Vector3.new(0, 6, 0), Color = Color3.fromRGB(235, 232, 225), Material = Enum.Material.SmoothPlastic })
		part({ Name = "TrunkMark", Size = Vector3.new(1.25, 0.5, 1.25), Position = pos + Vector3.new(0, 4.5, 0), Color = Color3.fromRGB(40, 40, 40), CanCollide = false })
		for _, off in { Vector3.new(0, 13, 0), Vector3.new(1.5, 15.5, 0.8) } do
			local l = part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(7, 7, 7), Position = pos + off, Color = Color3.fromRGB(120, 175 + math.random(0, 25), 70), Material = Enum.Material.Grass })
			l.CanCollide = false
		end
	else
		-- Лиственное дерево с пышной кроной.
		part({ Name = "Trunk", Size = Vector3.new(2, 9, 2), Position = pos + Vector3.new(0, 4.5, 0), Color = Color3.fromRGB(100, 70, 40), Material = Enum.Material.Wood })
		local green = Color3.fromRGB(60, 135 + math.random(0, 40), 55)
		for _, off in { Vector3.new(0, 12, 0), Vector3.new(2.5, 10.5, 1), Vector3.new(-2, 11, -1.5) } do
			local l = part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(8, 8, 8), Position = pos + off, Color = green, Material = Enum.Material.Grass })
			l.CanCollide = false
		end
	end
end

local function bench(pos, facingZ)
	local m = Instance.new("Model")
	m.Name = "Bench"
	m.Parent = City
	local cf = typeof(pos) == "CFrame" and pos or CFrame.new(pos)
	local seat = part({ Parent = m, Name = "Seat", Size = Vector3.new(7, 0.6, 2.5), CFrame = cf * CFrame.new(0, 1.6, 0), Color = Color3.fromRGB(140, 90, 50), Material = Enum.Material.Wood })
	part({ Parent = m, Name = "BackRest", Size = Vector3.new(7, 2.5, 0.4), CFrame = cf * CFrame.new(0, 3, -facingZ * 1.1), Color = Color3.fromRGB(140, 90, 50), Material = Enum.Material.Wood })
	return seat
end

local function streetLamp(pos)
	part({ Name = "LampBase", Size = Vector3.new(1.4, 1.2, 1.4), Position = pos + Vector3.new(0, 0.6, 0), Color = Color3.fromRGB(45, 45, 50), Material = Enum.Material.Metal })
	part({ Name = "LampPost", Size = Vector3.new(0.7, 17, 0.7), Position = pos + Vector3.new(0, 8.5, 0), Color = Color3.fromRGB(55, 55, 60), Material = Enum.Material.Metal })
	part({ Name = "LampArm", Size = Vector3.new(4, 0.4, 0.4), Position = pos + Vector3.new(1.8, 16.8, 0), Color = Color3.fromRGB(55, 55, 60), Material = Enum.Material.Metal })
	part({ Name = "LampHood", Size = Vector3.new(2.6, 0.6, 1.6), Position = pos + Vector3.new(3.6, 16.7, 0), Color = Color3.fromRGB(55, 55, 60), Material = Enum.Material.Metal })
	local bulb = part({ Name = "LampBulb", Size = Vector3.new(2.2, 0.3, 1.2), Position = pos + Vector3.new(3.6, 16.3, 0), Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon, CanCollide = false })
	local l = Instance.new("PointLight")
	l.Range = 35
	l.Brightness = 1.5
	l.Color = Color3.fromRGB(255, 225, 170)
	l.Parent = bulb
end

---------------------------------------------------------------------------
-- Карта Первоуральска (данные © участники OpenStreetMap, ODbL)
---------------------------------------------------------------------------
local MapFolder = script.Parent.Parent:WaitForChild("Map")
local Meta = require(MapFolder:WaitForChild("Meta"))
WorldBuilder.Meta = Meta

-- Перебирает записи вида "a,b,c;a,b,c" из модулей-чанков.
local function records(kind)
	local out = {}
	for _, name in Meta.Chunks[kind] or {} do
		local data = require(MapFolder:WaitForChild(name))
		for rec in string.gmatch(data, "[^;]+") do
			local fields = string.split(rec, ",")
			table.insert(out, fields)
		end
	end
	return out
end

local ASPHALT = Color3.fromRGB(52, 52, 58)
local BUILDING_COLORS = {
	Color3.fromRGB(205, 200, 190), Color3.fromRGB(220, 210, 185), Color3.fromRGB(185, 175, 165),
	Color3.fromRGB(225, 215, 200), Color3.fromRGB(190, 195, 200), Color3.fromRGB(170, 120, 90),
	Color3.fromRGB(200, 170, 130), Color3.fromRGB(150, 160, 120), Color3.fromRGB(180, 140, 110),
	Color3.fromRGB(140, 135, 140),
}

local yieldCounter = 0
local function maybeYield()
	yieldCounter += 1
	if yieldCounter % 400 == 0 then
		task.wait()
	end
end

local function buildTerrain()
	-- Земля из ровных плит (рельеф Terrain перекрывал дороги).
	local b = Meta.Bounds
	local margin = 300
	local x0, x1 = b.MinX - margin, b.MaxX + margin
	local z0, z1 = b.MinZ - margin, b.MaxZ + margin
	local tile = 2000
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = City
	for x = x0, x1, tile do
		for z = z0, z1, tile do
			local sx, sz = math.min(tile, x1 - x), math.min(tile, z1 - z)
			part({ Parent = ground, Name = "Ground", Size = Vector3.new(sx, 2, sz), Position = Vector3.new(x + sx / 2, -1, z + sz / 2), Color = Color3.fromRGB(104, 158, 82), Material = Enum.Material.Grass })
		end
	end
	for _, r in records("Parks") do
		part({ Parent = ground, Name = "Park", Size = Vector3.new(tonumber(r[3]), 0.2, tonumber(r[4])), Position = Vector3.new(tonumber(r[1]), -0.05, tonumber(r[2])), Color = Color3.fromRGB(78, 145, 62), Material = Enum.Material.Grass })
	end
	for _, r in records("Water") do
		part({ Parent = ground, Name = "Water", Size = Vector3.new(tonumber(r[3]), 0.3, tonumber(r[4])), Position = Vector3.new(tonumber(r[1]), -0.05, tonumber(r[2])), Color = Color3.fromRGB(62, 120, 180), Material = Enum.Material.Glass, Transparency = 0.1, Reflectance = 0.15, CanCollide = false })
	end
	-- Невидимые стены по краю карты.
	local cx, cz = (b.MinX + b.MaxX) / 2, (b.MinZ + b.MaxZ) / 2
	local w, d = b.MaxX - b.MinX, b.MaxZ - b.MinZ
	for _, wall in { { cx, b.MinZ, w, 2 }, { cx, b.MaxZ, w, 2 }, { b.MinX, cz, 2, d }, { b.MaxX, cz, 2, d } } do
		local sx, sz = wall[3], wall[4]
		-- Деталь не может быть длиннее 2048 studs — режем на куски.
		local n = math.ceil(math.max(sx, sz) / 2000)
		for i = 1, n do
			local t = (i - 0.5) / n - 0.5
			local px = wall[1] + (sx > sz and t * sx or 0)
			local pz = wall[2] + (sz > sx and t * sz or 0)
			part({ Name = "Border", Size = Vector3.new(sx > sz and sx / n or sx, 300, sz > sx and sz / n or sz), Position = Vector3.new(px, 150, pz), Transparency = 1 })
		end
	end
end

local SIDEWALK = Color3.fromRGB(176, 174, 168)
local NO_SIDEWALK = { service = true, pedestrian = true, rail = true }

local function buildRoads()
	local classes = Meta.RoadClasses
	local folder = Instance.new("Folder")
	folder.Name = "Roads"
	folder.Parent = City
	-- Проезжая часть: верх на высоте 0.3, тротуар под ней шире на 5 studs с каждой стороны.
	local ROAD_TOP, WALK_TOP = 0.3, 0.2
	for _, r in records("Roads") do
		local x1, z1, x2, z2 = tonumber(r[1]), tonumber(r[2]), tonumber(r[3]), tonumber(r[4])
		local w = tonumber(r[5])
		local cls = classes[tonumber(r[6])]
		local a, b = Vector3.new(x1, 0, z1), Vector3.new(x2, 0, z2)
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		if cls == "rail" then
			part({ Parent = folder, Name = "RailBed", Size = Vector3.new(w, 0.6, len + 0.2), CFrame = cf + Vector3.new(0, 0.1, 0), Color = Color3.fromRGB(110, 98, 86), Material = Enum.Material.Slate })
			for _, off in { -2.4, 2.4 } do
				part({ Parent = folder, Name = "Rail", Size = Vector3.new(0.4, 0.4, len), CFrame = cf * CFrame.new(off, 0.6, 0), Color = Color3.fromRGB(90, 90, 95), Material = Enum.Material.Metal })
			end
		else
			local color, mat = Color3.fromRGB(48, 48, 54), Enum.Material.Asphalt
			if cls == "pedestrian" then
				color, mat = SIDEWALK, Enum.Material.Concrete
			elseif cls == "service" then
				-- Дворовые проезды: светлее и уже основных улиц.
				color, w = Color3.fromRGB(105, 105, 110), w - 2
			end
			part({ Parent = folder, Name = cls, Size = Vector3.new(w, 0.6, len + 0.2), CFrame = cf + Vector3.new(0, ROAD_TOP - 0.3, 0), Color = color, Material = mat })
			if not NO_SIDEWALK[cls] then
				part({ Parent = folder, Name = "Sidewalk", Size = Vector3.new(w + 10, 0.6, len + 0.2), CFrame = cf + Vector3.new(0, WALK_TOP - 0.3, 0), Color = SIDEWALK, Material = Enum.Material.Concrete })
			end
			if cls == "primary" or cls == "secondary" or cls == "tertiary" then
				-- Осевая разметка: сплошная на главных, прерывистая на остальных.
				if cls == "tertiary" then
					local n = math.floor(len / 12)
					for i = 0, n - 1 do
						part({ Parent = folder, Name = "Dash", Size = Vector3.new(0.5, 0.05, 6), CFrame = cf * CFrame.new(0, ROAD_TOP + 0.02, -len / 2 + 6 + i * 12), Color = Color3.fromRGB(240, 240, 235), CanCollide = false })
					end
				else
					part({ Parent = folder, Name = "Line", Size = Vector3.new(0.6, 0.05, len), CFrame = cf + Vector3.new(0, ROAD_TOP + 0.02, 0), Color = Color3.fromRGB(240, 240, 235), CanCollide = false })
				end
			end
		end
		maybeYield()
	end
	for _, r in records("Discs") do
		local w = tonumber(r[3])
		local x, z = tonumber(r[1]), tonumber(r[2])
		local jointColor = w <= 12 and Color3.fromRGB(105, 105, 110) or Color3.fromRGB(48, 48, 54)
		local jw = w <= 12 and w - 2 or w
		part({ Parent = folder, Name = "Joint", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, jw, jw), CFrame = CFrame.new(x, ROAD_TOP - 0.31, z) * CFrame.Angles(0, 0, math.rad(90)), Color = jointColor, Material = Enum.Material.Asphalt })
		if w >= 18 and r[4] ~= "0" then
			part({ Parent = folder, Name = "SidewalkJoint", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, w + 10, w + 10), CFrame = CFrame.new(x, WALK_TOP - 0.31, z) * CFrame.Angles(0, 0, math.rad(90)), Color = SIDEWALK, Material = Enum.Material.Concrete })
		end
		maybeYield()
	end
end

local ROOF_COLORS = {
	Color3.fromRGB(140, 50, 40), Color3.fromRGB(95, 70, 55), Color3.fromRGB(60, 100, 70),
	Color3.fromRGB(70, 85, 110), Color3.fromRGB(120, 120, 125),
}
local WINDOW = Color3.fromRGB(60, 85, 110)

-- Двускатная крыша над прямоугольником sx × sz (конёк вдоль длинной стороны).
local function gableRoof(parent, cf, sx, sz, height, color)
	if sz > sx then
		cf = cf * CFrame.Angles(0, math.rad(90), 0)
		sx, sz = sz, sx
	end
	local half = sz / 2 + 0.8
	-- У клина высокая грань сзади (+Z), скат спускается вперёд (−Z).
	part({ Parent = parent, ClassName = "WedgePart", Name = "Roof", Size = Vector3.new(sx + 1.6, height, half), CFrame = cf * CFrame.new(0, height / 2, -half / 2), Color = color, Material = Enum.Material.Slate })
	part({ Parent = parent, ClassName = "WedgePart", Name = "Roof", Size = Vector3.new(sx + 1.6, height, half), CFrame = cf * CFrame.new(0, height / 2, half / 2) * CFrame.Angles(0, math.rad(180), 0), Color = color, Material = Enum.Material.Slate })
end

local function buildRealBuildings()
	local folder = Instance.new("Folder")
	folder.Name = "Pervouralsk"
	folder.Parent = City
	for _, r in records("Buildings") do
		local cx, cz, sx, sz = tonumber(r[1]), tonumber(r[2]), tonumber(r[3]), tonumber(r[4])
		local yaw, h, ci = tonumber(r[5]), tonumber(r[6]), tonumber(r[7])
		local color = BUILDING_COLORS[ci] or BUILDING_COLORS[1]
		local base = CFrame.new(cx, 0, cz) * CFrame.Angles(0, math.rad(yaw), 0)
		if ci == 10 then
			-- Промышленное здание: профлист, тёмная кровля, ленточное остекление.
			part({ Parent = folder, Name = "Building", Size = Vector3.new(sx, h, sz), CFrame = base * CFrame.new(0, h / 2, 0), Color = color, Material = Enum.Material.CorrodedMetal })
			part({ Parent = folder, Name = "Roof", Size = Vector3.new(sx + 0.4, 0.6, sz + 0.4), CFrame = base * CFrame.new(0, h + 0.3, 0), Color = Color3.fromRGB(85, 85, 90), Material = Enum.Material.Metal })
			part({ Parent = folder, Name = "Windows", Size = Vector3.new(sx + 0.2, 2, sz + 0.2), CFrame = base * CFrame.new(0, h - 3, 0), Color = WINDOW, Material = Enum.Material.Glass, CanCollide = false })
		elseif h <= 8 then
			-- Частный дом: стены, двускатная крыша, окна и дверь.
			local wallH = 7
			part({ Parent = folder, Name = "House", Size = Vector3.new(sx, wallH, sz), CFrame = base * CFrame.new(0, wallH / 2, 0), Color = color, Material = Enum.Material.WoodPlanks })
			gableRoof(folder, base * CFrame.new(0, wallH, 0), sx, sz, math.clamp(math.min(sx, sz) * 0.35, 3, 8), ROOF_COLORS[(math.floor(cx + cz) % #ROOF_COLORS) + 1])
			if sx >= 8 and sz >= 8 then
				local long, short = sx >= sz, nil
				short = long and sz or sx
				for _, side in { -1, 1 } do
					local off = (short / 2 + 0.1) * side
					local wcf = long and base * CFrame.new(sx * 0.22, 4, off) or base * CFrame.new(off, 4, sz * 0.22)
					part({ Parent = folder, Name = "Window", Size = long and Vector3.new(3, 2.6, 0.3) or Vector3.new(0.3, 2.6, 3), CFrame = wcf, Color = WINDOW, Material = Enum.Material.Glass, CanCollide = false })
				end
				local dcf = long and base * CFrame.new(-sx * 0.25, 2.6, sz / 2 + 0.1) or base * CFrame.new(sx / 2 + 0.1, 2.6, -sz * 0.25)
				part({ Parent = folder, Name = "Door", Size = long and Vector3.new(2.6, 5, 0.3) or Vector3.new(0.3, 5, 2.6), CFrame = dcf, Color = Color3.fromRGB(100, 65, 40), Material = Enum.Material.Wood, CanCollide = false })
			end
		else
			-- Многоэтажка: цоколь, этажи с лентами окон, парапет на крыше.
			part({ Parent = folder, Name = "Building", Size = Vector3.new(sx, h, sz), CFrame = base * CFrame.new(0, h / 2, 0), Color = color, Material = Enum.Material.Concrete })
			part({ Parent = folder, Name = "Plinth", Size = Vector3.new(sx + 0.4, 1.8, sz + 0.4), CFrame = base * CFrame.new(0, 0.9, 0), Color = color:Lerp(Color3.new(0, 0, 0), 0.35), Material = Enum.Material.Concrete })
			part({ Parent = folder, Name = "Parapet", Size = Vector3.new(sx + 0.6, 0.9, sz + 0.6), CFrame = base * CFrame.new(0, h + 0.2, 0), Color = color:Lerp(Color3.new(1, 1, 1), 0.3), Material = Enum.Material.Concrete })
			for y = 4.5, h - 3, 5 do
				local band = part({ Parent = folder, Name = "Windows", Size = Vector3.new(sx + 0.2, 1.8, sz + 0.2), CFrame = base * CFrame.new(0, y, 0), Color = WINDOW, Material = Enum.Material.Glass, CanCollide = false })
				if (math.floor(cx + cz + y) % 3) == 0 then
					band:AddTag("NightGlow") -- вечером в этих квартирах зажигается свет
				end
			end
			-- Детали фасада на длинных секциях: лоджии, подъезды с козырьками, вентиляция.
			local long, short = math.max(sx, sz), math.min(sx, sz)
			if long >= 28 and short >= 8 then
				local rot = sx >= sz and base or base * CFrame.Angles(0, math.rad(90), 0)
				local lighter = color:Lerp(Color3.new(1, 1, 1), 0.25)
				for _, f in { -0.3, 0, 0.3 } do
					part({ Parent = folder, Name = "Loggias", Size = Vector3.new(5, h - 6, 1.6), CFrame = rot * CFrame.new(long * f, 3 + (h - 6) / 2, short / 2 + 0.8), Color = lighter, Material = Enum.Material.Concrete })
				end
				local entrances = math.max(1, math.floor(long / 32))
				for i = 1, entrances do
					local ex = -long / 2 + long * (i - 0.5) / entrances
					part({ Parent = folder, Name = "Entrance", Size = Vector3.new(3, 4.4, 0.3), CFrame = rot * CFrame.new(ex, 2.2, -short / 2 - 0.15), Color = Color3.fromRGB(95, 60, 35), Material = Enum.Material.Wood, CanCollide = false })
					part({ Parent = folder, Name = "Canopy", Size = Vector3.new(5, 0.4, 2.6), CFrame = rot * CFrame.new(ex, 5, -short / 2 - 1.3), Color = Color3.fromRGB(120, 120, 125), Material = Enum.Material.Metal })
				end
				part({ Parent = folder, Name = "RoofVent", Size = Vector3.new(3, 2.2, 3), CFrame = rot * CFrame.new(long * 0.2, h + 1.6, 0), Color = Color3.fromRGB(150, 150, 150), Material = Enum.Material.Concrete })
				if (math.floor(cx) % 2) == 0 then
					part({ Parent = folder, Name = "Antenna", Size = Vector3.new(0.3, 6, 0.3), CFrame = rot * CFrame.new(-long * 0.25, h + 3.5, 0), Color = Color3.fromRGB(90, 90, 95), Material = Enum.Material.Metal })
				end
			end
		end
		maybeYield()
	end
end

local function buildStreetSigns()
	for _, r in records("Signs") do
		local x, z, yaw = tonumber(r[1]), tonumber(r[2]), tonumber(r[3])
		local name = r[4]
		part({ Name = "StreetSignPost", Size = Vector3.new(0.5, 9, 0.5), Position = Vector3.new(x, 4.5, z), Color = Color3.fromRGB(60, 60, 65), Material = Enum.Material.Metal })
		local board = part({ Name = "StreetSign", Size = Vector3.new(math.clamp(#name * 0.35, 8, 20), 2.2, 0.3), CFrame = CFrame.new(x, 9.5, z) * CFrame.Angles(0, math.rad(yaw), 0), Color = Color3.fromRGB(30, 70, 150), CanCollide = false })
		surfaceText(board, Enum.NormalId.Front, name, Color3.fromRGB(30, 70, 150))
		surfaceText(board, Enum.NormalId.Back, name, Color3.fromRGB(30, 70, 150))
	end
end

---------------------------------------------------------------------------
-- Жилой квартал
---------------------------------------------------------------------------
local HOUSE_COLORS = {
	Color3.fromRGB(230, 200, 160), Color3.fromRGB(180, 210, 230), Color3.fromRGB(230, 180, 180),
	Color3.fromRGB(200, 230, 190), Color3.fromRGB(240, 230, 170), Color3.fromRGB(210, 190, 230),
}

-- Коттедж игрока: участок 46×46 с газоном и забором, дом 30×22 с двускатной
-- крышей, крыльцом, окнами, трубой; внутри спальня, душ, кухня, гостиная.
local ROOF_PALETTE = { Color3.fromRGB(150, 55, 45), Color3.fromRGB(70, 90, 120), Color3.fromRGB(70, 110, 75), Color3.fromRGB(105, 75, 60) }

local function buildHouse(id, a)
	local m = Instance.new("Model")
	m.Name = "House" .. id
	m.Parent = City
	local base = CFrame.new(a.X, 0, a.Z) * CFrame.Angles(0, math.rad(a.Yaw), 0)
	local function at(lx, ly, lz)
		return base * CFrame.new(lx, ly, lz)
	end
	local wall = HOUSE_COLORS[(id - 1) % #HOUSE_COLORS + 1]
	local roofColor = ROOF_PALETTE[(id - 1) % #ROOF_PALETTE + 1]
	local trim = Color3.fromRGB(250, 250, 245)
	local wood = Color3.fromRGB(120, 80, 50)

	-- Участок: газон, забор с калиткой, дорожка до улицы.
	part({ Parent = m, Name = "Lawn", Size = Vector3.new(46, 0.3, 46), CFrame = at(0, 0.05, 0), Color = Color3.fromRGB(110, 175, 85), Material = Enum.Material.Grass })
	local fenceH = 3.5
	local function fence(lx, lz, sx, sz)
		part({ Parent = m, Name = "Fence", Size = Vector3.new(sx, fenceH, sz), CFrame = at(lx, fenceH / 2, lz), Color = trim, Material = Enum.Material.WoodPlanks })
	end
	fence(0, -23, 46, 0.5)
	fence(-23, 0, 0.5, 46)
	fence(23, 0, 0.5, 46)
	fence(-13.5, 23, 19, 0.5)
	fence(13.5, 23, 19, 0.5)
	for _, lx in { -4, 4 } do
		part({ Parent = m, Name = "GatePost", Size = Vector3.new(1, 5, 1), CFrame = at(lx, 2.5, 23), Color = trim, Material = Enum.Material.Wood })
	end
	part({ Parent = m, Name = "Path", Size = Vector3.new(4, 0.35, 28), CFrame = at(0, 0.18, 19), Color = Color3.fromRGB(190, 180, 165), Material = Enum.Material.Cobblestone })

	-- Дом: пол, стены с проёмами под дверь и окна.
	local W, D, H = 30, 22, 11
	local zc = -6 -- центр дома по глубине (участок спереди свободен под двор)
	local zf, zb = zc + D / 2, zc - D / 2
	part({ Parent = m, Name = "Foundation", Size = Vector3.new(W + 1, 1, D + 1), CFrame = at(0, 0.5, zc), Color = Color3.fromRGB(140, 135, 130), Material = Enum.Material.Concrete })
	part({ Parent = m, Name = "Floor", Size = Vector3.new(W - 1, 0.2, D - 1), CFrame = at(0, 1.05, zc), Color = Color3.fromRGB(175, 135, 95), Material = Enum.Material.WoodPlanks })
	local function wallPart(lx, ly, lz, sx, sy, sz)
		part({ Parent = m, Name = "Wall", Size = Vector3.new(sx, sy, sz), CFrame = at(lx, ly, lz), Color = wall, Material = Enum.Material.Plaster })
	end
	local top = 1 + H
	wallPart(0, 1 + H / 2, zb + 0.5, W, H, 1) -- задняя
	wallPart(-W / 2 + 0.5, 1 + H / 2, zc, 1, H, D) -- левая
	wallPart(W / 2 - 0.5, 1 + H / 2, zc, 1, H, D) -- правая
	-- Фасад с дверью (ширина 5, высота 8).
	wallPart(-(2.5 + (W / 2 - 2.5) / 2), 1 + H / 2, zf - 0.5, W / 2 - 2.5, H, 1)
	wallPart(2.5 + (W / 2 - 2.5) / 2, 1 + H / 2, zf - 0.5, W / 2 - 2.5, H, 1)
	wallPart(0, 1 + 8 + (H - 8) / 2, zf - 0.5, 5, H - 8, 1)
	part({ Parent = m, Name = "Ceiling", Size = Vector3.new(W, 0.4, D), CFrame = at(0, top + 0.2, zc), Color = trim, Material = Enum.Material.SmoothPlastic })

	-- Окна с белыми рамами (стекло чуть выступает из стены).
	local function window(lx, lz, alongX)
		local size = alongX and Vector3.new(5, 4, 0.3) or Vector3.new(0.3, 4, 5)
		local frame = alongX and Vector3.new(5.8, 4.8, 0.2) or Vector3.new(0.2, 4.8, 5.8)
		local out = alongX and Vector3.new(0, 0, lz > zc and 0.15 or -0.15) or Vector3.new(lx > 0 and 0.15 or -0.15, 0, 0)
		part({ Parent = m, Name = "WindowFrame", Size = frame, CFrame = at(lx, 6, lz) + base:VectorToWorldSpace(out), Color = trim, CanCollide = false })
		part({ Parent = m, Name = "Window", Size = size, CFrame = at(lx, 6, lz) + base:VectorToWorldSpace(out * 2), Color = Color3.fromRGB(150, 200, 235), Material = Enum.Material.Glass, Transparency = 0.35, CanCollide = false })
	end
	window(-9, zf, true)
	window(-8, zb, true)
	window(8, zb, true)
	window(-W / 2, zc, false)
	window(W / 2, zc, false)

	-- Двускатная крыша и труба.
	gableRoof(m, at(0, top + 0.4, zc), W + 2, D + 2, 7, roofColor)
	part({ Parent = m, Name = "Chimney", Size = Vector3.new(2.2, 6, 2.2), CFrame = at(8, top + 5, zc - 5), Color = Color3.fromRGB(150, 80, 60), Material = Enum.Material.Brick })

	-- Крыльцо с навесом.
	part({ Parent = m, Name = "Porch", Size = Vector3.new(12, 1, 5), CFrame = at(0, 0.5, zf + 2.5), Color = wood, Material = Enum.Material.WoodPlanks })
	part({ Parent = m, Name = "Step", Size = Vector3.new(6, 0.5, 2), CFrame = at(0, 0.25, zf + 6), Color = wood, Material = Enum.Material.WoodPlanks })
	for _, lx in { -5.5, 5.5 } do
		part({ Parent = m, Name = "PorchPost", Size = Vector3.new(0.8, 8.5, 0.8), CFrame = at(lx, 5.25, zf + 4.5), Color = trim, Material = Enum.Material.Wood })
	end
	part({ Parent = m, ClassName = "WedgePart", Name = "PorchRoof", Size = Vector3.new(13, 1.6, 5.5), CFrame = at(0, 10.3, zf + 2.6) * CFrame.Angles(0, math.rad(180), 0), Color = roofColor, Material = Enum.Material.Slate })
	local lamp = part({ Parent = m, Name = "PorchLamp", Size = Vector3.new(0.8, 0.8, 0.8), CFrame = at(3.5, 8, zf + 0.3), Color = Color3.fromRGB(255, 235, 180), Material = Enum.Material.Neon, CanCollide = false })
	local l = Instance.new("PointLight")
	l.Range = 18
	l.Color = Color3.fromRGB(255, 220, 160)
	l.Parent = lamp

	-- Двор: клумбы, дерево, скамейка.
	for _, lx in { -14, 14 } do
		part({ Parent = m, Name = "Flowerbed", Size = Vector3.new(8, 0.8, 3), CFrame = at(lx, 0.5, 14), Color = Color3.fromRGB(95, 65, 45), Material = Enum.Material.Ground })
		for i = -1, 1 do
			local colors = { Color3.fromRGB(240, 80, 120), Color3.fromRGB(255, 220, 60), Color3.fromRGB(180, 90, 230) }
			part({ Parent = m, Shape = Enum.PartType.Ball, Name = "Flower", Size = Vector3.new(1.4, 1.4, 1.4), CFrame = at(lx + i * 2.5, 1.4, 14), Color = colors[i + 2], Material = Enum.Material.SmoothPlastic, CanCollide = false })
		end
	end
	tree(at(-17, 0, -19).Position)
	bench(at(15, 0, 18) * CFrame.Angles(0, math.rad(180), 0), 1)

	-- Интерьер.
	local door = part({ Parent = m, Name = "Door", Size = Vector3.new(5, 8, 0.5), CFrame = at(0, 5, zf - 0.5), Color = Color3.fromRGB(110, 70, 40), Material = Enum.Material.Wood })
	part({ Parent = m, Name = "Rug", Size = Vector3.new(10, 0.1, 7), CFrame = at(4, 1.2, zc + 1), Color = Color3.fromRGB(170, 60, 70), Material = Enum.Material.Fabric, CanCollide = false })
	local bed = interactable(m, "Bed", at(-9, 2.2, zb + 5.5), Vector3.new(6, 2, 9), Color3.fromRGB(240, 240, 255), "Кровать", Enum.Material.Fabric)
	part({ Parent = m, Name = "Pillow", Size = Vector3.new(5, 0.8, 2), CFrame = at(-9, 3.5, zb + 2), Color = Color3.new(1, 1, 1), Material = Enum.Material.Fabric })
	part({ Parent = m, Name = "Blanket", Size = Vector3.new(6.2, 0.3, 5), CFrame = at(-9, 3.3, zb + 7.5), Color = Color3.fromRGB(80, 120, 190), Material = Enum.Material.Fabric })
	local shower = interactable(m, "Shower", at(11.5, 5, zb + 3.5), Vector3.new(5, 8, 5), Color3.fromRGB(160, 210, 240), "Душ", Enum.Material.Glass)
	shower.Transparency = 0.4
	shower.CanCollide = false
	local tv = interactable(m, "TV", at(9, 5, zf - 1.3), Vector3.new(7, 4, 0.5), Color3.fromRGB(20, 20, 20), "Телевизор")
	part({ Parent = m, Name = "Sofa", Size = Vector3.new(8, 2, 3), CFrame = at(9, 2.1, zc + 0.5), Color = Color3.fromRGB(90, 60, 120), Material = Enum.Material.Fabric })
	part({ Parent = m, Name = "SofaBack", Size = Vector3.new(8, 2.5, 0.8), CFrame = at(9, 3.4, zc - 1.1), Color = Color3.fromRGB(90, 60, 120), Material = Enum.Material.Fabric })
	local fridge = interactable(m, "Fridge", at(-12.5, 5, zf - 3), Vector3.new(3.5, 8, 3.5), Color3.fromRGB(235, 235, 240), "Холодильник", Enum.Material.Metal)
	part({ Parent = m, Name = "Kitchen", Size = Vector3.new(3.5, 3.5, 7), CFrame = at(-12.5, 2.8, zf - 9), Color = Color3.fromRGB(210, 200, 185), Material = Enum.Material.Wood })
	part({ Parent = m, Shape = Enum.PartType.Cylinder, Name = "Table", Size = Vector3.new(3.4, 5, 5), CFrame = at(-4, 2.75, zf - 5) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(190, 150, 110), Material = Enum.Material.Wood })
	local light = part({ Parent = m, Name = "Lamp", Size = Vector3.new(3, 0.4, 3), CFrame = at(0, top - 0.3, zc), Color = Color3.fromRGB(255, 250, 220), Material = Enum.Material.Neon, CanCollide = false })
	local pl = Instance.new("PointLight")
	pl.Range = 24
	pl.Brightness = 1.2
	pl.Parent = light

	-- Табличка с владельцем у калитки.
	part({ Parent = m, Name = "SignPost", Size = Vector3.new(0.5, 4, 0.5), CFrame = at(7, 2, 25), Color = wood })
	local board = part({ Parent = m, Name = "SignBoard", Size = Vector3.new(8, 3, 0.4), CFrame = at(7, 5, 25), Color = Color3.fromRGB(250, 250, 240), CanCollide = false })
	local label = surfaceText(board, Enum.NormalId.Back, "", Color3.fromRGB(250, 250, 240), Color3.fromRGB(30, 30, 30))
	local delivery = part({ Parent = m, Name = "Doorstep", Size = Vector3.new(4, 0.3, 3), CFrame = at(0, 0.5, 27), Color = Color3.fromRGB(150, 120, 90) })

	local house = {
		Id = id,
		Model = m,
		Door = door,
		Bed = bed,
		Shower = shower,
		TV = tv,
		Fridge = fridge,
		SignLabel = label,
		SignBoard = board,
		Doorstep = delivery,
		Spawn = at(0, 4, zc + 2),
		Center = at(0, 0, 0).Position,
	}
	table.insert(World.Houses, house)
	return house
end

local function buildResidential()
	for id, a in Meta.Houses do
		buildHouse(id, a)
	end
end

---------------------------------------------------------------------------
-- Общественные здания
---------------------------------------------------------------------------
local function buildCityHall(a)
	local m, at = building({ Name = "CityHall", GPSName = "Администрация города", X = a.X, Z = a.Z, Yaw = a.Yaw, W = 90, D = 70, H = 24, Color = Color3.fromRGB(235, 225, 200), Material = Enum.Material.Marble, Sign = "АДМИНИСТРАЦИЯ г. ПЕРВОУРАЛЬСК", SignColor = Color3.fromRGB(120, 90, 40), Path = 40, DoorW = 14 })
	for _, lx in { -20, -10, 10, 20 } do
		part({ Parent = m, Name = "Column", Shape = Enum.PartType.Cylinder, Size = Vector3.new(22, 3, 3), CFrame = (at(lx, 11, 38)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.new(1, 1, 1), Material = Enum.Material.Marble })
	end
	part({ Parent = m, Name = "Portico", Size = Vector3.new(50, 1.5, 10), Position = at(0, 22.7, 38), Color = Color3.fromRGB(235, 225, 200), Material = Enum.Material.Marble })

	local jobs = interactable(m, "JobBoard", at(-20, 5, -25), Vector3.new(12, 8, 1), Color3.fromRGB(40, 90, 50), "Биржа труда")
	surfaceText(jobs, Enum.NormalId.Front, "БИРЖА ТРУДА", Color3.fromRGB(40, 90, 50))
	surfaceText(jobs, Enum.NormalId.Back, "БИРЖА ТРУДА", Color3.fromRGB(40, 90, 50))
	World.Desks.Jobs = jobs
	local roles = counter(m, at(20, 1.9, -20), Vector3.new(14, 3.5, 3))
	floatLabel(roles, "Смена профессии / роли", 4)
	World.Desks.Roles = roles
	staff(at, 20, -23, "clerk", "Инспектор отдела кадров", { "Хотите сменить профессию? Подойдите к стойке.", "Полиция и спецслужбы всегда ждут ответственных людей." })
	local realty = counter(m, at(0, 1.9, -25), Vector3.new(12, 3.5, 3), Color3.fromRGB(70, 110, 160))
	floatLabel(realty, "Агентство недвижимости", 4)
	World.Desks.Realty = realty
	staff(at, 0, -28, "clerk", "Риелтор", { "Коттеджи в центре — лучший выбор! Всего несколько тысяч.", "После свадьбы супруги живут в одном доме." })
	staff(at, -20, -22, "clerk", "Специалист биржи труда", { "Работы много: кассир, повар, офис, грузчик, курьер.", "Помните: после смены нужно отдохнуть." })

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CitySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = at(0, 0.5, 58)
	spawn.Color = Color3.fromRGB(200, 200, 200)
	spawn.Material = Enum.Material.Marble
	spawn.Duration = 3
	spawn.Parent = City
	World.Spawns.CityHall = (at(0, 4, 58))

	-- Фонтан перед мэрией.
	part({ Name = "FountainBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.5, 18, 18), CFrame = (at(-30, 0.75, 60)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(200, 200, 200), Material = Enum.Material.Marble })
	part({ Name = "FountainWater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 16, 16), CFrame = (at(-30, 1.5, 60)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(80, 160, 230), Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false })
end

local function buildPolice(a)
	local m, at = building({ Name = "Police", GPSName = "ОМВД (полиция)", X = a.X, Z = a.Z, Yaw = a.Yaw, W = 90, D = 70, H = 20, Color = Color3.fromRGB(60, 80, 140), Sign = "ОМВД ПОЛИЦИЯ", SignColor = Color3.fromRGB(30, 50, 140), Path = 40 })
	counter(m, at(0, 1.9, 10), Vector3.new(20, 3.5, 3), Color3.fromRGB(60, 60, 70))
	for i = 1, 3 do
		part({ Parent = m, Name = "Locker", Size = Vector3.new(4, 8, 2), Position = at(-40 + i * 5, 4, -32), Color = Color3.fromRGB(100, 110, 120), Material = Enum.Material.Metal })
	end
	World.Spawns.PoliceStation = (at(0, 4, -10))
	staff(at, 0, 7.5, "police", "Дежурный ОМВД", { "Добро пожаловать в ОМВД Первоуральска.", "Видели что-то подозрительное? Сообщите патрулю." })
	local pad = part({ Parent = m, Name = "CarPad", Size = Vector3.new(16, 0.3, 24), Position = at(-35, 0.2, 55), Color = Color3.fromRGB(40, 40, 120) })
	local kiosk = interactable(m, "CarKiosk", at(-24, 2.5, 55), Vector3.new(2, 5, 2), Color3.fromRGB(40, 40, 120), "Служебный транспорт")
	World.PoliceCarKiosk = kiosk
	World.PoliceCarSpawn = pad.CFrame + Vector3.new(0, 3, 0)
end

local function buildHospital(a)
	local m, at = building({ Name = "Hospital", GPSName = "Городская больница №1", X = a.X, Z = a.Z, Yaw = a.Yaw, W = 100, D = 80, H = 20, Color = Color3.fromRGB(245, 245, 250), Sign = "ГОРОДСКАЯ БОЛЬНИЦА №1", SignColor = Color3.fromRGB(200, 40, 50), Path = 40, DoorW = 14 })
	counter(m, at(0, 1.9, 20), Vector3.new(18, 3.5, 3), Color3.fromRGB(230, 230, 240))
	World.Spawns.Hospital = (at(0, 4, 28))
	staff(at, 0, 17.5, "doctor", "Медсестра", { "Плохо себя чувствуете? Койки у дальней стены.", "Не забывайте есть и высыпаться!" })
	World.JobPoints.Hospital = {}
	for i, lx in { -36, -20, 20, 36 } do
		local bed = interactable(m, "HospitalBed", at(lx, 1.4, -25), Vector3.new(6, 2, 10), Color3.fromRGB(220, 240, 255), "Больничная койка", Enum.Material.Fabric)
		table.insert(World.Beds, { Part = bed, Rate = 5, Heal = true, Name = "Больничная койка" })
		local station = part({ Parent = m, Name = "PatientSpot" .. i, Size = Vector3.new(3, 0.2, 3), Position = at(lx, 0.5, -16), Color = Color3.fromRGB(200, 60, 70), CanCollide = false })
		table.insert(World.JobPoints.Hospital, station)
	end
end

local function buildBank(a)
	local m, at = building({ Name = "Bank", GPSName = "Банк", X = a.X, Z = a.Z, Yaw = a.Yaw, W = 80, D = 70, H = 22, Color = Color3.fromRGB(170, 170, 160), Material = Enum.Material.Granite, Sign = "БАНК", SignColor = Color3.fromRGB(30, 100, 60), Path = 40 })
	for _, lx in { -25, -15, 15, 25 } do
		part({ Parent = m, Name = "Column", Shape = Enum.PartType.Cylinder, Size = Vector3.new(20, 2.5, 2.5), CFrame = (at(lx, 10, 38)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(230, 230, 220), Material = Enum.Material.Marble })
	end
	counter(m, at(0, 1.9, 5), Vector3.new(30, 3.5, 3), Color3.fromRGB(90, 70, 50))
	local teller = interactable(m, "Teller", at(0, 4.5, 5), Vector3.new(2, 1, 1), Color3.fromRGB(240, 220, 120), "Кассир банка")
	teller.CanCollide = false
	table.insert(World.ATMs, teller)
	staff(at, 0, 2.5, "clerk", "Операционист банка", { "Храните деньги на карте — так надёжнее.", "Банкоматы есть у входа." })
	worker(at(-8, 0.4, 30) * CFrame.Angles(0, math.rad(180), 0), "guard", "Охранник", { "Проходите, не задерживайтесь.", "Хранилище под надёжной охраной!" })
	for _, lx in { -30, 30 } do
		local atm = interactable(m, "ATM", at(lx, 3, 42), Vector3.new(3, 6, 2), Color3.fromRGB(40, 120, 70), "Банкомат", Enum.Material.Metal)
		table.insert(World.ATMs, atm)
	end
	-- Хранилище.
	part({ Parent = m, Name = "VaultWall", Size = Vector3.new(30, 18, 1), Position = at(0, 9, -15), Color = Color3.fromRGB(90, 90, 95), Material = Enum.Material.DiamondPlate })
	local vaultDoor = part({ Parent = m, Name = "VaultDoor", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.5, 10, 10), CFrame = (at(0, 6, -14.3)) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(150, 150, 160), Material = Enum.Material.Metal, CanCollide = false })
	local vault = interactable(m, "Vault", at(0, 2, -12), Vector3.new(4, 0.4, 2), Color3.fromRGB(150, 150, 160))
	vault.CanCollide = false
	World.Robbery.Bank = vault
	floatLabel(vaultDoor, "Хранилище", 6, Color3.fromRGB(255, 120, 120))
end

local function buildOffice(a)
	local m, at = building({ Name = "Office", GPSName = "Бизнес-центр", X = a.X, Z = a.Z, Yaw = a.Yaw, W = 80, D = 64, H = 44, Color = Color3.fromRGB(120, 150, 180), Material = Enum.Material.Glass, Sign = "БИЗНЕС-ЦЕНТР", SignColor = Color3.fromRGB(30, 60, 100), Path = 40 })
	World.JobPoints.Office = {}
	for row = 0, 1 do
		for col = -1, 1 do
			local desk = part({ Parent = m, Name = "Desk", Size = Vector3.new(8, 3, 4), Position = at(col * 20, 1.9, -15 + row * 14), Color = Color3.fromRGB(200, 190, 170), Material = Enum.Material.Wood })
			local pc = interactable(m, "Computer", desk.CFrame * CFrame.new(0, 2.5, 0), Vector3.new(3, 2, 0.4), Color3.fromRGB(20, 20, 30))
			pc.CanCollide = false
			table.insert(World.JobPoints.Office, pc)
		end
	end
	local cooler = interactable(m, "Cooler", at(34, 2.5, -26), Vector3.new(2, 5, 2), Color3.fromRGB(120, 200, 255), "Кулер")
	table.insert(World.FunSpots, { Part = cooler, Need = "Hunger", Amount = 4, Text = "Попить воды", Hold = 1, Cooldown = 20 })
end

local function buildSupermarket(a)
	local m, at = building({ Name = "Supermarket", GPSName = "Супермаркет", X = a.X, Z = a.Z, Yaw = a.Yaw, W = 100, D = 76, H = 18, Color = Color3.fromRGB(240, 160, 60), Sign = "СУПЕРМАРКЕТ", SignColor = Color3.fromRGB(200, 90, 20), Path = 40, DoorW = 16 })
	for row = -1, 1 do
		for _, lx in { -30, 0, 30 } do
			part({ Parent = m, Name = "Shelf", Size = Vector3.new(18, 7, 3), Position = at(lx, 3.7, -15 + row * 10), Color = Color3.fromRGB(220, 220, 225), Material = Enum.Material.Metal })
		end
	end
	World.JobPoints.Supermarket = {}
	for i, lx in { -30, -15, 15 } do
		counter(m, at(lx, 1.9, 22), Vector3.new(8, 3.5, 3), Color3.fromRGB(60, 60, 70))
		local reg = interactable(m, "Register" .. i, at(lx, 4.2, 22), Vector3.new(2, 1, 1.5), Color3.fromRGB(30, 30, 30))
		reg.CanCollide = false
		table.insert(World.JobPoints.Supermarket, reg)
	end
	local shop = interactable(m, "ShopCounter", at(32, 2, 26), Vector3.new(10, 4, 4), Color3.fromRGB(240, 160, 60), "Продукты")
	World.Shops.Supermarket = shop
	staff(at, 32, 22.5, "cashier", "Продавец", { "Свежий хлеб и салаты — у нас!", "Кофе бодрит лучше всего." })
	local safe = interactable(m, "Safe", at(40, 2, -32), Vector3.new(4, 4, 4), Color3.fromRGB(60, 60, 60), nil, Enum.Material.DiamondPlate)
	World.Robbery.Supermarket = safe
	local atm = interactable(m, "ATM", at(-44, 3, 42), Vector3.new(3, 6, 2), Color3.fromRGB(40, 120, 70), "Банкомат", Enum.Material.Metal)
	table.insert(World.ATMs, atm)

end

-- Цветочный магазин — на месте реального магазина цветов.
local function buildFlorist(a)
	local base = CFrame.new(a.X, 0, a.Z) * CFrame.Angles(0, math.rad(a.Yaw), 0)
	local kiosk = part({ Name = "FloristKiosk", Size = Vector3.new(14, 9, 10), CFrame = base * CFrame.new(0, 4.5, 0), Color = Color3.fromRGB(250, 170, 200), Material = Enum.Material.Wood })
	surfaceText(kiosk, Enum.NormalId.Back, "ЦВЕТЫ", Color3.fromRGB(220, 80, 140))
	surfaceText(kiosk, Enum.NormalId.Front, "ЦВЕТЫ", Color3.fromRGB(220, 80, 140))
	local fshop = interactable(nil, "FloristCounter", base * CFrame.new(0, 2, 6.5), Vector3.new(8, 4, 2), Color3.fromRGB(250, 220, 230), "Цветы, подарки, кольца")
	World.Shops.Florist = fshop
	worker(base * CFrame.new(5, 0.4, 8) * CFrame.Angles(0, math.rad(180), 0), "clerk", "Флорист", { "Цветы — лучший подарок!", "Обручальные кольца тоже у нас." })
	addGPS("Цветочный магазин", base * CFrame.new(0, 3, 12))
end

local function buildCafe(a)
	local m, at = building({ Name = "Cafe", GPSName = "Пельменная", X = a.X, Z = a.Z, Yaw = a.Yaw, W = 70, D = 60, H = 16, Color = Color3.fromRGB(170, 110, 80), Material = Enum.Material.Brick, Sign = "ПЕЛЬМЕННАЯ", SignColor = Color3.fromRGB(120, 60, 30), Path = 40 })
	counter(m, at(0, 1.9, 2), Vector3.new(30, 3.5, 3))
	local shop = interactable(m, "CafeCounter", at(-10, 4.5, 4), Vector3.new(3, 1, 1), Color3.fromRGB(255, 220, 150), "Меню")
	shop.CanCollide = false
	World.Shops.Cafe = shop
	staff(at, -10, -1, "cook", "Официант", { "Пельмени сегодня особенно удались!", "Присаживайтесь за любой столик." })
	local reg = interactable(m, "CafeRegister", at(10, 4.2, 2), Vector3.new(2, 1, 1.5), Color3.fromRGB(30, 30, 30))
	reg.CanCollide = false
	World.Robbery.Cafe = reg
	World.JobPoints.Cafe = { Pickup = {}, Drop = {} }
	for _, lx in { -20, 0, 20 } do
		local stove = interactable(m, "Stove", at(lx, 2, -24), Vector3.new(6, 4, 4), Color3.fromRGB(80, 80, 85), nil, Enum.Material.Metal)
		table.insert(World.JobPoints.Cafe.Pickup, stove)
	end
	for _, pos in { { -22, 16 }, { 22, 16 }, { -22, 24 }, { 22, 24 } } do
		local tbl = part({ Parent = m, Name = "Table", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.4, 6, 6), CFrame = (at(pos[1], 1.7, pos[2])) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(230, 220, 200), Material = Enum.Material.Wood })
		table.insert(World.JobPoints.Cafe.Drop, tbl)
		part({ Parent = m, Name = "Stool", Size = Vector3.new(2.5, 2, 2.5), Position = at(pos[1] + 5, 1.2, pos[2]), Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.Wood })
	end
	local juke = interactable(m, "Jukebox", at(-32, 3, -10), Vector3.new(3, 6, 3), Color3.fromRGB(200, 60, 160), "Музыкальный автомат", Enum.Material.Neon)
	table.insert(World.FunSpots, { Part = juke, Need = "Fun", Amount = 15, Text = "Включить музыку", Hold = 1, Cooldown = 15 })
end

local function buildDealership(a)
	local m, at = building({ Name = "Dealership", GPSName = "Автосалон", X = a.X, Z = a.Z, Yaw = a.Yaw, W = 90, D = 60, H = 16, Color = Color3.fromRGB(200, 210, 220), Material = Enum.Material.Glass, Sign = "АВТОСАЛОН", SignColor = Color3.fromRGB(180, 30, 30), Path = 40, DoorW = 20 })
	local desk = interactable(m, "SalesDesk", at(0, 2, -20), Vector3.new(12, 4, 3), Color3.fromRGB(180, 30, 30), "Купить машину")
	World.Dealership = desk
	staff(at, 0, -23, "clerk", "Менеджер автосалона", { "Спорткар — мечта каждого!", "Купленную машину можно вызвать через телефон." })
	-- Витринные машины (декорация).
	for i, lx in { -28, 28 } do
		local c = i == 1 and Color3.fromRGB(220, 30, 30) or Color3.fromRGB(60, 90, 60)
		part({ Parent = m, Name = "ShowCar", Size = Vector3.new(7, 2.5, 13), Position = at(lx, 2, 0), Color = c, Material = Enum.Material.SmoothPlastic })
		part({ Parent = m, Name = "ShowCarTop", Size = Vector3.new(6, 2, 6), Position = at(lx, 4.2, -1), Color = Color3.fromRGB(120, 170, 220), Material = Enum.Material.Glass, Transparency = 0.3 })
	end
end

local function buildFactory(a)
	local m, at = building({ Name = "Factory", GPSName = "Трубный завод и склад", X = a.X, Z = a.Z, Yaw = a.Yaw, W = 110, D = 90, H = 26, Color = Color3.fromRGB(150, 120, 90), Material = Enum.Material.CorrodedMetal, Sign = "ТРУБНЫЙ ЗАВОД", SignColor = Color3.fromRGB(90, 70, 40), Path = 40, DoorW = 20 })
	World.JobPoints.Factory = { Pickup = {}, Drop = {} }
	part({ Parent = m, Name = "Conveyor", Size = Vector3.new(60, 3, 5), Position = at(0, 1.7, -32), Color = Color3.fromRGB(40, 40, 40), Material = Enum.Material.DiamondPlate })
	for _, lx in { -20, 0, 20 } do
		local crate = interactable(m, "CrateStack", at(lx, 4.7, -32), Vector3.new(4, 3, 4), Color3.fromRGB(170, 130, 80), nil, Enum.Material.WoodPlanks)
		table.insert(World.JobPoints.Factory.Pickup, crate)
	end
	-- Грузовик.
	part({ Parent = m, Name = "TruckBed", Size = Vector3.new(12, 6, 20), Position = at(-30, 4, 20), Color = Color3.fromRGB(200, 200, 200), Material = Enum.Material.Metal })
	part({ Parent = m, Name = "TruckCab", Size = Vector3.new(12, 8, 7), Position = at(-30, 5, 34), Color = Color3.fromRGB(30, 80, 160) })
	for _, lz in { 14, 26 } do
		local spot = interactable(m, "TruckLoad", at(-22.5, 3, lz), Vector3.new(2, 4, 4), Color3.fromRGB(255, 200, 0))
		spot.Transparency = 0.5
		spot.CanCollide = false
		table.insert(World.JobPoints.Factory.Drop, spot)
	end
	local depot = interactable(m, "CourierDepot", at(30, 2, 20), Vector3.new(10, 4, 4), Color3.fromRGB(240, 200, 60), "Склад посылок")
	World.JobPoints.CourierDepot = depot
	worker(at(-30, 0.4, -26), "worker", "Мастер цеха", { "Грузчики и курьеры всегда нужны заводу.", "Каска — обязательна!" })

	-- Убежище преступников за заводом.
	local shack = part({ Name = "Hideout", Size = Vector3.new(20, 10, 16), Position = at(0, 5, -70), Color = Color3.fromRGB(70, 60, 55), Material = Enum.Material.CorrodedMetal })
	shack.CanCollide = true
	World.Spawns.Hideout = (at(0, 4, -56))
	addGPS("Переулок за заводом", at(0, 3, -56))
	part({ Name = "Graffiti", Size = Vector3.new(14, 6, 0.2), CFrame = shack.CFrame * CFrame.new(0, 0, shack.Size.Z / 2 + 0.11), Color = Color3.fromRGB(150, 60, 160), CanCollide = false, Material = Enum.Material.Neon, Transparency = 0.5 })
end

-- ЗАГС (Дворец бракосочетаний) — здесь регистрируют браки, как в реальном Первоуральске.
local function buildWedding(a)
	local m, at = building({ Name = "ZAGS", GPSName = "ЗАГС (свадьбы)", X = a.X, Z = a.Z, Yaw = a.Yaw, W = 50, D = 80, H = 22, Color = Color3.fromRGB(250, 245, 235), Material = Enum.Material.Marble, RoofColor = Color3.fromRGB(190, 160, 110), Path = 40, Sign = "ЗАГС", SignColor = Color3.fromRGB(170, 120, 60) })
	for _, lx in { -15, 15 } do
		part({ Parent = m, Name = "Column", Shape = Enum.PartType.Cylinder, Size = Vector3.new(20, 2.5, 2.5), CFrame = at(lx, 10, 44) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.new(1, 1, 1), Material = Enum.Material.Marble })
	end
	part({ Parent = m, Name = "Rings", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 8, 8), CFrame = at(-3, 26, 38) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(240, 200, 80), Material = Enum.Material.Neon })
	part({ Parent = m, Name = "Rings", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 8, 8), CFrame = at(3, 26, 38) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(240, 200, 80), Material = Enum.Material.Neon })
	for row = 0, 4 do
		for _, lx in { -12, 12 } do
			bench(at(lx, 0, 20 - row * 9), -1)
		end
	end
	part({ Parent = m, Name = "Carpet", Size = Vector3.new(6, 0.1, 70), Position = at(0, 0.45, 0), Color = Color3.fromRGB(180, 30, 40), Material = Enum.Material.Fabric, CanCollide = false })
	local altar = interactable(m, "Altar", at(0, 2, -32), Vector3.new(10, 4, 4), Color3.fromRGB(240, 220, 160), "Регистрация брака", Enum.Material.Marble)
	World.Church = { Altar = altar, Center = at(0, 0, 0).Position, Radius = 45 }
	staff(at, 0, -35.5, "clerk", "Регистратор ЗАГСа", { "Для росписи нужно прийти вдвоём и быть помолвленными.", "Поздравляем будущих молодожёнов!" })
	-- Арка из цветов.
	for _, lx in { -6, 6 } do
		part({ Parent = m, Name = "Arch", Size = Vector3.new(1, 12, 1), Position = at(lx, 6, -27), Color = Color3.fromRGB(255, 180, 210), Material = Enum.Material.Fabric })
	end
	part({ Parent = m, Name = "ArchTop", Size = Vector3.new(13, 1, 1), Position = at(0, 12.5, -27), Color = Color3.fromRGB(255, 180, 210), Material = Enum.Material.Fabric })
end

-- Игровая зона в реальном Парке культуры и отдыха.
local function buildPark(a)
	local cx, cz = a.X, a.Z
	part({ Name = "ParkPathA", Size = Vector3.new(10, 0.3, 160), Position = Vector3.new(cx, 0.2, cz), Color = Color3.fromRGB(200, 180, 140), Material = Enum.Material.Sand })
	part({ Name = "ParkPathB", Size = Vector3.new(160, 0.3, 10), Position = Vector3.new(cx, 0.2, cz), Color = Color3.fromRGB(200, 180, 140), Material = Enum.Material.Sand })
	local fountain = part({ Name = "Fountain", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 22, 22), CFrame = CFrame.new(cx, 1.5, cz) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Marble })
	part({ Name = "FountainWater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 20, 20), CFrame = CFrame.new(cx, 3, cz) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(80, 160, 230), Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false })
	floatLabel(fountain, "Фонтан желаний", 6)
	table.insert(World.FunSpots, { Part = fountain, Need = "Fun", Amount = 10, Text = "Бросить монетку (5$)", Cost = 5, Hold = 1, Cooldown = 10 })

	for _, p in { { -40, -20 }, { 40, -20 }, { -40, 20 }, { 40, 20 }, { -20, -50 }, { 20, 50 } } do
		local seat = bench(Vector3.new(cx + p[1], 0, cz + p[2]), p[2] > 0 and -1 or 1)
		floatLabel(seat, "Скамейка", 2.5)
		table.insert(World.FunSpots, { Part = seat, Need = "Fun", Amount = 6, Text = "Отдохнуть", Hold = 0.5, Cooldown = 8, Extra = { Energy = 3 } })
	end
	-- Качели.
	part({ Name = "SwingFrame", Size = Vector3.new(14, 1, 1), Position = Vector3.new(cx + 50, 10, cz - 50), Color = Color3.fromRGB(200, 60, 60), Material = Enum.Material.Metal })
	for _, dx in { -7, 7 } do
		part({ Name = "SwingLeg", Size = Vector3.new(1, 10, 1), Position = Vector3.new(cx + 50 + dx, 5, cz - 50), Color = Color3.fromRGB(200, 60, 60), Material = Enum.Material.Metal })
	end
	local swing = interactable(nil, "Swing", Vector3.new(cx + 50, 2.5, cz - 50), Vector3.new(4, 0.5, 2), Color3.fromRGB(240, 200, 60), "Качели", Enum.Material.Wood)
	table.insert(World.FunSpots, { Part = swing, Need = "Fun", Amount = 18, Text = "Покачаться", Hold = 2, Cooldown = 12 })
	-- Уличный душ.
	local shower = interactable(nil, "ParkShower", Vector3.new(cx - 60, 4, cz - 60), Vector3.new(6, 8, 6), Color3.fromRGB(160, 210, 240), "Общественный душ", Enum.Material.Glass)
	shower.Transparency = 0.4
	shower.CanCollide = false
	table.insert(World.Showers, { Part = shower, Rate = 6, Name = "Общественный душ" })

	for _ = 1, 22 do
		local x = cx + math.random(-75, 75)
		local z = cz + math.random(-75, 75)
		-- Не сажаем деревья на дорожки, центр и тир (cx + 45, cz + 58).
		local nearTir = math.abs(x - cx - 45) < 16 and math.abs(z - cz - 58) < 16
		if math.abs(x - cx) > 15 and math.abs(z - cz) > 15 and (Vector2.new(x - cx, z - cz)).Magnitude > 20 and not nearTir then
			tree(Vector3.new(x, 0, z))
		end
	end
	addGPS("Парк культуры и отдыха", Vector3.new(cx, 3, cz - 75))
end

local function buildJail(a)
	local m, at = building({ Name = "Jail", GPSName = "Тюрьма", X = a.X, Z = a.Z, Yaw = a.Yaw, W = 80, D = 70, H = 18, Color = Color3.fromRGB(90, 90, 95), Material = Enum.Material.Concrete, Sign = "ТЮРЬМА", SignColor = Color3.fromRGB(40, 40, 40), Path = 40 })
	local cells = {}
	for i, lx in { -27, -9, 9, 27 } do
		-- Перегородки между камерами.
		part({ Parent = m, Name = "CellWall", Size = Vector3.new(1, 18, 22), Position = at(lx - 9, 9, -24), Color = Color3.fromRGB(90, 90, 95), Material = Enum.Material.Concrete })
		for bx = -7, 7, 2 do
			part({ Parent = m, Name = "Bar", Size = Vector3.new(0.4, 18, 0.4), Position = at(lx + bx, 9, -13), Color = Color3.fromRGB(50, 50, 55), Material = Enum.Material.Metal })
		end
		part({ Parent = m, Name = "BarTop", Size = Vector3.new(18, 1, 0.6), Position = at(lx, 17.5, -13), Color = Color3.fromRGB(50, 50, 55), Material = Enum.Material.Metal })
		local bunk = part({ Parent = m, Name = "Bunk", Size = Vector3.new(5, 1.5, 8), Position = at(lx + 4, 1.2, -29), Color = Color3.fromRGB(120, 110, 100), Material = Enum.Material.Fabric })
		table.insert(World.Beds, { Part = bunk, Rate = 2, Name = "Тюремная койка" })
		cells[i] = (at(lx, 4, -24))
	end
	part({ Parent = m, Name = "CellWall", Size = Vector3.new(1, 18, 22), Position = at(36, 9, -24), Color = Color3.fromRGB(90, 90, 95), Material = Enum.Material.Concrete })
	World.Jail = { Cells = cells, Exit = (at(0, 4, 48)), Center = at(0, 0, -24).Position, Radius = 30 }
	-- Забор с колючкой.
	for _, lx in { -46, 46 } do
		part({ Name = "Fence", Size = Vector3.new(1, 10, 90), Position = at(lx, 5, 0), Color = Color3.fromRGB(120, 120, 125), Material = Enum.Material.Metal, Transparency = 0.2 })
	end
end

local function buildPatrolPosts()
	World.JobPoints.Patrol = {}
	for _, p in Meta.PatrolPosts do
		local post = interactable(nil, "PatrolPost", Vector3.new(p.X, 3, p.Z), Vector3.new(3, 6, 3), Color3.fromRGB(40, 60, 160), nil, Enum.Material.Metal)
		table.insert(World.JobPoints.Patrol, post)
	end
end

local function buildNature()
	for _, r in records("Trees") do
		tree(Vector3.new(tonumber(r[1]), 0, tonumber(r[2])))
		maybeYield()
	end
	for _, r in records("Lamps") do
		streetLamp(Vector3.new(tonumber(r[1]), 0, tonumber(r[2])))
	end
	for _, r in records("CarSpawns") do
		table.insert(World.CarSpawns, CFrame.new(tonumber(r[1]), 3, tonumber(r[2])) * CFrame.Angles(0, math.rad(tonumber(r[3])), 0))
	end
	for _, l in Meta.Landmarks do
		addGPS(l.Name, Vector3.new(l.X, 3, l.Z))
	end
end

---------------------------------------------------------------------------
-- Секции, учёба, досуг и детали дворов
---------------------------------------------------------------------------
local TrafficCar = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrafficCar"))

local function activity(part, key, text, hold)
	table.insert(World.Activities, { Part = part, Activity = key, Text = text, Hold = hold or 0.3 })
end

local WHITE_LINE = Color3.fromRGB(245, 245, 245)

-- Центральный стадион: поле с разметкой и воротами, беговая дорожка,
-- трибуны, прожекторы, табло, мяч.
local function buildStadium(a)
	local m = Instance.new("Model")
	m.Name = "Stadium"
	m.Parent = City
	local base = CFrame.new(a.X, 0, a.Z) * CFrame.Angles(0, math.rad(a.Yaw), 0)
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	local FW, FD = 120, 76 -- поле
	-- Газон полосами.
	for i = 0, 9 do
		part({ Parent = m, Name = "Pitch", Size = Vector3.new(12, 0.3, FD), CFrame = at(-FW / 2 + 6 + i * 12, 0.15, 0), Color = i % 2 == 0 and Color3.fromRGB(70, 150, 60) or Color3.fromRGB(85, 165, 70), Material = Enum.Material.Grass })
	end
	local function line(x, z, sx, sz)
		part({ Parent = m, Name = "Line", Size = Vector3.new(sx, 0.05, sz), CFrame = at(x, 0.33, z), Color = WHITE_LINE, CanCollide = false })
	end
	line(0, -FD / 2, FW, 0.6)
	line(0, FD / 2, FW, 0.6)
	line(-FW / 2, 0, 0.6, FD)
	line(FW / 2, 0, 0.6, FD)
	line(0, 0, 0.6, FD)
	for _, sgn in { -1, 1 } do
		line(sgn * (FW / 2 - 14), 0, 0.6, 34)
		line(sgn * (FW / 2 - 7), -17, 14, 0.6)
		line(sgn * (FW / 2 - 7), 17, 14, 0.6)
	end
	part({ Parent = m, Name = "CenterCircle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.04, 20, 20), CFrame = at(0, 0.32, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = WHITE_LINE, CanCollide = false })
	part({ Parent = m, Name = "CenterInner", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, 18.8, 18.8), CFrame = at(0, 0.33, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(85, 165, 70), Material = Enum.Material.Grass, CanCollide = false })
	-- Ворота.
	local goals = {}
	for _, sgn in { -1, 1 } do
		local gx = sgn * (FW / 2 + 2)
		for _, gz in { -9, 9 } do
			part({ Parent = m, Name = "GoalPost", Size = Vector3.new(0.6, 8, 0.6), CFrame = at(gx, 4, gz), Color = WHITE_LINE, Material = Enum.Material.Metal })
		end
		part({ Parent = m, Name = "Crossbar", Size = Vector3.new(0.6, 0.6, 18.6), CFrame = at(gx, 8, 0), Color = WHITE_LINE, Material = Enum.Material.Metal })
		part({ Parent = m, Name = "Net", Size = Vector3.new(0.2, 8, 18), CFrame = at(gx + sgn * 4, 4, 0), Color = Color3.fromRGB(230, 230, 230), Transparency = 0.6, Material = Enum.Material.Fabric })
		for _, gz in { -9, 9 } do
			part({ Parent = m, Name = "NetSide", Size = Vector3.new(4, 8, 0.2), CFrame = at(gx + sgn * 2, 4, gz), Color = Color3.fromRGB(230, 230, 230), Transparency = 0.6, Material = Enum.Material.Fabric })
		end
		part({ Parent = m, Name = "NetTop", Size = Vector3.new(4, 0.2, 18), CFrame = at(gx + sgn * 2, 8, 0), Color = Color3.fromRGB(230, 230, 230), Transparency = 0.6, Material = Enum.Material.Fabric })
		table.insert(goals, { Side = sgn, Center = at(gx + sgn * 2, 4, 0).Position })
	end
	-- Беговая дорожка вокруг поля (4 прямых участка и закругления).
	local TW = 10
	local ix, iz = FW / 2 + 10, FD / 2 + 8
	local track = Color3.fromRGB(175, 70, 50)
	part({ Parent = m, Name = "Track", Size = Vector3.new(2 * ix, 0.25, TW), CFrame = at(0, 0.13, -iz - TW / 2), Color = track, Material = Enum.Material.Slate })
	part({ Parent = m, Name = "Track", Size = Vector3.new(2 * ix, 0.25, TW), CFrame = at(0, 0.13, iz + TW / 2), Color = track, Material = Enum.Material.Slate })
	part({ Parent = m, Name = "Track", Size = Vector3.new(TW, 0.25, 2 * iz + 2 * TW), CFrame = at(-ix - TW / 2, 0.13, 0), Color = track, Material = Enum.Material.Slate })
	part({ Parent = m, Name = "Track", Size = Vector3.new(TW, 0.25, 2 * iz + 2 * TW), CFrame = at(ix + TW / 2, 0.13, 0), Color = track, Material = Enum.Material.Slate })
	for lane = 1, 3 do
		local off = lane * TW / 4
		line(0, -iz - off, 2 * ix, 0.25)
		line(0, iz + off, 2 * ix, 0.25)
	end
	line(-ix + 6, iz + TW / 2, 0.8, TW) -- старт/финиш
	World.TrackPoints = {}
	local r = TW / 2
	for _, p in { { -ix + 6, iz + r }, { ix + r, iz + r }, { ix + r, 0 }, { ix + r, -iz - r }, { 0, -iz - r }, { -ix - r, -iz - r }, { -ix - r, 0 }, { -ix - r, iz + r }, { -ix + 6, iz + r } } do
		table.insert(World.TrackPoints, at(p[1], 3, p[2]).Position)
	end
	local start = interactable(m, "RunStart", at(-ix + 2, 2.5, iz + TW + 3), Vector3.new(2, 5, 2), Color3.fromRGB(240, 200, 40), "Старт забега", Enum.Material.Metal)
	activity(start, "run", "Начать забег")
	-- Трибуны вдоль длинных сторон.
	for _, sgn in { -1, 1 } do
		for step = 0, 4 do
			local z = sgn * (iz + TW + 6 + step * 3)
			part({ Parent = m, Name = "Stand", Size = Vector3.new(110, 1.5 + step * 1.5, 3), CFrame = at(0, (1.5 + step * 1.5) / 2, z), Color = Color3.fromRGB(170, 170, 175), Material = Enum.Material.Concrete })
			for sx = -50, 50, 4 do
				part({ Parent = m, Name = "Seat", Size = Vector3.new(2.6, 0.6, 1.6), CFrame = at(sx, 1.5 + step * 1.5 + 0.3, z), Color = (step % 2 == 0) and Color3.fromRGB(40, 90, 180) or Color3.fromRGB(240, 240, 240), CanCollide = false })
			end
		end
	end
	part({ Parent = m, Name = "StandRoof", Size = Vector3.new(112, 0.8, 18), CFrame = at(0, 16, -(iz + TW + 12)), Color = Color3.fromRGB(60, 120, 180), Material = Enum.Material.Metal })
	for sx = -50, 50, 25 do
		part({ Parent = m, Name = "RoofPost", Size = Vector3.new(0.8, 16, 0.8), CFrame = at(sx, 8, -(iz + TW + 20)), Color = Color3.fromRGB(80, 80, 85), Material = Enum.Material.Metal })
	end
	-- Прожекторы по углам.
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local x, z = c[1] * (ix + TW + 8), c[2] * (iz + TW + 22)
		part({ Parent = m, Name = "LightTower", Size = Vector3.new(1.4, 40, 1.4), CFrame = at(x, 20, z), Color = Color3.fromRGB(90, 90, 95), Material = Enum.Material.Metal })
		local lamp = part({ Parent = m, Name = "Floodlight", Size = Vector3.new(6, 3, 1), CFrame = CFrame.lookAt(at(x, 40, z).Position, at(0, 0, 0).Position), Color = Color3.fromRGB(255, 250, 230), Material = Enum.Material.Neon })
		local spot = Instance.new("SpotLight")
		spot.Range = 60
		spot.Angle = 70
		spot.Brightness = 2
		spot.Face = Enum.NormalId.Front
		spot.Parent = lamp
	end
	-- Табло со счётом и рекордом забега.
	local board = part({ Parent = m, Name = "Scoreboard", Size = Vector3.new(30, 10, 1), CFrame = at(-(ix + TW + 12), 12, 0) * CFrame.Angles(0, math.rad(-90), 0), Color = Color3.fromRGB(20, 20, 25) })
	part({ Parent = m, Name = "BoardLeg", Size = Vector3.new(1, 8, 1), CFrame = at(-(ix + TW + 12), 4, -8), Color = Color3.fromRGB(80, 80, 85) })
	part({ Parent = m, Name = "BoardLeg", Size = Vector3.new(1, 8, 1), CFrame = at(-(ix + TW + 12), 4, 8), Color = Color3.fromRGB(80, 80, 85) })
	local scoreLabel = surfaceText(board, Enum.NormalId.Front, "КРАСНЫЕ 0 : 0 СИНИЕ", Color3.fromRGB(20, 20, 25), Color3.fromRGB(255, 220, 80))
	local recordBoard = part({ Parent = m, Name = "RecordBoard", Size = Vector3.new(14, 5, 0.5), CFrame = at(-ix + 2, 5, iz + TW + 6), Color = Color3.fromRGB(20, 20, 25), CanCollide = false })
	local recordLabel = surfaceText(recordBoard, Enum.NormalId.Back, "Рекорд забега: —", Color3.fromRGB(20, 20, 25), Color3.fromRGB(120, 255, 140))
	-- Мяч.
	local ball = Instance.new("Part")
	ball.Name = "Football"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(3, 3, 3)
	ball.Color = Color3.fromRGB(250, 250, 250)
	ball.Material = Enum.Material.SmoothPlastic
	ball.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.4, 0.6, 1, 1)
	ball.CFrame = at(0, 3, 0)
	ball.Parent = m
	World.Football = { Ball = ball, Center = at(0, 3, 0), Base = base, HalfW = FW / 2, GoalHalf = 9, Goals = goals, ScoreLabel = scoreLabel }
	World.RunBoard = recordLabel
	worker(at(-ix + 6, 0.4, iz + TW + 8), "coach", "Тренер по лёгкой атлетике", { "Беги круг на время — рекорд попадёт на табло!", "Выносливость даёт скорость и бережёт силы." })
	addGPS("Центральный стадион", at(0, 3, iz + TW + 10))
end

local function buildSports(a)
	local m, at = building({ Name = "SportsComplex", GPSName = "Спорткомплекс «КОСМОС»", X = a.X, Z = a.Z, Yaw = a.Yaw, W = 80, D = 60, H = 18, Color = Color3.fromRGB(70, 110, 170), Material = Enum.Material.Concrete, Sign = "СПОРТКОМПЛЕКС «КОСМОС»", SignColor = Color3.fromRGB(30, 60, 120), Path = 40, DoorW = 12 })
	part({ Parent = m, Name = "Mats", Size = Vector3.new(34, 0.1, 40), CFrame = at(-18, 0.45, -4), Color = Color3.fromRGB(50, 80, 150), Material = Enum.Material.Fabric, CanCollide = false })
	part({ Parent = m, Name = "Mirror", Size = Vector3.new(34, 10, 0.2), CFrame = at(-18, 6, -28.8), Color = Color3.fromRGB(200, 220, 235), Material = Enum.Material.Glass, Reflectance = 0.4, CanCollide = false })
	-- Тренажёры.
	for i, lx in { -30, -18, -6 } do
		local benchPart = interactable(m, "GymMachine" .. i, at(lx, 1.6, -16), Vector3.new(3, 1.2, 7), Color3.fromRGB(40, 40, 45), "Тренажёр", Enum.Material.Leather)
		for _, sx in { -3.5, 3.5 } do
			part({ Parent = m, Name = "Rack", Size = Vector3.new(0.5, 6, 0.5), CFrame = at(lx + sx, 3.4, -19), Color = Color3.fromRGB(120, 120, 130), Material = Enum.Material.Metal })
		end
		part({ Parent = m, Name = "Bar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(9, 0.4, 0.4), CFrame = at(lx, 5.2, -19), Color = Color3.fromRGB(180, 180, 190), Material = Enum.Material.Metal })
		for _, sx in { -4, 4 } do
			part({ Parent = m, Name = "Weight", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 2.4, 2.4), CFrame = at(lx + sx, 5.2, -19), Color = Color3.fromRGB(30, 30, 30), Material = Enum.Material.Metal })
		end
		activity(benchPart, "gym", "Тренироваться (15$)")
	end
	for i, lx in { -30, -18 } do
		local tm = part({ Parent = m, Name = "Treadmill", Size = Vector3.new(3, 1, 7), CFrame = at(lx, 0.9, 8), Color = Color3.fromRGB(50, 50, 55), Material = Enum.Material.Metal })
		part({ Parent = m, Name = "TreadmillPanel", Size = Vector3.new(3, 4, 0.4), CFrame = at(lx, 3, 4.5), Color = Color3.fromRGB(30, 30, 35) })
		activity(tm, "gym", "Пробежка (15$)")
	end
	-- Боксёрский ринг и груши.
	part({ Parent = m, Name = "Ring", Size = Vector3.new(22, 1.6, 22), CFrame = at(20, 1.2, -10), Color = Color3.fromRGB(220, 220, 225), Material = Enum.Material.Fabric })
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		part({ Parent = m, Name = "RingPost", Size = Vector3.new(0.8, 5, 0.8), CFrame = at(20 + c[1] * 10.6, 4.4, -10 + c[2] * 10.6), Color = Color3.fromRGB(200, 40, 40), Material = Enum.Material.Metal })
	end
	for h = 3.4, 5.4, 1 do
		for _, side in { -1, 1 } do
			part({ Parent = m, Name = "Rope", Size = Vector3.new(21.2, 0.2, 0.2), CFrame = at(20, h, -10 + side * 10.6), Color = Color3.fromRGB(240, 240, 240), CanCollide = false })
			part({ Parent = m, Name = "Rope", Size = Vector3.new(0.2, 0.2, 21.2), CFrame = at(20 + side * 10.6, h, -10), Color = Color3.fromRGB(240, 240, 240), CanCollide = false })
		end
	end
	for i, lx in { 12, 24 } do
		local bag = part({ Parent = m, Name = "PunchingBag" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 2.4, 2.4), CFrame = at(lx, 5, 12) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(170, 30, 30), Material = Enum.Material.Leather })
		part({ Parent = m, Name = "Chain", Size = Vector3.new(0.2, 9, 0.2), CFrame = at(lx, 12, 12), Color = Color3.fromRGB(120, 120, 125), Material = Enum.Material.Metal })
		activity(bag, "boxing", "Бокс (20$)")
	end
	local shop = interactable(m, "SportsShop", at(30, 2, 24), Vector3.new(10, 4, 3), Color3.fromRGB(70, 110, 170), "Спорттовары")
	World.Shops.Sports = shop
	staff(at, 30, 21.5, "coach", "Тренер", { "Тренажёры качают силу, груши — бокс.", "Для спецслужб нужны сила и выносливость 2 уровня!" })
end

local function buildSchool(a)
	local m, at = building({ Name = "School", GPSName = "Лицей №21 и колледж", X = a.X, Z = a.Z, Yaw = a.Yaw, W = 100, D = 70, H = 22, Color = Color3.fromRGB(230, 205, 160), Material = Enum.Material.Brick, Sign = "ЛИЦЕЙ №21", SignColor = Color3.fromRGB(150, 50, 40), Path = 44, DoorW = 12 })
	-- Перегородка: слева — лицей, справа — колледж.
	part({ Parent = m, Name = "Partition", Size = Vector3.new(1, 22, 40), CFrame = at(0, 11, -15), Color = Color3.fromRGB(230, 205, 160), Material = Enum.Material.Plaster })
	local function classroom(cx, title, key, actionText, teacherName, lines)
		local board = part({ Parent = m, Name = "Chalkboard", Size = Vector3.new(24, 7, 0.4), CFrame = at(cx, 7, -34.2), Color = Color3.fromRGB(30, 70, 50) })
		surfaceText(board, Enum.NormalId.Back, title, Color3.fromRGB(30, 70, 50), Color3.fromRGB(240, 240, 230))
		part({ Parent = m, Name = "TeacherDesk", Size = Vector3.new(8, 3, 3.5), CFrame = at(cx, 1.9, -27), Color = Color3.fromRGB(130, 90, 55), Material = Enum.Material.Wood })
		local first
		for row = 0, 3 do
			for col = -1, 1 do
				local d = part({ Parent = m, Name = "Desk", Size = Vector3.new(5, 2.8, 2.5), CFrame = at(cx + col * 8, 1.8, -18 + row * 7), Color = Color3.fromRGB(200, 170, 120), Material = Enum.Material.Wood })
				part({ Parent = m, Name = "Chair", Size = Vector3.new(2.4, 1.8, 2.2), CFrame = at(cx + col * 8, 1.3, -15.5 + row * 7), Color = Color3.fromRGB(60, 90, 150), Material = Enum.Material.SmoothPlastic })
				first = first or d
				if row == 3 then
					activity(d, key, actionText)
				end
			end
		end
		staff(at, cx, -30, "teacher", teacherName, lines)
	end
	classroom(-25, "ЛИЦЕЙ: УРОК", "lesson", "Пойти на урок", "Учитель", { "5 уроков — и аттестат ваш!", "С аттестатом берут на работу в офис." })
	classroom(25, "КОЛЛЕДЖ: ЛЕКЦИЯ", "college", "Лекция (100$)", "Преподаватель колледжа", { "Диплом колледжа даёт +15% к любой зарплате.", "Сначала получите аттестат в лицее." })
	-- Школьный двор: флагшток, баскетбольные кольца, забор.
	part({ Parent = m, Name = "Flagpole", Size = Vector3.new(0.5, 24, 0.5), CFrame = at(-30, 12, 50), Color = Color3.fromRGB(200, 200, 205), Material = Enum.Material.Metal })
	for i, c in { Color3.fromRGB(255, 255, 255), Color3.fromRGB(30, 60, 170), Color3.fromRGB(210, 30, 40) } do
		part({ Parent = m, Name = "Flag", Size = Vector3.new(6, 1.3, 0.1), CFrame = at(-26.8, 23.2 - i * 1.3, 50), Color = c, Material = Enum.Material.Fabric, CanCollide = false })
	end
	for _, lx in { 18, 42 } do
		part({ Parent = m, Name = "HoopPole", Size = Vector3.new(0.6, 12, 0.6), CFrame = at(lx, 6, 56), Color = Color3.fromRGB(90, 90, 95), Material = Enum.Material.Metal })
		part({ Parent = m, Name = "Backboard", Size = Vector3.new(6, 4, 0.3), CFrame = at(lx, 12, 55.5), Color = Color3.new(1, 1, 1) })
		part({ Parent = m, Name = "Hoop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 2.2, 2.2), CFrame = at(lx, 10.5, 54) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(240, 100, 30), Material = Enum.Material.Metal, CanCollide = false })
	end
	part({ Parent = m, Name = "Court", Size = Vector3.new(36, 0.2, 18), CFrame = at(30, 0.1, 52), Color = Color3.fromRGB(190, 110, 70), Material = Enum.Material.Concrete })
end

local function buildCulture(a)
	local m, at = building({ Name = "Culture", GPSName = "Дом культуры и библиотека", X = a.X, Z = a.Z, Yaw = a.Yaw, W = 80, D = 60, H = 20, Color = Color3.fromRGB(235, 225, 210), Material = Enum.Material.Marble, Sign = "ДОМ КУЛЬТУРЫ • БИБЛИОТЕКА", SignColor = Color3.fromRGB(110, 60, 120), Path = 40, DoorW = 12 })
	-- Сцена и музыкальный класс.
	part({ Parent = m, Name = "Stage", Size = Vector3.new(30, 2, 12), CFrame = at(-20, 1.2, -22), Color = Color3.fromRGB(110, 70, 45), Material = Enum.Material.WoodPlanks })
	part({ Parent = m, Name = "Curtain", Size = Vector3.new(32, 14, 0.4), CFrame = at(-20, 8, -28.5), Color = Color3.fromRGB(150, 20, 40), Material = Enum.Material.Fabric })
	part({ Parent = m, Name = "Piano", Size = Vector3.new(6, 4, 3), CFrame = at(-30, 4.2, -22), Color = Color3.fromRGB(15, 15, 18), Material = Enum.Material.SmoothPlastic })
	part({ Parent = m, Name = "Keys", Size = Vector3.new(5.6, 0.2, 1), CFrame = at(-30, 6.3, -20.6), Color = Color3.new(1, 1, 1), CanCollide = false })
	for i, lx in { -20, -12 } do
		local stand = interactable(m, "GuitarStand" .. i, at(lx, 3.5, -20), Vector3.new(1.4, 3, 1), Color3.fromRGB(190, 120, 50), "Гитара", Enum.Material.Wood)
		activity(stand, "guitar", "Урок гитары (10$)")
	end
	-- Шахматный клуб: доски в клетку.
	for i, lx in { 8, 20 } do
		local tbl = part({ Parent = m, Name = "ChessTable", Size = Vector3.new(5, 3, 5), CFrame = at(lx, 1.9, -18), Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.Wood })
		for x = 0, 3 do
			for z = 0, 3 do
				part({ Parent = m, Name = "Cell", Size = Vector3.new(1, 0.06, 1), CFrame = at(lx - 1.5 + x, 3.43, -19.5 + z), Color = ((x + z) % 2 == 0) and Color3.fromRGB(240, 230, 210) or Color3.fromRGB(70, 45, 30), CanCollide = false })
			end
		end
		activity(tbl, "chess", "Шахматный кружок")
	end
	-- Библиотека: стеллажи с книгами.
	for i = 0, 3 do
		local x = 8 + i * 8
		part({ Parent = m, Name = "Bookshelf", Size = Vector3.new(6, 9, 2), CFrame = at(x, 4.9, 6), Color = Color3.fromRGB(110, 75, 45), Material = Enum.Material.Wood })
		for shelf = 0, 2 do
			part({ Parent = m, Name = "Books", Size = Vector3.new(5.6, 1.8, 2.1), CFrame = at(x, 2.2 + shelf * 2.8, 6), Color = ({ Color3.fromRGB(170, 50, 50), Color3.fromRGB(50, 90, 160), Color3.fromRGB(60, 130, 70) })[shelf + 1], CanCollide = false })
		end
	end
	local shop = interactable(m, "CultureShop", at(-28, 2, 20), Vector3.new(10, 4, 3), Color3.fromRGB(110, 60, 120), "Лавка: книги, гитары")
	World.Shops.Culture = shop
	staff(at, -28, 17.5, "teacher", "Библиотекарь", { "Книга поднимает настроение.", "Гитару можно купить здесь — и играть на улице!" })
	worker(at(-16, 2.4, -24) * CFrame.Angles(0, math.rad(180), 0), "teacher", "Учитель музыки", { "Попадайте в ритм: клавиши D, F, J, K.", "С уровнем музыки растут чаевые." })
end

local function buildDrivingSchool(a)
	local m, at = building({ Name = "DrivingSchool", GPSName = "Автошкола", X = a.X, Z = a.Z, Yaw = a.Yaw, W = 60, D = 40, H = 14, Color = Color3.fromRGB(240, 240, 240), Material = Enum.Material.Concrete, Sign = "АВТОШКОЛА «ПРАВА»", SignColor = Color3.fromRGB(30, 110, 60), Path = 10, DoorW = 10 })
	local screen = part({ Parent = m, Name = "Screen", Size = Vector3.new(14, 7, 0.3), CFrame = at(0, 7, -19), Color = Color3.fromRGB(20, 20, 25) })
	surfaceText(screen, Enum.NormalId.Back, "ПДД: ТЕОРИЯ", Color3.fromRGB(20, 40, 90), Color3.new(1, 1, 1))
	for row = 0, 1 do
		for col = -1, 1 do
			local d = part({ Parent = m, Name = "Desk", Size = Vector3.new(5, 2.8, 2.5), CFrame = at(col * 8, 1.8, -10 + row * 7), Color = Color3.fromRGB(200, 170, 120), Material = Enum.Material.Wood })
			if row == 1 and col == 0 then
				activity(d, "theory", "Экзамен по ПДД (300$)")
			end
		end
	end
	staff(at, 0, -15, "clerk", "Инструктор", { "Сначала теория, потом вождение по городу.", "Без прав купить машину нельзя!" })
	-- Площадка с конусами и учебной машиной.
	part({ Parent = m, Name = "Pad", Size = Vector3.new(40, 0.3, 24), CFrame = at(0, 0.15, 34), Color = Color3.fromRGB(70, 70, 75), Material = Enum.Material.Asphalt })
	for i = -3, 3 do
		part({ Parent = m, Name = "Cone", Size = Vector3.new(1, 1.6, 1), CFrame = at(i * 5, 1, 44), Color = Color3.fromRGB(255, 120, 20) })
	end
	World.DrivingPad = at(0, 3, 34) * CFrame.Angles(0, math.rad(180), 0)
	local kiosk = interactable(m, "ExamKiosk", at(16, 2.5, 26), Vector3.new(2, 5, 2), Color3.fromRGB(30, 110, 60), "Практический экзамен", Enum.Material.Metal)
	activity(kiosk, "drive", "Практический экзамен")
end

local function buildShootingGallery()
	local pa = Meta.Anchors.Park
	local base = CFrame.new(pa.X + 45, 0, pa.Z + 58)
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	part({ Name = "TirFloor", Size = Vector3.new(16, 0.4, 14), CFrame = at(0, 0.2, 0), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.WoodPlanks })
	part({ Name = "TirBack", Size = Vector3.new(16, 10, 0.6), CFrame = at(0, 5, -7), Color = Color3.fromRGB(60, 40, 30), Material = Enum.Material.Wood })
	part({ Name = "TirRoof", Size = Vector3.new(17, 0.6, 15), CFrame = at(0, 10.3, 0), Color = Color3.fromRGB(200, 40, 40), Material = Enum.Material.Fabric })
	for i = -2, 2 do
		part({ Name = "Target", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 2.2, 2.2), CFrame = at(i * 3, 5.5, -6.6) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.new(1, 1, 1), CanCollide = false })
		part({ Name = "TargetCenter", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 1, 1), CFrame = at(i * 3, 5.5, -6.55) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(220, 30, 30), CanCollide = false })
	end
	local counterPart = interactable(nil, "TirCounter", at(0, 2, 4), Vector3.new(14, 3.5, 2), Color3.fromRGB(120, 80, 50), "Тир", Enum.Material.Wood)
	activity(counterPart, "shooting", "Стрелять (10$)")
	addGPS("Тир в парке", at(0, 3, 10))
end

local function buildFishing()
	for i, f in Meta.FishingSpots or {} do
		local base = CFrame.new(f.X, 0, f.Z) * CFrame.Angles(0, math.rad(f.Yaw), 0)
		part({ Name = "Pier", Size = Vector3.new(6, 0.6, 16), CFrame = base * CFrame.new(0, 0.7, -6), Color = Color3.fromRGB(130, 95, 60), Material = Enum.Material.WoodPlanks })
		for _, c in { { -2.6, -12 }, { 2.6, -12 }, { -2.6, -2 }, { 2.6, -2 } } do
			part({ Name = "PierLeg", Size = Vector3.new(0.6, 3, 0.6), CFrame = base * CFrame.new(c[1], -0.5, c[2]), Color = Color3.fromRGB(90, 65, 40), Material = Enum.Material.Wood })
		end
		local spot = interactable(nil, "FishingSpot", base * CFrame.new(0, 1.6, -12.5), Vector3.new(4, 0.4, 2), Color3.fromRGB(140, 100, 65), "Рыбалка", Enum.Material.WoodPlanks)
		spot.Transparency = 0.2
		activity(spot, "fishing", "Рыбачить (нужна удочка)")
		part({ Name = "Bucket", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 1.2, 1.2), CFrame = base * CFrame.new(2, 1.7, -9) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(80, 120, 170), Material = Enum.Material.Metal })
		if i == 1 then
			addGPS("Рыбалка (Нижнешайтанский пруд)", base * CFrame.new(0, 3, 2))
		end
	end
end

local function buildPlaygrounds()
	for _, pg in Meta.Playgrounds or {} do
		local base = CFrame.new(pg.X, 0, pg.Z) * CFrame.Angles(0, math.rad(pg.Yaw), 0)
		local function at(x, y, z)
			return base * CFrame.new(x, y, z)
		end
		part({ Name = "PlayFloor", Size = Vector3.new(34, 0.25, 30), CFrame = at(0, 0.12, 0), Color = Color3.fromRGB(80, 160, 90), Material = Enum.Material.Fabric })
		-- Горка.
		part({ Name = "SlideTower", Size = Vector3.new(5, 7, 5), CFrame = at(-10, 3.5, -6), Color = Color3.fromRGB(240, 180, 40), Material = Enum.Material.SmoothPlastic })
		part({ ClassName = "WedgePart", Name = "Slide", Size = Vector3.new(3, 7, 10), CFrame = at(-10, 3.5, 3.5) * CFrame.Angles(0, math.rad(180), 0), Color = Color3.fromRGB(220, 50, 50), Material = Enum.Material.SmoothPlastic })
		part({ Name = "SlideRoof", Size = Vector3.new(6, 0.5, 6), CFrame = at(-10, 10.5, -6), Color = Color3.fromRGB(50, 120, 200) })
		-- Качели.
		part({ Name = "SwingBar", Size = Vector3.new(12, 0.6, 0.6), CFrame = at(8, 9, -6), Color = Color3.fromRGB(60, 120, 200), Material = Enum.Material.Metal })
		for _, x in { 2.5, 13.5 } do
			part({ Name = "SwingLeg", Size = Vector3.new(0.6, 9, 0.6), CFrame = at(x, 4.5, -6), Color = Color3.fromRGB(60, 120, 200), Material = Enum.Material.Metal })
		end
		local seat
		for _, x in { 5.5, 10.5 } do
			seat = part({ Name = "SwingSeat", Size = Vector3.new(2.4, 0.4, 1.4), CFrame = at(x, 2.4, -6), Color = Color3.fromRGB(240, 200, 60), Material = Enum.Material.Wood })
			for _, dx in { -1, 1 } do
				part({ Name = "SwingRope", Size = Vector3.new(0.15, 6.4, 0.15), CFrame = at(x + dx, 5.8, -6), Color = Color3.fromRGB(60, 60, 60), CanCollide = false })
			end
		end
		table.insert(World.FunSpots, { Part = seat, Need = "Fun", Amount = 12, Text = "Покачаться", Hold = 1, Cooldown = 12 })
		-- Песочница и карусель.
		part({ Name = "Sandbox", Size = Vector3.new(9, 1, 9), CFrame = at(8, 0.5, 8), Color = Color3.fromRGB(130, 90, 55), Material = Enum.Material.Wood })
		part({ Name = "Sand", Size = Vector3.new(8, 1.05, 8), CFrame = at(8, 0.55, 8), Color = Color3.fromRGB(230, 205, 140), Material = Enum.Material.Sand })
		part({ Name = "Carousel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 7, 7), CFrame = at(-8, 1, 9) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(220, 60, 160), Material = Enum.Material.Metal })
		part({ Name = "CarouselPole", Size = Vector3.new(0.5, 3, 0.5), CFrame = at(-8, 2.5, 9), Color = Color3.fromRGB(200, 200, 205), Material = Enum.Material.Metal })
		bench(at(0, 0, 14) * CFrame.Angles(0, math.rad(180), 0), -1)
	end
end

local function buildParkedCars()
	local folder = Instance.new("Folder")
	folder.Name = "ParkedCars"
	folder.Parent = City
	for i, pc in Meta.ParkedCars or {} do
		if i % 3 ~= 0 then -- каждая третья точка остаётся свободной
			local car = TrafficCar.Build(i * 977)
			if car.Kind ~= "bus" then
				local root = CFrame.new(pc.X, 0.2, pc.Z) * CFrame.Angles(0, math.rad(pc.Yaw), 0)
				for j, cf in TrafficCar.CFrames(car, root) do
					car.List[j].CFrame = cf
					car.List[j].CanCollide = true
				end
				car.Model.Name = "ParkedCar"
				car.Model.Parent = folder
			else
				car.Model:Destroy()
			end
		end
		maybeYield()
	end
end

local KIOSKS = {
	{ Name = "ШАУРМА", Color = Color3.fromRGB(230, 120, 30) },
	{ Name = "ПИРОЖКИ", Color = Color3.fromRGB(200, 60, 60) },
	{ Name = "КОФЕ С СОБОЙ", Color = Color3.fromRGB(110, 70, 40) },
	{ Name = "ПЕЧАТЬ", Color = Color3.fromRGB(40, 100, 170) },
}
local ADS = {
	"ТРУБНЫЙ ЗАВОД ЖДЁТ ТЕБЯ!", "ЛИЦЕЙ №21: НАБОР ОТКРЫТ", "АВТОШКОЛА «ПРАВА» — СДАЙ С ПЕРВОГО РАЗА",
	"ПЕЛЬМЕННАЯ: КАК У БАБУШКИ", "СПОРТКОМПЛЕКС «КОСМОС»", "ПЕРВОУРАЛЬСК — ГОРОД НА ГРАНИЦЕ ЕВРОПЫ И АЗИИ",
	"ДОМ КУЛЬТУРЫ: КРУЖКИ ДЛЯ ВСЕХ", "ЦЕНТРАЛЬНЫЙ СТАДИОН: ФУТБОЛ КАЖДЫЙ ДЕНЬ",
}

local function buildKiosksAndAds()
	World.ShopPoints.Kiosk = {}
	for i, k in Meta.Kiosks or {} do
		local info = KIOSKS[(i - 1) % #KIOSKS + 1]
		local base = CFrame.new(k.X, 0, k.Z) * CFrame.Angles(0, math.rad(k.Yaw), 0)
		-- Корпус киоска позади продавца, спереди — прилавок.
		part({ Name = "Kiosk", Size = Vector3.new(10, 8, 5), CFrame = base * CFrame.new(0, 4, 1), Color = Color3.fromRGB(235, 235, 230), Material = Enum.Material.SmoothPlastic })
		for _, x in { -4.7, 4.7 } do
			part({ Name = "KioskSide", Size = Vector3.new(0.6, 8, 3), CFrame = base * CFrame.new(x, 4, -2.9), Color = Color3.fromRGB(235, 235, 230) })
		end
		part({ Name = "KioskTop", Size = Vector3.new(10, 0.6, 3), CFrame = base * CFrame.new(0, 7.7, -2.9), Color = Color3.fromRGB(235, 235, 230) })
		part({ ClassName = "WedgePart", Name = "Awning", Size = Vector3.new(11, 1.4, 3), CFrame = base * CFrame.new(0, 7.3, -4.8), Color = info.Color, Material = Enum.Material.Fabric })
		local sign = part({ Name = "KioskSign", Size = Vector3.new(9, 1.6, 0.3), CFrame = base * CFrame.new(0, 8.8, -3.6), Color = info.Color, CanCollide = false })
		surfaceText(sign, Enum.NormalId.Front, info.Name, info.Color)
		local counterPart = interactable(nil, "KioskCounter", base * CFrame.new(0, 2.6, -4.2), Vector3.new(7, 0.4, 1.4), Color3.fromRGB(120, 80, 50), nil, Enum.Material.Wood)
		table.insert(World.ShopPoints.Kiosk, counterPart)
		worker(base * CFrame.new(0, 0.4, -2.6), "cook", "Продавец киоска", { "Свежая шаурма и горячий кофе!", "Пирожки только из печи." })
	end
	for i, b in Meta.Billboards or {} do
		local base = CFrame.new(b.X, 0, b.Z) * CFrame.Angles(0, math.rad(b.Yaw), 0)
		for _, x in { -8, 8 } do
			part({ Name = "BillboardLeg", Size = Vector3.new(0.8, 14, 0.8), CFrame = base * CFrame.new(x, 7, 0), Color = Color3.fromRGB(80, 80, 85), Material = Enum.Material.Metal })
		end
		local board = part({ Name = "Billboard", Size = Vector3.new(24, 9, 0.6), CFrame = base * CFrame.new(0, 16, 0), Color = Color3.fromRGB(250, 250, 250) })
		local ad = ADS[(i - 1) % #ADS + 1]
		local hue = Color3.fromHSV(((i * 0.17) % 1), 0.7, 0.75)
		surfaceText(board, Enum.NormalId.Front, ad, hue, Color3.new(1, 1, 1))
		surfaceText(board, Enum.NormalId.Back, ad, hue, Color3.new(1, 1, 1))
	end
end

---------------------------------------------------------------------------
-- Улицы: светофоры, «зебры», стоп-линии, остановки, скамейки, урны
---------------------------------------------------------------------------
local Roads = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Roads"))

local function nearGameplay(pos, dist)
	for _, a in Meta.Anchors do
		if (Vector3.new(a.X, 0, a.Z) - pos).Magnitude < dist then
			return true
		end
	end
	for _, h in Meta.Houses do
		if (Vector3.new(h.X, 0, h.Z) - pos).Magnitude < dist * 0.7 then
			return true
		end
	end
	return false
end

local function nearLight(pos, dist)
	for _, n in Roads.LightList do
		if (Roads.Nodes[n] - pos).Magnitude < dist then
			return true
		end
	end
	return false
end

local WHITE = Color3.fromRGB(240, 240, 235)
local POLE = Color3.fromRGB(60, 62, 68)

local function trafficLight(folder, node, nodeW, e, dir)
	-- dir — направление от перекрёстка вдоль улицы; машины едут навстречу (−dir).
	local incoming = -dir
	local right = Roads.Right(incoming)
	local base = Roads.Nodes[node] + dir * (nodeW / 2 + 4) + right * (e.Width / 2 + 2.5)
	part({ Parent = folder, Name = "LightPole", Size = Vector3.new(0.7, 15, 0.7), Position = base + Vector3.new(0, 7.5, 0), Color = POLE, Material = Enum.Material.Metal })
	local reach = e.Width / 4 + 2.5
	part({ Parent = folder, Name = "LightArm", Size = Vector3.new(0.4, 0.4, reach), CFrame = CFrame.lookAt(base - right * (reach / 2) + Vector3.new(0, 14.6, 0), base - right * reach + Vector3.new(0, 14.6, 0)), Color = POLE, Material = Enum.Material.Metal })
	local headPos = base - right * reach + Vector3.new(0, 12.4, 0)
	local head = part({ Parent = folder, Name = "TrafficLightHead", Size = Vector3.new(1.6, 4.6, 1.2), CFrame = CFrame.lookAt(headPos, headPos + dir), Color = Color3.fromRGB(30, 30, 32), Material = Enum.Material.Metal })
	head:SetAttribute("Node", node)
	head:SetAttribute("Group", Roads.Group(incoming))
	for i, name in { "Red", "Yellow", "Green" } do
		local bulb = part({ Parent = head, Name = name, Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.1, 1.1), CFrame = head.CFrame * CFrame.new(0, 1.45 - (i - 1) * 1.45, -0.45), Color = Color3.fromRGB(40, 40, 40), CanCollide = false })
		bulb.CastShadow = false
	end
	head:AddTag("TrafficLight")
	-- Стоп-линия на встречной полосе.
	local stopPos = Roads.Nodes[node] + dir * (nodeW / 2 + 8) + right * (e.Width / 4) + Vector3.new(0, 0.33, 0)
	part({ Parent = folder, Name = "StopLine", Size = Vector3.new(e.Width / 2 - 1, 0.06, 0.8), CFrame = CFrame.lookAt(stopPos, stopPos + dir), Color = WHITE, CanCollide = false })
	-- «Зебра».
	local cross = Roads.Nodes[node] + dir * (nodeW / 2 + 4) + Vector3.new(0, 0.33, 0)
	local half = e.Width / 2 - 1.5
	local off = -half
	while off <= half do
		local p = cross + Roads.Right(dir) * off
		part({ Parent = folder, Name = "Crosswalk", Size = Vector3.new(1.2, 0.06, 5), CFrame = CFrame.lookAt(p, p + dir), Color = WHITE, CanCollide = false })
		off += 2.4
	end
end

local function busStop(folder, pos, dir, right)
	-- Остановка стоит на тротуаре, лицом к дороге.
	local cf = CFrame.lookAt(pos, pos - right)
	part({ Parent = folder, Name = "StopRoof", Size = Vector3.new(11, 0.4, 4.5), CFrame = cf * CFrame.new(0, 8.2, 0), Color = Color3.fromRGB(60, 120, 170), Material = Enum.Material.Metal })
	part({ Parent = folder, Name = "StopBack", Size = Vector3.new(11, 6, 0.3), CFrame = cf * CFrame.new(0, 4.8, 2), Color = Color3.fromRGB(170, 210, 235), Material = Enum.Material.Glass, Transparency = 0.4 })
	for _, x in { -5.3, 5.3 } do
		part({ Parent = folder, Name = "StopPost", Size = Vector3.new(0.4, 8, 0.4), CFrame = cf * CFrame.new(x, 4.1, 2), Color = POLE, Material = Enum.Material.Metal })
	end
	part({ Parent = folder, Name = "StopBench", Size = Vector3.new(8, 0.5, 1.6), CFrame = cf * CFrame.new(0, 2, 1.1), Color = Color3.fromRGB(150, 100, 60), Material = Enum.Material.Wood })
	part({ Parent = folder, Name = "StopSignPole", Size = Vector3.new(0.4, 9, 0.4), CFrame = cf * CFrame.new(7, 4.5, -0.8), Color = POLE, Material = Enum.Material.Metal })
	local sign = part({ Parent = folder, Name = "StopSign", Size = Vector3.new(3, 2.4, 0.2), CFrame = cf * CFrame.new(7, 8.5, -0.8), Color = Color3.fromRGB(255, 255, 255), CanCollide = false })
	surfaceText(sign, Enum.NormalId.Front, "🚌 ОСТАНОВКА", Color3.fromRGB(30, 90, 170))
	surfaceText(sign, Enum.NormalId.Back, "🚌 ОСТАНОВКА", Color3.fromRGB(30, 90, 170))
end

local function trashBin(folder, pos)
	part({ Parent = folder, Name = "TrashBin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, 1.6, 1.6), CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 100, 70), Material = Enum.Material.Metal })
end

local function buildStreets()
	local folder = Instance.new("Folder")
	folder.Name = "StreetDetails"
	folder.Parent = City
	for _, n in Roads.LightList do
		local nodeW = Roads.NodeWidth[n] or 20
		for _, adj in Roads.Adj[n] or {} do
			local e = Roads.Edges[adj.Edge]
			local delta = Roads.Nodes[adj.To] - Roads.Nodes[n]
			if delta.Magnitude > nodeW + 14 then
				trafficLight(folder, n, nodeW, e, delta.Unit)
			end
		end
		maybeYield()
	end
	local sinceStop = 0
	for id, e in Roads.Edges do
		if e.Class == "primary" or e.Class == "secondary" or e.Class == "tertiary" then
			local a, b = Roads.Nodes[e.A], Roads.Nodes[e.B]
			local len = (b - a).Magnitude
			if len > 50 then
				local dir = (b - a).Unit
				local right = Roads.Right(dir)
				local count = math.floor(len / 90)
				for i = 1, count do
					local side = (i % 2 == 0) and 1 or -1
					local pos = a + dir * (len * i / (count + 1)) + right * side * (e.Width / 2 + 3.8)
					if not nearGameplay(pos, 70) and not nearLight(pos, 30) then
						if (id + i) % 3 == 0 then
							trashBin(folder, pos)
						else
							bench(CFrame.lookAt(pos, pos - right * side), -1)
						end
					end
				end
				sinceStop += len
				if (e.Class == "primary" or e.Class == "secondary") and sinceStop > 450 and len > 70 then
					local pos = a + dir * (len / 2) + right * (e.Width / 2 + 3.5)
					if not nearGameplay(pos, 70) and not nearLight(pos, 40) then
						sinceStop = 0
						busStop(folder, pos, dir, right)
					end
				end
			end
		end
		maybeYield()
	end
end

local function ensure(parent, className)
	local obj = parent:FindFirstChildOfClass(className)
	if not obj then
		obj = Instance.new(className)
		obj.Parent = parent
	end
	return obj
end

-- Освещение «Future» задаётся в файле места (build.py); здесь — атмосфера,
-- облака и пост-обработка. Широта — как у Первоуральска (57° с. ш.).
local function setupLighting()
	Lighting.ClockTime = 9
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(70, 72, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(125, 128, 138)
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ShadowSoftness = 0.15
	Lighting.GeographicLatitude = 57
	local atm = ensure(Lighting, "Atmosphere")
	atm.Density = 0.3
	atm.Offset = 0.25
	atm.Color = Color3.fromRGB(199, 205, 215)
	atm.Decay = Color3.fromRGB(106, 112, 125)
	atm.Glare = 0.2
	atm.Haze = 1.4
	local bloom = ensure(Lighting, "BloomEffect")
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 1.6
	local cc = ensure(Lighting, "ColorCorrectionEffect")
	cc.Brightness = 0.02
	cc.Contrast = 0.08
	cc.Saturation = 0.12
	cc.TintColor = Color3.fromRGB(255, 250, 245)
	local rays = ensure(Lighting, "SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.8
	local clouds = ensure(workspace.Terrain, "Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
end

-- Ночью в части окон загорается тёплый свет.
local nightState
function WorldBuilder.SetNight(isNight)
	if nightState == isNight then
		return
	end
	nightState = isNight
	for _, band in CollectionService:GetTagged("NightGlow") do
		band.Material = isNight and Enum.Material.Neon or Enum.Material.Glass
		band.Color = isNight and Color3.fromRGB(255, 205, 130) or WINDOW
	end
end

function WorldBuilder.Build()
	local old = workspace:FindFirstChild("City")
	if old then
		old:Destroy()
	end
	for _, child in workspace:GetChildren() do
		if child.Name == "Baseplate" or child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
	City = Instance.new("Folder")
	City.Name = "City"
	City.Parent = workspace

	local anchors = Meta.Anchors
	buildTerrain()
	buildRoads()
	buildRealBuildings()
	buildStreetSigns()
	buildResidential()
	buildCityHall(anchors.CityHall)
	buildPolice(anchors.Police)
	buildHospital(anchors.Hospital)
	buildBank(anchors.Bank)
	buildOffice(anchors.Office)
	buildSupermarket(anchors.Supermarket)
	buildFlorist(anchors.Florist)
	buildCafe(anchors.Cafe)
	buildDealership(anchors.Dealership)
	buildFactory(anchors.Factory)
	buildWedding(anchors.Wedding)
	buildPark(anchors.Park)
	buildJail(anchors.Jail)
	buildStadium(anchors.Stadium)
	buildSports(anchors.Sports)
	buildSchool(anchors.School)
	buildCulture(anchors.Culture)
	buildDrivingSchool(anchors.DrivingSchool)
	buildShootingGallery()
	buildFishing()
	buildPlaygrounds()
	buildParkedCars()
	buildKiosksAndAds()
	buildPatrolPosts()
	buildNature()
	buildStreets()
	setupLighting()

	local cars = Instance.new("Folder")
	cars.Name = "Cars"
	cars.Parent = workspace
	World.CarFolder = cars

	return World
end

return WorldBuilder
