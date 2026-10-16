-- Модели машин городского потока (клиентские, без физики):
-- седаны, хэтчбеки, такси и автобусы. Двигаются через CFrame.

local TrafficCar = {}

local COLORS = {
	Color3.fromRGB(220, 220, 225), Color3.fromRGB(30, 30, 35), Color3.fromRGB(170, 30, 35),
	Color3.fromRGB(40, 70, 140), Color3.fromRGB(120, 125, 130), Color3.fromRGB(60, 100, 70),
	Color3.fromRGB(200, 170, 120), Color3.fromRGB(150, 150, 155), Color3.fromRGB(240, 240, 240),
}

local function add(car, name, size, offset, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = car.Model
	table.insert(car.List, p)
	table.insert(car.Offsets, offset)
	return p
end

-- Передняя часть машины — направление −Z (LookVector).
function TrafficCar.Build(seed)
	local rng = Random.new(seed or math.random(1, 1e6))
	local roll = rng:NextNumber()
	local kind = roll < 0.08 and "bus" or roll < 0.2 and "taxi" or roll < 0.55 and "hatch" or "sedan"
	local car = { Model = Instance.new("Model"), List = {}, Offsets = {}, Kind = kind }
	car.Model.Name = "TrafficCar"
	local glass = Color3.fromRGB(35, 45, 60)
	local dark = Color3.fromRGB(25, 25, 28)

	if kind == "bus" then
		local color = rng:NextNumber() < 0.5 and Color3.fromRGB(230, 200, 40) or Color3.fromRGB(240, 240, 240)
		add(car, "Body", Vector3.new(7, 7.5, 26), CFrame.new(0, 4.6, 0), color)
		add(car, "Windows", Vector3.new(7.1, 2.6, 22), CFrame.new(0, 5.8, 1), glass, Enum.Material.Glass)
		add(car, "Windshield", Vector3.new(6.4, 3.5, 0.2), CFrame.new(0, 5.2, -13.05), glass, Enum.Material.Glass)
		add(car, "Stripe", Vector3.new(7.1, 0.6, 26.1), CFrame.new(0, 3.2, 0), Color3.fromRGB(30, 90, 170))
		add(car, "Route", Vector3.new(4, 1, 0.2), CFrame.new(0, 7.6, -13.1), Color3.fromRGB(255, 160, 40), Enum.Material.Neon)
		for _, z in { -8.5, 8.5 } do
			for _, x in { -3.3, 3.3 } do
				add(car, "Wheel", Vector3.new(1.2, 3, 3), CFrame.new(x, 1.5, z), dark, nil, Enum.PartType.Cylinder)
			end
		end
		for _, x in { -2.6, 2.6 } do
			add(car, "Headlight", Vector3.new(1.2, 0.6, 0.2), CFrame.new(x, 2.2, -13.05), Color3.fromRGB(255, 250, 220), Enum.Material.Neon)
			add(car, "Taillight", Vector3.new(1.2, 0.8, 0.2), CFrame.new(x, 2.4, 13.05), Color3.fromRGB(200, 20, 20), Enum.Material.Neon)
		end
		car.Length, car.Speed = 26, 0.8
		return car
	end

	local color = kind == "taxi" and Color3.fromRGB(245, 200, 30) or COLORS[rng:NextInteger(1, #COLORS)]
	local len = kind == "hatch" and 10.5 or 12
	add(car, "Body", Vector3.new(6, 1.8, len), CFrame.new(0, 1.9, 0), color)
	add(car, "Bumper", Vector3.new(6.1, 0.6, 0.4), CFrame.new(0, 1.3, -len / 2 - 0.1), dark)
	add(car, "Bumper", Vector3.new(6.1, 0.6, 0.4), CFrame.new(0, 1.3, len / 2 + 0.1), dark)
	local cabinLen = kind == "hatch" and 6 or 5.5
	local cabinZ = kind == "hatch" and 1.4 or 0.6
	add(car, "Cabin", Vector3.new(5.4, 1.7, cabinLen), CFrame.new(0, 3.65, cabinZ), glass, Enum.Material.Glass)
	add(car, "Roof", Vector3.new(5.5, 0.3, cabinLen - 0.6), CFrame.new(0, 4.6, cabinZ), color)
	for _, z in { -len / 2 + 2.2, len / 2 - 2.2 } do
		for _, x in { -2.9, 2.9 } do
			add(car, "Wheel", Vector3.new(0.9, 2.4, 2.4), CFrame.new(x, 1.2, z), dark, nil, Enum.PartType.Cylinder)
		end
	end
	for _, x in { -2.1, 2.1 } do
		add(car, "Headlight", Vector3.new(1.3, 0.5, 0.2), CFrame.new(x, 2.2, -len / 2 - 0.05), Color3.fromRGB(255, 250, 220), Enum.Material.Neon)
		add(car, "Taillight", Vector3.new(1.3, 0.5, 0.2), CFrame.new(x, 2.2, len / 2 + 0.05), Color3.fromRGB(200, 20, 20), Enum.Material.Neon)
	end
	if kind == "taxi" then
		add(car, "TaxiSign", Vector3.new(2, 0.8, 1), CFrame.new(0, 5.15, cabinZ), Color3.fromRGB(255, 230, 120), Enum.Material.Neon)
		add(car, "Checker", Vector3.new(6.05, 0.4, len * 0.6), CFrame.new(0, 2.4, 0), Color3.fromRGB(20, 20, 20))
	end
	car.Length, car.Speed = len, 1
	return car
end

function TrafficCar.CFrames(car, root)
	local out = table.create(#car.List)
	for i, off in car.Offsets do
		out[i] = root * off
	end
	return out
end

return TrafficCar
