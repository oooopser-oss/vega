-- Вход игроков, роли (команды), точки появления, табличка над головой,
-- выдача инструментов, смерть и больница.

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Util = require(script.Parent.Util)

local PlayerService = {}
local ctx

local lastRoleChange = {}
local pendingHospital = {}
local teams = {}

local function roleCount(role)
	local n = 0
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Role") == role then
			n += 1
		end
	end
	return n
end

local function relationLine(player)
	local status = player:GetAttribute("RelStatus") or ""
	local partner = player:GetAttribute("PartnerName") or ""
	if partner == "" then
		return nil
	end
	if status == "married" then
		return "💍 В браке с " .. partner
	elseif status == "engaged" then
		return "💎 Помолвка с " .. partner
	elseif status == "dating" then
		return "❤ Встречается с " .. partner
	end
	return nil
end

function PlayerService.UpdateNameplate(player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = head:FindFirstChild("Nameplate")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "Nameplate"
		gui.Size = UDim2.fromOffset(220, 78)
		gui.StudsOffset = Vector3.new(0, 2.8, 0)
		gui.MaxDistance = 70
		gui.Parent = head
		local layout = Instance.new("UIListLayout")
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = gui
		for i, name in { "Wanted", "NameLabel", "RoleLabel", "RelLabel" } do
			local l = Instance.new("TextLabel")
			l.Name = name
			l.LayoutOrder = i
			l.BackgroundTransparency = 1
			l.Size = UDim2.new(1, 0, 0, name == "NameLabel" and 22 or 17)
			l.Font = name == "NameLabel" and Enum.Font.GothamBold or Enum.Font.Gotham
			l.TextScaled = true
			l.TextStrokeTransparency = 0.4
			l.TextColor3 = Color3.new(1, 1, 1)
			l.Parent = gui
		end
	end
	local role = Config.Roles[player:GetAttribute("Role") or "Citizen"] or Config.Roles.Citizen
	gui.NameLabel.Text = (player:GetAttribute("Pass_VIP") and "👑 " or "") .. player.DisplayName
	gui.NameLabel.TextColor3 = player:GetAttribute("Pass_VIP") and Color3.fromRGB(255, 210, 70) or Color3.new(1, 1, 1)
	local jobId = player:GetAttribute("Job") or ""
	local job = Config.Jobs[jobId]
	gui.RoleLabel.Text = role.Name .. (job and (" • " .. job.Name) or "")
	gui.RoleLabel.TextColor3 = role.Color:Lerp(Color3.new(1, 1, 1), 0.35)
	local rel = relationLine(player)
	gui.RelLabel.Visible = rel ~= nil
	gui.RelLabel.Text = rel or ""
	gui.RelLabel.TextColor3 = Color3.fromRGB(255, 170, 200)
	local wanted = player:GetAttribute("Wanted") or 0
	local jailed = (player:GetAttribute("Jailed") or 0) > 0
	gui.Wanted.Visible = wanted > 0 or jailed
	gui.Wanted.Text = jailed and "⛓ В ТЮРЬМЕ" or Util.Stars(wanted)
	gui.Wanted.TextColor3 = Color3.fromRGB(255, 70, 70)
end

local function spawnCFrame(player)
	local World = ctx.World
	if (player:GetAttribute("Jailed") or 0) > 0 then
		return ctx.Crime.CellFor(player)
	end
	if pendingHospital[player] then
		pendingHospital[player] = nil
		return World.Spawns.Hospital
	end
	local roleId = player:GetAttribute("Role") or "Citizen"
	if roleId == "Citizen" or roleId == "Criminal" then
		local home = ctx.Housing.SpawnFor(player)
		if home then
			return home
		end
	end
	local role = Config.Roles[roleId]
	return (role and World.Spawns[role.Spawn]) or World.Spawns.CityHall
end

local function onCharacter(player, char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then
		return
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	char:WaitForChild("HumanoidRootPart", 10)
	task.wait()
	local cf = spawnCFrame(player)
	if cf then
		char:PivotTo(cf)
	end
	if (player:GetAttribute("Jailed") or 0) <= 0 then
		ctx.Tools.GiveRoleTools(player)
	end
	PlayerService.UpdateNameplate(player)
	ctx.Needs.UpdateSpeed(player)

	hum.Died:Connect(function()
		pendingHospital[player] = true
		ctx.Crime.OnDeath(player)
		ctx.Needs.StopActivity(player)
		ctx.Jobs.DropCarry(player)
		if ctx.Data.Spend(player, Config.DeathHospitalBill) then
			ctx.Net.Notify(player, "Вас доставили в больницу. Счёт за лечение: " .. Config.DeathHospitalBill .. "$", "bad")
		else
			ctx.Net.Notify(player, "Вас доставили в больницу. Лечение бесплатно — у вас нет денег.", "bad")
		end
		local data = ctx.Data.Get(player)
		if data then
			player:SetAttribute("Hunger", math.max(player:GetAttribute("Hunger") or 0, 40))
			player:SetAttribute("Energy", math.max(player:GetAttribute("Energy") or 0, 40))
		end
		task.delay(Players.RespawnTime, function()
			if player.Parent and player.Character == char then
				player:LoadCharacter()
			end
		end)
	end)
end

function PlayerService.SetRole(player, roleId, force)
	local role = Config.Roles[roleId]
	if not role then
		return
	end
	local current = player:GetAttribute("Role")
	if not force then
		if current == roleId and player:GetAttribute("RoleChosen") then
			ctx.Net.Send(player, "CloseMenus")
			return
		end
		if (player:GetAttribute("Jailed") or 0) > 0 then
			ctx.Net.Notify(player, "Нельзя сменить роль, находясь в тюрьме.", "bad")
			return
		end
		if (role.CanArrest) and (player:GetAttribute("Wanted") or 0) > 0 then
			ctx.Net.Notify(player, "Разыскиваемые не могут служить в полиции!", "bad")
			return
		end
		local last = lastRoleChange[player]
		if player:GetAttribute("RoleChosen") and last and os.clock() - last < Config.RoleChangeCooldown then
			ctx.Net.Notify(player, "Сменить роль можно через " .. math.ceil(Config.RoleChangeCooldown - (os.clock() - last)) .. " сек.", "bad")
			return
		end
		if role.MaxPlayers > 0 and current ~= roleId and roleCount(roleId) >= role.MaxPlayers then
			ctx.Net.Notify(player, "Все места в роли «" .. role.Name .. "» заняты.", "bad")
			return
		end
	end
	lastRoleChange[player] = os.clock()
	ctx.Jobs.Quit(player, true)
	player:SetAttribute("Role", roleId)
	player:SetAttribute("RoleChosen", true)
	player.Team = teams[roleId]
	local data = ctx.Data.Get(player)
	if data then
		data.Role = roleId
	end
	ctx.Vehicles.DespawnFor(player, true)
	ctx.Net.Send(player, "CloseMenus")
	ctx.Net.Notify(player, "Ваша роль: " .. role.Name .. ". " .. role.Description, "good")
	player:LoadCharacter()
end

local function onPlayerAdded(player)
	local data = ctx.Data.Load(player)
	if not player.Parent then
		return
	end
	ctx.Data.SyncMoney(player)
	for _, need in Config.NeedOrder do
		player:SetAttribute(need, data.Needs[need] or 80)
	end
	local roleId = Config.Roles[data.Role] and data.Role or "Citizen"
	if Config.Roles[roleId].CanArrest and roleCount(roleId) >= Config.Roles[roleId].MaxPlayers then
		roleId = "Citizen"
	end
	player:SetAttribute("Role", roleId)
	player.Team = teams[roleId]
	player:SetAttribute("Job", "")
	player:SetAttribute("Wanted", 0)
	player:SetAttribute("Jailed", data.JailLeft or 0)
	data.JailLeft = nil
	player:SetAttribute("PartnerName", "")
	player:SetAttribute("RelStatus", "")

	ctx.Housing.OnPlayerAdded(player)
	ctx.Social.OnPlayerAdded(player)
	ctx.Monetization.OnPlayerAdded(player)
	ctx.Quests.Send(player)
	if ctx.Data.IsReadOnly(player) then
		ctx.Net.Notify(player, "Не удалось загрузить ваш прогресс. Перезайдите позже — ваши данные в безопасности, сейчас они не будут перезаписаны.", "bad")
	end

	player.AttributeChanged:Connect(function(attr)
		if attr == "Role" or attr == "Job" or attr == "Wanted" or attr == "PartnerName" or attr == "RelStatus" or attr == "Jailed" then
			PlayerService.UpdateNameplate(player)
		end
	end)
	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)

	ctx.Economy.SendInventory(player)
	ctx.Vehicles.SendCars(player)
	ctx.Net.Send(player, "OpenRoleMenu", { First = true })
	player:LoadCharacter()
end

local function onPlayerRemoving(player)
	ctx.Jobs.Quit(player, true)
	ctx.Needs.StopActivity(player)
	ctx.Vehicles.DespawnFor(player, true)
	ctx.Crime.OnPlayerRemoving(player)
	ctx.Social.OnPlayerRemoving(player)
	ctx.Housing.OnPlayerRemoving(player)
	ctx.Data.Release(player)
	lastRoleChange[player] = nil
	pendingHospital[player] = nil
end

function PlayerService.Init(c)
	ctx = c
	Players.CharacterAutoLoads = false
	for _, roleId in Config.RoleOrder do
		local role = Config.Roles[roleId]
		local team = Instance.new("Team")
		team.Name = role.Name
		team.TeamColor = BrickColor.new(role.Color)
		team.AutoAssignable = false
		team.Parent = Teams
		teams[roleId] = team
	end

	ctx.Net.On("SelectRole", function(player, p)
		if type(p.Role) == "string" then
			PlayerService.SetRole(player, p.Role, false)
		end
	end)
	ctx.Net.On("Respawn", function(player)
		local hum = Util.Humanoid(player)
		if not hum or hum.Health <= 0 then
			player:LoadCharacter()
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

-- Подключает уже вошедших игроков (если скрипт запустился позже).
function PlayerService.Start()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return PlayerService
