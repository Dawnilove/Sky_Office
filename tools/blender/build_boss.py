"""하늘 오피스 사장 (= 플레이어, M4 3세션째 사용자: "사장 자리에 플레이어가 앉아 있게 · 직원과 다른 모델") → boss/boss.glb

실행 (OverLand 폴더에서):
  미리보기:  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P SkyOffice/tools/blender/build_boss.py -- <폴더> --preview
             → pick_boss.png (A 정장 · B 카디건 + 안경 · C 조끼 + 걷은 소매, 오른쪽 끝 = 직원 비교)
  내보내기:  ... -- SkyOffice/game/assets/models/boss   → boss.glb
- 뼈대 · 도형 방식 · 단위 (m) = build_staff.py 와 같음 (동작을 같이 쓸 수 있게). 직원과 다른 점 = 옷 · 머리 · 소품
- 색 규칙: 노랑 · 금색 · 주황 금지 (노랑 = '내 차례' 전용)
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_staff as ST  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(ARGS[0] if ARGS else "assets_out")
PREVIEW = "--preview" in ARGS
CHOICE = "A"   # 사용자 고름 (2026-10-16): A 남색 정장

SKIN, EYE, SHINE, BLUSH, MOUTH = "#f2d0b6", "#1f1b1b", "#ffffff", "#eab0a8", "#9a5a52"
WHITE, NAVY, NAVY_D, SKY = "#f1efea", "#3f4c6b", "#2f3a52", "#9fc3d6"


def torus(b, m, bone, c, R, r, rot_x=90.0, seg=(18, 8)):
    """고리 (안경테 등) — Body 에 붙임. 기본 = 얼굴 앞을 보는 고리 (XZ 평면)"""
    tb = bmesh.new()
    rows = []
    for i in range(seg[0]):
        a = 2 * math.pi * i / seg[0]
        ring = []
        for j in range(seg[1]):
            t = 2 * math.pi * j / seg[1]
            ring.append(tb.verts.new(((R + r * math.cos(t)) * math.cos(a), (R + r * math.cos(t)) * math.sin(a), r * math.sin(t))))
        rows.append(ring)
    for i in range(seg[0]):
        for j in range(seg[1]):
            tb.faces.new((rows[i][j], rows[(i + 1) % seg[0]][j], rows[(i + 1) % seg[0]][(j + 1) % seg[1]], rows[i][(j + 1) % seg[1]]))
    if bone == "head":
        c = (c[0], c[1], c[2] - ST.HEAD_DROP)
    bmesh.ops.transform(tb, matrix=Matrix.Translation(c) @ Matrix.Rotation(math.radians(rot_x), 4, "X"), verts=tb.verts)
    b._add(tb, m, bone)


def face(b, M):
    """얼굴 (직원과 같은 귀여운 눈 · 볼 · 입)"""
    b.ell(M["skin"], "head", (0, 0, 0.8), (0.165, 0.155, 0.155), seg=(28, 18))
    for s in (1, -1):
        b.ell(M["eye"], "head", (0.058 * s, -0.142, 0.79), (0.024, 0.014, 0.034))
        b.ell(M["shine"], "head", (0.052 * s, -0.154, 0.803), (0.009, 0.004, 0.01), seg=(10, 6))
        b.ell(M["shine"], "head", (0.065 * s, -0.153, 0.775), (0.005, 0.003, 0.005), seg=(8, 6))
        b.ell(M["blush"], "head", (0.1 * s, -0.122, 0.752), (0.028, 0.012, 0.016), seg=(12, 8))
    b.ell(M["mouth"], "head", (0, -0.152, 0.742), (0.016, 0.006, 0.007), seg=(10, 6))


def build_boss(v):
    mat = ST.mat
    M = {"skin": mat("Skin", SKIN), "eye": mat("EyeBlack", EYE, 0.3), "shine": mat("EyeShine", SHINE, 0.3),
         "blush": mat("Blush", BLUSH), "mouth": mat("Mouth", MOUTH)}
    shirt = mat("BossShirt", WHITE)
    hair = mat("BossHair" + v, {"A": "#2e2622", "B": "#5a4636", "C": "#3a2f2a"}[v])
    top = mat("BossTop" + v, {"A": NAVY, "B": "#8fa79a", "C": NAVY}[v])      # 재킷 · 카디건 · 조끼
    top_d = mat("BossTopD" + v, {"A": NAVY_D, "B": "#748c7f", "C": NAVY_D}[v])
    pants = mat("BossPants" + v, {"A": NAVY_D, "B": "#5b5f68", "C": "#4b505a"}[v])
    shoes = mat("BossShoes", "#2b2522", 0.5)
    tie = mat("BossTie", SKY, 0.5)
    b = ST.Body()
    face(b, M)
    # 머리 모양
    if v == "A":     # 단정한 옆가르마 (한쪽으로 넘긴 앞머리)
        b.ell(hair, "head", (0, 0.03, 0.848), (0.177, 0.166, 0.152), seg=(28, 18))
        b.ell(hair, "head", (0.035, -0.112, 0.905), (0.135, 0.055, 0.05))
        b.ell(hair, "head", (-0.105, -0.1, 0.885), (0.055, 0.045, 0.04))
        for s in (1, -1):
            b.ell(hair, "head", (0.15 * s, 0.01, 0.81), (0.024, 0.065, 0.055))
    elif v == "B":   # 동그란 보브 + 둥근 안경
        b.ell(hair, "head", (0, 0.035, 0.84), (0.188, 0.176, 0.165), seg=(28, 18))
        for x in (-0.09, 0.0, 0.09):
            b.ell(hair, "head", (x, -0.118, 0.9), (0.075, 0.05, 0.048))
        for s in (1, -1):
            b.ell(hair, "head", (0.16 * s, -0.01, 0.76), (0.04, 0.08, 0.09))
            torus(b, mat("Glasses", "#3b3d42", 0.4), "head", (0.058 * s, -0.158, 0.79), 0.042, 0.006)
        b.cap(mat("Glasses", "#3b3d42", 0.4), "head", (-0.018, -0.16, 0.795 - ST.HEAD_DROP), (0.018, -0.16, 0.795 - ST.HEAD_DROP), 0.005)
    else:            # 짧은 머리 + 올린 앞머리
        b.ell(hair, "head", (0, 0.03, 0.845), (0.172, 0.162, 0.148), seg=(28, 18))
        b.ell(hair, "head", (0.0, -0.085, 0.94), (0.12, 0.07, 0.06))
        for s in (1, -1):
            b.ell(hair, "head", (0.147 * s, 0.01, 0.82), (0.022, 0.06, 0.045))
    # 몸통: 흰 셔츠 + (재킷 · 카디건 · 조끼) + 앞 V 사이 셔츠 + 넥타이
    b.ell(shirt, "body", (0, 0.01, 0.47), (0.13, 0.11, 0.15))
    b.ell(top, "body", (0, 0.012, 0.462), (0.138, 0.118, 0.14))
    b.ell(shirt, "body", (0, -0.104, 0.54), (0.036, 0.014, 0.07))
    b.ell(shirt, "body", (0, 0.005, 0.605), (0.085, 0.075, 0.03))                   # 깃
    if v in "AC":
        b.ell(tie, "body", (0, -0.118, 0.52), (0.017, 0.008, 0.06))
        b.ell(tie, "body", (0, -0.115, 0.585), (0.014, 0.008, 0.012), seg=(10, 6))   # 매듭
    if v == "A":     # 라펠 + 가슴 행커치프
        for s in (1, -1):
            b.ell(top_d, "body", (0.04 * s, -0.11, 0.55), (0.02, 0.01, 0.06))
        b.ell(mat("Pocket", SKY, 0.6), "body", (0.075, -0.112, 0.5), (0.018, 0.006, 0.01), seg=(10, 6))
    else:            # 단추 3
        for z in (0.5, 0.45, 0.4):
            b.ell(top_d, "body", (0, -0.124, z), (0.01, 0.005, 0.01), seg=(10, 6))
    b.ell(pants, "root", (0, 0.01, 0.33), (0.122, 0.102, 0.085))
    for s, side in ((1, "L"), (-1, "R")):
        x = 0.06 * s
        b.cap(pants, "thigh_" + side, (x, 0.01, ST.HIP), (x, 0.01, 0.17), 0.048)
        b.cap(pants, "shin_" + side, (x, 0.01, 0.17), (x, 0.0, 0.07), 0.042)
        b.ell(shoes, "shin_" + side, (x, -0.02, 0.04), (0.05, 0.072, 0.036))
        sleeve = shirt if v == "C" else top                                           # C = 셔츠 소매만 (조끼)
        b.cap(sleeve, "arm_" + side, (0.125 * s, 0.0, 0.56), (0.155 * s, 0.0, 0.465), 0.042)
        if v == "C":   # 걷은 소매 (팔꿈치 위 흰 주름 + 아래팔 = 피부)
            b.ell(shirt, "fore_" + side, (0.156 * s, -0.004, 0.452), (0.043, 0.043, 0.02))
            b.cap(mat("Skin", SKIN), "fore_" + side, (0.155 * s, 0.0, 0.445), (0.16 * s, -0.015, 0.39), 0.032)
        else:
            b.cap(top, "fore_" + side, (0.155 * s, 0.0, 0.465), (0.16 * s, -0.015, 0.39), 0.038)
            b.ell(shirt, "fore_" + side, (0.16 * s, -0.015, 0.393), (0.041, 0.041, 0.014))   # 소맷부리
        b.ell(M["skin"], "fore_" + side, (0.16 * s, -0.018, 0.36), (0.038, 0.036, 0.04))
    if v == "B":   # 카디건 주머니
        for s in (1, -1):
            b.ell(top_d, "body", (0.075 * s, -0.106, 0.405), (0.032, 0.008, 0.022), seg=(12, 8))
    return b.obj("Boss")


def rig(v, x=0.0):
    arm = ST.make_armature("Boss")
    o = build_boss(v)
    o.parent = arm
    o.modifiers.new("Armature", "ARMATURE").object = arm
    arm.location = (x, 0, 0)
    return arm, o


def staff_ref(x):
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "game", "assets", "models", "staff.glb")
    root = bpy.data.objects.new("StaffRef", None)
    bpy.context.scene.collection.objects.link(root)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    for o in set(bpy.data.objects) - before:
        if o.parent is None:
            o.parent = root
        if o.name.startswith("Vest"):
            o.hide_render = True
    root.location = (x, 0, 0)


def label(t, x):
    txt = bpy.data.curves.new("T" + t, "FONT")
    txt.body = t
    txt.size = 0.07
    txt.align_x = "CENTER"
    o = bpy.data.objects.new("T" + t, txt)
    o.data.materials.append(ST.mat("Label", "#1f2329", 0.5))
    bpy.context.scene.collection.objects.link(o)
    o.rotation_euler = (math.radians(90), 0, 0)
    o.location = (x, -0.1, -0.1)


def preview():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for i, v in enumerate("ABC"):
        rig(v, (i - 1.5) * 0.5)
        label(v, (i - 1.5) * 0.5)
    staff_ref(0.75)
    label("직원", 0.75)
    scn = bpy.context.scene
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scn.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.2
    pitch = math.radians(12)
    cam.location = (0, -6 * math.cos(pitch), 0.45 + 6 * math.sin(pitch))
    cam.rotation_euler = (math.pi / 2 - pitch, 0, 0)
    scn.camera = cam
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.rotation_euler = (0.7, 0.2, 0.4)
    scn.collection.objects.link(sun)
    scn.world = bpy.data.worlds.new("W")
    scn.world.use_nodes = True
    scn.world.node_tree.nodes["Background"].inputs[0].default_value = (0.72, 0.8, 0.88, 1)
    scn.view_settings.view_transform = "Standard"
    scn.render.resolution_x, scn.render.resolution_y = 1500, 760
    scn.render.filepath = os.path.join(OUT, "pick_boss.png")
    bpy.ops.render.render(write_still=True)
    print("[boss]", scn.render.filepath)


# ------------------------------------------------------------------ 사장 동작 (직원 동작 전부 + 사장만의 2개)
SIT_LEGS = {"thigh_L": {"rot": (-88, 0, 0)}, "thigh_R": {"rot": (-88, 0, 0)},
            "shin_L": {"rot": (80, 0, 0)}, "shin_R": {"rot": (80, 0, 0)}}


def _lerp(a, b, k):
    return tuple(x + (y - x) * k for x, y in zip(a, b))


def boss_actions(arm):
    ST.actions(arm)

    def throw(t):   # 앉아서 종이비행기 던지기: 0~0.45 팔 올림 · 0.45~0.65 앞으로 휙 (0.6 = 손에서 놓음) · 0.65~1 내림
        sit_a, up_a, fwd_a = (-55, 0, -10), (-165, 0, -25), (-75, 0, -8)
        sit_f, up_f, fwd_f = (-30, 0, 0), (-70, 0, 0), (0, 0, 0)
        if t < 0.45:
            k = ST.ease(t / 0.45)
            a, f, lean = _lerp(sit_a, up_a, k), _lerp(sit_f, up_f, k), -4 * k
        elif t < 0.65:
            k = ST.ease((t - 0.45) / 0.2)
            a, f, lean = _lerp(up_a, fwd_a, k), _lerp(up_f, fwd_f, k), -4 + 12 * k
        else:
            k = ST.ease((t - 0.65) / 0.35)
            a, f, lean = _lerp(fwd_a, sit_a, k), _lerp(fwd_f, sit_f, k), 8 * (1 - k)
        return {**SIT_LEGS, "body": {"rot": (4 + lean, 0, -4)}, "head": {"rot": (-6, 0, -6)},
                "arm_R": {"rot": a}, "fore_R": {"rot": f},
                "arm_L": {"rot": (-55, 0, 10)}, "fore_L": {"rot": (-30, 0, 0)}}
    ST.action(arm, "SitThrow", 24, throw)
    ST.action(arm, "SitRead", 72, lambda t: {**SIT_LEGS,   # 두 손으로 보고서 들고 읽기 + 끄덕
        "body": {"rot": (3, 0, 0)}, "head": {"rot": (14 + 4 * ST.S(t * 2), 0, 3 * ST.S(t))},
        "arm_L": {"rot": (-62, 0, 22)}, "fore_L": {"rot": (-58, 0, -38)},
        "arm_R": {"rot": (-62, 0, -22)}, "fore_R": {"rot": (-58, 0, 38)}})


def build_report():
    """읽는 보고서 (몸통 뼈 = 가슴 앞, 손 사이). 게임: SitRead 때만 보임"""
    b = ST.Body()
    paper, line, clip = ST.mat("ReportPaper", "#f6f4ef", 0.8), ST.mat("ReportLine", "#9aa0a6", 0.8), ST.mat("ReportClip", NAVY, 0.5)
    tb = bmesh.new()
    bmesh.ops.create_cube(tb, size=1.0)
    bmesh.ops.scale(tb, vec=Vector((0.16, 0.006, 0.2)), verts=tb.verts)
    bmesh.ops.transform(tb, matrix=Matrix.Translation((0, -0.19, 0.47)) @ Matrix.Rotation(math.radians(-35), 4, "X"), verts=tb.verts)
    b._add(tb, paper, "body")
    for k in range(4):
        tb = bmesh.new()
        bmesh.ops.create_cube(tb, size=1.0)
        bmesh.ops.scale(tb, vec=Vector((0.11 - (k % 2) * 0.03, 0.004, 0.008)), verts=tb.verts)
        z = 0.05 - k * 0.03
        bmesh.ops.transform(tb, matrix=Matrix.Translation((0, -0.19, 0.47)) @ Matrix.Rotation(math.radians(-35), 4, "X")
                            @ Matrix.Translation((0, -0.005, z)), verts=tb.verts)
        b._add(tb, line if k else clip, "body")
    return b.obj("Report")


def export_boss():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    arm, body = rig(CHOICE)
    rep = build_report()
    rep.parent = arm
    rep.modifiers.new("Armature", "ARMATURE").object = arm
    boss_actions(arm)
    bpy.ops.object.select_all(action="DESELECT")
    for o in (arm, body, rep):
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "boss.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_animations=True, export_animation_mode="NLA_TRACKS", export_apply=False)
    print(f"[boss] -> {path}")
    if "--pose" in ARGS:   # 동작 확인 그림: SitThrow 0.45 · 0.6 / SitRead
        scn = bpy.context.scene
        ad = arm.animation_data
        cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
        scn.collection.objects.link(cam)
        cam.location = (0.9, -1.9, 1.0)
        cam.rotation_euler = (math.radians(72), 0, math.radians(25))
        scn.camera = cam
        sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
        sun.data.energy = 3.2
        sun.rotation_euler = (0.7, 0.2, 0.4)
        scn.collection.objects.link(sun)
        scn.world = bpy.data.worlds.new("W")
        scn.world.use_nodes = True
        scn.world.node_tree.nodes["Background"].inputs[0].default_value = (0.72, 0.8, 0.88, 1)
        scn.view_settings.view_transform = "Standard"
        scn.render.resolution_x, scn.render.resolution_y = 400, 500
        arm.location.z = 0.25   # 의자 높이 대신 띄움
        for nm, f, tag in (("Sit", 12, "sit"), ("SitThrow", 11, "throw_up"), ("SitThrow", 15, "throw_go"), ("SitRead", 20, "read")):
            for tr in ad.nla_tracks:
                tr.mute = tr.name != nm
            rep.hide_render = nm != "SitRead"
            scn.frame_set(f)
            scn.render.filepath = os.path.join(ARGS[ARGS.index("--pose") + 1], "boss_%s.png" % tag)
            bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    if PREVIEW:
        preview()
    else:
        export_boss()
