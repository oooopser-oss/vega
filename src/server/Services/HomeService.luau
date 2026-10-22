-- Обустройство дома: мебель (покупка, расстановка, перестановка, продажа),
-- отделка (стены, пол, крыша, забор), уют и польза мебели, гости.
-- Расстановка хранится в профиле владельца (data.Home) в координатах участка,
-- поэтому дом выглядит одинаково на любом сервере и после обновлений.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Furniture = require(Shared:WaitForChild("Furniture"))
local Util = require(script.Parent.Util)

local HomeService = {}
local ctx

local H = Config.Home
local defaults = {} -- [houseId] = { Wall = {Color, Material}, ... } — исходный вид дома
local comfort = {} -- [houseId] = 0..100
local useCooldown = {} -- [Player] = { [key] = os.clock() }

local function copyDefault()
	local list = {}
	for _, e in H.Default do
		table.insert(list, { Id = e.Id, X = e.X, Z = e.Z, R = e.R })
	end
	return list
end
HomeService.DefaultLayout = copyDefault

local function homeOf(data)
	if type(data.Home) ~= "table" then
		data.Home = {}
	end
	local home = data.Home
	if type(home.Items) ~= "table" then
		home.Items = copyDefault()
	end
	home.Style = type(home.Style) == "table" and home.Style or {}
	home.Unlocked = type(home.Unlocked) == "table" and home.Unlocked or {}
	home.Open = home.Open == true
	return home
end
HomeService.HomeOf = homeOf

local function ownerOf(house)
	return ctx.Housing.OwnerOf(house.Id)
end

local function ownerHome(house)
	local owner = ownerOf(house)
	local data = owner and ctx.Data.Get(owner)
	return data and homeOf(data) or nil, owner
end

local function rememberDefaults(house)
	if defaults[house.Id] then
		return
	end
	local d = {}
	for kind, parts in house.Styled do
		local first = parts[1]
		d[kind] = first and { Color = first.Color, Material = first.Material } or nil
	end
	defaults[house.Id] = d
end

local function applyStyle(house, style)
	rememberDefaults(house)
	for kind, parts in house.Styled do
		local choice = style and style[kind] and H.Styles[kind][style[kind]]
		local color = choice and choice.Color or (defaults[house.Id][kind] or {}).Color
		local material = choice and choice.Material and Enum.Material[choice.Material] or (defaults[house.Id][kind] or {}).Material
		for _, p in parts do
			if color then
				p.Color = color
			end
			if material then
				p.Material = material
			end
		end
	end
end

function HomeService.ComfortOf(house)
	return comfort[house.Id] or 0
end

-- Множитель восстановления потребностей дома: уют 100 → ×2.
function HomeService.ComfortMult(house)
	return 1 + (comfort[house.Id] or 0) / 100
end

function HomeService.IsOpen(house)
	local home = ownerHome(house)
	return home ~= nil and home.Open == true
end

local function onCooldown(player, key, seconds)
	useCooldown[player] = useCooldown[player] or {}
	local last = useCooldown[player][key]
	if last and os.clock() - last < seconds then
		return math.ceil(seconds - (os.clock() - last))
	end
	useCooldown[player][key] = os.clock()
	return nil
end

local function applyEffects(player, effects)
	for need, delta in effects or {} do
		ctx.Needs.Change(player, need, delta)
	end
end

local function useItem(player, house, entry, usePart)
	local item = H.Items[entry.Id]
	local use = item.Use
	if not ctx.Housing.CanUse(player, house) then
		ctx.Net.Notify(player, "Это не ваш дом.", "bad")
		return
	end
	local mult = HomeService.ComfortMult(house)
	if use.Type == "Sleep" then
		ctx.Needs.StartActivity(player, "Sleep", usePart, use.Need, use.Rate * mult, { Heal = true })
	elseif use.Type == "Shower" then
		ctx.Needs.StartActivity(player, "Shower", usePart, use.Need, use.Rate * mult)
	elseif use.Type == "Watch" then
		ctx.Needs.StartActivity(player, "TV", usePart, use.Need, use.Rate * mult, { Range = use.Range })
		ctx.Net.Notify(player, item.Name .. ": отойдите или нажмите «Встать», чтобы закончить.", "info")
	elseif use.Type == "Instant" then
		local wait = onCooldown(player, house.Id .. ":" .. entry.Id, use.Cooldown)
		if wait then
			ctx.Net.Notify(player, item.Name .. ": можно снова через " .. wait .. " сек.", "info")
			return
		end
		applyEffects(player, use.Effects)
		ctx.Net.Notify(player, "🏠 " .. use.Text .. " — готово!", "good")
	elseif use.Type == "Skill" then
		-- Кулдаун общий для навыка, чтобы несколько одинаковых вещей не ускоряли прокачку.
		local wait = onCooldown(player, "skill:" .. use.Skill, use.Cooldown)
		if wait then
			ctx.Net.Notify(player, "Отдохните немного: снова через " .. wait .. " сек.", "info")
			return
		end
		applyEffects(player, use.Effects)
		ctx.Progression.AddXP(player, use.Skill, use.XP)
	elseif use.Type == "Wardrobe" then
		ctx.Net.Send(player, "OpenPhone", { Tab = "Одежда 👕" })
	end
end

-- Перестраивает мебель и отделку дома по данным владельца (или стандартные).
function HomeService.Render(house)
	local home, owner = ownerHome(house)
	local items = home and home.Items or H.Default
	house.Furniture:ClearAllChildren()
	for i, entry in items do
		local item = H.Items[entry.Id]
		if item then
			local model, usePart = Furniture.Build(entry.Id, Furniture.ItemCFrame(house.Base, entry))
			model:SetAttribute("FurnIndex", i)
			model:SetAttribute("HouseId", house.Id)
			model.Parent = house.Furniture
			if item.Use and owner then
				local pp = ctx.WorldBuilder.MakePrompt(usePart, item.Use.Text, item.Name, 0.3, 8)
				pp.Triggered:Connect(function(player)
					useItem(player, house, entry, usePart)
				end)
			end
		end
	end
	applyStyle(house, home and home.Style)
	comfort[house.Id] = home and Furniture.Comfort(home.Items) or 0
	if owner then
		HomeService.SyncComfort(house)
	end
end

function HomeService.SyncComfort(house)
	local owner = ownerOf(house)
	if not owner then
		return
	end
	for _, p in Players:GetPlayers() do
		if ctx.Housing.AccessibleHouse(p) == house then
			p:SetAttribute("HomeComfort", comfort[house.Id] or 0)
		end
	end
	owner:SetAttribute("HomeComfort", comfort[house.Id] or 0)
end

local function hasDesigner(player)
	return ctx.Monetization.HasPass(player, "Designer")
end

function HomeService.Send(player)
	local house = ctx.Housing.AccessibleHouse(player)
	if not house then
		ctx.Net.Send(player, "Home", { HouseId = 0 })
		return
	end
	local home, owner = ownerHome(house)
	if not home then
		return
	end
	local myData = ctx.Data.Get(player)
	local unlocked = {}
	for id, item in H.Items do
		if item.Robux then
			unlocked[id] = hasDesigner(player) or (myData and homeOf(myData).Unlocked[id] == true) or home.Unlocked[id] == true
		end
	end
	local _, yaw = house.Base:ToOrientation()
	ctx.Net.Send(player, "Home", {
		HouseId = house.Id,
		Base = { X = house.Base.Position.X, Z = house.Base.Position.Z, Yaw = math.deg(yaw) },
		Items = home.Items,
		Style = home.Style,
		Unlocked = unlocked,
		Designer = hasDesigner(player),
		Open = home.Open,
		Comfort = comfort[house.Id] or 0,
		IsOwner = owner == player,
	})
end

local function sendAll(house)
	for _, p in Players:GetPlayers() do
		if ctx.Housing.AccessibleHouse(p) == house then
			HomeService.Send(p)
		end
	end
end

-- Дом, который игрок может обустраивать (свой или супруга), и его данные.
local function editable(player, needNear)
	local house = ctx.Housing.AccessibleHouse(player)
	if not house then
		ctx.Net.Notify(player, "Сначала купите дом в агентстве недвижимости (мэрия).", "bad")
		return nil
	end
	local home = ownerHome(house)
	if not home then
		return nil
	end
	if needNear then
		local hrp = Util.HRP(player)
		if not hrp or (hrp.Position - house.Center).Magnitude > H.EditRange then
			ctx.Net.Notify(player, "Обустраивать дом можно, только находясь у себя на участке.", "bad")
			return nil
		end
	end
	return house, home
end

local function changed(house)
	HomeService.Render(house)
	sendAll(house)
	local owner = ownerOf(house)
	if owner then
		ctx.Data.Save(owner)
	end
end

function HomeService.Unlock(player, id)
	local data = ctx.Data.Get(player)
	if not data or not H.Items[id] then
		return
	end
	homeOf(data).Unlocked[id] = true
	ctx.Net.Notify(player, "⭐ «" .. H.Items[id].Name .. "» теперь ваша! Поставьте её в режиме обустройства дома.", "good")
	HomeService.Send(player)
end

local function canPlacePremium(player, home, id)
	local data = ctx.Data.Get(player)
	return hasDesigner(player) or home.Unlocked[id] == true or (data ~= nil and homeOf(data).Unlocked[id] == true)
end

local function place(player, p)
	local house, home = editable(player, true)
	if not house then
		return
	end
	local id = p.Item
	local item = type(id) == "string" and H.Items[id]
	if not item then
		return
	end
	if #home.Items >= H.MaxItems then
		ctx.Net.Notify(player, "В доме уже " .. H.MaxItems .. " вещей — больше не поместится. Продайте что-нибудь.", "bad")
		return
	end
	local x, z, r = Furniture.Snap(tonumber(p.X) or 0/0), Furniture.Snap(tonumber(p.Z) or 0/0), tonumber(p.R) or 0
	local ok, reason = Furniture.Check(home.Items, id, x, z, r)
	if not ok then
		ctx.Net.Notify(player, reason, "bad")
		return
	end
	if item.Robux then
		if not canPlacePremium(player, home, id) then
			ctx.Net.Notify(player, "«" .. item.Name .. "» — премиум-вещь. Купите её за Robux или пасс «Дизайнер интерьеров».", "bad")
			return
		end
		-- Покупка за Robux открывает вещь для дома владельца.
		home.Unlocked[id] = true
	elseif not ctx.Data.Spend(player, item.Price) then
		ctx.Net.Notify(player, "Не хватает денег: «" .. item.Name .. "» стоит " .. item.Price .. "$.", "bad")
		return
	end
	table.insert(home.Items, { Id = id, X = x, Z = z, R = r })
	ctx.Net.Notify(player, "🛋 «" .. item.Name .. "» на месте! Уют дома: " .. Furniture.Comfort(home.Items), "good")
	ctx.Quests.Progress(player, "decor", 1)
	changed(house)
end

local function move(player, p)
	local house, home = editable(player, true)
	if not house then
		return
	end
	local index = tonumber(p.Index)
	local entry = index and home.Items[index]
	if not entry then
		return
	end
	local x, z, r = Furniture.Snap(tonumber(p.X) or 0/0), Furniture.Snap(tonumber(p.Z) or 0/0), tonumber(p.R) or 0
	local ok, reason = Furniture.Check(home.Items, entry.Id, x, z, r, index)
	if not ok then
		ctx.Net.Notify(player, reason, "bad")
		changed(house)
		return
	end
	entry.X, entry.Z, entry.R = x, z, r
	changed(house)
end

local function sell(player, p)
	local house, home = editable(player, false)
	if not house then
		return
	end
	local index = tonumber(p.Index)
	local entry = index and home.Items[index]
	if not entry then
		return
	end
	local item = H.Items[entry.Id]
	table.remove(home.Items, index)
	if item and item.Price then
		local refund = math.floor(item.Price * H.SellRefund)
		local data = ctx.Data.Get(player)
		data.Bank += refund
		ctx.Data.SyncMoney(player)
		ctx.Net.Notify(player, "«" .. item.Name .. "» продан(а). +" .. refund .. "$ на карту.", "info")
	elseif item then
		ctx.Net.Notify(player, "«" .. item.Name .. "» убран(а) на склад — премиум-вещь можно поставить снова бесплатно.", "info")
	end
	changed(house)
end

local function setStyle(player, p)
	local house, home = editable(player, false)
	if not house then
		return
	end
	local kind = p.Kind
	local list = type(kind) == "string" and H.Styles[kind]
	local index = tonumber(p.Index)
	if not list or not index or (index ~= 0 and not list[index]) then
		return
	end
	if (home.Style[kind] or 0) == index then
		return
	end
	if index > 0 and not hasDesigner(player) then
		local choice = list[index]
		if not ctx.Data.Spend(player, choice.Price) then
			ctx.Net.Notify(player, "Не хватает денег: отделка стоит " .. choice.Price .. "$.", "bad")
			return
		end
	end
	home.Style[kind] = index > 0 and index or nil
	ctx.Net.Notify(player, "🎨 " .. H.Styles.Names[kind] .. ": " .. (index > 0 and list[index].Name or "как было") .. ".", "good")
	changed(house)
end

function HomeService.OnPlayerRemoving(player)
	useCooldown[player] = nil
end

function HomeService.Init(c)
	ctx = c
	for _, house in ctx.World.Houses do
		HomeService.Render(house)
	end
	ctx.Net.On("GetHome", HomeService.Send)
	ctx.Net.On("HomePlace", place)
	ctx.Net.On("HomeMove", move)
	ctx.Net.On("HomeSell", sell)
	ctx.Net.On("HomeStyle", setStyle)
	ctx.Net.On("HomeOpen", function(player, p)
		local house, home = editable(player, false)
		if not house then
			return
		end
		home.Open = p.Open == true
		ctx.Net.Notify(player, home.Open and "🚪 Дом открыт для гостей: дверь может открыть любой." or "🔒 Дом закрыт: войти могут только жильцы.", "info")
		sendAll(house)
	end)
	Players.PlayerRemoving:Connect(HomeService.OnPlayerRemoving)
end

return HomeService
