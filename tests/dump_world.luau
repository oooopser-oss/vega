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
