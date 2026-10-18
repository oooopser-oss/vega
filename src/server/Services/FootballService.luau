-- Футбол на Центральном стадионе: мяч, удары, голы, счёт на табло.
-- Забивший получает опыт «Футбол» и настроение.

local Players = game:GetService("Players")

local FootballService = {}
local ctx

local lastKick = {} -- [Player] = os.clock()
local lastToucher
local score = { 0, 0 } -- красные (ворота справа), синие (ворота слева)
local resetting = false
local lastActivity = os.clock()

local function updateBoard()
	local F = ctx.World.Football
	if F and F.ScoreLabel then
		F.ScoreLabel.Text = string.format("КРАСНЫЕ %d : %d СИНИЕ", score[1], score[2])
	end
end

local function resetBall(delay)
	local F = ctx.World.Football
	resetting = true
	task.delay(delay or 0, function()
		F.Ball.AssemblyLinearVelocity = Vector3.zero
		F.Ball.AssemblyAngularVelocity = Vector3.zero
		F.Ball.CFrame = F.Center
		resetting = false
	end)
end

local function kick(player, hit)
	local F = ctx.World.Football
	local now = os.clock()
	if lastKick[player] and now - lastKick[player] < 0.35 then
		return
	end
	lastKick[player] = now
	lastToucher = player
	lastActivity = now
	local hrp = hit.Parent:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local away = F.Ball.Position - hrp.Position
	away = Vector3.new(away.X, 0, away.Z)
	local dir = (away.Magnitude > 0.1 and away.Unit or hrp.CFrame.LookVector) * 0.6 + hrp.CFrame.LookVector * 0.4
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local power = 48 * (1 + 0.08 * ctx.Progression.Level(player, "Football"))
	F.Ball.AssemblyLinearVelocity = dir * power + Vector3.new(0, 14, 0)
end

local function goal(sideScored)
	-- sideScored: 1 — мяч в правых воротах (гол красных), -1 — в левых (гол синих)
	local F = ctx.World.Football
	if sideScored == 1 then
		score[1] += 1
	else
		score[2] += 1
	end
	updateBoard()
	local who = lastToucher and lastToucher.Parent and lastToucher.DisplayName or "Кто-то"
	ctx.Net.NotifyAll(string.format("⚽ ГОЛ! Забил %s. Счёт %d:%d", who, score[1], score[2]), "good")
	if lastToucher and lastToucher.Parent then
		ctx.Progression.AddXP(lastToucher, "Football", 40)
		ctx.Needs.Change(lastToucher, "Fun", 10)
		ctx.Quests.Progress(lastToucher, "train", 1)
	end
	for _, p in Players:GetPlayers() do
		local pos = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if pos and (pos.Position - F.Center.Position).Magnitude < 120 then
			ctx.Needs.Change(p, "Fun", 3)
		end
	end
	resetBall(2.5)
end

function FootballService.Init(c)
	ctx = c
	local F = ctx.World.Football
	if not F then
		return
	end
	pcall(function()
		F.Ball:SetNetworkOwner(nil)
	end)
	F.Ball.Touched:Connect(function(hit)
		local char = hit.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		if player and not resetting then
			kick(player, hit)
		end
	end)
	updateBoard()
	task.spawn(function()
		while true do
			task.wait(0.1)
			if not resetting and F.Ball.Parent then
				local lp = F.Base:PointToObjectSpace(F.Ball.Position)
				if math.abs(lp.X) > F.HalfW + 0.5 and math.abs(lp.Z) < F.GoalHalf and lp.Y < 9 and math.abs(lp.X) < F.HalfW + 6 then
					goal(lp.X > 0 and 1 or -1)
				elseif math.abs(lp.X) > F.HalfW + 40 or math.abs(lp.Z) > 80 or lp.Y < -20 then
					resetBall(1)
				end
			end
			-- Без игроков долго — счёт обнуляется.
			if os.clock() - lastActivity > 180 and (score[1] > 0 or score[2] > 0) then
				score = { 0, 0 }
				updateBoard()
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastKick[player] = nil
		if lastToucher == player then
			lastToucher = nil
		end
	end)
end

return FootballService
