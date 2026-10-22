-- Мебель для дома: модели (общие для сервера и «призрака» в режиме
-- обустройства) и проверка, можно ли поставить вещь в это место.
-- Каталог (цены, польза, размеры) — Config.Home.Items.
-- Система координат вещи: центр основания (0, 0, 0), «лицевая» сторона — +Z.

local Config = require(script.Parent:WaitForChild("Config"))

local Furniture = {}
local H = Config.Home

local rgb = Color3.fromRGB
local M = Enum.Material

local WOOD, DARK_WOOD, WHITE, BLACK = rgb(170, 125, 80), rgb(95, 60, 40), rgb(240, 240, 238), rgb(30, 30, 34)
local METAL, GOLD = rgb(160, 165, 172), rgb(225, 180, 60)

-- Высота модели (для невидимого «хитбокса», по нему выбирают вещь мышью).
local HEIGHT = {
	sofa = 4, armchair = 4, table_round = 3, coffee_table = 1.8, rug = 0.2, tv_big = 6, console = 3.2, fireplace = 7,
	floor_lamp = 6, bed_double = 3.8, nightstand = 3.3, wardrobe = 8, bathtub = 2.6, stove = 3.5, coffee_machine = 4.3,
	chair = 4, bookshelf = 7, computer = 4.5, chess_set = 3, guitar_stand = 4.5, home_gym = 4, treadmill = 4.6, plant = 5,
	painting = 6.6, aquarium = 5.5, clock = 7, flowers = 1.8, bench_garden = 3.4, grill = 3.5, swing = 7.4, trampoline = 3,
	garden_bed = 1.5, gnome = 2.2, lantern = 6, neon_sofa = 4, gold_bed = 3.8, piano = 4.8, arcade = 6, home_cinema = 8,
	hot_tub = 3, pool = 1.6,
}

-- Геометрия: список деталей { name, size, cframe, color, material, opts }.
local function sofaParts(add, body, cushion, accent)
	add("Base", Vector3.new(8, 1.2, 3.5), CFrame.new(0, 0.9, 0), body, M.Fabric)
	for _, x in { -1.9, 1.9 } do
		add("Seat", Vector3.new(3.6, 0.6, 2.6), CFrame.new(x, 1.8, 0.35), cushion, M.Fabric, { Seat = true })
	end
	add("Back", Vector3.new(8, 2.4, 0.8), CFrame.new(0, 2.6, -1.35), body, M.Fabric)
	for _, x in { -3.6, 3.6 } do
		add("Arm", Vector3.new(0.8, 2, 3.5), CFrame.new(x, 1.6, 0), body, M.Fabric)
	end
	for _, x in { -3.5, 3.5 } do
		for _, z in { -1.4, 1.4 } do
			add("Leg", Vector3.new(0.4, 0.3, 0.4), CFrame.new(x, 0.15, z), accent or DARK_WOOD, M.Wood, { NoCollide = true })
		end
	end
end

local function bedParts(add, frame, sheet, blanket, mat)
	add("Frame", Vector3.new(8, 1.4, 10), CFrame.new(0, 0.7, 0), frame, mat or M.Wood)
	add("Mattress", Vector3.new(7.6, 0.8, 9.4), CFrame.new(0, 1.8, 0.3), sheet, M.Fabric, { Use = true })
	add("Blanket", Vector3.new(7.8, 0.3, 6), CFrame.new(0, 2.3, 1.9), blanket, M.Fabric, { NoCollide = true })
	for _, x in { -1.8, 1.8 } do
		add("Pillow", Vector3.new(3, 0.6, 1.6), CFrame.new(x, 2.5, -3.6), WHITE, M.Fabric, { NoCollide = true })
	end
	add("Headboard", Vector3.new(8, 3.6, 0.6), CFrame.new(0, 1.8, -4.7), frame, mat or M.Wood)
end

local GEOMETRY = {
	sofa = function(add)
		sofaParts(add, rgb(90, 60, 120), rgb(110, 80, 140))
	end,
	neon_sofa = function(add)
		sofaParts(add, rgb(25, 25, 30), rgb(40, 40, 48), rgb(255, 60, 200))
		add("Glow", Vector3.new(8.1, 0.15, 3.6), CFrame.new(0, 0.35, 0), rgb(255, 60, 200), M.Neon, { NoCollide = true, Light = { Range = 10, Color = rgb(255, 80, 210) } })
		add("BackGlow", Vector3.new(8.1, 0.15, 0.9), CFrame.new(0, 3.85, -1.35), rgb(80, 220, 255), M.Neon, { NoCollide = true })
	end,
	armchair = function(add)
		local c = rgb(150, 95, 60)
		add("Base", Vector3.new(3.5, 1.2, 3.5), CFrame.new(0, 0.9, 0), c, M.Fabric)
		add("Seat", Vector3.new(2.5, 0.6, 2.6), CFrame.new(0, 1.8, 0.3), rgb(175, 120, 80), M.Fabric, { Seat = true })
		add("Back", Vector3.new(3.5, 2.4, 0.8), CFrame.new(0, 2.6, -1.35), c, M.Fabric)
		for _, x in { -1.5, 1.5 } do
			add("Arm", Vector3.new(0.5, 1.8, 3.5), CFrame.new(x, 1.7, 0), c, M.Fabric)
		end
	end,
	table_round = function(add)
		add("Top", Vector3.new(0.3, 5, 5), CFrame.new(0, 2.85, 0) * CFrame.Angles(0, 0, math.rad(90)), WOOD, M.Wood, { Shape = Enum.PartType.Cylinder })
		add("Leg", Vector3.new(0.6, 2.7, 0.6), CFrame.new(0, 1.4, 0), DARK_WOOD, M.Wood)
		add("Foot", Vector3.new(0.2, 2.4, 2.4), CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), DARK_WOOD, M.Wood, { Shape = Enum.PartType.Cylinder })
	end,
	coffee_table = function(add)
		add("Top", Vector3.new(4, 0.25, 2.5), CFrame.new(0, 1.6, 0), rgb(200, 225, 235), M.Glass, { Transparency = 0.3 })
		add("Shelf", Vector3.new(3.6, 0.2, 2.1), CFrame.new(0, 0.5, 0), DARK_WOOD, M.Wood)
		for _, x in { -1.8, 1.8 } do
			for _, z in { -1.05, 1.05 } do
				add("Leg", Vector3.new(0.25, 1.5, 0.25), CFrame.new(x, 0.75, z), BLACK, M.Metal)
			end
		end
	end,
	rug = function(add)
		add("Rug", Vector3.new(10, 0.1, 7), CFrame.new(0, 0.05, 0), rgb(170, 60, 70), M.Fabric, { NoCollide = true })
		add("Pattern", Vector3.new(8, 0.11, 5), CFrame.new(0, 0.06, 0), rgb(220, 170, 90), M.Fabric, { NoCollide = true })
		add("Center", Vector3.new(6, 0.12, 3), CFrame.new(0, 0.07, 0), rgb(150, 45, 60), M.Fabric, { NoCollide = true })
	end,
	tv_big = function(add)
		add("Cabinet", Vector3.new(8, 1.6, 1.5), CFrame.new(0, 0.8, 0), DARK_WOOD, M.Wood)
		add("Screen", Vector3.new(7, 3.9, 0.3), CFrame.new(0, 3.8, -0.2), BLACK, M.SmoothPlastic, { Use = true })
		add("Display", Vector3.new(6.6, 3.5, 0.05), CFrame.new(0, 3.8, -0.03), rgb(40, 90, 150), M.Neon, { NoCollide = true })
	end,
	console = function(add)
		add("Stand", Vector3.new(3, 1.2, 2), CFrame.new(0, 0.6, 0), BLACK, M.SmoothPlastic)
		add("Console", Vector3.new(1.4, 0.4, 1), CFrame.new(-0.5, 1.4, 0.3), WHITE, M.SmoothPlastic, { Use = true })
		add("Strip", Vector3.new(1.4, 0.05, 0.1), CFrame.new(-0.5, 1.4, 0.82), rgb(60, 160, 255), M.Neon, { NoCollide = true })
		add("Screen", Vector3.new(2.8, 1.6, 0.2), CFrame.new(0, 2.4, -0.7), BLACK, M.SmoothPlastic)
		add("Display", Vector3.new(2.6, 1.4, 0.05), CFrame.new(0, 2.4, -0.58), rgb(80, 200, 120), M.Neon, { NoCollide = true })
		add("Pad", Vector3.new(0.8, 0.2, 0.5), CFrame.new(0.8, 1.3, 0.5), BLACK, M.SmoothPlastic, { NoCollide = true })
	end,
	fireplace = function(add)
		add("Body", Vector3.new(6, 5, 2.5), CFrame.new(0, 2.5, 0), rgb(165, 85, 65), M.Brick)
		add("Hearth", Vector3.new(3.2, 2.4, 0.2), CFrame.new(0, 1.5, 1.2), BLACK, M.Slate, { NoCollide = true })
		add("Fire", Vector3.new(2.4, 1, 0.4), CFrame.new(0, 0.9, 1), rgb(255, 140, 40), M.Neon, { NoCollide = true, Light = { Range = 16, Color = rgb(255, 150, 70), Brightness = 1.6 } })
		add("Mantel", Vector3.new(6.6, 0.4, 2.9), CFrame.new(0, 5.2, 0.1), DARK_WOOD, M.Wood)
		add("Chimney", Vector3.new(3, 1.8, 1.6), CFrame.new(0, 6.3, -0.4), rgb(165, 85, 65), M.Brick)
	end,
	floor_lamp = function(add)
		add("Base", Vector3.new(0.3, 1.4, 1.4), CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)), BLACK, M.Metal, { Shape = Enum.PartType.Cylinder })
		add("Pole", Vector3.new(0.25, 4.8, 0.25), CFrame.new(0, 2.6, 0), BLACK, M.Metal)
		add("Shade", Vector3.new(1.5, 1.2, 1.5), CFrame.new(0, 5.4, 0), rgb(255, 240, 200), M.Neon, { NoCollide = true, Light = { Range = 18, Color = rgb(255, 225, 170) } })
	end,
	bed_double = function(add)
		bedParts(add, WOOD, WHITE, rgb(80, 120, 190))
	end,
	gold_bed = function(add)
		bedParts(add, GOLD, rgb(255, 245, 230), rgb(170, 30, 50), M.Metal)
		add("Canopy", Vector3.new(8, 0.3, 10), CFrame.new(0, 7.5, 0), rgb(170, 30, 50), M.Fabric, { NoCollide = true })
		for _, x in { -3.8, 3.8 } do
			for _, z in { -4.8, 4.8 } do
				add("Post", Vector3.new(0.3, 6, 0.3), CFrame.new(x, 4.5, z), GOLD, M.Metal, { NoCollide = true })
			end
		end
	end,
	nightstand = function(add)
		add("Body", Vector3.new(2, 2, 2), CFrame.new(0, 1, 0), WOOD, M.Wood)
		add("Drawer", Vector3.new(1.6, 0.6, 0.1), CFrame.new(0, 1.3, 1.02), DARK_WOOD, M.Wood, { NoCollide = true })
		add("LampBase", Vector3.new(0.4, 0.6, 0.4), CFrame.new(0, 2.3, 0), WHITE, M.SmoothPlastic, { NoCollide = true })
		add("Shade", Vector3.new(1, 0.7, 1), CFrame.new(0, 2.9, 0), rgb(255, 235, 190), M.Neon, { NoCollide = true, Light = { Range = 12, Color = rgb(255, 220, 160) } })
	end,
	wardrobe = function(add)
		add("Body", Vector3.new(6, 8, 2.5), CFrame.new(0, 4, 0), WOOD, M.Wood, { Use = true })
		for _, x in { -1.45, 1.45 } do
			add("Mirror", Vector3.new(2.8, 7, 0.1), CFrame.new(x, 4, 1.26), rgb(200, 220, 235), M.Glass, { NoCollide = true, Transparency = 0.1 })
		end
		add("Handle", Vector3.new(0.15, 1.2, 0.15), CFrame.new(0, 4, 1.35), METAL, M.Metal, { NoCollide = true })
	end,
	bathtub = function(add)
		add("Tub", Vector3.new(7, 2.2, 3.5), CFrame.new(0, 1.1, 0), WHITE, M.SmoothPlastic)
		add("Water", Vector3.new(6.2, 0.2, 2.7), CFrame.new(0, 2.15, 0), rgb(150, 205, 240), M.Glass, { NoCollide = true, Transparency = 0.3, Use = true })
		add("Faucet", Vector3.new(0.3, 1, 0.3), CFrame.new(-3.2, 2.6, 0), METAL, M.Metal, { NoCollide = true })
		add("Foam", Vector3.new(2, 0.3, 1.5), CFrame.new(1, 2.3, 0.3), WHITE, M.Fabric, { NoCollide = true })
	end,
	stove = function(add)
		add("Body", Vector3.new(3.5, 3, 3), CFrame.new(0, 1.5, 0), WHITE, M.Metal, { Use = true })
		add("Top", Vector3.new(3.5, 0.1, 3), CFrame.new(0, 3.05, 0), BLACK, M.Glass)
		for _, x in { -0.8, 0.8 } do
			for _, z in { -0.7, 0.7 } do
				add("Burner", Vector3.new(0.12, 1, 1), CFrame.new(x, 3.12, z) * CFrame.Angles(0, 0, math.rad(90)), rgb(200, 60, 40), M.Neon, { NoCollide = true, Shape = Enum.PartType.Cylinder })
			end
		end
		add("Oven", Vector3.new(2.6, 1.6, 0.1), CFrame.new(0, 1.3, 1.52), BLACK, M.Glass, { NoCollide = true })
		add("Pot", Vector3.new(1, 0.9, 0.9), CFrame.new(0.8, 3.55, -0.7) * CFrame.Angles(0, 0, math.rad(90)), METAL, M.Metal, { NoCollide = true, Shape = Enum.PartType.Cylinder })
	end,
	coffee_machine = function(add)
		add("Cabinet", Vector3.new(2, 3, 2), CFrame.new(0, 1.5, 0), WOOD, M.Wood)
		add("Machine", Vector3.new(1.3, 1.3, 1.1), CFrame.new(0, 3.65, -0.3), BLACK, M.Metal, { Use = true })
		add("Light", Vector3.new(0.6, 0.15, 0.05), CFrame.new(0, 4, 0.27), rgb(80, 220, 120), M.Neon, { NoCollide = true })
		add("Cup", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 3.2, 0.45), WHITE, M.SmoothPlastic, { NoCollide = true })
	end,
	chair = function(add)
		add("Seat", Vector3.new(2, 0.4, 2), CFrame.new(0, 1.8, 0), WOOD, M.Wood, { Seat = true })
		add("Back", Vector3.new(2, 2, 0.3), CFrame.new(0, 3, -0.85), WOOD, M.Wood)
		for _, x in { -0.85, 0.85 } do
			for _, z in { -0.85, 0.85 } do
				add("Leg", Vector3.new(0.25, 1.6, 0.25), CFrame.new(x, 0.8, z), DARK_WOOD, M.Wood, { NoCollide = true })
			end
		end
	end,
	bookshelf = function(add)
		add("Back", Vector3.new(5, 7, 0.2), CFrame.new(0, 3.5, -0.8), DARK_WOOD, M.Wood, { Use = true })
		for _, x in { -2.4, 2.4 } do
			add("Side", Vector3.new(0.2, 7, 1.8), CFrame.new(x, 3.5, 0), DARK_WOOD, M.Wood)
		end
		local colors = { rgb(180, 50, 50), rgb(50, 90, 160), rgb(60, 140, 80), rgb(210, 170, 60), rgb(120, 70, 140) }
		for i = 0, 3 do
			local y = 0.2 + i * 1.7
			add("Shelf", Vector3.new(4.6, 0.2, 1.6), CFrame.new(0, y, 0), DARK_WOOD, M.Wood)
			for b = 0, 7 do
				local hgt = 1 + ((b + i) % 3) * 0.15
				add("Book", Vector3.new(0.4, hgt, 1.1), CFrame.new(-1.9 + b * 0.5, y + 0.1 + hgt / 2, 0.1), colors[(b + i) % #colors + 1], M.SmoothPlastic, { NoCollide = true })
			end
		end
	end,
	computer = function(add)
		add("Desk", Vector3.new(5, 0.3, 2.4), CFrame.new(0, 2.6, -0.3), WHITE, M.Wood)
		for _, x in { -2.3, 2.3 } do
			add("Leg", Vector3.new(0.3, 2.5, 2.2), CFrame.new(x, 1.25, -0.3), BLACK, M.Metal)
		end
		add("Monitor", Vector3.new(2.6, 1.6, 0.2), CFrame.new(0, 3.8, -1.1), BLACK, M.SmoothPlastic, { Use = true })
		add("Display", Vector3.new(2.4, 1.4, 0.05), CFrame.new(0, 3.8, -0.98), rgb(70, 120, 210), M.Neon, { NoCollide = true })
		add("Keyboard", Vector3.new(1.8, 0.1, 0.6), CFrame.new(0, 2.8, 0.2), BLACK, M.SmoothPlastic, { NoCollide = true })
		add("Chair", Vector3.new(1.8, 0.4, 1.4), CFrame.new(0, 1.7, 0.75), rgb(40, 40, 50), M.Fabric, { Seat = true })
	end,
	chess_set = function(add)
		add("Top", Vector3.new(3, 0.3, 3), CFrame.new(0, 2.4, 0), DARK_WOOD, M.Wood, { Use = true })
		add("Leg", Vector3.new(0.6, 2.3, 0.6), CFrame.new(0, 1.15, 0), DARK_WOOD, M.Wood)
		for i = 0, 3 do
			for j = 0, 3 do
				add("Cell", Vector3.new(0.6, 0.05, 0.6), CFrame.new(-0.9 + i * 0.6, 2.58, -0.9 + j * 0.6), (i + j) % 2 == 0 and WHITE or BLACK, M.SmoothPlastic, { NoCollide = true })
			end
		end
		add("King", Vector3.new(0.25, 0.5, 0.25), CFrame.new(0.3, 2.85, 0.3), WHITE, M.SmoothPlastic, { NoCollide = true })
		add("Queen", Vector3.new(0.25, 0.45, 0.25), CFrame.new(-0.3, 2.83, -0.3), BLACK, M.SmoothPlastic, { NoCollide = true })
	end,
	guitar_stand = function(add)
		add("Stand", Vector3.new(1.6, 0.2, 1.6), CFrame.new(0, 0.1, 0), BLACK, M.Metal)
		add("Body", Vector3.new(0.5, 1.8, 1.8), CFrame.new(0, 1.3, 0) * CFrame.Angles(0, math.rad(90), math.rad(90)), rgb(190, 110, 50), M.Wood, { Shape = Enum.PartType.Cylinder, Use = true })
		add("Upper", Vector3.new(0.5, 1.3, 1.3), CFrame.new(0, 2.3, 0) * CFrame.Angles(0, math.rad(90), math.rad(90)), rgb(190, 110, 50), M.Wood, { Shape = Enum.PartType.Cylinder, NoCollide = true })
		add("Neck", Vector3.new(0.3, 2, 0.2), CFrame.new(0, 3.7, 0), DARK_WOOD, M.Wood, { NoCollide = true })
		add("Head", Vector3.new(0.4, 0.6, 0.2), CFrame.new(0, 4.9, 0), BLACK, M.Wood, { NoCollide = true })
	end,
	home_gym = function(add)
		add("Bench", Vector3.new(4, 0.5, 1.2), CFrame.new(0, 1.4, 0.6), BLACK, M.Fabric, { Use = true })
		add("BenchLeg", Vector3.new(3.6, 1.2, 0.4), CFrame.new(0, 0.6, 0.6), METAL, M.Metal)
		for _, x in { -2.4, 2.4 } do
			add("Post", Vector3.new(0.3, 4, 0.3), CFrame.new(x, 2, -0.8), METAL, M.Metal)
			add("Plate", Vector3.new(0.3, 1.6, 1.6), CFrame.new(x * 1.12, 3.4, -0.8) * CFrame.Angles(0, 0, 0), BLACK, M.Metal, { NoCollide = true, Shape = Enum.PartType.Cylinder })
		end
		add("Bar", Vector3.new(6, 0.2, 0.2), CFrame.new(0, 3.4, -0.8), METAL, M.Metal, { NoCollide = true })
	end,
	treadmill = function(add)
		add("Base", Vector3.new(3, 0.6, 6), CFrame.new(0, 0.3, 0), rgb(50, 50, 55), M.Metal, { Use = true })
		add("Belt", Vector3.new(2.4, 0.1, 5.2), CFrame.new(0, 0.65, 0.3), BLACK, M.Fabric)
		for _, x in { -1.3, 1.3 } do
			add("Upright", Vector3.new(0.25, 3.8, 0.25), CFrame.new(x, 2.4, -2.6), METAL, M.Metal)
		end
		add("Console", Vector3.new(3, 0.8, 0.6), CFrame.new(0, 4.2, -2.6), BLACK, M.SmoothPlastic)
		add("Display", Vector3.new(1.4, 0.4, 0.05), CFrame.new(0, 4.25, -2.28), rgb(60, 220, 120), M.Neon, { NoCollide = true })
	end,
	plant = function(add)
		add("Pot", Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(190, 110, 70), M.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
		add("Stem", Vector3.new(0.25, 2, 0.25), CFrame.new(0, 2.4, 0), DARK_WOOD, M.Wood, { NoCollide = true })
		for i, off in { Vector3.new(0, 3.8, 0), Vector3.new(0.5, 3.2, 0.3), Vector3.new(-0.5, 3.3, -0.3), Vector3.new(0, 4.4, 0.2) } do
			add("Leaves", Vector3.new(1.6, 1.6, 1.6) * (i == 1 and 1.2 or 0.9), CFrame.new(off), rgb(60, 140 + i * 8, 70), M.Grass, { NoCollide = true, Shape = Enum.PartType.Ball })
		end
	end,
	painting = function(add)
		add("Frame", Vector3.new(4, 3, 0.2), CFrame.new(0, 5, -0.2), GOLD, M.Wood, { NoCollide = true })
		add("Canvas", Vector3.new(3.6, 2.6, 0.05), CFrame.new(0, 5, -0.08), rgb(120, 180, 220), M.SmoothPlastic, { NoCollide = true })
		add("Hill", Vector3.new(3.6, 1, 0.06), CFrame.new(0, 4.2, -0.07), rgb(90, 150, 80), M.SmoothPlastic, { NoCollide = true })
		add("Sun", Vector3.new(0.07, 0.7, 0.7), CFrame.new(1, 5.7, -0.06) * CFrame.Angles(0, math.rad(90), 0), rgb(255, 210, 80), M.SmoothPlastic, { NoCollide = true, Shape = Enum.PartType.Cylinder })
	end,
	aquarium = function(add)
		add("Stand", Vector3.new(5, 2.2, 2), CFrame.new(0, 1.1, 0), BLACK, M.Wood)
		add("Tank", Vector3.new(5, 2.6, 2), CFrame.new(0, 3.5, 0), rgb(180, 220, 240), M.Glass, { Transparency = 0.6 })
		add("Water", Vector3.new(4.8, 2.2, 1.8), CFrame.new(0, 3.4, 0), rgb(40, 150, 220), M.Neon, { NoCollide = true, Transparency = 0.7, Light = { Range = 10, Color = rgb(80, 170, 255) } })
		local fish = { rgb(255, 140, 30), rgb(255, 220, 40), rgb(240, 70, 70) }
		for i = 1, 3 do
			add("Fish", Vector3.new(0.5, 0.3, 0.15), CFrame.new(-1.5 + i * 0.8, 3 + (i % 2) * 0.6, 0.2 - i * 0.15), fish[i], M.SmoothPlastic, { NoCollide = true })
		end
		add("Lid", Vector3.new(5.1, 0.2, 2.1), CFrame.new(0, 4.9, 0), BLACK, M.SmoothPlastic)
	end,
	clock = function(add)
		add("Body", Vector3.new(1.8, 7, 1.5), CFrame.new(0, 3.5, 0), DARK_WOOD, M.Wood)
		add("Face", Vector3.new(0.1, 1.4, 1.4), CFrame.new(0, 5.8, 0.76) * CFrame.Angles(0, math.rad(90), 0), WHITE, M.SmoothPlastic, { NoCollide = true, Shape = Enum.PartType.Cylinder })
		add("Glass", Vector3.new(1.2, 3, 0.05), CFrame.new(0, 2.8, 0.76), rgb(200, 220, 230), M.Glass, { NoCollide = true, Transparency = 0.5 })
		add("Pendulum", Vector3.new(0.5, 0.5, 0.1), CFrame.new(0, 2.3, 0.6), GOLD, M.Metal, { NoCollide = true })
	end,
	flowers = function(add)
		add("Bed", Vector3.new(8, 0.8, 3), CFrame.new(0, 0.4, 0), rgb(95, 65, 45), M.Ground)
		local colors = { rgb(240, 80, 120), rgb(255, 220, 60), rgb(180, 90, 230), rgb(255, 255, 255), rgb(255, 120, 40) }
		for i = 1, 5 do
			add("Flower", Vector3.new(1.4, 1.4, 1.4), CFrame.new(-3.6 + i * 1.2, 1.2, (i % 2 == 0) and 0.5 or -0.5), colors[i], M.SmoothPlastic, { NoCollide = true, Shape = Enum.PartType.Ball })
		end
	end,
	bench_garden = function(add)
		add("Seat", Vector3.new(6, 0.4, 1.8), CFrame.new(0, 1.6, 0.2), WOOD, M.WoodPlanks, { Seat = true })
		add("Back", Vector3.new(6, 1.6, 0.3), CFrame.new(0, 2.6, -0.85), WOOD, M.WoodPlanks)
		for _, x in { -2.6, 2.6 } do
			add("Leg", Vector3.new(0.4, 1.4, 2), CFrame.new(x, 0.7, 0), BLACK, M.Metal)
		end
	end,
	grill = function(add)
		for _, x in { -1.6, 1.6 } do
			add("Leg", Vector3.new(0.2, 1.8, 1.6), CFrame.new(x, 0.9, 0), BLACK, M.Metal)
		end
		add("Box", Vector3.new(3.6, 0.9, 1.8), CFrame.new(0, 2.2, 0), BLACK, M.Metal, { Use = true })
		add("Coals", Vector3.new(3.2, 0.1, 1.4), CFrame.new(0, 2.7, 0), rgb(255, 110, 30), M.Neon, { NoCollide = true, Light = { Range = 10, Color = rgb(255, 130, 60) } })
		for i = -1, 1 do
			add("Skewer", Vector3.new(0.1, 0.1, 2.2), CFrame.new(i * 0.9, 2.85, 0), METAL, M.Metal, { NoCollide = true })
			add("Meat", Vector3.new(0.35, 0.35, 1.2), CFrame.new(i * 0.9, 2.95, 0), rgb(150, 70, 40), M.SmoothPlastic, { NoCollide = true })
		end
	end,
	swing = function(add)
		for _, x in { -2.8, 2.8 } do
			for _, z in { -1.2, 1.2 } do
				add("Post", Vector3.new(0.35, 7.2, 0.35), CFrame.new(x, 3.6, z * 0.6) * CFrame.Angles(math.rad(z > 0 and -9 or 9), 0, 0), WOOD, M.Wood)
			end
		end
		add("Beam", Vector3.new(6, 0.4, 0.4), CFrame.new(0, 7.1, 0), WOOD, M.Wood)
		for _, x in { -1.8, 1.8 } do
			add("Rope", Vector3.new(0.12, 5, 0.12), CFrame.new(x, 4.5, 0), rgb(220, 210, 180), M.Fabric, { NoCollide = true })
		end
		add("Seat", Vector3.new(4, 0.4, 1.6), CFrame.new(0, 1.9, 0), WOOD, M.WoodPlanks, { Seat = true })
	end,
	trampoline = function(add)
		add("Frame", Vector3.new(0.4, 7, 7), CFrame.new(0, 2.2, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(40, 110, 200), M.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
		add("Mat", Vector3.new(0.12, 6.2, 6.2), CFrame.new(0, 2.45, 0) * CFrame.Angles(0, 0, math.rad(90)), BLACK, M.Fabric, { Shape = Enum.PartType.Cylinder, Use = true })
		for _, a in { 45, 135, 225, 315 } do
			local r = math.rad(a)
			add("Leg", Vector3.new(0.3, 2, 0.3), CFrame.new(math.cos(r) * 3, 1, math.sin(r) * 3), METAL, M.Metal, { NoCollide = true })
		end
	end,
	garden_bed = function(add)
		add("Soil", Vector3.new(6, 0.6, 3), CFrame.new(0, 0.3, 0), rgb(80, 55, 35), M.Ground, { Use = true })
		for i = 0, 4 do
			for _, z in { -0.7, 0.7 } do
				add("Plant", Vector3.new(0.8, 0.8, 0.8), CFrame.new(-2.2 + i * 1.1, 0.95, z), rgb(70, 150, 60), M.Grass, { NoCollide = true, Shape = Enum.PartType.Ball })
				if i % 2 == 0 then
					add("Tomato", Vector3.new(0.35, 0.35, 0.35), CFrame.new(-2.0 + i * 1.1, 1.1, z + 0.2), rgb(220, 40, 30), M.SmoothPlastic, { NoCollide = true, Shape = Enum.PartType.Ball })
				end
			end
		end
	end,
	gnome = function(add)
		add("Body", Vector3.new(0.9, 0.9, 0.7), CFrame.new(0, 0.45, 0), rgb(50, 90, 170), M.SmoothPlastic)
		add("Head", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 1.15, 0), rgb(240, 200, 170), M.SmoothPlastic, { NoCollide = true, Shape = Enum.PartType.Ball })
		add("Beard", Vector3.new(0.6, 0.5, 0.2), CFrame.new(0, 0.95, 0.3), WHITE, M.SmoothPlastic, { NoCollide = true })
		add("Hat", Vector3.new(0.6, 0.8, 0.6), CFrame.new(0, 1.75, 0), rgb(220, 40, 40), M.SmoothPlastic, { NoCollide = true })
	end,
	lantern = function(add)
		add("Pole", Vector3.new(0.3, 5, 0.3), CFrame.new(0, 2.5, 0), BLACK, M.Metal)
		add("Lamp", Vector3.new(0.9, 1, 0.9), CFrame.new(0, 5.4, 0), rgb(255, 230, 170), M.Neon, { NoCollide = true, Light = { Range = 18, Color = rgb(255, 215, 150) } })
		add("Cap", Vector3.new(1.2, 0.2, 1.2), CFrame.new(0, 6, 0), BLACK, M.Metal, { NoCollide = true })
	end,
	piano = function(add)
		add("Body", Vector3.new(5, 1.6, 5.5), CFrame.new(0, 3.2, -0.7), BLACK, M.SmoothPlastic, { Use = true })
		add("Lid", Vector3.new(4.8, 0.15, 4.5), CFrame.new(0, 4.6, -1.3) * CFrame.Angles(math.rad(-25), 0, 0), BLACK, M.SmoothPlastic, { NoCollide = true })
		add("Keys", Vector3.new(4.6, 0.25, 1), CFrame.new(0, 3, 2.4), WHITE, M.SmoothPlastic, { NoCollide = true })
		for i = 0, 8 do
			add("BlackKey", Vector3.new(0.18, 0.15, 0.55), CFrame.new(-2 + i * 0.5, 3.18, 2.2), BLACK, M.SmoothPlastic, { NoCollide = true })
		end
		for _, p in { Vector3.new(-2.1, 1.2, 1.6), Vector3.new(2.1, 1.2, 1.6), Vector3.new(0, 1.2, -3) } do
			add("Leg", Vector3.new(0.4, 2.4, 0.4), CFrame.new(p), BLACK, M.SmoothPlastic)
		end
	end,
	arcade = function(add)
		add("Cabinet", Vector3.new(3, 6, 2.4), CFrame.new(0, 3, -0.3), rgb(110, 40, 170), M.SmoothPlastic, { Use = true })
		add("Screen", Vector3.new(2.4, 1.8, 0.1), CFrame.new(0, 4.3, 0.92) * CFrame.Angles(math.rad(-10), 0, 0), rgb(40, 220, 160), M.Neon, { NoCollide = true, Light = { Range = 8, Color = rgb(90, 220, 200) } })
		add("Panel", Vector3.new(3, 0.4, 1.1), CFrame.new(0, 3, 1.1), BLACK, M.SmoothPlastic)
		add("Marquee", Vector3.new(3, 0.6, 0.1), CFrame.new(0, 5.65, 0.92), rgb(255, 200, 40), M.Neon, { NoCollide = true })
		for i, c in { rgb(255, 50, 50), rgb(60, 140, 255), rgb(255, 220, 40) } do
			add("Button", Vector3.new(0.25, 0.15, 0.25), CFrame.new(0.2 + i * 0.4, 3.25, 1.2), c, M.Neon, { NoCollide = true })
		end
	end,
	home_cinema = function(add)
		add("Frame", Vector3.new(8, 4.8, 0.3), CFrame.new(0, 5, -0.4), BLACK, M.SmoothPlastic, { Use = true })
		add("Display", Vector3.new(7.6, 4.4, 0.05), CFrame.new(0, 5, -0.23), rgb(60, 70, 140), M.Neon, { NoCollide = true, Light = { Range = 14, Color = rgb(120, 140, 255) } })
		for _, x in { -4.4, 4.4 } do
			add("Speaker", Vector3.new(1.2, 6, 1.2), CFrame.new(x, 3, 0), BLACK, M.SmoothPlastic)
			add("Cone", Vector3.new(0.1, 0.8, 0.8), CFrame.new(x, 4.6, 0.61) * CFrame.Angles(0, math.rad(90), 0), METAL, M.Metal, { NoCollide = true, Shape = Enum.PartType.Cylinder })
		end
		add("Soundbar", Vector3.new(6, 0.5, 0.6), CFrame.new(0, 2.2, 0), BLACK, M.SmoothPlastic)
	end,
	hot_tub = function(add)
		add("Tub", Vector3.new(8, 2.6, 8), CFrame.new(0, 1.3, 0), rgb(140, 95, 60), M.WoodPlanks)
		add("Water", Vector3.new(7, 0.3, 7), CFrame.new(0, 2.5, 0), rgb(80, 220, 230), M.Neon, { NoCollide = true, Transparency = 0.35, Use = true, Light = { Range = 12, Color = rgb(90, 230, 240) } })
		add("Step", Vector3.new(3, 1, 1.2), CFrame.new(0, 0.5, 4.5), rgb(140, 95, 60), M.WoodPlanks)
	end,
	pool = function(add)
		add("Rim", Vector3.new(14, 1, 9), CFrame.new(0, 0.5, 0), rgb(235, 235, 230), M.Concrete)
		add("Water", Vector3.new(12.6, 0.3, 7.6), CFrame.new(0, 1.05, 0), rgb(60, 170, 235), M.Glass, { NoCollide = true, Transparency = 0.2, Use = true })
		for _, x in { 5.6, 6.2 } do
			add("Ladder", Vector3.new(0.15, 1.8, 0.15), CFrame.new(x, 1.5, 3.2), METAL, M.Metal, { NoCollide = true })
		end
		add("Float", Vector3.new(0.5, 2, 2), CFrame.new(-3, 1.3, -1) * CFrame.Angles(0, 0, math.rad(90)), rgb(255, 120, 60), M.SmoothPlastic, { NoCollide = true, Shape = Enum.PartType.Cylinder })
	end,
}

-- Строит модель вещи в точке cf (основание вещи). Деталь с Use = true
-- (или «хитбокс») — та, на которой висит подсказка «Использовать».
function Furniture.Build(id, cf)
	local item = H.Items[id]
	local build = GEOMETRY[id]
	if not item or not build then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = id
	local h = HEIGHT[id] or 4
	local hit = Instance.new("Part")
	hit.Name = "Hitbox"
	hit.Size = Vector3.new(item.Size[1], h, item.Size[2])
	hit.CFrame = cf * CFrame.new(0, h / 2, 0)
	hit.Transparency = 1
	hit.Anchored = true
	hit.CanCollide = false
	hit.CanTouch = false
	hit.Parent = model
	model.PrimaryPart = hit
	local usePart
	build(function(name, size, local_cf, color, material, opts)
		opts = opts or {}
		local p = Instance.new(opts.Seat and "Seat" or "Part")
		p.Name = name
		if opts.Shape then
			p.Shape = opts.Shape
		end
		p.Size = size
		p.CFrame = cf * local_cf
		p.Color = color
		p.Material = material or M.SmoothPlastic
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = not opts.NoCollide
		p.Transparency = opts.Transparency or 0
		if opts.Light then
			local l = Instance.new("PointLight")
			l.Range = opts.Light.Range or 12
			l.Color = opts.Light.Color or Color3.new(1, 1, 1)
			l.Brightness = opts.Light.Brightness or 1
			l.Parent = p
		end
		if opts.Use and not usePart then
			usePart = p
		end
		p.Parent = model
	end)
	return model, usePart or hit
end

function Furniture.ItemCFrame(base, entry)
	local item = H.Items[entry.Id]
	local y = item and H.FloorY[item.Zone == "out" and "Out" or "In"] or 1
	return base * CFrame.new(entry.X, y, entry.Z) * CFrame.Angles(0, (entry.R or 0) * math.pi / 2, 0)
end

-- Прямоугольник, занятый вещью: minX, maxX, minZ, maxZ.
function Furniture.Footprint(id, x, z, r)
	local item = H.Items[id]
	local w, d = item.Size[1], item.Size[2]
	if (r or 0) % 2 == 1 then
		w, d = d, w
	end
	return x - w / 2, x + w / 2, z - d / 2, z + d / 2
end

local function overlap(a1, a2, a3, a4, b)
	local e = 0.05
	return a1 < b[2] - e and a2 > b[1] + e and a3 < b[4] - e and a4 > b[3] + e
end

-- Можно ли поставить вещь id в (x, z) с поворотом r среди items
-- (skip — индекс вещи, которую переставляют). Возвращает ok, причина.
function Furniture.Check(items, id, x, z, r, skip)
	local item = H.Items[id]
	if not item then
		return false, "Нет такой вещи."
	end
	if type(x) ~= "number" or type(z) ~= "number" or x ~= x or z ~= z then
		return false, "Неверное место."
	end
	if r ~= 0 and r ~= 1 and r ~= 2 and r ~= 3 then
		return false, "Неверный поворот."
	end
	local zone = item.Zone == "out" and "Out" or "In"
	local x1, x2, z1, z2 = Furniture.Footprint(id, x, z, r)
	local area = H.Zones[zone]
	if x1 < area[1] - 0.01 or x2 > area[2] + 0.01 or z1 < area[3] - 0.01 or z2 > area[4] + 0.01 then
		return false, zone == "In" and "Эта вещь ставится только в доме." or "Эта вещь ставится только во дворе, внутри забора."
	end
	for _, b in H.Blocked[zone] do
		if overlap(x1, x2, z1, z2, b) then
			return false, zone == "In" and "Мешает кровать, душ, кухня или проход к двери." or "Здесь дом, крыльцо, дорожка или дерево."
		end
	end
	if not item.Flat then
		for i, other in items do
			local o = H.Items[other.Id]
			if i ~= skip and o and not o.Flat and (o.Zone == "out") == (item.Zone == "out") then
				local a1, a2, a3, a4 = Furniture.Footprint(other.Id, other.X, other.Z, other.R)
				if overlap(x1, x2, z1, z2, { a1, a2, a3, a4 }) then
					return false, "Место занято: «" .. o.Name .. "»."
				end
			end
		end
	end
	return true
end

-- Сумма уюта (0..100).
function Furniture.Comfort(items)
	local total = 0
	for _, e in items do
		local item = H.Items[e.Id]
		if item then
			total += item.Comfort or 0
		end
	end
	return math.min(100, total)
end

function Furniture.Snap(v)
	return math.floor(v * 2 + 0.5) / 2
end

return Furniture
