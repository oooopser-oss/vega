local Util = {}

function Util.HRP(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

function Util.Humanoid(player)
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

function Util.Alive(player)
	local hum = Util.Humanoid(player)
	return hum ~= nil and hum.Health > 0
end

function Util.Position(player)
	local hrp = Util.HRP(player)
	return hrp and hrp.Position
end

-- Находится ли игрок не дальше dist от точки/детали.
function Util.Near(player, target, dist)
	local pos = Util.Position(player)
	if not pos or not target then
		return false
	end
	local tpos = typeof(target) == "Vector3" and target or target.Position
	return (pos - tpos).Magnitude <= dist
end

function Util.Distance(a, b)
	local pa, pb = Util.Position(a), Util.Position(b)
	if not pa or not pb then
		return math.huge
	end
	return (pa - pb).Magnitude
end

-- Телепорт с подгрузкой области (StreamingEnabled), чтобы не провалиться сквозь землю.
function Util.Teleport(player, cf)
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(cf.Position, 5)
		end)
		local char = player.Character
		if char then
			char:PivotTo(cf)
		end
	end)
end

function Util.Stars(n)
	return string.rep("★", n) .. string.rep("☆", 5 - n)
end

return Util
