-- Сетевой слой: одно событие «Action» (клиент → сервер) и одно «Event»
-- (сервер → клиент). Все запросы клиента проверяются на сервере.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = {}

local handlers = {}
local budget = {} -- [Player] = { tokens, last }
local ActionRemote, EventRemote

local MAX_TOKENS = 15
local REFILL_PER_SEC = 6

local function allow(player)
	local now = os.clock()
	local b = budget[player]
	if not b then
		b = { tokens = MAX_TOKENS, last = now }
		budget[player] = b
	end
	b.tokens = math.min(MAX_TOKENS, b.tokens + (now - b.last) * REFILL_PER_SEC)
	b.last = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

function Net.Init()
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	ActionRemote = Instance.new("RemoteEvent")
	ActionRemote.Name = "Action"
	ActionRemote.Parent = folder
	EventRemote = Instance.new("RemoteEvent")
	EventRemote.Name = "Event"
	EventRemote.Parent = folder
	folder.Parent = ReplicatedStorage

	ActionRemote.OnServerEvent:Connect(function(player, name, payload)
		if type(name) ~= "string" or not allow(player) then
			return
		end
		local handler = handlers[name]
		if not handler then
			return
		end
		if type(payload) ~= "table" then
			payload = {}
		end
		local ok, err = pcall(handler, player, payload)
		if not ok then
			warn("[Net] Ошибка обработки " .. name .. ": " .. tostring(err))
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		budget[player] = nil
	end)
end

function Net.On(name, fn)
	handlers[name] = fn
end

function Net.Send(player, name, payload)
	EventRemote:FireClient(player, name, payload or {})
end

function Net.Broadcast(name, payload)
	EventRemote:FireAllClients(name, payload or {})
end

function Net.Notify(player, text, kind)
	Net.Send(player, "Notify", { Text = text, Kind = kind or "info" })
end

function Net.NotifyAll(text, kind)
	Net.Broadcast("Notify", { Text = text, Kind = kind or "info" })
end

return Net
