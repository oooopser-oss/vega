-- Хранение прогресса игроков (деньги, вещи, машины, дом, отношения).
-- Работает через DataStore; если API отключено (например, в Studio без
-- «Enable Studio Access to API Services»), игра работает без сохранений.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local DataService = {}

-- ВАЖНО: имя хранилища НЕ меняется между обновлениями игры — иначе игроки
-- потеряют прогресс. Изменения формата данных делаются через DATA_VERSION
-- и миграции ниже (см. UPDATES.md).
local STORE_NAME = "LifeCity_v1"
local DATA_VERSION = 4

-- Миграции: функция для каждой новой версии формата данных.
-- Старые сохранения последовательно доводятся до DATA_VERSION.
local MIGRATIONS = {
	[2] = function(data)
		-- v2: город Первоуральск, ежедневные задания, монетизация.
		data.Quests = nil
		data.RegistrationBonusGiven = data.RegistrationBonusGiven or false
	end,
	[3] = function(data)
		-- v3: навыки, учёба, права. Кто уже купил машину — получает права.
		if type(data.Cars) == "table" and next(data.Cars) ~= nil then
			data.License = true
		end
	end,
	[4] = function(data)
		-- v4: обустройство дома. Владельцы получают стандартную мебель
		-- (HomeService.HomeOf), которую теперь можно переставить или продать.
		if type(data.Home) ~= "table" then
			data.Home = nil
		end
	end,
}
local store
local storeOk = pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)

local profiles = {} -- [Player] = data

local function defaultData()
	return {
		Version = DATA_VERSION,
		Cash = Config.StartCash,
		Bank = Config.StartBank,
		Inventory = { bread = 2, water = 2 },
		Cars = {},
		Wardrobe = {}, -- купленная одежда: [id] = true
		Skills = {}, -- опыт навыков: [skill] = xp
		Education = { School = 0, College = 0 }, -- сданные уроки и лекции
		Records = {}, -- личные рекорды (забег)
		License = false, -- водительские права
		Outfit = nil, -- надетый комплект { Top, Bottom, Hat, Accessory }; nil — свой аватар
		HasHouse = false,
		Home = { Style = {}, Unlocked = {}, Open = false }, -- отделка, премиум-мебель; расстановку (Items) создаёт HomeService
		Role = "Citizen",
		Relations = {}, -- [tostring(userId)] = { Points, Status, Name }
		Partner = nil, -- tostring(userId)
		Needs = { Hunger = 80, Energy = 90, Hygiene = 90, Fun = 70 },
		Stats = { TasksDone = 0, Arrests = 0, Robberies = 0, Earned = 0, QuestsDone = 0 },
		RegistrationBonusGiven = false,
		LastDaily = 0,
		DailyStreak = 0,
	}
end

local function reconcile(data, template)
	for k, v in template do
		if data[k] == nil then
			data[k] = v
		elseif type(v) == "table" and type(data[k]) == "table" and k ~= "Relations" and k ~= "Inventory" and k ~= "Cars" and k ~= "Items" and k ~= "Unlocked" and k ~= "Style" then
			reconcile(data[k], v)
		end
	end
	return data
end

local readOnly = {} -- [Player] = true, если загрузка не удалась (не перезаписываем сохранение)

function DataService.Load(player)
	local data
	local loaded = not (storeOk and store)
	if storeOk and store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync("p_" .. player.UserId)
			end)
			if ok then
				data = result
				loaded = true
				break
			end
			warn("[Data] Ошибка загрузки (попытка " .. attempt .. "): " .. tostring(result))
			task.wait(1)
		end
	end
	if not loaded then
		readOnly[player] = true
		warn("[Data] Не удалось загрузить данные " .. player.Name .. " — сохранение отключено, чтобы не стереть прогресс.")
	end
	local isNew = type(data) ~= "table"
	data = type(data) == "table" and data or {}
	if not isNew then
		data.Version = data.Version or 1
		for v = data.Version + 1, DATA_VERSION do
			if MIGRATIONS[v] then
				MIGRATIONS[v](data)
			end
			data.Version = v
		end
	end
	data = reconcile(data, defaultData())
	data.Version = DATA_VERSION
	profiles[player] = data
	return data
end

function DataService.Get(player)
	return profiles[player]
end

function DataService.Save(player)
	local data = profiles[player]
	if not data or not storeOk or not store or readOnly[player] then
		return
	end
	-- Сохраняем актуальные потребности из атрибутов.
	for _, need in Config.NeedOrder do
		local v = player:GetAttribute(need)
		if v then
			data.Needs[need] = v
		end
	end
	local ok, err = pcall(function()
		store:UpdateAsync("p_" .. player.UserId, function(old)
			-- Не перезаписываем более новый формат старой версией сервера
			-- (во время обновления старые и новые серверы работают одновременно).
			if type(old) == "table" and (old.Version or 1) > DATA_VERSION then
				return nil
			end
			return data
		end)
	end)
	if not ok then
		warn("[Data] Ошибка сохранения: " .. tostring(err))
	end
end

function DataService.Release(player)
	DataService.Save(player)
	profiles[player] = nil
	readOnly[player] = nil
end

function DataService.IsReadOnly(player)
	return readOnly[player] == true
end

-- Деньги ----------------------------------------------------------------

local function syncMoney(player)
	local data = profiles[player]
	if data then
		player:SetAttribute("Cash", data.Cash)
		player:SetAttribute("Bank", data.Bank)
	end
end
DataService.SyncMoney = syncMoney

function DataService.AddCash(player, amount)
	local data = profiles[player]
	if not data then
		return false
	end
	data.Cash = math.max(0, math.floor(data.Cash + amount))
	if amount > 0 then
		data.Stats.Earned += amount
	end
	syncMoney(player)
	return true
end

-- Списывает деньги: сначала наличные, затем с карты.
function DataService.Spend(player, amount)
	local data = profiles[player]
	if not data or amount < 0 then
		return false
	end
	if data.Cash + data.Bank < amount then
		return false
	end
	local fromCash = math.min(data.Cash, amount)
	data.Cash -= fromCash
	data.Bank -= amount - fromCash
	syncMoney(player)
	return true
end

function DataService.Total(player)
	local data = profiles[player]
	return data and (data.Cash + data.Bank) or 0
end

-- Инвентарь -------------------------------------------------------------

function DataService.AddItem(player, item, count)
	local data = profiles[player]
	if not data then
		return
	end
	data.Inventory[item] = (data.Inventory[item] or 0) + (count or 1)
	if data.Inventory[item] <= 0 then
		data.Inventory[item] = nil
	end
end

function DataService.HasItem(player, item)
	local data = profiles[player]
	return data ~= nil and (data.Inventory[item] or 0) > 0
end

function DataService.TakeItem(player, item)
	if not DataService.HasItem(player, item) then
		return false
	end
	DataService.AddItem(player, item, -1)
	return true
end

function DataService.Init()
	if RunService:IsStudio() and storeOk then
		-- Проверяем, доступны ли DataStore в Studio.
		local ok = pcall(function()
			store:GetAsync("__probe")
		end)
		if not ok then
			storeOk = false
			warn("[Data] DataStore недоступен — прогресс не будет сохраняться. Включите Game Settings → Security → Enable Studio Access to API Services.")
		end
	end

	task.spawn(function()
		while true do
			task.wait(120)
			for _, player in Players:GetPlayers() do
				task.spawn(DataService.Save, player)
			end
		end
	end)

	game:BindToClose(function()
		local threads = 0
		for _, player in Players:GetPlayers() do
			threads += 1
			task.spawn(function()
				DataService.Save(player)
				threads -= 1
			end)
		end
		local start = os.clock()
		while threads > 0 and os.clock() - start < 20 do
			task.wait(0.1)
		end
	end)
end

return DataService
