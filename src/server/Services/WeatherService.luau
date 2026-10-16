-- Погода: смена ясно/облачно/дождь/гроза/туман/снег по сезону,
-- плавная перестройка облаков, тумана и освещения, снег на земле,
-- влияние на игроков (промокли — хуже настроение, мороз — меньше энергии),
-- зонт над головой.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Util = require(script.Parent.Util)

local WeatherService = {}
local ctx

local W = Config.Weather
local current
local snowSince -- os.clock() начала снегопада
local snowCover = false
local groundOriginal = {} -- [Part] = { Color, Material }
local shelterParams

local function season()
	return Config.Season(tonumber(os.date("!*t").month))
end

local function pickWeather(exclude)
	local weights = W.Seasons[season()].Weights
	local total = 0
	for key, w in weights do
		if key ~= exclude then
			total += w
		end
	end
	local roll = math.random() * total
	for key, w in weights do
		if key ~= exclude then
			roll -= w
			if roll <= 0 then
				return key
			end
		end
	end
	return "Clear"
end

local function temperature()
	local t = W.Types[current]
	local s = W.Seasons[season()]
	local temp = t.Temp + s.TempOffset
	local clock = Lighting.ClockTime
	if clock >= 21 or clock < 6 then
		temp += W.NightTempOffset
	end
	if current == "Snow" then
		temp = math.min(temp, -2)
	elseif t.Precip == "rain" then
		temp = math.max(temp, 2) -- дождь при морозе превратился бы в снег
	end
	return math.floor(temp + 0.5)
end

local function tween(obj, props)
	if obj then
		TweenService:Create(obj, TweenInfo.new(20, Enum.EasingStyle.Sine), props):Play()
	end
end

local function applyAtmosphere(t)
	tween(Lighting:FindFirstChildOfClass("Atmosphere"), { Density = t.Density, Haze = t.Haze })
	tween(workspace.Terrain:FindFirstChildOfClass("Clouds"), {
		Cover = t.Cloud,
		Density = math.clamp(t.Cloud + 0.1, 0, 1),
		Color = t.Precip and Color3.fromRGB(150, 155, 165) or Color3.fromRGB(255, 255, 255),
	})
	tween(Lighting, { Brightness = t.Brightness })
	tween(Lighting:FindFirstChildOfClass("ColorCorrectionEffect"), { Saturation = t.Saturation })
	tween(Lighting:FindFirstChildOfClass("SunRaysEffect"), { Intensity = t.Precip and 0 or 0.06 })
end

-- Снег на земле: после минуты снегопада земля белеет, без снега — тает.
local function setSnowCover(on)
	if snowCover == on then
		return
	end
	snowCover = on
	local city = workspace:FindFirstChild("City")
	local ground = city and city:FindFirstChild("Ground")
	if not ground then
		return
	end
	for _, p in ground:GetChildren() do
		if p:IsA("BasePart") and (p.Name == "Ground" or p.Name == "Park") then
			if on then
				groundOriginal[p] = { Color = p.Color, Material = p.Material }
				p.Material = Enum.Material.Snow
				tween(p, { Color = Color3.fromRGB(235, 240, 248) })
			elseif groundOriginal[p] then
				p.Material = groundOriginal[p].Material
				tween(p, { Color = groundOriginal[p].Color })
			end
		end
	end
	ctx.Net.NotifyAll(on and "❄ Город замело снегом!" or "Снег растаял.", "info")
end

function WeatherService.Set(key)
	if not W.Types[key] then
		return
	end
	current = key
	local t = W.Types[key]
	local duration = math.random(W.MinDuration, W.MaxDuration)
	local nextKey = pickWeather(key)
	workspace:SetAttribute("Weather", key)
	workspace:SetAttribute("WeatherNext", nextKey)
	workspace:SetAttribute("WeatherNextAt", workspace:GetServerTimeNow() + duration)
	workspace:SetAttribute("Season", season())
	workspace:SetAttribute("Temperature", temperature())
	applyAtmosphere(t)
	snowSince = key == "Snow" and os.clock() or nil
	ctx.Net.NotifyAll(t.Icon .. " " .. t.Message, "info")
	return duration, nextKey
end

function WeatherService.Current()
	return current
end

-- Есть ли крыша над головой (луч вверх).
local function sheltered(player, hrp)
	if not shelterParams then
		shelterParams = RaycastParams.new()
		shelterParams.FilterType = Enum.RaycastFilterType.Exclude
	end
	local ignore = { player.Character }
	local ambient = workspace:FindFirstChild("AmbientLife")
	if ambient then
		table.insert(ignore, ambient)
	end
	shelterParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(hrp.Position + Vector3.new(0, 3, 0), Vector3.new(0, 80, 0), shelterParams)
	return hit ~= nil
end

local function setUmbrella(player, on)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then
		return
	end
	local existing = char:FindFirstChild("WeatherUmbrella")
	if on and not existing then
		local model = Instance.new("Model")
		model.Name = "WeatherUmbrella"
		local canopy = Instance.new("Part")
		canopy.Name = "Canopy"
		canopy.Shape = Enum.PartType.Cylinder
		canopy.Size = Vector3.new(0.4, 6, 6)
		canopy.Color = Color3.fromRGB(180, 40, 60)
		canopy.Material = Enum.Material.Fabric
		canopy.CanCollide = false
		canopy.Massless = true
		canopy.CFrame = head.CFrame * CFrame.new(0.8, 2.6, 0) * CFrame.Angles(0, 0, math.rad(90))
		canopy.Parent = model
		local stick = Instance.new("Part")
		stick.Name = "Handle"
		stick.Size = Vector3.new(0.2, 3, 0.2)
		stick.Color = Color3.fromRGB(40, 40, 40)
		stick.CanCollide = false
		stick.Massless = true
		stick.CFrame = head.CFrame * CFrame.new(0.8, 1.2, 0)
		stick.Parent = model
		for _, p in { canopy, stick } do
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = p
			weld.Parent = p
		end
		model.Parent = char
	elseif not on and existing then
		existing:Destroy()
	end
end

local function tickPlayers()
	local t = W.Types[current]
	for _, player in Players:GetPlayers() do
		local hrp = Util.HRP(player)
		local hum = Util.Humanoid(player)
		if hrp and hum and hum.Health > 0 and player:GetAttribute("RoleChosen") then
			local exposed = false
			if t.Precip or t.Cold then
				local inVehicle = hum.SeatPart ~= nil
				exposed = not inVehicle and (player:GetAttribute("Jailed") or 0) <= 0 and not sheltered(player, hrp)
			end
			local hasUmbrella = ctx.Data.HasItem(player, "umbrella")
			setUmbrella(player, exposed and t.Precip ~= nil and hasUmbrella)
			local wet = exposed and t.Precip ~= nil and not hasUmbrella
			if wet then
				ctx.Needs.Change(player, "Fun", -W.WetFunLoss * (t.Heavy and 2 or 1))
			end
			local freezing = t.Cold or (workspace:GetAttribute("Temperature") or 0) <= -10
			if not exposed and freezing and not hum.SeatPart and (player:GetAttribute("Jailed") or 0) <= 0 then
				exposed = not sheltered(player, hrp)
			end
			if exposed and freezing then
				ctx.Needs.Change(player, "Energy", -W.ColdEnergyLoss)
			end
			if wet and not player:GetAttribute("Wet") then
				ctx.Net.Notify(player, "Вы промокли! Настроение падает. Купите зонт в супермаркете или зайдите под крышу.", "warn")
			end
			player:SetAttribute("Wet", wet)
			player:SetAttribute("Cold", exposed and freezing)
		end
	end
end

function WeatherService.Init(c)
	ctx = c
	math.randomseed(os.time())
	local duration = WeatherService.Set(pickWeather(nil))

	task.spawn(function()
		local untilChange = duration
		local acc = 0
		while true do
			local dt = task.wait(3)
			untilChange -= dt
			acc += dt
			if untilChange <= 0 then
				untilChange = WeatherService.Set(workspace:GetAttribute("WeatherNext") or pickWeather(current))
			end
			if acc >= 30 then
				acc = 0
				workspace:SetAttribute("Temperature", temperature())
			end
			if current == "Snow" and snowSince and os.clock() - snowSince > 60 then
				setSnowCover(true)
			elseif current ~= "Snow" and current ~= "Cloudy" and current ~= "Fog" then
				setSnowCover(false)
			end
			tickPlayers()
		end
	end)

	-- Для проверки в Studio: напишите в чат «/погода дождь» (или ясно, облачно, гроза, туман, снег).
	if RunService:IsStudio() then
		-- string.lower не работает с кириллицей, поэтому варианты перечислены явно.
		local names = {
			["ясно"] = "Clear", ["Ясно"] = "Clear", ["облачно"] = "Cloudy", ["Облачно"] = "Cloudy",
			["дождь"] = "Rain", ["Дождь"] = "Rain", ["гроза"] = "Storm", ["Гроза"] = "Storm",
			["туман"] = "Fog", ["Туман"] = "Fog", ["снег"] = "Snow", ["Снег"] = "Snow",
		}
		for key in W.Types do
			names[string.lower(key)] = key
		end
		local function hook(player)
			player.Chatted:Connect(function(msg)
				local arg = string.match(msg, "^/погода%s+(%S+)") or string.match(msg, "^/weather%s+(%S+)")
				if arg and (names[arg] or names[string.lower(arg)]) then
					arg = names[arg] and arg or string.lower(arg)
					WeatherService.Set(names[arg])
				end
			end)
		end
		Players.PlayerAdded:Connect(hook)
		for _, p in Players:GetPlayers() do
			hook(p)
		end
	end
end

return WeatherService
