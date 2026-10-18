-- Управление машиной на стороне водителя: W/S — газ/тормоз/задний ход,
-- A/D — поворот. Работает с LinearVelocity/AngularVelocity из VehicleService.

local Players = game:GetService("Players")
-- Сцепление с дорогой по погоде: скорость и разгон.
local GRIP = { Rain = 0.9, Storm = 0.85, Snow = 0.7, Fog = 0.95 }
local RunService = game:GetService("RunService")

local CarController = {}
CarController.Speed = 0
CarController.Driving = false

local function approach(current, target, step)
	if current < target then
		return math.min(current + step, target)
	end
	return math.max(current - step, target)
end

function CarController.Start()
	local player = Players.LocalPlayer
	local speed = 0

	RunService.Heartbeat:Connect(function(dt)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local seat = hum and hum.SeatPart
		if not (seat and seat:IsA("VehicleSeat") and seat:GetAttribute("LifeCar")) then
			speed = 0
			CarController.Driving = false
			CarController.Speed = 0
			return
		end
		local model = seat.Parent
		local root = model and model.PrimaryPart
		local lv = root and root:FindFirstChild("Drive")
		local av = root and root:FindFirstChild("Steer")
		if not lv or not av then
			return
		end
		CarController.Driving = true
		local grip = GRIP[workspace:GetAttribute("Weather") or "Clear"] or 1
		-- Навык «Вождение»: +3% к скорости за уровень.
		local skill = 1 + 0.03 * (player:GetAttribute("Skill_Driving") or 0)
		local maxSpeed = (model:GetAttribute("MaxSpeed") or 60) * grip * skill
		local throttle = seat.ThrottleFloat
		local steer = seat.SteerFloat

		local target = throttle * maxSpeed
		if throttle < 0 then
			target = throttle * maxSpeed * 0.35
		end
		local accel = 30
		if throttle == 0 then
			accel = 20
		elseif (throttle > 0 and speed < 0) or (throttle < 0 and speed > 0) then
			accel = 90 -- торможение
		end
		speed = approach(speed, target, accel * grip * dt)

		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.1 then
			return
		end
		flat = flat.Unit
		-- Если врезались — скорость падает до реальной.
		local actual = root.AssemblyLinearVelocity:Dot(flat)
		if math.abs(actual) < math.abs(speed) - 12 then
			speed = actual
		end

		lv.VectorVelocity = flat * speed
		local turnFactor = math.clamp(math.abs(speed) / 12, 0, 1)
		local dir = speed >= 0 and 1 or -1
		av.AngularVelocity = Vector3.new(0, -steer * 1.7 * turnFactor * dir, 0)
		CarController.Speed = math.abs(speed)
	end)
end

return CarController
