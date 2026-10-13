#!/usr/bin/env python3
"""3D-превью города без Roblox: python3 render3d.py ../../tests/world3d.csv out.png "x,y,z" "дистанция,азимут,наклон" [радиус]"""
import sys, math
from PIL import Image, ImageDraw
csv, out = sys.argv[1], sys.argv[2]
tx, ty, tz = map(float, sys.argv[3].split(','))   # точка, куда смотрит камера
dist, yaw, pitch = map(float, sys.argv[4].split(','))  # расстояние, азимут°, наклон°
radius = float(sys.argv[5]) if len(sys.argv) > 5 else 300
W, H = 1400, 900
yr, pr = math.radians(yaw), math.radians(pitch)
cam = (tx + dist*math.cos(pr)*math.sin(yr), ty + dist*math.sin(pr), tz + dist*math.cos(pr)*math.cos(yr))
fwd = [tx-cam[0], ty-cam[1], tz-cam[2]]; n = math.sqrt(sum(v*v for v in fwd)); fwd = [v/n for v in fwd]
right = [-fwd[2], 0, fwd[0]]; n = math.sqrt(sum(v*v for v in right)); right = [v/n for v in right]
up = [right[1]*fwd[2]-right[2]*fwd[1], right[2]*fwd[0]-right[0]*fwd[2], right[0]*fwd[1]-right[1]*fwd[0]]
F = W * 0.9
SUN = [0.4, 0.8, 0.3]; n = math.sqrt(sum(v*v for v in SUN)); SUN = [v/n for v in SUN]
def proj(p):
    d = [p[0]-cam[0], p[1]-cam[1], p[2]-cam[2]]
    z = sum(a*b for a, b in zip(d, fwd))
    if z < 1: return None, z
    x = sum(a*b for a, b in zip(d, right)); y = sum(a*b for a, b in zip(d, up))
    return (W/2 + F*x/z, H/2 - F*y/z), z
faces = []
def add_face(pts, normal, col, alpha):
    c = [sum(p[i] for p in pts)/len(pts) for i in range(3)]
    view = [cam[i]-c[i] for i in range(3)]
    if sum(a*b for a, b in zip(view, normal)) <= 0: return
    pp = []; depth = 0
    for p in pts:
        q, z = proj(p)
        if q is None: return
        pp.append(q); depth += z
    shade = 0.5 + 0.5*max(0, sum(a*b for a, b in zip(normal, SUN)))
    faces.append((depth/len(pts), pp, tuple(int(min(255, ch*shade)) for ch in col), alpha))
for line in open(csv):
    r = line.rstrip('\n').split(',')
    name, shape = r[0], r[1]
    x, y, z = map(float, r[2:5]); rv = list(map(float, r[5:8])); uv = list(map(float, r[8:11])); lv = list(map(float, r[11:14]))
    sx, sy, sz = map(float, r[14:17]); col = tuple(int(float(v)) for v in r[17:20]); tr = float(r[20])
    if tr >= 0.9 or name in ('Border',): continue
    if abs(x-tx) > radius or abs(z-tz) > radius: continue
    if name == 'Ground': sx = sz = min(sx, radius*2.5); x, z = tx, tz
    bk = [-v for v in lv]
    P0 = (x, y, z)
    def W_(lx, ly, lz): return [P0[i] + rv[i]*lx + uv[i]*ly + bk[i]*lz for i in range(3)]
    def N_(a, b, c): return [rv[i]*a + uv[i]*b + bk[i]*c for i in range(3)]
    hx, hy, hz = sx/2, sy/2, sz/2
    alpha = 1 - tr
    if shape == 'Ball':
        q, d = proj([x, y, z])
        if q:
            rr = F*hx/d
            faces.append((d, ('circle', q, rr), tuple(int(ch*0.85) for ch in col), alpha))
        continue
    if shape == 'Cylinder':
        R = min(hy, hz); k = 14
        ring = [(math.cos(2*math.pi*i/k)*R, math.sin(2*math.pi*i/k)*R) for i in range(k)]
        for sgn in (-1, 1):
            add_face([W_(sgn*hx, a, b) for a, b in (ring if sgn > 0 else ring[::-1])], N_(sgn, 0, 0), col, alpha)
        for i in range(k):
            a1, b1 = ring[i]; a2, b2 = ring[(i+1) % k]
            nm = N_(0, (a1+a2)/2/R, (b1+b2)/2/R)
            add_face([W_(-hx, a1, b1), W_(-hx, a2, b2), W_(hx, a2, b2), W_(hx, a1, b1)], nm, col, alpha)
        continue
    if shape == 'Wedge':
        s = math.hypot(sy, sz)
        add_face([W_(-hx,-hy,-hz), W_(hx,-hy,-hz), W_(hx,-hy,hz), W_(-hx,-hy,hz)], N_(0,-1,0), col, alpha)
        add_face([W_(-hx,-hy,hz), W_(hx,-hy,hz), W_(hx,hy,hz), W_(-hx,hy,hz)], N_(0,0,1), col, alpha)
        add_face([W_(-hx,-hy,-hz), W_(hx,-hy,-hz), W_(hx,hy,hz), W_(-hx,hy,hz)], N_(0, sz/s, -sy/s), col, alpha)
        for sg in (-1, 1):
            add_face([W_(sg*hx,-hy,-hz), W_(sg*hx,-hy,hz), W_(sg*hx,hy,hz)], N_(sg,0,0), col, alpha)
        continue
    for axis in range(3):
        for sg in (-1, 1):
            if axis == 0: pts = [W_(sg*hx, a*hy, b*hz) for a, b in ((-1,-1),(1,-1),(1,1),(-1,1))]; nm = N_(sg,0,0)
            elif axis == 1: pts = [W_(a*hx, sg*hy, b*hz) for a, b in ((-1,-1),(1,-1),(1,1),(-1,1))]; nm = N_(0,sg,0)
            else: pts = [W_(a*hx, b*hy, sg*hz) for a, b in ((-1,-1),(1,-1),(1,1),(-1,1))]; nm = N_(0,0,sg)
            add_face(pts, nm, col, alpha)
faces.sort(key=lambda f: -f[0])
img = Image.new('RGB', (W, H), (104, 158, 82))
d = ImageDraw.Draw(img, 'RGBA')
far = [cam[0] + fwd[0]*1e5, cam[1], cam[2] + fwd[2]*1e5]
hz, _ = proj(far)
if hz:
    if hz[1] > 0: d.rectangle([0, 0, W, hz[1]], fill=(150, 190, 230))
for depth, pp, col, alpha in faces:
    a = int(255*alpha)
    if pp and pp[0] == 'circle':
        _, q, rr = pp; d.ellipse([q[0]-rr, q[1]-rr, q[0]+rr, q[1]+rr], fill=col + (a,))
    else:
        d.polygon(pp, fill=col + (a,))
img.save(out)
print(out, len(faces))
