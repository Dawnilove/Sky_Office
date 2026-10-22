"""하늘 오피스 분위기 조각 (M2): 책상 세트 · 탕비 카운터 · 결재 창구 → .glb

실행 (OverLand 폴더에서):
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P SkyOffice/tools/blender/build_office_props.py -- SkyOffice/game/assets/models

- 크기 단위 = 칸 (1 Blender 단위 = 1칸 = 0.88m). 게임에서 layout.unit_m 배로 키움
- 좌표: Blender Z 위 · -Y 앞 → glTF 내보내기 후 Godot Y 위 · +Z 앞
- 색 규칙 (PLAN 3-3 · v2.5): 노랑 · 금색 · 주황 금지 (노랑 = '내 차례' 전용). 나무는 채도 낮은 갈색
- 이름 붙인 부품 (게임이 찾아 씀): Screen (모니터 화면 — 상태에 따라 빛남) · Bulb (스탠드 전구) · ChairBack (의자 등받이 — 직원 색)
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(ARGS[0] if ARGS else "assets_out")
os.makedirs(OUT, exist_ok=True)

## 색 (sRGB) — 채도 낮게, 따뜻하지만 노랑 · 주황 쪽으로 안 가게
WOOD = "#9a8068"        # 책상 상판 · 카운터 상판 (밝은 호두나무)
WOOD_DARK = "#6e5a4a"
WHITE = "#e9e6e1"       # 서랍장 · 카운터 문
STEEL = "#8b9097"
DARK = "#3b3d42"        # 모니터 테두리 · 다리
SCREEN = "#2c3036"      # 꺼진 화면 (게임에서 덮어씀)
FABRIC = "#8e98a3"      # 칸막이 천 (회청색, 작업실 카펫과 같은 계열)
SEAT = "#5f646c"        # 의자 쿠션
SHIRT_DEFAULT = "#7d8fa6"
BULB = "#f2efe8"        # 전구 (흰빛 — 노랑 아님)
STONE = "#d5d2cc"       # 카운터 상판 (밝은 돌)
LEAF = "#6f8a5a"
POT = "#a39587"
CUPS = ["#f1efe9", "#8fa79a", "#7f93ad"]


# ------------------------------------------------------------------ 도우미
def lin(hexcol):
    h = hexcol.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]


_MATS = {}


def mat(name, hexcol, rough=0.8, metal=0.0):
    if name in _MATS:
        return _MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*lin(hexcol), 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    _MATS[name] = m
    return m


class Parts:
    """여러 도형을 재질별로 모아 한 물체로 만듦. 도형마다 임시 bmesh 에서 만들고 합침 (bevel = 모서리 살짝 깎기)"""

    def __init__(self):
        self.bm = bmesh.new()
        self.mats = []
        self._tmp = bpy.data.meshes.new("_tmp")

    def _add(self, tb, m, c, rot):
        rx, ry, rz = (math.radians(a) for a in rot)
        mtx = Matrix.Translation(c) @ Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rx, 4, "X")
        bmesh.ops.transform(tb, matrix=mtx, verts=tb.verts)
        if m not in self.mats:
            self.mats.append(m)
        for f in tb.faces:
            f.material_index = self.mats.index(m)
        tb.to_mesh(self._tmp)
        tb.free()
        self.bm.from_mesh(self._tmp)

    def box(self, m, c, size, bevel=0.012, rot_z=0.0, seg=2):
        """c = 중심 (x, y, z), size = 전체 크기 (칸). seg = 모서리 깎는 단 수 (2 = 둥글게, M4 KayKit 처럼 두툼하게)"""
        tb = bmesh.new()
        bmesh.ops.create_cube(tb, size=1.0)
        bmesh.ops.scale(tb, vec=Vector(size), verts=tb.verts)
        if bevel > 0:
            bmesh.ops.bevel(tb, geom=list(tb.edges), offset=min(bevel, min(size) * 0.45), segments=seg,
                            affect="EDGES", profile=0.5)
        self._add(tb, m, c, (0, 0, math.degrees(rot_z)))

    def cyl(self, m, c, r, h, seg=12, rot=(0, 0, 0)):
        """밑면 중심 c, 반지름 r, 높이 h (rot = 도 단위 X · Y · Z 회전)"""
        self.cone(m, c, r, r, h, seg, rot)

    def cone(self, m, c, r0, r1, h, seg=12, rot=(0, 0, 0)):
        tb = bmesh.new()
        bmesh.ops.create_cone(tb, cap_ends=True, segments=seg, radius1=r0, radius2=r1, depth=h)
        bmesh.ops.translate(tb, vec=Vector((0, 0, h / 2)), verts=tb.verts)
        self._add(tb, m, c, rot)

    def sphere(self, m, c, r, sub=1, scale=(1, 1, 1)):
        tb = bmesh.new()
        bmesh.ops.create_icosphere(tb, subdivisions=sub, radius=r)
        bmesh.ops.scale(tb, vec=Vector(scale), verts=tb.verts)
        self._add(tb, m, c, (0, 0, 0))

    def obj(self, name):
        me = bpy.data.meshes.new(name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        bpy.data.meshes.remove(self._tmp)
        for m in self.mats:
            me.materials.append(m)
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        return o


def clear():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)


def export(name, objs, root_name):
    root = bpy.data.objects.new(root_name, None)
    bpy.context.scene.collection.objects.link(root)
    for o in objs:
        o.parent = root
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = root
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=True)
    faces = sum(len(o.data.polygons) for o in objs)
    print(f"[office] {name}.glb  faces={faces}")


# ------------------------------------------------------------------ 책상 세트
## 기준 = 앞줄 책상 (rot 0): 앉은 사람이 Godot -Z (= Blender +Y) 를 봄. 원점 = 책상 중심 바닥
## zones.json: 책상 1.2 × 0.6 · 의자 = 책상 중심에서 사람 쪽 0.55 · 앞 칸막이 = 책상 먼 쪽 끝 (마주 보는 책상과 맞닿는 선)
DESK_W, DESK_D = 1.2, 0.6
TOP = 0.48        # 상판 윗면 높이 (칸) — 앉은 직원 손 바로 아래
SEAT_Y = -0.55    # 의자 중심 (Blender y, 사람 쪽 = -Y)
SEAT_TOP = 0.28   # 의자 방석 윗면 — 직원 엉덩이 높이 (0.245m), 발은 살짝 뜸
PANEL_TOP = 0.8


def build_desk_set():
    clear()
    wood = mat("DeskWood", WOOD, 0.7)
    white = mat("Cabinet", WHITE, 0.6)
    dark = mat("Dark", DARK, 0.5)
    steel = mat("Steel", STEEL, 0.4, 0.6)
    fabric = mat("PanelFabric", FABRIC, 0.95)
    seat = mat("Seat", SEAT, 0.9)
    wdark = mat("WoodDark", WOOD_DARK, 0.7)

    d = Parts()
    # 상판 + 다리 (왼쪽은 서랍장이 받침, 오른쪽은 금속 다리 2개)
    d.box(wood, (0, 0, TOP - 0.035), (DESK_W, DESK_D, 0.07), bevel=0.028)   # 두꺼운 상판 + 둥근 모서리 (M4: KayKit 처럼)
    for y in (-DESK_D / 2 + 0.07, DESK_D / 2 - 0.07):
        d.box(steel, (DESK_W / 2 - 0.07, y, (TOP - 0.07) / 2), (0.065, 0.065, TOP - 0.07), bevel=0.02)
    d.box(steel, (DESK_W / 2 - 0.07, 0, 0.035), (0.06, DESK_D - 0.1, 0.05), bevel=0.018)
    # 서랍장 (왼쪽 아래, 서랍 3칸 + 손잡이)
    cx, cw, cd = -DESK_W / 2 + 0.2, 0.34, 0.52
    d.box(white, (cx, 0, (TOP - 0.07) / 2), (cw, cd, TOP - 0.07), bevel=0.03)
    for k, z in enumerate((0.33, 0.21, 0.09)):
        d.box(mat("CabinetLine", "#cfcac2", 0.7), (cx, -cd / 2 - 0.004, z + 0.055), (cw - 0.06, 0.01, 0.01), bevel=0)
        d.box(steel, (cx, -cd / 2 - 0.014, z), (0.12, 0.02, 0.026), bevel=0.009)
    # 앞 칸막이 (책상 먼 쪽 끝, 천 + 아래 나무 띠) — 마주 보는 책상의 칸막이와 맞닿게 안쪽으로 두께 절반
    py = DESK_D / 2 - 0.015
    d.box(fabric, (0, py, (TOP + PANEL_TOP) / 2 + 0.01), (DESK_W - 0.02, 0.03, PANEL_TOP - TOP - 0.02), bevel=0.012)
    d.box(wdark, (0, py, PANEL_TOP), (DESK_W, 0.05, 0.04), bevel=0.016)
    # 모니터: 받침 + 목 + 테두리 (화면은 따로)
    my = DESK_D / 2 - 0.08   # 칸막이 쪽으로 (앞줄 직원 머리에 안 가리게)
    d.box(dark, (0, my - 0.01, TOP + 0.012), (0.2, 0.12, 0.024), bevel=0.01)
    d.box(dark, (0, my + 0.01, TOP + 0.12), (0.06, 0.04, 0.22), bevel=0.015)
    d.box(dark, (0, my, TOP + 0.29), (0.54, 0.05, 0.32), bevel=0.024)
    # 키보드 · 마우스 · 서류 · 머그
    d.box(mat("Keys", "#d9d6d0", 0.6), (0, -0.04, TOP + 0.011), (0.34, 0.12, 0.022), bevel=0.01)
    d.box(mat("Keys", "#d9d6d0"), (0.26, -0.05, TOP + 0.013), (0.06, 0.09, 0.026), bevel=0.012)
    d.box(mat("Paper", "#f3f1ec", 0.9), (-0.3, -0.02, TOP + 0.006), (0.18, 0.24, 0.012), bevel=0, rot_z=math.radians(-8))
    d.cyl(mat("Mug", CUPS[1], 0.5), (-0.42, 0.12, TOP), 0.035, 0.07)
    # 스탠드: 받침 + 기둥 (유리 갓 = Bulb, 따로 — 위에서 내려다봐도 켜진 게 보이게 버섯 모양)
    lx, ly = DESK_W / 2 - 0.12, 0.1
    d.cone(dark, (lx, ly, TOP), 0.06, 0.05, 0.03, seg=16)
    d.cyl(dark, (lx, ly, TOP + 0.03), 0.02, 0.19, seg=10)
    # 의자: 다리 5개 + 기둥 + 방석 (등받이는 따로 — 직원 색)
    for k in range(5):
        a = math.radians(90 + k * 72)
        d.box(dark, (0.12 * math.cos(a), SEAT_Y + 0.12 * math.sin(a), 0.035), (0.24, 0.05, 0.04), bevel=0.015, rot_z=a)
        d.sphere(dark, (0.22 * math.cos(a), SEAT_Y + 0.22 * math.sin(a), 0.025), 0.028)
    d.cyl(steel, (0, SEAT_Y, 0.05), 0.03, SEAT_TOP - 0.12, seg=12)
    d.box(seat, (0, SEAT_Y, SEAT_TOP - 0.045), (0.42, 0.4, 0.09), bevel=0.042)   # 두툼한 방석
    d.box(dark, (0, SEAT_Y - 0.2, SEAT_TOP + 0.08), (0.08, 0.04, 0.2), bevel=0.016)   # 등받이 지지대
    desk = d.obj("Desk")

    s = Parts()
    s.box(mat("ScreenOff", SCREEN, 0.3), (0, 0, 0), (0.46, 0.01, 0.26), bevel=0)
    screen = s.obj("Screen")
    screen.location = (0, my - 0.027, TOP + 0.295)   # 두꺼워진 테두리 앞면보다 살짝 앞

    b = Parts()
    b.sphere(mat("Bulb", BULB, 0.4), (0, 0, 0), 0.07, sub=2, scale=(1, 1, 0.7))
    bulb = b.obj("Bulb")
    bulb.location = (lx, ly, TOP + 0.24)

    c = Parts()
    c.box(mat("ChairBack", SHIRT_DEFAULT, 0.9), (0, 0, 0), (0.42, 0.08, 0.3), bevel=0.04)
    back = c.obj("ChairBack")
    back.location = (0, SEAT_Y - 0.21, SEAT_TOP + 0.2)
    export("desk_set", [desk, screen, bulb, back], "DeskSet")


# ------------------------------------------------------------------ 탕비 카운터
## zones.json pantry: 크기 0.5 (x) × 1.4 (z), 휴게 구역 왼쪽 → 앞면이 Godot +X 를 봄. 원점 = 가운데 바닥
## Godot z = -Blender y 이므로 Blender 에서 길이 방향 = Y
P_W, P_L, P_TOP = 0.5, 1.4, 0.55


def build_pantry():
    clear()
    white = mat("Cabinet", WHITE, 0.6)
    stone = mat("CounterTop", STONE, 0.5)
    wood = mat("DeskWood", WOOD, 0.7)
    dark = mat("Dark", DARK, 0.5)
    steel = mat("Steel", STEEL, 0.35, 0.7)
    leaf = mat("Leaf", LEAF, 0.9)
    pot = mat("Pot", POT, 0.9)

    p = Parts()
    # 몸통 (나무 띠 받침 + 흰 문 3짝) + 돌 상판
    p.box(wood, (0, 0, 0.03), (P_W - 0.04, P_L - 0.04, 0.06), bevel=0.006)
    p.box(white, (0, 0, (P_TOP - 0.04) / 2 + 0.03), (P_W, P_L, P_TOP - 0.1))
    door_l = (P_L - 0.06) / 3
    for k in range(3):
        y = -P_L / 2 + 0.03 + door_l * (k + 0.5)
        p.box(mat("CabinetLine", "#cfcac2", 0.7), (P_W / 2 + 0.003, y + door_l / 2, 0.29), (0.01, 0.008, 0.4), bevel=0)
        p.box(steel, (P_W / 2 + 0.012, y + door_l / 2 - 0.05, 0.42), (0.014, 0.016, 0.1), bevel=0.003)
    p.box(stone, (0, 0, P_TOP - 0.02), (P_W + 0.04, P_L + 0.04, 0.04), bevel=0.01)
    p.box(wood, (-P_W / 2 + 0.02, 0, P_TOP + 0.06), (0.04, P_L + 0.04, 0.12), bevel=0.006)   # 뒤쪽 낮은 막이
    # 커피 머신 (상판 한쪽 끝)
    cy = -P_L / 2 + 0.22
    p.box(dark, (-0.03, cy, P_TOP + 0.15), (0.26, 0.24, 0.3), bevel=0.03)
    p.box(steel, (0.06, cy, P_TOP + 0.22), (0.12, 0.2, 0.06), bevel=0.01)
    p.box(steel, (0.09, cy, P_TOP + 0.015), (0.12, 0.16, 0.012), bevel=0.003)
    p.cyl(mat("Cup0", CUPS[0], 0.4), (0.08, cy, P_TOP + 0.02), 0.03, 0.06)
    # 컵 3개 (거꾸로 엎은 컵 + 서 있는 컵)
    for k, col in enumerate(CUPS):
        p.cyl(mat("Cup%d" % k, col, 0.4), (0.1 - (k % 2) * 0.09, -0.12 + k * 0.1, P_TOP), 0.035, 0.07)
    # 주전자
    p.cyl(steel, (0.0, 0.14, P_TOP), 0.06, 0.13, seg=14)
    p.cone(steel, (0.0, 0.14, P_TOP + 0.13), 0.06, 0.02, 0.04, seg=14)
    p.box(dark, (-0.07, 0.14, P_TOP + 0.09), (0.03, 0.02, 0.08), bevel=0.005)
    # 과일 그릇 (초록 사과 — 주황 · 노랑 과일 안 씀)
    p.cyl(mat("Bowl", "#c9c4bc", 0.6), (0.05, 0.38, P_TOP), 0.09, 0.04, seg=14)
    for k in range(3):
        a = math.radians(k * 120)
        p.sphere(mat("Apple", "#86a35f", 0.6), (0.05 + 0.04 * math.cos(a), 0.38 + 0.04 * math.sin(a), P_TOP + 0.06), 0.035)
    # 작은 화분 (끝)
    p.cyl(pot, (-0.05, P_L / 2 - 0.13, P_TOP), 0.07, 0.11, seg=10)
    p.sphere(leaf, (-0.05, P_L / 2 - 0.13, P_TOP + 0.2), 0.11, scale=(1, 1, 1.2))
    p.sphere(leaf, (-0.0, P_L / 2 - 0.08, P_TOP + 0.15), 0.07)
    pantry = p.obj("Pantry")
    export("pantry", [pantry], "PantrySet")


# ------------------------------------------------------------------ 결재 창구 (v2.6 구역 표시 — 높은 카운터 + 유리 틀)
## zones.json fixed.counter: 크기 0.5 (x) × 1.2 (z). 손님 (줄) 쪽 = Godot +X, 사장 쪽 = -X. 원점 = 가운데 바닥
## 유리 판은 게임이 반투명 상자로 덧붙임 (틀만 여기) — 차가운 회청색으로 휴게 (나무) 와 대비
C_W, C_L, C_TOP, GLASS_TOP = 0.5, 1.2, 0.78, 1.35
COOL = "#c3cad0"        # 카운터 몸통 (차가운 밝은 회색)
COOL_DARK = "#7f8b97"   # 앞면 띠 · 걸레받이


def build_service_counter():
    clear()
    body = mat("CounterBody", COOL, 0.6)
    band = mat("CounterBand", COOL_DARK, 0.6)
    stone = mat("CounterTop", STONE, 0.5)
    steel = mat("Steel", STEEL, 0.35, 0.7)
    dark = mat("Dark", DARK, 0.5)
    paper = mat("Paper", "#f3f1ec", 0.9)

    c = Parts()
    # 몸통 (손님 쪽 = 높은 막이, 사장 쪽은 안쪽 선반) + 걸레받이 + 앞면 가로 띠
    c.box(band, (0, 0, 0.03), (C_W - 0.04, C_L - 0.04, 0.06), bevel=0.006)
    c.box(body, (0.05, 0, C_TOP / 2), (C_W - 0.1, C_L, C_TOP - 0.04))
    c.box(band, (C_W / 2 + 0.003, 0, C_TOP * 0.62), (0.012, C_L - 0.04, 0.05), bevel=0)
    c.box(body, (-C_W / 2 + 0.06, 0, 0.26), (0.12, C_L, 0.04))   # 사장 쪽 낮은 선반
    # 상판 (손님 쪽으로 살짝 나옴)
    c.box(stone, (0.04, 0, C_TOP - 0.02), (C_W + 0.08, C_L + 0.06, 0.04), bevel=0.01)
    # 유리 틀: 양 끝 기둥 + 위 가로대 (유리 아래 0.08 = 서류 넣는 틈)
    for y in (-C_L / 2 + 0.02, C_L / 2 - 0.02):
        c.box(steel, (0, y, (C_TOP + GLASS_TOP) / 2), (0.04, 0.04, GLASS_TOP - C_TOP), bevel=0.006)
    c.box(steel, (0, 0, GLASS_TOP), (0.05, C_L, 0.04), bevel=0.008)
    c.box(dark, (0, 0, GLASS_TOP + 0.1), (0.03, 0.5, 0.16), bevel=0.01)   # 위 안내판 (창구 표시)
    # 손님 쪽: 펜 꽂이 · 서류 받침, 사장 쪽: 도장 · 서류 더미
    c.cyl(dark, (0.18, -0.4, C_TOP), 0.03, 0.08)
    c.box(paper, (0.15, 0.15, C_TOP + 0.006), (0.16, 0.22, 0.012), bevel=0, rot_z=math.radians(6))
    c.box(paper, (-0.15, 0.3, C_TOP + 0.03), (0.16, 0.22, 0.06), bevel=0.004)
    c.cyl(dark, (-0.15, -0.2, C_TOP), 0.025, 0.07)
    counter = c.obj("ServiceCounter")
    export("service_counter", [counter], "ServiceCounterSet")


if __name__ == "__main__":
    build_desk_set()
    build_pantry()
    build_service_counter()
