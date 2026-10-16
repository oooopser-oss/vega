-- Монетизация: Game Passes (VIP, Премиум-гараж, Свадебный пакет),
-- Developer Products (игровые деньги, салют), ежедневный бонус и бонус
-- подписчикам Roblox Premium. Бонус за регистрацию тоже выдаётся здесь.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Util = require(script.Parent.Util)

local MonetizationService = {}
local ctx

local M = Config.Monetization

local function passById(id)
	for key, pass in M.GamePasses do
		if pass.Id ~= 0 and pass.Id == id then
			return key
		end
	end
	return nil
end

local function productById(id)
	for key, product in M.Products do
		if product.Id ~= 0 and product.Id == id then
			return key, product
		end
	end
	return nil
end

function MonetizationService.HasPass(player, key)
	return player:GetAttribute("Pass_" .. key) == true
end

-- Множитель зарплаты: VIP ×2, Roblox Premium +10%.
function MonetizationService.PayMultiplier(player)
	local mult = 1
	if MonetizationService.HasPass(player, "VIP") then
		mult *= 2
	end
	if player.MembershipType == Enum.MembershipType.Premium then
		mult *= 1 + M.PremiumPayBonus
	end
	return mult
end

function MonetizationService.Fireworks(player)
	local hrp = Util.HRP(player)
	if not hrp then
		return
	end
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, 6, 0)
	att.Parent = hrp
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 230, 90)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 160, 255)),
	})
	pe.LightEmission = 1
	pe.Rate = 120
	pe.Lifetime = NumberRange.new(1.5, 2.5)
	pe.Speed = NumberRange.new(25, 40)
	pe.SpreadAngle = Vector2.new(60, 60)
	pe.Acceleration = Vector3.new(0, -20, 0)
	pe.Size = NumberSequence.new(0.6, 0)
	pe.Parent = att
	task.delay(6, function()
		pe.Enabled = false
		task.delay(3, function()
			att:Destroy()
		end)
	end)
end

local function applyPass(player, key)
	player:SetAttribute("Pass_" .. key, true)
	if key == "VIP" then
		ctx.Players.UpdateNameplate(player)
	end
end

local function grantPassReward(player, key)
	-- Разовые награды при покупке пасса.
	if key == "Wedding" then
		ctx.Data.AddItem(player, "ring", 1)
		ctx.Economy.SendInventory(player)
	end
end

local function checkPasses(player)
	for key, pass in M.GamePasses do
		if pass.Id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and owns then
				applyPass(player, key)
			end
		end
	end
end

local function dailyBonus(player)
	local data = ctx.Data.Get(player)
	if not data then
		return
	end
	local today = math.floor(os.time() / 86400)
	if data.LastDaily == today then
		return
	end
	local streak = (data.LastDaily == today - 1) and ((data.DailyStreak or 0) + 1) or 1
	data.LastDaily = today
	data.DailyStreak = streak
	local amount = M.DailyBonus * math.min(streak, 7)
	if MonetizationService.HasPass(player, "VIP") then
		amount *= 2
	end
	data.Bank += amount
	ctx.Data.SyncMoney(player)
	ctx.Net.Notify(player, "🎁 Ежедневный бонус: +" .. amount .. "$ (день подряд: " .. streak .. ")", "good")
end

function MonetizationService.OnPlayerAdded(player)
	local data = ctx.Data.Get(player)
	if data and not data.RegistrationBonusGiven then
		data.RegistrationBonusGiven = true
		data.Bank += Config.RegistrationBonus
		ctx.Data.SyncMoney(player)
		ctx.Net.Send(player, "Toast", { Title = "Добро пожаловать в Первоуральск!", Text = "Бонус за регистрацию: +" .. Config.RegistrationBonus .. "$ на вашу карту." })
	end
	task.spawn(function()
		checkPasses(player)
		dailyBonus(player)
		-- Пасс «Модный гардероб» открывает премиум-одежду.
		if ctx.Clothing then
			ctx.Clothing.Send(player)
		end
	end)
end

function MonetizationService.Init(c)
	ctx = c

	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local data = player and ctx.Data.Get(player)
		if not data then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		data.Receipts = data.Receipts or {}
		if data.Receipts[receipt.PurchaseId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local _, product = productById(receipt.ProductId)
		if not product then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if product.Cash then
			data.Bank += product.Cash
			ctx.Data.SyncMoney(player)
			ctx.Net.Notify(player, "Спасибо за покупку! +" .. product.Cash .. "$ на карту.", "good")
		end
		if product.Clothing then
			ctx.Clothing.Grant(player, product.Clothing)
		end
		if product.Fireworks then
			MonetizationService.Fireworks(player)
			ctx.Net.NotifyAll("🎆 " .. player.DisplayName .. " запустил(а) салют над Первоуральском!", "info")
		end
		data.Receipts[receipt.PurchaseId] = true
		-- Сохраняем сразу, чтобы покупка не потерялась.
		ctx.Data.Save(player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passById(passId)
		if purchased and key then
			applyPass(player, key)
			grantPassReward(player, key)
			ctx.Clothing.Send(player)
			ctx.Net.Notify(player, "Спасибо! Пасс «" .. M.GamePasses[key].Name .. "» активирован.", "good")
		end
	end)

	ctx.Net.On("BuyPass", function(player, p)
		local pass = M.GamePasses[p.Key]
		if not pass then
			return
		end
		if pass.Id == 0 then
			ctx.Net.Notify(player, "Покупка ещё не настроена разработчиком (нет ID пасса).", "warn")
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
	end)

	ctx.Net.On("BuyProduct", function(player, p)
		local product = M.Products[p.Key]
		if not product then
			return
		end
		if product.Id == 0 then
			ctx.Net.Notify(player, "Покупка ещё не настроена разработчиком (нет ID товара).", "warn")
			return
		end
		MarketplaceService:PromptProductPurchase(player, product.Id)
	end)
end

return MonetizationService
