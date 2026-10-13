-- Машины: покупка в автосалоне, вызов своей машины на дорогу,
-- служебные патрульные машины. Управление — на клиенте (CarController).

local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Util = require(script.Parent.Util)

local VehicleService = {}
local ctx

local activeCars = {} -- [Player] = Model
local lastSpawn = {} -- [Player] = time

function VehicleService.SendCars(player)
	local data = ctx.Data.Get(player)
	if data then
		ctx.Net.Send(player, "Cars", { Owned = data.Cars })
	end
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function buildCar(carId, cf, owner)
	local def = Config.Cars[carId]
	local model = Instance.new("Model")
	model.Name = owner.Name .. "_" .. carId
	model:SetAttribute("Owner", owner.UserId)
	model:SetAttribute("CarId", carId)
	model:SetAttribute("MaxSpeed", def.Speed)

	local function add(name, size, offset, props)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf * offset
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		for k, v in props or {} do
			p[k] = v
		end
		p.Parent = model
		return p
	end

	local root = add("Root", Vector3.new(5.6, 0.6, 11), CFrame.new(0, 0.35, 0), {
		Transparency = 1,
		CustomPhysicalProperties = PhysicalProperties.new(3, 0, 0, 100, 1),
	})
	model.PrimaryPart = root

	local body = add("Body", Vector3.new(6.4, 1.8, 13), CFrame.new(0, 1.6, 0), { Color = def.Color, Material = Enum.Material.SmoothPlastic, CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.3, 0.2) })
	local cabin = add("Cabin", Vector3.new(5.8, 3.2, 6.5), CFrame.new(0, 4.1, 1), { Color = Color3.fromRGB(40, 50, 70), Material = Enum.Material.Glass, Transparency = 0.55, CanCollide = false, Massless = true })
	local roof = add("Roof", Vector3.new(6, 0.4, 6.7), CFrame.new(0, 5.9, 1), { Color = def.Color, Massless = true })
	weld(root, body)
	weld(root, cabin)
	weld(root, roof)

	for _, x in { -3.2, 3.2 } do
		for _, z in { -4.2, 4.2 } do
			local wheel = add("Wheel", Vector3.new(1, 2.6, 2.6), CFrame.new(x, 1.3, z), { Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(25, 25, 25), CanCollide = false, Massless = true })
			weld(root, wheel)
		end
	end
	for _, x in { -2.2, 2.2 } do
		weld(root, add("Headlight", Vector3.new(1.4, 0.6, 0.2), CFrame.new(x, 1.9, -6.55), { Color = Color3.fromRGB(255, 250, 220), Material = Enum.Material.Neon, CanCollide = false, Massless = true }))
		weld(root, add("Taillight", Vector3.new(1.4, 0.6, 0.2), CFrame.new(x, 1.9, 6.55), { Color = Color3.fromRGB(220, 20, 20), Material = Enum.Material.Neon, CanCollide = false, Massless = true }))
	end
	local lamp = model:FindFirstChild("Headlight")
	if lamp then
		local spot = Instance.new("SpotLight")
		spot.Range = 40
		spot.Angle = 60
		spot.Face = Enum.NormalId.Front
		spot.Brightness = 3
		spot.Parent = lamp
	end

	if def.Police then
		local red = add("LightRed", Vector3.new(2, 0.5, 1), CFrame.new(-1.2, 6.35, 1), { Color = Color3.fromRGB(255, 0, 0), Material = Enum.Material.Neon, CanCollide = false, Massless = true })
		local blue = add("LightBlue", Vector3.new(2, 0.5, 1), CFrame.new(1.2, 6.35, 1), { Color = Color3.fromRGB(0, 80, 255), Material = Enum.Material.Neon, CanCollide = false, Massless = true })
		weld(root, red)
		weld(root, blue)
		for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
			ctx.WorldBuilder.SurfaceText(body, face, "ПОЛИЦИЯ", Color3.fromRGB(240, 240, 255), Color3.fromRGB(20, 40, 160))
		end
		task.spawn(function()
			local on = true
			while model.Parent do
				red.Transparency = on and 0 or 0.8
				blue.Transparency = on and 0.8 or 0
				on = not on
				task.wait(0.4)
			end
		end)
	end

	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2, 0.6, 2)
	seat.CFrame = cf * CFrame.new(-1.3, 2.8, 1.5)
	seat.Transparency = 1
	seat.MaxSpeed = def.Speed
	seat.Torque = 0
	seat.Massless = true
	seat:SetAttribute("LifeCar", true)
	seat.Parent = model
	weld(root, seat)
	for i, pos in { Vector3.new(1.3, 2.8, 1.5), Vector3.new(-1.3, 2.8, 4), Vector3.new(1.3, 2.8, 4) } do
		local s = Instance.new("Seat")
		s.Name = "Passenger" .. i
		s.Size = Vector3.new(2, 0.6, 2)
		s.CFrame = cf * CFrame.new(pos)
		s.Transparency = 1
		s.Massless = true
		s.Parent = model
		weld(root, s)
	end

	-- Физика движения: клиент водителя меняет скорость этих ограничителей.
	local att = Instance.new("Attachment")
	att.Name = "DriveAttachment"
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Name = "Drive"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	lv.VectorVelocity = Vector3.zero
	lv.Parent = root
	local av = Instance.new("AngularVelocity")
	av.Name = "Steer"
	av.Attachment0 = att
	av.RelativeTo = Enum.ActuatorRelativeTo.World
	av.AngularVelocity = Vector3.zero
	av.Parent = root

	model.Parent = ctx.World.CarFolder
	local mass = root.AssemblyMass
	lv.MaxAxesForce = Vector3.new(mass * 120, 0, mass * 120)
	av.MaxTorque = mass * 400

	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local hum = seat.Occupant
		local driver = hum and Players:GetPlayerFromCharacter(hum.Parent)
		if driver then
			local allowed = driver == owner
			if not allowed and def.Police then
				allowed = ctx.Crime.IsLaw(driver)
			end
			if not allowed and not def.Police then
				local data = ctx.Data.Get(owner)
				allowed = data ~= nil and data.Partner == tostring(driver.UserId)
			end
			if not allowed and driver:GetAttribute("Role") == "Criminal" then
				allowed = true
				ctx.Crime.AddWanted(driver, def.Police and 3 or 1, "угон автомобиля")
				if owner.Parent then
					ctx.Net.Notify(owner, "🚨 Вашу машину угоняет " .. driver.DisplayName .. "!", "bad")
				end
			end
			if not allowed then
				task.defer(function()
					hum.Sit = false
					hum.Jump = true
				end)
				ctx.Net.Notify(driver, "Это чужая машина.", "bad")
				return
			end
			pcall(function()
				root:SetNetworkOwner(driver)
			end)
		else
			pcall(function()
				root:SetNetworkOwnershipAuto()
			end)
		end
	end)
	return model
end

function VehicleService.DespawnFor(player, silent)
	local car = activeCars[player]
	if car then
		activeCars[player] = nil
		car:Destroy()
		if not silent then
			ctx.Net.Notify(player, "Машина отправлена на парковку.", "info")
		end
	end
end

local function freeSpawnNear(pos)
	local best, bestDist = nil, math.huge
	for _, cf in ctx.World.CarSpawns do
		local d = (cf.Position - pos).Magnitude
		if d < bestDist then
			local blocked = false
			for _, car in ctx.World.CarFolder:GetChildren() do
				if car.PrimaryPart and (car.PrimaryPart.Position - cf.Position).Magnitude < 14 then
					blocked = true
					break
				end
			end
			if not blocked then
				best, bestDist = cf, d
			end
		end
	end
	return best
end

local function spawnCar(player, carId, cf)
	if lastSpawn[player] and os.clock() - lastSpawn[player] < 5 then
		ctx.Net.Notify(player, "Подождите пару секунд.", "info")
		return
	end
	lastSpawn[player] = os.clock()
	VehicleService.DespawnFor(player, true)
	local car = buildCar(carId, cf, player)
	activeCars[player] = car
	ctx.Net.Notify(player, Config.Cars[carId].Name .. " ждёт вас! Сядьте за руль (W/S — газ/тормоз, A/D — поворот).", "good")
	ctx.Net.Send(player, "Waypoint", { Name = "Моя машина", Position = cf.Position })
end

function VehicleService.Init(c)
	ctx = c
	local MakePrompt = ctx.WorldBuilder.MakePrompt
	local Net = ctx.Net

	MakePrompt(ctx.World.Dealership, "Каталог", "Автосалон", 0, 12).Triggered:Connect(function(player)
		Net.Send(player, "OpenDealer", {})
	end)

	MakePrompt(ctx.World.PoliceCarKiosk, "Взять патрульную машину", "Гараж", 0.5, 10).Triggered:Connect(function(player)
		if not ctx.Crime.IsLaw(player) then
			Net.Notify(player, "Только для сотрудников полиции и спецслужб.", "bad")
			return
		end
		spawnCar(player, "police", ctx.World.PoliceCarSpawn)
	end)

	Net.On("BuyCar", function(player, p)
		local def = Config.Cars[p.Car]
		local data = ctx.Data.Get(player)
		if not def or def.Hidden or def.Pass or not data then
			return
		end
		if data.Cars[p.Car] then
			Net.Notify(player, "У вас уже есть эта машина.", "info")
			return
		end
		if not Util.Near(player, ctx.World.Dealership, 25) then
			Net.Notify(player, "Покупка машин — в автосалоне.", "bad")
			return
		end
		if not ctx.Data.Spend(player, def.Price) then
			Net.Notify(player, "Недостаточно денег (" .. def.Price .. "$).", "bad")
			return
		end
		data.Cars[p.Car] = true
		Net.Notify(player, "Поздравляем с покупкой: " .. def.Name .. "! Вызвать машину можно в телефоне.", "good")
		VehicleService.SendCars(player)
	end)

	Net.On("SpawnCar", function(player, p)
		local data = ctx.Data.Get(player)
		local def = Config.Cars[p.Car]
		if not data or not def then
			return
		end
		local owned = data.Cars[p.Car] or (def.Pass and ctx.Monetization.HasPass(player, def.Pass))
		if not owned then
			if def.Pass then
				Net.Notify(player, "Эта машина доступна с пассом «" .. Config.Monetization.GamePasses[def.Pass].Name .. "».", "info")
			end
			return
		end
		if (player:GetAttribute("Jailed") or 0) > 0 then
			return
		end
		local pos = Util.Position(player)
		if not pos then
			return
		end
		local cf = freeSpawnNear(pos)
		if not cf then
			Net.Notify(player, "Нет свободного места на дороге.", "bad")
			return
		end
		spawnCar(player, p.Car, cf)
	end)

	Net.On("DespawnCar", function(player)
		VehicleService.DespawnFor(player, false)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastSpawn[player] = nil
	end)
end

return VehicleService
