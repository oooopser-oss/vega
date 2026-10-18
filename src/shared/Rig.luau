-- Простая «блочная» фигура человека (как классический персонаж Roblox) для
-- жителей-NPC: сотрудники в зданиях (сервер) и прохожие на улицах (клиент).
-- Части анкерные; ходьба — покачивание рук и ног через Rig.Pose.

local Outfits = require(script.Parent:WaitForChild("Outfits"))

local Rig = {}

local SKIN = {
	Color3.fromRGB(255, 220, 190), Color3.fromRGB(240, 200, 165), Color3.fromRGB(225, 180, 140),
	Color3.fromRGB(200, 150, 110), Color3.fromRGB(150, 105, 75),
}
local SHIRTS = {
	Color3.fromRGB(200, 60, 60), Color3.fromRGB(60, 110, 190), Color3.fromRGB(240, 240, 235),
	Color3.fromRGB(70, 150, 90), Color3.fromRGB(230, 180, 50), Color3.fromRGB(120, 80, 160),
	Color3.fromRGB(40, 40, 45), Color3.fromRGB(230, 120, 160), Color3.fromRGB(110, 120, 130),
}
local PANTS = {
	Color3.fromRGB(40, 50, 80), Color3.fromRGB(30, 30, 35), Color3.fromRGB(90, 70, 50),
	Color3.fromRGB(120, 120, 125), Color3.fromRGB(60, 80, 60),
}
local HAIR = {
	Color3.fromRGB(40, 30, 25), Color3.fromRGB(90, 60, 35), Color3.fromRGB(200, 170, 110),
	Color3.fromRGB(20, 20, 20), Color3.fromRGB(150, 70, 40), Color3.fromRGB(190, 190, 190),
}

-- Униформа сотрудников (ключ — Role в Rig.Build).
Rig.Uniforms = {
	cashier = { Shirt = Color3.fromRGB(230, 120, 30), Pants = Color3.fromRGB(40, 40, 45) },
	doctor = { Shirt = Color3.fromRGB(245, 245, 250), Pants = Color3.fromRGB(245, 245, 250) },
	police = { Shirt = Color3.fromRGB(40, 60, 120), Pants = Color3.fromRGB(30, 35, 60), Hat = Color3.fromRGB(30, 40, 90) },
	guard = { Shirt = Color3.fromRGB(30, 30, 35), Pants = Color3.fromRGB(30, 30, 35) },
	clerk = { Shirt = Color3.fromRGB(70, 90, 140), Pants = Color3.fromRGB(40, 40, 50) },
	cook = { Shirt = Color3.fromRGB(250, 250, 250), Pants = Color3.fromRGB(60, 60, 65), Hat = Color3.fromRGB(250, 250, 250) },
	worker = { Shirt = Color3.fromRGB(240, 140, 30), Pants = Color3.fromRGB(50, 60, 90), Hat = Color3.fromRGB(240, 200, 40) },
	coach = { Shirt = Color3.fromRGB(200, 40, 40), Pants = Color3.fromRGB(30, 30, 40) },
	teacher = { Shirt = Color3.fromRGB(110, 90, 140), Pants = Color3.fromRGB(50, 50, 60) },
}

local function pick(list, rng)
	return list[rng:NextInteger(1, #list)]
end

local function newPart(model, name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = true
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- opts: { Seed = number, Role = "doctor" | ..., Name = string }
function Rig.Build(opts)
	opts = opts or {}
	local rng = Random.new(opts.Seed or math.random(1, 1e6))
	local uniform = opts.Role and Rig.Uniforms[opts.Role]
	local skin = pick(SKIN, rng)
	local shirt = uniform and uniform.Shirt or pick(SHIRTS, rng)
	local pants = uniform and uniform.Pants or pick(PANTS, rng)
	local model = Instance.new("Model")
	model.Name = opts.Name or "Житель"

	local parts = {}
	parts.Torso = newPart(model, "Torso", Vector3.new(2, 2, 1), shirt)
	parts.Head = newPart(model, "Head", Vector3.new(2, 1, 1), skin)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = parts.Head
	local face = Instance.new("Decal")
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = parts.Head
	parts.LArm = newPart(model, "Left Arm", Vector3.new(1, 2, 1), rng:NextNumber() < 0.5 and shirt or skin)
	parts.RArm = newPart(model, "Right Arm", Vector3.new(1, 2, 1), parts.LArm.Color)
	parts.LLeg = newPart(model, "Left Leg", Vector3.new(1, 2, 1), pants)
	parts.RLeg = newPart(model, "Right Leg", Vector3.new(1, 2, 1), pants)
	if uniform and uniform.Hat then
		parts.Hair = newPart(model, "Hat", Vector3.new(2.1, 0.6, 1.3), uniform.Hat)
	else
		parts.Hair = newPart(model, "Hair", Vector3.new(2.05, 0.45, 1.15), pick(HAIR, rng))
	end
	model.PrimaryPart = parts.Torso

	local rig = { Model = model, Parts = parts, Phase = rng:NextNumber() * 6.28, Extras = {} }
	rig.List = { parts.Torso, parts.Head, parts.Hair, parts.LArm, parts.RArm, parts.LLeg, parts.RLeg }

	local function extra(...)
		return Rig.AddExtra(rig, ...)
	end
	local shoes = rng:NextNumber() < 0.5 and Color3.fromRGB(30, 30, 32) or Color3.fromRGB(235, 235, 235)
	extra("ShoeL", Vector3.new(1.05, 0.35, 1.25), 6, CFrame.new(0, -0.85, -0.12), shoes)
	extra("ShoeR", Vector3.new(1.05, 0.35, 1.25), 7, CFrame.new(0, -0.85, -0.12), shoes)
	if parts.LArm.Color ~= skin then
		extra("HandL", Vector3.new(1.02, 0.45, 1.02), 4, CFrame.new(0, -0.8, 0), skin)
		extra("HandR", Vector3.new(1.02, 0.45, 1.02), 5, CFrame.new(0, -0.8, 0), skin)
	end
	extra("Belt", Vector3.new(2.04, 0.25, 1.04), 1, CFrame.new(0, -0.88, 0), Color3.fromRGB(45, 35, 30))
	extra("Collar", Vector3.new(1.2, 0.18, 1.04), 1, CFrame.new(0, 0.93, 0), shirt:Lerp(Color3.new(1, 1, 1), 0.3))

	if not uniform then
		-- Причёска: короткая, длинная или пучок.
		local style = rng:NextNumber()
		if style < 0.35 then
			extra("LongHair", Vector3.new(2.05, 1.2, 0.35), 2, CFrame.new(0, -0.15, 0.6), parts.Hair.Color, Enum.Material.Fabric)
		elseif style < 0.5 then
			extra("Bun", Vector3.new(0.7, 0.7, 0.7), 2, CFrame.new(0, 0.8, 0.4), parts.Hair.Color, Enum.Material.Fabric, Enum.PartType.Ball)
		end
		-- Иногда — шапка, очки, рюкзак или шарф из того же каталога, что у игроков.
		local function wear(kind, color)
			Rig.Wear(rig, kind, color)
		end
		local hats = { "cap", "beanie", "ushanka", "headphones" }
		if rng:NextNumber() < 0.3 then
			wear(hats[rng:NextInteger(1, #hats)], pick(SHIRTS, rng))
			parts.Hair.Transparency = 1
		end
		if rng:NextNumber() < 0.2 then
			wear("glasses", Color3.fromRGB(20, 20, 20))
		end
		local r = rng:NextNumber()
		if r < 0.15 then
			wear("backpack", pick(SHIRTS, rng))
		elseif r < 0.27 then
			wear("scarf", pick(SHIRTS, rng))
		end
	end
	return rig
end

-- Деталь, привязанная к части базовой позы:
-- bone — 1 торс, 2 голова, 4/5 руки, 6/7 ноги.
function Rig.AddExtra(rig, name, size, bone, offset, color, material, shape)
	local part = Outfits.MakePart({ Name = name, Size = size, Color = color, Material = material, Shape = shape })
	part.Anchored = true
	part.Parent = rig.Model
	table.insert(rig.Extras, { Part = part, Bone = bone, Offset = offset })
	table.insert(rig.List, part)
	return part
end

-- Надевает шапку/аксессуар из каталога (shared/Outfits).
function Rig.Wear(rig, kind, color)
	local headRest = { CFrame = CFrame.new(0, 1.5, 0), Size = rig.Parts.Head.Size }
	local torsoRest = { CFrame = CFrame.new(), Size = rig.Parts.Torso.Size }
	for _, spec in Outfits.Pieces(kind, color) do
		local onHead = spec.Anchor == "HeadTop" or spec.Anchor == "Face"
		local boneRest = onHead and headRest.CFrame or torsoRest.CFrame
		local offset = boneRest:Inverse() * Outfits.AnchorCFrame(spec.Anchor, headRest, torsoRest) * spec.Offset
		Rig.AddExtra(rig, spec.Name, spec.Size, onHead and 2 or 1, offset, spec.Color, spec.Material, spec.Shape)
	end
	if (kind == "cap" or kind == "beanie" or kind == "ushanka" or kind == "cowboy" or kind == "tophat" or kind == "crown") then
		rig.Parts.Hair.Transparency = 1
	end
end

-- Одевает фигуру в вещи из Config.Clothing (для витрин и превью).
function Rig.Dress(rig, items)
	for _, item in items do
		if item.Slot == "Top" then
			for _, k in { "Torso", "LArm", "RArm" } do
				rig.Parts[k].Color = item.Color
				rig.Parts[k].Material = item.Material or Enum.Material.SmoothPlastic
			end
		elseif item.Slot == "Bottom" then
			for _, k in { "LLeg", "RLeg" } do
				rig.Parts[k].Color = item.Color
				rig.Parts[k].Material = item.Material or Enum.Material.SmoothPlastic
			end
		else
			Rig.Wear(rig, item.Kind, item.Color)
		end
	end
end

-- Возвращает CFrame для частей (порядок как в rig.List).
-- root — CFrame на уровне земли, смотрит в направлении движения.
function Rig.Pose(rig, root, swing)
	local t = root * CFrame.new(0, 3, 0)
	local a = swing or 0
	local hipL = t * CFrame.new(-0.5, -1, 0) * CFrame.Angles(a, 0, 0) * CFrame.new(0, -1, 0)
	local hipR = t * CFrame.new(0.5, -1, 0) * CFrame.Angles(-a, 0, 0) * CFrame.new(0, -1, 0)
	local armL = t * CFrame.new(-1.5, 0.5, 0) * CFrame.Angles(-a * 0.8, 0, 0) * CFrame.new(0, -0.5, 0)
	local armR = t * CFrame.new(1.5, 0.5, 0) * CFrame.Angles(a * 0.8, 0, 0) * CFrame.new(0, -0.5, 0)
	local head = t * CFrame.new(0, 1.5, 0)
	local hair = head * CFrame.new(0, 0.55, 0.05)
	local out = { t, head, hair, armL, armR, hipL, hipR }
	for _, e in rig.Extras or {} do
		table.insert(out, out[e.Bone] * e.Offset)
	end
	return out
end

-- Сразу ставит фигуру в позу (для статичных NPC).
function Rig.Place(rig, root, swing)
	local cfs = Rig.Pose(rig, root, swing)
	for i, p in rig.List do
		p.CFrame = cfs[i]
	end
end

return Rig
