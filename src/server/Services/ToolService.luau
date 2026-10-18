-- Инструменты ролей: наручники и электрошокер (полиция/спецслужбы),
-- аптечка (медик), бита (преступник).

local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Util = require(script.Parent.Util)

local ToolService = {}
local ctx

local cooldowns = {} -- [Player] = { [toolName] = time }
local healCooldown = {} -- [target] = time
local hitMemory = {} -- [attacker] = { [victim] = time }

local TOOL_DEFS = {
	Handcuffs = { Name = "Наручники", Tip = "Арестовать разыскиваемого рядом", Color = Color3.fromRGB(180, 180, 190), Size = Vector3.new(1, 0.4, 1.6), Cooldown = 1.5, Range = 8 },
	Taser = { Name = "Электрошокер", Tip = "Обездвижить цель перед собой", Color = Color3.fromRGB(240, 220, 40), Size = Vector3.new(0.5, 1, 1.6), Cooldown = 5, Range = 25 },
	Medkit = { Name = "Аптечка", Tip = "Вылечить игрока рядом", Color = Color3.fromRGB(230, 40, 40), Size = Vector3.new(1.6, 1.2, 0.8), Cooldown = 2, Range = 8 },
	Guitar = { Name = "Гитара", Tip = "Играть на улице за чаевые", Color = Color3.fromRGB(190, 120, 50), Size = Vector3.new(1, 3, 0.4), Cooldown = 1, Range = 0 },
	Bat = { Name = "Бита", Tip = "Ударить игрока перед собой", Color = Color3.fromRGB(150, 100, 60), Size = Vector3.new(0.5, 0.5, 4), Cooldown = 0.8, Range = 7 },
}

local function onCooldown(player, name, seconds)
	cooldowns[player] = cooldowns[player] or {}
	local last = cooldowns[player][name]
	if last and os.clock() - last < seconds then
		return true
	end
	cooldowns[player][name] = os.clock()
	return false
end

-- Ближайший живой игрок перед персонажем.
local function targetInFront(player, range, minDot)
	local hrp = Util.HRP(player)
	if not hrp then
		return nil
	end
	local best, bestDist = nil, range
	for _, other in Players:GetPlayers() do
		if other ~= player and Util.Alive(other) then
			local ohrp = Util.HRP(other)
			if ohrp then
				local offset = ohrp.Position - hrp.Position
				local dist = offset.Magnitude
				if dist <= bestDist then
					local dot = dist > 0.1 and hrp.CFrame.LookVector:Dot(offset.Unit) or 1
					if dot >= (minDot or -1) then
						best, bestDist = other, dist
					end
				end
			end
		end
	end
	return best
end

local function stun(target, seconds)
	target:SetAttribute("Stunned", true)
	ctx.Needs.UpdateSpeed(target)
	local hum = Util.Humanoid(target)
	if hum then
		hum.Sit = false
	end
	ctx.Net.Notify(target, "Вас ударило током! Вы обездвижены на " .. seconds .. " сек.", "bad")
	task.delay(seconds, function()
		if target.Parent then
			target:SetAttribute("Stunned", nil)
			ctx.Needs.UpdateSpeed(target)
		end
	end)
end

local function useTool(player, name)
	if (player:GetAttribute("Jailed") or 0) > 0 or player:GetAttribute("Stunned") then
		return
	end
	local def = TOOL_DEFS[name]
	if onCooldown(player, name, def.Cooldown) then
		return
	end
	if name == "Guitar" then
		ctx.Activities.ToggleBusking(player)
		return
	end
	if name == "Handcuffs" then
		local target = targetInFront(player, def.Range, -1)
		if not target then
			ctx.Net.Notify(player, "Рядом никого нет.", "info")
			return
		end
		ctx.Crime.Arrest(player, target)
	elseif name == "Taser" then
		local target = targetInFront(player, def.Range, 0.85)
		if not target then
			ctx.Net.Notify(player, "Промах!", "info")
			return
		end
		-- Боксёры быстрее приходят в себя.
		stun(target, math.max(1, Config.Crime.TaserStun - 0.4 * ctx.Progression.Level(target, "Boxing")))
		if (target:GetAttribute("Wanted") or 0) == 0 then
			ctx.Net.Notify(player, "Внимание: " .. target.DisplayName .. " не в розыске. Не злоупотребляйте шокером!", "warn")
		end
	elseif name == "Medkit" then
		local target = targetInFront(player, def.Range, -1)
		if not target then
			ctx.Net.Notify(player, "Рядом нет пациентов.", "info")
			return
		end
		local hum = Util.Humanoid(target)
		if not hum then
			return
		end
		if hum.Health >= hum.MaxHealth - 5 then
			ctx.Net.Notify(player, target.DisplayName .. " здоров(а).", "info")
			return
		end
		hum.Health = math.min(hum.MaxHealth, hum.Health + 50)
		ctx.Net.Notify(target, player.DisplayName .. " оказал(а) вам медицинскую помощь.", "good")
		local last = healCooldown[target]
		if not last or os.clock() - last > 20 then
			healCooldown[target] = os.clock()
			ctx.Data.AddCash(player, 40)
			ctx.Net.Send(player, "Earned", { Amount = 40, Text = "Лечение " .. target.DisplayName })
			ctx.Quests.Progress(player, "heal", 1)
		end
	elseif name == "Bat" then
		local target = targetInFront(player, def.Range, 0.3)
		if not target then
			return
		end
		local hum = Util.Humanoid(target)
		if not hum then
			return
		end
		ctx.Crime.TagAttack(target, player)
		-- Навыки «Сила» и «Бокс» усиливают удар.
		local bonus = 2 * (ctx.Progression.Level(player, "Strength") + ctx.Progression.Level(player, "Boxing"))
		hum:TakeDamage(Config.Crime.BatDamage + bonus)
		local hrp, thrp = Util.HRP(player), Util.HRP(target)
		if hrp and thrp then
			thrp.AssemblyLinearVelocity += (thrp.Position - hrp.Position).Unit * 30 + Vector3.new(0, 15, 0)
		end
		hitMemory[player] = hitMemory[player] or {}
		local last = hitMemory[player][target]
		hitMemory[player][target] = os.clock()
		if (target:GetAttribute("Wanted") or 0) == 0 and (not last or os.clock() - last > 30) then
			ctx.Crime.AddWanted(player, 1, "нападение на " .. target.DisplayName)
		end
	end
end

local function makeTool(name)
	local def = TOOL_DEFS[name]
	local tool = Instance.new("Tool")
	tool.Name = def.Name
	tool.ToolTip = def.Tip
	tool.CanBeDropped = false
	tool:SetAttribute("RoleTool", true)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = def.Size
	handle.Color = def.Color
	handle.Material = name == "Bat" and Enum.Material.Wood or Enum.Material.Metal
	handle.CanCollide = false
	handle.Parent = tool
	if name == "Bat" then
		tool.GripPos = Vector3.new(0, 0, 1.4)
	end
	tool.Activated:Connect(function()
		local char = tool.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		if player then
			useTool(player, name)
		end
	end)
	return tool
end

function ToolService.RemoveTools(player)
	local containers = { player:FindFirstChild("Backpack"), player.Character }
	for _, container in containers do
		if container then
			for _, item in container:GetChildren() do
				if item:IsA("Tool") and item:GetAttribute("RoleTool") then
					item:Destroy()
				end
			end
		end
	end
end

function ToolService.GiveRoleTools(player)
	ToolService.RemoveTools(player)
	local role = Config.Roles[player:GetAttribute("Role") or "Citizen"]
	local backpack = player:FindFirstChild("Backpack")
	if not role or not backpack then
		return
	end
	for _, name in role.Tools or {} do
		makeTool(name).Parent = backpack
	end
	-- Хобби: купленная гитара.
	if ctx.Data.HasItem(player, "guitar") then
		makeTool("Guitar").Parent = backpack
	end
end

function ToolService.Init(c)
	ctx = c
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
		healCooldown[player] = nil
		hitMemory[player] = nil
	end)
end

return ToolService
