-- Работы: игрок выбирает профессию, получает задания (подойти к месту,
-- выполнить действие, отнести груз) и получает зарплату за каждое задание.

local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Util = require(script.Parent.Util)

local JobService = {}
local ctx

local tasks = {} -- [Player] = { Id, Job, Stage, Target, Label, Hold, Issued }
local waiting = {} -- [Player] = { Token, Until } — пауза между заданиями
local shiftCount = {} -- [Player] = заданий в текущей смене
local nextAllowed = {} -- [Player] = os.clock(), раньше которого новое задание не выдаётся
local nextId = 0
local W = Config.Work

local function points(jobId)
	local job = Config.Jobs[jobId]
	local jp = ctx.World.JobPoints
	if job.Type == "courier" then
		local drops = {}
		for _, h in ctx.World.Houses do
			table.insert(drops, h.Doorstep)
		end
		return { jp.CourierDepot }, drops
	end
	local place = jp[job.Place]
	if job.Type == "delivery" then
		return place.Pickup, place.Drop
	end
	return place, nil
end

local function pick(list, avoid)
	if #list == 1 then
		return list[1]
	end
	local choice
	repeat
		choice = list[math.random(1, #list)]
	until choice ~= avoid
	return choice
end

function JobService.DropCarry(player)
	local char = player.Character
	local box = char and char:FindFirstChild("CarryBox")
	if box then
		box:Destroy()
	end
end

local function carry(player, color)
	JobService.DropCarry(player)
	local char = player.Character
	local hrp = Util.HRP(player)
	if not char or not hrp then
		return
	end
	local box = Instance.new("Part")
	box.Name = "CarryBox"
	box.Size = Vector3.new(2, 1.6, 1.6)
	box.Color = color
	box.Material = Enum.Material.WoodPlanks
	box.CanCollide = false
	box.Massless = true
	box.CFrame = hrp.CFrame * CFrame.new(0, 0.3, -1.6)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = box
	weld.Parent = box
	box.Parent = char
end

local function sendTask(player)
	local t = tasks[player]
	local w = waiting[player]
	if not t and w then
		ctx.Net.Send(player, "JobTask", { Waiting = math.max(0, w.Until - os.clock()), Reason = w.Reason })
		return
	end
	if not t then
		ctx.Net.Send(player, "JobTask", {})
		return
	end
	ctx.Net.Send(player, "JobTask", { Id = t.Id, Target = t.Target, Position = t.Target.Position, Label = t.Label, Hold = t.Hold, Job = t.Job })
end

function JobService.ResendTask(player)
	sendTask(player)
end

local function issue(player, stage, avoid)
	local jobId = player:GetAttribute("Job")
	local job = Config.Jobs[jobId]
	if not job then
		tasks[player] = nil
		sendTask(player)
		return
	end
	local a, b = points(jobId)
	nextId += 1
	local t = { Id = nextId, Job = jobId, Stage = stage, Issued = os.clock(), Hold = job.Duration }
	if stage == "drop" then
		t.Target = pick(b, avoid)
		t.Label = job.Drop
	elseif job.Type == "station" then
		t.Target = pick(a, avoid)
		t.Label = job.Action
	else
		t.Target = pick(a, avoid)
		t.Label = job.Pickup
	end
	tasks[player] = t
	sendTask(player)
end

-- Выдаёт следующее задание после паузы (новый покупатель, отдых после смены).
local function issueLater(player, delay, reason, avoid)
	if delay <= 0 then
		issue(player, "pickup", avoid)
		return
	end
	tasks[player] = nil
	local token = {}
	waiting[player] = { Token = token, Until = os.clock() + delay, Reason = reason }
	sendTask(player)
	local jobId = player:GetAttribute("Job")
	task.delay(delay, function()
		local w = waiting[player]
		if w and w.Token == token and player.Parent and player:GetAttribute("Job") == jobId then
			waiting[player] = nil
			issue(player, "pickup", avoid)
		end
	end)
end

function JobService.Quit(player, silent)
	if tasks[player] or waiting[player] or (player:GetAttribute("Job") or "") ~= "" then
		tasks[player] = nil
		waiting[player] = nil
		player:SetAttribute("Job", "")
		JobService.DropCarry(player)
		sendTask(player)
		if not silent then
			ctx.Net.Notify(player, "Вы ушли с работы.", "info")
		end
	end
end

function JobService.Select(player, jobId)
	local job = Config.Jobs[jobId]
	local role = Config.Roles[player:GetAttribute("Role") or "Citizen"]
	if not job or not role then
		return
	end
	if not table.find(role.Jobs, jobId) then
		ctx.Net.Notify(player, "Эта работа недоступна для вашей роли.", "bad")
		return
	end
	if (player:GetAttribute("Jailed") or 0) > 0 then
		ctx.Net.Notify(player, "Из тюрьмы на работу не ходят.", "bad")
		return
	end
	JobService.DropCarry(player)
	waiting[player] = nil
	player:SetAttribute("Job", jobId)
	ctx.Net.Notify(player, "Вы устроились: " .. job.Name .. ". Следуйте к отмеченной точке!", "good")
	-- Смена работы или перезаход не сбрасывают паузу и отдых между сменами.
	local data = ctx.Data.Get(player)
	local rest = data and data.WorkToday and (data.WorkToday.RestUntil or 0) - os.time() or 0
	local cooldown = (nextAllowed[player] or 0) - os.clock()
	if rest > 0 then
		issueLater(player, rest, "Перерыв между сменами")
	else
		issueLater(player, math.max(0, cooldown), job.WaitText or "Ожидайте")
	end
end

local function complete(player, t)
	local job = Config.Jobs[t.Job]
	local data = ctx.Data.Get(player)
	if not data then
		return
	end
	if job.Type ~= "station" and t.Stage == "pickup" then
		carry(player, t.Job == "cook" and Color3.fromRGB(240, 220, 180) or Color3.fromRGB(170, 130, 80))
		issue(player, "drop")
		return
	end
	JobService.DropCarry(player)
	local pay = math.floor(job.Pay * ctx.Monetization.PayMultiplier(player))
	local mood = ""
	if (player:GetAttribute("Fun") or 100) < 20 then
		pay = math.floor(pay * 0.8)
		mood = " (плохое настроение −20%)"
	end
	if (player:GetAttribute("Hygiene") or 100) < 20 then
		pay = math.floor(pay * 0.9)
		mood ..= " (неопрятный вид −10%)"
	end
	-- Дневной лимит: после него платят меньше.
	local day = math.floor(os.time() / 86400)
	if not data.WorkToday or data.WorkToday.Day ~= day then
		data.WorkToday = { Day = day, Earned = 0 }
	end
	if data.WorkToday.Earned >= W.DailyCap then
		pay = math.max(1, math.floor(pay * W.OverCapMultiplier))
		mood ..= " (дневной лимит " .. W.DailyCap .. "$ достигнут — оплата 25%)"
	end
	data.WorkToday.Earned += pay
	ctx.Data.AddCash(player, pay)
	data.Stats.TasksDone += 1
	ctx.Needs.Change(player, "Energy", -Config.WorkEnergyCost)
	ctx.Needs.Change(player, "Hunger", -0.5)
	ctx.Net.Send(player, "Earned", { Amount = pay, Text = job.Name .. mood })
	ctx.Quests.Progress(player, "work", 1)
	ctx.Quests.Progress(player, "earn", pay)
	shiftCount[player] = (shiftCount[player] or 0) + 1
	if shiftCount[player] >= W.ShiftTasks then
		shiftCount[player] = 0
		data.WorkToday.RestUntil = os.time() + W.ShiftRest
		ctx.Net.Notify(player, "Смена окончена! Отдохните " .. math.floor(W.ShiftRest / 60) .. " мин. — потом можно работать дальше.", "info")
		issueLater(player, W.ShiftRest, "Перерыв между сменами", t.Target)
	else
		nextAllowed[player] = os.clock() + (job.Cooldown or 0)
		issueLater(player, job.Cooldown or 0, job.WaitText or "Ожидайте", t.Target)
	end
end

function JobService.Init(c)
	ctx = c
	ctx.Net.On("SelectJob", function(player, p)
		if type(p.Job) == "string" then
			JobService.Select(player, p.Job)
		end
	end)
	ctx.Net.On("QuitJob", function(player)
		JobService.Quit(player)
	end)
	ctx.Net.On("JobTask", function(player, p)
		local t = tasks[player]
		if not t or p.Id ~= t.Id then
			return
		end
		if os.clock() - t.Issued < (t.Hold or 0) then
			return
		end
		if not Util.Alive(player) then
			return
		end
		if not Util.Near(player, t.Target, 16) then
			ctx.Net.Notify(player, "Подойдите ближе к месту работы.", "bad")
			return
		end
		if (player:GetAttribute("Energy") or 0) < 3 then
			ctx.Net.Notify(player, "Вы слишком устали! Выпейте кофе или поспите.", "bad")
			return
		end
		complete(player, t)
	end)
	Players.PlayerRemoving:Connect(function(player)
		tasks[player] = nil
		waiting[player] = nil
		shiftCount[player] = nil
		nextAllowed[player] = nil
	end)
end

return JobService
