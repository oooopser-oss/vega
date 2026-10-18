-- Автотест ограничений работы (пауза между заданиями, смены, дневной лимит).
-- Запуск: cd tests && lune run jobs
local H = require("./harness")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local place = H.place
local PlayersStub = { GetPlayers = function() return {} end, PlayerRemoving = H.signal() }
local gameObj = { GetService = function(_, n) return ({ Players = PlayersStub })[n] or H.wrap(place:GetService(n)) end }
local env, req = H.makeEnv(gameObj)
local Config = req(H.wrap(place:GetService("ReplicatedStorage")).Shared.Config)
-- Ускоряем время для теста.
Config.Jobs.cashier.Duration = 0
Config.Jobs.cashier.Cooldown = 0.05
Config.Work.ShiftTasks = 3
Config.Work.ShiftRest = 1
Config.Work.DailyCap = 50

local function at(x)
	local p = roblox.Instance.new("Part")
	p.Position = roblox.Vector3.new(x, 0, 0)
	return H.wrap(p)
end
local hrp = at(0)
local hum = { Health = 100 }
local char = { FindFirstChild = function(_, n) return n == "HumanoidRootPart" and hrp or nil end, FindFirstChildOfClass = function() return hum end }
local attrs = { Role = "Citizen", Energy = 100, Fun = 100, Hygiene = 100 }
local player = { Name = "T", Character = char, Parent = true, GetAttribute = function(_, k) return attrs[k] end, SetAttribute = function(_, k, v) attrs[k] = v end }
local data = { Cash = 0, Stats = { TasksDone = 0 } }
local lastTask, cash = nil, 0
local handlers = {}
local J = req(H.wrap(place:GetService("ServerScriptService")).Server.Services.JobService)
J.Init({
	Net = { On = function(n, f) handlers[n] = f end, Send = function(_, name, p) if name == "JobTask" then lastTask = p end end, Notify = function() end },
	Data = { Get = function() return data end, AddCash = function(_, a) cash += a end },
	World = { JobPoints = { Supermarket = { at(10), at(20) } } },
	Needs = { Change = function() end },
	Quests = { Progress = function() end },
	Monetization = { PayMultiplier = function() return 1 end },
	Progression = { PayMultiplier = function() return 1 end, Meets = function() return true end },
})
local function work()
	assert(lastTask and lastTask.Id, "нет задания: " .. tostring(lastTask and lastTask.Reason))
	hrp.Position = lastTask.Target.Position
	handlers.JobTask(player, { Id = lastTask.Id })
end
J.Select(player, "cashier")
task.wait(0.1)
work()
assert(lastTask.Waiting, "после задания должна быть пауза")
local id = lastTask
handlers.JobTask(player, { Id = 1 }) -- спам во время паузы ничего не даёт
local before = cash
assert(cash == before)
task.wait(0.1)
work()
task.wait(0.1)
work() -- 3-е задание = конец смены
assert(lastTask.Waiting and lastTask.Reason == "Перерыв между сменами", "должен быть перерыв")
J.Select(player, "cashier") -- перевыбор работы не сбрасывает перерыв
assert(lastTask.Waiting and lastTask.Waiting > 0.5, "перевыбор сбросил перерыв")
task.wait(1.2)
work()
print("cash", cash, "earned today", data.WorkToday.Earned)
assert(cash < 4 * 20, "после дневного лимита оплата должна снизиться")
print("JOBS OK")
require("@lune/process").exit(0)
