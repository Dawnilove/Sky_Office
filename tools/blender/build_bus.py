"""하늘 통근버스 (M4 3세션째, 사용자: "비행선이 통근버스처럼 · 사람 크기에 맞춰 크게") — 비행선 재사용 대신 새 모델
(스타일 = build_desk_kit.py: 두툼한 덩어리 · 크게 둥근 모서리. 색 = 남색 · 크림 · 하늘색, 노랑 금지 = '내 차례' 전용)

미리보기 (OverLand 폴더에서):
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P SkyOffice/tools/blender/build_bus.py -- <폴더>
  → pick_bus.png (A 지붕 프로펠러 · B 풍선 버스 · C 날개 셔틀, 옆에 직원 = 크기 비교)
내보내기: ... -P SkyOffice/tools/blender/build_bus.py -- SkyOffice/game/assets/models/station --export  → bus.glb
- 단위 = 칸 (직원 머리 중심 0.875). 원점 = 차 바닥 가운데, 앞 = +X, 문 = -Y 쪽 (게임: 카메라 쪽)
- 이름 붙인 부품 (게임이 돌림): Rotor0 · Rotor1 (원점 = 축)
"""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_office_props import Parts, clear, export, mat, lin  # noqa: E402
import build_desk_kit as K  # noqa: E402

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(ARGV[0]) if ARGV else "."
EXPORT = "--export" in ARGV
CHOICE = "A"   # 사용자 고름 (2026-10-16): A 지붕 프로펠러 + 바닥 추진기

NAVY, NAVY_D, CREAM, SKY = "#3f4c6b", "#2f3a52", "#e9e3d8", "#9fc3d6"
GLASS, DARK, SILVER = "#2c3540", "#3b3d42", "#c5ccd1"
L, W, H, Z0 = 2.7, 0.95, 1.0, 0.18   # 차체 길이 · 폭 · 높이 · 바닥 높이 (직원 키 ≈ 1.0 이 문으로 들어감)


def M(n, c, r=0.6, metal=0.0):
    return mat(n, c, r, metal)


def emit(name, hexcol, strength=1.0):
    m = mat(name, hexcol, 0.4)
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Emission Color"].default_value = (*lin(hexcol), 1)
    bsdf.inputs["Emission Strength"].default_value = strength
    return m


def body(p, ln=L, h=H, z0=Z0, wins=6):
    """버스 몸통: 크림 몸 + 남색 아랫단 + 하늘 띠 + 옆 창 줄 + 앞 유리 · 행선판 + 문 + 등 + 바퀴"""
    cream, navy, navy_d = M("BusCream", CREAM, 0.5), M("BusNavy", NAVY, 0.5), M("BusNavyD", NAVY_D, 0.55)
    glass, dark = M("BusGlass", GLASS, 0.25), M("BusDark", DARK, 0.6)
    zc = z0 + h / 2
    p.box(cream, (0, 0, zc), (ln, W, h), bevel=0.16, seg=4)                                  # 몸
    p.box(navy, (0, 0, z0 + 0.19), (ln + 0.02, W + 0.02, 0.38), bevel=0.12, seg=3)            # 아랫단
    p.box(M("BusSky", SKY, 0.5), (0, 0, z0 + 0.43), (ln + 0.025, W + 0.025, 0.07), bevel=0.03)  # 하늘 띠
    p.box(cream, (0, 0, z0 + h - 0.02), (ln - 0.3, W - 0.2, 0.08), bevel=0.04)                # 지붕 덮개
    wz, wh = z0 + 0.68, 0.36
    span = ln - 0.55
    for sy in (-1, 1):                                                                          # 옆 창 띠 (이어진 유리 + 크림 기둥, 문 쪽은 앞 한 칸 = 문)
        x0 = -ln / 2 + 0.25
        x1 = x0 + span * ((wins - 1) / wins if sy < 0 else 1.0)
        p.box(glass, ((x0 + x1) / 2, sy * (W / 2 + 0.003), wz), (x1 - x0, 0.02, wh), bevel=0.05)
        for k in range(1, wins if sy > 0 else wins - 1):
            p.box(cream, (x0 + span * k / wins, sy * (W / 2 + 0.008), wz), (0.05, 0.02, wh + 0.01), bevel=0.01)
    fx = ln / 2 + 0.003                                                                         # 앞: 유리 · 행선판 · 등 · 범퍼
    p.box(glass, (fx, 0, wz - 0.02), (0.02, W - 0.2, wh + 0.1), bevel=0.05)
    p.box(dark, (fx, 0, z0 + h - 0.13), (0.02, W - 0.3, 0.1), bevel=0.02)
    p.box(emit("BusSign", "#7fe3ff", 0.8), (fx + 0.011, 0, z0 + h - 0.13), (0.004, W - 0.42, 0.04), bevel=0)
    for sy in (-1, 1):
        p.cyl(emit("BusHead", "#f2efe8", 0.6), (fx, sy * 0.3, z0 + 0.25), 0.055, 0.03, seg=16, rot=(0, 90, 0))
        p.cyl(M("BusTail", "#a65e5e", 0.5), (-ln / 2 - 0.01, sy * 0.33, z0 + 0.3), 0.045, 0.03, seg=16, rot=(0, 90, 0))
    p.box(navy_d, (fx + 0.02, 0, z0 + 0.08), (0.06, W - 0.06, 0.1), bevel=0.04)
    p.box(glass, (-ln / 2 - 0.003, 0, wz), (0.02, W - 0.3, wh - 0.04), bevel=0.04)             # 뒤 유리
    dx = -ln / 2 + 0.25 + span * (wins - 0.5) / wins                                             # 문 (문 쪽 -Y, 앞쪽): 유리 두 짝 + 테
    p.box(navy_d, (dx, -W / 2 - 0.004, z0 + 0.43), (span / wins + 0.02, 0.02, 0.84), bevel=0.04)
    for s in (-1, 1):
        p.box(glass, (dx + s * span / wins / 4, -W / 2 - 0.012, z0 + 0.45), (span / wins / 2 - 0.035, 0.012, 0.74), bevel=0.02)
    p.box(M("BusStep", SILVER, 0.4, 0.5), (dx, -W / 2 - 0.05, z0 - 0.03), (span / wins, 0.1, 0.03), bevel=0.01)
    tire, hub = M("Tire", "#2b2d31", 0.8), M("Hub", SILVER, 0.35, 0.6)                         # 바퀴 (반쯤 숨음)
    for x in (-ln / 2 + 0.42, ln / 2 - 0.42):
        for sy in (-1, 1):
            p.cyl(tire, (x, sy * (W / 2 - 0.04), z0 + 0.02), 0.13, 0.1, seg=20, rot=(90, 0, 0))
            p.cyl(hub, (x, sy * (W / 2 + 0.065), z0 + 0.02), 0.06, 0.012, seg=16, rot=(90, 0, 0))


def thrusters(p, ln=L, z0=Z0):
    """바닥 추진기 2 (하늘색 빛) — 바퀴 대신 뜨는 이유"""
    shell, glow = M("ThrShell", "#5c6067", 0.45, 0.4), emit("ThrGlow", "#9fd8ef", 1.2)
    for x in (-ln / 4, ln / 4):
        p.cone(shell, (x, 0, z0 - 0.16), 0.13, 0.17, 0.16, seg=20)
        p.cyl(glow, (x, 0, z0 - 0.18), 0.1, 0.02, seg=20)


def rotor(name, hub, r=0.42, blades=3, tilt=(0, 0, 0)):
    """프로펠러 (원점 = 축): 둥근 축 + 날개. 게임이 축 둘레로 돌림"""
    p = Parts()
    blade, cap = M("Blade", "#e9e6e1", 0.45), M("RotCap", NAVY, 0.45)
    for k in range(blades):
        a = 360 * k / blades
        K.tbox(p, blade, (r / 2 * math.cos(math.radians(a)), r / 2 * math.sin(math.radians(a)), 0), (r, 0.09, 0.018),
               rot=(8, 0, a), bevel=0.008)
    p.sphere(cap, (0, 0, 0.01), 0.06, sub=2, scale=(1, 1, 0.7))
    o = p.obj(name)
    o.location = hub
    o.rotation_euler = tuple(math.radians(t) for t in tilt)
    return o


def bus(v):
    p = Parts()
    objs = []
    if v == "A":     # 통근버스 + 지붕 프로펠러 2 + 바닥 추진기
        body(p)
        thrusters(p)
        mast = M("Mast", "#5c6067", 0.45, 0.4)
        for k, x in enumerate((-0.6, 0.6)):
            p.cyl(mast, (x, 0, Z0 + H - 0.02), 0.035, 0.16, seg=12)
            objs.append(rotor("Rotor%d" % k, (x, 0, Z0 + H + 0.15)))
    elif v == "B":   # 풍선 버스: 낮은 버스 몸 + 위 작은 비행선 풍선 (줄 4)
        body(p, h=1.0)
        env, stripe = M("Envelope", CREAM, 0.5), M("EnvStripe", NAVY, 0.5)
        ez = Z0 + 1.0 + 0.55
        p.sphere(env, (0, 0, ez), 1.0, sub=3, scale=(1.25, 0.45, 0.38))
        p.sphere(stripe, (0, 0, ez), 1.0, sub=3, scale=(1.255, 0.455, 0.08))
        for sx in (-1, 1):   # 꼬리 날개
            K.tbox(p, stripe, (-1.15, sx * 0.18, ez + 0.05), (0.3, 0.03, 0.22), rot=(sx * 40, 0, 0), bevel=0.02)
        cable = M("Cable", "#5c6067", 0.5)
        for x in (-0.65, 0.65):
            for sy in (-1, 1):
                p.cyl(cable, (x, sy * 0.3, Z0 + 0.98), 0.01, 0.25, seg=6)
        objs.append(rotor("Rotor0", (-1.4, 0, ez), r=0.3, tilt=(0, 90, 0)))
    else:            # C 날개 셔틀: 짧고 둥근 미니버스 + 옆 짧은 날개 끝 프로펠러 2 + 꼬리 지느러미
        ln = 1.85
        body(p, ln=ln, wins=4)
        thrusters(p, ln=ln)
        wing = M("Wing", NAVY, 0.5)
        for k, sy in enumerate((-1, 1)):
            K.tbox(p, wing, (-0.1, sy * (W / 2 + 0.22), Z0 + 0.5), (0.5, 0.45, 0.06), rot=(sy * -8, 0, 0), bevel=0.025, seg=3)
            p.cyl(M("Pod", "#5c6067", 0.45, 0.4), (-0.1, sy * (W / 2 + 0.44), Z0 + 0.42), 0.07, 0.2, seg=16)
            objs.append(rotor("Rotor%d" % k, (-0.1, sy * (W / 2 + 0.44), Z0 + 0.66), r=0.3))
        K.tbox(p, wing, (-ln / 2 + 0.12, 0, Z0 + H + 0.12), (0.32, 0.05, 0.3), rot=(0, -20, 0), bevel=0.02)
    return [p.obj("BusBody")] + objs


def staff_ref(x, y):
    """크기 비교용 직원 (game/assets/models/staff.glb)"""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "game", "assets", "models", "staff.glb")
    root = bpy.data.objects.new("StaffRef", None)
    bpy.context.scene.collection.objects.link(root)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    for o in set(bpy.data.objects) - before:
        if o.parent is None:
            o.parent = root
    root.location = (x, y, 0)
    root.scale = (1 / 0.88,) * 3   # 모델 = 미터, 1칸 = 0.88m (게임 unit_m)


def preview():
    clear()
    for i, v in enumerate("ABC"):
        root = bpy.data.objects.new("V" + v, None)
        bpy.context.scene.collection.objects.link(root)
        for o in bus(v):
            o.parent = root
        x = (i - 1) * 3.4
        root.location = (x, 0, 0.6)   # 떠 있음
        root.rotation_euler = (0, 0, math.radians(-25))   # 앞 (+X) 이 살짝 보이게
        staff_ref(x + 0.9, -1.1)
        txt = bpy.data.curves.new("T" + v, "FONT")
        txt.body = v
        txt.size = 0.3
        txt.align_x = "CENTER"
        t = bpy.data.objects.new("T" + v, txt)
        t.data.materials.append(mat("Label", "#1f2329", 0.5))
        bpy.context.scene.collection.objects.link(t)
        t.location = (x, -1.6, 0)
    scn = bpy.context.scene
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scn.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 10.6
    pitch = math.radians(35)
    cam.location = (0, -20 * math.cos(pitch), 1.0 + 20 * math.sin(pitch))
    cam.rotation_euler = (math.pi / 2 - pitch, 0, 0)
    scn.camera = cam
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.rotation_euler = (0.6, 0.25, 0.4)
    scn.collection.objects.link(sun)
    scn.world = bpy.data.worlds.new("W")
    scn.world.use_nodes = True
    scn.world.node_tree.nodes["Background"].inputs[0].default_value = (0.72, 0.8, 0.88, 1)
    scn.world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    scn.view_settings.view_transform = "Standard"
    scn.render.resolution_x, scn.render.resolution_y = 1800, 760
    scn.render.filepath = os.path.join(OUT, "pick_bus.png")
    bpy.ops.render.render(write_still=True)
    print("[bus]", scn.render.filepath)


if __name__ == "__main__":
    if EXPORT:
        clear()
        export("bus", bus(CHOICE), "Bus")
    else:
        preview()
