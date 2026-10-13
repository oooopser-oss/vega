-- Автотест миграции сохранений. Запуск: cd tests && lune run data
local H = require("./harness")
local place = H.place
local saved, fail = nil, false
local old = { Cash = 777, Bank = 5000, Inventory = { ring = 1 }, Cars = { sport = true }, HasHouse = true, Role = "Medic", Relations = { ["5"] = { Points = 80, Status = "married", Name = "Anna" } }, Partner = "5", Needs = { Hunger = 50 }, Stats = { TasksDone = 10 } }
local store = {
	GetAsync = function(_, key) if fail then error("api down") end return old end,
	UpdateAsync = function(_, key, fn) saved = fn(nil) end,
}
local services = { DataStoreService = { GetDataStore = function() return store end }, RunService = { IsStudio = function() return false end }, Players = { GetPlayers = function() return {} end } }
local gameObj = { GetService = function(_, n) return services[n] or H.wrap(place:GetService(n)) end, BindToClose = function() end }
local env, req = H.makeEnv(gameObj)
local DS = req(H.wrap(place:GetService("ServerScriptService")).Server.Services.DataService)
local attrs = {}
local p = { UserId = 9, Name = "Old", GetAttribute = function(_, k) return attrs[k] end, SetAttribute = function(_, k, v) attrs[k] = v end }
local d = DS.Load(p)
print("version", d.Version, "cash", d.Cash, "bank", d.Bank, "car", d.Cars.sport, "partner", d.Partner, "house", d.HasHouse, "bonusFlag", d.RegistrationBonusGiven, "questsDone", d.Stats.QuestsDone, "energy", d.Needs.Energy)
assert(d.Version == 2 and d.Cash == 777 and d.Cars.sport and d.Partner == "5" and d.Stats.TasksDone == 10 and d.Stats.QuestsDone == 0)
DS.Save(p)
assert(saved and saved.Cash == 777, "saved")
-- сбой загрузки: сохранение не должно перезаписать данные
DS.Release(p)
saved = nil
fail = true
local d2 = DS.Load(p)
DS.Save(p)
assert(saved == nil and DS.IsReadOnly(p), "must not overwrite on failed load")
print("MIGRATION OK, failed-load protection OK")
require("@lune/process").exit(0)
