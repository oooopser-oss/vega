-- Потребности как в The Sims: сытость, энергия, гигиена, настроение.
-- Со временем падают; восстанавливаются едой, сном, душем, отдыхом.

local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Util = require(script.Parent.Util)

local NeedsService = {}
local ctx

local activities = {} -- [Player] = { Kind, Token, Part }
local warned = {} -- [Player] = { [need] = true }
local spotCooldown = {} -- [Player] = { [Part] = time }

local ACTIVITY_NAMES = {
	Sleep = "Сон",
	Shower = "Душ",
	TV = "Просмотр ТВ",
}

function NeedsService.Change(player, need, delta)
	local v = player:GetAttribute(need)
	if v == nil then
		return
	end
	local nv = math.clamp(v + delta, 0, 100)
	player:SetAttribute(need, math.floor(nv * 10 + 0.5) / 10)
	if nv >= 25 and warned[player] then
		warned[player][need] = nil
	end
end

function NeedsService.ApplyEffects(player, effects)
	if not effects then
		return
	end
	for need, amount in effects do
		NeedsService.Change(player, need, amount)
	end
end

function NeedsService.UpdateSpeed(player)
	local hum = Util.Humanoid(player)
	if not hum then
		return
	end
	-- Выносливость: +0,5 к скорости за уровень.
	local speed = 16 + 0.5 * (player:GetAttribute("Skill_Stamina") or 0)
	if (player:GetAttribute("Energy") or 100) < 15 then
		speed = 10
	end
	if player:GetAttribute("Stunned") then
		speed = 0
	end
	hum.WalkSpeed = speed
	hum.JumpPower = player:GetAttribute("Stunned") and 0 or 50
end

function NeedsService.StopActivity(player)
	local act = activities[player]
	if not act then
		return
	end
	activities[player] = nil
	player:SetAttribute("Activity", "")
	local hrp = Util.HRP(player)
	if hrp then
		hrp.Anchored = false
		if act.Part and act.Part.Parent then
			local p = act.Part
			-- Ставим персонажа рядом с объектом.
			local out = p.Position + Vector3.new(0, p.Size.Y / 2 + 3, 0) + (p.CFrame.RightVector * (p.Size.X / 2 + 3))
			player.Character:PivotTo(CFrame.new(out))
		end
	end
end

-- kind: "Sleep" | "Shower" | "TV"
function NeedsService.StartActivity(player, kind, target, need, rate, opts)
	opts = opts or {}
	if not Util.Alive(player) then
		return
	end
	if activities[player] then
		NeedsService.StopActivity(player)
	end
	if (player:GetAttribute(need) or 0) >= 99 then
		ctx.Net.Notify(player, Config.Needs[need].Name .. " и так на максимуме.", "info")
		return
	end
	local hrp = Util.HRP(player)
	local hum = Util.Humanoid(player)
	if not hrp or not hum then
		return
	end
	hum.Sit = false
	local token = {}
	activities[player] = { Kind = kind, Token = token, Part = target }
	player:SetAttribute("Activity", ACTIVITY_NAMES[kind] or kind)

	if kind == "Sleep" then
		local top = target.Position + Vector3.new(0, target.Size.Y / 2 + 1, 0)
		local along = target.Size.Z >= target.Size.X and target.CFrame.LookVector or target.CFrame.RightVector
		player.Character:PivotTo(CFrame.lookAt(top, top + Vector3.new(0, 1, 0), along))
		hrp.Anchored = true
	elseif kind == "Shower" then
		player.Character:PivotTo(CFrame.new(target.Position + Vector3.new(0, 0.5, 0)))
		hrp.Anchored = true
	end

	task.spawn(function()
		while activities[player] and activities[player].Token == token do
			task.wait(1)
			if not activities[player] or activities[player].Token ~= token then
				return
			end
			if not Util.Alive(player) or (kind == "TV" and not Util.Near(player, target, opts.Range or 14)) then
				break
			end
			NeedsService.Change(player, need, rate)
			if opts.Heal then
				local h = Util.Humanoid(player)
				if h then
					h.Health = math.min(h.MaxHealth, h.Health + 4)
				end
			end
			if opts.Extra then
				NeedsService.ApplyEffects(player, opts.Extra)
			end
			if (player:GetAttribute(need) or 0) >= 100 then
				ctx.Net.Notify(player, Config.Needs[need].Name .. " восстановлена!", "good")
				if kind == "Sleep" then
					ctx.Quests.Progress(player, "sleep", 1)
				elseif kind == "Shower" then
					ctx.Quests.Progress(player, "shower", 1)
				end
				break
			end
		end
		if activities[player] and activities[player].Token == token then
			NeedsService.StopActivity(player)
		end
	end)
end

function NeedsService.InActivity(player)
	return activities[player] ~= nil
end

local function onCooldown(player, p, seconds)
	spotCooldown[player] = spotCooldown[player] or {}
	local last = spotCooldown[player][p]
	if last and os.clock() - last < seconds then
		return true
	end
	spotCooldown[player][p] = os.clock()
	return false
end

local function stinkFor(player, on)
	local hrp = Util.HRP(player)
	if not hrp then
		return
	end
	local existing = hrp:FindFirstChild("Stink")
	if on and not existing then
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "Stink"
		pe.Color = ColorSequence.new(Color3.fromRGB(120, 160, 60))
		pe.Rate = 4
		pe.Lifetime = NumberRange.new(1.5, 2.5)
		pe.Speed = NumberRange.new(1, 2)
		pe.Size = NumberSequence.new(1.2, 2.5)
		pe.Transparency = NumberSequence.new(0.5, 1)
		pe.Parent = hrp
	elseif not on and existing then
		existing:Destroy()
	end
end

local function tick(dt)
	local minutes = dt / 60
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("RoleChosen") and Util.Alive(player) then
			local act = activities[player]
			for _, need in Config.NeedOrder do
				local info = Config.Needs[need]
				local paused = act and ((act.Kind == "Sleep" and need == "Energy") or (act.Kind == "Shower" and need == "Hygiene") or (act.Kind == "TV" and need == "Fun"))
				if not paused then
					local mult = need == "Energy" and (1 - 0.05 * (player:GetAttribute("Skill_Stamina") or 0)) or 1
					NeedsService.Change(player, need, -info.Decay * minutes * mult)
				end
				local v = player:GetAttribute(need) or 0
				warned[player] = warned[player] or {}
				if v < 20 and not warned[player][need] then
					warned[player][need] = true
					ctx.Net.Notify(player, "Низкий уровень: " .. info.Name .. "!", "warn")
				end
			end
			if (player:GetAttribute("Hunger") or 0) <= 0 then
				local hum = Util.Humanoid(player)
				if hum then
					hum:TakeDamage(3)
				end
			end
			stinkFor(player, (player:GetAttribute("Hygiene") or 100) < 20)
			NeedsService.UpdateSpeed(player)
		end
	end
end

function NeedsService.Init(c)
	ctx = c
	local World = ctx.World
	local MakePrompt = ctx.WorldBuilder.MakePrompt

	for _, bed in World.Beds do
		local pp = MakePrompt(bed.Part, "Лечь спать", bed.Name, 0.5, 9)
		pp.Triggered:Connect(function(player)
			NeedsService.StartActivity(player, "Sleep", bed.Part, "Energy", bed.Rate, { Heal = bed.Heal })
		end)
	end
	for _, shower in World.Showers do
		local pp = MakePrompt(shower.Part, "Принять душ", shower.Name, 0.5, 9)
		pp.Triggered:Connect(function(player)
			NeedsService.StartActivity(player, "Shower", shower.Part, "Hygiene", shower.Rate)
		end)
	end
	for _, spot in World.FunSpots do
		local pp = MakePrompt(spot.Part, spot.Text, "", spot.Hold or 0, 10)
		pp.Triggered:Connect(function(player)
			if onCooldown(player, spot.Part, spot.Cooldown or 10) then
				ctx.Net.Notify(player, "Подождите немного, прежде чем повторить.", "info")
				return
			end
			if spot.Cost and not ctx.Data.Spend(player, spot.Cost) then
				ctx.Net.Notify(player, "Недостаточно денег.", "bad")
				return
			end
			NeedsService.Change(player, spot.Need, spot.Amount)
			NeedsService.ApplyEffects(player, spot.Extra)
			ctx.Net.Notify(player, "+" .. spot.Amount .. " " .. Config.Needs[spot.Need].Name, "good")
			ctx.Quests.Progress(player, "fun", 1)
		end)
	end

	ctx.Net.On("StopActivity", function(player)
		NeedsService.StopActivity(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		activities[player] = nil
		warned[player] = nil
		spotCooldown[player] = nil
	end)

	task.spawn(function()
		while true do
			local dt = task.wait(2)
			tick(dt)
		end
	end)
end

return NeedsService
