-- Автотест занятий: урок (викторина) засчитывается, тренажёр даёт опыт,
-- слишком быстрый результат отклоняется, без удочки рыбачить нельзя.
-- Запуск: cd tests && lune run activities
local H = require("./harness")
local task = require("@lune/task")
local place = H.place
local PlayersStub = { GetPlayers = function() return {} end, PlayerRemoving = H.signal() }
local gameObj = { GetService = function(_, n) return ({ Players = PlayersStub })[n] or H.wrap(place:GetService(n)) end }
local env, req = H.makeEnv(gameObj)
local server = H.wrap(place:GetService("ServerScriptService")).Server
local Questions = req(server.Questions)
local Progression = req(server.Services.ProgressionService)
local Activities = req(server.Services.ActivityService)

local attrs = { Energy = 100 }
local player = { Name = "T", DisplayName = "T", UserId = 1, Parent = true, Character = nil,
	GetAttribute = function(_, k) return attrs[k] end, SetAttribute = function(_, k, v) attrs[k] = v end }
local data = { Cash = 1000, Bank = 0, Inventory = {}, Cars = {}, Stats = {} }
local notes, last = {}, {}
local handlers = {}
local prompts = {}
local function fakePart() return {} end
local ctx = {
	Data = { Get = function() return data end, Spend = function(_, a) if data.Cash >= a then data.Cash -= a return true end return false end,
		HasItem = function(_, i) return (data.Inventory[i] or 0) > 0 end, AddItem = function(_, i, n) data.Inventory[i] = (data.Inventory[i] or 0) + n end, AddCash = function(_, a) data.Cash += a end },
	Net = { On = function(n, f) handlers[n] = f end, Send = function(_, n, p) last[n] = p end, Notify = function(_, t) table.insert(notes, t) end, NotifyAll = function() end },
	Needs = { ApplyEffects = function() end, Change = function() end, UpdateSpeed = function() end },
	Quests = { Progress = function() end },
	Economy = { SendInventory = function() end },
	WorldBuilder = { MakePrompt = function() local pp = { Triggered = H.signal() } table.insert(prompts, pp) return pp end },
	World = { Activities = { { Part = fakePart(), Activity = "lesson", Text = "" }, { Part = fakePart(), Activity = "gym", Text = "" }, { Part = fakePart(), Activity = "fishing", Text = "" } } },
}
ctx.Progression = Progression
Progression.Init(ctx)
Activities.Init(ctx)
Progression.OnPlayerAdded(player)

-- 1) Урок: отвечаем правильно.
prompts[1].Triggered:Fire(player)
local mg = last.MiniGame
assert(mg and mg.Type == "quiz" and #mg.Params.Questions == 5, "урок выдан")
assert(mg.Params.Questions[1].A == nil, "ответы не уходят клиенту")
local answers = {}
for i, q in mg.Params.Questions do
	for _, bankQ in Questions.School do
		if bankQ.Q == q.Q then answers[i] = bankQ.A end
	end
end
task.wait(6)
handlers.MiniGameResult(player, { Id = mg.Id, Answers = answers })
assert(data.Education.School == 1, "урок засчитан: " .. tostring(data.Education.School))
assert((data.Skills.Intellect or 0) == 75, "опыт интеллекта: " .. tostring(data.Skills.Intellect))

-- 2) Тренажёр: слишком быстрый результат не засчитывается.
prompts[2].Triggered:Fire(player)
local gym = last.MiniGame
assert(gym.Type == "timing" and data.Cash == 985, "оплата тренировки")
handlers.MiniGameResult(player, { Id = gym.Id, Score = 6 })
assert((data.Skills.Strength or 0) == 0, "мгновенный результат отклонён")

-- 3) Рыбалка без удочки.
prompts[3].Triggered:Fire(player)
assert(string.find(notes[#notes], "Удочка"), "без удочки нельзя: " .. notes[#notes])
print("level", attrs.Level, "intellect lvl", attrs.Skill_Intellect)
print("ACTIVITIES OK")
require("@lune/process").exit(0)
