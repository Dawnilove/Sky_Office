"""M4 3세션째: 창구 쪽 모델 — 사장 책상 (+ 빈 의자 · 명패 · 결재함 · 전화기 · 스탠드 · 작은 진열장) · 종이비행기
(스타일 = build_desk_kit.py: 두툼한 판 · 크게 둥근 모서리 · 단순한 덩어리)

미리보기 (OverLand 폴더에서):
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P SkyOffice/tools/blender/build_counter_kit.py -- <출력 폴더>
  → pick_boss_desk.png (사장 책상 A ㄱ자 · B 중역 · C 둥근 끝, 같은 소품)
내보내기: ... -P SkyOffice/tools/blender/build_counter_kit.py -- SkyOffice/game/assets/models/boss --export
- 좌표 · 단위는 build_desk_kit.py 와 같음 (1 단위 = 1칸, 상판 TOP 0.48, 사장 = -Y 쪽에 앉아 +Y (손님 · 창구 쪽) 를 봄)
- 색 규칙: 노랑 · 금색 · 주황 금지 (노랑 = '내 차례' 전용). 사장 책상은 직원 책상보다 진한 호두나무, 의자 = 트레이 아이콘 남색
- 이름 붙인 부품 (게임이 찾아 씀, v2.8 5-7): BossChair (빈 의자 — 자리 비우면 빠짐) · Bulb (스탠드 갓 — 내가 있으면 흰빛)
  · Note (쪽지 — 자리 비우면 보임) · Handset · PhoneLight (전화기 — M5 연결 상태) · InboxPapers (결재함 서류)
"""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_office_props import Parts, clear, export, mat, TOP, SEAT_TOP  # noqa: E402
import build_desk_kit as K  # noqa: E402
from build_workroom import add_leaf, pot_round  # noqa: E402

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(ARGV[0]) if ARGV else "."
EXPORT = "--export" in ARGV

BW, BW_TOP, BW_D, BW_FR = "#7a5a46", "#8a6a54", "#5e4636", "#83634e"   # 진한 호두나무 (직원 책상 #9a7458 보다 한 단계 진함)
LEATHER, LEATHER_D = "#3f4c6b", "#33405c"                              # 사장 의자 = 트레이 아이콘 남색
SLATE, PAPER, KNOB = "#3b3d42", "#f3f1ec", "#e6dfd2"
NOTE = "#bcd8e8"                                                       # 쪽지 = 옅은 하늘색 (노랑 포스트잇 아님)


def M(n, c, r=0.7, metal=0.0):
    return mat(n, c, r, metal)


# ------------------------------------------------------------------ 사장 책상 (1.0 × 0.5)
def boss_desk(v, p):
    w, wt, wd, fr = M("BWood", BW), M("BWoodTop", BW_TOP, 0.55), M("BWoodD", BW_D, 0.75), M("BFront", BW_FR, 0.6)
    k = M("Knob", KNOB, 0.4)
    UND = TOP - 0.085

    def top(cx, cy, sx, sy):   # 두 겹 상판 (밝은 윗판 + 진한 띠)
        p.box(wt, (cx, cy, TOP - 0.025), (sx, sy, 0.05), bevel=0.024, seg=3)
        p.box(wd, (cx, cy, TOP - 0.065), (sx - 0.03, sy - 0.03, 0.04), bevel=0.015)

    def pedestal(x, y=0.0, depth=0.44, wdt=0.32):   # 서랍 받침 (서랍 면 = 사장 쪽 -Y)
        h = UND - 0.03
        p.box(w, (x, y, 0.03 + h / 2), (wdt, depth, h), bevel=0.03, seg=2)
        p.box(wd, (x, y + 0.01, 0.018), (wdt - 0.03, depth - 0.04, 0.036), bevel=0.01)
        fy = y - depth / 2 - 0.006
        for z, hh in ((0.07, 0.11), (0.19, 0.1), (0.3, 0.1)):
            p.box(fr, (x, fy, z + hh / 2), (wdt - 0.05, 0.02, hh - 0.012), bevel=0.012, seg=2)
            p.box(k, (x, fy - 0.016, z + hh * 0.62), (0.1, 0.016, 0.018), bevel=0.007)

    def front_panel(x0, x1, y=0.22):   # 손님 쪽 앞판 (전체 높이 + 가운데 홈 띠 = 중역 책상 느낌)
        cx, sx = (x0 + x1) / 2, x1 - x0
        p.box(w, (cx, y, UND / 2 + 0.02), (sx, 0.035, UND - 0.02), bevel=0.014)
        p.box(fr, (cx, y + 0.02, UND * 0.55), (sx - 0.08, 0.01, UND * 0.5), bevel=0.006)

    if v == "A":     # ㄱ자: 오른쪽 날개가 사장 쪽으로 꺾임 (전화기 · 결재함 자리)
        top(0, 0, 1.0, 0.5)
        top(0.6, -0.22, 0.36, 0.56)
        pedestal(0.6, -0.26, 0.42, 0.3)
        K.tleg(p, w, -0.44, -0.19, 0.0, UND, 0.036, 0.05)
        K.tleg(p, w, -0.44, 0.19, 0.0, UND, 0.036, 0.05)
        front_panel(-0.48, 0.48)
    elif v == "B":   # 중역: 양쪽 서랍 + 가운데 얕은 서랍 + 앞판
        top(0, 0, 1.1, 0.52)
        pedestal(-0.36)
        pedestal(0.36)
        p.box(fr, (0, -0.23, UND - 0.045), (0.36, 0.02, 0.07), bevel=0.012)
        p.box(k, (0, -0.247, UND - 0.045), (0.1, 0.016, 0.018), bevel=0.007)
        front_panel(-0.5, 0.5)
    else:            # 둥근 끝: 왼쪽 끝이 반원 (회의도 하는 책상) + 오른쪽 서랍
        top(0.1, 0, 0.8, 0.5)
        p.cyl(wt, (-0.3, 0, TOP - 0.05), 0.25, 0.05, seg=32)
        p.cyl(wd, (-0.3, 0, TOP - 0.085), 0.235, 0.04, seg=32)
        p.cone(w, (-0.33, 0, 0.0), 0.1, 0.05, UND, seg=20)   # 둥근 기둥 다리
        p.cyl(wd, (-0.33, 0, 0.0), 0.13, 0.025, seg=24)
        pedestal(0.32)
        front_panel(-0.15, 0.48)


# ------------------------------------------------------------------ 빈 의자 (중역 의자: 높은 등받이 + 머리 받침 + 팔걸이, 남색 가죽)
def boss_chair(p, y=-0.5):
    c, cd = M("BossLeather", LEATHER, 0.55), M("BossLeatherD", LEATHER_D, 0.6)
    bs, ch = M("ChairBase", K.BASE, 0.45, 0.2), M("Chrome", "#9aa0a6", 0.3, 0.7)
    for i in range(5):
        a = math.radians(90 + i * 72)
        K.tbox(p, bs, (0.11 * math.cos(a), y + 0.11 * math.sin(a), 0.055), (0.22, 0.045, 0.035), rot=(0, 6, math.degrees(a)),
               bevel=0.014)
        p.cyl(bs, (0.22 * math.cos(a) - 0.015, y + 0.22 * math.sin(a), 0.022), 0.022, 0.03, seg=10, rot=(0, 90, 0))
    p.cone(bs, (0, y, 0.06), 0.05, 0.03, 0.05, seg=12)
    p.cyl(ch, (0, y, 0.1), 0.022, SEAT_TOP - 0.17, seg=10)
    p.box(c, (0, y + 0.01, SEAT_TOP - 0.04), (0.46, 0.42, 0.09), bevel=0.045, seg=3)        # 두툼한 방석
    K.tbox(p, c, (0, y - 0.22, SEAT_TOP + 0.24), (0.44, 0.09, 0.44), rot=(-8, 0, 0), bevel=0.045)   # 높은 등받이
    for zz in (0.14, 0.3):   # 등받이 누빔 줄
        K.tbox(p, cd, (0, y - 0.17 + zz * 0.02, SEAT_TOP + zz), (0.36, 0.012, 0.018), rot=(-8, 0, 0), bevel=0.005)
    K.tbox(p, cd, (0, y - 0.26, SEAT_TOP + 0.52), (0.3, 0.09, 0.12), rot=(-10, 0, 0), bevel=0.04)  # 머리 받침
    for x in (-0.25, 0.25):   # 팔걸이
        p.box(ch, (x, y, SEAT_TOP + 0.04), (0.03, 0.04, 0.14), bevel=0.01)
        p.box(cd, (x, y + 0.01, SEAT_TOP + 0.12), (0.07, 0.26, 0.04), bevel=0.018, seg=2)


# ------------------------------------------------------------------ 책상 위 소품
def nameplate(p, x=-0.05, y=0.16):
    """명패: 진한 받침 + 비스듬한 판 (글자 '사장' 은 따로 된 물체 — 손님 쪽 +Y 를 봄)"""
    p.box(M("BWoodD", BW_D, 0.75), (x, y, TOP + 0.012), (0.3, 0.07, 0.024), bevel=0.01)
    K.tbox(p, M("Slate", SLATE, 0.45), (x, y + 0.005, TOP + 0.05), (0.27, 0.02, 0.07), rot=(-18, 0, 0), bevel=0.008)


def nameplate_text(x=-0.05, y=0.16):
    cu = bpy.data.curves.new("NameText", "FONT")
    cu.body = "사장"
    cu.font = bpy.data.fonts.load("C:/Windows/Fonts/malgunbd.ttf")
    cu.size = 0.05
    cu.align_x, cu.align_y = "CENTER", "CENTER"
    cu.extrude = 0.002
    o = bpy.data.objects.new("NameText", cu)
    o.data.materials.append(M("NameInk", "#f2efe8", 0.5))
    bpy.context.scene.collection.objects.link(o)
    o.location = (x, y + 0.017, TOP + 0.05)
    o.rotation_euler = (math.radians(90 - 18), 0, math.radians(180))   # 손님 쪽 (+Y) 에서 읽힘
    me = bpy.data.meshes.new_from_object(o.evaluated_get(bpy.context.evaluated_depsgraph_get()))   # 글자 → 메시 (glb 로 나가게)
    m = bpy.data.objects.new("NameText", me)
    bpy.context.scene.collection.objects.link(m)
    m.matrix_world = o.matrix_world.copy()
    bpy.data.objects.remove(o, do_unlink=True)
    m.name = "NameText"
    return m


def inbox(p, pp, x, y, rz=0.0):
    """결재함 2단 (진한 나무 틀 + 서류). pp = InboxPapers"""
    f = M("BWoodD", BW_D, 0.75)
    for z in (0.0, 0.07):
        p.box(f, (x, y, TOP + z + 0.008), (0.22, 0.28, 0.016), bevel=0.006, rot_z=rz)
        for sx in (-1, 1):
            dx, dy = 0.105 * sx * math.cos(rz), 0.105 * sx * math.sin(rz)
            p.box(f, (x + dx, y + dy, TOP + z + 0.03), (0.014, 0.28, 0.05), bevel=0.005, rot_z=rz)
    for z, n in ((0.016, 3), (0.086, 2)):
        for i in range(n):
            pp.box(M("Paper", PAPER, 0.9), (x + 0.004 * i, y - 0.01, TOP + z + 0.004 + i * 0.007), (0.18, 0.24, 0.006), bevel=0,
                   rot_z=rz + math.radians(-3 + i * 3))


def phone(p, hp, lp, x, y, rz=0.0):
    """탁상 전화기: 비스듬한 몸통 + 번호판 + 수화기 (Handset) + 상태 불 (PhoneLight). 사장 쪽 (-Y) 을 봄"""
    b, bd = M("Phone", "#4a4e55", 0.45), M("PhoneD", "#34373c", 0.5)
    K.tbox(p, b, (x, y, TOP + 0.028), (0.17, 0.15, 0.056), rot=(0, 0, math.degrees(rz)), bevel=0.02)
    K.tbox(p, bd, (x, y - 0.03, TOP + 0.062), (0.11, 0.07, 0.012), rot=(-14, 0, math.degrees(rz)), bevel=0.004)   # 번호판
    for i in range(3):
        for j in range(2):
            p.box(M("Keys", "#f0ede7", 0.6), (x - 0.03 + 0.03 * i, y - 0.045 + 0.025 * j, TOP + 0.07 + 0.006 * j),
                  (0.018, 0.014, 0.008), bevel=0.002)
    for sx in (-1, 1):   # 수화기 받침
        p.box(bd, (x + 0.06 * sx, y + 0.04, TOP + 0.066), (0.03, 0.05, 0.02), bevel=0.006)
    K.tbox(hp, M("Phone", "#4a4e55", 0.45), (x, y + 0.04, TOP + 0.086), (0.19, 0.045, 0.03), rot=(0, 0, math.degrees(rz)),
           bevel=0.014)
    for sx in (-1, 1):
        hp.sphere(M("Phone", "#4a4e55", 0.45), (x + 0.085 * sx, y + 0.04, TOP + 0.08), 0.026, sub=2, scale=(1, 1, 0.7))
    lp.sphere(M("PhoneLight", "#9aa0a6", 0.4), (x + 0.065, y - 0.055, TOP + 0.06), 0.012, sub=2)   # 게임이 상태 색을 덮어씀


def note(p, x, y):
    """쪽지 (자리 비움 — 옅은 하늘색, 접힌 모서리)"""
    p.box(M("Note", NOTE, 0.9), (x, y, TOP + 0.01), (0.13, 0.13, 0.006), bevel=0, rot_z=math.radians(12))


def desk_props(v, p, hp, lp, pp):
    """책상마다 소품 자리 (A = 날개에 전화 · 결재함)"""
    if v == "A":
        inbox(p, pp, 0.62, -0.12)
        phone(p, hp, lp, 0.6, -0.38)
        np_x = -0.1
    elif v == "B":
        inbox(p, pp, 0.34, 0.05)
        phone(p, hp, lp, -0.22, -0.1)
        np_x = 0.0
    else:
        inbox(p, pp, 0.2, 0.06)
        phone(p, hp, lp, -0.32, -0.02)
        np_x = -0.13
    nameplate(p, np_x)
    # 서류 한 장 + 펜 (일하는 책상)
    p.box(M("Paper", PAPER, 0.9), (np_x + 0.02, -0.1, TOP + 0.004), (0.18, 0.24, 0.006), bevel=0, rot_z=math.radians(-8))
    p.cyl(M("Pen", "#3b3d42", 0.5), (np_x + 0.13, -0.12, TOP + 0.008), 0.006, 0.13, seg=6, rot=(90, 0, 70))
    return np_x


def boss_lamp(p, lp, v):
    """스탠드 (사장 왼쪽 뒤). 갓 = Bulb (내가 있으면 흰빛)"""
    x = {"A": -0.4, "B": -0.42, "C": 0.42}[v]
    sh, sd = M("BLamp", "#4f5560", 0.45, 0.3), M("BLampD", "#3b3d42", 0.5)
    y0 = 0.17
    p.cone(sd, (x, y0, TOP), 0.06, 0.05, 0.025, seg=18)
    p.cyl(sh, (x, y0, TOP + 0.02), 0.012, 0.26, seg=8)
    p.cyl(sh, (x, y0, TOP + 0.28), 0.011, 0.14, seg=8, rot=(68, 0, 0))   # 사장 쪽으로 꺾임
    hy, hz = y0 - 0.14 * math.sin(math.radians(68)), TOP + 0.28 + 0.14 * math.cos(math.radians(68))
    lp.cone(M("Bulb", "#f2efe8", 0.4), (x, hy, hz - 0.075), 0.075, 0.03, 0.085, seg=20, rot=(-12, 0, 0))


# ------------------------------------------------------------------ 작은 진열장 (0.6 × 0.28, 높이 0.72) — 회사 물건 (비행선 모형 · 지구본 · 액자 · 책 · 화분)
def cabinet(p):
    w, wd, wt = M("BWood", BW), M("BWoodD", BW_D, 0.75), M("BWoodTop", BW_TOP, 0.55)
    W, D, H = 0.6, 0.28, 0.72
    p.box(wd, (0, 0, 0.02), (W - 0.04, D - 0.04, 0.04), bevel=0.01)          # 받침
    p.box(w, (0, 0.12, H / 2), (W, 0.03, H), bevel=0.012)                     # 뒷판
    for sx in (-1, 1):
        p.box(w, (sx * (W / 2 - 0.02), 0, H / 2), (0.04, D, H), bevel=0.015)  # 옆판
    p.box(wt, (0, 0, H - 0.015), (W + 0.03, D + 0.03, 0.04), bevel=0.016, seg=2)  # 윗판
    p.box(w, (0, 0, 0.3), (W - 0.06, D - 0.02, 0.03), bevel=0.006)            # 가운데 선반
    p.box(w, (0, -0.02, 0.15), (W - 0.06, D - 0.06, 0.24), bevel=0.012)       # 아래 문짝 (닫힌 장)
    for sx in (-1, 1):
        p.box(M("BFront", BW_FR, 0.6), (sx * 0.135, -0.13, 0.15), (0.25, 0.012, 0.21), bevel=0.008)
        p.box(M("Knob", KNOB, 0.4), (sx * 0.03, -0.142, 0.17), (0.014, 0.012, 0.06), bevel=0.004)
    # 가운데 칸: 비행선 모형 (받침 위) · 지구본
    sb = M("ModelShip", "#e9e6e1", 0.5)
    p.box(wd, (-0.12, 0, 0.33), (0.16, 0.08, 0.02), bevel=0.006)
    p.cyl(M("Slate", SLATE, 0.45), (-0.12, 0, 0.34), 0.006, 0.07, seg=6)
    p.sphere(sb, (-0.12, 0, 0.44), 0.06, sub=2, scale=(1.6, 0.8, 0.8))
    p.box(M("ModelGondola", "#7f93ad", 0.5), (-0.12, 0, 0.39), (0.06, 0.03, 0.025), bevel=0.008)
    for sx in (-1, 1):
        p.box(sb, (-0.12 - 0.09, sx * 0.02, 0.45), (0.03, 0.006, 0.04), bevel=0.003)
    p.cyl(M("Slate", SLATE, 0.45), (0.13, 0, 0.315), 0.04, 0.015, seg=14)
    p.cyl(M("Slate", SLATE, 0.45), (0.13, 0, 0.33), 0.006, 0.05, seg=6)
    p.sphere(M("Globe", "#8fb5c9", 0.5), (0.13, 0, 0.42), 0.055, sub=2)
    p.sphere(M("GlobeLand", "#8fa79a", 0.6), (0.145, -0.01, 0.43), 0.045, sub=1, scale=(0.9, 1.25, 0.7))
    # 윗판 위: 액자 · 책 · 화분
    K.tbox(p, M("Frame", "#e9e6e1", 0.5), (-0.17, 0.03, H + 0.07), (0.13, 0.02, 0.1), rot=(-10, 0, 0), bevel=0.006)
    K.tbox(p, M("Photo", "#9fb3c8", 0.6), (-0.17, 0.018, H + 0.07), (0.1, 0.006, 0.07), rot=(-10, 0, 0), bevel=0)
    for i, col in enumerate(("#6e7a8c", "#a07c7c", "#8fa79a")):
        p.box(M("Book" + col, col, 0.7), (0.02 + 0.035 * i, 0.04, H + 0.075), (0.03, 0.15, 0.13 - 0.01 * i), bevel=0.004)
    pl = Parts()
    t = pot_round(pl, 0.035, 0.045, 0.06, "#e9e6e1", "#d8d2c8")
    for i in range(6):
        add_leaf(pl, M("Leaf", "#6f8a5a", 0.6) if i % 2 else M("LeafDark", "#56724a", 0.6), (0, 0, t - 0.01), i * 60,
                 45 + (i % 3) * 10, 0.07, 0.045, droop=0.02, fold=0.2)
    po = pl.obj("CabPlant")
    po.location = (0.21, 0.0, H)
    return po


# ------------------------------------------------------------------ 종이비행기 (게임이 날림, 앞 = +Y)
def paper_plane(p):
    import bmesh
    from mathutils import Vector
    tb = bmesh.new()
    L, Wd, H = 0.16, 0.13, 0.03
    nose = tb.verts.new((0, L / 2, 0))
    tl, tr = tb.verts.new((-Wd / 2, -L / 2, 0.012)), tb.verts.new((Wd / 2, -L / 2, 0.012))
    kl, kr = tb.verts.new((-0.012, -L / 2, -H)), tb.verts.new((0.012, -L / 2, -H))
    mid = tb.verts.new((0, -L / 2, 0.0))
    for f in ((nose, mid, tl), (nose, tr, mid), (nose, kl, mid), (nose, mid, kr)):
        tb.faces.new(f)
    p._add(tb, M("Plane", "#f6f4ef", 0.8), Vector((0, 0, 0)), (0, 0, 0))


# ------------------------------------------------------------------ 한 벌 놓기 (미리보기 · 내보내기 공통)
def boss_set(v):
    """사장 책상 한 벌 → [Desk, BossChair, Bulb, Handset, PhoneLight, InboxPapers, Note, NameText]"""
    d, c, lp, hp, plp, pp, nt = Parts(), Parts(), Parts(), Parts(), Parts(), Parts(), Parts()
    boss_desk(v, d)
    npx = desk_props(v, d, hp, plp, pp)
    boss_lamp(d, lp, v)
    boss_chair(c)
    note(nt, npx + 0.2, -0.17)
    objs = [d.obj("Desk"), c.obj("BossChair"), lp.obj("Bulb"), hp.obj("Handset"), plp.obj("PhoneLight"), pp.obj("InboxPapers"),
            nt.obj("Note"), nameplate_text(npx)]
    return objs


def render(name, ortho, look=(0, 0.3, 0.3), res=(1500, 700)):
    scn = bpy.context.scene
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scn.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    pitch = math.radians(55)
    cam.location = (look[0], look[1] - 20 * math.cos(pitch), look[2] + 20 * math.sin(pitch))
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
    scn.render.resolution_x, scn.render.resolution_y = res
    scn.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("[counter]", scn.render.filepath)


def place(objs, x, y=0.0, rz=0.0):
    root = bpy.data.objects.new("R", None)
    bpy.context.scene.collection.objects.link(root)
    for o in objs:
        o.parent = root
    root.location = (x, y, 0)
    root.rotation_euler = (0, 0, rz)
    return root


CHOICE = "B"   # 사용자 고름 (2026-10-16): B 중역 책상


def export_all():
    """게임용 glb (game/assets/models/boss/): boss_desk (사장 책상 한 벌) · boss_cabinet (작은 진열장) · paper_plane"""
    clear()
    export("boss_desk", boss_set(CHOICE), "BossDesk")
    clear()
    cb = Parts()
    po = cabinet(cb)
    export("boss_cabinet", [cb.obj("Cabinet"), po], "BossCabinet")
    clear()
    pp = Parts()
    paper_plane(pp)
    export("paper_plane", [pp.obj("PaperPlane")], "PaperPlane")


# ================================================================== 창구 · 승강장 나머지 (M4 3세션째 이어서): 창구 · 프린터 · 대기 의자
## 미리보기: ... -P build_counter_kit.py -- <폴더> --station  → pick_station.png (줄 1 창구 A·B·C / 줄 2 프린터 A·B · 대기 의자 A·B·C)
C_W, C_L, C_TOP, GLASS_TOP = 0.5, 1.2, 0.78, 1.35   # build_office_props.build_service_counter 와 같음 (게임 유리 = 코드 0.86~1.33)
STATION = {"counter": "C", "printer": "A", "wait_chair": "C"}   # 사용자 고름 (2026-10-16)
## 내보내기: ... -P build_counter_kit.py -- SkyOffice/game/assets/models/station --station-export
SKY = "#b9d3df"


def emit(name, hexcol, strength=1.0):
    from build_office_props import lin
    m = mat(name, hexcol, 0.4)
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Emission Color"].default_value = (*lin(hexcol), 1)
    bsdf.inputs["Emission Strength"].default_value = strength
    return m


def service_counter(v, p):
    """결재 창구 (원점 = 바닥 가운데, 손님 쪽 = +X, 길이 = Y). A 차가운 회색 · B 흰 판 + 나무 · C 남색 은행 창구"""
    cols = {"A": ("#c3cad0", "#d3d9de", "#7f8b97", "#d5d2cc", "#8b9097", "#3b3d42"),
            "B": ("#e9e6e1", "#f1eee9", "#9a7458", "#a98468", "#5c6067", "#3f4c6b"),
            "C": ("#3f4c6b", "#4b5a7d", "#e9e6e1", "#d5d2cc", "#c5ccd1", "#2f3a52")}[v]
    body, panel, band, top, frame, sign = (M("Ctr" + n + v, c, r) for n, c, r in zip(
        ("Body", "Panel", "Band", "Top", "Frame", "Sign"), cols, (0.6, 0.55, 0.6, 0.45, 0.4, 0.5)))
    p.box(band, (0.02, 0, 0.03), (C_W - 0.06, C_L - 0.04, 0.06), bevel=0.02)                       # 걸레받이
    p.box(body, (0.03, 0, 0.06 + (C_TOP - 0.14) / 2), (C_W - 0.08, C_L, C_TOP - 0.14), bevel=0.035, seg=3)
    for k in range(3):                                                                              # 손님 쪽 판 3장 (홈)
        p.box(panel, (C_W / 2 - 0.005, (k - 1) * 0.385, 0.38), (0.024, 0.35, 0.46), bevel=0.012, seg=2)
    p.box(band, (C_W / 2 - 0.002, 0, C_TOP - 0.13), (0.02, C_L - 0.04, 0.04), bevel=0.01)          # 앞 가로 띠
    p.box(top, (0.05, 0, C_TOP - 0.025), (C_W + 0.1, C_L + 0.08, 0.05), bevel=0.022, seg=3)         # 두 겹 상판
    p.box(band, (0.05, 0, C_TOP - 0.065), (C_W + 0.06, C_L + 0.04, 0.035), bevel=0.012)
    p.box(body, (-C_W / 2 + 0.03, 0, 0.5), (0.1, C_L - 0.06, 0.04), bevel=0.012)                    # 사장 쪽 선반
    for y in (-C_L / 2 + 0.03, C_L / 2 - 0.03):                                                     # 유리 틀
        p.box(frame, (0, y, (C_TOP + GLASS_TOP) / 2), (0.05, 0.05, GLASS_TOP - C_TOP), bevel=0.02)
    p.box(frame, (0, 0, GLASS_TOP), (0.065, C_L, 0.05), bevel=0.02)
    p.box(sign, (0, 0, GLASS_TOP + 0.13), (0.06, 0.58, 0.18), bevel=0.03, seg=3)                    # 위 창구 표시판
    line = emit("CtrSignGlow", SKY, 0.6) if v == "C" else M("CtrSignLine", "#e9e6e1", 0.5)
    for sx in (1, -1):
        p.box(line, (sx * 0.031, 0, GLASS_TOP + 0.13), (0.004, 0.38, 0.04), bevel=0)
    for y in (-0.16, 0.16):                                                                          # 표시판 걸이
        p.box(frame, (0, y, GLASS_TOP + 0.03), (0.02, 0.02, 0.04), bevel=0.006)
    paper, dark = M("Paper", PAPER, 0.9), M("Dark", SLATE, 0.5)
    p.cyl(M("PenCup", "#5f646c", 0.5), (0.18, -0.42, C_TOP), 0.03, 0.08, seg=14)                    # 손님 쪽: 펜꽂이 · 서류 받침
    for k, c in enumerate(("#3b3d42", "#4f6fa0")):
        p.cyl(M("Pen%d" % k, c, 0.5), (0.18 + 0.01 * k, -0.42, C_TOP + 0.04), 0.006, 0.09, seg=8, rot=(0, 8 * (2 * k - 1), 0))
    K.tbox(p, M("TrayDark", "#4a4d53", 0.5), (0.16, 0.18, C_TOP + 0.012), (0.2, 0.26, 0.024), bevel=0.008)
    K.tbox(p, paper, (0.16, 0.18, C_TOP + 0.028), (0.16, 0.22, 0.01), bevel=0.003)
    K.tbox(p, paper, (-0.16, 0.32, C_TOP + 0.03), (0.17, 0.23, 0.06), bevel=0.006)                   # 사장 쪽: 서류 더미 · 도장
    p.cyl(dark, (-0.16, -0.2, C_TOP), 0.026, 0.06, seg=14)
    p.sphere(dark, (-0.16, -0.2, C_TOP + 0.07), 0.024, sub=2)


def printer(v, p):
    """프린터 (원점 = 바닥 가운데, 앞 = -Y, 자리 0.45 × 0.35). A 흰 복합기 · B 나무 수납장 위 작은 프린터"""
    white, gray, dark = M("PrWhite", "#ece9e3", 0.5), M("PrGray", "#d4d0c8", 0.55), M("PrDark", "#5c6067", 0.45)
    paper = M("Paper", PAPER, 0.9)
    scr = emit("PrScreen", "#7fd0c0", 0.8)
    if v == "A":
        p.box(white, (0, 0, 0.19), (0.44, 0.34, 0.36), bevel=0.035, seg=3)
        for z in (0.08, 0.18):                                                       # 종이 서랍 2 + 손잡이
            p.box(gray, (0, -0.17, z), (0.38, 0.02, 0.08), bevel=0.012)
            p.box(dark, (0, -0.183, z + 0.015), (0.12, 0.012, 0.016), bevel=0.005)
        p.box(gray, (-0.04, -0.16, 0.29), (0.3, 0.03, 0.05), bevel=0.012)           # 나오는 칸
        K.tbox(p, paper, (-0.04, -0.17, 0.3), (0.2, 0.1, 0.01), rot=(-6, 0, 0), bevel=0.003)
        p.box(dark, (0, 0.01, 0.395), (0.42, 0.32, 0.05), bevel=0.02, seg=2)        # 스캐너 덮개
        K.tbox(p, dark, (0.14, -0.16, 0.43), (0.14, 0.08, 0.03), rot=(-25, 0, 0), bevel=0.01)   # 조작판 + 화면
        K.tbox(p, scr, (0.14, -0.178, 0.438), (0.09, 0.004, 0.04), rot=(-25, 0, 0), bevel=0)
    else:
        wood, wood_d = M("KWood", K.WOOD), M("KWoodD", K.WOOD_D, 0.75)
        p.box(wood, (0, 0, 0.16), (0.44, 0.34, 0.3), bevel=0.03, seg=3)
        for sx in (-1, 1):                                                           # 문 2 + 손잡이
            p.box(M("KFront", K.FRONT, 0.65), (sx * 0.105, -0.17, 0.16), (0.19, 0.02, 0.24), bevel=0.012)
            p.box(M("Knob", K.KNOB, 0.4), (sx * 0.03, -0.184, 0.2), (0.016, 0.014, 0.06), bevel=0.006)
        p.box(wood_d, (0, 0, 0.315), (0.42, 0.32, 0.02), bevel=0.008)
        p.box(white, (0, 0.0, 0.39), (0.36, 0.26, 0.13), bevel=0.03, seg=3)        # 작은 프린터
        p.box(dark, (0, 0.0, 0.455), (0.34, 0.24, 0.02), bevel=0.008)
        K.tbox(p, paper, (0, 0.12, 0.5), (0.2, 0.01, 0.12), rot=(-20, 0, 0), bevel=0.003)   # 뒤 종이 받침
        K.tbox(p, paper, (0, -0.16, 0.36), (0.18, 0.1, 0.008), rot=(8, 0, 0), bevel=0.002)
        p.box(scr, (0.13, -0.131, 0.41), (0.05, 0.004, 0.025), bevel=0)


def wait_chair(v, p):
    """대기 의자 (원점 = 바닥 가운데, 앉는 사람이 -Y 를 봄, 방석 위 = SEAT_TOP). A 둥근 셸 + 금속 다리 · B 쿠션 + 나무 다리 · C 금속 공항 의자"""
    metal = M("ChMetal", "#5c6067", 0.45, 0.5)
    S = SEAT_TOP
    if v == "A":
        shell = M("Shell", "#8fa79a", 0.45)
        p.box(shell, (0, 0, S - 0.025), (0.38, 0.36, 0.05), bevel=0.024, seg=3)
        K.tbox(p, shell, (0, 0.17, S + 0.17), (0.38, 0.05, 0.3), rot=(-10, 0, 0), bevel=0.024, seg=3)
        for x in (-0.15, 0.15):
            for y in (-0.13, 0.13):
                p.cyl(metal, (x, y, 0), 0.012, S - 0.04, seg=8)
            p.box(metal, (x, 0, 0.02), (0.02, 0.3, 0.02), bevel=0.006)
    elif v == "B":
        wood, fab = M("KWood", K.WOOD), M("ChFabric", "#7f93ad", 0.85)
        p.box(wood, (0, 0, S - 0.07), (0.38, 0.36, 0.04), bevel=0.012)
        p.box(fab, (0, -0.005, S - 0.03), (0.38, 0.36, 0.07), bevel=0.03, seg=3)
        for x in (-0.16, 0.16):
            for y in (-0.14, 0.14):
                K.tleg(p, wood, x, y, 0.0, S - 0.08, 0.018, 0.026)
            p.box(wood, (x, 0.165, S + 0.1), (0.03, 0.03, 0.26), bevel=0.01)
        K.tbox(p, fab, (0, 0.17, S + 0.17), (0.36, 0.06, 0.2), rot=(-8, 0, 0), bevel=0.03, seg=3)
    else:
        pad = M("ChPad", LEATHER, 0.6)
        p.box(metal, (0, 0, S - 0.07), (0.42, 0.06, 0.03), bevel=0.01)                # 가로 보
        for x in (-0.17, 0.17):
            p.box(metal, (x, 0, (S - 0.07) / 2), (0.03, 0.03, S - 0.07), bevel=0.008)
            p.box(metal, (x, 0, 0.012), (0.04, 0.3, 0.024), bevel=0.008)
        p.box(pad, (0, -0.01, S - 0.03), (0.36, 0.34, 0.06), bevel=0.025, seg=3)
        K.tbox(p, pad, (0, 0.165, S + 0.16), (0.36, 0.05, 0.26), rot=(-12, 0, 0), bevel=0.025, seg=3)
        for x in (-0.205, 0.205):                                                    # 팔걸이
            p.box(metal, (x, 0.02, S + 0.1), (0.025, 0.3, 0.025), bevel=0.008)
            p.box(metal, (x, -0.12, S + 0.03), (0.02, 0.02, 0.14), bevel=0.006)


def _label(k, t, x, y, size=0.16):
    txt = bpy.data.curves.new("L%d" % k, "FONT")
    txt.body = t
    txt.size = size
    txt.align_x = "CENTER"
    o = bpy.data.objects.new("L%d" % k, txt)
    o.data.materials.append(mat("Label", "#1f2329", 0.5))
    bpy.context.scene.collection.objects.link(o)
    o.location = (x, y, 0)


def station_preview():
    clear()
    for i, v in enumerate("ABC"):
        c = Parts()
        service_counter(v, c)
        place([c.obj("Counter" + v)], (i - 1) * 1.7, 0.9, math.radians(-90))   # 손님 쪽 (+X) 이 카메라를 봄
        _label(i, "창구 " + v, (i - 1) * 1.7, 0.2)
    for i, v in enumerate("AB"):
        c = Parts()
        printer(v, c)
        place([c.obj("Printer" + v)], -2.0 + i * 0.75, -0.9)
        _label(10 + i, "프린터 " + v, -2.0 + i * 0.75, -1.45, 0.11)
    for i, v in enumerate("ABC"):
        c = Parts()
        wait_chair(v, c)
        place([c.obj("Chair" + v)], 0.2 + i * 0.75, -0.9)
        _label(20 + i, "의자 " + v, 0.2 + i * 0.75, -1.45, 0.11)
    render("pick_station", 5.6, look=(0.0, -0.1, 0.3), res=(1600, 1000))


def station_export():
    """게임용 glb (game/assets/models/station/): service_counter · printer · wait_chair"""
    for name, fn, root in (("service_counter", service_counter, "ServiceCounterSet"), ("printer", printer, "Printer"),
                           ("wait_chair", wait_chair, "WaitChair")):
        clear()
        p = Parts()
        fn(STATION[name if name != "service_counter" else "counter"], p)
        export(name, [p.obj(root + "Mesh")], root)


# ------------------------------------------------------------------ 깃대 · 간판 · 게시판 (M4 3세션째 이어서)
## 미리보기: ... -- <폴더> --station2 → pick_station2.png (깃대 A·B / 간판 창업 손글씨 · 스타트업 A·B / 게시판 A·B·C)
STATION2 = {"flagpole": "B", "sign": "A", "notice": "D"}   # 사용자 고름 (2026-10-16): 게시판 D = B 이젤 + C 흰 둥근 틀
## 내보내기: ... -- SkyOffice/game/assets/models/station --station2-export
FLAG_H = 1.5   # zones.json flagpole height (깃발은 게임 코드가 그림 · 올림)


def flagpole(v, p):
    """깃대 (원점 = 받침 바닥, 높이 FLAG_H). A 흰 기둥 + 은색 공 · B 남색 기둥 + 은색 띠"""
    pole = M("PoleWhite", "#ece9e3", 0.4) if v == "A" else M("PoleNavy", LEATHER, 0.45)
    silver = M("PoleSilver", "#c5ccd1", 0.3, 0.7)
    base = M("PoleBase", "#5c6067", 0.45, 0.4)
    p.cyl(base, (0, 0, 0), 0.09, 0.04, seg=20)
    p.cone(base, (0, 0, 0.04), 0.06, 0.04, 0.06, seg=20)
    p.cyl(pole, (0, 0, 0.1), 0.03, FLAG_H - 0.1, seg=14)
    p.sphere(silver, (0, 0, FLAG_H + 0.03), 0.05, sub=2)
    if v == "B":
        for z in (0.35, FLAG_H - 0.12):
            p.cyl(silver, (0, 0, z), 0.036, 0.03, seg=14)
    p.box(silver, (0.035, 0, FLAG_H - 0.05), (0.04, 0.02, 0.02), bevel=0.005)   # 줄 고리
    p.cyl(M("Rope", "#e9e6e1", 0.8), (0.045, 0, 0.12), 0.004, FLAG_H - 0.17, seg=6)


SIGN_W, SIGN_H, SIGN_Z = 1.2, 0.42, 0.18   # 간판 판 (원점 = 뒷벽 윗면 가운데, 판 아래 = SIGN_Z)


def sign(v, p, face):
    """뒷벽 위 세움 간판 (앞 = -Y). 글자 (회사 이름) 는 게임이 판 앞에 씀 → face = 글자 바탕 (SignFace, 단계마다 재질 교체)
    H 창업 손글씨 (나무 판자 + 다리) · A 남색 판 + 흰 테 · B 흰 둥근 판 + 남색 테 + 위 조명 2"""
    zc = SIGN_Z + SIGN_H / 2
    metal = M("SignMetal", "#5c6067", 0.45, 0.4)
    if v == "H":
        wood, wood_d = M("KWood", K.WOOD), M("KWoodD", K.WOOD_D, 0.75)
        for x in (-0.42, 0.42):
            p.box(wood_d, (x, 0.02, (SIGN_Z + 0.1) / 2), (0.06, 0.05, SIGN_Z + 0.1), bevel=0.012)
        for k in range(3):   # 판자 3장 (살짝 어긋남)
            K.tbox(p, wood, (0.01 * (k - 1), 0, SIGN_Z + 0.07 + k * 0.14), (SIGN_W - 0.04 * k, 0.04, 0.13), rot=(0, (-1.5, 1, -0.5)[k], 0), bevel=0.012)
        face.box(M("SignFaceChalk", "#8a6a54", 0.9), (0, -0.022, zc), (SIGN_W - 0.2, 0.004, SIGN_H - 0.1), bevel=0)
        return
    rim = M("SignRimW", "#e9e6e1", 0.5) if v == "A" else M("SignRimN", LEATHER, 0.5)
    board = M("SignNavy", "#2f3a52", 0.55) if v == "A" else M("SignWhite", "#f1eee9", 0.45)
    for x in (-0.4, 0.4):
        p.box(metal, (x, 0.02, SIGN_Z / 2 + 0.02), (0.04, 0.04, SIGN_Z + 0.04), bevel=0.01)
    p.box(rim, (0, 0, zc), (SIGN_W + 0.06, 0.07, SIGN_H + 0.06), bevel=0.035, seg=3)
    face.box(board, (0, -0.034, zc), (SIGN_W - 0.04, 0.008, SIGN_H - 0.04), bevel=0.01)
    if v == "B":   # 위 조명 2 (팔 + 갓, 밤에 판을 비춤)
        for x in (-0.35, 0.35):
            p.box(metal, (x, -0.06, SIGN_Z + SIGN_H + 0.06), (0.02, 0.14, 0.02), bevel=0.006)
            p.cone(M("SignLamp", "#3b3d42", 0.5), (x, -0.13, SIGN_Z + SIGN_H + 0.02), 0.04, 0.02, 0.05, seg=14, rot=(-30, 0, 0))


def sign_text(text="하늘 오피스", v="A"):
    """미리보기용 글자 (게임은 Label3D 로 회사 이름)"""
    txt = bpy.data.curves.new("SignText", "FONT")
    txt.body = text
    txt.size = 0.22
    txt.align_x = "CENTER"
    txt.align_y = "CENTER"
    o = bpy.data.objects.new("SignText", txt)
    col = {"H": "#f1eee9", "A": "#f1eee9", "B": "#2f3a52"}[v]
    o.data.materials.append(mat("SignInk" + v, col, 0.6))
    bpy.context.scene.collection.objects.link(o)
    o.rotation_euler = (math.pi / 2, 0, 0)
    o.location = (0, -0.045, SIGN_Z + SIGN_H / 2)
    return o


NB_W, NB_H, NB_Z = 0.56, 0.62, 0.36   # 게시판 판 (코르크) 크기 · 아래 높이


def notice_board(v, p, cont, gp=None):
    """복도 입간판 게시판 (원점 = 바닥 가운데, 앞 = -Y). 판 위 = 성장 막대 (Growth, 게임이 늘림) · 사진 2 · 종이 3 → cont
    A A자 입간판 (나무) · B 나무 이젤 · C 금속 틀 + 바퀴 (화이트보드 B 짝) · D = B 이젤 + C 흰 둥근 틀 (사용자)
    gp = 성장 막대 (Growth, 따로 — 게임이 x 로 늘림)"""
    wood, wood_d = M("KWood", K.WOOD), M("KWoodD", K.WOOD_D, 0.75)
    cork = M("Cork", "#b58f6b", 0.95)
    zc = NB_Z + NB_H / 2
    tilt = -10 if v != "C" else 0
    if v == "A":   # 뒤 다리판 + 앞 판 (기움) + 위 손잡이
        K.tbox(p, wood_d, (0, 0.17, zc - 0.05), (NB_W - 0.06, 0.04, NB_H + 0.3), rot=(12, 0, 0), bevel=0.02)
        K.tbox(p, wood, (0, 0.0, zc - 0.04), (NB_W + 0.08, 0.05, NB_H + 0.34), rot=(tilt, 0, 0), bevel=0.025, seg=3)
        K.tbox(p, wood_d, (0, 0.06, NB_Z + NB_H + 0.18), (0.16, 0.06, 0.05), rot=(0, 0, 0), bevel=0.015)
    elif v in "BD":   # 이젤: 앞 다리 2 + 뒤 다리 1 + 받침대
        for x in (-0.2, 0.2):
            K.tbox(p, wood, (x, -0.03, 0.5), (0.04, 0.04, 1.05), rot=(-6, 0, -6 if x < 0 else 6), bevel=0.012)
        K.tbox(p, wood_d, (0, 0.2, 0.45), (0.04, 0.04, 0.95), rot=(22, 0, 0), bevel=0.012)
        K.tbox(p, wood_d, (0, -0.07, NB_Z - 0.03), (NB_W + 0.1, 0.08, 0.04), bevel=0.012)
        if v == "B":
            K.tbox(p, wood, (0, -0.02, zc), (NB_W + 0.06, 0.04, NB_H + 0.06), rot=(tilt, 0, 0), bevel=0.02, seg=3)
        else:
            K.tbox(p, M("WbFrame", "#ece9e3", 0.5), (0, -0.02, zc), (NB_W + 0.07, 0.05, NB_H + 0.07), rot=(tilt, 0, 0), bevel=0.03, seg=3)
    else:          # 금속 틀 + 다리 2 + 바퀴
        frame = M("WbFrame", "#ece9e3", 0.5)
        metal = M("WbMetal", "#5c6067", 0.45, 0.5)
        for x in (-NB_W / 2 - 0.04, NB_W / 2 + 0.04):
            p.box(metal, (x, 0, (NB_Z + NB_H + 0.05) / 2), (0.03, 0.03, NB_Z + NB_H + 0.05), bevel=0.008)
            p.box(metal, (x, 0, 0.05), (0.04, 0.34, 0.03), bevel=0.008)
            for y in (-0.15, 0.15):
                p.sphere(M("Wheel", SLATE, 0.6), (x, y, 0.025), 0.025)
        p.box(frame, (0, 0, zc), (NB_W + 0.07, 0.05, NB_H + 0.07), bevel=0.03, seg=3)
    # 코르크 판 + 내용 (판 앞면 기준, 기울기 같이): 판 위 방향 = (0, -sin t, cos t), 앞 방향 = (0, -cos t, -sin t)
    t = math.radians(tilt)
    ct, st = math.cos(t), math.sin(t)
    cy = {"B": -0.046, "D": -0.051}.get(v, -0.031)

    def on(x, z, sx, sz, m, d=0.006, rz=0.0, to=None):   # 판 가운데 기준 (x, z), 코르크 앞에 붙음
        o = 0.006 + d / 2
        K.tbox(to or cont, m, (x, cy - z * st - o * ct, zc + z * ct - o * st), (sx, d, sz), rot=(tilt, rz, 0), bevel=0.002)
    K.tbox(p, cork, (0, cy, zc), (NB_W, 0.012, NB_H), rot=(tilt, 0, 0), bevel=0.004)
    paper, navy = M("Paper", PAPER, 0.9), M("NbNavy", LEATHER, 0.6)
    on(0, 0.23, NB_W - 0.12, 0.1, navy, d=0.008)                                  # 제목 띠
    on(-0.12, 0.05, 0.22, 0.16, paper, rz=-4)                                      # 성장 종이 + 막대
    on(-0.12, 0.08, 0.17, 0.03, M("NbBarBack", "#d4d0c8", 0.8), d=0.01)
    on(-0.16, 0.08, 0.09, 0.032, M("NbBar", "#8fd18f", 0.6), d=0.012, to=gp)        # Growth (초록 = 끝 · 성장)
    on(0.13, 0.05, 0.13, 0.15, M("PhotoW", "#f1eee9", 0.8), rz=5)                  # 사진 (흰 테 + 하늘)
    on(0.13, 0.06, 0.1, 0.09, M("PhotoSky", "#9fb6c9", 0.6), d=0.01, rz=5)
    on(-0.1, -0.17, 0.2, 0.14, M("NoteBlue", "#a9c6e0", 0.8), rz=3)
    on(0.14, -0.18, 0.16, 0.13, paper, rz=-6)
    for x, z in ((-0.12, 0.13), (0.13, 0.13), (-0.1, -0.11), (0.14, -0.12)):      # 핀
        on(x, z, 0.022, 0.022, M("Pin", "#a65e5e", 0.5), d=0.016)


def station2_preview():
    clear()
    for i, v in enumerate("AB"):
        c = Parts()
        flagpole(v, c)
        place([c.obj("Pole" + v)], -2.55 + i * 0.45, 0.6)
        _label(30 + i, "깃대 " + v, -2.55 + i * 0.45, -0.1, 0.1)
    for i, v in enumerate("HAB"):
        c, f = Parts(), Parts()
        sign(v, c, f)
        objs = [c.obj("Sign" + v), f.obj("SignFace" + v), sign_text(v=v)]
        place(objs, -1.0 + i * 1.45, 0.9)
        _label(40 + i, ("간판 창업 손글씨", "간판 A", "간판 B")[i], -1.0 + i * 1.45, 0.45, 0.1)
    for i, v in enumerate("ABCD"):
        c, ct = Parts(), Parts()
        notice_board(v, c, ct)
        place([c.obj("Notice" + v), ct.obj("NoticeContent" + v)], -1.0 + i * 0.9, -0.9)
        _label(50 + i, "게시판 " + v, -1.0 + i * 0.9, -1.45, 0.1)
    render("pick_station2", 5.6, look=(-0.1, 0.0, 0.5), res=(1600, 1000))


def station2_export():
    """게임용 glb (game/assets/models/station/): flagpole · sign (SignHand 창업 손글씨 / SignNew 스타트업 — M5 단계가 바꿈) · notice_board"""
    clear()
    p = Parts()
    flagpole(STATION2["flagpole"], p)
    export("flagpole", [p.obj("FlagPoleMesh")], "FlagPole")
    clear()
    objs = []
    for v, n in (("H", "SignHand"), (STATION2["sign"], "SignNew")):   # 판 · 바탕을 한 물체로 (단계 = 물체째 바꿈)
        c = Parts()
        sign(v, c, c)
        objs.append(c.obj(n))
    export("sign", objs, "Sign")
    clear()
    c, ct, g = Parts(), Parts(), Parts()
    notice_board(STATION2["notice"], c, ct, g)
    export("notice_board", [c.obj("NoticeBoardMesh"), ct.obj("NoticeContent"), g.obj("Growth")], "NoticeBoard")


if __name__ == "__main__" and "--station2-export" in ARGV:
    station2_export()
elif __name__ == "__main__" and "--station2" in ARGV:
    station2_preview()
elif __name__ == "__main__" and "--station-export" in ARGV:
    station_export()
elif __name__ == "__main__" and "--station" in ARGV:
    station_preview()
elif __name__ == "__main__" and EXPORT:
    export_all()
elif __name__ == "__main__":
    clear()
    G = 1.9
    for i, v in enumerate("ABC"):
        x = (i - 1) * G
        place(boss_set(v), x)
        cb = Parts()
        po = cabinet(cb)
        r = place([cb.obj("Cabinet"), po], x + 0.55, 0.85)
        r.scale = (0.9, 0.9, 0.9)
        place(boss_set(v), x - 0.1, -2.0, math.radians(90))   # 줄 2 = 게임 방향 (사장이 왼쪽 창구를 봄)
    pp = Parts()
    paper_plane(pp)
    r = place([pp.obj("PaperPlane")], 2.75, -0.6, math.radians(-30))
    r.scale = (2.5, 2.5, 2.5)
    r.location.z = 0.5
    r.rotation_euler.x = math.radians(-12)
    render("pick_boss_desk", 6.6, look=(0.1, -0.6, 0.3), res=(1600, 1150))
