-- Автотест: сервер + сборка всех машин. Запуск: cd tests && lune run server
local H = require("./harness")
local place = H.place
local function stub() return setmetatable({}, { __index = function(t, k)
	if k:match("^%u") and (k:match("ed$") or k:match("ing$") or k == "Heartbeat") then local s = H.signal() rawset(t, k, s) return s end
	return function() return nil end
end }) end
local PlayersStub = stub()
PlayersStub.GetPlayers = function() return {} end
PlayersStub.RespawnTime = 5
local services = {
	Players = PlayersStub,
	DataStoreService = { GetDataStore = function() return { GetAsync = function() return nil end, SetAsync = function() end } end },
	RunService = { IsStudio = function() return false end },
	MarketplaceService = setmetatable({}, { __index = function(t, k) local sg = H.signal() rawset(t, k, sg) return sg end }),
}
local gameObj = setmetatable({ GetService = function(_, n) return services[n] or H.wrap(place:GetService(n)) end, BindToClose = function() end }, {})
local env, req = H.makeEnv(gameObj)
local main = H.wrap(place:GetService("ServerScriptService")).Server.Main
H.run(main, env)
print("SERVER INIT OK")
-- Сборка машины: вызываем приватную функцию через патч исходника.
local vs = H.unwrap(H.wrap(place:GetService("ServerScriptService")).Server.Services.VehicleService)
vs.Source = vs.Source:gsub("local function buildCar", "function VehicleService._buildCar")
local env2, req2 = H.makeEnv(gameObj)
local VS = req2(H.wrap(vs))
local roblox = require("@lune/roblox")
local fakeOwner = { UserId = 1, Name = "Tester", DisplayName = "Tester" }
VS.Init({ WorldBuilder = req2(H.wrap(place:GetService("ServerScriptService")).Server.Services.WorldBuilder), World = { CarFolder = H.wrap(roblox.Instance.new("Folder")), Dealership = H.wrap(roblox.Instance.new("Part")), PoliceCarKiosk = H.wrap(roblox.Instance.new("Part")) }, Net = { Send = function() end, Notify = function() end, On = function() end } })
for _, id in { "sedan", "suv", "sport", "police" } do
	local m = VS._buildCar(id, roblox.CFrame.new(0, 3, 0), fakeOwner)
	print("car", id, #m:GetChildren())
end
print("CARS OK")
require("@lune/process").exit(0)
