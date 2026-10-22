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
		RequiresSkills = { Strength = 2, Stamina = 2 }, -- тренируйтесь в спорткомплексе и на стадионе
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
	office = { Name = "Офисный работник", Place = "Office", Type = "station", Pay = 40, Action = "Составить отчёт", Duration = 8, Cooldown = 15, WaitText = "Ждём новую задачу от начальника", Requires = "School" },
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
	umbrella = { Name = "Зонт", Price = 120, Passive = "Защищает от дождя и снега на улице" },
	ring = { Name = "Обручальное кольцо", Price = 1500, Gift = true },
	shawarma = { Name = "Шаурма", Price = 45, Effects = { Hunger = 40, Fun = 4 } },
	pie = { Name = "Пирожок", Price = 20, Effects = { Hunger = 18 } },
	protein = { Name = "Протеиновый батончик", Price = 35, Effects = { Energy = 15, Hunger = 10 } },
	book = { Name = "Книга", Price = 60, Effects = { Fun = 15 } },
	rod = { Name = "Удочка", Price = 150, Passive = "Нужна для рыбалки на пруду" },
	guitar = { Name = "Гитара", Price = 500, Passive = "Играйте на улице и получайте чаевые" },
	fish_crucian = { Name = "Карась", Price = 0, SellPrice = 25, Effects = { Hunger = 15 } },
	fish_perch = { Name = "Окунь", Price = 0, SellPrice = 40, Effects = { Hunger = 20 } },
	fish_pike = { Name = "Щука", Price = 0, SellPrice = 90, Effects = { Hunger = 30 } },
	fish_catfish = { Name = "Сом", Price = 0, SellPrice = 250, Effects = { Hunger = 45, Fun = 10 } },
}

Config.Shops = {
	Supermarket = { Name = "Супермаркет", Items = { "bread", "salad", "water", "coffee", "soap", "chocolate", "pizza", "umbrella" } },
	Cafe = { Name = "Пельменная", Items = { "burger", "pizza", "coffee", "cake", "water" } },
	Florist = { Name = "Цветы и подарки", Items = { "flowers", "chocolate", "ring" } },
	Sports = { Name = "Спортивный магазин", Items = { "protein", "water", "rod" } },
	Culture = { Name = "Лавка Дома культуры", Items = { "book", "guitar", "coffee" } },
	Kiosk = { Name = "Киоск", Items = { "shawarma", "pie", "coffee", "water" } },
}

Config.Cars = {
	sedan = { Name = "Седан", Price = 3000, Speed = 60, Color = Color3.fromRGB(200, 200, 210) },
	suv = { Name = "Внедорожник", Price = 6500, Speed = 65, Color = Color3.fromRGB(60, 90, 60) },
	sport = { Name = "Спорткар", Price = 15000, Speed = 95, Color = Color3.fromRGB(220, 30, 30) },
	limo = { Name = "Лимузин (Премиум-гараж)", Price = 0, Speed = 80, Color = Color3.fromRGB(15, 15, 20), Pass = "PremiumGarage" },
	school = { Name = "Учебная машина", Price = 0, Speed = 45, Color = Color3.fromRGB(245, 245, 245), Hidden = true },
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
		train = { Text = "Позанимайтесь в секциях %d раз(а) (спорткомплекс, стадион)", Goals = { 2, 3 }, Reward = 150 },
		study = { Text = "Посетите %d урок(а) в лицее или колледже", Goals = { 1, 2 }, Reward = 250 },
		fish = { Text = "Поймайте %d рыб(ы) на пруду", Goals = { 2, 4 }, Reward = 120 },
		decor = { Text = "Обустройте дом: поставьте %d вещь(и) мебели", Goals = { 1, 2 }, Reward = 150, NeedsHouse = true },
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

-- Погода. Меняется каждые MinDuration..MaxDuration секунд, вероятности
-- зависят от сезона (по текущему месяцу). Temp — температура при ясном дне
-- летом; к ней добавляется поправка сезона и ночи.
Config.Weather = {
	MinDuration = 240,
	MaxDuration = 480,
	Types = {
		Clear = { Name = "Ясно", Icon = "☀", Temp = 22, Cloud = 0.3, Density = 0.28, Haze = 1.2, Brightness = 3, Saturation = 0.12,
			Message = "Распогодилось! Отличное время для прогулки." },
		Cloudy = { Name = "Облачно", Icon = "☁", Temp = 18, Cloud = 0.8, Density = 0.34, Haze = 2, Brightness = 2.3, Saturation = 0.02,
			Message = "Небо затянуло облаками." },
		Rain = { Name = "Дождь", Icon = "🌧", Temp = 15, Cloud = 0.95, Density = 0.42, Haze = 2.6, Brightness = 1.6, Saturation = -0.1, Precip = "rain",
			Message = "Начался дождь. Зонт или крыша спасут настроение." },
		Storm = { Name = "Гроза", Icon = "⛈", Temp = 17, Cloud = 1, Density = 0.5, Haze = 3.2, Brightness = 1.1, Saturation = -0.2, Precip = "rain", Heavy = true, Lightning = true,
			Message = "Гроза! Лучше переждать в помещении." },
		Fog = { Name = "Туман", Icon = "🌫", Temp = 12, Cloud = 0.7, Density = 0.75, Haze = 7, Brightness = 1.8, Saturation = -0.08,
			Message = "Город окутал туман. Водите осторожно." },
		Snow = { Name = "Снег", Icon = "❄", Temp = 0, Cloud = 0.9, Density = 0.45, Haze = 3, Brightness = 2.3, Saturation = -0.05, Precip = "snow", Cold = true,
			Message = "Пошёл снег! На улице холодно — одевайтесь теплее." },
	},
	Seasons = {
		summer = { Name = "лето", TempOffset = 0, Weights = { Clear = 5, Cloudy = 3, Rain = 2, Storm = 1, Fog = 1 } },
		autumn = { Name = "осень", TempOffset = -10, Weights = { Clear = 2, Cloudy = 4, Rain = 3, Storm = 0.5, Fog = 2, Snow = 0.7 } },
		winter = { Name = "зима", TempOffset = -26, Weights = { Clear = 3, Cloudy = 3, Fog = 1, Snow = 4 } },
		spring = { Name = "весна", TempOffset = -9, Weights = { Clear = 3, Cloudy = 3, Rain = 2, Fog = 1, Snow = 0.5 } },
	},
	NightTempOffset = -5,
	-- Влияние на игроков без крыши над головой и без зонта (за 3 секунды).
	WetFunLoss = 0.25,
	ColdEnergyLoss = 0.2,
	-- Скорость городских машин и доля прохожих в плохую погоду.
	TrafficSpeed = { Rain = 0.85, Storm = 0.7, Fog = 0.6, Snow = 0.65 },
	PedestrianShare = { Rain = 0.4, Storm = 0.2, Snow = 0.6, Fog = 0.8 },
	-- Звуки (по желанию): ID звуков из Creator Store, например "rbxassetid://...".
	Sounds = { Rain = "", Thunder = "" },
}

function Config.Season(month)
	if month == 12 or month <= 2 then
		return "winter"
	elseif month <= 5 then
		return "spring"
	elseif month <= 8 then
		return "summer"
	end
	return "autumn"
end

-- Одежда. Slot: Top (торс и рукава), Bottom (ноги), Hat (голова), Accessory.
-- Price — цена в игровых $, Robux — премиум-вещь за Robux (ID товара в
-- Config.Monetization.Products с ключом "Cloth_<id>"). Kind — форма шапки
-- или аксессуара (см. shared/Outfits.luau). Logo — надпись на спине.
Config.Clothing = {
	SlotOrder = { "Top", "Bottom", "Hat", "Accessory" },
	SlotNames = { Top = "Верх", Bottom = "Низ", Hat = "Головной убор", Accessory = "Аксессуар" },
	Items = {
		-- Верх
		tee_white = { Slot = "Top", Name = "Белая футболка", Price = 0, Color = Color3.fromRGB(240, 240, 238) },
		tee_red = { Slot = "Top", Name = "Красная футболка", Price = 150, Color = Color3.fromRGB(200, 50, 50) },
		tee_blue = { Slot = "Top", Name = "Синяя футболка", Price = 150, Color = Color3.fromRGB(50, 90, 180) },
		sweater = { Slot = "Top", Name = "Вязаный свитер", Price = 400, Color = Color3.fromRGB(120, 80, 60), Material = Enum.Material.Fabric },
		suit = { Slot = "Top", Name = "Деловой пиджак", Price = 900, Color = Color3.fromRGB(35, 40, 55), Material = Enum.Material.Fabric },
		hoodie_perv = { Slot = "Top", Name = "Худи «Первоуральск»", Robux = 49, Color = Color3.fromRGB(240, 120, 30), Material = Enum.Material.Fabric, Logo = "ПЕРВОУРАЛЬСК" },
		leather = { Slot = "Top", Name = "Кожаная куртка", Robux = 59, Color = Color3.fromRGB(28, 26, 26), Material = Enum.Material.Leather },
		neon_jacket = { Slot = "Top", Name = "Неоновая куртка", Robux = 79, Color = Color3.fromRGB(40, 230, 255), Material = Enum.Material.Neon },
		gold_suit = { Slot = "Top", Name = "Золотой костюм", Robux = 149, Color = Color3.fromRGB(230, 185, 60), Material = Enum.Material.Foil },
		-- Низ
		jeans = { Slot = "Bottom", Name = "Джинсы", Price = 0, Color = Color3.fromRGB(45, 70, 120) },
		black_pants = { Slot = "Bottom", Name = "Чёрные брюки", Price = 200, Color = Color3.fromRGB(25, 25, 30) },
		khaki = { Slot = "Bottom", Name = "Брюки хаки", Price = 250, Color = Color3.fromRGB(150, 135, 95) },
		track = { Slot = "Bottom", Name = "Спортивные штаны", Price = 180, Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Fabric },
		neon_pants = { Slot = "Bottom", Name = "Неоновые брюки", Robux = 59, Color = Color3.fromRGB(255, 60, 200), Material = Enum.Material.Neon },
		-- Головные уборы
		cap = { Slot = "Hat", Name = "Кепка", Price = 100, Kind = "cap", Color = Color3.fromRGB(200, 40, 40) },
		beanie = { Slot = "Hat", Name = "Шапка с помпоном", Price = 120, Kind = "beanie", Color = Color3.fromRGB(60, 120, 200) },
		ushanka = { Slot = "Hat", Name = "Шапка-ушанка", Price = 300, Kind = "ushanka", Color = Color3.fromRGB(110, 80, 55) },
		cowboy = { Slot = "Hat", Name = "Ковбойская шляпа", Price = 350, Kind = "cowboy", Color = Color3.fromRGB(150, 100, 55) },
		headphones = { Slot = "Hat", Name = "Наушники", Price = 400, Kind = "headphones", Color = Color3.fromRGB(30, 30, 35) },
		tophat = { Slot = "Hat", Name = "Цилиндр", Price = 500, Kind = "tophat", Color = Color3.fromRGB(20, 20, 22) },
		crown = { Slot = "Hat", Name = "Золотая корона", Robux = 199, Kind = "crown", Color = Color3.fromRGB(245, 200, 60) },
		halo = { Slot = "Hat", Name = "Нимб", Robux = 99, Kind = "halo", Color = Color3.fromRGB(255, 240, 150) },
		-- Аксессуары
		glasses = { Slot = "Accessory", Name = "Очки", Price = 150, Kind = "glasses", Color = Color3.fromRGB(20, 20, 20) },
		scarf = { Slot = "Accessory", Name = "Шарф", Price = 180, Kind = "scarf", Color = Color3.fromRGB(190, 40, 50) },
		backpack = { Slot = "Accessory", Name = "Рюкзак", Price = 250, Kind = "backpack", Color = Color3.fromRGB(60, 100, 70) },
		star_glasses = { Slot = "Accessory", Name = "Звёздные очки", Robux = 39, Kind = "star_glasses", Color = Color3.fromRGB(255, 80, 200) },
		gold_chain = { Slot = "Accessory", Name = "Золотая цепь", Robux = 69, Kind = "chain", Color = Color3.fromRGB(245, 200, 60) },
		wings = { Slot = "Accessory", Name = "Крылья ангела", Robux = 249, Kind = "wings", Color = Color3.fromRGB(250, 250, 255) },
	},
	-- Порядок в каталоге.
	Order = {
		"tee_white", "tee_red", "tee_blue", "sweater", "suit", "hoodie_perv", "leather", "neon_jacket", "gold_suit",
		"jeans", "black_pants", "khaki", "track", "neon_pants",
		"cap", "beanie", "ushanka", "cowboy", "headphones", "tophat", "crown", "halo",
		"glasses", "scarf", "backpack", "star_glasses", "gold_chain", "wings",
	},
}

-- Премиум-одежда продаётся как Developer Products «Cloth_<id>» (ID = 0 — не настроено).
for id, item in Config.Clothing.Items do
	if item.Robux then
		Config.Monetization.Products["Cloth_" .. id] = { Id = 0, Name = item.Name, Robux = item.Robux, Clothing = id }
	end
end
Config.Monetization.GamePasses.Fashion = { Id = 0, Name = "Модный гардероб", Robux = 499, Description = "Вся премиум-одежда навсегда: куртки, корона, нимб, крылья и другое." }
table.insert(Config.Monetization.PassOrder, "Fashion")

-- Навыки: 5 уровней, опыт за занятия в секциях и мини-игры.
Config.Skills = {
	Order = { "Strength", "Boxing", "Stamina", "Football", "Intellect", "Music", "Driving", "Fishing" },
	Levels = { 100, 250, 450, 700, 1000 }, -- опыт для уровней 1..5
	List = {
		Strength = { Name = "Сила", Icon = "💪", Where = "Спорткомплекс «КОСМОС»: тренажёры", Perk = "+5% к оплате грузчика и курьера, +2 к удару битой за уровень" },
		Boxing = { Name = "Бокс", Icon = "🥊", Where = "Спорткомплекс «КОСМОС»: ринг и груши", Perk = "−0,4 с оглушения шокером, +2 к удару за уровень" },
		Stamina = { Name = "Выносливость", Icon = "🏃", Where = "Центральный стадион: беговая дорожка", Perk = "+0,5 к скорости бега, −5% расхода энергии за уровень" },
		Football = { Name = "Футбол", Icon = "⚽", Where = "Центральный стадион: забивайте голы", Perk = "+8% к силе удара по мячу за уровень" },
		Intellect = { Name = "Интеллект", Icon = "🧠", Where = "Лицей №21 (уроки) и шахматный клуб в Доме культуры", Perk = "+6% к оплате офиса за уровень" },
		Music = { Name = "Музыка", Icon = "🎸", Where = "Дом культуры: уроки гитары", Perk = "Чаевые за игру на улице: +40% за уровень" },
		Driving = { Name = "Вождение", Icon = "🚗", Where = "Автошкола: экзамены и практика", Perk = "+3% к скорости машины за уровень" },
		Fishing = { Name = "Рыбалка", Icon = "🎣", Where = "Нижнешайтанский пруд", Perk = "Чаще клюёт крупная рыба" },
	},
}

-- Занятия (мини-игры). Type: timing — нажать вовремя, targets — быстро
-- кликать по мишеням, sequence — повторить последовательность (память),
-- rhythm — ритм-игра, quiz — вопросы.
Config.Activities = {
	gym = { Name = "Тренажёр", Type = "timing", Rounds = 6, Skill = "Strength", XP = 12, Cost = 15, Needs = { Energy = -6, Hunger = -3, Fun = 3 }, Cooldown = 20 },
	boxing = { Name = "Боксёрская груша", Type = "targets", Duration = 15, Skill = "Boxing", XP = 2.5, Cost = 20, Needs = { Energy = -8, Hunger = -3, Fun = 4 }, Cooldown = 25 },
	chess = { Name = "Шахматный кружок", Type = "sequence", Skill = "Intellect", XP = 10, Cost = 0, Needs = { Fun = 6 }, Cooldown = 20 },
	guitar = { Name = "Урок гитары", Type = "rhythm", Duration = 20, Skill = "Music", XP = 1.6, Cost = 10, Needs = { Fun = 8 }, Cooldown = 25 },
	shooting = { Name = "Тир", Type = "targets", Duration = 20, Cost = 10, Needs = { Fun = 12 }, Cooldown = 15, Prizes = { { 25, 60 }, { 15, 25 } } },
	fishing = { Name = "Рыбалка", Type = "timing", Rounds = 1, Wait = true, Skill = "Fishing", XP = 15, Cost = 0, Needs = { Fun = 5 }, Cooldown = 6, Item = "rod" },
	lesson = { Name = "Урок в лицее", Type = "quiz", Bank = "School", Questions = 5, Pass = 3, Skill = "Intellect", XP = 15, Cost = 0, Needs = { Fun = -2, Energy = -3 }, Cooldown = 45 },
	college = { Name = "Лекция в колледже", Type = "quiz", Bank = "College", Questions = 5, Pass = 4, Skill = "Intellect", XP = 20, Cost = 100, Needs = { Energy = -4 }, Cooldown = 60, Requires = "School" },
	theory = { Name = "Теория ПДД (экзамен)", Type = "quiz", Bank = "Traffic", Questions = 10, Pass = 8, Skill = "Driving", XP = 5, Cost = 300, Cooldown = 30 },
}

Config.Education = {
	SchoolLessons = 5, -- уроков до аттестата
	CollegeLessons = 6, -- лекций до диплома
	DiplomaPayBonus = 0.15, -- +15% к зарплате на любой работе
}

-- Рыба: шанс зависит от уровня рыбалки.
Config.Fish = {
	{ Item = "fish_crucian", Weight = 50 },
	{ Item = "fish_perch", Weight = 30 },
	{ Item = "fish_pike", Weight = 14, PerLevel = 3 },
	{ Item = "fish_catfish", Weight = 3, PerLevel = 2 },
}

Config.Busking = { Interval = 6, MinTip = 3, MaxTip = 9, DailyCap = 900 }

-- Обустройство дома: мебель, отделка, уют.
-- Координаты — в системе участка (центр участка 0,0; фасад дома смотрит в +Z).
-- Size = { ширина по X, глубина по Z } до поворота; Zone "in" — в доме, "out" — во дворе.
-- Flat — плоские вещи (ковёр, картина): не мешают другой мебели.
-- Use — польза: Sleep/Shower/Watch — длительное занятие, Instant — разовый эффект,
-- Skill — опыт навыка, Wardrobe — переодевание. Robux — премиум (товар «Furn_<id>»).
Config.Home = {
	MaxItems = 45,
	SellRefund = 0.5,
	EditRange = 45, -- как далеко от центра участка можно расставлять мебель
	FloorY = { In = 1.15, Out = 0.2 },
	Zones = {
		In = { -14, 14, -16, 4 },
		Out = { -22.3, 22.3, -22.3, 22.3 },
	},
	-- Встроенные вещи дома (кровать, душ, ТВ, холодильник, кухня, проход у двери) и двор.
	Blocked = {
		In = { { -12, -6, -16, -7 }, { 9, 14, -16, -11 }, { 5.5, 12.5, 2.8, 4 }, { -14, -10.75, 0.25, 3.75 }, { -14, -10.75, -7.5, -0.5 }, { -3, 3, 2, 4 } },
		Out = { { -16, 16, -18, 6 }, { -6.5, 6.5, 5, 10 }, { -2.5, 2.5, 5, 23 }, { -19.5, -14.5, -21.5, -16.5 }, { -4.5, 4.5, 20, 23 } },
	},
	-- Мебель нового дома (её можно переставить или продать).
	Default = {
		{ Id = "sofa", X = 9, Z = -5.5, R = 0 },
		{ Id = "table_round", X = -4, Z = -1, R = 0 },
		{ Id = "rug", X = 4, Z = -5, R = 0 },
		{ Id = "flowers", X = -14, Z = 14, R = 0 },
		{ Id = "flowers", X = 14, Z = 14, R = 0 },
		{ Id = "bench_garden", X = 15, Z = 18.5, R = 2 },
	},
	Categories = { "Гостиная", "Спальня и ванная", "Кухня", "Хобби", "Декор", "Двор", "Премиум ⭐" },
	Items = {
		-- Гостиная
		sofa = { Name = "Диван", Cat = "Гостиная", Price = 600, Size = { 8, 3.5 }, Comfort = 6, Zone = "in" },
		armchair = { Name = "Кресло", Cat = "Гостиная", Price = 300, Size = { 3.5, 3.5 }, Comfort = 3, Zone = "in" },
		table_round = { Name = "Обеденный стол", Cat = "Гостиная", Price = 250, Size = { 5, 5 }, Comfort = 2, Zone = "in" },
		coffee_table = { Name = "Журнальный столик", Cat = "Гостиная", Price = 150, Size = { 4, 2.5 }, Comfort = 1, Zone = "in" },
		rug = { Name = "Ковёр", Cat = "Гостиная", Price = 120, Size = { 10, 7 }, Comfort = 2, Zone = "in", Flat = true },
		tv_big = { Name = "Большой телевизор", Cat = "Гостиная", Price = 1500, Size = { 8, 1.5 }, Comfort = 4, Zone = "in",
			Use = { Type = "Watch", Need = "Fun", Rate = 5, Range = 16, Text = "Смотреть кино" } },
		console = { Name = "Игровая приставка", Cat = "Гостиная", Price = 900, Size = { 3, 2 }, Comfort = 3, Zone = "in",
			Use = { Type = "Watch", Need = "Fun", Rate = 6, Range = 12, Text = "Поиграть" } },
		fireplace = { Name = "Камин", Cat = "Гостиная", Price = 1800, Size = { 6, 2.5 }, Comfort = 10, Zone = "in" },
		floor_lamp = { Name = "Торшер", Cat = "Гостиная", Price = 120, Size = { 1.5, 1.5 }, Comfort = 2, Zone = "in" },
		-- Спальня и ванная
		bed_double = { Name = "Двуспальная кровать", Cat = "Спальня и ванная", Price = 1400, Size = { 8, 10 }, Comfort = 6, Zone = "in",
			Use = { Type = "Sleep", Need = "Energy", Rate = 9, Text = "Спать" } },
		nightstand = { Name = "Тумбочка с лампой", Cat = "Спальня и ванная", Price = 150, Size = { 2, 2 }, Comfort = 1, Zone = "in" },
		wardrobe = { Name = "Шкаф-купе", Cat = "Спальня и ванная", Price = 700, Size = { 6, 2.5 }, Comfort = 2, Zone = "in",
			Use = { Type = "Wardrobe", Text = "Переодеться" } },
		bathtub = { Name = "Ванна", Cat = "Спальня и ванная", Price = 1100, Size = { 7, 3.5 }, Comfort = 5, Zone = "in",
			Use = { Type = "Shower", Need = "Hygiene", Rate = 12, Text = "Принять ванну" } },
		-- Кухня
		stove = { Name = "Плита", Cat = "Кухня", Price = 800, Size = { 3.5, 3 }, Comfort = 2, Zone = "in",
			Use = { Type = "Instant", Effects = { Hunger = 30 }, Cooldown = 150, Text = "Приготовить ужин" } },
		coffee_machine = { Name = "Кофемашина", Cat = "Кухня", Price = 400, Size = { 2, 2 }, Comfort = 1, Zone = "in",
			Use = { Type = "Instant", Effects = { Energy = 12, Fun = 2 }, Cooldown = 120, Text = "Выпить кофе" } },
		chair = { Name = "Стул", Cat = "Кухня", Price = 80, Size = { 2, 2 }, Comfort = 1, Zone = "in" },
		-- Хобби (опыт навыков дома, но реже, чем в секциях)
		bookshelf = { Name = "Книжный шкаф", Cat = "Хобби", Price = 500, Size = { 5, 1.8 }, Comfort = 3, Zone = "in",
			Use = { Type = "Skill", Skill = "Intellect", XP = 6, Effects = { Fun = 3 }, Cooldown = 90, Text = "Почитать" } },
		computer = { Name = "Компьютерный стол", Cat = "Хобби", Price = 1200, Size = { 5, 3 }, Comfort = 2, Zone = "in",
			Use = { Type = "Skill", Skill = "Intellect", XP = 5, Effects = { Fun = 4 }, Cooldown = 90, Text = "Посидеть за ПК" } },
		chess_set = { Name = "Шахматный столик", Cat = "Хобби", Price = 350, Size = { 3, 3 }, Comfort = 2, Zone = "in",
			Use = { Type = "Skill", Skill = "Intellect", XP = 4, Effects = { Fun = 4 }, Cooldown = 90, Text = "Решить задачу" } },
		guitar_stand = { Name = "Гитара на стойке", Cat = "Хобби", Price = 600, Size = { 2, 2 }, Comfort = 2, Zone = "in",
			Use = { Type = "Skill", Skill = "Music", XP = 6, Effects = { Fun = 4 }, Cooldown = 90, Text = "Поиграть на гитаре" } },
		home_gym = { Name = "Штанга и скамья", Cat = "Хобби", Price = 900, Size = { 6, 3 }, Comfort = 1, Zone = "in",
			Use = { Type = "Skill", Skill = "Strength", XP = 6, Effects = { Energy = -4 }, Cooldown = 90, Text = "Потренироваться" } },
		treadmill = { Name = "Беговая дорожка", Cat = "Хобби", Price = 1000, Size = { 3, 6 }, Comfort = 1, Zone = "in",
			Use = { Type = "Skill", Skill = "Stamina", XP = 6, Effects = { Energy = -4 }, Cooldown = 90, Text = "Пробежка" } },
		-- Декор
		plant = { Name = "Фикус в кадке", Cat = "Декор", Price = 90, Size = { 2, 2 }, Comfort = 2, Zone = "in" },
		painting = { Name = "Картина", Cat = "Декор", Price = 200, Size = { 4, 0.6 }, Comfort = 2, Zone = "in", Flat = true },
		aquarium = { Name = "Аквариум", Cat = "Декор", Price = 1300, Size = { 5, 2 }, Comfort = 8, Zone = "in" },
		clock = { Name = "Напольные часы", Cat = "Декор", Price = 450, Size = { 1.8, 1.5 }, Comfort = 3, Zone = "in" },
		-- Двор
		flowers = { Name = "Клумба", Cat = "Двор", Price = 80, Size = { 8, 3 }, Comfort = 2, Zone = "out" },
		bench_garden = { Name = "Садовая скамейка", Cat = "Двор", Price = 150, Size = { 6, 2.5 }, Comfort = 2, Zone = "out" },
		grill = { Name = "Мангал", Cat = "Двор", Price = 500, Size = { 4, 2 }, Comfort = 2, Zone = "out",
			Use = { Type = "Instant", Effects = { Hunger = 35, Fun = 5 }, Cooldown = 180, Text = "Пожарить шашлык" } },
		swing = { Name = "Садовые качели", Cat = "Двор", Price = 700, Size = { 6, 3 }, Comfort = 4, Zone = "out" },
		trampoline = { Name = "Батут", Cat = "Двор", Price = 600, Size = { 7, 7 }, Comfort = 2, Zone = "out",
			Use = { Type = "Instant", Effects = { Fun = 12, Energy = -3 }, Cooldown = 40, Text = "Попрыгать" } },
		garden_bed = { Name = "Грядка", Cat = "Двор", Price = 100, Size = { 6, 3 }, Comfort = 1, Zone = "out",
			Use = { Type = "Instant", Effects = { Hunger = 10, Fun = 3 }, Cooldown = 300, Text = "Собрать урожай" } },
		gnome = { Name = "Садовый гном", Cat = "Двор", Price = 60, Size = { 1.2, 1.2 }, Comfort = 1, Zone = "out" },
		lantern = { Name = "Садовый фонарь", Cat = "Двор", Price = 150, Size = { 1.2, 1.2 }, Comfort = 1, Zone = "out" },
		-- Премиум (Robux)
		neon_sofa = { Name = "Неоновый диван", Cat = "Премиум ⭐", Robux = 59, Size = { 8, 3.5 }, Comfort = 10, Zone = "in" },
		gold_bed = { Name = "Золотая кровать", Cat = "Премиум ⭐", Robux = 79, Size = { 8, 10 }, Comfort = 12, Zone = "in",
			Use = { Type = "Sleep", Need = "Energy", Rate = 12, Text = "Спать" } },
		piano = { Name = "Рояль", Cat = "Премиум ⭐", Robux = 99, Size = { 6, 7 }, Comfort = 10, Zone = "in",
			Use = { Type = "Skill", Skill = "Music", XP = 10, Effects = { Fun = 6 }, Cooldown = 90, Text = "Сыграть на рояле" } },
		arcade = { Name = "Игровой автомат", Cat = "Премиум ⭐", Robux = 49, Size = { 3, 3 }, Comfort = 6, Zone = "in",
			Use = { Type = "Watch", Need = "Fun", Rate = 8, Range = 10, Text = "Играть" } },
		home_cinema = { Name = "Домашний кинотеатр", Cat = "Премиум ⭐", Robux = 129, Size = { 10, 1.5 }, Comfort = 14, Zone = "in",
			Use = { Type = "Watch", Need = "Fun", Rate = 9, Range = 18, Text = "Смотреть фильм" } },
		hot_tub = { Name = "Джакузи", Cat = "Премиум ⭐", Robux = 99, Size = { 8, 8 }, Comfort = 10, Zone = "out",
			Use = { Type = "Shower", Need = "Hygiene", Rate = 14, Text = "Понежиться в джакузи" } },
		pool = { Name = "Бассейн", Cat = "Премиум ⭐", Robux = 149, Size = { 14, 9 }, Comfort = 14, Zone = "out",
			Use = { Type = "Instant", Effects = { Fun = 15, Hygiene = 10 }, Cooldown = 60, Text = "Поплавать" } },
	},
	-- Отделка. Index 0 — исходный вид дома (бесплатно).
	Styles = {
		Order = { "Wall", "Floor", "Roof", "Fence" },
		Names = { Wall = "Стены", Floor = "Пол", Roof = "Крыша", Fence = "Забор" },
		Wall = {
			{ Name = "Белый", Color = Color3.fromRGB(245, 243, 235), Price = 400 },
			{ Name = "Персиковый", Color = Color3.fromRGB(245, 200, 170), Price = 400 },
			{ Name = "Голубой", Color = Color3.fromRGB(170, 205, 235), Price = 400 },
			{ Name = "Мятный", Color = Color3.fromRGB(180, 230, 200), Price = 400 },
			{ Name = "Лавандовый", Color = Color3.fromRGB(205, 190, 235), Price = 400 },
			{ Name = "Графит", Color = Color3.fromRGB(80, 85, 95), Price = 600 },
			{ Name = "Красный кирпич", Color = Color3.fromRGB(165, 85, 65), Material = "Brick", Price = 900 },
			{ Name = "Деревянный сруб", Color = Color3.fromRGB(160, 115, 70), Material = "WoodPlanks", Price = 900 },
		},
		Floor = {
			{ Name = "Светлый паркет", Color = Color3.fromRGB(215, 180, 135), Material = "WoodPlanks", Price = 300 },
			{ Name = "Тёмный паркет", Color = Color3.fromRGB(110, 70, 45), Material = "WoodPlanks", Price = 300 },
			{ Name = "Мрамор", Color = Color3.fromRGB(235, 235, 240), Material = "Marble", Price = 1200 },
			{ Name = "Ковролин", Color = Color3.fromRGB(120, 130, 160), Material = "Fabric", Price = 500 },
			{ Name = "Плитка", Color = Color3.fromRGB(200, 195, 185), Material = "Slate", Price = 600 },
		},
		Roof = {
			{ Name = "Красная черепица", Color = Color3.fromRGB(165, 55, 45), Price = 500 },
			{ Name = "Синяя", Color = Color3.fromRGB(60, 85, 130), Price = 500 },
			{ Name = "Зелёная", Color = Color3.fromRGB(65, 115, 75), Price = 500 },
			{ Name = "Графитовая", Color = Color3.fromRGB(55, 55, 60), Price = 500 },
			{ Name = "Медная", Color = Color3.fromRGB(190, 120, 70), Material = "Metal", Price = 900 },
		},
		Fence = {
			{ Name = "Белый", Color = Color3.fromRGB(250, 250, 245), Price = 200 },
			{ Name = "Натуральное дерево", Color = Color3.fromRGB(150, 105, 65), Price = 200 },
			{ Name = "Зелёный", Color = Color3.fromRGB(70, 120, 80), Price = 200 },
			{ Name = "Кованый чёрный", Color = Color3.fromRGB(35, 35, 40), Material = "Metal", Price = 500 },
		},
	},
}
for id, item in Config.Home.Items do
	if item.Robux then
		Config.Monetization.Products["Furn_" .. id] = { Id = 0, Name = item.Name, Robux = item.Robux, Furniture = id }
	end
end
Config.Monetization.GamePasses.Designer = { Id = 0, Name = "Дизайнер интерьеров", Robux = 349, Description = "Вся премиум-мебель (рояль, джакузи, бассейн, кинотеатр…) и любая отделка дома бесплатно." }
table.insert(Config.Monetization.PassOrder, "Designer")

return Config
