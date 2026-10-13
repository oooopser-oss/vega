-- Автотест ежедневных заданий. Запуск: cd tests && lune run quests
local H = require("./harness")
local roblox = require("@lune/roblox")
local place = H.place
local attrs = {}
local player = { UserId = 1, Name = "T", DisplayName = "T", GetAttribute = function(_, k) return attrs[k] end, SetAttribute = function(_, k, v) attrs[k] = v end }
attrs.Role = "Police"; attrs.RoleChosen = true
local PlayersStub = { GetPlayers = function() return {} end, PlayerRemoving = H.signal() }
local services = { Players = PlayersStub }
local gameObj = { GetService = function(_, n) return services[n] or H.wrap(place:GetService(n)) end }
local env, req = H.makeEnv(gameObj)
local svc = H.wrap(place:GetService("ServerScriptService")).Server.Services
local Q = req(svc.QuestService)
local data = { Cars = {}, Bank = 0, Stats = { QuestsDone = 0 }, DailyStreak = 2 }
local sent, earned = {}, 0
Q.Init({
	Data = { Get = function() return data end, SyncMoney = function() end },
	Net = { On = function() end, Send = function(_, name, p) table.insert(sent, name) if name == "Earned" then earned += p.Amount end end, Notify = function() end },
	World = { GPS = { { Name = "Банк", Position = roblox.Vector3.new(0, 0, 0) } } },
	WorldBuilder = { Meta = { Scale = 1.4 } },
})
Q.Send(player)
for _, q in data.Quests.List do print("quest", q.Kind, q.Goal, q.Reward) end
assert(#data.Quests.List == 3, "need 3 quests")
local hasRole = false
for _, q in data.Quests.List do if q.Kind == "arrest" then hasRole = true end end
assert(hasRole, "police should get arrest quest")
for _, q in data.Quests.List do Q.Progress(player, q.Kind, q.Goal) end
print("bank", data.Bank, "earned", earned, "bonus", data.Quests.Bonus, "done", attrs.QuestsDone, attrs.QuestsTotal)
assert(data.Quests.Bonus and data.Bank > 1500)
-- новый день
data.Quests.Day -= 1
Q.Send(player)
assert(not data.Quests.Bonus and data.Quests.List[1].Progress == 0, "reset")
print("QUESTS OK")

require("@lune/process").exit(0)
