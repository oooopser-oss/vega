-- Песочница: настоящие Instance из Lune (проверка свойств) + заглушки событий.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local task = require("@lune/task")

local H = {}
local place = roblox.deserializePlace(fs.readFile("../LifeCity.rbxlx"))
H.place = place

local proxies = setmetatable({}, { __mode = "k" })
local reals = setmetatable({}, { __mode = "k" })
local wrap, unwrap

local function signal()
	local s = { handlers = {} }
	function s:Connect(fn) table.insert(self.handlers, fn) return { Disconnect = function() end } end
	function s:Fire(...) for _, h in self.handlers do h(...) end end
	function s:Wait() return nil end
	return s
end
H.signal = signal

local signals = {}
local nextSig = 0
local function sigFor(real, key)
	local id = real:GetAttribute("__sig")
	if not id then
		nextSig += 1
		id = nextSig
		real:SetAttribute("__sig", id)
	end
	signals[id] = signals[id] or {}
	signals[id][key] = signals[id][key] or signal()
	return signals[id][key]
end
H.sigFor = function(p, key) return sigFor(unwrap(p), key) end

function unwrap(x)
	if type(x) == "table" and reals[x] then return reals[x] end
	return x
end
local function unwrapAll(...)
	local t = table.pack(...)
	for i = 1, t.n do t[i] = unwrap(t[i]) end
	return table.unpack(t, 1, t.n)
end
local function wrapAll(...)
	local t = table.pack(...)
	for i = 1, t.n do
		if typeof(t[i]) == "Instance" then t[i] = wrap(t[i])
		elseif type(t[i]) == "table" and not reals[t[i]] then
			local arr = t[i]
			local isArr = #arr > 0
			if isArr and typeof(arr[1]) == "Instance" then
				local copy = {}
				for j, v in arr do copy[j] = wrap(v) end
				t[i] = copy
			end
		end
	end
	return table.unpack(t, 1, t.n)
end

local special = {
	WaitForChild = function(real, name) return real:FindFirstChild(name) or error("WaitForChild: no " .. name .. " in " .. real:GetFullName()) end,
	GetPropertyChangedSignal = function(real, prop) return sigFor(real, "prop:" .. prop) end,
	GetAttributeChangedSignal = function(real, a) return sigFor(real, "attr:" .. a) end,
	PivotTo = function(real, cf) end,
	SetNetworkOwner = function() end,
	SetNetworkOwnershipAuto = function() end,
	TakeDamage = function() end,
	LoadCharacter = function() end,
	Play = function() end,
	FireServer = function() end,
	FillBlock = function() end,
	GetTagged = function() return {} end,
	GetServerTimeNow = function() return os.clock() end,
	Raycast = function() return nil end,
	Create = function() return { Play = function() end } end,
	FireAllClients = function() end,
	FireClient = function() end,
	BulkMoveTo = function() end,
}

function wrap(real)
	if proxies[real] then return proxies[real] end
	local p = setmetatable({}, {
		__index = function(_, k)
			if special[k] then
				return function(_, ...) return wrapAll(special[k](real, unwrapAll(...))) end
			end
			local ok, v = pcall(function() return real[k] end)
			if not ok then
				if type(k) == "string" and k:match("^%u") then
					-- событие (Triggered, MouseButton1Click, ...) или нереализованное в Lune свойство
					if k == "AssemblyMass" then return 50 end
					if k == "Occupant" or k == "CurrentCamera" or k == "Character" or k == "ViewportSize" then return nil end
					return sigFor(real, k)
				end
				error(v, 2)
			end
			if type(v) == "function" then
				return function(_, ...) return wrapAll(v(real, unwrapAll(...))) end
			end
			if typeof(v) == "Instance" then return wrap(v) end
			return v
		end,
		__newindex = function(_, k, v)
			real[k] = unwrap(v)
		end,
		__tostring = function() return tostring(real) end,
	})
	proxies[real] = p
	reals[p] = real
	return p
end
H.wrap, H.unwrap = wrap, unwrap

local InstanceShim = { new = function(class, parent)
	local r = roblox.Instance.new(class)
	if parent then r.Parent = unwrap(parent) end
	return wrap(r)
end }

local realTypeof = typeof
local function typeofShim(x)
	if type(x) == "table" and reals[x] then return "Instance" end
	return realTypeof(x)
end

function H.makeEnv(gameObj, extra)
	local env = {
		game = gameObj, workspace = wrap(place:GetService("Workspace")), task = task,
		Instance = InstanceShim, Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, CFrame = roblox.CFrame,
		Color3 = roblox.Color3, UDim2 = roblox.UDim2, UDim = roblox.UDim, Enum = roblox.Enum, BrickColor = roblox.BrickColor,
		ColorSequence = roblox.ColorSequence, NumberSequence = roblox.NumberSequence, NumberRange = roblox.NumberRange,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, PhysicalProperties = roblox.PhysicalProperties,
		TweenInfo = { new = function() return {} end },
		RaycastParams = { new = function() return {} end },
		Random = { new = function(seed)
			local state = (seed or 1) % 2147483647
			if state <= 0 then state += 2147483646 end
			local function nextFloat()
				state = (state * 16807) % 2147483647
				return state / 2147483647
			end
			local r = {}
			function r:NextNumber(a, b)
				a, b = a or 0, b or 1
				return a + (b - a) * nextFloat()
			end
			function r:NextInteger(a, b)
				return math.floor(a + (b - a + 1) * nextFloat())
			end
			return r
		end },
		warn = function(...) print("WARN", ...) end, typeof = typeofShim, print = print,
		os = os, math = math, string = string, table = table, pcall = pcall, error = error, type = type,
		tostring = tostring, tonumber = tonumber, setmetatable = setmetatable, ipairs = ipairs, pairs = pairs,
		select = select, next = next, rawget = rawget, utf8 = utf8,
	}
	for k, v in extra or {} do env[k] = v end
	local cache = {}
	local function req(mod)
		local real = unwrap(mod)
		local key = real:GetFullName()
		if cache[key] ~= nil then return cache[key] end
		local e = table.clone(env)
		e.script = wrap(real)
		e.require = env.require
		local fn = luau.load(real.Source, { debugName = real:GetFullName(), environment = e })
		local r = fn()
		cache[key] = r
		return r
	end
	env.require = req
	return env, req
end

function H.run(scriptInst, env)
	local real = unwrap(scriptInst)
	local e = table.clone(env)
	e.script = wrap(real)
	local fn = luau.load(real.Source, { debugName = real:GetFullName(), environment = e })
	return fn()
end

return H
