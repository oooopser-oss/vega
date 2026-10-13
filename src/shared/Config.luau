-- Общие настройки игры «Жизнь Города».
-- Здесь можно менять цены, зарплаты, скорость голода и т.д. без правки логики.

local Config = {}

Config.GameName = "Жизнь Города: Первоуральск"

Config.StartCash = 500
Config.StartBank = 1000
-- Бонус каждому игроку за регистрацию (первый вход), зачисляется на карту.
Config.RegistrationBonus = 10000

-- Роли игроков (каждая роль = команда Roblox).
Config.Roles = {
	Citizen = {
		Name = "Мирный житель",
		Color = Color3.fromRGB(80, 170, 255),
		Description = "Работайте кассиром, поваром, в офисе, грузчиком или курьером. Стройте семью и карьеру.",
		Jobs = { "cashier", "cook", "office", "loader", "courier" },
		Spawn = "CityHall",
		MaxPlayers = 0, -- 0 = без ограничений
	},
	Police = {
		Name = "Полиция",
		Color = Color3.fromRGB(40, 70, 200),
		Description = "Патрулируйте город, ловите преступников (наручники и электрошокер), получайте премии за задержания.",
		Jobs = { "patrol" },
		Spawn = "PoliceStation",
		Tools = { "Handcuffs", "Taser" },
		CanArrest = true,
		ArrestBonus = 120,
		MaxPlayers = 6,
	},
	SWAT = {
		Name = "Спецслужбы",
		Color = Color3.fromRGB(25, 25, 35),
		Description = "Элитное подразделение: опасные преступники (3+ звезды), ограбления банка. Выше зарплата и премии.",
		Jobs = { "special" },
		Spawn = "PoliceStation",
		Tools = { "Handcuffs", "Taser" },
		CanArrest = true,
		ArrestBonus = 200,
		MaxPlayers = 3,
	},
	Medic = {
		Name = "Медик",
		Color = Color3.fromRGB(240, 80, 90),
		Description = "Лечите жителей аптечкой и принимайте пациентов в больнице.",
		Jobs = { "doctor" },
		Spawn = "Hospital",
		Tools = { "Medkit" },
		MaxPlayers = 5,
	},
	Criminal = {
		Name = "Преступник",
		Color = Color3.fromRGB(150, 60, 160),
		Description = "Грабьте магазины и банк, но берегитесь полиции: розыск растёт, а тюрьма — это потерянное время.",
		Jobs = { "loader" },
		Spawn = "Hideout",
		Tools = { "Bat" },
		MaxPlayers = 6,
	},
}
Config.RoleOrder = { "Citizen", "Police", "SWAT", "Medic", "Criminal" }
Config.RoleChangeCooldown = 60

-- Работы. type:
--   "station"  — подойти к рабочему месту и выполнить действие;
--   "delivery" — забрать груз в точке A и отнести в точку B.
-- Duration — сколько секунд удерживать E; Cooldown — пауза до следующего
-- задания (например, ждать нового покупателя). Так деньги нельзя «накликать».
Config.Jobs = {
	cashier = { Name = "Кассир", Place = "Supermarket", Type = "station", Pay = 20, Action = "Обслужить покупателя", Duration = 4, Cooldown = 12, WaitText = "Ждём следующего покупателя" },
	cook = { Name = "Повар", Place = "Cafe", Type = "delivery", Pay = 35, Pickup = "Приготовить блюдо", Drop = "Отдать заказ", Duration = 5, Cooldown = 8, WaitText = "Ждём новый заказ" },
	office = { Name = "Офисный работник", Place = "Office", Type = "station", Pay = 40, Action = "Составить отчёт", Duration = 8, Cooldown = 15, WaitText = "Ждём новую задачу от начальника" },
	loader = { Name = "Грузчик", Place = "Factory", Type = "delivery", Pay = 35, Pickup = "Взять ящик", Drop = "Погрузить ящик", Duration = 2, Cooldown = 5, WaitText = "Ждём следующую партию" },
	courier = { Name = "Курьер", Place = "Factory", Type = "courier", Pay = 70, Pickup = "Забрать посылку", Drop = "Доставить посылку", Duration = 2, Cooldown = 5, WaitText = "Посылку упаковывают" },
	patrol = { Name = "Патрульный", Place = "Patrol", Type = "station", Pay = 45, Action = "Отметиться на посту", Duration = 2, Cooldown = 20, WaitText = "Патрулируйте район" },
	special = { Name = "Оперативник", Place = "Patrol", Type = "station", Pay = 60, Action = "Проверить периметр", Duration = 2, Cooldown = 20, WaitText = "Ожидайте вызова" },
	doctor = { Name = "Врач", Place = "Hospital", Type = "station", Pay = 45, Action = "Осмотреть пациента", Duration = 6, Cooldown = 12, WaitText = "Ждём следующего пациента" },
}

-- Ограничения заработка на работе.
Config.Work = {
	ShiftTasks = 15, -- заданий за смену
	ShiftRest = 240, -- секунд отдыха после смены
	DailyCap = 5000, -- $ в сутки по полной ставке
	OverCapMultiplier = 0.25, -- после лимита платят 25%
}

-- Потребности (0..100). Decay — сколько теряется за минуту.
Config.Needs = {
	Hunger = { Name = "Сытость", Decay = 2.2, Color = Color3.fromRGB(255, 170, 60) },
	Energy = { Name = "Энергия", Decay = 1.6, Color = Color3.fromRGB(90, 200, 255) },
	Hygiene = { Name = "Гигиена", Decay = 1.3, Color = Color3.fromRGB(120, 230, 200) },
	Fun = { Name = "Настроение", Decay = 1.4, Color = Color3.fromRGB(255, 110, 200) },
}
Config.NeedOrder = { "Hunger", "Energy", "Hygiene", "Fun" }
Config.WorkEnergyCost = 1.5 -- доп. расход энергии за одно рабочее задание

-- Предметы. Effects — изменение потребностей при использовании.
Config.Items = {
	bread = { Name = "Хлеб", Price = 15, Effects = { Hunger = 20 } },
	burger = { Name = "Бургер", Price = 40, Effects = { Hunger = 45, Fun = 5 } },
	pizza = { Name = "Пицца", Price = 60, Effects = { Hunger = 60, Fun = 10 } },
	salad = { Name = "Салат", Price = 30, Effects = { Hunger = 30, Hygiene = 3 } },
	water = { Name = "Вода", Price = 5, Effects = { Hunger = 5, Energy = 3 } },
	coffee = { Name = "Кофе", Price = 20, Effects = { Energy = 25, Hunger = 3 } },
	cake = { Name = "Торт", Price = 90, Effects = { Hunger = 35, Fun = 25 } },
	soap = { Name = "Мыло", Price = 25, Effects = { Hygiene = 40 } },
	flowers = { Name = "Букет цветов", Price = 50, Gift = true },
	chocolate = { Name = "Конфеты", Price = 40, Gift = true, Effects = { Hunger = 10, Fun = 10 } },
	ring = { Name = "Обручальное кольцо", Price = 1500, Gift = true },
}

Config.Shops = {
	Supermarket = { Name = "Супермаркет", Items = { "bread", "salad", "water", "coffee", "soap", "chocolate", "pizza" } },
	Cafe = { Name = "Пельменная", Items = { "burger", "pizza", "coffee", "cake", "water" } },
	Florist = { Name = "Цветы и подарки", Items = { "flowers", "chocolate", "ring" } },
}

Config.Cars = {
	sedan = { Name = "Седан", Price = 3000, Speed = 60, Color = Color3.fromRGB(200, 200, 210) },
	suv = { Name = "Внедорожник", Price = 6500, Speed = 65, Color = Color3.fromRGB(60, 90, 60) },
	sport = { Name = "Спорткар", Price = 15000, Speed = 95, Color = Color3.fromRGB(220, 30, 30) },
	limo = { Name = "Лимузин (Премиум-гараж)", Price = 0, Speed = 80, Color = Color3.fromRGB(15, 15, 20), Pass = "PremiumGarage" },
	police = { Name = "Патрульная машина", Price = 0, Speed = 85, Color = Color3.fromRGB(240, 240, 255), Police = true, Hidden = true },
}
Config.CarOrder = { "sedan", "suv", "sport", "limo" }

-- Такси: мгновенная поездка к месту из GPS.
Config.Taxi = { Base = 20, PerStud = 0.03, Max = 150 }
function Config.TaxiPrice(distance)
	return math.min(Config.Taxi.Max, math.floor(Config.Taxi.Base + distance * Config.Taxi.PerStud))
end

Config.HousePrice = 7500
Config.HouseSellRefund = 0.5

-- Отношения: очки 0..100.
Config.Social = {
	MaxDistance = 14,
	Cooldown = 8, -- секунд между действиями с одним и тем же человеком
	Actions = {
		talk = { Name = "Поговорить", Points = 3, MinPoints = 0 },
		joke = { Name = "Пошутить", Points = 4, MinPoints = 5, Fun = 5 },
		compliment = { Name = "Сделать комплимент", Points = 5, MinPoints = 10 },
		hug = { Name = "Обнять", Points = 6, MinPoints = 20 },
		flowers = { Name = "Подарить цветы", Points = 12, MinPoints = 15, Item = "flowers" },
		chocolate = { Name = "Подарить конфеты", Points = 8, MinPoints = 10, Item = "chocolate" },
		date = { Name = "Пригласить на свидание (100$)", Points = 15, MinPoints = 25, Cost = 100, NeedsAccept = true, Fun = 20 },
		kiss = { Name = "Поцеловать", Points = 8, MinPoints = 0, RequiresStatus = { "dating", "engaged", "married" } },
		ask_out = { Name = "Предложить встречаться", MinPoints = 40, NeedsAccept = true, RequiresStatus = { "none" } },
		propose = { Name = "Сделать предложение (кольцо)", MinPoints = 70, NeedsAccept = true, Item = "ring", RequiresStatus = { "dating" } },
		wedding = { Name = "Расписаться в ЗАГСе (1000$)", MinPoints = 70, NeedsAccept = true, Cost = 1000, RequiresStatus = { "engaged" }, AtChurch = true },
		breakup = { Name = "Расстаться", MinPoints = 0, RequiresStatus = { "dating", "engaged" } },
		divorce = { Name = "Развестись", MinPoints = 0, RequiresStatus = { "married" } },
		give_money = { Name = "Дать 100$", MinPoints = 0, GiveMoney = 100 },
	},
	ActionOrder = { "talk", "joke", "compliment", "hug", "chocolate", "flowers", "date", "kiss", "ask_out", "propose", "wedding", "give_money", "breakup", "divorce" },
	StatusNames = {
		none = "Знакомые",
		dating = "Встречаются",
		engaged = "Помолвлены",
		married = "В браке",
	},
}

Config.Crime = {
	JailSecondsPerStar = 30,
	WantedDecaySeconds = 150, -- через сколько секунд без преступлений снимается 1 звезда
	Robberies = {
		Supermarket = { Name = "кассу супермаркета", Min = 250, Max = 500, Stars = 2, Duration = 8, Cooldown = 180 },
		Cafe = { Name = "кассу кафе", Min = 200, Max = 400, Stars = 2, Duration = 8, Cooldown = 180 },
		Bank = { Name = "хранилище банка", Min = 1500, Max = 3000, Stars = 4, Duration = 20, Cooldown = 420 },
	},
	BatDamage = 18,
	TaserStun = 4,
}

Config.DeathHospitalBill = 150

-- Ежедневные задания: каждый день игрок получает 3 новых задания.
-- Goals — варианты цели; Reward — награда за единицу цели (округляется).
-- Role — задание выпадает только этой роли.
Config.Quests = {
	PerDay = 3,
	AllDoneBonus = 1500, -- бонус за выполнение всех заданий дня
	Pool = {
		work = { Text = "Выполните %d рабочих заданий", Goals = { 5, 8, 12 }, Reward = 60 },
		earn = { Text = "Заработайте %d$ на работе", Goals = { 300, 600, 900 }, Reward = 0.8 },
		eat = { Text = "Поешьте %d раз(а)", Goals = { 2, 3 }, Reward = 120 },
		shop = { Text = "Сделайте %d покупки в магазинах", Goals = { 2, 3 }, Reward = 120 },
		sleep = { Text = "Выспитесь (поспите до полной энергии)", Goals = { 1 }, Reward = 400 },
		shower = { Text = "Примите душ до полной гигиены", Goals = { 1 }, Reward = 300 },
		talk = { Text = "Пообщайтесь с жителями %d раз(а)", Goals = { 3, 5, 8 }, Reward = 90 },
		fun = { Text = "Отдохните %d раз(а) (парк, скамейки, кафе)", Goals = { 2, 4 }, Reward = 110 },
		visit = { Text = "Посетите: %s", Goals = { 1 }, Reward = 450 },
		drive = { Text = "Проедьте на машине %d м", Goals = { 1500, 3000 }, Reward = 0.25 },
		arrest = { Text = "Задержите %d преступника(ов)", Goals = { 1, 2 }, Reward = 500, Role = { "Police", "SWAT" } },
		heal = { Text = "Окажите помощь %d пациентам", Goals = { 2, 4 }, Reward = 200, Role = { "Medic" } },
		rob = { Text = "Совершите %d ограбление(я) и не попадитесь", Goals = { 1, 2 }, Reward = 400, Role = { "Criminal" } },
	},
}

-- Монетизация (см. MONETIZATION.md). ID создаются в Creator Hub:
-- Game Passes / Developer Products. Пока ID = 0, покупка отключена.
Config.Monetization = {
	GamePasses = {
		VIP = { Id = 0, Name = "VIP-житель", Robux = 299, Description = "Зарплата ×2, ежедневный бонус ×2, золотой ник над головой." },
		PremiumGarage = { Id = 0, Name = "Премиум-гараж", Robux = 399, Description = "Эксклюзивный чёрный лимузин в гараже." },
		Wedding = { Id = 0, Name = "Свадебный пакет", Robux = 149, Description = "Бесплатная регистрация брака, салют и кольцо в подарок." },
	},
	PassOrder = { "VIP", "PremiumGarage", "Wedding" },
	Products = {
		Cash10k = { Id = 0, Name = "10 000$ на карту", Robux = 49, Cash = 10000 },
		Cash50k = { Id = 0, Name = "50 000$ на карту", Robux = 199, Cash = 50000 },
		Cash200k = { Id = 0, Name = "200 000$ на карту", Robux = 599, Cash = 200000 },
		Fireworks = { Id = 0, Name = "Праздничный салют", Robux = 25, Fireworks = true },
	},
	ProductOrder = { "Cash10k", "Cash50k", "Cash200k", "Fireworks" },
	DailyBonus = 500, -- ежедневный бонус за вход (VIP получает ×2)
	PremiumPayBonus = 0.1, -- +10% к зарплате для подписчиков Roblox Premium
}
Config.DayLengthMinutes = 16 -- длина игровых суток в реальных минутах

return Config
