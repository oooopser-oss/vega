-- Отношения между игроками: знакомство → дружба → свидания → отношения →
-- помолвка (кольцо) → свадьба в ЗАГСе → брак (общий дом). Можно расстаться
-- или развестись.

local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Util = require(script.Parent.Util)

local SocialService = {}
local ctx

local S = Config.Social
local cooldowns = {} -- [Player] = { [key] = time }
local requests = {} -- [id] = { From, To, Act, Expires }
local nextRequest = 0

local PHRASES = {
	talk = { "Привет! Как дела?", "Чем занимаешься?", "Классная погода сегодня!", "Давно тут живёшь?", "Где работаешь?" },
	joke = { "Почему программисты путают Хэллоуин и Рождество? 31 OCT = 25 DEC!", "Я на диете: ем только то, что вижу. Поэтому иду в супермаркет!", "Мой кот — лучший слушатель: никогда не перебивает." },
	compliment = { "Ты сегодня отлично выглядишь!", "С тобой так интересно!", "У тебя классный стиль!", "Ты очень добрый человек!" },
	hug = { "*обнимает*" },
	kiss = { "*целует* ❤" },
	flowers = { "Это тебе! 💐" },
	chocolate = { "Угощайся! 🍫" },
}

local function key(userId)
	return tostring(userId)
end

local function relOf(player, otherId, otherName)
	local data = ctx.Data.Get(player)
	if not data then
		return nil
	end
	local k = key(otherId)
	local r = data.Relations[k]
	if not r then
		r = { Points = 0, Status = "none", Name = otherName }
		data.Relations[k] = r
	end
	if otherName then
		r.Name = otherName
	end
	return r
end

function SocialService.SendRelations(player)
	local data = ctx.Data.Get(player)
	if not data then
		return
	end
	local list = {}
	for k, r in data.Relations do
		local online = Players:GetPlayerByUserId(tonumber(k))
		table.insert(list, { UserId = tonumber(k), Name = r.Name, Points = r.Points, Status = r.Status, Online = online ~= nil })
	end
	table.sort(list, function(a, b)
		return a.Points > b.Points
	end)
	ctx.Net.Send(player, "Relations", { List = list, Partner = data.Partner and tonumber(data.Partner) or nil })
end

local function applyPartnerAttributes(player)
	local data = ctx.Data.Get(player)
	if not data then
		return
	end
	if data.Partner then
		local r = data.Relations[data.Partner]
		player:SetAttribute("PartnerName", r and r.Name or "")
		player:SetAttribute("RelStatus", r and r.Status or "")
	else
		player:SetAttribute("PartnerName", "")
		player:SetAttribute("RelStatus", "")
	end
end

local function setPartner(data, otherKey, status)
	if status ~= "none" then
		data.Partner = otherKey
	elseif data.Partner == otherKey then
		data.Partner = nil
	end
end

-- Обновляет запись об отношениях с обеих сторон (вторая сторона может быть офлайн).
local function setPair(a, bId, bName, points, status)
	local ra = relOf(a, bId, bName)
	if not ra then
		return
	end
	ra.Points = math.clamp(points, 0, 100)
	if status then
		ra.Status = status
	end
	local dataA = ctx.Data.Get(a)
	if status then
		setPartner(dataA, key(bId), status)
	end
	local b = Players:GetPlayerByUserId(bId)
	if b then
		local rb = relOf(b, a.UserId, a.DisplayName)
		local dataB = ctx.Data.Get(b)
		if rb and dataB then
			rb.Points = ra.Points
			if status then
				rb.Status = status
				setPartner(dataB, key(a.UserId), status)
			end
		end
		applyPartnerAttributes(b)
		SocialService.SendRelations(b)
		ctx.Housing.RefreshFor(b)
	end
	applyPartnerAttributes(a)
	SocialService.SendRelations(a)
	ctx.Housing.RefreshFor(a)
end

local function bubble(player, act)
	local list = PHRASES[act]
	if list and player.Character then
		ctx.Net.Broadcast("Bubble", { Character = player.Character, Text = list[math.random(1, #list)] })
	end
end

local function hearts(player, seconds)
	local hrp = Util.HRP(player)
	if not hrp then
		return
	end
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 90, 150))
	pe.Rate = 12
	pe.Lifetime = NumberRange.new(1, 1.5)
	pe.Speed = NumberRange.new(2, 4)
	pe.SpreadAngle = Vector2.new(30, 30)
	pe.Size = NumberSequence.new(0.6, 0)
	pe.Parent = hrp
	task.delay(seconds or 3, function()
		pe.Enabled = false
		task.delay(2, function()
			pe:Destroy()
		end)
	end)
end

local function confetti(part, seconds)
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, 8, 0)
	att.Parent = part
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 180)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 220, 90)),
	})
	pe.Rate = 80
	pe.Lifetime = NumberRange.new(2, 4)
	pe.Speed = NumberRange.new(10, 20)
	pe.SpreadAngle = Vector2.new(70, 70)
	pe.Acceleration = Vector3.new(0, -12, 0)
	pe.Size = NumberSequence.new(0.4)
	pe.Parent = att
	task.delay(seconds, function()
		pe.Enabled = false
		task.delay(5, function()
			att:Destroy()
		end)
	end)
end

local function onCooldown(player, k, seconds)
	cooldowns[player] = cooldowns[player] or {}
	local last = cooldowns[player][k]
	if last and os.clock() - last < seconds then
		return true
	end
	cooldowns[player][k] = os.clock()
	return false
end

local function atChurch(player)
	local church = ctx.World.Church
	local pos = Util.Position(player)
	return pos ~= nil and (pos - church.Center).Magnitude <= church.Radius
end

-- Применяет действие (после согласия, если оно требуется).
local function apply(a, b, actId)
	local act = S.Actions[actId]
	local ra = relOf(a, b.UserId, b.DisplayName)
	if not ra then
		return
	end
	local Net = ctx.Net
	if actId == "ask_out" then
		setPair(a, b.UserId, b.DisplayName, ra.Points + 10, "dating")
		hearts(a, 4)
		hearts(b, 4)
		Net.Notify(a, b.DisplayName .. " согласился(ась) встречаться с вами! ❤", "good")
		Net.Notify(b, "Теперь вы встречаетесь с " .. a.DisplayName .. "! ❤", "good")
		return
	elseif actId == "propose" then
		if not ctx.Data.TakeItem(a, "ring") then
			Net.Notify(a, "Кольцо пропало из инвентаря!", "bad")
			return
		end
		ctx.Economy.SendInventory(a)
		setPair(a, b.UserId, b.DisplayName, ra.Points + 10, "engaged")
		hearts(a, 6)
		hearts(b, 6)
		Net.NotifyAll("💎 " .. a.DisplayName .. " сделал(а) предложение " .. b.DisplayName .. ", и получил(а) ответ «ДА»!", "good")
		return
	elseif actId == "wedding" then
		if not (atChurch(a) and atChurch(b)) then
			Net.Notify(a, "Вы оба должны быть в ЗАГСе.", "bad")
			return
		end
		local freeWedding = ctx.Monetization.HasPass(a, "Wedding") or ctx.Monetization.HasPass(b, "Wedding")
		if not freeWedding and not ctx.Data.Spend(a, act.Cost) then
			Net.Notify(a, "Недостаточно денег на свадьбу (" .. act.Cost .. "$).", "bad")
			return
		end
		if freeWedding then
			ctx.Monetization.Fireworks(a)
			ctx.Monetization.Fireworks(b)
		end
		setPair(a, b.UserId, b.DisplayName, 100, "married")
		confetti(ctx.World.Church.Altar, 15)
		hearts(a, 10)
		hearts(b, 10)
		ctx.Needs.Change(a, "Fun", 50)
		ctx.Needs.Change(b, "Fun", 50)
		Net.NotifyAll("💒 Свадьба! " .. a.DisplayName .. " и " .. b.DisplayName .. " теперь муж и жена / супруги! Поздравляем!", "good")
		Net.Send(a, "Toast", { Title = "Свадьба!", Text = "Теперь у вас общий дом (если он есть у одного из вас)." })
		Net.Send(b, "Toast", { Title = "Свадьба!", Text = "Теперь у вас общий дом (если он есть у одного из вас)." })
		return
	elseif actId == "date" then
		if not ctx.Data.Spend(a, act.Cost) then
			Net.Notify(a, "Недостаточно денег на свидание.", "bad")
			return
		end
		ctx.Needs.Change(a, "Fun", act.Fun)
		ctx.Needs.Change(b, "Fun", act.Fun)
		ctx.Needs.Change(a, "Hunger", 25)
		ctx.Needs.Change(b, "Hunger", 25)
		hearts(a, 3)
		hearts(b, 3)
		Net.Notify(a, "Отличное свидание с " .. b.DisplayName .. "!", "good")
		Net.Notify(b, "Отличное свидание с " .. a.DisplayName .. "!", "good")
	end
	local gain = act.Points or 0
	if (a:GetAttribute("Hygiene") or 100) < 20 then
		gain = math.floor(gain / 2)
		Net.Notify(a, "От вас неприятно пахнет — отношения улучшаются медленнее. Примите душ!", "warn")
	end
	setPair(a, b.UserId, b.DisplayName, ra.Points + gain, nil)
	if gain > 0 then
		Net.Notify(a, act.Name .. ": +" .. gain .. " к отношениям с " .. b.DisplayName .. " (" .. math.floor(ra.Points) .. "/100)", "good")
	end
end

local function statusAllowed(act, status)
	if not act.RequiresStatus then
		return true
	end
	return table.find(act.RequiresStatus, status) ~= nil
end

local function handleSocial(a, p)
	local actId = p.Act
	local act = S.Actions[actId]
	local targetId = tonumber(p.Target)
	if not act or not targetId or targetId == a.UserId then
		return
	end
	local Net = ctx.Net
	local dataA = ctx.Data.Get(a)
	if not dataA then
		return
	end
	local b = Players:GetPlayerByUserId(targetId)

	-- Расставание/развод работает и когда партнёр не в сети.
	if actId == "breakup" or actId == "divorce" then
		local r = dataA.Relations[key(targetId)]
		if not r or not statusAllowed(act, r.Status) then
			return
		end
		setPair(a, targetId, r.Name, r.Points - 30, "none")
		Net.Notify(a, (actId == "divorce" and "Вы развелись с " or "Вы расстались с ") .. r.Name .. ".", "info")
		if b then
			Net.Notify(b, a.DisplayName .. (actId == "divorce" and " подал(а) на развод. Брак расторгнут." or " расстался(ась) с вами. 💔"), "bad")
		end
		return
	end

	if not b then
		Net.Notify(a, "Этого игрока нет на сервере.", "bad")
		return
	end
	if not Util.Alive(a) or not Util.Alive(b) then
		return
	end
	if act.AtChurch then
		if not (atChurch(a) and atChurch(b)) then
			Net.Notify(a, "Расписаться можно только в ЗАГСе — приходите туда вдвоём (см. GPS).", "bad")
			return
		end
	elseif Util.Distance(a, b) > S.MaxDistance then
		Net.Notify(a, "Подойдите ближе к " .. b.DisplayName .. ".", "bad")
		return
	end
	local r = relOf(a, b.UserId, b.DisplayName)
	if r.Points < act.MinPoints then
		Net.Notify(a, "Нужно больше симпатии (" .. act.MinPoints .. "+, сейчас " .. math.floor(r.Points) .. ").", "bad")
		return
	end
	if not statusAllowed(act, r.Status) then
		Net.Notify(a, "Это действие сейчас недоступно (" .. (S.StatusNames[r.Status] or r.Status) .. ").", "bad")
		return
	end
	if actId == "ask_out" then
		local dataB = ctx.Data.Get(b)
		if dataA.Partner or (dataB and dataB.Partner) then
			Net.Notify(a, "Кто-то из вас уже в отношениях.", "bad")
			return
		end
	end
	if act.Item and not ctx.Data.HasItem(a, act.Item) then
		Net.Notify(a, "Нужен предмет: " .. Config.Items[act.Item].Name .. ". Купите в цветочном киоске.", "bad")
		return
	end
	local paidByPass = actId == "wedding" and (ctx.Monetization.HasPass(a, "Wedding") or ctx.Monetization.HasPass(b, "Wedding"))
	if act.Cost and not paidByPass and ctx.Data.Total(a) < act.Cost then
		Net.Notify(a, "Нужно " .. act.Cost .. "$.", "bad")
		return
	end
	if onCooldown(a, actId .. ":" .. b.UserId, act.NeedsAccept and 15 or S.Cooldown) then
		Net.Notify(a, "Не так быстро! Подождите немного.", "info")
		return
	end

	if act.GiveMoney then
		local data = ctx.Data.Get(a)
		if data.Cash < act.GiveMoney then
			Net.Notify(a, "Нужно " .. act.GiveMoney .. "$ наличными.", "bad")
			return
		end
		ctx.Data.AddCash(a, -act.GiveMoney)
		ctx.Data.AddCash(b, act.GiveMoney)
		Net.Notify(a, "Вы передали " .. act.GiveMoney .. "$ игроку " .. b.DisplayName, "info")
		Net.Notify(b, a.DisplayName .. " передал(а) вам " .. act.GiveMoney .. "$", "good")
		setPair(a, b.UserId, b.DisplayName, r.Points + 2, nil)
		return
	end

	if act.NeedsAccept then
		nextRequest += 1
		requests[nextRequest] = { From = a, To = b, Act = actId, Expires = os.clock() + 30 }
		local texts = {
			date = a.DisplayName .. " приглашает вас на свидание!",
			ask_out = a.DisplayName .. " предлагает вам встречаться! ❤",
			propose = a.DisplayName .. " встаёт на одно колено и делает вам предложение! 💍",
			wedding = a.DisplayName .. " готов(а) сыграть свадьбу прямо сейчас! 💒",
		}
		Net.Send(b, "Request", { Id = nextRequest, From = a.DisplayName, Text = texts[actId] or act.Name })
		Net.Notify(a, "Запрос отправлен. Ждём ответа " .. b.DisplayName .. "...", "info")
		return
	end

	if act.Item then
		ctx.Data.TakeItem(a, act.Item)
		ctx.Data.AddItem(b, act.Item, 1)
		ctx.Economy.SendInventory(a)
		ctx.Economy.SendInventory(b)
		Net.Notify(b, a.DisplayName .. " подарил(а) вам: " .. Config.Items[act.Item].Name, "good")
	end
	if act.Fun then
		ctx.Needs.Change(a, "Fun", act.Fun)
		ctx.Needs.Change(b, "Fun", act.Fun)
	end
	if actId == "hug" or actId == "kiss" then
		hearts(a, 2)
		hearts(b, 2)
	end
	bubble(a, actId)
	ctx.Quests.Progress(a, "talk", 1)
	ctx.Needs.Change(a, "Fun", 2)
	ctx.Needs.Change(b, "Fun", 2)
	apply(a, b, actId)
end

function SocialService.OnPlayerAdded(player)
	local data = ctx.Data.Get(player)
	if data and data.Partner then
		local partner = Players:GetPlayerByUserId(tonumber(data.Partner))
		local pdata = partner and ctx.Data.Get(partner)
		if pdata and pdata.Partner ~= key(player.UserId) then
			-- Партнёр расстался с нами, пока мы были не в сети.
			local r = data.Relations[data.Partner]
			if r then
				r.Status = "none"
			end
			data.Partner = nil
			ctx.Net.Notify(player, "Пока вас не было, ваши отношения закончились. 💔", "bad")
		end
	end
	-- Если кто-то из онлайн-игроков считает нас партнёром, а мы его — нет.
	for _, other in Players:GetPlayers() do
		local od = other ~= player and ctx.Data.Get(other)
		if od and od.Partner == key(player.UserId) and (not data or data.Partner ~= key(other.UserId)) then
			local r = od.Relations[od.Partner]
			if r then
				r.Status = "none"
			end
			od.Partner = nil
			applyPartnerAttributes(other)
			SocialService.SendRelations(other)
		end
	end
	applyPartnerAttributes(player)
	SocialService.SendRelations(player)
	if data and data.Partner then
		local partner = Players:GetPlayerByUserId(tonumber(data.Partner))
		if partner then
			SocialService.SendRelations(partner)
			ctx.Housing.RefreshFor(partner)
			ctx.Net.Notify(partner, player.DisplayName .. " зашёл(ла) в город! ❤", "good")
		end
	end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local od = ctx.Data.Get(other)
			if od and od.Relations[key(player.UserId)] then
				SocialService.SendRelations(other)
			end
		end
	end
end

function SocialService.OnPlayerRemoving(player)
	cooldowns[player] = nil
	for id, req in requests do
		if req.From == player or req.To == player then
			requests[id] = nil
		end
	end
	task.defer(function()
		for _, other in Players:GetPlayers() do
			local od = ctx.Data.Get(other)
			if od and od.Relations[key(player.UserId)] then
				SocialService.SendRelations(other)
				ctx.Housing.RefreshFor(other)
			end
		end
	end)
end

function SocialService.Init(c)
	ctx = c
	ctx.Net.On("Social", handleSocial)
	ctx.Net.On("Respond", function(player, p)
		local req = requests[tonumber(p.Id)]
		if not req or req.To ~= player then
			return
		end
		requests[tonumber(p.Id)] = nil
		if os.clock() > req.Expires or not req.From.Parent then
			ctx.Net.Notify(player, "Запрос устарел.", "info")
			return
		end
		if p.Accept then
			apply(req.From, player, req.Act)
		else
			ctx.Net.Notify(req.From, player.DisplayName .. " отказал(а)... 💔", "bad")
			local r = relOf(req.From, player.UserId, player.DisplayName)
			if r then
				setPair(req.From, player.UserId, player.DisplayName, r.Points - 3, nil)
			end
		end
	end)
end

return SocialService
