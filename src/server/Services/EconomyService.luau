-- Магазины, банкоматы, инвентарь и использование предметов.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Util = require(script.Parent.Util)

local EconomyService = {}
local ctx

local SHOP_DISTANCE = 16

function EconomyService.SendInventory(player)
	local data = ctx.Data.Get(player)
	if data then
		ctx.Net.Send(player, "Inventory", { Items = data.Inventory })
	end
end

local function nearAnyATM(player)
	for _, atm in ctx.World.ATMs do
		if Util.Near(player, atm, SHOP_DISTANCE) then
			return true
		end
	end
	return false
end

function EconomyService.Init(c)
	ctx = c
	local World = ctx.World
	local MakePrompt = ctx.WorldBuilder.MakePrompt
	local Net = ctx.Net
	local Data = ctx.Data

	for shopId, shopPart in World.Shops do
		local shop = Config.Shops[shopId]
		local pp = MakePrompt(shopPart, "Купить", shop.Name, 0, 10)
		pp.Triggered:Connect(function(player)
			Net.Send(player, "OpenShop", { Shop = shopId })
		end)
	end

	for _, atm in World.ATMs do
		local pp = MakePrompt(atm, "Открыть", "Банк", 0, 10)
		pp.Triggered:Connect(function(player)
			Net.Send(player, "OpenBank", {})
		end)
	end

	MakePrompt(World.Desks.Jobs, "Найти работу", "Биржа труда", 0, 12).Triggered:Connect(function(player)
		Net.Send(player, "OpenPhone", { Tab = "Работа" })
	end)
	MakePrompt(World.Desks.Roles, "Сменить роль", "Отдел кадров", 0, 12).Triggered:Connect(function(player)
		Net.Send(player, "OpenRoleMenu", {})
	end)

	Net.On("BuyItem", function(player, p)
		local shopId, itemId = p.Shop, p.Item
		local count = math.clamp(math.floor(tonumber(p.Count) or 1), 1, 10)
		local shop = Config.Shops[shopId]
		local item = Config.Items[itemId]
		if not shop or not item or not table.find(shop.Items, itemId) then
			return
		end
		if not Util.Near(player, World.Shops[shopId], SHOP_DISTANCE) then
			Net.Notify(player, "Подойдите ближе к прилавку.", "bad")
			return
		end
		local price = item.Price * count
		if not Data.Spend(player, price) then
			Net.Notify(player, "Недостаточно денег (нужно " .. price .. "$).", "bad")
			return
		end
		Data.AddItem(player, itemId, count)
		Net.Notify(player, "Куплено: " .. item.Name .. " ×" .. count .. " за " .. price .. "$", "good")
		EconomyService.SendInventory(player)
		ctx.Quests.Progress(player, "shop", 1)
	end)

	Net.On("UseItem", function(player, p)
		local item = Config.Items[p.Item]
		if not item or not item.Effects then
			return
		end
		if not Util.Alive(player) then
			return
		end
		if not Data.TakeItem(player, p.Item) then
			Net.Notify(player, "У вас нет этого предмета.", "bad")
			return
		end
		ctx.Needs.ApplyEffects(player, item.Effects)
		if item.Effects.Hunger and item.Effects.Hunger >= 10 then
			ctx.Quests.Progress(player, "eat", 1)
		end
		Net.Notify(player, "Вы использовали: " .. item.Name, "good")
		EconomyService.SendInventory(player)
	end)

	Net.On("Bank", function(player, p)
		local amount = math.floor(tonumber(p.Amount) or 0)
		if amount <= 0 or amount > 1e9 then
			return
		end
		if not nearAnyATM(player) then
			Net.Notify(player, "Нужно стоять у банкомата.", "bad")
			return
		end
		local data = Data.Get(player)
		if not data then
			return
		end
		if p.Op == "deposit" then
			amount = math.min(amount, data.Cash)
			data.Cash -= amount
			data.Bank += amount
			Net.Notify(player, "Внесено на карту: " .. amount .. "$", "good")
		elseif p.Op == "withdraw" then
			amount = math.min(amount, data.Bank)
			data.Bank -= amount
			data.Cash += amount
			Net.Notify(player, "Снято наличными: " .. amount .. "$", "good")
		end
		Data.SyncMoney(player)
	end)

	Net.On("GetState", function(player)
		EconomyService.SendInventory(player)
		ctx.Vehicles.SendCars(player)
		ctx.Social.SendRelations(player)
		ctx.Jobs.ResendTask(player)
		ctx.Net.Send(player, "GPS", { List = ctx.World.GPS })
	end)
end

return EconomyService
