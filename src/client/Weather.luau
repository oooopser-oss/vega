-- Осадки и молнии на клиенте: дождь/снег идут вокруг камеры (под крышей
-- выключаются), в грозу — вспышки молний. Тип погоды задаёт сервер
-- атрибутом workspace.Weather.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Weather = {}

local W = Config.Weather
local emitterPart, rain, snow, flash
local rainSound, thunderSound
local nextLightning = 0
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function makeEmitters()
	emitterPart = Instance.new("Part")
	emitterPart.Name = "WeatherEmitter"
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(140, 1, 140)
	emitterPart.Parent = workspace

	rain = Instance.new("ParticleEmitter")
	rain.Name = "Rain"
	rain.Texture = "rbxasset://textures/particles/smoke_main.dds"
	rain.Color = ColorSequence.new(Color3.fromRGB(190, 205, 225))
	rain.LightEmission = 0.2
	rain.Transparency = NumberSequence.new(0.35)
	rain.Size = NumberSequence.new(0.12)
	rain.Squash = NumberSequence.new(2.8) -- вытягивает частицу в «струйку»
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Speed = NumberRange.new(90, 110)
	rain.Lifetime = NumberRange.new(0.6, 0.8)
	rain.Acceleration = Vector3.new(4, 0, 2)
	rain.Rate = 0
	rain.Enabled = false
	rain.Parent = emitterPart

	snow = Instance.new("ParticleEmitter")
	snow.Name = "Snow"
	snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	snow.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	snow.LightEmission = 0.3
	snow.Transparency = NumberSequence.new(0.1)
	snow.Size = NumberSequence.new(0.35, 0.5)
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.Speed = NumberRange.new(6, 10)
	snow.SpreadAngle = Vector2.new(25, 25)
	snow.Lifetime = NumberRange.new(5, 7)
	snow.Acceleration = Vector3.new(1.5, -1, 0.8)
	snow.RotSpeed = NumberRange.new(-60, 60)
	snow.Rate = 0
	snow.Enabled = false
	snow.Parent = emitterPart

	flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "LightningFlash"
	flash.Brightness = 0
	flash.Parent = Lighting

	if W.Sounds.Rain ~= "" then
		rainSound = Instance.new("Sound")
		rainSound.SoundId = W.Sounds.Rain
		rainSound.Looped = true
		rainSound.Volume = 0
		rainSound.Parent = workspace
	end
	if W.Sounds.Thunder ~= "" then
		thunderSound = Instance.new("Sound")
		thunderSound.SoundId = W.Sounds.Thunder
		thunderSound.Volume = 0.8
		thunderSound.Parent = workspace
	end
end

local function lightning()
	flash.Brightness = 0.7
	TweenService:Create(flash, TweenInfo.new(0.35), { Brightness = 0 }):Play()
	task.delay(0.15, function()
		flash.Brightness = 0.45
		TweenService:Create(flash, TweenInfo.new(0.5), { Brightness = 0 }):Play()
	end)
	if thunderSound then
		task.delay(math.random() * 2 + 0.5, function()
			thunderSound:Play()
		end)
	end
end

-- Текущая погода (ключ из Config.Weather.Types).
function Weather.Current()
	return workspace:GetAttribute("Weather") or "Clear"
end

-- Строка для HUD: «🌧 Дождь, 12°C • далее ☀ Ясно через 3 мин».
function Weather.Describe()
	local key = Weather.Current()
	local t = W.Types[key]
	if not t then
		return ""
	end
	local temp = workspace:GetAttribute("Temperature")
	local text = t.Icon .. " " .. t.Name .. (temp and string.format(", %+d°C", temp) or "")
	local nextKey = workspace:GetAttribute("WeatherNext")
	local nextAt = workspace:GetAttribute("WeatherNextAt")
	local nt = nextKey and W.Types[nextKey]
	if nt and nextAt then
		local ok, now = pcall(function()
			return workspace:GetServerTimeNow()
		end)
		local mins = math.max(1, math.ceil(((nextAt - (ok and now or 0))) / 60))
		text ..= " • далее " .. nt.Icon .. " " .. nt.Name .. " ~" .. mins .. " мин"
	end
	return text
end

function Weather.Start()
	makeEmitters()
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local key = Weather.Current()
		local t = W.Types[key] or W.Types.Clear
		local pos = cam.CFrame.Position
		emitterPart.CFrame = CFrame.new(pos + Vector3.new(0, 45, 0))
		acc += dt
		if acc >= 0.4 then
			acc = 0
			-- Под крышей (в здании, в машине под навесом) осадки не рисуем.
			local ignore = { emitterPart }
			local ambient = workspace:FindFirstChild("AmbientLife")
			if ambient then
				table.insert(ignore, ambient)
			end
			local char = game:GetService("Players").LocalPlayer.Character
			if char then
				table.insert(ignore, char)
			end
			rayParams.FilterDescendantsInstances = ignore
			local covered = workspace:Raycast(pos, Vector3.new(0, 60, 0), rayParams) ~= nil
			local raining = t.Precip == "rain" and not covered
			local snowing = t.Precip == "snow" and not covered
			rain.Enabled = raining
			rain.Rate = t.Heavy and 1400 or 800
			snow.Enabled = snowing
			snow.Rate = 450
			if rainSound then
				local want = t.Precip == "rain" and (covered and 0.15 or (t.Heavy and 0.6 or 0.4)) or 0
				if want > 0 and not rainSound.IsPlaying then
					rainSound:Play()
				end
				rainSound.Volume = want
			end
		end
		if t.Lightning and os.clock() > nextLightning then
			nextLightning = os.clock() + math.random(6, 16)
			lightning()
		end
	end)
end

return Weather
