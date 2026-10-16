-- Сотрудники-NPC в зданиях (продавцы, медсестра, дежурный, охранник и др.)
-- и разговоры с жителями. Разговор засчитывается в задание «пообщаться».

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rig"))

local NpcService = {}
local ctx

local TALK_COOLDOWN = 15
local lastTalk = {} -- [Player] = os.clock()

local function countTalk(player)
	local last = lastTalk[player]
	if last and os.clock() - last < TALK_COOLDOWN then
		return
	end
	lastTalk[player] = os.clock()
	ctx.Quests.Progress(player, "talk", 1)
	ctx.Needs.Change(player, "Fun", 2)
end

function NpcService.Init(c)
	ctx = c
	local folder = Instance.new("Folder")
	folder.Name = "Workers"
	folder.Parent = workspace

	for i, w in ctx.World.Workers do
		local rig = Rig.Build({ Seed = i * 7919, Role = w.Role, Name = w.Name })
		Rig.Place(rig, w.CFrame, 0)
		rig.Model.Parent = folder
		ctx.WorldBuilder.FloatLabel(rig.Parts.Head, w.Name, 2.2, Color3.fromRGB(255, 240, 180))
		local prompt = ctx.WorldBuilder.MakePrompt(rig.Parts.Torso, "Поговорить", w.Name, 0, 9)
		local lineIndex = 0
		prompt.Triggered:Connect(function(player)
			lineIndex = lineIndex % #w.Lines + 1
			ctx.Net.Broadcast("Bubble", { Character = rig.Model, Text = w.Lines[lineIndex] })
			countTalk(player)
		end)
	end

	-- Разговор с прохожим на улице (прохожие живут на клиенте).
	ctx.Net.On("TalkNPC", function(player)
		countTalk(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastTalk[player] = nil
	end)
end

return NpcService
