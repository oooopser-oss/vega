-- Автотест гардероба: покупка за $, премиум без оплаты недоступен, пасс, надеть/снять.
-- Запуск: cd tests && lune run clothing
local H = require("./harness")
local place = H.place
local PlayersStub = { GetPlayers = function() return {} end, PlayerRemoving = H.signal() }
local gameObj = { GetService = function(_, n) return ({ Players = PlayersStub })[n] or H.wrap(place:GetService(n)) end }
local env, req = H.makeEnv(gameObj)
local svc = H.wrap(place:GetService("ServerScriptService")).Server.Services
local C = req(svc.ClothingService)
local data = { Cash = 500, Bank = 0, Wardrobe = {} }
local passes, sent, handlers = {}, {}, {}
local player = { Name = "T", UserId = 1, Character = nil }
C.Init({
	Data = { Get = function() return data end, Spend = function(_, a) if data.Cash >= a then data.Cash -= a return true end return false end },
	Net = { On = function(n, f) handlers[n] = f end, Send = function(_, n, p) sent[n] = p end, Notify = function() end },
	Monetization = { HasPass = function(_, k) return passes[k] == true end },
})
assert(C.Owns(player, "tee_white"), "бесплатная вещь должна быть доступна")
assert(not C.Owns(player, "crown"), "премиум без оплаты недоступен")
handlers.Clothing(player, { Op = "buy", Item = "crown" })
assert(not data.Wardrobe.crown, "премиум нельзя купить за $")
handlers.Clothing(player, { Op = "buy", Item = "cap" })
assert(data.Wardrobe.cap and data.Cash == 400 and data.Outfit.Hat == "cap", "покупка кепки")
handlers.Clothing(player, { Op = "buy", Item = "tophat" })
assert(not data.Wardrobe.tophat and data.Cash == 400, "не хватает денег на цилиндр")
handlers.Clothing(player, { Op = "wear", Item = "wings" })
assert(not (data.Outfit.Accessory == "wings"), "нельзя надеть некупленное")
C.Grant(player, "wings") -- покупка за Robux
assert(data.Outfit.Accessory == "wings", "после покупки за Robux надето")
passes.Fashion = true
assert(C.Owns(player, "gold_suit"), "пасс открывает премиум")
handlers.Clothing(player, { Op = "remove", Slot = "Hat" })
assert(data.Outfit.Hat == nil, "снять")
handlers.Clothing(player, { Op = "avatar" })
assert(data.Outfit == nil and sent.Wardrobe, "вернуть аватар")
print("CLOTHING OK")
require("@lune/process").exit(0)
