-- Строит город Первоуральск при запуске сервера: реальные улицы и здания
-- из открытых данных OpenStreetMap (src/server/Map, генерирует
-- tools/pervouralsk/convert.py) + игровые здания с интерьерами
-- (мэрия, ОМВД, больница, банк, офис, супермаркет, кафе, автосалон, завод,
-- ЗАГС, парк, тюрьма, дома игроков) на местах реальных объектов.
-- Возвращает реестр важных точек (World), который используют остальные сервисы.

local Lighting = game:GetService("Lighting")

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

	-- Дорожка от двери к дороге.
	if o.Path then
		part({ Parent = m, Name = "Path", Size = Vector3.new(doorW, 0.3, o.Path), Position = at(0, 0.15, d / 2 + o.Path / 2), Color = Color3.fromRGB(180, 180, 175), Material = Enum.Material.Concrete })
	end

	addGPS(o.GPSName or o.Name, at(0, 3, d / 2 + 6))
	return m, at
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

local function tree(pos)
	part({ Name = "Trunk", Size = Vector3.new(2, 10, 2), Position = pos + Vector3.new(0, 5, 0), Color = Color3.fromRGB(100, 70, 40), Material = Enum.Material.Wood })
	local leaves = part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(11, 11, 11), Position = pos + Vector3.new(0, 12, 0), Color = Color3.fromRGB(60, 140 + math.random(0, 40), 60), Material = Enum.Material.Grass })
	leaves.CanCollide = false
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
	part({ Name = "LampPost", Size = Vector3.new(0.8, 16, 0.8), Position = pos + Vector3.new(0, 8, 0), Color = Color3.fromRGB(50, 50, 55), Material = Enum.Material.Metal })
	local bulb = part({ Name = "LampBulb", Size = Vector3.new(2, 1, 2), Position = pos + Vector3.new(0, 16.5, 0), Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon, CanCollide = false })
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
		if w >= 18 then
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
				part({ Parent = folder, Name = "Windows", Size = Vector3.new(sx + 0.2, 1.8, sz + 0.2), CFrame = base * CFrame.new(0, y, 0), Color = WINDOW, Material = Enum.Material.Glass, CanCollide = false })
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
	local realty = counter(m, at(0, 1.9, -25), Vector3.new(12, 3.5, 3), Color3.fromRGB(70, 110, 160))
	floatLabel(realty, "Агентство недвижимости", 4)
	World.Desks.Realty = realty

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
	local pad = part({ Parent = m, Name = "CarPad", Size = Vector3.new(16, 0.3, 24), Position = at(-35, 0.2, 55), Color = Color3.fromRGB(40, 40, 120) })
	local kiosk = interactable(m, "CarKiosk", at(-24, 2.5, 55), Vector3.new(2, 5, 2), Color3.fromRGB(40, 40, 120), "Служебный транспорт")
	World.PoliceCarKiosk = kiosk
	World.PoliceCarSpawn = pad.CFrame + Vector3.new(0, 3, 0)
end

local function buildHospital(a)
	local m, at = building({ Name = "Hospital", GPSName = "Городская больница №1", X = a.X, Z = a.Z, Yaw = a.Yaw, W = 100, D = 80, H = 20, Color = Color3.fromRGB(245, 245, 250), Sign = "ГОРОДСКАЯ БОЛЬНИЦА №1", SignColor = Color3.fromRGB(200, 40, 50), Path = 40, DoorW = 14 })
	counter(m, at(0, 1.9, 20), Vector3.new(18, 3.5, 3), Color3.fromRGB(230, 230, 240))
	World.Spawns.Hospital = (at(0, 4, 28))
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
	addGPS("Цветочный магазин", base * CFrame.new(0, 3, 12))
end

local function buildCafe(a)
	local m, at = building({ Name = "Cafe", GPSName = "Пельменная", X = a.X, Z = a.Z, Yaw = a.Yaw, W = 70, D = 60, H = 16, Color = Color3.fromRGB(170, 110, 80), Material = Enum.Material.Brick, Sign = "ПЕЛЬМЕННАЯ", SignColor = Color3.fromRGB(120, 60, 30), Path = 40 })
	counter(m, at(0, 1.9, 2), Vector3.new(30, 3.5, 3))
	local shop = interactable(m, "CafeCounter", at(-10, 4.5, 4), Vector3.new(3, 1, 1), Color3.fromRGB(255, 220, 150), "Меню")
	shop.CanCollide = false
	World.Shops.Cafe = shop
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
		if math.abs(x - cx) > 15 and math.abs(z - cz) > 15 and (Vector2.new(x - cx, z - cz)).Magnitude > 20 then
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

local function setupLighting()
	Lighting.ClockTime = 9
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(90, 90, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(130, 130, 140)
	Lighting.GlobalShadows = true
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atm = Instance.new("Atmosphere")
		atm.Density = 0.25
		atm.Haze = 1
		atm.Parent = Lighting
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
	buildPatrolPosts()
	buildNature()
	setupLighting()

	local cars = Instance.new("Folder")
	cars.Name = "Cars"
	cars.Parent = workspace
	World.CarFolder = cars

	return World
end

return WorldBuilder
