#!/usr/bin/env python3
"""Конвертирует открытые картографические данные Первоуральска
(OpenStreetMap через Overture Maps, лицензия ODbL) в данные для Roblox.

Вход:  tools/pervouralsk/data/*.parquet  (см. fetch_overture.py)
Выход: src/server/Map/*.luau              (ModuleScript-ы со строками данных)

Масштаб: 1 метр = K studs. Север — это -Z, восток — +X.
Игровые здания (мэрия, полиция, больница, ...) ставятся рядом с реальными
объектами; реальные дома, которые им мешают, удаляются.
"""

import math
import os
import random

import pyarrow.parquet as pq
import shapely
from shapely import affinity, wkb
from shapely.geometry import LineString, Point, Polygon, box
from shapely.ops import unary_union
from shapely.strtree import STRtree

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "data")
OUT = os.path.join(HERE, "..", "..", "src", "server", "Map")

K = 1.4
LAT0, LON0 = 56.905, 59.945
KX = math.cos(math.radians(LAT0)) * 111320 * K
KZ = 110540 * K
# Границы игровой зоны в метрах (x — восток, z — юг).
BX = (-1100 * K, 1500 * K)
BZ = (-1400 * K, 1700 * K)
BOUNDS = box(BX[0], BZ[0], BX[1], BZ[1])

random.seed(42)


def proj(lon, lat):
    return ((lon - LON0) * KX, -(lat - LAT0) * KZ)


def proj_geom(g):
    return shapely.transform(g, lambda c: [[(x - LON0) * KX, -(y - LAT0) * KZ] for x, y in c])


def load(name):
    return pq.read_table(os.path.join(DATA, name)).to_pylist()


def r1(v):
    return f"{v:.1f}".rstrip("0").rstrip(".")


# ---------------------------------------------------------------------------
# Дороги
# ---------------------------------------------------------------------------
ROAD_W = {
    "primary": 34, "secondary": 30, "tertiary": 26, "unclassified": 20, "residential": 20,
    "living_street": 18, "service": 12, "pedestrian": 10,
}
ROAD_CLASSES = list(ROAD_W) + ["rail"]
MAJOR = {"primary", "secondary", "tertiary", "unclassified", "residential", "living_street"}

roads = []  # (LineString, class, name)
for r in load("transportation_segment.parquet"):
    cls = r["class"] if r["subtype"] == "road" else ("rail" if r["subtype"] == "rail" else None)
    if cls not in ROAD_W and cls != "rail":
        continue
    g = proj_geom(wkb.loads(r["geometry"])).intersection(BOUNDS)
    if g.is_empty:
        continue
    name = (r["names"] or {}).get("primary") if r.get("names") else None
    for line in getattr(g, "geoms", [g]):
        if line.geom_type != "LineString" or line.length < 2:
            continue
        roads.append((line.simplify(1.5), cls, name))

major_lines = [l for l, c, _ in roads if c in MAJOR]
major_buf = unary_union([l.buffer(ROAD_W[c] / 2) for l, c, _ in roads if c in MAJOR])
all_road_buf = unary_union([l.buffer(ROAD_W.get(c, 8) / 2) for l, c, _ in roads])
major_tree = STRtree(major_lines)
major_w = {id(l): ROAD_W[c] for l, c, _ in roads if c in MAJOR}

# ---------------------------------------------------------------------------
# Вода
# ---------------------------------------------------------------------------
water_geoms = []
for r in load("base_water.parquet"):
    g = proj_geom(wkb.loads(r["geometry"]))
    if g.geom_type in ("LineString", "MultiLineString"):
        w = 16 if r["class"] in ("river", "canal") else 7
        g = g.buffer(w / 2)
    elif g.geom_type not in ("Polygon", "MultiPolygon"):
        continue
    g = g.intersection(BOUNDS)
    if not g.is_empty:
        water_geoms.append(g)
water = unary_union(water_geoms) if water_geoms else Polygon()

# ---------------------------------------------------------------------------
# Парки
# ---------------------------------------------------------------------------
parks = []
for r in load("base_land_use.parquet"):
    if r["subtype"] == "park" or r["class"] in ("park", "garden"):
        g = proj_geom(wkb.loads(r["geometry"]))
        if g.geom_type in ("Polygon", "MultiPolygon"):
            g = g.intersection(BOUNDS)
            if not g.is_empty:
                parks.append(g)
park_union = unary_union(parks) if parks else Polygon()

# ---------------------------------------------------------------------------
# Здания
# ---------------------------------------------------------------------------
buildings = []  # dict(poly, floors, subtype)
for r in load("buildings_building.parquet"):
    g = proj_geom(wkb.loads(r["geometry"]))
    if not g.intersects(BOUNDS):
        continue
    for poly in getattr(g, "geoms", [g]):
        if poly.geom_type != "Polygon" or poly.area < 20:
            continue
        if not BOUNDS.contains(poly.centroid):
            continue
        buildings.append({"poly": poly.buffer(0), "floors": r["num_floors"], "subtype": r["subtype"], "class": r["class"]})
btree = STRtree([b["poly"] for b in buildings])

# ---------------------------------------------------------------------------
# Реальные объекты (места)
# ---------------------------------------------------------------------------
places = {}
for r in load("places_place.parquet"):
    n = (r["names"] or {}).get("primary") or ""
    p = wkb.loads(r["geometry"])
    places.setdefault(n, proj(p.x, p.y))


def place(name, fallback=None):
    for n, pos in places.items():
        if name in n:
            return pos
    if fallback is None:
        raise KeyError(name)
    return (fallback[0] * K, fallback[1] * K)


# ---------------------------------------------------------------------------
# Расстановка игровых зданий
# ---------------------------------------------------------------------------
reserved = []  # Polygon-ы, занятые игровыми объектами


def rect_poly(x, z, yaw, w, d, front=0.0, back=0.0, side=0.0):
    """Прямоугольник здания в мировых координатах (локальный +Z — фасад)."""
    c, s = math.cos(yaw), math.sin(yaw)
    pts = []
    for lx, lz in ((-w / 2 - side, -d / 2 - back), (w / 2 + side, -d / 2 - back), (w / 2 + side, d / 2 + front), (-w / 2 - side, d / 2 + front)):
        pts.append((x + lx * c + lz * s, z - lx * s + lz * c))
    return Polygon(pts)


def road_dist(pt):
    best = 1e9
    for i in major_tree.query(pt.buffer(120)):
        line = major_lines[i]
        d = line.distance(pt) - major_w[id(line)] / 2
        best = min(best, d)
    return best


def removed_area(poly):
    return sum(buildings[i]["poly"].intersection(poly).area for i in btree.query(poly))


def find_spot(target, w, d, front, back=0, side=4, radius=420, step=8, need_road=True, yaws=(0, 90, 180, 270)):
    tx, tz = target
    best = None
    for dx in range(-radius, radius + 1, step):
        for dz in range(-radius, radius + 1, step):
            dist = math.hypot(dx, dz)
            if dist > radius:
                continue
            x, z = tx + dx, tz + dz
            for yd in yaws:
                yaw = math.radians(yd)
                poly = rect_poly(x, z, yaw, w, d, front, back, side)
                if not BOUNDS.contains(poly):
                    continue
                if poly.intersects(major_buf) or poly.intersects(water):
                    continue
                if any(poly.intersects(rp) for rp in reserved):
                    continue
                cost = dist
                if need_road:
                    fx = x + math.sin(yaw) * (d / 2 + front + 4)
                    fz = z + math.cos(yaw) * (d / 2 + front + 4)
                    rd = road_dist(Point(fx, fz))
                    if rd > 14:
                        continue
                    cost += rd * 2
                cost += removed_area(poly) * 0.004
                if best is None or cost < best[0]:
                    best = (cost, x, z, yd, poly)
    if best is None:
        raise RuntimeError(f"Не найдено место для объекта у {target}")
    _, x, z, yd, poly = best
    reserved.append(poly.buffer(4))
    return {"X": round(x, 1), "Z": round(z, 1), "Yaw": yd}


anchors = {}
# key: (поиск места, ширина, глубина, запас спереди, запас сзади, запас сбоку)
SPECS = [
    ("CityHall", place("Администрация Города Первоуральск"), 90, 70, 72, 0, 4),
    ("Police", place("Отдел МВД России"), 90, 70, 66, 0, 4),
    ("Hospital", place("Городская больница №1"), 100, 80, 34, 0, 4),
    ("Bank", place("Сбербанк"), 80, 70, 48, 0, 4),
    ("Cafe", place("Пельменная"), 70, 60, 30, 0, 4),
    ("Supermarket", place("Магнит"), 100, 76, 48, 0, 4),
    ("Florist", place("Цветочная Страна"), 16, 12, 10, 0, 2),
    ("Wedding", place("ЗАГС"), 50, 80, 32, 0, 4),
    ("Office", (60 * K, -250 * K), 80, 64, 30, 0, 4),
    ("Dealership", (700 * K, 820 * K), 90, 60, 34, 0, 4),
    ("Factory", (1150 * K, 420 * K), 110, 90, 30, 40, 4),
    ("Jail", (-650 * K, 950 * K), 94, 92, 30, 0, 4),
]
for key, target, w, d, front, back, side in SPECS:
    anchors[key] = find_spot(target, w, d, front, back, side)
    anchors[key].update({"W": w, "D": d})
    print("anchor", key, anchors[key])

# Парк: реальный «Парк культуры и отдыха», круг радиусом ~85 studs.
park_target = place("Парк Культуры И Отдыха")
best = None
for dx in range(-300, 301, 10):
    for dz in range(-300, 301, 10):
        c = Point(park_target[0] + dx, park_target[1] + dz)
        circ = c.buffer(85)
        if circ.intersects(major_buf) or circ.intersects(water) or any(circ.intersects(rp) for rp in reserved):
            continue
        cost = math.hypot(dx, dz) + removed_area(circ) * 0.01
        if best is None or cost < best[0]:
            best = (cost, c)
anchors["Park"] = {"X": round(best[1].x, 1), "Z": round(best[1].y, 1), "Yaw": 0}
reserved.append(best[1].buffer(88))
print("anchor Park", anchors["Park"])

# Дома игроков — в частном секторе на юге города.
houses = []
small = [b for b in buildings if b["poly"].area < 260 * K * K and b["poly"].centroid.y > 1180 * K and abs(b["poly"].centroid.x) < 700 * K]
small.sort(key=lambda b: math.hypot(b["poly"].centroid.x - 0, b["poly"].centroid.y - 1250 * K))
for b in small:
    if len(houses) >= 12:
        break
    c = b["poly"].centroid
    if any(math.hypot(c.x - h["X"], c.y - h["Z"]) < 70 for h in houses):
        continue
    try:
        spot = find_spot((c.x, c.y), 34, 34, 18, 0, 3, radius=50, step=6)
    except RuntimeError:
        continue
    houses.append(spot)
print("houses", len(houses))
assert len(houses) == 12, "не хватило мест под дома"

reserved_union = unary_union(reserved)

# ---------------------------------------------------------------------------
# Генерация данных
# ---------------------------------------------------------------------------
CLS_INDEX = {c: i + 1 for i, c in enumerate(ROAD_CLASSES)}

road_out = []
discs = {}
for line, cls, name in roads:
    if cls in ("service", "pedestrian") and line.intersects(reserved_union):
        continue
    w = ROAD_W.get(cls, 8)
    coords = list(line.coords)
    for (x1, z1), (x2, z2) in zip(coords, coords[1:]):
        if math.hypot(x2 - x1, z2 - z1) < 0.5:
            continue
        road_out.append(f"{r1(x1)},{r1(z1)},{r1(x2)},{r1(z2)},{w},{CLS_INDEX[cls]}")
    if cls != "rail":
        for x, z in coords:
            k = (round(x / 2), round(z / 2))
            if discs.get(k, (0,))[0] < w:
                discs[k] = (w, x, z)
disc_out = [f"{r1(x)},{r1(z)},{w}" for w, x, z in discs.values()]

# Названия улиц.
signs = []
by_name = {}
for line, cls, name in roads:
    if name and cls in MAJOR:
        by_name.setdefault(name, []).append(line)
for name, lines in by_name.items():
    total = sum(l.length for l in lines)
    if total < 150:
        continue
    for line in lines:
        n = int(line.length // 420) + (1 if line.length > 160 else 0)
        for i in range(n):
            p = line.interpolate((i + 0.5) / max(n, 1), normalized=True)
            q = line.interpolate(min(line.project(p) + 2, line.length))
            ang = math.atan2(q.y - p.y, q.x - p.x)
            off = 14
            sx, sz = p.x - math.sin(ang) * off, p.y + math.cos(ang) * off
            if Point(sx, sz).buffer(2).intersects(reserved_union):
                continue
            signs.append(f"{r1(sx)},{r1(sz)},{r1(-math.degrees(ang))},{name.replace(',', ' ').replace(';', ' ')}")

# Здания — разбиваем на прямоугольники.
PALETTE_BIG = [1, 2, 3, 4, 5]
PALETTE_SMALL = [6, 7, 8, 9]


def decompose(poly):
    mrr = poly.minimum_rotated_rectangle
    if mrr.geom_type != "Polygon":
        return []
    co = list(mrr.exterior.coords)
    edges = [(co[i], co[i + 1]) for i in range(4)]
    (ax, az), (bx, bz) = max(edges, key=lambda e: math.hypot(e[1][0] - e[0][0], e[1][1] - e[0][1]))
    ang = math.atan2(bz - az, bx - ax)
    c = poly.centroid
    rot = affinity.rotate(poly, -ang, origin=c, use_radians=True)
    minx, minz, maxx, maxz = rot.bounds
    rects = []
    if rot.area / max(box(minx, minz, maxx, maxz).area, 1) > 0.82:
        rects.append((minx, minz, maxx, maxz))
    else:
        cell = 3.0
        nx = max(1, int(math.ceil((maxx - minx) / cell)))
        nz = max(1, int(math.ceil((maxz - minz) / cell)))
        prepared = shapely.prepared.prep(rot)
        grid = [[prepared.contains(Point(minx + (i + 0.5) * cell, minz + (j + 0.5) * cell)) for i in range(nx)] for j in range(nz)]
        runs_prev = {}
        for j in range(nz + 1):
            runs = {}
            if j < nz:
                i = 0
                while i < nx:
                    if grid[j][i]:
                        s = i
                        while i < nx and grid[j][i]:
                            i += 1
                        runs[(s, i)] = j
                    else:
                        i += 1
            for key, start in runs_prev.items():
                if key in runs:
                    runs[key] = start
                else:
                    s, e = key
                    rects.append((minx + s * cell, minz + start * cell, minx + e * cell, minz + j * cell))
            runs_prev = runs
    out = []
    for x0, z0, x1, z1 in rects:
        lc = Point((x0 + x1) / 2, (z0 + z1) / 2)
        wc = affinity.rotate(lc, ang, origin=c, use_radians=True)
        out.append((wc.x, wc.y, x1 - x0, z1 - z0, -math.degrees(ang)))
    return out


bld_out = []
removed = 0
for b in buildings:
    poly = b["poly"]
    if poly.intersects(reserved_union) or poly.intersects(major_buf.buffer(-3)):
        removed += 1
        continue
    area_m2 = poly.area / (K * K)
    floors = b["floors"]
    if not floors:
        if area_m2 < 130:
            floors = 1
        elif area_m2 < 400:
            floors = 2
        elif b["subtype"] == "industrial" or b["class"] in ("industrial", "warehouse"):
            floors = 3
        else:
            floors = 5
    h = 8 if floors == 1 else floors * 5 + 2
    if b["subtype"] == "industrial" or b["class"] in ("industrial", "warehouse"):
        color = 10
    elif floors <= 1:
        color = random.choice(PALETTE_SMALL)
    else:
        color = random.choice(PALETTE_BIG)
    for cx, cz, sx, sz, yaw in decompose(poly):
        if sx < 1.5 or sz < 1.5:
            continue
        bld_out.append(f"{r1(cx)},{r1(cz)},{r1(sx)},{r1(sz)},{r1(yaw)},{h},{color}")
print("buildings parts", len(bld_out), "removed", removed)


# Растеризация полигонов в прямоугольники (вода, парки).
def raster_rects(geom, cell):
    if geom.is_empty:
        return []
    prepared = shapely.prepared.prep(geom)
    minx, minz, maxx, maxz = geom.bounds
    nx = int(math.ceil((maxx - minx) / cell))
    nz = int(math.ceil((maxz - minz) / cell))
    rects = []
    prev = {}
    for j in range(nz + 1):
        runs = {}
        if j < nz:
            i = 0
            while i < nx:
                if prepared.contains(Point(minx + (i + 0.5) * cell, minz + (j + 0.5) * cell)):
                    s = i
                    while i < nx and prepared.contains(Point(minx + (i + 0.5) * cell, minz + (j + 0.5) * cell)):
                        i += 1
                    runs[(s, i)] = j
                else:
                    i += 1
        for key, start in prev.items():
            if key in runs:
                runs[key] = start
            else:
                s, e = key
                rects.append((minx + s * cell, minz + start * cell, minx + e * cell, minz + j * cell))
        prev = runs
    return [f"{r1((a + c) / 2)},{r1((b + d) / 2)},{r1(c - a)},{r1(d - b)}" for a, b, c, d in rects]


water_out = raster_rects(water, 8)
park_out = raster_rects(park_union.difference(major_buf), 8)
print("water rects", len(water_out), "park rects", len(park_out))

# Деревья в парках и на пустырях.
occupied = unary_union([b["poly"] for b in buildings] + [all_road_buf, water, reserved_union])
occ = shapely.prepared.prep(occupied.buffer(5))
occ_far = shapely.prepared.prep(occupied.buffer(30))
trees = []
minx, minz, maxx, maxz = park_union.bounds if not park_union.is_empty else (0, 0, 0, 0)
park_prep = shapely.prepared.prep(park_union)
for _ in range(9000):
    if len(trees) >= 450:
        break
    x, z = random.uniform(minx, maxx), random.uniform(minz, maxz)
    p = Point(x, z)
    if park_prep.contains(p) and not occ.contains(p):
        trees.append(f"{r1(x)},{r1(z)}")
for _ in range(20000):
    if len(trees) >= 900:
        break
    x, z = random.uniform(*BX), random.uniform(*BZ)
    p = Point(x, z)
    if not occ_far.contains(p):
        trees.append(f"{r1(x)},{r1(z)}")
print("trees", len(trees))

# Фонари, точки машин, посты полиции.
lamps, car_spawns = [], []
occ_strict = shapely.prepared.prep(unary_union([b["poly"] for b in buildings] + [reserved_union, water]).buffer(2))
for line, cls, name in roads:
    if cls not in ("primary", "secondary", "tertiary"):
        continue
    w = ROAD_W[cls]
    L = line.length
    d = 40.0
    side = 1
    while d < L - 40:
        p = line.interpolate(d)
        q = line.interpolate(min(d + 2, L))
        ang = math.atan2(q.y - p.y, q.x - p.x)
        nxv, nzv = -math.sin(ang), math.cos(ang)
        lx, lz = p.x + nxv * (w / 2 + 3) * side, p.y + nzv * (w / 2 + 3) * side
        lp = Point(lx, lz)
        if not occ_strict.contains(lp) and not all_road_buf.contains(lp):
            lamps.append(f"{r1(lx)},{r1(lz)}")
        side = -side
        if len(car_spawns) < 400 and d > 60 and d < L - 60:
            cx, cz = p.x + nxv * (w / 4), p.y + nzv * (w / 4)
            yaw = math.degrees(math.atan2(-(q.x - p.x), -(q.y - p.y)))
            car_spawns.append(f"{r1(cx)},{r1(cz)},{r1(yaw)}")
        d += 130
lamps = lamps[:420]

# Перекрёстки главных улиц для постов полиции.
ends = {}
for line, cls, name in roads:
    if cls in ("primary", "secondary", "tertiary"):
        for pt in (line.coords[0], line.coords[-1]):
            k = (round(pt[0] / 6), round(pt[1] / 6))
            ends.setdefault(k, []).append((pt, ROAD_W[cls]))
cands = [(v[0][0], max(w for _, w in v)) for v in ends.values() if len(v) >= 3]
posts = []
cands.sort(key=lambda c: math.hypot(c[0][0] - 0, c[0][1] - 300 * K))
for (x, z), w in cands:
    if len(posts) >= 9:
        break
    if any(math.hypot(x - px, z - pz) < 400 for px, pz in posts):
        continue
    px, pz = x + w / 2 + 6, z + w / 2 + 6
    if occ_strict.contains(Point(px, pz)) or all_road_buf.contains(Point(px, pz)):
        continue
    posts.append((px, pz))
print("posts", len(posts), "lamps", len(lamps), "cars", len(car_spawns))

landmarks = []
if not water.is_empty:
    biggest = max(getattr(water, "geoms", [water]), key=lambda g: g.area)
    p = biggest.representative_point()
    landmarks.append(("Нижнешайтанский пруд", p.x, p.y))
landmarks.append(("Частный сектор (дома игроков)", houses[0]["X"], houses[0]["Z"]))
landmarks.append(("Улица Ватутина", *place("ул. Ватутина")))


# ---------------------------------------------------------------------------
# Запись Luau-модулей
# ---------------------------------------------------------------------------
def lua_str(s):
    return "[==[" + s + "]==]"


def write(name, body):
    path = os.path.join(OUT, name + ".luau")
    with open(path, "w", encoding="utf-8") as f:
        f.write(body)
    print("wrote", path, os.path.getsize(path))


def write_chunks(base, rows, per=4000):
    names = []
    for i in range(0, len(rows), per):
        n = f"{base}{i // per + 1}"
        write(n, "-- Сгенерировано tools/pervouralsk/convert.py. Данные © участники OpenStreetMap (ODbL).\nreturn " + lua_str(";".join(rows[i:i + per])) + "\n")
        names.append(n)
    return names


os.makedirs(OUT, exist_ok=True)
for f in os.listdir(OUT):
    if f.endswith(".luau"):
        os.remove(os.path.join(OUT, f))

chunks = {
    "Roads": write_chunks("Roads", road_out),
    "Discs": write_chunks("Discs", disc_out),
    "Buildings": write_chunks("Buildings", bld_out, 3500),
    "Water": write_chunks("Water", water_out),
    "Parks": write_chunks("Parks", park_out),
    "Trees": write_chunks("Trees", trees),
    "Lamps": write_chunks("Lamps", lamps),
    "CarSpawns": write_chunks("CarSpawns", car_spawns),
    "Signs": write_chunks("Signs", signs),
}


def anchor_lua(a):
    return "{ " + ", ".join(f"{k} = {v}" for k, v in a.items()) + " }"


meta = ["-- Первоуральск: метаданные карты. Сгенерировано tools/pervouralsk/convert.py.",
        "-- Картографические данные © участники OpenStreetMap, лицензия ODbL (через Overture Maps).",
        "return {",
        f"\tScale = {K},",
        f"\tBounds = {{ MinX = {r1(BX[0])}, MaxX = {r1(BX[1])}, MinZ = {r1(BZ[0])}, MaxZ = {r1(BZ[1])} }},",
        "\tRoadClasses = { " + ", ".join(f'"{c}"' for c in ROAD_CLASSES) + " },",
        "\tAnchors = {"]
for k, a in anchors.items():
    meta.append(f"\t\t{k} = {anchor_lua(a)},")
meta.append("\t},")
meta.append("\tHouses = {")
for h in houses:
    meta.append(f"\t\t{anchor_lua(h)},")
meta.append("\t},")
meta.append("\tPatrolPosts = {")
for x, z in posts:
    meta.append(f"\t\t{{ X = {r1(x)}, Z = {r1(z)} }},")
meta.append("\t},")
meta.append("\tLandmarks = {")
for n, x, z in landmarks:
    meta.append(f'\t\t{{ Name = "{n}", X = {r1(x)}, Z = {r1(z)} }},')
meta.append("\t},")
meta.append("\tChunks = {")
for k, names in chunks.items():
    meta.append(f"\t\t{k} = {{ " + ", ".join(f'"{n}"' for n in names) + " },")
meta.append("\t},")
meta.append("}")
write("Meta", "\n".join(meta) + "\n")
