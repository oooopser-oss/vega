-- Прогрессия: навыки (опыт → уровни 0..5), общий уровень игрока,
-- образование (аттестат, диплом), водительские права и бонусы навыков.

local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local ProgressionService = {}
local ctx

local S = Config.Skills

local function levelFor(xp)
	local lvl = 0
	for i, need in S.Levels do
		if xp >= need then
			lvl = i
		end
	end
	return lvl
end
ProgressionService.LevelFor = levelFor

local function ensure(data)
	data.Skills = data.Skills or {}
	data.Education = data.Education or { School = 0, College = 0 }
	data.Records = data.Records or {}
	return data
end

function ProgressionService.Level(player, skill)
	return player:GetAttribute("Skill_" .. skill) or 0
end

function ProgressionService.HasSchool(player)
	local data = ctx.Data.Get(player)
	return data ~= nil and ensure(data).Education.School >= Config.Education.SchoolLessons
end

function ProgressionService.HasDiploma(player)
	local data = ctx.Data.Get(player)
	return data ~= nil and ensure(data).Education.College >= Config.Education.CollegeLessons
end

function ProgressionService.HasLicense(player)
	local data = ctx.Data.Get(player)
	return data ~= nil and data.License == true
end

-- Проверка требований вида "School" (аттестат) или "College" (диплом).
function ProgressionService.Meets(player, requirement)
	if requirement == "School" then
		return ProgressionService.HasSchool(player)
	elseif requirement == "College" then
		return ProgressionService.HasDiploma(player)
	end
	return true
end

function ProgressionService.Sync(player)
	local data = ctx.Data.Get(player)
	if not data then
		return
	end
	ensure(data)
	local total = 0
	for _, skill in S.Order do
		local lvl = levelFor(data.Skills[skill] or 0)
		player:SetAttribute("Skill_" .. skill, lvl)
		total += lvl
	end
	if ProgressionService.HasSchool(player) then
		total += 1
	end
	if ProgressionService.HasDiploma(player) then
		total += 2
	end
	if data.License then
		total += 1
	end
	player:SetAttribute("Level", 1 + total)
	player:SetAttribute("License", data.License == true)
	ctx.Net.Send(player, "Progress", {
		Skills = data.Skills,
		Education = data.Education,
		License = data.License == true,
		TheoryPassed = data.TheoryPassed == true,
		Records = data.Records,
	})
end

function ProgressionService.AddXP(player, skill, amount)
	local data = ctx.Data.Get(player)
	if not data or not S.List[skill] or amount <= 0 then
		return
	end
	ensure(data)
	amount = math.floor(amount + 0.5)
	local before = levelFor(data.Skills[skill] or 0)
	data.Skills[skill] = math.min((data.Skills[skill] or 0) + amount, S.Levels[#S.Levels])
	local after = levelFor(data.Skills[skill])
	local info = S.List[skill]
	if after > before then
		ctx.Net.Send(player, "Toast", { Title = info.Icon .. " " .. info.Name .. ": уровень " .. after .. "!", Text = info.Perk })
	else
		ctx.Net.Notify(player, info.Icon .. " " .. info.Name .. " +" .. amount .. " опыта", "good")
	end
	ProgressionService.Sync(player)
	ctx.Needs.UpdateSpeed(player)
end

-- Множитель оплаты работы с учётом навыков и диплома.
function ProgressionService.PayMultiplier(player, jobId)
	local mult = 1
	if ProgressionService.HasDiploma(player) then
		mult += Config.Education.DiplomaPayBonus
	end
	if jobId == "loader" or jobId == "courier" then
		mult += 0.05 * ProgressionService.Level(player, "Strength")
	elseif jobId == "office" then
		mult += 0.06 * ProgressionService.Level(player, "Intellect")
	end
	return mult
end

function ProgressionService.OnPlayerAdded(player)
	local data = ctx.Data.Get(player)
	if data then
		ensure(data)
	end
	ProgressionService.Sync(player)
end

function ProgressionService.Init(c)
	ctx = c
	ctx.Net.On("GetProgress", function(player)
		ProgressionService.Sync(player)
	end)
end

return ProgressionService
