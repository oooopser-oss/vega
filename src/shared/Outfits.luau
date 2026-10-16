-- Геометрия шапок и аксессуаров из деталей (без ассетов каталога).
-- Используется и для персонажей игроков (части приваривают к голове/торсу),
-- и для жителей-NPC (Rig).
--
-- Точки крепления (Anchor):
--   HeadTop — макушка, Face — перед лица, Neck — верх торса,
--   Back — спина, Chest — грудь.

local Outfits = {}

local GOLD = Color3.fromRGB(245, 200, 60)
local BLACK = Color3.fromRGB(20, 20, 22)

local function p(name, size, anchor, offset, color, material, shape)
	return { Name = name, Size = size, Anchor = anchor, Offset = offset, Color = color, Material = material, Shape = shape }
end

local R90 = CFrame.Angles(0, 0, math.rad(90))

-- Возвращает список деталей для вида (Kind) и цвета.
function Outfits.Pieces(kind, color)
	if kind == "cap" then
		return {
			p("CapCrown", Vector3.new(1.3, 0.45, 1.3), "HeadTop", CFrame.new(0, 0.1, 0), color, Enum.Material.Fabric),
			p("CapVisor", Vector3.new(1.2, 0.12, 0.75), "HeadTop", CFrame.new(0, -0.05, -0.85), color, Enum.Material.Fabric),
		}
	elseif kind == "beanie" then
		return {
			p("Beanie", Vector3.new(1.35, 0.6, 1.35), "HeadTop", CFrame.new(0, 0.12, 0), color, Enum.Material.Fabric),
			p("Pompom", Vector3.new(0.45, 0.45, 0.45), "HeadTop", CFrame.new(0, 0.55, 0), Color3.fromRGB(245, 245, 245), Enum.Material.Fabric, Enum.PartType.Ball),
		}
	elseif kind == "ushanka" then
		return {
			p("Ushanka", Vector3.new(1.55, 0.6, 1.5), "HeadTop", CFrame.new(0, 0.15, 0), color, Enum.Material.Fabric),
			p("EarFlapL", Vector3.new(0.25, 0.8, 1.1), "HeadTop", CFrame.new(-0.72, -0.45, 0), color, Enum.Material.Fabric),
			p("EarFlapR", Vector3.new(0.25, 0.8, 1.1), "HeadTop", CFrame.new(0.72, -0.45, 0), color, Enum.Material.Fabric),
			p("Front", Vector3.new(1.5, 0.35, 0.25), "HeadTop", CFrame.new(0, 0.05, -0.7), color:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Fabric),
		}
	elseif kind == "cowboy" then
		return {
			p("Brim", Vector3.new(0.15, 2.5, 2.5), "HeadTop", CFrame.new(0, 0, 0) * R90, color, Enum.Material.Leather, Enum.PartType.Cylinder),
			p("HatCrown", Vector3.new(1.25, 0.7, 1.25), "HeadTop", CFrame.new(0, 0.38, 0), color, Enum.Material.Leather),
			p("Band", Vector3.new(1.3, 0.15, 1.3), "HeadTop", CFrame.new(0, 0.12, 0), Color3.fromRGB(60, 40, 25), Enum.Material.Leather),
		}
	elseif kind == "tophat" then
		return {
			p("Brim", Vector3.new(0.12, 2, 2), "HeadTop", CFrame.new(0, 0, 0) * R90, color, Enum.Material.Fabric, Enum.PartType.Cylinder),
			p("HatTube", Vector3.new(1.3, 1.25, 1.25), "HeadTop", CFrame.new(0, 0.65, 0) * R90, color, Enum.Material.Fabric, Enum.PartType.Cylinder),
			p("Band", Vector3.new(0.25, 1.3, 1.3), "HeadTop", CFrame.new(0, 0.18, 0) * R90, Color3.fromRGB(150, 20, 30), Enum.Material.Fabric, Enum.PartType.Cylinder),
		}
	elseif kind == "headphones" then
		return {
			p("Band", Vector3.new(1.5, 0.18, 0.3), "HeadTop", CFrame.new(0, 0.05, 0), color, Enum.Material.SmoothPlastic),
			p("CupL", Vector3.new(0.3, 0.6, 0.6), "HeadTop", CFrame.new(-0.72, -0.55, 0), color, Enum.Material.SmoothPlastic),
			p("CupR", Vector3.new(0.3, 0.6, 0.6), "HeadTop", CFrame.new(0.72, -0.55, 0), color, Enum.Material.SmoothPlastic),
			p("Light", Vector3.new(0.05, 0.25, 0.25), "HeadTop", CFrame.new(0.88, -0.55, 0), Color3.fromRGB(80, 220, 255), Enum.Material.Neon),
		}
	elseif kind == "crown" then
		local list = { p("CrownBand", Vector3.new(1.3, 0.35, 1.3), "HeadTop", CFrame.new(0, 0.12, 0), color, Enum.Material.Foil) }
		for i = 0, 3 do
			local a = math.rad(i * 90 + 45)
			table.insert(list, p("Spike", Vector3.new(0.3, 0.45, 0.3), "HeadTop", CFrame.new(math.sin(a) * 0.5, 0.45, math.cos(a) * 0.5), color, Enum.Material.Foil))
		end
		table.insert(list, p("Gem", Vector3.new(0.25, 0.25, 0.1), "HeadTop", CFrame.new(0, 0.15, -0.67), Color3.fromRGB(220, 30, 60), Enum.Material.Neon))
		return list
	elseif kind == "halo" then
		return { p("Halo", Vector3.new(0.15, 1.4, 1.4), "HeadTop", CFrame.new(0, 0.6, 0) * R90, color, Enum.Material.Neon, Enum.PartType.Cylinder) }
	elseif kind == "glasses" or kind == "star_glasses" then
		local frame = kind == "star_glasses" and color or BLACK
		local lens = kind == "star_glasses" and Color3.fromRGB(40, 20, 60) or Color3.fromRGB(150, 190, 220)
		return {
			p("LensL", Vector3.new(0.42, 0.3, 0.06), "Face", CFrame.new(-0.27, 0.1, -0.03), lens, Enum.Material.Glass),
			p("LensR", Vector3.new(0.42, 0.3, 0.06), "Face", CFrame.new(0.27, 0.1, -0.03), lens, Enum.Material.Glass),
			p("Bridge", Vector3.new(1.15, 0.07, 0.08), "Face", CFrame.new(0, 0.22, -0.04), frame, kind == "star_glasses" and Enum.Material.Neon or Enum.Material.Metal),
		}
	elseif kind == "scarf" then
		return {
			p("Scarf", Vector3.new(1.5, 0.35, 1.15), "Neck", CFrame.new(0, 0.05, 0), color, Enum.Material.Fabric),
			p("ScarfEnd", Vector3.new(0.35, 0.9, 0.15), "Chest", CFrame.new(0.35, 0.15, -0.05), color, Enum.Material.Fabric),
		}
	elseif kind == "backpack" then
		return {
			p("Backpack", Vector3.new(1.4, 1.5, 0.6), "Back", CFrame.new(0, -0.05, 0.3), color, Enum.Material.Fabric),
			p("Pocket", Vector3.new(1, 0.6, 0.15), "Back", CFrame.new(0, -0.4, 0.65), color:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Fabric),
		}
	elseif kind == "chain" then
		return {
			p("Chain", Vector3.new(0.12, 1, 1), "Chest", CFrame.new(0, 0.35, -0.02) * CFrame.Angles(0, math.rad(90), 0), color, Enum.Material.Foil, Enum.PartType.Cylinder),
			p("Pendant", Vector3.new(0.3, 0.35, 0.08), "Chest", CFrame.new(0, -0.1, -0.05), color, Enum.Material.Neon),
		}
	elseif kind == "wings" then
		return {
			p("WingL", Vector3.new(2.2, 2.6, 0.2), "Back", CFrame.new(-1.1, 0.2, 0.25) * CFrame.Angles(0, math.rad(25), math.rad(-15)), color, Enum.Material.Neon),
			p("WingR", Vector3.new(2.2, 2.6, 0.2), "Back", CFrame.new(1.1, 0.2, 0.25) * CFrame.Angles(0, math.rad(-25), math.rad(15)), color, Enum.Material.Neon),
		}
	end
	return {}
end

-- CFrame точки крепления для головы/торса заданных размеров.
function Outfits.AnchorCFrame(anchor, head, torso)
	if anchor == "HeadTop" then
		return head.CFrame * CFrame.new(0, math.max(head.Size.Y, 1.2) / 2, 0)
	elseif anchor == "Face" then
		return head.CFrame * CFrame.new(0, 0, -math.max(head.Size.Z, 1.2) / 2)
	elseif anchor == "Neck" then
		return torso.CFrame * CFrame.new(0, torso.Size.Y / 2, 0)
	elseif anchor == "Back" then
		return torso.CFrame * CFrame.new(0, torso.Size.Y * 0.1, torso.Size.Z / 2)
	end
	return torso.CFrame * CFrame.new(0, torso.Size.Y * 0.2, -torso.Size.Z / 2) -- Chest
end

function Outfits.MakePart(spec)
	local part = Instance.new("Part")
	part.Name = spec.Name
	if spec.Shape then
		part.Shape = spec.Shape
	end
	part.Size = spec.Size
	part.Color = spec.Color
	part.Material = spec.Material or Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

return Outfits
