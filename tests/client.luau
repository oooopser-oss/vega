-- Автотест интерфейса: открывает все окна и вкладки. Запуск: cd tests && lune run client
local H = require("./harness")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local place = H.place

local rs = place:GetService("ReplicatedStorage")
local remotes = roblox.Instance.new("Folder"); remotes.Name = "Remotes"; remotes.Parent = rs
local a = roblox.Instance.new("RemoteEvent"); a.Name = "Action"; a.Parent = remotes
local e = roblox.Instance.new("RemoteEvent"); e.Name = "Event"; e.Parent = remotes
local sent = {}
local plrReal = roblox.Instance.new("Player")
plrReal.Name = "Tester"
local pg = roblox.Instance.new("PlayerGui"); pg.Parent = plrReal
for k, v in { Cash = 1234, Bank = 50000, Role = "Citizen", Job = "loader", Hunger = 15, Energy = 50, Hygiene = 80, Fun = 60, Wanted = 2, Jailed = 0, RoleChosen = true, HouseId = 3, HasHouse = true, Activity = "" } do plrReal:SetAttribute(k, v) end
local player = H.wrap(plrReal)

local other = { UserId = 2, DisplayName = "Anna", Character = nil, GetAttribute = function(_, k) return k == "Role" and "Medic" or nil end }
local PlayersStub = { LocalPlayer = player, GetPlayers = function() return { player, other } end, GetPlayerByUserId = function(_, id) return id == 2 and other or nil end }
local function sigs() return setmetatable({}, { __index = function(t, k) local s = H.signal() rawset(t, k, s) return s end }) end
local RunService = sigs()
local UIS = sigs()
local services = {
	Players = PlayersStub, RunService = RunService, UserInputService = UIS,
	TextChatService = { DisplayBubble = function() end },
	TweenService = { Create = function() return { Play = function() end } end },
}
local gameObj = { GetService = function(_, n) return services[n] or H.wrap(place:GetService(n)) end }
local env = H.makeEnv(gameObj)
-- FireServer заглушка
local aw = H.wrap(a)
local mt = getmetatable(aw)
local oldIndex = mt.__index
mt.__index = function(t, k) if k == "FireServer" then return function(_, name, p) table.insert(sent, name) end end return oldIndex(t, k) end

place:GetService("Lighting").ClockTime = 14.5
local main = H.wrap(place:GetService("StarterPlayer")).StarterPlayerScripts.Client.Main
H.run(main, env)
print("CLIENT LOADED")
local fire = function(name, payload) H.sigFor(e, "OnClientEvent"):Fire(name, payload) end
local gui = pg:FindFirstChild("LifeCityUI")
local function clickText(pattern)
	for _, d in gui:GetDescendants() do
		if d:IsA("TextButton") and string.find(d.Text, pattern, 1, true) then
			H.sigFor(d, "MouseButton1Click"):Fire()
			return true
		end
	end
	return false
end
local steps = {
	function() fire("OpenRoleMenu", { First = true }) end,
	function() fire("Quests", { List = { { Text = "Выполните 5 рабочих заданий", Progress = 2, Goal = 5, Reward = 300, Done = false, Kind = "work" }, { Text = "Поешьте", Progress = 2, Goal = 2, Reward = 240, Done = true, Kind = "eat" } }, Bonus = 1500, BonusTaken = false, Streak = 3 }); fire("OpenPhone", { Tab = "Задания" }) end,
	function() fire("OpenPhone", { Tab = "Магазин ⭐" }); assert(clickText("R$ 299"), "no pass btn") end,
	function() for _, s in { "Supermarket", "Cafe", "Florist" } do fire("OpenShop", { Shop = s }) end end,
	function() fire("OpenBank", {}) end,
	function() fire("Cars", { Owned = { sedan = true } }); fire("OpenDealer", {}) end,
	function() fire("Inventory", { Items = { bread = 2, ring = 1 } }) end,
	function() fire("Relations", { List = { { UserId = 2, Name = "Anna", Points = 45, Status = "dating", Online = true }, { UserId = 3, Name = "Old", Points = 10, Status = "none", Online = false } }, Partner = 2 }) end,
	function() fire("GPS", { List = { { Name = "Мэрия", Position = roblox.Vector3.new(1, 2, 3) } } }) end,
	function() for _, t in { "Задания", "Работа", "Люди", "Вещи", "Машины", "Дом", "GPS", "Магазин ⭐", "Помощь" } do fire("OpenPhone", { Tab = t }) end end,
	function() fire("OpenPhone", { Tab = "Люди" }); assert(clickText("Anna"), "no Anna button") end,
	function() assert(clickText("Поговорить"), "no action button") end,
	function() fire("Notify", { Text = "Привет", Kind = "good" }); fire("Earned", { Amount = 35, Text = "x" }); fire("Toast", { Title = "T", Text = "x" }) end,
	function() fire("Request", { Id = 1, From = "Anna", Text = "Свидание?" }); assert(clickText("Да"), "no yes") end,
	function() local part = roblox.Instance.new("Part"); part.Parent = place:GetService("Workspace"); fire("JobTask", { Id = 1, Target = part, Position = roblox.Vector3.new(0,0,0), Label = "Взять ящик", Hold = 1, Job = "loader" }) end,
	function() fire("JobTask", { Id = 2, Position = roblox.Vector3.new(5,0,5), Label = "Далеко", Hold = 1, Job = "loader" }) end,
	function() fire("Waypoint", { Name = "Дом", Position = roblox.Vector3.new(10, 0, 10) }); fire("Alert", { Text = "Тревога", Position = roblox.Vector3.new(0, 0, 50) }) end,
	function() fire("DoorBell", { From = "Anna", House = 3 }); fire("Bubble", { Text = "hi" }); fire("CloseMenus", {}) end,
	function() for _, s in RunService.RenderStepped.handlers do s(0.2) end for _, s in RunService.Heartbeat.handlers do s(0.2) end end,
	function() fire("OpenPhone", { Tab = "Дом" }); clickText("Продать") ; fire("OpenBank", {}); clickText("Внести") end,
	function()
		-- Городская жизнь: машины и прохожие появляются и двигаются.
		for _ = 1, 40 do
			for _, h in RunService.Heartbeat.handlers do h(0.3) end
		end
		local life = place:GetService("Workspace"):FindFirstChild("AmbientLife")
		assert(life and #life:GetChildren() > 10, "мало машин/прохожих: " .. (life and #life:GetChildren() or 0))
		print("ambient objects", #life:GetChildren())
	end,
}
local failed = 0
for i, step in steps do
	local ok, err = pcall(step)
	print(i, ok and "ok" or ("FAIL: " .. tostring(err)))
	if not ok then
		failed += 1
	end
end
print(failed == 0 and "CLIENT OK" or ("CLIENT FAILED: " .. failed))
require("@lune/process").exit(failed == 0 and 0 or 1)
