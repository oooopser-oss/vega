-- Граф улиц (из TrafficGraph) + общая логика светофоров.
-- Сервер по нему ставит светофоры, «зебры», остановки и скамейки,
-- клиент — пускает машины и прохожих.

local TrafficGraph = require(script.Parent:WaitForChild("TrafficGraph"))

local Roads = {}

Roads.Nodes = {} -- [i] = Vector3 (y = 0)
Roads.Edges = {} -- [i] = { A, B, Width, Class }
Roads.Adj = {} -- [node] = { { To, Edge } }
Roads.Lights = {} -- [node] = true
Roads.LightList = {}
Roads.NodeWidth = {} -- [node] = ширина самой широкой улицы в узле

for rec in string.gmatch(TrafficGraph.Nodes, "[^;]+") do
	local f = string.split(rec, ",")
	table.insert(Roads.Nodes, Vector3.new(tonumber(f[1]), 0, tonumber(f[2])))
end
for rec in string.gmatch(TrafficGraph.Edges, "[^;]+") do
	local f = string.split(rec, ",")
	local a, b, w = tonumber(f[1]), tonumber(f[2]), tonumber(f[3])
	local edge = { A = a, B = b, Width = w, Class = TrafficGraph.RoadClasses[tonumber(f[4])] }
	table.insert(Roads.Edges, edge)
	local id = #Roads.Edges
	Roads.Adj[a] = Roads.Adj[a] or {}
	Roads.Adj[b] = Roads.Adj[b] or {}
	table.insert(Roads.Adj[a], { To = b, Edge = id })
	table.insert(Roads.Adj[b], { To = a, Edge = id })
	Roads.NodeWidth[a] = math.max(Roads.NodeWidth[a] or 0, w)
	Roads.NodeWidth[b] = math.max(Roads.NodeWidth[b] or 0, w)
end
for rec in string.gmatch(TrafficGraph.Lights, "[^;]+") do
	local n = tonumber(rec)
	Roads.Lights[n] = true
	table.insert(Roads.LightList, n)
end

-- Скорость машин по классу улицы (studs/сек).
Roads.Speed = { primary = 55, secondary = 50, tertiary = 42, unclassified = 34, residential = 30, living_street = 20 }

-- Группа направления: 0 — «север-юг», 1 — «запад-восток».
function Roads.Group(dir)
	local ang = math.deg(math.atan2(dir.Z, dir.X)) % 180
	return (ang >= 45 and ang < 135) and 0 or 1
end

-- Цикл светофора 24 с: группа 0 — зелёный 0–9, жёлтый 9–12; группа 1 — зелёный 12–21, жёлтый 21–24.
local CYCLE = 24
function Roads.LightState(node, group, now)
	local t = (now + node * 3.7) % CYCLE
	local start = group == 0 and 0 or CYCLE / 2
	local local_t = (t - start) % CYCLE
	if local_t < 9 then
		return "green"
	elseif local_t < 12 then
		return "yellow"
	end
	return "red"
end

-- Правый перпендикуляр к направлению движения (движение по правой полосе).
function Roads.Right(dir)
	return Vector3.new(-dir.Z, 0, dir.X)
end

return Roads
