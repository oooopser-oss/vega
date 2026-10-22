-- Ежедневные задания: каждые сутки (по UTC) игрок получает новые задания,
-- прогресс сохраняется. За каждое — награда, за все — бонус дня.

local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Util = require(script.Parent.Util)

local QuestService = {}
local ctx

local Q = Config.Quests
local lastPos = {} -- [Player] = Vector3 (для задания «проехать на машине»)

local function today()
	return math.floor(os.time() / 86400)
end

local function gpsPosition(name)
	for _, place in ctx.World.GPS do
		if place.Name == name then
			return place.Position
		end
	end
	return nil
end

local function questText(q)
	local def = Q.Pool[q.Kind]
	if q.Kind == "visit" then
		return string.format(def.Text, q.Target or "?")
	end
	return string.format(def.Text, q.Goal)
end

local function generate(player, data)
	local role = player:GetAttribute("Role") or "Citizen"
	local roleKinds, common = {}, {}
	for kind, def in Q.Pool do
		if def.Role then
			if table.find(def.Role, role) then
				table.insert(roleKinds, kind)
			end
		elseif (kind ~= "drive" or next(data.Cars) ~= nil or Config.Roles[role].CanArrest) and (not def.NeedsHouse or data.HasHouse) then
			table.insert(common, kind)
		end
	end
	local chosen = {}
	if #roleKinds > 0 then
		table.insert(chosen, roleKinds[math.random(1, #roleKinds)])
	end
	while #chosen < Q.PerDay and #common > 0 do
		table.insert(chosen, table.remove(common, math.random(1, #common)))
	end
	local list = {}
	for _, kind in chosen do
		local def = Q.Pool[kind]
		local goal = def.Goals[math.random(1, #def.Goals)]
		local q = { Kind = kind, Goal = goal, Progress = 0, Done = false }
		q.Reward = math.floor(def.Reward * goal / 10 + 0.5) * 10
		if kind == "visit" then
			local places = ctx.World.GPS
			q.Target = places[math.random(1, #places)].Name
			q.Reward = def.Reward
		end
		q.Reward = math.max(q.Reward, 100)
		table.insert(list, q)
	end
	data.Quests = { Day = today(), List = list, Bonus = false }
end

local function ensure(player)
	local data = ctx.Data.Get(player)
	if not data then
		return nil
	end
	if not data.Quests or data.Quests.Day ~= today() then
		local wasOld = data.Quests ~= nil
		generate(player, data)
		if wasOld then
			ctx.Net.Notify(player, "📅 Новый день — новые задания! Откройте телефон → «Задания».", "info")
		end
	end
	return data
end

function QuestService.Send(player)
	local data = ensure(player)
	if not data then
		return
	end
	local list, done = {}, 0
	for _, q in data.Quests.List do
		table.insert(list, { Text = questText(q), Progress = q.Progress, Goal = q.Goal, Reward = q.Reward, Done = q.Done, Kind = q.Kind })
		if q.Done then
			done += 1
		end
	end
	player:SetAttribute("QuestsDone", done)
	player:SetAttribute("QuestsTotal", #list)
	ctx.Net.Send(player, "Quests", { List = list, Bonus = Q.AllDoneBonus, BonusTaken = data.Quests.Bonus, Streak = data.DailyStreak or 0 })
end

function QuestService.Progress(player, kind, amount)
	local data = ensure(player)
	if not data then
		return
	end
	local changed = false
	for _, q in data.Quests.List do
		if q.Kind == kind and not q.Done then
			q.Progress = math.min(q.Goal, q.Progress + (amount or 1))
			changed = true
			if q.Progress >= q.Goal then
				q.Done = true
				data.Bank += q.Reward
				data.Stats.QuestsDone = (data.Stats.QuestsDone or 0) + 1
				ctx.Data.SyncMoney(player)
				ctx.Net.Send(player, "Earned", { Amount = q.Reward, Text = "Задание выполнено: " .. questText(q) })
			end
		end
	end
	if not changed then
		return
	end
	local all = true
	for _, q in data.Quests.List do
		all = all and q.Done
	end
	if all and not data.Quests.Bonus then
		data.Quests.Bonus = true
		data.Bank += Q.AllDoneBonus
		ctx.Data.SyncMoney(player)
		ctx.Net.Send(player, "Toast", { Title = "Все задания дня выполнены!", Text = "Бонус +" .. Q.AllDoneBonus .. "$. Завтра будут новые задания." })
	end
	QuestService.Send(player)
end

function QuestService.Init(c)
	ctx = c
	ctx.Net.On("GetQuests", function(player)
		QuestService.Send(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastPos[player] = nil
	end)

	-- Проверка заданий «посетить место», «проехать на машине» и смены дня.
	task.spawn(function()
		local scale = (ctx.WorldBuilder.Meta and ctx.WorldBuilder.Meta.Scale) or 1
		while true do
			task.wait(2)
			for _, player in Players:GetPlayers() do
				local data = ctx.Data.Get(player)
				if data and data.Quests and player:GetAttribute("RoleChosen") then
					if data.Quests.Day ~= today() then
						QuestService.Send(player)
					end
					local pos = Util.Position(player)
					for _, q in data.Quests.List do
						if q.Kind == "visit" and not q.Done and pos then
							local target = gpsPosition(q.Target)
							if target and (pos - target).Magnitude < 40 then
								QuestService.Progress(player, "visit", 1)
							end
						end
					end
					local hum = Util.Humanoid(player)
					local seat = hum and hum.SeatPart
					if pos and seat and seat:IsA("VehicleSeat") then
						local prev = lastPos[player]
						if prev then
							local meters = (pos - prev).Magnitude / scale
							if meters > 2 and meters < 400 then
								QuestService.Progress(player, "drive", math.floor(meters))
							end
						end
						lastPos[player] = pos
					else
						lastPos[player] = nil
					end
				end
			end
		end
	end)
end

return QuestService
