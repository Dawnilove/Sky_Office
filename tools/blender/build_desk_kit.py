"""책상 · 모니터 · 의자 후보 (KayKit Extra 미리보기를 스타일 레퍼런스로: 두툼한 판 · 크게 둥근 모서리 · 굵은 다리 · 단순한 덩어리)

미리보기 (OverLand 폴더에서):
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P SkyOffice/tools/blender/build_desk_kit.py -- <출력 폴더>
  → pick_desk_kit.png (줄 1 책상 A·B·C / 줄 2 모니터 A·B·C / 줄 3 의자 A·B·C / 줄 4 조합 세트)
  → pick_desk_kit_small.png (같은 그림을 게임 크기 — 책상 ≈ 50px — 로 줄인 것, 가독성 확인용)
- 좌표 · 단위는 build_office_props.py 와 같음 (상판 높이 TOP 0.48, 의자 방석 SEAT_TOP 0.28, 사람 쪽 = -Y)
- 2차 (사용자 '조금만 더 정성'): 두 겹 상판 · 좁아지는 다리 · 서랍 면판 + 손잡이 · 가림판 / 둥근 모니터 + 뒷 덮개 / 곡면 등받이 · 바퀴 · 팔걸이 / 관절 스탠드 · 화분 · 펜꽂이
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_office_props import Parts, clear, export, mat, PANEL_TOP, TOP, SEAT_TOP  # noqa: E402
from build_workroom import add_leaf, pot_round  # noqa: E402

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(ARGV[0]) if ARGV else "."
EXPORT = "--export" in ARGV
## 게임이 이름으로 찾는 부품을 따로 모으는 곳 (내보낼 때만 씀): Screen · ChairBack · Bulb
SP, BP = [None], [None]
WOOD, WOOD_TOP, WOOD_D, FRONT = "#9a7458", "#a98468", "#7d5d47", "#a07c60"
METAL, KNOB = "#5c6067", "#e6dfd2"
MON, MON_D, SCR = "#ece9e3", "#d4d0c8", "#2c3540"
CHAIR, CHAIR_D, BASE = "#7f93ad", "#6a7d96", "#45484e"


def M(n, c, r=0.7, metal=0.0):
    return mat(n, c, r, metal)


def tbox(p, m, c, size, rot=(0, 0, 0), bevel=0.02, seg=2):
    """아무 방향으로 돌린 둥근 상자 (rot = 도, X · Y · Z)"""
    tb = bmesh.new()
    bmesh.ops.create_cube(tb, size=1.0)
    bmesh.ops.scale(tb, vec=Vector(size), verts=tb.verts)
    if bevel > 0:
        bmesh.ops.bevel(tb, geom=list(tb.edges), offset=min(bevel, min(size) * 0.45), segments=seg, affect="EDGES",
                        profile=0.5)
    p._add(tb, m, Vector(c), rot)


def tleg(p, m, x, y, z0, z1, r0, r1):
    """끝이 좁아지는 네모 다리 (원뿔 4각 45° 돌림 = 네모)"""
    p.cone(m, (x, y, z0), r0, r1, z1 - z0, seg=4, rot=(0, 0, 45))


# ------------------------------------------------------------------ 책상 (1.2 × 0.6)
def desk(v, p):
    w, wt, wd, fr = M("KWood", WOOD), M("KWoodTop", WOOD_TOP, 0.6), M("KWoodD", WOOD_D, 0.75), M("KFront", FRONT, 0.65)
    k = M("Knob", KNOB, 0.4)
    UND = TOP - 0.085   # 상판 밑면

    def top(cx, cy, sx, sy):   # 두 겹 상판: 밝은 윗판 + 살짝 들어간 진한 띠 (가장자리가 또렷)
        p.box(wt, (cx, cy, TOP - 0.025), (sx, sy, 0.05), bevel=0.024, seg=3)
        p.box(wd, (cx, cy, TOP - 0.065), (sx - 0.03, sy - 0.03, 0.04), bevel=0.015)

    def pedestal(x, y=0.0, depth=0.5):   # 서랍 받침: 몸통 + 받침대 + 서랍 3 (면판 + 가로 손잡이)
        h = UND - 0.03
        p.box(w, (x, y, 0.03 + h / 2), (0.36, depth, h), bevel=0.03, seg=2)
        p.box(wd, (x, y + 0.01, 0.018), (0.33, depth - 0.04, 0.036), bevel=0.01)
        fy = y - depth / 2 - 0.006
        for i, (z, hh) in enumerate(((0.07, 0.11), (0.19, 0.1), (0.3, 0.1))):
            p.box(fr, (x, fy, z + hh / 2), (0.31, 0.02, hh - 0.012), bevel=0.012, seg=2)
            p.box(k, (x, fy - 0.016, z + hh * 0.62), (0.12, 0.016, 0.018), bevel=0.007)

    def legs(pts):
        for x, y in pts:
            tleg(p, w, x, y, 0.0, UND, 0.038, 0.052)
            p.cyl(wd, (x, y, 0.0), 0.034, 0.015, seg=10)   # 발 덮개

    def modesty(x0, x1):   # 뒤 가림판 (앞줄 직원 다리 가림 · 마주 보는 책상 쪽)
        p.box(w, ((x0 + x1) / 2, 0.24, UND - 0.11), (x1 - x0, 0.03, 0.2), bevel=0.012)

    if v == "A":     # 서랍 받침 1 + 다리 2
        top(0, 0, 1.2, 0.6)
        pedestal(-0.38)
        legs(((0.52, -0.22), (0.52, 0.22)))
        modesty(-0.2, 0.5)
    elif v == "B":   # 양쪽 서랍 (중역 책상) + 가운데 얕은 서랍
        top(0, 0, 1.2, 0.6)
        pedestal(-0.4)
        pedestal(0.4)
        p.box(fr, (0, -0.27, UND - 0.045), (0.4, 0.02, 0.07), bevel=0.012)
        p.box(k, (0, -0.287, UND - 0.045), (0.12, 0.016, 0.018), bevel=0.007)
        modesty(-0.22, 0.22)
    else:            # ㄱ자: 오른쪽으로 꺾인 판, 꺾인 쪽 아래 서랍 받침
        top(0, 0, 1.2, 0.6)
        top(0.75, 0.15, 0.42, 0.9)
        p.box(wd, (0.555, 0.0, TOP - 0.065), (0.06, 0.55, 0.04), bevel=0.01)   # 이음 띠
        pedestal(0.77, 0.32, 0.4)
        legs(((-0.54, -0.22), (-0.54, 0.22), (0.9, -0.22)))
        modesty(-0.5, 0.5)


# ------------------------------------------------------------------ 모니터 (책상 위, 화면 = 따로 된 색 — 게임에선 Screen 으로 나눔)
def monitor(v, p, y=0.17):
    b, bd, s = M("MonBody", MON, 0.4), M("MonBack", MON_D, 0.5), M("MonScr", SCR, 0.25)
    z0 = TOP

    def stand(x, rz=0.0):
        p.box(b, (x, y + 0.01, z0 + 0.012), (0.2, 0.13, 0.024), bevel=0.04, seg=3, rot_z=rz)      # 둥근 네모 받침
        tbox(p, b, (x, y + 0.035, z0 + 0.11), (0.055, 0.035, 0.2), rot=(-8, 0, math.degrees(rz)), bevel=0.016)
        p.sphere(bd, (x, y + 0.045, z0 + 0.2), 0.03, sub=2)                                        # 경첩

    def panel(x, z, wdt, hgt, rz=0.0):
        rzd = math.degrees(rz)
        fx, fy = -math.sin(rz), -math.cos(rz)   # 앞 방향 (사람 쪽)
        tbox(p, b, (x, y, z), (wdt, 0.045, hgt), rot=(0, 0, rzd), bevel=0.03, seg=3)              # 테두리
        tbox(p, bd, (x - fx * 0.035, y - fy * 0.035, z - 0.01), (wdt * 0.55, 0.04, hgt * 0.55), rot=(0, 0, rzd),
             bevel=0.02, seg=2)                                                                      # 뒷 덮개 (뒷줄에서 보임)
        tbox(SP[0] or p, s, (x + fx * 0.024, y + fy * 0.024, z + 0.008), (wdt - 0.06, 0.006, hgt - 0.07), rot=(0, 0, rzd),
             bevel=0.006, seg=1)                                                                     # 화면

    if v == "A":     # 큰 1대
        stand(0.0)
        panel(0.0, z0 + 0.31, 0.54, 0.34)
    elif v == "B":   # 2대, 안쪽으로 꺾음
        for sx in (-1, 1):
            rz = math.radians(14 * sx)
            stand(0.25 * sx, rz)
            panel(0.25 * sx, z0 + 0.3, 0.46, 0.3, rz)
    else:            # 휘어진 와이드 (3조각) + 노트북
        stand(0.0)
        for i, ang in ((-1, -9), (0, 0), (1, 9)):
            rz = math.radians(ang)
            panel(0.255 * i, z0 + 0.3, 0.27 if i else 0.25, 0.3, rz)
        lb = M("Laptop", "#b9bec6", 0.4, 0.3)
        p.box(lb, (0.45, -0.07, z0 + 0.01), (0.26, 0.18, 0.02), bevel=0.012, rot_z=math.radians(-14))
        tbox(p, lb, (0.47, 0.02, z0 + 0.09), (0.26, 0.014, 0.17), rot=(-12, 0, -14), bevel=0.01)
        tbox(SP[0] or p, s, (0.468, 0.012, z0 + 0.092), (0.22, 0.004, 0.13), rot=(-12, 0, -14), bevel=0, seg=1)
    # 키보드 (키 줄 3) · 마우스 · 패드
    kb, kd = M("Keys", "#f0ede7", 0.6), M("KeysRow", "#c9c4bb", 0.7)
    p.box(kb, (0, -0.1, z0 + 0.013), (0.38, 0.13, 0.026), bevel=0.012, seg=2)
    for r in range(3):
        p.box(kd, (0, -0.135 + r * 0.035, z0 + 0.027), (0.33, 0.022, 0.004), bevel=0)
    p.box(M("Pad", "#5f6f80", 0.9), (0.29, -0.1, z0 + 0.003), (0.16, 0.14, 0.006), bevel=0.01)
    p.sphere(kb, (0.29, -0.1, z0 + 0.016), 0.03, sub=2, scale=(0.75, 1.1, 0.5))


# ------------------------------------------------------------------ 의자 (가운데 = (0, y), 사람은 +Y 를 봄)
def chair(v, p, y=-0.55):
    c, cd, bs = M("ChairC", CHAIR, 0.85), M("ChairD", CHAIR_D, 0.85), M("ChairBase", BASE, 0.45, 0.2)
    for k in range(5):   # 다섯 발 (끝이 살짝 내려감) + 바퀴
        a = math.radians(90 + k * 72)
        tbox(p, bs, (0.11 * math.cos(a), y + 0.11 * math.sin(a), 0.055), (0.22, 0.045, 0.035),
             rot=(0, 6, math.degrees(a)), bevel=0.014)
        p.cyl(bs, (0.22 * math.cos(a) - 0.015, y + 0.22 * math.sin(a), 0.022), 0.022, 0.03, seg=10, rot=(0, 90, 0))
    p.cone(bs, (0, y, 0.06), 0.05, 0.03, 0.05, seg=12)          # 가스 실린더 덮개
    p.cyl(M("Chrome", "#9aa0a6", 0.3, 0.7), (0, y, 0.1), 0.022, SEAT_TOP - 0.17, seg=10)
    p.box(bs, (0, y, SEAT_TOP - 0.085), (0.3, 0.28, 0.03), bevel=0.012)   # 방석 아래 판

    def seat(wd=0.42, dp=0.4):
        p.box(c, (0, y + 0.01, SEAT_TOP - 0.04), (wd, dp, 0.08), bevel=0.04, seg=3)
        tbox(p, c, (0, y + dp / 2 - 0.01, SEAT_TOP - 0.06), (wd - 0.02, 0.06, 0.06), rot=(35, 0, 0), bevel=0.025)   # 앞 끝 둥글게

    def curved_back(z0, hgt, wd, r=0.38, th=0.075):   # 곡면 등받이: 둥근 상자를 잘게 자른 뒤 사람 쪽으로 감아 휨 (매끈하게)
        tb = bmesh.new()
        bmesh.ops.create_cube(tb, size=1.0)
        bmesh.ops.scale(tb, vec=Vector((wd, th, hgt)), verts=tb.verts)
        bmesh.ops.bevel(tb, geom=list(tb.edges), offset=0.03, segments=3, affect="EDGES", profile=0.5)
        for k in range(1, 10):
            xx = -wd / 2 + wd * k / 10
            g = list(tb.verts) + list(tb.edges) + list(tb.faces)
            bmesh.ops.bisect_plane(tb, geom=g, plane_co=(xx, 0, 0), plane_no=(1, 0, 0))
        for vt in tb.verts:
            ang = vt.co.x / r
            rad = r - vt.co.y
            vt.co.x, vt.co.y = math.sin(ang) * rad, r - math.cos(ang) * rad
        for f in tb.faces:
            f.smooth = True
        (BP[0] or p)._add(tb, c, Vector((0, y - 0.21, z0 + hgt / 2)), (-6, 0, 0))
        p.box(bs, (0, y - 0.21, SEAT_TOP + 0.02), (0.07, 0.04, 0.12), bevel=0.015)   # 등받이 지지대

    if v == "A":     # 둥근 등받이 (KayKit 파란 의자)
        seat()
        curved_back(SEAT_TOP + 0.06, 0.28, 0.4)
    elif v == "B":   # 높은 등받이 + 머리 받침 + 팔걸이
        seat(0.44, 0.42)
        curved_back(SEAT_TOP + 0.06, 0.38, 0.42)
        tbox(p, cd, (0, y - 0.25, SEAT_TOP + 0.5), (0.24, 0.07, 0.09), rot=(-10, 0, 0), bevel=0.035)
        for x in (-0.23, 0.23):
            p.box(bs, (x, y, SEAT_TOP + 0.04), (0.035, 0.05, 0.14), bevel=0.012)
            p.box(cd, (x, y + 0.01, SEAT_TOP + 0.12), (0.06, 0.24, 0.035), bevel=0.016, seg=2)
    else:            # 통 의자 (둥근 껍데기가 옆까지 감쌈 + 안쪽 방석)
        p.cyl(cd, (0, y, SEAT_TOP - 0.1), 0.22, 0.08, seg=28)
        p.cyl(c, (0, y + 0.01, SEAT_TOP - 0.03), 0.19, 0.05, seg=28)
        for k in range(9):
            a = math.radians(195 + k * 18.75)
            tbox(BP[0] or p, cd, (0.2 * math.cos(a), y + 0.2 * math.sin(a), SEAT_TOP + 0.1), (0.09, 0.07, 0.28),
                 rot=(0, 0, math.degrees(a) + 90), bevel=0.03)
        for k in range(7):   # 안쪽 쿠션 띠
            a = math.radians(205 + k * 21.6)
            tbox(p, c, (0.16 * math.cos(a), y + 0.16 * math.sin(a), SEAT_TOP + 0.09), (0.08, 0.04, 0.2),
                 rot=(0, 0, math.degrees(a) + 90), bevel=0.018)


# ------------------------------------------------------------------ 책상 위 소품 (관절 스탠드 · 화분 · 펜꽂이 · 서류 · 머그)
def deco(p):
    sh, sd = M("Lamp", "#7f93ad", 0.5), M("LampD", "#5f6f80", 0.5)
    x0, y0 = 0.5, 0.2
    p.cone(sd, (x0, y0, TOP), 0.065, 0.055, 0.025, seg=18)
    a1 = math.radians(20)
    l1 = 0.2
    p.cyl(sh, (x0, y0, TOP + 0.02), 0.012, l1, seg=8, rot=(0, -20, 0))
    j = (x0 - l1 * math.sin(a1), y0, TOP + 0.02 + l1 * math.cos(a1))
    p.sphere(sd, j, 0.02, sub=2)
    l2 = 0.16
    p.cyl(sh, j, 0.011, l2, seg=8, rot=(0, -70, 0))
    h = (j[0] - l2 * math.sin(math.radians(70)), y0, j[2] + l2 * math.cos(math.radians(70)))
    p.cone(sh, (h[0], h[1], h[2] - 0.07), 0.07, 0.025, 0.08, seg=18, rot=(0, 20, 0))   # 갓 (아래로 벌어짐)
    p.sphere(M("LampBulb", "#f2efe8", 0.3), (h[0] + 0.01, h[1], h[2] - 0.06), 0.028, sub=2)
    # 펜꽂이 + 펜 · 서류 더미 · 머그 (손잡이)
    p.cyl(M("PenCup", "#5f646c", 0.5), (-0.33, 0.22, TOP), 0.028, 0.08, seg=12)
    for k, col in enumerate(("#3b3d42", "#4f6fa0", "#a65e5e")):
        p.cyl(M("Pen%d" % k, col, 0.5), (-0.33 + 0.01 * (k - 1), 0.22, TOP + 0.04), 0.005, 0.09, seg=6, rot=(0, 8 * (k - 1), 0))
    paper = M("Paper", "#f3f1ec", 0.9)
    for k in range(4):
        p.box(paper, (-0.22 + 0.004 * k, -0.06, TOP + 0.006 + k * 0.008), (0.17, 0.22, 0.007), bevel=0,
              rot_z=math.radians(-6 + k * 3))
    mug = M("Mug", "#8fa79a", 0.5)
    p.cyl(mug, (-0.46, 0.02, TOP), 0.035, 0.08, seg=14)
    tbox(p, mug, (-0.42, 0.02, TOP + 0.04), (0.02, 0.012, 0.05), bevel=0.005)


def lamp(p, lp=None):
    """관절 스탠드 (오른쪽 뒤, 팔이 사람 쪽 -Y 로 숙임). 갓 = lp (게임: Bulb — 켜지면 갓 전체가 빛남)"""
    sh, sd = M("Lamp", "#7f93ad", 0.5), M("LampD", "#5f6f80", 0.5)
    x0, y0 = 0.52, 0.22
    p.cone(sd, (x0, y0, TOP), 0.06, 0.05, 0.025, seg=18)
    l1, a1 = 0.2, 15
    p.cyl(sh, (x0, y0, TOP + 0.02), 0.012, l1, seg=8, rot=(a1, 0, 0))
    j = (x0, y0 - l1 * math.sin(math.radians(a1)), TOP + 0.02 + l1 * math.cos(math.radians(a1)))
    p.sphere(sd, j, 0.02, sub=2)
    l2, a2 = 0.15, 75
    p.cyl(sh, j, 0.011, l2, seg=8, rot=(a2, 0, 0))
    h = (x0, j[1] - l2 * math.sin(math.radians(a2)), j[2] + l2 * math.cos(math.radians(a2)))
    (lp or p).cone(M("Bulb", "#f2efe8", 0.4), (h[0], h[1], h[2] - 0.07), 0.07, 0.03, 0.085, seg=20, rot=(-15, 0, 0))


def desk_items(p):
    """책상에 늘 있는 것: 서류 더미 (왼쪽 앞). 개인 소품은 desk_personal.glb (책상마다 다르게)"""
    paper = M("Paper", "#f3f1ec", 0.9)
    for k in range(3):
        p.box(paper, (-0.3 + 0.004 * k, -0.15, TOP + 0.006 + k * 0.008), (0.16, 0.2, 0.007), bevel=0, rot_z=math.radians(-6 + k * 4))


def partition(p):
    """마주 보는 책상 사이 칸막이 (책상 먼 쪽 끝, 천 + 나무 덮개) — desk_set 과 같은 자리 · 높이"""
    py = 0.285
    p.box(M("PanelFabric", "#8e98a3", 0.95), (0, py, (TOP + PANEL_TOP) / 2 + 0.01), (1.18, 0.03, PANEL_TOP - TOP - 0.02),
          bevel=0.012)
    p.box(M("KWoodD", WOOD_D, 0.75), (0, py, PANEL_TOP), (1.2, 0.05, 0.04), bevel=0.016)


def plant(p):   # 작은 둥근 화분 + 잎 (원점 기준 — 놓을 때 옮김)
    top = pot_round(p, 0.04, 0.05, 0.07, "#e9e6e1", "#d8d2c8")
    leafs = [M("Leaf", "#6f8a5a", 0.6), M("LeafDark", "#56724a", 0.6)]
    for k in range(7):
        add_leaf(p, leafs[k % 2], (0, 0, top - 0.01), k * 51, 40 + (k % 3) * 12, 0.08, 0.05, droop=0.02, fold=0.2)


def place(fn, v, x, y):
    p = Parts()
    fn(v, p)
    o = p.obj("O")
    o.location = (x, y, 0)


def place_set(v, x, y):
    place(lambda vv, p: (desk(vv, p), monitor(vv, p), chair(vv, p)), v, x, y)
    d = Parts()
    deco(d)
    d.obj("Deco").location = (x, y, 0)
    f = Parts()   # 화분은 원점 기준이라 따로 놓음
    plant(f)
    f.obj("Plant").location = (x - 0.5, y + 0.2, TOP)


def export_all():
    """게임용 glb: desk_{a,b} (책상 + 칸막이 + 서류 + 스탠드/Bulb) · monitor_{a,b,c} (모니터 + 키보드, Screen) · chair_{a,b,c} (ChairBack)"""
    for v in "AB":
        clear()
        p, lp = Parts(), Parts()
        desk(v, p); partition(p); desk_items(p); lamp(p, lp)
        export("desk_" + v.lower(), [p.obj("Desk"), lp.obj("Bulb")], "Desk" + v)
    for v in "ABC":
        clear()
        p, sp = Parts(), Parts()
        SP[0] = sp
        monitor(v, p)
        SP[0] = None
        export("monitor_" + v.lower(), [p.obj("Monitor"), sp.obj("Screen")], "Monitor" + v)
    for v in "ABC":
        clear()
        p, bp = Parts(), Parts()
        BP[0] = bp
        chair(v, p)
        BP[0] = None
        export("chair_" + v.lower(), [p.obj("Chair"), bp.obj("ChairBack")], "Chair" + v)


if __name__ == "__main__" and EXPORT:
    export_all()
elif __name__ == "__main__":
    clear()
    G = 1.75
    for i, v in enumerate("ABC"):
        x = (i - 1) * G
        place(desk, v, x, 3.0)                                                 # 줄 1 책상
        place(lambda vv, p: (desk("A", p), monitor(vv, p)), v, x, 1.6)         # 줄 2 모니터 (책상 A 위)
        place(chair, v, x, 0.75)                                               # 줄 3 의자
        place_set(v, x, -1.2)                                                  # 줄 4 세트
    scn = bpy.context.scene
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scn.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 6.4
    pitch = math.radians(55)
    cam.location = (0, 0.9 - 20 * math.cos(pitch), 0.3 + 20 * math.sin(pitch))
    cam.rotation_euler = (math.pi / 2 - pitch, 0, 0)
    scn.camera = cam
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.data.angle = math.radians(8)
    sun.rotation_euler = (0.6, 0.25, 0.4)
    scn.collection.objects.link(sun)
    scn.world = bpy.data.worlds.new("W")
    scn.world.use_nodes = True
    scn.world.node_tree.nodes["Background"].inputs[0].default_value = (0.72, 0.8, 0.88, 1)
    scn.world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    scn.view_settings.view_transform = "Standard"
    scn.render.resolution_x, scn.render.resolution_y = 1500, 1300
    scn.render.filepath = os.path.join(OUT, "pick_desk_kit.png")
    bpy.ops.render.render(write_still=True)
    print("[kit]", scn.render.filepath)
