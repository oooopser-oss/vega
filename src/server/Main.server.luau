-- Точка входа сервера «Жизнь Города».
-- Строит город и запускает все игровые системы.

local Lighting = game:GetService("Lighting")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Services = script.Parent:WaitForChild("Services")

local Net = require(Services.Net)
local WorldBuilder = require(Services.WorldBuilder)
local DataService = require(Services.DataService)

-- Игроки появятся только после постройки города (PlayerService вызывает LoadCharacter).
game:GetService("Players").CharacterAutoLoads = false

Net.Init()
local World = WorldBuilder.Build()
DataService.Init()

local ctx = {
	Net = Net,
	World = World,
	WorldBuilder = WorldBuilder,
	Data = DataService,
	Players = require(Services.PlayerService),
	Needs = require(Services.NeedsService),
	Economy = require(Services.EconomyService),
	Jobs = require(Services.JobService),
	Crime = require(Services.CrimeService),
	Tools = require(Services.ToolService),
	Housing = require(Services.HousingService),
	Social = require(Services.SocialService),
	Vehicles = require(Services.VehicleService),
	Monetization = require(Services.MonetizationService),
	Quests = require(Services.QuestService),
	Npcs = require(Services.NpcService),
	Weather = require(Services.WeatherService),
	Clothing = require(Services.ClothingService),
	Progression = require(Services.ProgressionService),
	Activities = require(Services.ActivityService),
	Football = require(Services.FootballService),
	Home = require(Services.HomeService),
}

for _, name in { "Needs", "Economy", "Jobs", "Crime", "Tools", "Housing", "Social", "Vehicles", "Monetization", "Quests", "Npcs", "Weather", "Clothing", "Progression", "Activities", "Football", "Home", "Players" } do
	ctx[name].Init(ctx)
end
ctx.Players.Start()

-- Смена дня и ночи.
task.spawn(function()
	local hoursPerSecond = 24 / (Config.DayLengthMinutes * 60)
	while true do
		local dt = task.wait(0.5)
		Lighting.ClockTime = (Lighting.ClockTime + dt * hoursPerSecond) % 24
		WorldBuilder.SetNight(Lighting.ClockTime >= 19 or Lighting.ClockTime < 6)
	end
end)

print("[" .. Config.GameName .. "] Сервер запущен.")
