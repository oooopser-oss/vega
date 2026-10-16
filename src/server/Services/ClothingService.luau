-- Одежда: гардероб игрока (купленные вещи), надетый комплект и его
-- применение к персонажу. Обычные вещи — за игровые $, премиум — за Robux
-- (товары «Cloth_<id>» или пасс «Модный гардероб»).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Outfits = require(Shared:WaitForChild("Outfits"))

local ClothingService = {}
local ctx

local C = Config.Clothing
local descriptions = {} -- [Player] = HumanoidDescription (исходный аватар)

local TOP_PARTS = { "Torso", "UpperTorso", "LowerTorso", "Left Arm", "Right Arm", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm" }
local BOTTOM_PARTS = { "Left Leg", "Right Leg", "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg", "LeftFoot", "RightFoot" }

function ClothingService.Owns(player, id)
	local item = C.Items[id]
	local data = ctx.Data.Get(player)
	if not item or not data then
		return false
	end
	if item.Price == 0 then
		return true
	end
	if data.Wardrobe and data.Wardrobe[id] then
		return true
	end
	return item.Robux ~= nil and ctx.Monetization.HasPass(player, "Fashion")
end

function ClothingService.Send(player)
	local data = ctx.Data.Get(player)
	if not data then
		return
	end
	local owned = {}
	for id in C.Items do
		owned[id] = ClothingService.Owns(player, id)
	end
	ctx.Net.Send(player, "Wardrobe", { Owned = owned, Outfit = data.Outfit or {} })
end

local function clearOutfitParts(char)
	for _, child in char:GetChildren() do
		if child.Name == "OutfitPieces" then
			child:Destroy()
		end
	end
	for _, d in char:GetDescendants() do
		if d.Name == "OutfitLogo" then
			d:Destroy()
		end
	end
end

local function attachPieces(char, kind, color)
	local head = char:FindFirstChild("Head")
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	if not head or not torso then
		return
	end
	local folder = Instance.new("Model")
	folder.Name = "OutfitPieces"
	for _, spec in Outfits.Pieces(kind, color) do
		local part = Outfits.MakePart(spec)
		local bone = (spec.Anchor == "HeadTop" or spec.Anchor == "Face") and head or torso
		part.CFrame = Outfits.AnchorCFrame(spec.Anchor, head, torso) * spec.Offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = bone
		weld.Part1 = part
		weld.Parent = part
		part.Parent = folder
	end
	folder.Parent = char
end

local function paint(char, names, color, material)
	for _, name in names do
		local p = char:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			p.Color = color
			p.Material = material or Enum.Material.SmoothPlastic
		end
	end
end

-- Применяет надетый комплект к персонажу (поверх исходного аватара).
function ClothingService.Apply(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local data = ctx.Data.Get(player)
	if not hum or not data then
		return
	end
	clearOutfitParts(char)
	-- Сначала возвращаем исходный аватар, затем надеваем вещи.
	local desc = descriptions[player]
	if desc then
		pcall(function()
			hum:ApplyDescription(desc)
		end)
	end
	local outfit = data.Outfit
	if not outfit then
		return
	end
	local body = char:FindFirstChildOfClass("BodyColors")
	local top = outfit.Top and C.Items[outfit.Top]
	if top then
		for _, c in char:GetChildren() do
			if c:IsA("Shirt") or c:IsA("ShirtGraphic") then
				c:Destroy()
			end
		end
		if body then
			body.TorsoColor3, body.LeftArmColor3, body.RightArmColor3 = top.Color, top.Color, top.Color
		end
		paint(char, TOP_PARTS, top.Color, top.Material)
		if top.Logo then
			local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
			if torso then
				local sg = Instance.new("SurfaceGui")
				sg.Name = "OutfitLogo"
				sg.Face = Enum.NormalId.Back
				sg.Parent = torso
				local tl = Instance.new("TextLabel")
				tl.Size = UDim2.fromScale(1, 0.4)
				tl.Position = UDim2.fromScale(0, 0.3)
				tl.BackgroundTransparency = 1
				tl.TextScaled = true
				tl.Font = Enum.Font.GothamBlack
				tl.TextColor3 = Color3.new(1, 1, 1)
				tl.Text = top.Logo
				tl.Parent = sg
			end
		end
	end
	local bottom = outfit.Bottom and C.Items[outfit.Bottom]
	if bottom then
		for _, c in char:GetChildren() do
			if c:IsA("Pants") then
				c:Destroy()
			end
		end
		if body then
			body.LeftLegColor3, body.RightLegColor3 = bottom.Color, bottom.Color
		end
		paint(char, BOTTOM_PARTS, bottom.Color, bottom.Material)
	end
	local hat = outfit.Hat and C.Items[outfit.Hat]
	if hat then
		-- Снимаем шляпы аватара, чтобы не торчали сквозь нашу.
		for _, acc in hum:GetAccessories() do
			if acc.AccessoryType == Enum.AccessoryType.Hat then
				acc:Destroy()
			end
		end
		attachPieces(char, hat.Kind, hat.Color)
	end
	local accessory = outfit.Accessory and C.Items[outfit.Accessory]
	if accessory then
		attachPieces(char, accessory.Kind, accessory.Color)
	end
end

function ClothingService.Wear(player, id)
	local item = C.Items[id]
	local data = ctx.Data.Get(player)
	if not item or not data or not ClothingService.Owns(player, id) then
		return
	end
	data.Outfit = data.Outfit or {}
	data.Outfit[item.Slot] = id
	ClothingService.Apply(player)
	ClothingService.Send(player)
end

function ClothingService.Grant(player, id)
	local data = ctx.Data.Get(player)
	if data and C.Items[id] then
		data.Wardrobe = data.Wardrobe or {}
		data.Wardrobe[id] = true
		ClothingService.Wear(player, id)
		ctx.Net.Notify(player, "👕 Новая вещь в гардеробе: " .. C.Items[id].Name, "good")
	end
end

function ClothingService.OnPlayerAdded(player)
	task.spawn(function()
		local ok, desc = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(math.max(1, player.UserId))
		end)
		if ok then
			descriptions[player] = desc
		end
	end)
	player.CharacterAppearanceLoaded:Connect(function()
		ClothingService.Apply(player)
	end)
	ClothingService.Send(player)
end

function ClothingService.Init(c)
	ctx = c
	ctx.Net.On("Clothing", function(player, p)
		local data = ctx.Data.Get(player)
		if not data then
			return
		end
		local id, op = p.Item, p.Op
		local item = C.Items[id]
		if op == "buy" and item and item.Price then
			if ClothingService.Owns(player, id) then
				ClothingService.Wear(player, id)
				return
			end
			if not ctx.Data.Spend(player, item.Price) then
				ctx.Net.Notify(player, "Недостаточно денег (" .. item.Price .. "$).", "bad")
				return
			end
			ClothingService.Grant(player, id)
		elseif op == "wear" and item then
			if not ClothingService.Owns(player, id) then
				ctx.Net.Notify(player, "Сначала купите эту вещь.", "bad")
				return
			end
			ClothingService.Wear(player, id)
		elseif op == "remove" and C.SlotNames[p.Slot] then
			if data.Outfit then
				data.Outfit[p.Slot] = nil
			end
			ClothingService.Apply(player)
			ClothingService.Send(player)
		elseif op == "avatar" then
			data.Outfit = nil
			ClothingService.Apply(player)
			ClothingService.Send(player)
			ctx.Net.Notify(player, "Вы снова в своём аватаре Roblox.", "info")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		descriptions[player] = nil
	end)
end

return ClothingService
