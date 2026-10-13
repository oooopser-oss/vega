-- Преступность: уровень розыска (звёзды), ограбления, арест, тюрьма.

local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Util = require(script.Parent.Util)

local CrimeService = {}
local ctx

local lastCrime = {} -- [Player] = os.clock()
local lastAttacker = {} -- [victim] = { Player, Time }
local robberyCooldown = {} -- [spotId] = os.clock()
local cellIndex = {} -- [Player] = номер камеры

local function isLaw(player)
	local role = Config.Roles[player:GetAttribute("Role") or ""]
	return role ~= nil and role.CanArrest == true
end
CrimeService.IsLaw = isLaw

local function alertPolice(text, position)
	for _, p in Players:GetPlayers() do
		if isLaw(p) then
			ctx.Net.Send(p, "Alert", { Text = text, Position = position })
		end
	end
end
CrimeService.AlertPolice = alertPolice

function CrimeService.AddWanted(player, stars, reason)
	local before = player:GetAttribute("Wanted") or 0
	local after = math.clamp(before + stars, 0, 5)
	player:SetAttribute("Wanted", after)
	lastCrime[player] = os.clock()
	if after > before then
		ctx.Net.Notify(player, "Розыск повышен: " .. Util.Stars(after) .. " (" .. reason .. ")", "bad")
		alertPolice("🚨 " .. player.DisplayName .. " — " .. reason .. " " .. Util.Stars(after), Util.Position(player))
	end
	if isLaw(player) and after >= 2 then
		-- Полицейский-преступник лишается значка.
		ctx.Net.Notify(player, "Вы уволены из органов за преступления!", "bad")
		task.defer(ctx.Players.SetRole, player, "Citizen", true)
	end
end

function CrimeService.TagAttack(victim, attacker)
	lastAttacker[victim] = { Player = attacker, Time = os.clock() }
end

function CrimeService.CellFor(player)
	local cells = ctx.World.Jail.Cells
	local idx = cellIndex[player]
	if not idx then
		idx = math.random(1, #cells)
		cellIndex[player] = idx
	end
	return cells[idx]
end

local function release(player)
	player:SetAttribute("Jailed", 0)
	cellIndex[player] = nil
	if Util.Alive(player) then
		Util.Teleport(player, ctx.World.Jail.Exit)
		ctx.Tools.GiveRoleTools(player)
	end
	ctx.Net.Notify(player, "Вы освобождены. Ведите себя хорошо!", "good")
end

function CrimeService.Jail(player, seconds)
	ctx.Jobs.Quit(player, true)
	ctx.Needs.StopActivity(player)
	ctx.Vehicles.DespawnFor(player, false)
	ctx.Tools.RemoveTools(player)
	local hum = Util.Humanoid(player)
	if hum then
		hum.Sit = false
	end
	player:SetAttribute("Wanted", 0)
	player:SetAttribute("Stunned", nil)
	player:SetAttribute("Jailed", seconds)
	task.wait()
	Util.Teleport(player, CrimeService.CellFor(player))
	ctx.Needs.UpdateSpeed(player)
end

function CrimeService.Arrest(officer, target)
	if not isLaw(officer) then
		return false
	end
	local stars = target:GetAttribute("Wanted") or 0
	if stars <= 0 then
		ctx.Net.Notify(officer, target.DisplayName .. " не находится в розыске.", "bad")
		return false
	end
	if (target:GetAttribute("Jailed") or 0) > 0 then
		return false
	end
	local seconds = stars * Config.Crime.JailSecondsPerStar
	CrimeService.Jail(target, seconds)
	local role = Config.Roles[officer:GetAttribute("Role")]
	local bonus = (role.ArrestBonus or 100) * stars
	ctx.Data.AddCash(officer, bonus)
	local data = ctx.Data.Get(officer)
	if data then
		data.Stats.Arrests += 1
	end
	ctx.Quests.Progress(officer, "arrest", 1)
	ctx.Net.Notify(target, "Вас арестовал(а) " .. officer.DisplayName .. ". Срок: " .. seconds .. " сек.", "bad")
	ctx.Net.Send(officer, "Earned", { Amount = bonus, Text = "Премия за задержание " .. target.DisplayName })
	ctx.Net.NotifyAll("👮 " .. officer.DisplayName .. " задержал(а) " .. target.DisplayName .. " (" .. Util.Stars(stars) .. ")", "info")
	return true
end

function CrimeService.OnDeath(victim)
	local info = lastAttacker[victim]
	lastAttacker[victim] = nil
	if not info or os.clock() - info.Time > 10 then
		return
	end
	local killer = info.Player
	if not killer.Parent or killer == victim then
		return
	end
	local victimWanted = (victim:GetAttribute("Wanted") or 0) > 0
	if not (isLaw(killer) and victimWanted) then
		CrimeService.AddWanted(killer, 2, "убийство")
	end
end

function CrimeService.OnPlayerRemoving(player)
	local jailed = player:GetAttribute("Jailed") or 0
	local data = ctx.Data.Get(player)
	if data then
		local wanted = player:GetAttribute("Wanted") or 0
		-- Выход из игры в розыске = автоматический срок при следующем входе.
		data.JailLeft = jailed > 0 and jailed or (wanted > 0 and wanted * Config.Crime.JailSecondsPerStar or nil)
	end
	lastCrime[player] = nil
	lastAttacker[player] = nil
	cellIndex[player] = nil
end

local function setupRobberies()
	local MakePrompt = ctx.WorldBuilder.MakePrompt
	for spotId, spotPart in ctx.World.Robbery do
		local info = Config.Crime.Robberies[spotId]
		local pp = MakePrompt(spotPart, "Ограбить", info.Name, info.Duration, 8)
		pp.Style = Enum.ProximityPromptStyle.Default
		pp.Triggered:Connect(function(player)
			if isLaw(player) or player:GetAttribute("Role") == "Medic" then
				ctx.Net.Notify(player, "Ваша роль не позволяет совершать преступления.", "bad")
				return
			end
			if (player:GetAttribute("Jailed") or 0) > 0 then
				return
			end
			local last = robberyCooldown[spotId]
			if last and os.clock() - last < info.Cooldown then
				ctx.Net.Notify(player, "Здесь уже пусто. Приходите через " .. math.ceil(info.Cooldown - (os.clock() - last)) .. " сек.", "bad")
				return
			end
			robberyCooldown[spotId] = os.clock()
			local amount = math.random(info.Min, info.Max)
			ctx.Data.AddCash(player, amount)
			local data = ctx.Data.Get(player)
			if data then
				data.Stats.Robberies += 1
			end
			ctx.Quests.Progress(player, "rob", 1)
			ctx.Net.Send(player, "Earned", { Amount = amount, Text = "Ограбление: " .. info.Name })
			CrimeService.AddWanted(player, info.Stars, "ограбил(а) " .. info.Name)
			ctx.Net.NotifyAll("🚨 Ограблен(а) " .. info.Name .. "! Полиция выехала на место.", "warn")
		end)
	end
end

function CrimeService.Init(c)
	ctx = c
	setupRobberies()

	-- Цикл: снижение розыска и тюремный срок.
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local wanted = player:GetAttribute("Wanted") or 0
				if wanted > 0 and now - (lastCrime[player] or now) >= Config.Crime.WantedDecaySeconds then
					player:SetAttribute("Wanted", wanted - 1)
					lastCrime[player] = now
					if wanted - 1 == 0 then
						ctx.Net.Notify(player, "Полиция прекратила поиски. Розыск снят.", "good")
					end
				end
				local jailed = player:GetAttribute("Jailed") or 0
				if jailed > 0 then
					jailed -= 1
					if jailed <= 0 then
						release(player)
					else
						player:SetAttribute("Jailed", jailed)
						local jail = ctx.World.Jail
						local pos = Util.Position(player)
						if pos and (pos - jail.Center).Magnitude > jail.Radius then
							Util.Teleport(player, CrimeService.CellFor(player))
							ctx.Net.Notify(player, "Побег не удался!", "bad")
						end
					end
				end
			end
		end
	end)
end

return CrimeService
