-- Строит город в песочнице и выгружает все детали в world3d.csv для превью
-- (tools/preview/render3d.py). Запуск: cd tests && lune run dump_world
local H = require("./harness")
local place = H.place
local function stub() return setmetatable({}, { __index = function(t, k)
	if k:match("^%u") and (k:match("ed$") or k:match("ing$") or k == "Heartbeat") then local s = H.signal() rawset(t, k, s) return s end
	return function() return nil end
end }) end
local PlayersStub = stub()
PlayersStub.GetPlayers = function() return {} end
PlayersStub.RespawnTime = 5
local services = {
	Players = PlayersStub,
	DataStoreService = { GetDataStore = function() return { GetAsync = function() return nil end, SetAsync = function() end } end },
	RunService = { IsStudio = function() return false end },
	MarketplaceService = setmetatable({}, { __index = function(t, k) local sg = H.signal() rawset(t, k, sg) return sg end }),
}
local gameObj = setmetatable({ GetService = function(_, n) return services[n] or H.wrap(place:GetService(n)) end, BindToClose = function() end }, {})
local env, req = H.makeEnv(gameObj)
local main = H.wrap(place:GetService("ServerScriptService")).Server.Main
H.run(main, env)
print("SERVER INIT OK")
-- Снимок городской жизни (машины и прохожие живут на клиенте) вокруг точки из аргументов.
do
	local process = require("@lune/process")
	local roblox0 = require("@lune/roblox")
	local cx, cz = tonumber(process.args[1] or "-160"), tonumber(process.args[2] or "-340")
	local Ambient = req(H.wrap(H.place:GetService("StarterPlayer")).StarterPlayerScripts.Client.Ambient)
	local folder = H.wrap(roblox0.Instance.new("Folder"))
	folder.Parent = H.wrap(H.place:GetService("Workspace"))
	-- Витрина одежды: ряд манекенов в вещах из каталога (5-й аргумент "showcase").
	if process.args[5] == "showcase" then
		local Rig = req(H.wrap(H.place:GetService("ReplicatedStorage")).Shared.Rig)
		local Config = req(H.wrap(H.place:GetService("ReplicatedStorage")).Shared.Config)
		local I = Config.Clothing.Items
		local looks = {
			{ I.hoodie_perv, I.jeans, I.cap },
			{ I.neon_jacket, I.neon_pants, I.headphones, I.star_glasses },
			{ I.gold_suit, I.black_pants, I.crown, I.gold_chain },
			{ I.leather, I.black_pants, I.tophat, I.glasses },
			{ I.tee_white, I.khaki, I.halo, I.wings },
			{ I.sweater, I.track, I.ushanka, I.scarf },
			{ I.suit, I.black_pants, I.cowboy, I.backpack },
		}
		for i, look in looks do
			local rig = Rig.Build({ Seed = i * 31 })
			Rig.Dress(rig, look)
			rig.Model.Parent = folder
			Rig.Place(rig, roblox0.CFrame.new(cx - 18 + i * 4.5, 0.4, cz) * roblox0.CFrame.Angles(0, math.pi, 0), 0)
		end
	end
	-- Обставленный дом №1 (5-й аргумент "home"): полный набор мебели и отделки.
	if process.args[5] == "home" then
		local Shared = H.wrap(H.place:GetService("ReplicatedStorage")).Shared
		local Config = req(Shared.Config)
		local Furniture = req(Shared.Furniture)
		local houseModel = H.wrap(H.place:GetService("Workspace")):FindFirstChild("House1", true)
		local lawn = houseModel:FindFirstChild("Lawn")
		local base = lawn.CFrame * roblox0.CFrame.new(0, -0.05, 0)
		local layout = {
			{ Id = "sofa", X = 9, Z = -5.5, R = 0 }, { Id = "rug", X = 4, Z = -5, R = 0 }, { Id = "coffee_table", X = 9, Z = -1.5, R = 0 },
			{ Id = "bookshelf", X = 0, Z = -15, R = 0 }, { Id = "piano", X = -1, Z = -9.5, R = 0 }, { Id = "fireplace", X = 5.5, Z = -14.75, R = 0 },
			{ Id = "armchair", X = 3, Z = -1, R = 0 }, { Id = "floor_lamp", X = 13.2, Z = -9.5, R = 0 }, { Id = "plant", X = -8.5, Z = -5.5, R = 0 },
			{ Id = "painting", X = -4, Z = -15.6, R = 0 }, { Id = "table_round", X = -4, Z = -1, R = 0 },
			{ Id = "pool", X = -14.5, Z = 13, R = 0 }, { Id = "hot_tub", X = 17, Z = 10, R = 0 }, { Id = "bench_garden", X = 15, Z = 18.5, R = 2 },
			{ Id = "flowers", X = -9, Z = 20.5, R = 0 }, { Id = "grill", X = -19, Z = -2, R = 1 }, { Id = "trampoline", X = 9.5, Z = 13.5, R = 0 },
			{ Id = "swing", X = 19, Z = -6, R = 1 }, { Id = "lantern", X = -7.5, Z = 7, R = 0 }, { Id = "gnome", X = -4, Z = 12, R = 0 },
			{ Id = "garden_bed", X = -19, Z = -12, R = 1 },
		}
		local furn = houseModel:FindFirstChild("Furniture")
		for _, c in furn:GetChildren() do c:Destroy() end
		local placed = {}
		for _, e in layout do
			local ok, why = Furniture.Check(placed, e.Id, e.X, e.Z, e.R)
			if not ok then print("НЕЛЬЗЯ", e.Id, why) end
			table.insert(placed, e)
			Furniture.Build(e.Id, Furniture.ItemCFrame(base, e)).Parent = furn
		end
		for _, w in houseModel:GetChildren() do
			if w.Name == "Floor" then w.Color = Config.Home.Styles.Floor[3].Color end
			if w.Name == "Wall" then w.Color = Config.Home.Styles.Wall[3].Color end
		end
		print("home at", base.Position, "yaw", select(2, base:ToOrientation()), "comfort", Furniture.Comfort(placed))
	end
	print("ambient", Ambient.Snapshot(folder, roblox0.Vector3.new(cx, 0, cz), tonumber(process.args[3] or "30"), tonumber(process.args[4] or "45")))
end
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local CFrame = roblox.CFrame
local out = {}
for _, d in H.place:GetService("Workspace"):GetDescendants() do
	if d:IsA("BasePart") and d.ClassName ~= "Terrain" then
		local okp, pos = pcall(function() return d.Position end)
		local cf = d.CFrame
		if okp and pos then cf = CFrame.new(pos) * (cf - cf.Position) end
		local c = d.Color
		local rv, uv, lv = cf.RightVector, cf.UpVector, cf.LookVector
		local okt, tr = pcall(function() return d.Transparency end)
		local shape = "Block"
		if d.ClassName == "WedgePart" then shape = "Wedge" elseif d.ClassName == "Part" then local oks, sh = pcall(function() return d.Shape.Name end) if oks then shape = sh end end
		table.insert(out, string.format("%s,%s,%.2f,%.2f,%.2f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.2f,%.2f,%.2f,%d,%d,%d,%.2f", d.Name, shape, cf.Position.X, cf.Position.Y, cf.Position.Z, rv.X, rv.Y, rv.Z, uv.X, uv.Y, uv.Z, lv.X, lv.Y, lv.Z, d.Size.X, d.Size.Y, d.Size.Z, c.R*255, c.G*255, c.B*255, okt and tr or 0))
	end
end
fs.writeFile("world3d.csv", table.concat(out, "\n"))
print("parts", #out)
require("@lune/process").exit(0)
