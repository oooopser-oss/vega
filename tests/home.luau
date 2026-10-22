-- Автотест обустройства дома: стандартная мебель, покупка и расстановка,
-- запреты (вне дома, на кровати, поверх другой вещи), перестановка,
-- продажа, отделка, премиум-вещи, уют и польза мебели.
-- Запуск: cd tests && lune run home
local H = require("./harness")
local place = H.place
local PlayersStub = { GetPlayers = function() return {} end, PlayerRemoving = H.signal() }
local gameObj = { GetService = function(_, n) return ({ Players = PlayersStub })[n] or H.wrap(place:GetService(n)) end }
local env, req = H.makeEnv(gameObj)
local server = H.wrap(place:GetService("ServerScriptService")).Server
local shared = H.wrap(place:GetService("ReplicatedStorage")).Shared
local Config = req(shared.Config)
local Furniture = req(shared.Furniture)
local Home = req(server.Services.HomeService)
local Instance, CFrame, Vector3, Color3 = env.Instance, env.CFrame, env.Vector3, env.Color3

local function mk(color)
	local p = Instance.new("Part")
	p.Color = color
	return p
end
local wallColor = Color3.fromRGB(230, 200, 160)
local house = {
	Id = 1,
	Base = CFrame.new(100, 0, 50) * CFrame.Angles(0, math.rad(90), 0),
	Center = Vector3.new(100, 0, 50),
	Styled = { Wall = { mk(wallColor), mk(wallColor) }, Floor = { mk(Color3.new(0.5, 0.4, 0.3)) }, Roof = { mk(Color3.new(0.6, 0.2, 0.2)) }, Fence = { mk(Color3.new(1, 1, 1)) } },
	Furniture = Instance.new("Model"),
}

local attrs = { Fun = 50, Hunger = 50, Energy = 50 }
local hrp = { Position = Vector3.new(100, 3, 50) }
local player = { Name = "T", DisplayName = "T", UserId = 1, Parent = true,
	Character = { FindFirstChild = function(_, n) return n == "HumanoidRootPart" and hrp or nil end },
	GetAttribute = function(_, k) return attrs[k] end, SetAttribute = function(_, k, v) attrs[k] = v end }
local data = { Cash = 10000, Bank = 0, HasHouse = true, Home = { Style = {}, Unlocked = {}, Open = false } }
local notes, last, handlers, prompts, xp, saved = {}, {}, {}, {}, {}, 0
local passes = {}
local ctx = {
	World = { Houses = { house } },
	Data = { Get = function() return data end, Save = function() saved += 1 end, SyncMoney = function() end,
		Spend = function(_, a) if data.Cash + data.Bank >= a then data.Cash -= a return true end return false end },
	Net = { On = function(n, f) handlers[n] = f end, Send = function(_, n, p) last[n] = p end, Notify = function(_, t) table.insert(notes, t) end },
	Needs = { Change = function(_, need, d) attrs[need] = (attrs[need] or 0) + d end, StartActivity = function(_, kind, part, need, rate) last.Activity = { Kind = kind, Need = need, Rate = rate } end },
	Quests = { Progress = function(_, kind) last.Quest = kind end },
	Progression = { AddXP = function(_, skill, amount) xp[skill] = (xp[skill] or 0) + amount end },
	Monetization = { HasPass = function(_, key) return passes[key] == true end },
	WorldBuilder = { MakePrompt = function(parent, action) local pp = { Triggered = H.signal(), Action = action, Parent = parent } table.insert(prompts, pp) return pp end },
}
local owner = nil
ctx.Housing = {
	OwnerOf = function() return owner end,
	AccessibleHouse = function(p) return owner == p and house or nil end,
	CanUse = function(p) return owner == p end,
}
Home.Init(ctx)

-- 1) Ничейный дом: стандартная мебель без подсказок.
assert(#house.Furniture:GetChildren() == #Config.Home.Default, "стандартная мебель в продаваемом доме")
assert(#prompts == 0, "в чужом доме мебель не используется")

-- 2) Игрок купил дом: та же мебель, данные создаются.
owner = player
Home.Render(house)
handlers.GetHome(player)
local h = last.Home
assert(h and h.HouseId == 1 and #h.Items == #Config.Home.Default and h.IsOwner, "данные дома отправлены")
assert(math.abs(h.Base.Yaw - 90) < 0.01 and h.Base.X == 100, "положение участка")
local comfort0 = attrs.HomeComfort
assert(comfort0 and comfort0 > 0, "уют от стандартной мебели: " .. tostring(comfort0))

-- 3) Покупка и расстановка.
handlers.HomePlace(player, { Item = "bookshelf", X = 0, Z = -15, R = 0 })
assert(#data.Home.Items == #Config.Home.Default + 1, "книжный шкаф поставлен: " .. tostring(notes[#notes]))
assert(data.Cash == 10000 - 500, "оплата шкафа")
assert(last.Quest == "decor", "задание «обустроить дом»")
assert(attrs.HomeComfort == comfort0 + 3, "уют вырос")

-- запреты
local before = #data.Home.Items
handlers.HomePlace(player, { Item = "armchair", X = -9, Z = -12, R = 0 }) -- на кровати
handlers.HomePlace(player, { Item = "armchair", X = 0, Z = -15, R = 0 }) -- поверх шкафа
handlers.HomePlace(player, { Item = "grill", X = 0, Z = -10, R = 0 }) -- мангал в доме
handlers.HomePlace(player, { Item = "sofa", X = 30, Z = 0, R = 0 }) -- за забором
handlers.HomePlace(player, { Item = "armchair", X = 0 / 0, Z = 0, R = 0 }) -- NaN
handlers.HomePlace(player, { Item = "armchair", X = 0, Z = -10, R = 7 }) -- плохой поворот
assert(#data.Home.Items == before and data.Cash == 9500, "запрещённые места отклонены: " .. notes[#notes])

-- ковёр (плоский) можно класть под мебель
handlers.HomePlace(player, { Item = "rug", X = 0, Z = -12.5, R = 0 })
assert(#data.Home.Items == before + 1, "ковёр под мебелью")

-- поворот меняет занятое место: беговая дорожка 3×6 повёрнутая встаёт в узкий проход
local okR = Furniture.Check(data.Home.Items, "treadmill", -1, -12, 1)
local okN = Furniture.Check(data.Home.Items, "treadmill", -1, -12, 0)
assert(okR and not okN, "поворот учитывается")

-- 4) Перестановка и продажа.
local shelfIndex = #Config.Home.Default + 1
handlers.HomeMove(player, { Index = shelfIndex, X = 2, Z = -15, R = 0 })
assert(data.Home.Items[shelfIndex].X == 2, "шкаф переставлен")
handlers.HomeMove(player, { Index = shelfIndex, X = -9, Z = -12, R = 0 })
assert(data.Home.Items[shelfIndex].X == 2, "перестановка на кровать отклонена")
local cash = data.Cash + data.Bank
handlers.HomeSell(player, { Index = 1 }) -- диван из стандартного набора
assert(data.Cash + data.Bank == cash + 300, "продажа дивана за 50%")

-- 5) Отделка: стены, затем возврат исходного вида.
handlers.HomeStyle(player, { Kind = "Wall", Index = 3 })
assert(house.Styled.Wall[1].Color == Config.Home.Styles.Wall[3].Color and data.Home.Style.Wall == 3, "стены перекрашены")
handlers.HomeStyle(player, { Kind = "Wall", Index = 0 })
assert(house.Styled.Wall[2].Color == wallColor and data.Home.Style.Wall == nil, "исходный цвет")
handlers.HomeStyle(player, { Kind = "Floor", Index = 3 })
assert(tostring(house.Styled.Floor[1].Material):find("Marble"), "мраморный пол")
handlers.HomeStyle(player, { Kind = "Nope", Index = 1 })

-- 6) Премиум: без покупки нельзя, после покупки — бесплатно.
local cashP = data.Cash
handlers.HomePlace(player, { Item = "piano", X = -1, Z = -9.5, R = 0 })
assert(notes[#notes]:find("премиум"), "рояль без покупки нельзя")
Home.Unlock(player, "piano")
handlers.HomePlace(player, { Item = "piano", X = -1, Z = -9.5, R = 0 })
assert(data.Home.Items[#data.Home.Items].Id == "piano" and data.Cash == cashP, "рояль поставлен бесплатно: " .. notes[#notes])

-- 7) Польза: рояль даёт опыт «Музыки», повтор сразу — нет.
local pianoPrompt
for _, pp in prompts do
	if pp.Action == "Сыграть на рояле" then
		pianoPrompt = pp
	end
end
assert(pianoPrompt, "у рояля есть подсказка")
pianoPrompt.Triggered:Fire(player)
assert(xp.Music == 10, "опыт музыки")
pianoPrompt.Triggered:Fire(player)
assert(xp.Music == 10, "кулдаун навыка")

-- 8) Далеко от дома обустраивать нельзя.
hrp.Position = Vector3.new(400, 3, 400)
local n = #data.Home.Items
handlers.HomePlace(player, { Item = "plant", X = 5, Z = -1, R = 0 })
assert(#data.Home.Items == n, "вне участка нельзя")

-- 9) Гости.
handlers.HomeOpen(player, { Open = true })
assert(Home.IsOpen(house), "дом открыт для гостей")
assert(saved > 0, "изменения сохраняются")
print("items", #data.Home.Items, "comfort", attrs.HomeComfort, "cash", data.Cash)
print("HOME OK")
require("@lune/process").exit(0)
