-- Дома: покупка в агентстве недвижимости, личная дверь, кровать, душ,
-- телевизор и холодильник. Супруг(а) пользуется домом вместе с владельцем.

local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Util = require(script.Parent.Util)

local HousingService = {}
local ctx

local owners = {} -- [houseId] = Player
local fridgeCooldown = {} -- [Player] = time

local function houseOf(player)
	for id, owner in owners do
		if owner == player then
			return ctx.World.Houses[id]
		end
	end
	return nil
end
HousingService.HouseOf = houseOf

local function partnerPlayer(player)
	local data = ctx.Data.Get(player)
	if not data or not data.Partner then
		return nil
	end
	return Players:GetPlayerByUserId(tonumber(data.Partner))
end

-- Дом, которым игрок может пользоваться: свой или супруга(и).
local function accessibleHouse(player)
	local own = houseOf(player)
	if own then
		return own
	end
	if player:GetAttribute("RelStatus") == "married" then
		local partner = partnerPlayer(player)
		if partner then
			return houseOf(partner)
		end
	end
	return nil
end
HousingService.AccessibleHouse = accessibleHouse

local function canUse(player, house)
	return accessibleHouse(player) == house
end
HousingService.CanUse = canUse

function HousingService.OwnerOf(houseId)
	return owners[houseId]
end

-- Мебель, отделка и уют дома перестраиваются при смене владельца.
local function homeChanged(house)
	if ctx.Home then
		ctx.Home.Render(house)
	end
end

local function refreshSign(house)
	local owner = owners[house.Id]
	if owner then
		local text = "Дом №" .. house.Id .. "\n" .. owner.DisplayName
		if owner:GetAttribute("RelStatus") == "married" and (owner:GetAttribute("PartnerName") or "") ~= "" then
			text = "Дом №" .. house.Id .. "\nСемья " .. owner.DisplayName .. " и " .. owner:GetAttribute("PartnerName")
		end
		house.SignLabel.Text = text
		house.SignLabel.BackgroundColor3 = Color3.fromRGB(250, 250, 240)
	else
		house.SignLabel.Text = "Дом №" .. house.Id .. "\nПРОДАЁТСЯ " .. Config.HousePrice .. "$"
		house.SignLabel.BackgroundColor3 = Color3.fromRGB(255, 230, 150)
	end
end
HousingService.RefreshSign = refreshSign

function HousingService.RefreshFor(player)
	local house = houseOf(player)
	if house then
		refreshSign(house)
	end
	local accessible = accessibleHouse(player)
	player:SetAttribute("HouseId", (accessible or {}).Id or 0)
	local data = ctx.Data.Get(player)
	player:SetAttribute("HasHouse", data ~= nil and data.HasHouse == true)
	if ctx.Home then
		player:SetAttribute("HomeComfort", accessible and ctx.Home.ComfortOf(accessible) or 0)
		ctx.Home.Send(player)
	end
end

local function claimPlot(player)
	for _, house in ctx.World.Houses do
		if not owners[house.Id] then
			owners[house.Id] = player
			refreshSign(house)
			homeChanged(house)
			return house
		end
	end
	return nil
end

function HousingService.SpawnFor(player)
	local house = accessibleHouse(player)
	return house and house.Spawn or nil
end

function HousingService.OnPlayerAdded(player)
	local data = ctx.Data.Get(player)
	if data and data.HasHouse then
		local house = claimPlot(player)
		if not house then
			ctx.Net.Notify(player, "На этом сервере нет свободного участка для вашего дома. Ваш дом сохранён.", "warn")
		end
	end
	HousingService.RefreshFor(player)
end

function HousingService.OnPlayerRemoving(player)
	for id, owner in owners do
		if owner == player then
			owners[id] = nil
			local house = ctx.World.Houses[id]
			refreshSign(house)
			homeChanged(house)
			house.Door.CanCollide = true
			house.Door.Transparency = 0
		end
	end
	fridgeCooldown[player] = nil
	for _, other in Players:GetPlayers() do
		if other ~= player then
			task.defer(HousingService.RefreshFor, other)
		end
	end
end

local function openDoor(house)
	house.Door.CanCollide = false
	house.Door.Transparency = 0.7
	task.delay(4, function()
		house.Door.CanCollide = true
		house.Door.Transparency = 0
	end)
end

function HousingService.Init(c)
	ctx = c
	local MakePrompt = ctx.WorldBuilder.MakePrompt
	local Net = ctx.Net

	for _, house in ctx.World.Houses do
		refreshSign(house)
		MakePrompt(house.Door, "Открыть дверь", "Дом №" .. house.Id, 0, 8).Triggered:Connect(function(player)
			if canUse(player, house) or (ctx.Home and ctx.Home.IsOpen(house)) then
				openDoor(house)
			else
				local owner = owners[house.Id]
				if owner then
					Net.Notify(player, "Вы позвонили в дверь. Хозяин(ка) получил(а) уведомление.", "info")
					Net.Send(owner, "DoorBell", { From = player.DisplayName, UserId = player.UserId, House = house.Id })
				else
					Net.Notify(player, "Этот дом продаётся за " .. Config.HousePrice .. "$. Купите его в мэрии (агентство недвижимости).", "info")
				end
			end
		end)
		local function homeAction(p, action, fn)
			MakePrompt(p, action, "", 0.3, 8).Triggered:Connect(function(player)
				if not canUse(player, house) then
					Net.Notify(player, "Это не ваш дом.", "bad")
					return
				end
				fn(player)
			end)
		end
		-- Уют дома ускоряет отдых (до ×2).
		local function comfort()
			return ctx.Home and ctx.Home.ComfortMult(house) or 1
		end
		homeAction(house.Bed, "Спать", function(player)
			ctx.Needs.StartActivity(player, "Sleep", house.Bed, "Energy", 6 * comfort(), { Heal = true })
		end)
		homeAction(house.Shower, "Принять душ", function(player)
			ctx.Needs.StartActivity(player, "Shower", house.Shower, "Hygiene", 8 * comfort())
		end)
		homeAction(house.TV, "Смотреть ТВ", function(player)
			ctx.Needs.StartActivity(player, "TV", house.TV, "Fun", 3 * comfort())
			Net.Notify(player, "Вы смотрите телевизор. Отойдите или нажмите «Встать», чтобы закончить.", "info")
		end)
		homeAction(house.Fridge, "Перекусить", function(player)
			local last = fridgeCooldown[player]
			if last and os.clock() - last < 120 then
				Net.Notify(player, "Холодильник пуст. Загляните через " .. math.ceil(120 - (os.clock() - last)) .. " сек. или купите продукты.", "info")
				return
			end
			fridgeCooldown[player] = os.clock()
			ctx.Needs.Change(player, "Hunger", 30)
			Net.Notify(player, "Вы перекусили дома. +30 Сытость", "good")
		end)
	end

	MakePrompt(ctx.World.Desks.Realty, "Недвижимость", "Агентство", 0, 12).Triggered:Connect(function(player)
		Net.Send(player, "OpenPhone", { Tab = "Дом" })
	end)

	Net.On("BuyHouse", function(player)
		local data = ctx.Data.Get(player)
		if not data then
			return
		end
		if data.HasHouse then
			Net.Notify(player, "У вас уже есть дом.", "bad")
			return
		end
		if not Util.Near(player, ctx.World.Desks.Realty, 20) then
			Net.Notify(player, "Купить дом можно в агентстве недвижимости в мэрии.", "bad")
			return
		end
		local free = false
		for _, house in ctx.World.Houses do
			if not owners[house.Id] then
				free = true
			end
		end
		if not free then
			Net.Notify(player, "Свободных домов нет.", "bad")
			return
		end
		if not ctx.Data.Spend(player, Config.HousePrice) then
			Net.Notify(player, "Недостаточно денег. Дом стоит " .. Config.HousePrice .. "$.", "bad")
			return
		end
		data.HasHouse = true
		local house = claimPlot(player)
		HousingService.RefreshFor(player)
		local partner = partnerPlayer(player)
		if partner then
			HousingService.RefreshFor(partner)
		end
		Net.Notify(player, "Поздравляем с новосельем! Ваш дом — №" .. house.Id .. ". Он отмечен в GPS.", "good")
		Net.Send(player, "Waypoint", { Name = "Мой дом", Position = house.Spawn.Position })
	end)

	Net.On("SellHouse", function(player)
		local data = ctx.Data.Get(player)
		if not data or not data.HasHouse then
			return
		end
		data.HasHouse = false
		local refund = math.floor(Config.HousePrice * Config.HouseSellRefund)
		data.Bank += refund
		ctx.Data.SyncMoney(player)
		for id, owner in owners do
			if owner == player then
				owners[id] = nil
				refreshSign(ctx.World.Houses[id])
				homeChanged(ctx.World.Houses[id])
			end
		end
		-- Мебель продаётся вместе с домом; премиум-вещи остаются открытыми.
		if type(data.Home) == "table" then
			data.Home.Items = nil
			data.Home.Style = nil
		end
		HousingService.RefreshFor(player)
		local partner = partnerPlayer(player)
		if partner then
			HousingService.RefreshFor(partner)
		end
		Net.Notify(player, "Дом продан. На карту зачислено " .. refund .. "$.", "info")
	end)

	Net.On("GoHome", function(player)
		local house = accessibleHouse(player)
		if house then
			Net.Send(player, "Waypoint", { Name = "Мой дом", Position = house.Spawn.Position })
		else
			Net.Notify(player, "У вас нет дома.", "bad")
		end
	end)
end

return HousingService
